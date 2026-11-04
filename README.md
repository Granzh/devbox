# Devbox

A Docker-based dev environment: zsh + oh-my-zsh + Powerlevel10k, C/C++ (clang, cppcheck, gdb, valgrind, cmake),
Python + uv, Node 24 + pnpm, mise, Rust, Go, and everyday CLI tools. Flutter and Java are separate images.

The repo root holds the environment only. **Your projects live in `projects/`** (gitignored; each one is its own git repo).
`contests/` (gitignored) is used by `contest-gen.sh` / `run.sh`.

## Images

| Image | Contents |
|---|---|
| `devbox-base` | git, zsh stack, build-essential, cmake, gdb, valgrind, clang/clang-tidy/clang-format/lldb (Ubuntu's current version), cppcheck, Python 3 + uv, Node 24 + pnpm, mise, Claude Code, Rust (stable, clippy, rustfmt, rust-analyzer), Go (latest stable), ripgrep, fd, fzf, jq, tmux, bat, just, direnv, htop, docker CLI |
| `devbox-flutter` | `devbox-base` + Flutter SDK (no Android SDK) |
| `devbox-java` | `devbox-base` + OpenJDK 17 |

The base is Ubuntu 24.04. clang and cppcheck come straight from its apt, so there is no separate LLVM image.
Timezone is Europe/Moscow.

### Build

```bash
bin/devbox build          # docker buildx bake: base first, then flutter and java
bin/devbox build base     # just one target
make build                # same thing
```

Versions: the `FROM` lines in `Dockerfile` (Ubuntu, Node, uv, docker CLI) and `docker/npm/package.json` (Claude Code, pnpm)
are bumped by Dependabot PRs; the rest are `ARG`s (`JUST_VERSION`, `GO_VERSION`, `RUST_TOOLCHAIN`, `FLUTTER_REF`).
Nothing updates by itself: merge the PR, then `devbox build --pull`.

## Updating

| What | How |
|---|---|
| Tools you use every day: node, go, uv, pnpm, just, claude, rust | `devbox update` (`--check` only lists what is outdated). Installs into the volumes, so it survives container restarts and takes precedence over what the image was built with. |
| System packages: clang, cmake, gdb, apt stuff, the baked tool versions | `devbox build --pull` (rebuild the images). |
| Image pins (Ubuntu, Node, uv, claude-code, pnpm) | Dependabot PRs in `.github/dependabot.yml`; merge, then rebuild. |

`devbox update` works from the host and inside the container. The list of mise-managed tools is
`~/.config/mise/config.toml` (seeded from `docker/mise-global.toml` on first start; edit it to pin or drop a tool).
Projects can pin their own versions with `mise.toml`, `.tool-versions`, `rust-toolchain.toml` or `go.mod`.

## The `devbox` CLI

`bin/devbox` is the single source of logic. On Windows use `.\devbox.ps1 <args>` (runs it through WSL, or Git Bash as fallback).
`make` targets and `dev.ps1` are thin wrappers.

| Command | What it does |
|---|---|
| `devbox shell [--image base\|flutter\|java] [--dood] [--here]` | Shell in the `devbox` container. If it is already running, `docker exec` into it; otherwise start it with `projects/` mounted at `/work`. `--here` mounts the current directory instead, `--dood` passes the host docker socket. |
| `devbox claude [path\|project] [--isolate] [--image ...] [-- args]` | Start (or exec into) the container, `cd` into `/work/<project>` and run `claude`. See [Claude Code](#claude-code). |
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

## Claude Code

`claude` is installed in `devbox-base` (so in every derived image) with `npm install -g`, as root into
`/usr/local`. It is deliberately **not** under `/home/dev`: that is the `devbox-home` volume and would hide a rebuilt binary.
Auto-update is off for this baked copy (root-owned); the version comes from `docker/npm/package.json` (Dependabot).
To get a newer one without rebuilding, run `devbox update`: mise installs it into the home volume and its shim wins.

```bash
devbox claude                      # in projects/ (or the project you are cd'd into)
devbox claude myproj               # cd /work/myproj, run claude
devbox claude myproj --isolate     # container with ONLY projects/myproj mounted
devbox claude myproj -- --resume   # arguments after -- go to claude
```

- **State:** `~/.claude` and `~/.claude.json` are in the `devbox-home` volume, so login, settings, history and memory survive
  `docker compose down && up` and `devbox stop`. Only `docker volume rm devbox-home` removes them.
- **Login:** run `devbox claude`, pick a login method, open the printed URL in your host browser and paste the code back.
- **API key:** if `ANTHROPIC_API_KEY` is set in the host environment it is forwarded by name (`-e ANTHROPIC_API_KEY`); it is never written
  to an image, compose file or disk. Claude asks once whether to use it. On Windows `devbox.ps1` passes it through `WSLENV`.
- **Global instructions:** host `~/.claude/CLAUDE.md`, if present, is mounted read-only and linked to `/home/dev/.claude/CLAUDE.md`.
  Absent is fine. (Project-level `CLAUDE.md` files are just part of the project.)
- `devbox doctor` checks the binary, its version and that `~/.claude` is writable.

### The container is only a partial sandbox

- `/work` is `projects/`, **all of it, writable**. Claude can modify or delete every project, not just the one you named.
- The host `~/.ssh` keys are **copied into `/home/dev/.ssh`** (in the shared `devbox-home` volume), plus the SSH agent socket when
  available, so anything running as `dev` can push to your git remotes. `dev` also has passwordless sudo.
- Credentials for Claude itself live in the same home volume.

So treat `--dangerously-skip-permissions` with care, and only use it through
`devbox claude <project> --isolate`: that starts a separate container (`devbox-claude-<project>`) where just that project is
mounted, so other projects are unreachable. It does not remove the SSH keys or the shared home volume; `--dood` is never
applied to it. For stronger isolation use a throwaway project and a deploy key.

## Competitive programming

```bash
./contest-gen.sh 1920 5     # contests/1920/1920A.cpp ... 1920E.cpp
cd contests/1920 && ./run.sh 1920A
```

`contests/` is gitignored. To work in it from the container, run `devbox shell --here` from the repo root.

## Docker in Docker

`devbox dind` starts a `docker:26-dind` daemon on 127.0.0.1:2375; inside the devbox use
`export DOCKER_HOST=tcp://host.docker.internal:2375`. For the host daemon use `devbox shell --dood`.

## Working from Zed (one window, terminal inside the container)

1. On the host: `.\devbox.ps1 up` (starts the sshd container on `127.0.0.1:2222`, key login only).
2. Zed: `Cmd/Ctrl+Shift+P` -> "projects: open remote" -> add the connection, or put this in `settings.json`:
   ```json
   {
     "ssh_connections": [
       {
         "host": "127.0.0.1",
         "port": 2222,
         "username": "dev",
         "projects": [{ "paths": ["/work"] }]
       }
     ]
   }
   ```
3. The integrated terminal now runs inside the container, so `claude`, `cargo`, `go`, `uv` and the container-side
   `devbox` commands are all available without a separate window.

## `devbox` inside the container

Only `new`, `scratch` and `clean` work in the container (they just create/remove folders under `/work`, which is
`projects/` on the host). Everything else needs Docker on the host and prints a message saying so.

```bash
devbox new -n myproj -g   # /work/myproj with git init
devbox scratch            # /work/scratch/YYYY-MM-DD-xxxxxx
devbox clean --days 30    # remove old scratch dirs (asks first)
```

After changing `bin/devbox`, rebuild so the container gets the new copy: `.\devbox.ps1 build`.

## React / Vue / Tailwind

```bash
devbox new -n shop -t react -g    # or: -t vue.  Vite + TypeScript + Tailwind v4 (+ git init with -g)
cd projects/shop && pnpm dev      # inside the container; open http://localhost:5173 on the host
```

- Ports `3000-3010`, `4173`, `5173` and `8080` are published on `127.0.0.1` by both `devbox shell` and the compose service.
  Dev servers must listen on `0.0.0.0` (the templates set `server.host: true`; for others use `--host`).
  Override the list with `DEVBOX_PORTS="-p 127.0.0.1:9000:9000"` (empty value = publish nothing).
  The `devbox` and `devbox-sshd` containers cannot run at the same time with the same ports published.
- HMR on Windows bind mounts: file events do not arrive, so devbox sets `CHOKIDAR_USEPOLLING=1` there and the templates turn on
  Vite's polling when it is set. Keeping `projects/` inside WSL2 (`~/projects`, with `DEVBOX_PROJECTS` pointing there) is faster and
  needs no polling; `node_modules` on a Windows bind mount is slow for installs and builds.
- Zed starts TypeScript, Vue (Volar) and Tailwind language servers on the remote side by itself; they are not in the image.
- Next.js and Nuxt are not templates: use their own CLIs (`pnpm create next-app`, `pnpm dlx nuxi init`) inside the container.
