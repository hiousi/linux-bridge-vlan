# Building a VLAN-Aware Linux Bridge with `systemd-networkd` and isolated VMs

This write-up explains a reproducible pattern for building a VLAN-aware Linux bridge using `systemd-networkd` , focusing on deterministic boot-time configuration, in-kernel VLAN filtering, and clear DevOps automation paths. It also shows how to segment networks for VMs, including “SVI-like” host routing for a management VLAN, without relying on SDN frameworks.

VLAN-aware bridge filtering has recently been [discussed](https://forums.freebsd.org/threads/freebsd-15-bridges-vlans-and-jails-nice.101719/) in the context of FreeBSD 15 bridges and jails.
This document focuses on the **Linux implementation** and the operational implications of using the kernel bridge as a first-class switching component, without introducing SDN overlays or additional control planes.

The goal is not novelty. It is operational clarity.

This model keeps switching inside the kernel, routing explicit, and segmentation enforceable at the bridge layer.


# Git repository

Full configuration files and examples are available here:

👉 GitHub repository:
https://github.com/hiousi/linux-bridge-vlan

# Architecture summary


The design is straightforward:

* `eth0` is an **802.1Q trunk** to a switch or vSwitch.
* `br0` is a **VLAN-aware Linux bridge** (`VLANFiltering=yes`)
* VLAN **90** is routed on the host as `br0.90` (SVI-like behavior)
* VMs attach to `br0` via `virtio`
* VLAN separation enforced at the bridge level
* A dedicated VM provides routing + firewalling
* WAN isolated on VLAN 110/120

```text
              ┌─────────────────────┐
              │        Switch       │
              │     802.1Q trunk    │
              └──────────┬──────────┘
                         │
                       eth0
                         │
    ┌────────────────────┴─────────────────────┐
    │                  Host                    │
    │                                          │
    │                  br0                     │
    │    (Linux bridge, VLAN filtering ON)     │
    │                   │                      │
    │    ┌───────────┬──┴───────┬─────────┐    │
    │    │           │          │         │    │
    │  VLAN10     VLAN20      VLAN90    VLANnn │
    │  vnet0       vnet1      vnet2     vnetn  │
    │    │           │          │         │    │
    │   VM1         VM1        VM2       VMn   │
    │                                          │
    │  br0.90  (L3 SVI-like interface)         │
    │  10.70.90.5/24  gw 10.70.90.1            │
    └──────────────────────────────────────────┘
```


Switching remains inside the kernel fast path.
Routing is explicit.
Policy lives in the firewall VM.

# DevOps and Automation Perspective

Because the entire configuration is declarative and file-based:

+ it can be templated (Ansible, Nix, Terraform provisioners, etc.)
+ it can be version-controlled and code-reviewed
+ it can be validated pre-deployment (CI linting / static checks)
+ it supports controlled rollbacks
+ it avoids configuration drift between hosts

The bridge becomes infrastructure code, not a mutable runtime artifact.

This approach is particularly relevant for:
+ bare-metal virtualization hosts
+ lab environments that need repeatability
+ small clusters without full SDN stacks
+ operators who prefer kernel primitives over orchestration-heavy networking layers






# VLAN Layout

| VLAN | Role       | Handling               |
| ---- | ---------- | ---------------------- |
| 10   | L2 only    | bridged through `br0`  |
| 20   | L2 only    | bridged through `br0`  |
| 40   | L2 only    | bridged through `br0`  |
| 90   | Internal LAN (host L3 too) | `br0.90` (mgmt)        |
| 110  | WAN / isolated segment     | bridged through `br0`  |
| 120  | WAN / isolated segment     | bridged through `br0`  |

In my case, VLAN 110/120 are treated as “WAN-side” isolated segments and are not bridged into the internal LAN in any permissive way. They exist specifically to keep the outside world separated, even on the same physical trunk.

# Why `systemd-networkd`?

### Established facts

* Kernel bridge VLAN filtering is mature and fast (in-kernel switching).
* `systemd-networkd` gives deterministic device creation and ordering.
* A declarative config removes “works on this host only” drift.

### Practical goal

A host that behaves like:

* a small VLAN-aware switch (`br0`)
* plus an SVI for one VLAN (`br0.90`)
* plus a clean attachment point for VMs

### Automation angle (Ansible/GitOps)

Because the network is just a handful of text files:

- you can template them (host-specific IP, GW, DNS)
- deploy them with Ansible
- validate with networkctl and bridge vlan show
- rollback via version control if needed

This is the opposite of “hand-tuned networking until it works”. It’s reproducible infrastructure.

# Final Host Configuration (`systemd-networkd`)

All files in:

```text
/etc/systemd/network/
```

## 1. Bridge Device

### `10-br0.netdev`

```ini
[NetDev]
Name=br0
Kind=bridge

[Bridge]
VLANFiltering=yes
STP=no
```

Notes:

* `VLANFiltering=yes` is the key: per-port VLAN enforcement happens in the kernel.
* `STP=no` assumes you have no L2 loops. If you have redundant links, reconsider.



## 2. Bridge Network + “Self VLAN” for L3

### `10-br0.network`

```ini
[Match]
Name=br0

[Network]
VLAN=br0.90

[BridgeVLAN]
VLAN=90
Self=yes
```

**This matters more than it looks.**

`Self=yes` ensures VLAN 90 is allowed on the bridge device itself, not just on its ports — so the `br0.90` L3 interface actually receives traffic.



## 3. Physical Trunk Port

### `10-eth0.network`

```ini
[Match]
Name=eth0

[Network]
Bridge=br0

[BridgeVLAN]
VLAN=10
VLAN=20
VLAN=40
VLAN=90
VLAN=110
VLAN=120
```

This defines `eth0` as a tagged trunk for those VLANs.

No native VLAN is defined here (good: fewer surprises).



## 4. Routed VLAN Interface (SVI-like)

### `20-br0.90.netdev`

```ini
[NetDev]
Name=br0.90
Kind=vlan

[VLAN]
Id=90
```

### `20-br0.90.network`

```ini
[Match]
Name=br0.90

[Network]
Address=10.70.90.5/24
Gateway=10.70.90.1
DNS=10.70.90.1
```

This makes VLAN 90 a routed segment on the host.

# The Router/Firewall VM (WAN isolated on VLAN 110/120)

A key part of the setup is a VM that acts as the network’s routing + firewall policy point.

The important operational constraint is isolation:

+ WAN is carried on VLAN 110 and/or 120
+ internal LAN is on VLAN 90 (and possibly others later)
+ the firewall VM becomes the only place where LAN↔WAN policy exists

This is essentially a virtualized firewall appliance with “ports”, except ports are virtual and VLAN-pinned.

# VM Networking Model

Inside the VM, interfaces appear as **normal Ethernet devices** (eth0, eth1...).
No eth0.90, no VLAN subinterfaces, no tagging in the guest.

The VLAN tagging is enforced by the hypervisor side (libvirt + bridge VLAN filtering). From the guest’s point of view, it’s plugged into a normal access port.

Example: firewall VM with 2 NICs

+ `eth0` = LAN interface (VLAN 90)
+ `eth1` = WAN interface (VLAN 110 or 120)

Inside the VM you just configure IPs and firewall rules on `eth0` / `eth1`.

## Pattern A: Access Port VM (libvirt adds the VLAN tag)

This is what you described: the **XML adds a VLAN tag**, so the guest just configures a normal interface.

### libvirt XML example: access port pinned to VLAN 90

```xml
<interface type='bridge'>
  <source bridge='br0'/>
  <model type='virtio'/>
  <vlan>
    <tag id='90'/>
  </vlan>
</interface>
```

### libvirt interface example (trunk)

When the VM should handle tags (router VM, firewall VM, lab box), pass multiple VLANs as a trunk.

```xml
<interface type='bridge'>
  <source bridge='br0'/>
  <model type='virtio'/>
  <vlan trunk='yes'>
    <tag id='10'/>
    <tag id='20'/>
    <tag id='90'/>
  </vlan>
</interface>
```

This is the VM equivalent of plugging into a trunk port on a physical switch.



# Verification Checklist

On the host, verify device state:

```bash
networkctl status
```

Verify VLAN membership as the kernel sees it:

```bash
bridge vlan show
```

You should see entries for:

* `eth0` carrying VLANs 10/20/40/90/110/120
* `br0` with VLAN 90 as `self`
* `vnetX` ports showing VLAN membership matching your libvirt XML (access or trunk)



# Operational Considerations

### Switch configuration must match

* trunk port must allow VLANs 10/20/40/90/110/120
* avoid accidental native VLANs unless you explicitly want one

### STP


* `STP=no` is fine in a simple topology
* enable STP if your L2 can ever form loops

### Firewalling and routing

If the firewall VM is the policy point:

* keep inter-VLAN and WAN policies in that VM
* default deny
* explicit allows only
* document what is routed on host (`br0.90`) vs what is routed via firewall VM

### Performance notes

* `virtio` is the right NIC model for throughput and CPU efficiency.
* this design stays in-kernel (bridge fast path), which is usually plenty unless you need SDN features.



# Why this is interesting

Not because VLANs on Linux are new.
But because this is a clean, modern composition of:

* VLAN-aware kernel bridge
* declarative systemd-networkd configuration
* SVI-like routed VLAN on the host
* VM segmentation implemented as access ports
* explicit LAN↔WAN policy via a firewall VM
* infrastructure-as-code networking

No hidden abstractions.
No opaque control planes.
Just explicit architecture.

# Open the discussion

I’m particularly interested in:

* edge cases around VLAN filtering and libvirt
* bonding / LACP scenarios
* multi-host trunk consistency
* performance characteristics under high PPS workloads
* operational pitfalls others have encountered
* Constructive critique welcome.