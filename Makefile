NETWORK ?= webmall_net

.PHONY: net
net:
	docker network create $(NETWORK) || true

# локальный режим (агенты + локальный webmall при необходимости)
.PHONY: up-local
up-local: net
	docker compose -f compose/compose.base.yml -f compose/compose.local.yml up -d

.PHONY: up-local-with-webmall
up-local-with-webmall: net
	docker compose -f compose/compose.webmall.local.yml up -d
	docker compose -f compose/compose.base.yml -f compose/compose.local.yml up -d

# vpn режим (агенты, webmall внешний)
.PHONY: up-vpn
up-vpn: net
	docker compose -f compose/compose.base.yml -f compose/compose.vpn.yml up -d

.PHONY: down
down:
	docker compose -f compose/compose.base.yml down
	docker compose -f compose/compose.webmall.local.yml down || true

.PHONY: logs
logs:
	docker compose -f compose/compose.base.yml logs -f

.PHONY: ps
ps:
	docker compose -f compose/compose.base.yml ps

REPO_DIR ?= $(HOME)/WebMall
NETWORK  ?= webmall_net
CONTAINER_FRONT ?= WebMall_frontend

.PHONY: webmall-up
webmall-up:
	@set -euo pipefail; \
	echo "[i] Using REPO_DIR=$(REPO_DIR), NETWORK=$(NETWORK)"; \
	if [ -d "$(REPO_DIR)/.git" ]; then \
	  echo "[i] Repo exists: $(REPO_DIR) — pulling latest..."; \
	  git -C "$(REPO_DIR)" pull --ff-only; \
	  git -C "$(REPO_DIR)" submodule update --init --recursive; \
	else \
	  echo "[i] Cloning WebMall into $(REPO_DIR) ..."; \
	  git clone --recurse-submodules https://github.com/wbsg-uni-mannheim/WebMall.git "$(REPO_DIR)"; \
	fi; \
	if [ ! -f "$(REPO_DIR)/.env" ]; then \
	  echo "[i] Creating $(REPO_DIR)/.env from example..."; \
	  cp "$(REPO_DIR)/.env.example" "$(REPO_DIR)/.env"; \
	fi; \
	cd "$(REPO_DIR)/docker_all"; \
	docker compose up -d; \
	docker network create "$(NETWORK)" || true; \
	docker network connect "$(NETWORK)" "$(CONTAINER_FRONT)" || true; \
	echo "\n[✓] WebMall is up. Use WEBMALL_BASE_URL=http://webmall_frontend:80\n"; \
	docker compose ps

.PHONY: webmall-down
webmall-down:
	@cd "$(REPO_DIR)/docker_all" && docker compose down || true