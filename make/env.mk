# ===== Root env bootstrap (slim) =====
.PHONY: env-init env-check env-print

# Откуда-куда копируем шаблон
ENV_EXAMPLE_ROOT ?= .env.example
ENV_ROOT         ?= .env

env-init:
	@set -e; \
	if [ ! -f "$(ENV_EXAMPLE_ROOT)" ]; then \
	  echo "ERROR: $(ENV_EXAMPLE_ROOT) not found."; exit 1; \
	fi; \
	if [ -f "$(ENV_ROOT)" ] && [ -z "$$FORCE" ]; then \
	  echo ">>> $(ENV_ROOT) exists (skip). Use 'FORCE=1 make env-init' to overwrite."; \
	else \
	  cp "$(ENV_EXAMPLE_ROOT)" "$(ENV_ROOT)"; \
	  echo ">>> Created $(ENV_ROOT) from $(ENV_EXAMPLE_ROOT)"; \
	fi

env-check:
	@if [ ! -f "$(ENV_ROOT)" ]; then echo "ERROR: $(ENV_ROOT) not found. Run 'make env-init'."; exit 1; fi
	@echo "INFO: $(ENV_ROOT) present."

env-print:
	@echo "----- $(ENV_ROOT) -----"; \
	if [ -f "$(ENV_ROOT)" ]; then sed 's/^OPENAI_API_KEY=.*/OPENAI_API_KEY=********/' "$(ENV_ROOT)"; else echo "<missing>"; fi; \
	echo "-----------------------"
