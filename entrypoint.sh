#!/usr/bin/env bash
# Runs as root: remaps dev's UID/GID, provisions SSH keys from the read-only host
# mount, then either starts sshd (no args) or runs the command as dev.
set -euo pipefail

DEV_UID="${DEV_UID:-1000}"
DEV_GID="${DEV_GID:-1000}"
DEV_HOME=/home/dev
HOST_SSH=/tmp/host-ssh

# volume roots / install dirs that must stay writable for dev
OWNED_DIRS=(/home/dev/.cargo /home/dev/go /home/dev/.cache /home/dev/.cache/uv /home/dev/.pnpm-store
            /usr/local/cargo /usr/local/rustup /opt/oh-my-zsh /opt/flutter)

if [ "$(id -u dev)" != "$DEV_UID" ] || [ "$(id -g dev)" != "$DEV_GID" ]; then
  groupmod -o -g "$DEV_GID" dev 2>/dev/null || true
  usermod -o -u "$DEV_UID" -g "$DEV_GID" dev 2>/dev/null || true
  chown -R dev:dev "$DEV_HOME" "${OWNED_DIRS[@]:3}" 2>/dev/null || true
fi

# named volumes (and Docker-created mount points) can come up root-owned
for d in "${OWNED_DIRS[@]}"; do
  if [ -d "$d" ] && [ "$(stat -c %u "$d")" != "$DEV_UID" ]; then
    chown -R dev:dev "$d" 2>/dev/null || true
  fi
done

mkdir -p /work
[ "$(stat -c %u /work)" = "$DEV_UID" ] || chown dev:dev /work 2>/dev/null || true

# first run with a fresh home volume: oh-my-zsh lives in /opt, dotfiles come from /etc/skel
[ -e "$DEV_HOME/.oh-my-zsh" ] || ln -s /opt/oh-my-zsh "$DEV_HOME/.oh-my-zsh"
[ -e "$DEV_HOME/.zshrc" ] || install -o dev -g dev -m 644 /etc/skel/.zshrc "$DEV_HOME/.zshrc"
chown -h dev:dev "$DEV_HOME/.oh-my-zsh" 2>/dev/null || true

# SSH: copy keys from the read-only staging mount with sane ownership and modes
if [ -d "$HOST_SSH" ]; then
  install -d -o dev -g dev -m 700 "$DEV_HOME/.ssh"
  shopt -s nullglob dotglob
  for f in "$HOST_SSH"/*; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    case "$name" in
      *.pub|known_hosts|known_hosts.old|authorized_keys) mode=644 ;;
      *) mode=600 ;;
    esac
    install -o dev -g dev -m "$mode" "$f" "$DEV_HOME/.ssh/$name"
  done
  shopt -u nullglob dotglob
  # key login for sshd: every host public key is allowed
  if compgen -G "$HOST_SSH/*.pub" >/dev/null; then
    cat "$HOST_SSH"/*.pub > "$DEV_HOME/.ssh/authorized_keys"
    chown dev:dev "$DEV_HOME/.ssh/authorized_keys"; chmod 600 "$DEV_HOME/.ssh/authorized_keys"
  fi
fi

# known_hosts: add github/gitlab only if missing (needs network, failure is not fatal)
if [ -d "$DEV_HOME/.ssh" ]; then
  kh="$DEV_HOME/.ssh/known_hosts"
  for host in github.com gitlab.com; do
    if ! gosu dev ssh-keygen -F "$host" -f "$kh" >/dev/null 2>&1; then
      keys="$(timeout 10 ssh-keyscan -T 5 "$host" 2>/dev/null || true)"
      if [ -n "$keys" ]; then
        printf '%s\n' "$keys" >> "$kh"
        chown dev:dev "$kh"; chmod 644 "$kh"
      fi
    fi
  done
fi

if [ "$#" -eq 0 ]; then
  install -d /run/sshd
  exec /usr/sbin/sshd -D -e
fi
exec gosu dev "$@"
