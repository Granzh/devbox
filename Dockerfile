# devbox-base: shell stack, C/C++ (current clang + cppcheck from Ubuntu apt),
# Python + uv, Node + pnpm, Rust, Go, mise and everyday CLI tools.
# Flutter and Java live in docker/*.Dockerfile on top of this image.
#
# Toolchains are installed OUTSIDE /home/dev on purpose: /home/dev is a named
# volume at runtime and would hide anything baked into it.

# FROM tags are literal on purpose: Dependabot reads and bumps them.
FROM ghcr.io/astral-sh/uv:0.9.5 AS uv
FROM docker:27-cli AS dockercli
FROM node:24.22.2-bookworm-slim AS node

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG RUST_TOOLCHAIN=stable
# "latest" resolves the newest stable release from go.dev (checksum from go.dev's own JSON index)
ARG GO_VERSION=latest
ARG JUST_VERSION=1.43.0
ARG TZ=Europe/Moscow

# --- apt packages (one layer, downloads cached across builds) ---
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg xz-utils unzip zip sudo gosu tzdata \
        git git-lfs openssh-client openssh-server netcat-openbsd \
        zsh bash-completion vim neovim \
        build-essential pkg-config gdb valgrind cmake libssl-dev \
        clang clang-tools clang-tidy clang-format lldb lld cppcheck \
        python3 python3-venv python3-pip python3-dev \
        ripgrep fd-find fzf jq tmux bat direnv htop; \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd; \
    ln -sf /usr/bin/batcat /usr/local/bin/bat; \
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime; echo "${TZ}" > /etc/timezone; \
    git config --system --add safe.directory '*'; \
    git lfs install --system --skip-repo

# --- mise (from its apt repo, so a rebuild with --pull brings a new mise). Tool versions
# are managed at runtime by `devbox update`; data lives in the home volume.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    install -dm 755 /etc/apt/keyrings; \
    curl -fsSL https://mise.jdx.dev/gpg-key.pub | gpg --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=$(dpkg --print-architecture)] https://mise.jdx.dev/deb stable main" > /etc/apt/sources.list.d/mise.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends mise; \
    mise --version
COPY docker/mise-global.toml /etc/devbox/mise-global.toml

# --- user dev (UID/GID are remapped by entrypoint.sh) ---
# Ubuntu 24.04+ ships an 'ubuntu' user on 1000:1000; drop it so dev can take that id
# password '*' (not '!') keeps the account usable for key-only sshd logins
RUN set -eux; \
    if id ubuntu >/dev/null 2>&1; then userdel -r ubuntu; fi; \
    groupadd -g 1000 dev; \
    useradd -m -s /usr/bin/zsh -u 1000 -g 1000 dev; \
    usermod -p '*' dev; \
    usermod -aG sudo dev; \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/devbox; chmod 0440 /etc/sudoers.d/devbox; \
    install -d -o dev -g dev /home/dev/.cargo /home/dev/go /home/dev/.cache /home/dev/.cache/uv /home/dev/.pnpm-store /work /opt/oh-my-zsh

COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=uv /uv /uvx /usr/local/bin/

# --- Node.js from the official image (Dependabot bumps the tag in the FROM line at the top) ---
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN set -eux; \
    ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm; \
    ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx; \
    node --version; npm --version

# --- pnpm + Claude Code: npm global as root => /usr/local (outside the home volume).
# Versions come from docker/npm/package.json (Dependabot bumps them). Config/login live in
# /home/dev/.claude and /home/dev/.claude.json (the devbox-home volume).
# Auto-update is off for this baked copy (root-owned). `devbox update` installs a newer
# claude via mise into the home volume; its shim then wins over this one.
COPY docker/npm/package.json /tmp/npm-tools/package.json
RUN --mount=type=cache,target=/root/.npm \
    set -eux; \
    npm install -g $(node -p "Object.entries(require('/tmp/npm-tools/package.json').dependencies).map(([n,v])=>n+'@'+v).join(' ')"); \
    rm -rf /tmp/npm-tools; \
    pnpm --version; gosu dev claude --version

# --- Go (checksum comes from the go.dev download index) ---
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    if [ "${GO_VERSION}" = latest ]; then url='https://go.dev/dl/?mode=json'; sel='.[0]'; \
    else url='https://go.dev/dl/?mode=json&include=all'; sel=".[] | select(.version==\"go${GO_VERSION}\")"; fi; \
    meta="$(curl -fsSL "${url}" | jq -c "${sel} | .files[] | select(.os==\"linux\" and .arch==\"${arch}\" and .kind==\"archive\")")"; \
    f="$(echo "${meta}" | jq -r .filename)"; sum="$(echo "${meta}" | jq -r .sha256)"; \
    curl -fsSLo "/tmp/${f}" "https://go.dev/dl/${f}"; \
    echo "${sum}  /tmp/${f}" | sha256sum -c -; \
    tar -C /usr/local -xzf "/tmp/${f}"; rm -f "/tmp/${f}"; \
    /usr/local/go/bin/go version

