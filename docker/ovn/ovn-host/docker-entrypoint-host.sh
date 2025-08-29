#!/bin/sh
set -eu
OVS_CTL=/usr/share/openvswitch/scripts/ovs-ctl
OVN_CTL=/usr/share/ovn/scripts/ovn-ctl

# Required env:
: "${SB_REMOTES:?e.g. tcp:4.0.0.7:6642,tcp:4.0.0.8:6642,tcp:4.0.0.9:6642}"
: "${ENCAP_IP:?e.g. 4.0.0.5}"
: "${ENCAP_TYPE:=geneve}"  # geneve|vxlan

# Prepare runtime dirs (container-local; do NOT mount host /run/openvswitch)
mkdir -p /var/run/openvswitch /var/log/openvswitch /etc/openvswitch
rm -f /var/run/openvswitch/ovsdb-server.pid /var/run/openvswitch/db.sock || true

# Create OVS config DB on first boot
if [ ! -f /etc/openvswitch/conf.db ]; then
  ovsdb-tool create /etc/openvswitch/conf.db /usr/share/openvswitch/vswitch.ovsschema
fi

# Start OVS user-space daemons
"$OVS_CTL" --no-mlockall --system-id=random start

# Wait until ovsdb is ready
i=0
until ovs-vsctl --timeout=2 show >/dev/null 2>&1; do
  i=$((i+1)); [ $i -gt 60 ] && echo "OVS not ready" >&2 && exit 1
  sleep 1
done

# Configure OVN southbound + encap on the switch
ovs-vsctl --retry -- set Open_vSwitch . external-ids:ovn-remote="${SB_REMOTES}"
ovs-vsctl --retry -- set Open_vSwitch . external-ids:ovn-encap-type="${ENCAP_TYPE}"
ovs-vsctl --retry -- set Open_vSwitch . external-ids:ovn-encap-ip="${ENCAP_IP}"
ovs-vsctl --retry -- set Open_vSwitch . other_config:tc-policy=hw-offload
ovs-vsctl --retry -- set Open_vSwitch . other_config:hw-offload=true


# Optional: create bridge & ports only on host "gigabyte"
if [ "$(hostname -s)" = "gigabyte" ]; then
  # Create the bridge
  ovs-vsctl --may-exist add-br mlnx_sriov

  # Add the bonded VF port with VLAN trunks (correct syntax, no brackets)
  ovs-vsctl --may-exist add-port mlnx_sriov mlnx-vf_bond trunks=10,20,30,40,50,60,70,80,90,100

  # Add ten VF ports, tagging them 10,20,...,100
  for i in $(seq 0 9); do
    tag=$(( (i + 1) * 10 ))
    ovs-vsctl --may-exist add-port mlnx_sriov "enp65s0f0r${i}" tag="${tag}"
  done
fi

# Start ovn-controller (uses /var/run/ovn/ by default)
"$OVN_CTL" --no-monitor start_controller


# Keep in foreground, stop cleanly on signal
trap 'echo "Stopping..."; "$OVN_CTL" stop_controller;  "$OVS_CTL" stop; exit 0' TERM INT


touch /var/log/openvswitch/ovs-vswitchd.log /var/log/openvswitch/ovsdb-server.log
tail -F /var/log/openvswitch/*.log
