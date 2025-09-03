FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive

# Базовые инструменты
RUN apt-get update && apt-get install -y \
    curl git unzip zip ca-certificates build-essential pkg-config \
    openssh-client sudo bash-completion wget gnupg \
    python3 python3-venv python3-pip python3-dev \
    openjdk-17-jdk \
    gosu zsh fonts-powerline \
  && rm -rf /var/lib/apt/lists/*

# Пользователь "dev" (UID/GID подстроим в entrypoint)
RUN groupadd -g 1000 dev && useradd -m -s /bin/bash -u 1000 -g 1000 dev \
 && usermod -aG sudo dev && echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER dev
WORKDIR /work

# -------- Node.js + pnpm (corepack) --------
ARG NODE_VERSION=20.18.0
# 1) распаковываем Node в $HOME/.local/node
RUN mkdir -p $HOME/.local && cd $HOME/.local && \
    curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz -o node.tar.xz && \
    tar -xJf node.tar.xz && rm node.tar.xz && \
    mv node-v${NODE_VERSION}-linux-x64 node
# 2) PATH виден в следующих слоях
ENV PATH="/home/dev/.local/node/bin:/home/dev/.local/bin:${PATH}"
RUN npm i -g pnpm@9 && pnpm -v \
 && pnpm config set store-dir /home/dev/.pnpm-store

# -------- uv (Python tooling) --------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/home/dev/.local/bin:${PATH}"

# -------- Flutter (без Android SDK) --------
ENV FLUTTER_HOME="/home/dev/.flutter"
RUN git clone --depth 1 --branch stable https://github.com/flutter/flutter.git ${FLUTTER_HOME}
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

# -------- Zsh + Oh My Zsh + Powerlevel10k + плагины --------
WORKDIR /home/dev
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Кладём .zshrc
COPY --chown=dev:dev .zshrc /home/dev/.zshrc


# По умолчанию — zsh
ENV SHELL=/usr/bin/zsh
CMD ["zsh"]

# -------- Entrypoint (root нужен для usermod/chown) --------
USER root
WORKDIR /work
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
