# ---- network ----
NETWORK                 ?= webmall_net

# ---- env paths ----
ENV_DIR                 ?= runner
ENV_ROOT                := .env
ENV_RUNNER              := $(strip $(ENV_DIR))/.env

# ---- env templates ----
ENV_EXAMPLE_ROOT        ?= .env.example
ENV_EXAMPLE_RUNNER      ?= $(ENV_DIR)/.env.example

# ---- compose env (use ROOT .env)
ENV                     := $(strip $(ENV_ROOT))
ENV_ABS                 := $(abspath $(ENV))

# ---- compose files ----
BROWSER_COMPOSE         ?= docker-compose-browser.yaml
BROWSERUSE_COMPOSE      ?= docker-compose-browseruse.yaml
OCCAM_COMPOSE           ?= docker-compose-occam.yaml

# ---- compose project names ----
BROWSER_PROJ            ?= webmall-agents-browser
BROWSERUSE_PROJ         ?= webmall-agents-browseruse
OCCAM_PROJ              ?= webmall-agents-occam

# ---- service names ----
BROWSER_SERVICE         ?= browseragent
BROWSERUSE_SERVICE      ?= browseragent
OCCAM_SERVICE           ?= agentoccam

# ---- WebMall submodule ----
WEBMALL_REPO            ?= external/WebMall/docker_all
WEBMALL_COMPOSE         ?=                        

# ---------------- docker network --------------
.PHONY: net
net:
	docker network create $(NETWORK) || true

# --------------- git submodules ---------------
.PHONY: submodules-init submodules-update
submodules-init:
	git submodule update --init --recursive

submodules-update:
	git submodule update --remote --recursive
