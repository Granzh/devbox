# Thin wrappers around bin/devbox (all logic lives there).
# Primary interface:  bin/devbox new -n foo -g   (make cannot take --flags, hence NAME=/GIT=)
SHELL := /bin/bash
DEVBOX := bin/devbox

.PHONY: build dev shell dev-dood dind up down stop project scratch clean prune doctor

build:
	@$(DEVBOX) build

dev shell:
	@$(DEVBOX) shell

dev-dood:
	@$(DEVBOX) shell --dood

dind:
	@$(DEVBOX) dind

up:
	@$(DEVBOX) up

down:
	@$(DEVBOX) down

stop:
	@$(DEVBOX) stop

# make project NAME=foo [GIT=1]
project:
	@test -n "$(NAME)" || { echo "usage: make project NAME=foo [GIT=1]"; exit 1; }
	@$(DEVBOX) new -n "$(NAME)" $(if $(GIT),-g,)

scratch:
	@$(DEVBOX) scratch

# make clean [DAYS=30]
clean:
	@$(DEVBOX) clean $(if $(DAYS),--days $(DAYS),)

prune:
	@$(DEVBOX) prune

doctor:
	@$(DEVBOX) doctor
