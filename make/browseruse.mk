# =================== BrowserUse stack (fixed) ===================

.PHONY: up-browseruse down-browseruse ps-browseruse logs-browseruse browseruse-run-once browseruse-attach-webmall

up-browseruse: env-check-root env-check-compose net
	docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" --env-file "$(ENV_ABS)" up -d --build

down-browseruse:
	docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" --env-file "$(ENV_ABS)" down

ps-browseruse:
	docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" ps

logs-browseruse:
	docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" logs -f --tail=200

# Run once in a disposable container and exit (no daemon)
browseruse-run-once: env-check-root env-check-compose net
	docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" --env-file "$(ENV_ABS)" build
	docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" --env-file "$(ENV_ABS)" run --rm \
	  $(BROWSERUSE_SERVICE) bash -lc "python /app/runner/run_browseruse_webmall_study.py"

# Attach a running BrowserUse container to the WebMall network (if needed)
browseruse-attach-webmall: net
	@cid=$$(docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" ps -q $(BROWSERUSE_SERVICE)); \
	if [ -z "$$cid" ]; then echo "BrowserUse container not running. Do 'make up-browseruse' first."; exit 1; fi; \
	echo "Connecting $$cid to $(NETWORK)"; docker network connect "$(NETWORK)" "$$cid" 2>/dev/null || true; echo "OK."
