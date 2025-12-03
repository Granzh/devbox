FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive

# Базовые утилиты
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      curl wget git unzip zip ca-certificates gnupg lsb-release \
      sudo bash-completion openssh-client \
      build-essential pkg-config \
      python3 python3-venv python3-pip python3-dev \
      openjdk-17-jdk \
      gosu zsh \
    ; \
    rm -rf /var/lib/apt/lists/*

# Пользователь dev (UID/GID подгоняем в entrypoint)
RUN groupadd -g 1000 dev && useradd -m -s /bin/bash -u 1000 -g 1000 dev \
 && usermod -aG sudo dev && echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER dev
WORKDIR /work

# Node.js + pnpm (без corepack)
ARG NODE_VERSION=20.18.0
RUN mkdir -p $HOME/.local && cd $HOME/.local && \
    curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz -o node.tar.xz && \
    tar -xJf node.tar.xz && rm node.tar.xz && mv node-v${NODE_VERSION}-linux-x64 node
ENV PATH="/home/dev/.local/node/bin:/home/dev/.local/bin:${PATH}"
RUN npm i -g pnpm@9 && pnpm -v && pnpm config set store-dir /home/dev/.pnpm-store

# uv (Python tooling)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/home/dev/.local/bin:${PATH}"

# Flutter (без Android SDK)
ENV FLUTTER_HOME="/home/dev/.flutter"
RUN git clone --depth 1 --branch stable https://github.com/flutter/flutter.git ${FLUTTER_HOME}
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

# zsh + oh-my-zsh + powerlevel10k + плагины
WORKDIR /home/dev
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
# если у тебя в корне лежит .zshrc — скопируй:
# COPY --chown=dev:dev .zshrc /home/dev/.zshrc

ENV SHELL=/usr/bin/zsh
CMD ["zsh"]

# --- C/C++ toolchain, LLVM 15, Valgrind, CMake, cppcheck 2.7, editors ---
USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      build-essential gdb pkg-config \
      curl wget ca-certificates gnupg lsb-release software-properties-common \
      git python3 python3-pip \
      cmake \
      valgrind \
      vim neovim \
      libboost-all-dev \
    ; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    codename="$(. /etc/os-release && echo $VERSION_CODENAME)"; \
    install -m 0755 -d /usr/share/keyrings; \
    wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor >/usr/share/keyrings/llvm.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/llvm.gpg] http://apt.llvm.org/${codename}/ llvm-toolchain-${codename}-15 main" \
      >/etc/apt/sources.list.d/llvm15.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      clang-15 clang-tools-15 clang-tidy-15 clang-format-15 lldb-15 lld-15 \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    update-alternatives --install /usr/bin/clang clang /usr/bin/clang-15 150; \
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-15 150; \
    update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-15 150; \
    update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-15 150

ARG CPPCHECK_VERSION=2.7
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends git g++ libpcre3-dev; \
    rm -rf /var/lib/apt/lists/*; \
    git clone --branch ${CPPCHECK_VERSION} --depth 1 https://github.com/danmar/cppcheck.git /tmp/cppcheck; \
    cmake -S /tmp/cppcheck -B /tmp/cppcheck/build -DCMAKE_BUILD_TYPE=Release -DHAVE_RULES=ON; \
    cmake --build /tmp/cppcheck/build -j"$(nproc)"; \
    cmake --install /tmp/cppcheck/build; \
    rm -rf /tmp/cppcheck

SHELL ["/bin/sh", "-c"]

# entrypoint для подстройки UID/GID и входа как dev
WORKDIR /work
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
