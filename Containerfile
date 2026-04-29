# Containerfile
#
# Minimal Debian image for running opencode in a rootless Podman sandbox.
# Your code never lives here - it's always bind-mounted from the host.
# Rebuild deliberately when you want a new opencode version or OS updates.
#
# The dev user can install additional packages at runtime via:
#   sudo apt-get update && sudo apt-get install <package>
#
# Build (run from the repo root):
#   podman build \
#     --build-arg HOST_UID=$(id -u) \
#     --build-arg OPENCODE_VERSION=1.14.22 \
#     -t opencode-sandbox:latest \
#     .
#
# To update opencode: bump OPENCODE_VERSION and rebuild.
# To update base OS packages: rebuild without cache: add --no-cache to the command above.
# Running containers are unaffected until they naturally exit and are recreated by `oc`.

FROM debian:bookworm-slim

ARG HOST_UID=1000
ARG OPENCODE_VERSION=1.14.22

# Base tools + apt cache kept so dev user can install more packages at runtime.
# procps: ps, top, pgrep, pkill
# findutils: find, xargs
# util-linux: lsblk, mount, renice, etc.
# less, jq: common CLI utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    openssh-client \
    neovim \
    python3 \
    python3-pip \
    python3-venv \
    sudo \
    procps \
    findutils \
    util-linux \
    less \
    jq

# Install gh CLI from official GitHub repo (bookworm's version is stale).
RUN mkdir -p -m 755 /etc/apt/keyrings && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
        tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y --no-install-recommends gh

# Install pinned opencode version.
# Pinned so that rebuilding the image is a deliberate, reviewable act.
# RUN curl -fsSL https://opencode.ai/install | bash -s -- --version ${OPENCODE_VERSION} \
#     && opencode --version
RUN curl -fsSL https://opencode.ai/install | bash -s -- --version ${OPENCODE_VERSION} \
    && mv /root/.opencode/bin/opencode /usr/local/bin/opencode \
    && opencode --version

# Create a non-root user whose UID matches the host user.
# This prevents volume mount permission mismatches without needing --userns tricks.
RUN useradd -m -u ${HOST_UID} -s /bin/bash dev && \
    # Allow dev to install packages at runtime without a password.
    echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev

# Ensure the dev user has a home directory for opencode internal state if needed
# and a placeholder for gh config (populated via bind-mount at runtime).
RUN mkdir -p /home/dev/.config/gh \
             /home/dev/.config/nvim \
             /home/dev/.config/opencode \
             /home/dev/.local/state/opencode \
             /home/dev/.local/share/opencode \
             /home/dev/.local/share/opentui \
             /home/dev/.ssh \
    && chown -R dev:dev /home/dev/ \
    && echo 'colorscheme default' > /home/dev/.config/nvim/init.vim

USER dev

WORKDIR /workspace

# API keys are injected at runtime as env vars - never baked into the image.
# Ensure /usr/local/bin is in path (it usually is by default in Debian)
ENV PATH="/usr/local/bin:${PATH}"
ENV EDITOR=nvim
