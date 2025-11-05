# ----------------------- Cleanup ------------------------
.PHONY: clean-results prune-dangling nuke-all

clean-results:
	@RESULTS_DIR_VAL=`grep -E '^RESULTS_DIR=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	if [ -z "$$RESULTS_DIR_VAL" ]; then RESULTS_DIR_VAL="./results"; fi; \
	echo ">>> Removing results dir: $$RESULTS_DIR_VAL"; \
	rm -rf "$$RESULTS_DIR_VAL"

prune-dangling:
	@echo ">>> Pruning dangling images/volumes/build-cache (non-interactive)"
	- docker image prune -f
	- docker volume prune -f
	- docker builder prune -f

nuke-all:
	@echo ">>> Bringing down agent stacks (with volumes)"
	- docker compose -p "$(BROWSER_PROJ)"    -f "$(BROWSER_COMPOSE)"    --env-file "$(ENV_ABS)" down -v
	- docker compose -p "$(BROWSERUSE_PROJ)" -f "$(BROWSERUSE_COMPOSE)" --env-file "$(ENV_ABS)" down -v
	- docker compose -p "$(OCCAM_PROJ)"      -f "$(OCCAM_COMPOSE)"      --env-file "$(ENV_ABS)" down -v
	@echo ">>> Nuking WebMall (containers + volumes)"
	- $(MAKE) webmall-reset-all
	@if [ "$(NUKE_IMAGES)" = "1" ]; then \
	  echo ">>> Also nuking WebMall images"; \
	  $(MAKE) webmall-nuke NUKE_IMAGES=1; \
	fi
	@echo ">>> Removing docker network: $(NETWORK)"
	- docker network rm "$(NETWORK)"
	@$(MAKE) prune-dangling
	@if [ "$(NUKE_RESULTS)" = "1" ]; then \
	  $(MAKE) clean-results; \
	fi
	@echo ">>> Done."
