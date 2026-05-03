# opencode sandbox setup

Rootless Podman containers for opencode - one per project, isolated to its
directory. Containers persist between sessions (runtime installs survive) and
stop automatically when you exit opencode.

---

## Repo contents

| File            | Purpose                 |
| --------------- | ----------------------- |
| `Containerfile` | Podman image definition |
| `oc`            | Sandbox launcher script |

---

## Setup

### 1. Install the launcher

```sh
cp oc ~/.local/bin/oc
chmod +x ~/.local/bin/oc
```

### 2. Build the image

Run from the repo root:

```sh
podman build \
  --build-arg HOST_UID=$(id -u) \
  --build-arg OPENCODE_VERSION=1.14.22 \
  -t opencode-sandbox:latest \
  .
```

### 3. Launch

```sh
cd ~/projects/myproject
oc                         # uses current directory

oc ~/projects/myproject    # explicit path
oc ~/work/otherproject     # switch to another project
```

---

## Daily usage

| Command                     | What it does                                     |
| --------------------------- | ------------------------------------------------ |
| `oc`                        | Launch opencode in sandbox for current directory |
| `oc ~/path/to/project`      | Launch for a specific project                    |
| `ENABLE_WEB=true oc`        | Same, but with webapp on port 4096 (see below)   |
| `oc attach|a [PROJECT_DIR]` | Open a bash shell in a running sandbox           |
| `oc list`                   | Show all managed containers and their status     |
| `oc stop [PROJECT_DIR]`     | Stop a running container                         |
| `oc recreate [PROJECT_DIR]` | Rebuild a container from the current image       |
| `oc clean`                  | Remove all stopped managed containers            |
| `oc logs [PROJECT_DIR]`     | Tail container logs                              |
| `oc help`                   | Show usage message                               |

Containers persist between sessions - packages installed at runtime
(`sudo apt-get install`) survive. The container stops automatically when
opencode exits and restarts on next launch. Use `oc recreate` to rebuild
a container from a fresh image.

---

## What's inside the container

The sandbox is based on **Debian Bookworm** with these tools pre-installed:

| Category     | Packages                                                  |
| ------------ | --------------------------------------------------------- |
| Version ctrl | `git`, `gh` (GitHub CLI, latest from official repo)       |
| Editors      | `neovim` (default `$EDITOR`)                              |
| Python       | `python3`, `python3-pip`, `python3-venv`                  |
| NodeJS       | `nodejs`, `npm`, `npx`, `bun`                  |
| Utilities    | `curl`, `jq`, `less`, `procps`, `findutils`, `util-linux`, `uzip` |
| Runtime      | `sudo` (passwordless for `dev` user)                      |

The `dev` user is created with the same UID as your host user, so volume
mount permissions match seamlessly.

---

## Container architecture

Each sandbox is a persistent Podman container with `sleep infinity` as PID 1.
Opencode runs via `podman exec`, so the container stays alive between sessions.

**Volume mounts:**

| Host path                  | Container path                     | Mode | Purpose                     |
| -------------------------- | ---------------------------------- | ---- | --------------------------- |
| `<project-dir>`            | `/workspace/<project-dir>`         | rw   | Project files               |
| `~/.config/opencode`       | `/home/dev/.config/opencode`       | rw   | Opencode configs            |
| `~/.local/share/opencode/` | `/home/dev/.local/share/opencode/` | rw   | Opencode session data       |
| `~/.local/state/opencode/` | `/home/dev/.local/state/opencode/` | rw   | Opencode state              |
| `~/.local/share/opentui/`  | `/home/dev/.local/share/opentui/`  | rw   | OpenTUI state               |
| `~/.config/git/`           | `/home/dev/.config/git/`           | ro   | Git config passthrough      |
| `~/.config/gh/`            | `/home/dev/.config/gh/`            | ro   | GitHub CLI auth passthrough |

> [!NOTE]
> You might want to keep `~/.config/opencode` mount as read-only (`ro`). Keep it read-write if you want your agent to be able to modify it's own config. It is only recommended to do this if you version control your configs.

**Environment:**

- `GH_TOKEN` - GitHub CLI auth passthrough (optional, falls back to `gh auth login`)
- `EDITOR=nvim` - default editor inside the sandbox
- `ENABLE_WEB` - set to `true` to expose port `4096` for webapp access (default: `false`, TUI-only)

> [!WARNING]
> **`ENABLE_WEB=true` breaks concurrent sandboxes.** Port 4096 can only be bound by one container at a time, so launching a second project will fail with a port-in-use error. Keep it `false` (the default) unless you specifically need the webapp - and only ever use it for one project at a time.

---

## Updating opencode

1. Check the [opencode releases](https://github.com/anomalyco/opencode/releases)
2. Bump `OPENCODE_VERSION` in `Containerfile`
3. Rebuild the image (from repo root):
   
   ```sh
   podman build \
     --build-arg HOST_UID=$(id -u) \
     --build-arg OPENCODE_VERSION=1.15.0 \
     -t opencode-sandbox:latest \
     .
   ```
4. Recreate existing sandboxes:
   
   ```sh
   oc recreate ~/projects/myproject
   ```
   
   Or let them recreate naturally: running containers are unaffected until
   they exit, and the next `oc` launch will use the new image.

To also pull fresh OS packages (security updates):

```sh
podman build --no-cache \
  --build-arg HOST_UID=$(id -u) \
  --build-arg OPENCODE_VERSION=1.15.0 \
  -t opencode-sandbox:latest \
  .
```

---

## What the container can and cannot do

**Can:**

- Read and edit files in `/workspace` (your project directory)
- Run git and GitHub CLI commands (config/auth passed through from host)
- Make HTTPS calls to configured AI providers
- Install additional packages at runtime via `sudo apt-get install`
- Run any build/test commands (permission set to `allow` by default)

**Cannot:**

- See your home directory, other projects, SSH keys, `.env` files outside `/workspace`
- Touch any path outside `/workspace` (except its own state dirs)
