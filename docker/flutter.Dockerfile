# devbox-flutter: devbox-base + Flutter SDK (no Android SDK)
ARG BASE_IMAGE=devbox-base
FROM ${BASE_IMAGE}

# a branch (stable) or a tag (e.g. 3.35.0)
ARG FLUTTER_REF=stable

RUN install -d -o dev -g dev /opt/flutter
USER dev
RUN set -eux; \
    git clone --depth 1 --branch "${FLUTTER_REF}" https://github.com/flutter/flutter.git /opt/flutter; \
    /opt/flutter/bin/flutter config --no-analytics --no-cli-animations; \
    /opt/flutter/bin/flutter --version

USER root
ENV FLUTTER_HOME=/opt/flutter \
    PATH=/opt/flutter/bin:${PATH}
RUN printf '%s\n' 'export FLUTTER_HOME=/opt/flutter' 'export PATH=/opt/flutter/bin:$PATH' > /etc/devbox/env.d/20-flutter.sh
