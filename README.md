# VLAN-aware Linux bridge with systemd-networkd (and isolated VMs)

This repository demonstrates a reproducible, version-controlled Linux networking pattern using the in-kernel bridge with VLAN filtering.

It turns a virtualization host into:

+ a small VLAN-aware switch (br0)
+ an SVI-like routed interface for a management VLAN (br0.90)
+ a clean attachment point for VLAN-isolated VMs (via libvirt VLAN tags)

The goal is operational clarity, no SDN overlays, no external switching daemons, just explicit architecture built on kernel primitives.

**Architecture overview**
- `eth0` as an 802.1Q trunk
- `br0` as a VLAN-aware Linux bridge (`VLANFiltering=yes`)
- VLAN 90 routed on the host via `br0.90`
- VMs connected to `br0` with VLAN separation enforced on the host side (libvirt VLAN tags)
- Validation commands included




## Full Documentation

The complete architectural explanation and configuration walkthrough is here:   
→ [Complete Architecture and Configuration Guide](docs/writeup.md)


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
