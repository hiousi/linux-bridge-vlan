
## High-level intent

The host acts like:
- a small VLAN-aware L2 switch (`br0`)
- plus one routed “SVI-like” interface for management (`br0.90`)

VM isolation is enforced by the host bridge VLAN filtering and libvirt VLAN tags.

## Components

### Physical uplink (`eth0`)
- 802.1Q trunk to switch/vSwitch
- Allowed VLAN list defined explicitly in `10-eth0.network`

### VLAN-aware bridge (`br0`)
- Kernel bridge with VLAN filtering enabled
- VLAN membership enforced per-port
- No implicit/native VLAN

### Routed VLAN interface (`br0.90`)
- Host gets an IP on VLAN 90 (management)
- Default gateway typically on VLAN 90

## Responsibilities (L2 vs L3)

### Layer 2
- VLANs are switched inside the host (kernel bridge fast-path)
- VM ports are treated as access ports or trunks (via libvirt XML + bridge VLAN filtering)

### Layer 3
- Host routes only VLAN 90 (management)
- If you add inter-VLAN routing, document it explicitly (don’t let it “accidentally happen”)

## Security boundary notes (minimal)

- VLAN separation relies on correct trunk configuration + correct bridge VLAN membership.
- `STP=no` is safe only if you’re sure you have no L2 loops.