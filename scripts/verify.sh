#!/usr/bin/env bash
set -euo pipefail

echo "== networkctl status (br0, eth0, br0.90) =="
networkctl status br0 || true
echo
networkctl status eth0 || true
echo
networkctl status br0.90 || true
echo

echo "== bridge vlan show =="
bridge vlan show || true
echo

echo "== ip addr (br0.90) =="
ip addr show br0.90 || true
echo

echo "== routes =="
ip route || true
echo

echo "Hints:"
echo "- If br0.90 can't talk: confirm VLAN 90 is allowed on eth0 and br0 has VLAN 90 as self."
echo "- If a VM can't talk: confirm its vnetX VLAN tag matches your libvirt XML and is allowed on eth0."

