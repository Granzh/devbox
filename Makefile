SHELL := /bin/bash
IMAGE ?= devbox:latest
HOME_VOL ?= devbox-home

SSH_AGENT_FLAGS :=
ifneq ($(SSH_AUTH_SOCK),)
  SSH_AGENT_FLAGS := -e SSH_AUTH_SOCK=/ssh-agent -v $(SSH_AUTH_SOCK):/ssh-agent
endif

# Git config прокидывание (для коммитов и пушей из контейнера)
GIT_CONFIG_FLAGS :=
ifneq ($(wildcard $(HOME)/.gitconfig),)
  GIT_CONFIG_FLAGS := -v $(HOME)/.gitconfig:/home/dev/.gitconfig:ro
endif

.PHONY: dev dev-dood dind

dev:
	@docker run --rm -it \
		-e UID=$$(id -u) -e GID=$$(id -g) \
		$(SSH_AGENT_FLAGS) \
		$(GIT_CONFIG_FLAGS) \
		-v $$(pwd):/work \
		-v $(HOME_VOL):/home/dev \
		--add-host host.docker.internal:host-gateway \
		--name devbox \
		$(IMAGE)

dev-dood:
	@docker run --rm -it \
		-e UID=$$(id -u) -e GID=$$(id -g) \
		$(SSH_AGENT_FLAGS) \
		$(GIT_CONFIG_FLAGS) \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $$(pwd):/work \
		-v $(HOME_VOL):/home/dev \
		--add-host host.docker.internal:host-gateway \
		--name devbox \
		$(IMAGE)

dind:
	@docker rm -f devbox-dind >/dev/null 2>&1 || true
	@docker run -d --privileged --name devbox-dind \
		-p 2375:2375 -e DOCKER_TLS_CERTDIR= \
		-v devbox-dind-storage:/var/lib/docker docker:26-dind
	@echo "DinD up. Use inside dev container: export DOCKER_HOST=tcp://host.docker.internal:2375"

