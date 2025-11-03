# ---- vars ----
NETWORK ?= webmall_net
ENV ?= .env

BROWSER_COMPOSE ?= docker-compose-browser.yaml
BROWSER_PROJ ?= webmall-agents-browser

OCCAM_COMPOSE   ?= docker-compose-occam.yaml
OCCAM_PROJ ?= webmall-agents-occam

WEBMALL_REPO ?= external/WebMall/docker_all

# ---- common ----
.PHONY: net
net:
	docker network create $(NETWORK) || true

.PHONY: submodules-init
submodules-init:
	git submodule update --init --recursive

.PHONY: submodules-update
submodules-update:
	git submodule update --remote --recursive

# ---- WebMall local (их compose) ----
.PHONY: up-local-webmall
up-local-webmall:
	@[ -d "$(WEBMALL_REPO)" ] || (echo "Submodule $(WEBMALL_REPO) not found"; exit 1)
	cd $(WEBMALL_REPO) && docker compose up -d
	@echo ">>> Set WEBMALL_BASE_URL in .env to local URL (e.g., http://localhost:8080)"

# ---- Browser stack ----
.PHONY: up-browser
up-browser: net
	COMPOSE_PROFILES=$${COMPOSE_PROFILES:-runner,agents} \
	docker compose -p $(BROWSER_PROJ) -f $(BROWSER_COMPOSE) --env-file $(ENV) up -d --build

.PHONY: down-browser
down-browser:
	docker compose -p $(BROWSER_PROJ) -f $(BROWSER_COMPOSE) --env-file $(ENV) down

.PHONY: ps-browser
ps-browser:
	docker compose -p $(BROWSER_PROJ) -f $(BROWSER_COMPOSE) ps

.PHONY: logs-browser
logs-browser:
	docker compose -p $(BROWSER_PROJ) -f $(BROWSER_COMPOSE) logs -f --tail=200

# ---- Occam stack ----
.PHONY: up-occam
up-occam: net
	COMPOSE_PROFILES=$${COMPOSE_PROFILES:-runner,agents} \
	docker compose -p $(OCCAM_PROJ) -f $(OCCAM_COMPOSE) --env-file $(ENV) up -d --build

.PHONY: down-occam
down-occam:
	docker compose -p $(OCCAM_PROJ) -f $(OCCAM_COMPOSE) --env-file $(ENV) down

.PHONY: ps-occam
ps-occam:
	docker compose -p $(OCCAM_PROJ) -f $(OCCAM_COMPOSE) ps

.PHONY: logs-occam
logs-occam:
	docker compose -p $(OCCAM_PROJ) -f $(OCCAM_COMPOSE) logs -f --tail=200

# ---- both stacks helpers ----
.PHONY: up-both
up-both: up-browser up-occam

.PHONY: down-both
down-both: down-browser down-occam

# ---- quick runs via runner (каждый стэк имеет свой runner) ----
.PHONY: run-browser
run-browser:
	docker compose -p $(BROWSER_PROJ) -f $(BROWSER_COMPOSE) exec runner \
	  python -u main.py run \
	    --agent browser \
	    --base-url "$$(grep -E '^WEBMALL_BASE_URL=' $(ENV) | cut -d= -f2-)" \
	    --taskset "$$(grep -E '^TASKSET_PATH=' $(ENV) | cut -d= -f2-)" \
	    --episodes $${EPISODES:-3} \
	    --output "$$(grep -E '^RESULTS_DIR=' $(ENV) | cut -d= -f2-)/browser"

.PHONY: run-occam
run-occam:
	docker compose -p $(OCCAM_PROJ) -f $(OCCAM_COMPOSE) exec runner \
	  python -u main.py run \
	    --agent occam \
	    --base-url "$$(grep -E '^WEBMALL_BASE_URL=' $(ENV) | cut -d= -f2-)" \
	    --taskset "$$(grep -E '^TASKSET_PATH=' $(ENV) | cut -d= -f2-)" \
	    --episodes $${EPISODES:-3} \
	    --output "$$(grep -E '^RESULTS_DIR=' $(ENV) | cut -d= -f2-)/occam"

