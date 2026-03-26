# =============================================================================
# Dev Environment: Claude Code + code-server (VS Code) + Go / .NET 10 / Python
# Based on Anthropic's official devcontainer reference:
#   https://github.com/anthropics/claude-code/tree/main/.devcontainer
# =============================================================================
FROM node:22-bookworm

ARG GIT_USER="Michael Robertson"
ARG GIT_EMAIL="michael.robertson1991@gmail.com"
ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest

# ---------------------------------------------------------------------------
# System packages
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # --- Anthropic reference baseline ---
    less git procps sudo fzf zsh man-db unzip gnupg2 gh \
    iptables ipset iproute2 dnsutils aggregate jq nano vim \
    # --- Build essentials for native extensions ---
    build-essential ca-certificates curl wget \
    # --- Python ---
    python3 python3-pip python3-venv python3-dev \
    # --- Misc dev tools ---
    ripgrep fd-find bat httpie tmux zip  \
    # --- AWS ---
    awscli \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Convenience symlinks for tools with odd Debian names
RUN ln -sf /usr/bin/batcat /usr/local/bin/bat \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd

ENV PATH="/home/node/.local/bin:/home/node/bin:${PATH}"

# ---------------------------------------------------------------------------
# Git Credential Manager
# ---------------------------------------------------------------------------
ARG GCM_VERSION=2.7.3
RUN wget -q "https://github.com/git-ecosystem/git-credential-manager/releases/download/v${GCM_VERSION}/gcm-linux-x64-${GCM_VERSION}.deb" \
    && dpkg -i "gcm-linux-x64-${GCM_VERSION}.deb" \
    && rm "gcm-linux-x64-${GCM_VERSION}.deb"

RUN git-credential-manager configure \
    && git config --global credential.credentialStore plaintext

# ---------------------------------------------------------------------------
# Lazy Git
# ---------------------------------------------------------------------------
ARG LAZYGIT_VERSION=0.60.0
RUN curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" && \
    tar xf lazygit.tar.gz lazygit && \
    sudo install lazygit -D -t /usr/local/bin/
# ---------------------------------------------------------------------------
# Go
# ---------------------------------------------------------------------------
ARG GO_VERSION=1.26.1
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:/home/node/go/bin:${PATH}" \
    GOPATH="/home/node/go"

# ---------------------------------------------------------------------------
# Go Task (Taskfile)
# ---------------------------------------------------------------------------
RUN curl -1sLf 'https://dl.cloudsmith.io/public/task/task/setup.deb.sh' | sudo -E bash && \
    apt-get install task

# ---------------------------------------------------------------------------
# .NET 10 SDK (via install script — supports preview/RC channels cleanly)
# ---------------------------------------------------------------------------
RUN curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
    && chmod +x /tmp/dotnet-install.sh \
    && /tmp/dotnet-install.sh --channel 10.0 --install-dir /usr/share/dotnet \
    && rm /tmp/dotnet-install.sh \
    && ln -s /usr/share/dotnet/dotnet /usr/local/bin/dotnet
ENV DOTNET_ROOT=/usr/share/dotnet \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1

# ---------------------------------------------------------------------------
# code-server  (VS Code in browser, port 8080)
# ---------------------------------------------------------------------------
RUN curl -fsSL https://code-server.dev/install.sh | sh

# ---------------------------------------------------------------------------
# npm global prefix for non-root installs
# ---------------------------------------------------------------------------
RUN mkdir -p /usr/local/share/npm-global \
    && chown -R node:node /usr/local/share/npm-global

ARG USERNAME=node

# ---------------------------------------------------------------------------
# Persist bash / zsh history across rebuilds  (Anthropic pattern)
# ---------------------------------------------------------------------------
RUN mkdir /commandhistory \
    && touch /commandhistory/.bash_history \
    && touch /commandhistory/.zsh_history \
    && chown -R $USERNAME /commandhistory

ENV DEVCONTAINER=true

# ---------------------------------------------------------------------------
# Workspace and Claude config dirs
# ---------------------------------------------------------------------------
RUN mkdir -p /workspace /home/node/.claude /home/node/.local/share/code-server /home/node/.nuget \
    && chown -R node:node /workspace /home/node/.claude /home/node/.local /home/node/.nuget

WORKDIR /workspace

# ---------------------------------------------------------------------------
# git-delta for better diffs
# ---------------------------------------------------------------------------
ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) \
    && wget -q "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" \
    && dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" \
    && rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# ---------------------------------------------------------------------------
# Switch to non-root user
# ---------------------------------------------------------------------------
USER node

ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH="${NPM_CONFIG_PREFIX}/bin:${PATH}"
ENV SHELL=/bin/zsh
ENV EDITOR=vim
ENV VISUAL=vim
ENV TERM=xterm-256color
ENV COLORTERM=truecolor

# ---------------------------------------------------------------------------
# Git config node user
# ---------------------------------------------------------------------------
RUN git-credential-manager configure \
    && git config --global credential.credentialStore plaintext \
    && git config --global credential.guiPrompt false \
    && git config --global user.email ${GIT_EMAIL} \
    && git config --global user.name ${GIT_USER}

# ---------------------------------------------------------------------------
# Zsh + Powerlevel10k  (Anthropic pattern)
# ---------------------------------------------------------------------------
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
    -p git \
    -p fzf \
    -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
    -a "source /usr/share/doc/fzf/examples/completion.zsh" \
    -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.zsh_history" \
    -x

# ---------------------------------------------------------------------------
# MVN Settings
# ---------------------------------------------------------------------------
RUN mkdir -p /home/node/.m2
## If need private mvn repo
## COPY mvn-settings.xml /home/node/.m2/settings.xml

# ---------------------------------------------------------------------------
# SDKMAN + Java 11 (Amazon Corretto) + Maven
# ---------------------------------------------------------------------------
RUN curl -s "https://get.sdkman.io" | bash \
    && bash -c "source /home/node/.sdkman/bin/sdkman-init.sh \
        && sdk install java 11.0.30-amzn \
        && sdk install maven"

# Wire SDKMAN into zsh and bash
RUN echo 'export SDKMAN_DIR="/home/node/.sdkman"' >> /home/node/.zshrc \
    && echo '[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"' >> /home/node/.zshrc \
    && echo 'export SDKMAN_DIR="/home/node/.sdkman"' >> /home/node/.bashrc \
    && echo '[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"' >> /home/node/.bashrc

# ---------------------------------------------------------------------------
# Custom shell aliases
# ---------------------------------------------------------------------------
COPY .aliases /home/node/.aliases
RUN echo '[ -f ~/.aliases ] && source ~/.aliases' >> /home/node/.zshrc \
    && echo '[ -f ~/.aliases ] && source ~/.aliases' >> /home/node/.bashrc

ENV SDKMAN_DIR=/home/node/.sdkman
ENV JAVA_HOME=/home/node/.sdkman/candidates/java/current
ENV PATH="/home/node/.sdkman/candidates/java/current/bin:/home/node/.sdkman/candidates/maven/current/bin:${PATH}"

# ---------------------------------------------------------------------------
# Claude Code
# ---------------------------------------------------------------------------
# RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}
RUN curl -fsSL https://claude.ai/install.sh | bash

# ---------------------------------------------------------------------------
# Firewall script  (copied separately, requires root for iptables)
# ---------------------------------------------------------------------------
# COPY init-firewall.sh /usr/local/bin/
USER root
# RUN chmod +x /usr/local/bin/init-firewall.sh \
#     && echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall \
#     && chmod 0440 /etc/sudoers.d/node-firewall

USER node