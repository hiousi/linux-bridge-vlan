# VLAN-aware Linux bridge with systemd-networkd (and isolated VMs)

I got tired of the "spaghetti" that comes with creating a dozen separate br0.10, br0.20 interfaces on my KVM hosts. I also wanted to move away from Open vSwitch (OVS) complexity while still getting proper VLAN isolation for my VMs.

This repo is a reproducible pattern for using the VLAN-aware Linux bridge. It treats a Linux host like a managed switch: one bridge (br0) that handles all the tagging, filtering, and trunking directly in the kernel fast path.

The goal is operational clarity, no SDN overlays, no external switching daemons, just explicit architecture built on kernel primitives.



**Architecture**
- physical `eth0` as an 802.1Q trunk
- bridge `br0` as a VLAN-aware Linux bridge (`VLANFiltering=yes`)
- managment VLAN 90 routed on the host via `br0.90`
- isolqtion of guest VMs connected to `br0` with VLAN separation enforced on the host side (libvirt VLAN tags)





## Full Documentation

The complete architectural explanation and configuration walkthrough is here:   
→ [Complete Architecture Guide](docs/writeup.md)


## Network Schema

![Network schema](docs/schema.png)

## Why this exists (DevOps angle)

- Declarative networking configuration (`/etc/systemd/network`) you can track in Git
- Reproducible host setup (install script)
- Clear verification steps (verification script)
- Easy to extend into **Ansible/GitOps**

## Contents

- [`docs/architecture.md`](docs/architecture.md) — topology + responsibilities (L2 vs L3)
- [`docs/decisions.md`](docs/decisions.md) — design tradeoffs & rationale
- [`docs/writeup.md`](docs/writeup.md) — full write-up and deep dive
- [`docs/verification.md`](docs/verification.md) — how to validate the setup
- [`systemd-networkd/`](systemd-networkd/) — config files to deploy on the host
- [`libvirt/`](libvirt/) — example VM NIC definitions (access VLAN and trunk)
- [`scripts/`](scripts/) — install + verify helpers

## Quick start (host)

> ⚠️ Networking changes can lock you out. Use console access or out-of-band management.

1) Copy files into `/etc/systemd/network/` (see [`scripts/install-networkd-config.sh`](scripts/install-networkd-config.sh))
2) Restart networkd:
```bash
sudo systemctl restart systemd-networkd
```
3) Verify
```bash
./scripts/verify.sh
```
