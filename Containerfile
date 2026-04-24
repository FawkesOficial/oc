# $HOME/programming/oc/Containerfile
#
# Minimal Debian image for running opencode in a rootless Podman sandbox.
# Your code never lives here — it's always bind-mounted from the host.
# Rebuild deliberately when you want a new opencode version or OS updates.
#
# Build:
#   podman build \
#     --build-arg HOST_UID=$(id -u) \
#     --build-arg OPENCODE_VERSION=1.1.1 \
#     -t opencode-sandbox:latest \
#     $HOME/programming/oc/
#
# To update opencode: bump OPENCODE_VERSION and rebuild.
# To update base OS packages: rebuild without cache: add --no-cache to the command above.
# Running containers are unaffected until they naturally exit and are recreated by `oc`.

FROM debian:bookworm-slim

ARG HOST_UID=1000
ARG OPENCODE_VERSION=1.14.22

# Minimal runtime dependencies only.
# git: needed by opencode for context and by many project workflows.
# ca-certificates: TLS for outbound API calls.
# curl: opencode install script + occasional project use.
# No compilers, no package managers beyond what projects mount in from the host.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    neovim \
    && rm -rf /var/lib/apt/lists/*

# Install pinned opencode version.
# Pinned so that rebuilding the image is a deliberate, reviewable act.
# RUN curl -fsSL https://opencode.ai/install | bash -s -- --version ${OPENCODE_VERSION} \
#     && opencode --version
RUN curl -fsSL https://opencode.ai/install | bash -s -- --version ${OPENCODE_VERSION} \
    && mv /root/.opencode/bin/opencode /usr/local/bin/opencode \
    && opencode --version

# Create a non-root user whose UID matches the host user.
# This prevents volume mount permission mismatches without needing --userns tricks.
RUN useradd -m -u ${HOST_UID} -s /bin/bash dev

# Ensure the dev user has a home directory for opencode internal state if needed
RUN mkdir -p /home/dev/.opencode && chown -R dev:dev /home/dev/.opencode

USER dev

RUN mkdir -p ~/.config/nvim && echo 'colorscheme default' > ~/.config/nvim/init.vim

WORKDIR /workspace

# Config dir is set via env so opencode looks at the read-only host config mount.
# API keys are injected at runtime as env vars — never baked into the image.
ENV OPENCODE_CONFIG_DIR=/config
# Ensure /usr/local/bin is in path (it usually is by default in Debian)
ENV PATH="/usr/local/bin:${PATH}"
ENV EDITOR=nvim
