#!/usr/bin/env bash
set -euo pipefail

# Если переданы UID/GID — подстроим пользователя dev
HOST_UID=${UID:-1000}
HOST_GID=${GID:-1000}

if [ "$(id -u dev)" != "$HOST_UID" ] || [ "$(id -g dev)" != "$HOST_GID" ]; then
  usermod -u "$HOST_UID" dev 2>/dev/null || true
  groupmod -g "$HOST_GID" dev 2>/dev/null || true
  # Домашняя директория контейнера
  chown -R dev:dev /home/dev 2>/dev/null || true
fi

# SSH-агент
if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "${SSH_AUTH_SOCK}" ]; then
  export SSH_AUTH_SOCK
fi

# Рабочая папка (chown только если смонтирована и пустая метка)
mkdir -p /work
if [ ! -e /work/.dev_ownership_checked ]; then
  chown -R dev:dev /work 2>/dev/null || true
  touch /work/.dev_ownership_checked 2>/dev/null || true
fi

# Вперёд в интерактивный shell от имени dev
exec gosu dev "$@"
