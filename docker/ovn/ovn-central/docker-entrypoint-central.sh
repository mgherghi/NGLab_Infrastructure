#!/bin/sh
set -eu

LOG_DIR=/var/log/ovn

case "$(hostname -s)" in
  r730xd-1)
    cat > /etc/default/ovn-central <<EOF
OVN_CTL_OPTS=" \
    --db-nb-addr=${LOCAL_IP} \
    --db-nb-create-insecure-remote=yes \
    --db-sb-addr=${LOCAL_IP} \
    --db-sb-create-insecure-remote=yes \
    --db-nb-cluster-local-addr=${LOCAL_IP} \
    --db-sb-cluster-local-addr=${LOCAL_IP} \
    --ovn-northd-nb-db=tcp:${SERVER_1}:6641,tcp:${SERVER_2}:6641,tcp:${SERVER_3}:6641 \
    --ovn-northd-sb-db=tcp:${SERVER_1}:6642,tcp:${SERVER_2}:6642,tcp:${SERVER_3}:6642"
EOF
    echo "[INFO] /etc/default/ovn-central written for r730xd-1 (cluster bootstrap)"
    ;;

  r730xd-2|r730xd-3)
    cat > /etc/default/ovn-central <<EOF
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
EOF
    echo "[INFO] /etc/default/ovn-central written for $(hostname -s) (cluster joiner)"
    ;;

  *)
    echo "[WARN] Hostname $(hostname -s) not recognized, no changes made."
    ;;
esac


# -----------------------------
# Keep container alive / stream logs
# -----------------------------
touch "${LOG_DIR}/ovn-northd.log" "${LOG_DIR}/ovsdb-server.log"
tail -F "${LOG_DIR}/ovn-northd.log" "${LOG_DIR}/ovsdb-server.log"
