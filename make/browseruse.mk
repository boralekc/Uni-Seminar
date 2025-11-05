# =================== BrowserUse stack ===================
.PHONY: up-browseruse down-browseruse ps-browseruse logs-browseruse browseruse-run-once browseruse-attach-webmall

up-browseruse: env-check-root env-check-compose net
	docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" --env-file "$(ENV_ABS)" up -d --build

down-browseruse:
	docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" --env-file "$(ENV_ABS)" down

ps-browseruse:
	docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" ps

logs-browseruse:
	docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" logs -f --tail=200

browseruse-run-once: env-check-root env-check-compose net
	docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" --env-file "$(ENV_ABS)" build
	docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" --env-file "$(ENV_ABS)" run --rm \
	  $(BROWSERUSE_SERVICE) bash -lc "python /app/runner/run_study.py"

browseruse-attach-webmall: net
	@cid=$$(docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" ps -q $(BROWSERUSE_SERVICE)); \
	if [ -z "$$cid" ]; then echo "BrowserUse container not running. Do 'make up-browseruse' first."; exit 1; fi; \
	echo "Connecting $$cid to $(NETWORK)"; docker network connect "$(NETWORK)" "$$cid" 2>/dev/null || true; echo "OK."
