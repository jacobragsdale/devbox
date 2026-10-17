#!/bin/sh
# Publishes people/*.pub as the dev box's authorized_keys. No restart needed: kubelet updates the
# mounted ConfigMap within about a minute, and sshd rereads it at every login.
set -eu
cd "$(dirname "$0")/.."
cat people/*.pub \
    | kubectl -n "${NAMESPACE:-devbox}" create configmap devbox-keys --from-file=authorized_keys=/dev/stdin \
        --dry-run=client -o yaml \
    | kubectl -n "${NAMESPACE:-devbox}" apply -f -