# --- just (apt's version is old; release tarball is checksum-verified) ---
RUN set -eux; \
    case "$(dpkg --print-architecture)" in amd64) t=x86_64-unknown-linux-musl;; arm64) t=aarch64-unknown-linux-musl;; *) exit 1;; esac; \
    f="just-${JUST_VERSION}-${t}.tar.gz"; base="https://github.com/casey/just/releases/download/${JUST_VERSION}"; \
    cd /tmp; curl -fsSLO "${base}/${f}"; \
    curl -fsSL "${base}/SHA256SUMS" | grep " ${f}\$" | sha256sum -c -; \
    tar -xzf "${f}" -C /usr/local/bin just; rm -f "${f}"; just --version

# --- Rust: toolchain + rustup proxies in /usr/local; CARGO_HOME moves to the volume at runtime ---
ENV RUSTUP_HOME=/usr/local/rustup
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    set -eux; \
    export CARGO_HOME=/usr/local/cargo; \
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal \
        --default-toolchain "${RUST_TOOLCHAIN}" -c clippy -c rustfmt -c rust-analyzer; \
    chown -R dev:dev /usr/local/cargo /usr/local/rustup; \
    /usr/local/cargo/bin/rustc --version

# --- zsh stack, in /opt so the home volume does not hide it (entrypoint links it) ---
USER dev
RUN set -eux; \
    ZSH=/opt/oh-my-zsh; \
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH"; \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH/custom/themes/powerlevel10k"; \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH/custom/plugins/zsh-autosuggestions"; \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH/custom/plugins/zsh-syntax-highlighting"; \
    find "$ZSH" -name .git -prune -exec rm -rf {} +

USER root
COPY .zshrc /etc/skel/.zshrc

# --- environment for every kind of shell (docker exec, ssh login, zsh, bash) ---
ENV TZ=${TZ} \
    CARGO_HOME=/home/dev/.cargo \
    GOPATH=/home/dev/go \
    UV_CACHE_DIR=/home/dev/.cache/uv \
    npm_config_store_dir=/home/dev/.pnpm-store \
    SHELL=/usr/bin/zsh \
    DISABLE_AUTOUPDATER=1 \
    PATH=/home/dev/.local/share/mise/shims:/home/dev/.cargo/bin:/home/dev/go/bin:/home/dev/.local/bin:/usr/local/cargo/bin:/usr/local/go/bin:${PATH}
RUN set -eux; \
    install -d /etc/devbox/env.d; \
    printf '%s\n' \
      "export TZ=${TZ}" \
      "export RUSTUP_HOME=${RUSTUP_HOME}" \
      "export CARGO_HOME=${CARGO_HOME}" \
      "export GOPATH=${GOPATH}" \
      "export UV_CACHE_DIR=${UV_CACHE_DIR}" \
      "export npm_config_store_dir=${npm_config_store_dir}" \
      "export DISABLE_AUTOUPDATER=1" \
      "export PATH=${PATH}" > /etc/devbox/env.d/10-base.sh; \
    echo 'for f in /etc/devbox/env.d/*.sh; do [ -r "$f" ] && . "$f"; done; unset f' > /etc/profile.d/00-devbox.sh; \
    cp /etc/profile.d/00-devbox.sh /etc/zsh/zshenv; \
    echo '. /etc/profile.d/00-devbox.sh' >> /etc/bash.bashrc

# --- sshd: key-only; host keys are generated at build time ---
RUN set -eux; \
    install -d /run/sshd; ssh-keygen -A; \
    grep -q '^Include /etc/ssh/sshd_config.d' /etc/ssh/sshd_config; \
    printf '%s\n' \
      'PasswordAuthentication no' \
      'KbdInteractiveAuthentication no' \
      'PubkeyAuthentication yes' \
      'PermitRootLogin no' \
      'UsePAM no' \
      'AllowUsers dev' > /etc/ssh/sshd_config.d/10-devbox.conf

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# devbox CLI inside the container: new / scratch / clean only (the rest needs docker on the host)
COPY bin/devbox /usr/local/bin/devbox
RUN chmod +x /usr/local/bin/devbox

WORKDIR /work
EXPOSE 22
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
