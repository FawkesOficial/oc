# opencode sandbox setup

Rootless Podman containers for opencode — one per project, isolated to its
directory, stops automatically when you exit.

---

## Directory layout

Copy these files to your home directory (preserving the structure):

```
$HOME/programming/oc/
    Containerfile          ← image definition
~/.config/opencode/
    opencode.json          ← global agent + permission config
~/.local/bin/
    oc                     ← shell utility (chmod +x)
```

---

## First-time setup

### 1. API keys

Add to your `~/.bashrc` or `~/.zshrc`:

```sh
export GROQ_API_KEY="gsk_..."                  # required
export OPENROUTER_API_KEY="sk-or-..."          # for qwen3-coder:free fallback
export GOOGLE_API_KEY="AIza..."                # for plan agent (Gemini 2.5 Pro)

export PATH="$HOME/.local/bin:$PATH"
```

### 2. Build the image

```sh
podman build \
  --build-arg HOST_UID=$(id -u) \
  --build-arg OPENCODE_VERSION=1.1.1 \
  -t opencode-sandbox:latest \
  $HOME/programming/oc/
```

### 3. Make `oc` executable

```sh
chmod +x ~/.local/bin/oc
```

### 4. Launch

```sh
cd ~/projects/myproject
oc                         # uses current directory

oc ~/projects/myproject    # explicit path
oc ~/work/otherproject     # switch to another project
```

---

## Daily usage

| Command                | What it does                                     |
|------------------------|--------------------------------------------------|
| `oc`                   | Launch opencode in sandbox for current directory |
| `oc ~/path/to/project` | Launch for a specific project                    |
| `oc list`              | Show all sandboxes and their status              |
| `oc stop`              | Stop the sandbox for current directory           |
| `oc stop ~/path`       | Stop a specific sandbox                          |
| `oc clean`             | Remove all stopped sandbox containers            |
| `oc logs`              | Tail logs for current directory's sandbox        |

Containers stop automatically when you exit opencode. `oc` into the same
project again and it creates a fresh container from the current image.

---

## Agents (Tab to switch between primary agents)

| Agent     | Model                        | When to use                                      |
|-----------|------------------------------|--------------------------------------------------|
| `build`   | Groq Llama 3.3 70B           | Default. All coding, edits, bug fixes, tests     |
| `plan`    | Gemini 2.5 Pro               | Architecture, task breakdown, hard reasoning     |
| `@explore`| Gemini 2.5 Flash             | Read-only codebase exploration (auto or mention) |
| `@reason` | Groq DeepSeek R1 70B         | Complex logic, tricky bugs, refactoring          |
| `@coder`  | Qwen3-Coder:free (262K ctx)  | Very long file context tasks                     |

`reason` and `coder` are hidden from autocomplete — call them with `@mention`.

---

## Per-project config

Drop an `opencode.json` in any project root to extend the global config.
The container already limits edits to `/workspace`, so use these to loosen
specific bash commands for that project's toolchain:

```jsonc
// ~/projects/myproject/opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "bash": {
      "npm run *":   "allow",
      "npm test":    "allow",
      "npm install": "ask",
      "npx *":       "ask"
    }
  }
}
```

---

## Updating opencode

1. Check the [opencode releases](https://github.com/anomalyco/opencode/releases)
2. Rebuild the image with a bumped version:
   ```sh
   podman build \
     --build-arg HOST_UID=$(id -u) \
     --build-arg OPENCODE_VERSION=1.2.0 \
     -t opencode-sandbox:latest \
     $HOME/programming/oc/
   ```
3. Next time you `oc` into a project, a fresh container uses the new image.
   Running containers are unaffected until they exit naturally.

To also pull fresh OS packages (security updates):
```sh
podman build --no-cache \
  --build-arg HOST_UID=$(id -u) \
  --build-arg OPENCODE_VERSION=1.2.0 \
  -t opencode-sandbox:latest \
  $HOME/programming/oc/
```

---

## What the container can and cannot do

**Can:**
- Read and edit files in `/workspace` (your project directory)
- Run git commands (allowlisted)
- Make HTTPS calls to Groq, OpenRouter, Google AI APIs
- Run project build/test commands you've allowlisted per-project

**Cannot:**
- See your home directory, other projects, SSH keys, `.env` files outside `/workspace`
- Auto-push to git
- Run `rm`, `sudo`, or any command not in the allowlist without prompting you
- Write to the opencode config (mounted read-only)
- Touch any path outside `/workspace`
