# ====================== Occam stack =====================
.PHONY: up-occam down-occam ps-occam logs-occam occam-attach-webmall up-agents down-agents

up-occam: env-check-root env-check-compose net
	docker compose -p "$(OCCAM_PROJ)" -f "$(OCCAM_COMPOSE)" --env-file "$(ENV_ABS)" up -d --build

down-occam:
	docker compose -p "$(OCCAM_PROJ)" -f "$(OCCAM_COMPOSE)" --env-file "$(ENV_ABS)" down

ps-occam:
	docker compose -p "$(OCCAM_PROJ)" -f "$(OCCAM_COMPOSE)" ps

logs-occam:
	docker compose -p "$(OCCAM_PROJ)" -f "$(OCCAM_COMPOSE)" logs -f --tail=200

occam-attach-webmall: net
	@cid=$$(docker compose -p "$(OCCAM_PROJ)" -f "$(OCCAM_COMPOSE)" ps -q $(OCCAM_SERVICE)); \
	if [ -z "$$cid" ]; then echo "Occam container not running. Do 'make up-occam' first."; exit 1; fi; \
	echo "Connecting $$cid to $(NETWORK)"; docker network connect "$(NETWORK)" "$$cid" 2>/dev/null || true; echo "OK."
