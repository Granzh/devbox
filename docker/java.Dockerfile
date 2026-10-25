# devbox-java: devbox-base + OpenJDK 17
ARG BASE_IMAGE=devbox-base
FROM ${BASE_IMAGE}

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends openjdk-17-jdk; \
    ln -snf "/usr/lib/jvm/java-17-openjdk-$(dpkg --print-architecture)" /usr/lib/jvm/default-java-17

ENV JAVA_HOME=/usr/lib/jvm/default-java-17
RUN echo 'export JAVA_HOME=/usr/lib/jvm/default-java-17' > /etc/devbox/env.d/20-java.sh
