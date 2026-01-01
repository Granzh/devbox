#!/usr/bin/env bash
set -euo pipefail

HOST_UID=${UID:-1000}
HOST_GID=${GID:-1000}

if [ "$(id -u dev)" != "$HOST_UID" ] || [ "$(id -g dev)" != "$HOST_GID" ]; then
  usermod -u "$HOST_UID" dev 2>/dev/null || true
  groupmod -g "$HOST_GID" dev 2>/dev/null || true
  chown -R dev:dev /home/dev || true
fi

mkdir -p /work
chown -R dev:dev /work || true


if [ "$#" -eq 0 ]; then
  exec /usr/sbin/sshd -D -e
else
  exec "$@"
fi
