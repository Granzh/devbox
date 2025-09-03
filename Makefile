SHELL := /bin/bash
IMAGE ?= ghcr.io/<org>/<repo>:py-ts-flutter-2025.09
HOME_VOL ?= devbox-home

-include .devbox.env

.PHONY: dev dev-dood dind

dev:
	@docker run --rm -it \
		-e UID=$$(id -u) -e GID=$$(id -g) \
		-e SSH_AUTH_SOCK=/ssh-agent \
		-v $$SSH_AUTH_SOCK:/ssh-agent \
		-v $$(pwd):/work \
		-v $(HOME_VOL):/home/dev \
		--add-host host.docker.internal:host-gateway \
		--name devbox \
		$(IMAGE)

dev-dood:
	@docker run --rm -it \
		-e UID=$$(id -u) -e GID=$$(id -g) \
		-e SSH_AUTH_SOCK=/ssh-agent \
		-v $$SSH_AUTH_SOCK:/ssh-agent \
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
