# ===================== Browser stack ====================
.PHONY: up-browser down-browser ps-browser logs-browser browser-run-once browser-attach-webmall

up-browser: env-check-root env-check-compose net
	docker compose -p "$(BROWSER_PROJ)" -f "$(BROWSER_COMPOSE)" --env-file "$(ENV_ABS)" up -d --build

down-browser:
	docker compose -p "$(BROWSER_PROJ)" -f "$(BROWSER_COMPOSE)" --env-file "$(ENV_ABS)" down

ps-browser:
	docker compose -p "$(BROWSER_PROJ)" -f "$(BROWSER_COMPOSE)" ps

logs-browser:
	docker compose -p "$(BROWSER_PROJ)" -f "$(BROWSER_COMPOSE)" logs -f --tail=200

browser-run-once: env-check-root env-check-compose net
	docker compose -p "$(BROWSER_PROJ)" -f "$(BROWSER_COMPOSE)" --env-file "$(ENV_ABS)" build
	docker compose -p "$(BROWSER_PROJ)" -f "$(BROWSER_COMPOSE)" --env-file "$(ENV_ABS)" run --rm \
	  $(BROWSER_SERVICE) bash -lc "python /app/runner/run_study.py"