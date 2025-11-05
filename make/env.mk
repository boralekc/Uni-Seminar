.PHONY: env-init-root env-init-runner env-init-both env-check-root env-check-compose env-print-root env-print-runner

env-init-root:
	@set -e; \
	if [ ! -f "$(ENV_EXAMPLE_ROOT)" ]; then \
	  echo "ERROR: $(ENV_EXAMPLE_ROOT) not found."; exit 1; \
	fi; \
	if [ -f "$(ENV_ROOT)" ] && [ -z "$$FORCE" ]; then \
	  echo ">>> $(ENV_ROOT) exists (skip). Use 'FORCE=1 make env-init-root' to overwrite."; \
	else \
	  cp "$(ENV_EXAMPLE_ROOT)" "$(ENV_ROOT)"; \
	  echo ">>> Created $(ENV_ROOT) from $(ENV_EXAMPLE_ROOT)"; \
	fi

env-init-runner:
	@set -e; \
	mkdir -p "$(ENV_DIR)"; \
	if [ ! -f "$(ENV_EXAMPLE_RUNNER)" ]; then \
	  echo "ERROR: $(ENV_EXAMPLE_RUNNER) not found."; exit 1; \
	fi; \
	if [ -f "$(ENV_RUNNER)" ] && [ -z "$$FORCE" ]; then \
	  echo ">>> $(ENV_RUNNER) exists (skip). Use 'FORCE=1 make env-init-runner' to overwrite."; \
	else \
	  cp "$(ENV_EXAMPLE_RUNNER)" "$(ENV_RUNNER)"; \
	  echo ">>> Created $(ENV_RUNNER) from $(ENV_EXAMPLE_RUNNER)"; \
	fi

env-init-both: env-init-root env-init-runner
	@echo ">>> Both env files are ready. docker compose will use: $(ENV)"

env-check-root:
	@if [ ! -f "$(ENV_ROOT)" ]; then echo "ERROR: $(ENV_ROOT) not found. Run 'make env-init-root'."; exit 1; fi
	@echo "INFO: $(ENV_ROOT) present."

env-check-compose:
	@if [ ! -f "$(ENV)" ]; then echo "ERROR: $(ENV) not found. Run 'make env-init-root'."; exit 1; fi
	@if grep -q "OPENAI_API_KEY=sk-...your-key..." "$(ENV)"; then \
	  echo "WARNING: OPENAI_API_KEY still placeholder in $(ENV)"; \
	fi
	@if ! grep -Eq "^RESULTS_DIR=" "$(ENV)"; then \
	  echo "WARNING: RESULTS_DIR is missing in $(ENV)"; \
	fi
	@COMPOSE_PROFILES_VAL=`grep -E '^COMPOSE_PROFILES=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	WEBMALL_BASE_URL_VAL=`grep -E '^WEBMALL_BASE_URL=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	FRONTEND_PORT_VAL=`grep -E '^FRONTEND_PORT=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	SHOP1_PORT_VAL=`grep -E '^SHOP1_PORT=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	SHOP2_PORT_VAL=`grep -E '^SHOP2_PORT=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	SHOP3_PORT_VAL=`grep -E '^SHOP3_PORT=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	SHOP4_PORT_VAL=`grep -E '^SHOP4_PORT=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	WP_USER_VAL=`grep -E '^WP_ADMIN_USER=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	WP_MAIL_VAL=`grep -E '^WP_ADMIN_EMAIL=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	SAMPLE_VAL=`grep -E '^WOO_SAMPLE_COUNT=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	if [ -z "$$COMPOSE_PROFILES_VAL" ]; then COMPOSE_PROFILES_VAL="runner,agents"; fi; \
	echo "INFO: COMPOSE_PROFILES=$$COMPOSE_PROFILES_VAL"; \
	echo "INFO: WEBMALL_BASE_URL=$${WEBMALL_BASE_URL_VAL:-<unset>}"; \
	echo "INFO: FRONTEND_PORT=$${FRONTEND_PORT_VAL:-<unset>}"; \
	echo "INFO: SHOP1_PORT=$${SHOP1_PORT_VAL:-<unset>} SHOP2_PORT=$${SHOP2_PORT_VAL:-<unset>} SHOP3_PORT=$${SHOP3_PORT_VAL:-<unset>} SHOP4_PORT=$${SHOP4_PORT_VAL:-<unset>}"; \
	echo "INFO: WP_ADMIN_USER=$${WP_USER_VAL:-<unset>}  WP_ADMIN_EMAIL=$${WP_MAIL_VAL:-<unset>}"; \
	echo "INFO: WOO_SAMPLE_COUNT=$${SAMPLE_VAL:-<unset>}"; \
	echo "INFO: docker compose reads env from: $(ENV)"

env-print-root:
	@echo "----- $(ENV_ROOT) -----"; \
	if [ -f "$(ENV_ROOT)" ]; then sed 's/^OPENAI_API_KEY=.*/OPENAI_API_KEY=********/' "$(ENV_ROOT)"; else echo "<missing>"; fi; \
	echo "-----------------------"

env-print-runner:
	@echo "----- $(ENV_RUNNER) -----"; \
	if [ -f "$(ENV_RUNNER)" ]; then sed 's/^OPENAI_API_KEY=.*/OPENAI_API_KEY=********/' "$(ENV_RUNNER)"; else echo "<missing>"; fi; \
	echo "-------------------------"
