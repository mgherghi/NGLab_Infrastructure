#!/bin/sh
set -eu

# Required env
: "${LOCAL_IP:?local IP for this node}"
: "${SERVER_1:?bootstrap peer IP}"
: "${SERVER_2:?peer 2 IP}"
: "${SERVER_3:?peer 3 IP}"
: "${ROLE:=bootstrap}"   # bootstrap | joiner

# Render OVN central opts (NB=6641, SB=6642)
if [ "$ROLE" = "bootstrap" ]; then
  OVN_CTL_OPTS=" \
    --db-nb-addr=${LOCAL_IP} \
    --db-nb-create-insecure-remote=yes \
    --db-sb-addr=${LOCAL_IP} \
    --db-sb-create-insecure-remote=yes \
    --db-nb-cluster-local-addr=${LOCAL_IP} \
    --db-sb-cluster-local-addr=${LOCAL_IP} \
    --ovn-northd-nb-db=tcp:${SERVER_1}:6641,tcp:${SERVER_2}:6641,tcp:${SERVER_3}:6641 \
    --ovn-northd-sb-db=tcp:${SERVER_1}:6642,tcp:${SERVER_2}:6642,tcp:${SERVER_3}:6642"
else
  OVN_CTL_OPTS=" \
    --db-nb-addr=${LOCAL_IP} \
    --db-nb-cluster-remote-addr=${SERVER_1} \
    --db-nb-create-insecure-remote=yes \
    --db-sb-addr=${LOCAL_IP} \
    --db-sb-cluster-remote-addr=${SERVER_1} \
    --db-sb-create-insecure-remote=yes \
    --db-nb-cluster-local-addr=${LOCAL_IP} \
    --db-sb-cluster-local-addr=${LOCAL_IP} \
    --ovn-northd-nb-db=tcp:${SERVER_1}:6641,tcp:${SERVER_2}:6641,tcp:${SERVER_3}:6641 \
    --ovn-northd-sb-db=tcp:${SERVER_1}:6642,tcp:${SERVER_2}:6642,tcp:${SERVER_3}:6642"
fi

# First boot: create NB/SB DBs if missing (idempotent)
if [ ! -f /var/lib/ovn/ovnnb_db.db ]; then
  ovn-ctl --no-monitor ${OVN_CTL_OPTS} run_nb_ovsdb && ovn-ctl stop_nb_ovsdb
fi
if [ ! -f /var/lib/ovn/ovnsb_db.db ]; then
  ovn-ctl --no-monitor ${OVN_CTL_OPTS} run_sb_ovsdb && ovn-ctl stop_sb_ovsdb
fi

# Start services
ovn-ctl --no-monitor ${OVN_CTL_OPTS} start_nb_ovsdb
ovn-ctl --no-monitor ${OVN_CTL_OPTS} start_sb_ovsdb
ovn-ctl --no-monitor ${OVN_CTL_OPTS} start_northd

# Keep foreground
trap 'echo "Stopping..."; ovn-ctl stop_northd; ovn-ctl stop_sb_ovsdb; ovn-ctl stop_nb_ovsdb; exit 0' TERM INT
touch /var/log/ovn/ovn-northd.log /var/log/ovn/ovn-nb.log /var/log/ovn/ovn-sb.log
tail -F /var/log/ovn/*.log
