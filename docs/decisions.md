# Design decisions

## Why systemd-networkd (vs ifupdown/NetworkManager)
Established facts:
- Deterministic device creation and ordering at boot.
- Plain-text config that is easy to version-control.

Implication:
- Fewer “it works on this host only” surprises.

## Why Linux bridge VLAN filtering (vs OVS)
Established facts:
- Kernel bridge VLAN filtering is mature and efficient (in-kernel switching).

Reasonable hypothesis:
- OVS is unnecessary unless you need SDN features, OpenFlow, or more complex policy.

Implication:
- Lower operational complexity and fewer moving parts for a typical DevOps host.

## Why route VLAN 90 on the host
Reasonable practice:
- Having a management VLAN with host IP simplifies access, monitoring, and automation.

Risk:
- If you start routing more VLANs on the host, you can unintentionally create lateral movement paths.

