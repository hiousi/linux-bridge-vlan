# Verification

> Run these from console access where possible.

## 1. Confirm devices are up

```bash
networkctl status br0
networkctl status eth0
networkctl status br0.90
```

## 2. Confirm VLAN membership (kernel view)


```bash
bridge vlan show
```

Expect:

- eth0 has the allowed VLANs (tagged)
- br0 shows VLAN 90 as self (so br0.90 receives traffic)
- VM ports (vnetX) show VLAN membership matching libvirt XML

```bash
root@host:~# bridge vlan show
port              vlan-id
eth0              1 PVID Egress Untagged
                  10
                  20
                  40
                  90
                  110
                  120
br0               1 PVID Egress Untagged
                  90
vnet0             40 PVID Egress Untagged
vnet1             10 PVID Egress Untagged
vnet2             20 PVID Egress Untagged
vnet3             40 PVID Egress Untagged
vnet4             90 PVID Egress Untagged
vnet5             110 PVID Egress Untagged
vnet6             120 PVID Egress Untagged
```

## 3. Confirm routing on VLAN 90

```bash
ip addr show br0.90
ip route
```


## 4. Packet sanity

```bash
sudo tcpdump -eni br0 vlan 90
```


## 5. Common failure modes

- No connectivity on VLAN 90: missing Self=yes on br0 or VLAN not allowed on trunk
- VM can’t reach network: VM port VLAN tag mismatch or VLAN not allowed on eth0
- Host loses connectivity after restart: wrong NIC name (eth0 vs enpXsY)