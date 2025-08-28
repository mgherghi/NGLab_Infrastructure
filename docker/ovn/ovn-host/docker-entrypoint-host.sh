#!/usr/bin/env bash
set -euo pipefail

if [ "$(hostname -s)" = "gigabyte" ]; then
    ovs-vsctl set Open_vSwitch . other_config:hw-offload=true
    ovs-vsctl set Open_vSwitch . other_config:tc-policy=hw-offload
    ovs-vsctl add-br mlnx_sriov
    ovs-vsctl add-port mlnx_sriov mlnx-vf_bond trunks=[10,20,30,40,50,60,70,80,90,100]
    for i in $(seq 0 9); do
       ovs-vsctl add-port mlnx_sriov enp65s0f0r"$i" tag=$((i+1))0
    done
fi

ovs-vsctl set open_vswitch . \
   external_ids:ovn-remote=tcp:${SERVER_1}:6642,tcp:${SERVER_2}:6642,tcp:${SERVER_3}:6642 \
   external_ids:ovn-encap-type=geneve \
   external_ids:ovn-encap-ip=${LOCAL_IP}

# Health tail
touch /var/log/ovn/ovn-controller.log /var/log/openvswitch/ovs-vswitchd.log /var/log/openvswitch/ovsdb-server.log
tail -F /var/log/ovn/ovn-controller.log /var/log/openvswitch/ovs-vswitchd.log /var/log/openvswitch/ovsdb-server.log
