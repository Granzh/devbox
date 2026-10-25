# Devbox

A Docker-based dev environment: zsh + oh-my-zsh + Powerlevel10k, C/C++ (clang-15, cppcheck, gdb, valgrind, cmake),
Python + uv, Node 20 + pnpm, Rust, Go, and everyday CLI tools. Flutter and Java are separate images.

The repo root holds the environment only. **Your projects live in `projects/`** (gitignored; each one is its own git repo).
`contests/` (gitignored) is used by `contest-gen.sh` / `run.sh`.

## Images

| Image | Contents |
|---|---|
| `devbox-base` | git, zsh stack, build-essential, cmake, gdb, valgrind, clang/clang-tidy/clang-format/lldb 15, cppcheck 2.13, Python 3 + uv, Node 20 + pnpm, Rust (stable, clippy, rustfmt, rust-analyzer), Go (latest stable), ripgrep, fd, fzf, jq, tmux, bat, just, direnv, htop, docker CLI |
| `devbox-flutter` | `devbox-base` + Flutter SDK (no Android SDK) |
| `devbox-java` | `devbox-base` + OpenJDK 17 |

The base is Ubuntu 24.04 (`UBUNTU_VERSION` build arg). clang-15 and cppcheck 2.13 come straight from its apt (Ubuntu 26.04 dropped clang-15), so there is no separate LLVM image.
Timezone is Europe/Moscow.

### Build

```bash
bin/devbox build          # docker buildx bake: base first, then flutter and java
bin/devbox build base     # just one target
make build                # same thing
```

Versions are pinned with `ARG`s at the top of `Dockerfile` / `docker/*.Dockerfile`
(`NODE_VERSION`, `UV_VERSION`, `JUST_VERSION`, `GO_VERSION`, `RUST_TOOLCHAIN`, `FLUTTER_REF`).

## The `devbox` CLI

`bin/devbox` is the single source of logic. On Windows use `.\devbox.ps1 <args>` (runs it through WSL, or Git Bash as fallback).
`make` targets and `dev.ps1` are thin wrappers.

| Command | What it does |
|---|---|
| `devbox shell [--image base\|flutter\|java] [--dood] [--here]` | Shell in the `devbox` container. If it is already running, `docker exec` into it; otherwise start it with `projects/` mounted at `/work`. `--here` mounts the current directory instead, `--dood` passes the host docker socket. |
| `devbox stop` | Stop the container. Needed to switch to a different `--image`. |
| `devbox new -n <name> [-g\|--git]` | Create `projects/<name>`. `-g` runs `git init -b main` and adds a minimal `.gitignore` and `README.md`. `devbox new <name>` also works. |
| `devbox scratch` | Create `projects/scratch/YYYY-MM-DD-<random>` and print its path. |
| `devbox clean [--days N] [-y]` | List and delete scratch dirs with no changes for N days (default 30), after confirmation. |
| `devbox prune [-y]` | Remove stopped containers, dangling images and build cache. **Never touches volumes.** |
| `devbox doctor` | Check docker, images, volumes, SSH keys and git config inside the container; show `docker system df`. |
| `devbox up` / `down` | Start / stop the persistent sshd container (compose). |

`make` cannot take `--flags`, so the convenience wrappers are `make project NAME=foo GIT=1`, `make scratch`,
`make clean DAYS=7`, `make doctor`, `make prune`, `make shell`. Prefer `devbox new -n foo -g`.

## SSH and git config

- The host `~/.ssh` is mounted **read-only** at `/tmp/host-ssh`. `entrypoint.sh` copies it to `/home/dev/.ssh` with proper
  ownership and modes (700 dir, 600 private keys, 644 `.pub` / `known_hosts`) and adds github.com / gitlab.com to
  `known_hosts` if missing. This works the same on Windows, where agent passthrough and direct mounts do not.
- If `SSH_AUTH_SOCK` is set to a socket (Linux, macOS, WSL), the agent is passed through as well.
- The host `~/.gitconfig` is mounted read-only at `/home/dev/.gitconfig`.
- Passphrase-protected keys still need a passphrase (or an agent) inside the container.

## Remote access from an IDE (sshd)

```bash
devbox up                 # docker compose up -d
ssh -p 2222 dev@127.0.0.1
```

sshd listens on **127.0.0.1:2222 only**, with **password login disabled**. `authorized_keys` is built from the `.pub` files in
your host `~/.ssh`. The service has a healthcheck (`docker ps` shows `healthy`). `.devcontainer/devcontainer.json` points
VS Code / JetBrains Dev Containers at the same compose service, with `projects/` as `/work`.

## Persistent caches

Named volumes, so rebuilding the image or container does not redownload anything:

| Volume | Mounted at |
|---|---|
| `devbox-home` | `/home/dev` |
| `devbox-cargo` | `/home/dev/.cargo` (registry, `cargo install` binaries) |
| `devbox-rustup` | `/usr/local/rustup` (toolchains) |
| `devbox-go` | `/home/dev/go` (GOPATH and module cache) |
| `devbox-uv-cache` | `/home/dev/.cache/uv` |
| `devbox-pnpm-store` | `/home/dev/.pnpm-store` |

A new Rust toolchain version baked into the image does not replace the one already in `devbox-rustup`; use
`rustup update`, or remove that volume yourself to start fresh. The older `devbox_cargo-cache` / `devbox_rustup-cache`
volumes are no longer used and were left in place.

## Competitive programming

```bash
./contest-gen.sh 1920 5     # contests/1920/1920A.cpp ... 1920E.cpp
cd contests/1920 && ./run.sh 1920A
```

`contests/` is gitignored. To work in it from the container, run `devbox shell --here` from the repo root.

## Docker in Docker

`devbox dind` starts a `docker:26-dind` daemon on 127.0.0.1:2375; inside the devbox use
`export DOCKER_HOST=tcp://host.docker.internal:2375`. For the host daemon use `devbox shell --dood`.
