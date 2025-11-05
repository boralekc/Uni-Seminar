# ========================================
# make/webmall.mk — WebMall helpers (native restore)
# ========================================

# ---- Locations / names ----
WEBMALL_REPO        ?= external/WebMall/docker_all
WEBMALL_COMPOSE     ?= $(WEBMALL_REPO)/docker-compose.yml
WEBMALL_PROJ        ?= webmall-local
WP_SVC_PREFIX       ?= WebMall_wordpress_shop

# ---- Environment ----
ENV                 ?= .env
ENV_ABS             := $(abspath $(ENV))

# ---- Absolute paths for convenience
ABS_WEBMALL_REPO    := $(abspath $(WEBMALL_REPO))
WEBMALL_TEMP_CFG_DIR ?= $(WEBMALL_REPO)/deployed_wp_config_local
ABS_TEMP_CFG_DIR    := $(abspath $(WEBMALL_TEMP_CFG_DIR))

# ---- Ports (pulled from .env)
SHOP1_PORT ?= $(shell grep -E '^SHOP1_PORT=' $(ENV) | cut -d= -f2- | tr -d '\r')
SHOP2_PORT ?= $(shell grep -E '^SHOP2_PORT=' $(ENV) | cut -d= -f2- | tr -d '\r')
SHOP3_PORT ?= $(shell grep -E '^SHOP3_PORT=' $(ENV) | cut -d= -f2- | tr -d '\r')
SHOP4_PORT ?= $(shell grep -E '^SHOP4_PORT=' $(ENV) | cut -d= -f2- | tr -d '\r')

# ---- Phonies ----
.PHONY: env-check-root env-check-compose submodules-init \
        up-webmall down-webmall ps-webmall logs-webmall \
        webmall-init-admins webmall-fix-urls webmall-seed-sample webmall-wp-pass \
        webmall-reset-all webmall-nuke \
        webmall-unixify webmall-env-bridge \
        webmall-generate-temp-configs webmall-generate-temp-configs-from-backups \
        webmall-assert-temp-configs webmall-debug-temp-configs \
        webmall-restore-native webmall-restore-all

# ========================================
# Base checks / utils
# ========================================

env-check-root:
	@echo "INFO: .env present."; test -f "$(ENV)" || { echo "ERROR: $(ENV) not found"; exit 1; }
	@grep -qE '^WEBMALL_BASE_URL=' "$(ENV)" || echo "WARN: WEBMALL_BASE_URL missing in $(ENV)"
	@grep -qE '^FRONTEND_PORT='   "$(ENV)" || echo "WARN: FRONTEND_PORT missing in $(ENV)"
	@echo "INFO: COMPOSE_PROFILES=$$(grep -E '^COMPOSE_PROFILES=' $(ENV) | cut -d= -f2- | tr -d '\r')"
	@echo "INFO: WEBMALL_BASE_URL=$$(grep -E '^WEBMALL_BASE_URL=' $(ENV) | cut -d= -f2- | tr -d '\r')"
	@echo "INFO: FRONTEND_PORT=$$(grep -E '^FRONTEND_PORT=' $(ENV) | cut -d= -f2- | tr -d '\r')"
	@echo "INFO: SHOP1_PORT=$$(grep -E '^SHOP1_PORT=' $(ENV) | cut -d= -f2- | tr -d '\r') SHOP2_PORT=$$(grep -E '^SHOP2_PORT=' $(ENV) | cut -d= -f2- | tr -d '\r') SHOP3_PORT=$$(grep -E '^SHOP3_PORT=' $(ENV) | cut -d= -f2- | tr -d '\r') SHOP4_PORT=$$(grep -E '^SHOP4_PORT=' $(ENV) | cut -d= -f2- | tr -d '\r')"
	@echo "INFO: WP_ADMIN_USER=$$(grep -E '^WP_ADMIN_USER=' $(ENV) | cut -d= -f2- | tr -d '\r')  WP_ADMIN_EMAIL=$$(grep -E '^WP_ADMIN_EMAIL=' $(ENV) | cut -d= -f2- | tr -d '\r')"
	@echo "INFO: WOO_SAMPLE_COUNT=$$(grep -E '^WOO_SAMPLE_COUNT=' $(ENV) | cut -d= -f2- | tr -d '\r')"
	@echo "INFO: docker compose reads env from: $(ENV)"
	@grep -qE '^OPENAI_API_KEY=sk-' "$(ENV)" || echo "WARNING: OPENAI_API_KEY still placeholder in $(ENV)" || true

env-check-compose:
	@command -v docker >/dev/null || { echo "ERROR: docker not found"; exit 1; }
	@docker compose version >/dev/null 2>&1 || { echo "ERROR: docker compose not available"; exit 1; }

submodules-init:
	@git submodule update --init --recursive

# ========================================
# CRLF normalization for submodule scripts
# ========================================

webmall-unixify:
	@if [ ! -d "$(WEBMALL_REPO)" ]; then echo "Submodule $(WEBMALL_REPO) not found"; exit 1; fi
	@echo ">>> Normalizing line endings to LF in $(WEBMALL_REPO)"
	@cd "$(WEBMALL_REPO)" && \
	  if command -v dos2unix >/dev/null 2>&1; then \
	    dos2unix -q *.sh */*.sh 2>/dev/null || true; \
	  else \
	    find . -type f -name "*.sh" -print0 | xargs -0 -I{} sh -c "sed -i 's/\r$$//' '{}' || true"; \
	  fi
	@echo ">>> Done: CRLF -> LF"

# ========================================
# Bridge .env for submodule scripts (they source ../.env)
# ========================================

webmall-env-bridge:
	@if [ ! -d "$(WEBMALL_REPO)" ]; then echo "Submodule $(WEBMALL_REPO) not found"; exit 1; fi
	@echo ">>> Bridging .env to external/WebMall/.env"
	@cd "$(WEBMALL_REPO)" && { ln -sf "$(ENV_ABS)" ../.env || cp -f "$(ENV_ABS)" ../.env; }
	@echo ">>> .env bridge created at external/WebMall/.env"

define EXTRACT_AND_PATCH_WP_CONFIG
	@echo ">>> [shop$(1)] extracting wp-config.php into $(WEBMALL_TEMP_CFG_DIR)/shop_$(1)_temp.php"
	@mkdir -p "$(WEBMALL_TEMP_CFG_DIR)"
	@docker run --rm -v "woocommerce_wordpress_data_shop$(1):/mnt" alpine \
	  sh -c 'for p in \
	    /mnt/wordpress/wp-config.php \
	    /mnt/wp-config.php \
	    /mnt/bitnami/wordpress/wp-config.php \
	    /mnt/wordpress/html/wp-config.php \
	  ; do [ -f $$p ] && { cat $$p; exit 0; }; done; exit 1' \
	  > "$(WEBMALL_TEMP_CFG_DIR)/shop_$(1)_temp.php" || { echo "ERROR: wp-config.php not found in volume woocommerce_wordpress_data_shop$(1)"; exit 1; }
	@echo ">>> [shop$(1)] patching WP_HOME/SITEURL -> http://localhost:$(2)"
	@grep -q "define *('WP_HOME'" "$(WEBMALL_TEMP_CFG_DIR)/shop_$(1)_temp.php" && \
	  sed -i "s#define *('WP_HOME'.*#define('WP_HOME','http://localhost:$(2)');#g" "$(WEBMALL_TEMP_CFG_DIR)/shop_$(1)_temp.php" || true
	@grep -q "define *('WP_SITEURL'" "$(WEBMALL_TEMP_CFG_DIR)/shop_$(1)_temp.php" && \
	  sed -i "s#define *('WP_SITEURL'.*#define('WP_SITEURL','http://localhost:$(2)');#g" "$(WEBMALL_TEMP_CFG_DIR)/shop_$(1)_temp.php" || true
	@grep -q "define *('WP_HOME'" "$(WEBMALL_TEMP_CFG_DIR)/shop_$(1)_temp.php" || \
	  sed -i "0,/^<\?php/s//<?php\ndefine('WP_HOME','http:\/\/localhost:$(2)');\n/" "$(WEBMALL_TEMP_CFG_DIR)/shop_$(1)_temp.php"
	@grep -q "define *('WP_SITEURL'" "$(WEBMALL_TEMP_CFG_DIR)/shop_$(1)_temp.php" || \
	  sed -i "0,/^<\?php/s//<?php\ndefine('WP_SITEURL','http:\/\/localhost:$(2)');\n/" "$(WEBMALL_TEMP_CFG_DIR)/shop_$(1)_temp.php"
endef

webmall-generate-temp-configs:
	@if [ ! -d "$(WEBMALL_REPO)" ]; then echo "Submodule $(WEBMALL_REPO) not found"; exit 1; fi
	@echo ">>> Generating temp configs from restored volumes into $(WEBMALL_TEMP_CFG_DIR)"
	$(call EXTRACT_AND_PATCH_WP_CONFIG,1,$(SHOP1_PORT))
	$(call EXTRACT_AND_PATCH_WP_CONFIG,2,$(SHOP2_PORT))
	$(call EXTRACT_AND_PATCH_WP_CONFIG,3,$(SHOP3_PORT))
	$(call EXTRACT_AND_PATCH_WP_CONFIG,4,$(SHOP4_PORT))
	@echo ">>> OK: shop_*_temp.php generated."

webmall-generate-temp-configs-from-backups:
	@if [ ! -d "$(WEBMALL_REPO)" ]; then echo "Submodule $(WEBMALL_REPO) not found"; exit 1; fi
	@mkdir -p "$(WEBMALL_TEMP_CFG_DIR)"
	@echo ">>> Generating temp configs from backup tarballs into $(WEBMALL_TEMP_CFG_DIR)"
	@set -e; \
	for i in 1 2 3 4; do \
	  TAR="$(WEBMALL_REPO)/backup/wordpress_data_shop$$i.tar.gz"; \
	  OUT="$(WEBMALL_TEMP_CFG_DIR)/shop_$$i_temp.php"; \
	  [ -f "$$TAR" ] || { echo "ERROR: $$TAR not found"; exit 1; }; \
	  echo ">>> [shop$$i] locating wp-config.php in $$TAR"; \
	  CAND=$$(tar -tzf "$$TAR" | grep -Ei '(^|/)\.?wp-config\.php$$' | head -n1 || true); \
	  if [ -z "$$CAND" ]; then \
	    echo "ERROR: wp-config.php not found inside $$TAR"; exit 1; \
	  fi; \
	  echo ">>> [shop$$i] extracting $$CAND"; \
	  tar -xOzf "$$TAR" "$$CAND" > "$$OUT"; \
	  PORT=$$(grep -E "^SHOP$${i}_PORT=" "$(ENV)" | cut -d= -f2- | tr -d '\r'); \
	  [ -n "$$PORT" ] || PORT=$$(expr 8080 + $$i); \
	  echo ">>> [shop$$i] patching WP_HOME/SITEURL -> http://localhost:$$PORT"; \
	  grep -q "define *('WP_HOME'" "$$OUT" && \
	    sed -i "s#define *('WP_HOME'.*#define('WP_HOME','http://localhost:$$PORT');#g" "$$OUT" || true; \
	  grep -q "define *('WP_SITEURL'" "$$OUT" && \
	    sed -i "s#define *('WP_SITEURL'.*#define('WP_SITEURL','http://localhost:$$PORT');#g" "$$OUT" || true; \
	  grep -q "define *('WP_HOME'" "$$OUT" || \
	    sed -i "0,/^<\?php/s//<?php\ndefine('WP_HOME','http:\/\/localhost:$$PORT');\n/" "$$OUT"; \
	  grep -q "define *('WP_SITEURL'" "$$OUT" || \
	    sed -i "0,/^<\?php/s//<?php\ndefine('WP_SITEURL','http:\/\/localhost:$$PORT');\n/" "$$OUT"; \
	done
	@echo ">>> OK: shop_*_temp.php generated from backups."

webmall-assert-temp-configs:
	@for i in 1 2 3 4; do \
	  f="$(WEBMALL_TEMP_CFG_DIR)/shop_$${i}_temp.php"; \
	  [ -f "$$f" ] || { echo "ERROR: $$f not found. Run webmall-generate-temp-configs-from-backups first."; exit 1; }; \
	done
	@echo ">>> OK: all shop_*_temp.php present in $(WEBMALL_TEMP_CFG_DIR)"

webmall-debug-temp-configs:
	@echo "DIR: $(WEBMALL_TEMP_CFG_DIR)"
	@ls -la "$(WEBMALL_TEMP_CFG_DIR)" || true
	@for i in 1 2 3 4; do \
	  f="$(WEBMALL_TEMP_CFG_DIR)/shop_$${i}_temp.php"; \
	  [ -f "$$f" ] && echo "OK $$f" || echo "MISS $$f"; \
	done

webmall-restore-native: env-check-root env-check-compose submodules-init \
  webmall-unixify webmall-env-bridge \
  webmall-generate-temp-configs-from-backups webmall-assert-temp-configs webmall-debug-temp-configs
	@set -e; \
	echo ">>> Native restore starting (bypassing vendor script)"; \
	BACKUP_DIR="$(ABS_WEBMALL_REPO)/backup"; \
	CFG_DIR="$(ABS_TEMP_CFG_DIR)"; \
	for i in 1 2 3 4; do \
	  WP_VOL="woocommerce_wordpress_data_shop$$i"; \
	  DB_VOL="woocommerce_mariadb_data_shop$$i"; \
	  echo "=== [shop$$i] ensuring volumes ==="; \
	  docker volume create "$$WP_VOL" >/dev/null; \
	  docker volume create "$$DB_VOL" >/dev/null; \
	  echo "=== [shop$$i] restoring WordPress volume from backup ==="; \
	  docker run --rm -v "$$WP_VOL:/volume" -v "$$BACKUP_DIR:/backup" busybox sh -lc "tar xzf \"/backup/wordpress_data_shop$$i.tar.gz\" -C /volume"; \
	  echo "=== [shop$$i] restoring MariaDB volume from backup ==="; \
	  docker run --rm -v "$$DB_VOL:/volume" -v "$$BACKUP_DIR:/backup" busybox sh -lc "tar xzf \"/backup/mariadb_data_shop$$i.tar.gz\" -C /volume"; \
	  echo "=== [shop$$i] installing wp-config.php ==="; \
	  test -f "$$CFG_DIR/shop_$${i}_temp.php" || { echo "ERROR: $$CFG_DIR/shop_$${i}_temp.php not found"; exit 1; }; \
	  docker run --rm -v "$$WP_VOL:/volume" -v "$$CFG_DIR:/cfg" busybox sh -lc "cp /cfg/shop_$${i}_temp.php /volume/wp-config.php && chmod 0644 /volume/wp-config.php"; \
	done; \
	echo ">>> Native restore done."

# One-shot: restore + up + fix-urls
webmall-restore-all: webmall-restore-native up-webmall webmall-fix-urls

# ========================================
# Compose controls
# ========================================

up-webmall: env-check-root env-check-compose submodules-init
	@if [ ! -d "$(WEBMALL_REPO)" ]; then echo "Submodule $(WEBMALL_REPO) not found"; exit 1; fi
	@echo ">>> Starting WebMall with env file: $(ENV_ABS)"
	@if [ -n "$(WEBMALL_COMPOSE)" ]; then \
	  cd "$(WEBMALL_REPO)" && docker compose --env-file "$(ENV_ABS)" -p "$(WEBMALL_PROJ)" -f "$(WEBMALL_COMPOSE)" up -d; \
	else \
	  cd "$(WEBMALL_REPO)" && docker compose --env-file "$(ENV_ABS)" -p "$(WEBMALL_PROJ)" up -d; \
	fi
	@echo ">>> Tip: WEBMALL_BASE_URL should match FRONTEND_PORT (e.g., http://localhost:$$(grep -E '^FRONTEND_PORT=' $(ENV) | cut -d= -f2- ))"

down-webmall:
	@if [ ! -d "$(WEBMALL_REPO)" ]; then echo "Submodule $(WEBMALL_REPO) not found"; exit 1; fi
	@if [ -n "$(WEBMALL_COMPOSE)" ]; then \
	  cd "$(WEBMALL_REPO)" && docker compose --env-file "$(ENV_ABS)" -p "$(WEBMALL_PROJ)" -f "$(WEBMALL_COMPOSE)" down; \
	else \
	  cd "$(WEBMALL_REPO)" && docker compose --env-file "$(ENV_ABS)" -p "$(WEBMALL_PROJ)" down; \
	fi

ps-webmall:
	@if [ ! -d "$(WEBMALL_REPO)" ]; then echo "Submodule $(WEBMALL_REPO) not found"; exit 1; fi
	@if [ -n "$(WEBMALL_COMPOSE)" ]; then \
	  cd "$(WEBMALL_REPO)" && docker compose -p "$(WEBMALL_PROJ)" -f "$(WEBMALL_COMPOSE)" ps; \
	else \
	  cd "$(WEBMALL_REPO)" && docker compose -p "$(WEBMALL_PROJ)" ps; \
	fi

logs-webmall:
	@if [ ! -d "$(WEBMALL_REPO)" ]; then echo "Submodule $(WEBMALL_REPO) not found"; exit 1; fi
	@if [ -n "$(WEBMALL_COMPOSE)" ]; then \
	  cd "$(WEBMALL_REPO)" && docker compose -p "$(WEBMALL_PROJ)" -f "$(WEBMALL_COMPOSE)" logs -f --tail=200; \
	else \
	  cd "$(WEBMALL_REPO)" && docker compose -p "$(WEBMALL_PROJ)" logs -f --tail=200; \
	fi

# ========================================
# WordPress utilities
# ========================================

webmall-init-admins:
	@set -e; \
	WP_USER=`grep -E '^WP_ADMIN_USER=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	WP_PASS=`grep -E '^WP_ADMIN_PASS=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	WP_MAIL=`grep -E '^WP_ADMIN_EMAIL=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	for i in 1 2 3 4; do \
	  URL="http://localhost:$$(grep -E "^SHOP$${i}_PORT=" "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r')"; \
	  TITLE="Shop $$i"; \
	  echo ">>> [shop$$i] checking/installing WP at $$URL"; \
	  docker exec "$(WP_SVC_PREFIX)$$i" bash -lc " \
	    wp core is-installed --allow-root --path=/opt/bitnami/wordpress || \
	    wp core install --allow-root --url='$$URL' --title='$$TITLE' \
	      --admin_user='$$WP_USER' --admin_password='$$WP_PASS' \
	      --admin_email='$$WP_MAIL' --skip-email \
	      --path=/opt/bitnami/wordpress \
	  "; \
	done
	@echo ">>> Admin users ensured."

webmall-seed-sample:
	@set -e; \
	COUNT=`grep -E '^WOO_SAMPLE_COUNT=' "$(ENV)" | head -n1 | cut -d= -f2- | tr -d '\r'`; \
	if [ -z "$$COUNT" ]; then COUNT=3; fi; \
	for i in 1 2 3 4; do \
	  echo ">>> [shop$$i] installing WooCommerce and creating $$COUNT sample products"; \
	  docker exec "$(WP_SVC_PREFIX)$$i" bash -lc " \
	    wp plugin is-installed woocommerce --path=/opt/bitnami/wordpress || wp plugin install woocommerce --activate --path=/opt/bitnami/wordpress; \
	    wp plugin activate woocommerce --path=/opt/bitnami/wordpress; \
	    wp wc --allow-root --path=/opt/bitnami/wordpress tool run install_pages || true; \
	    n=1; \
	    while [ \$$n -le $$COUNT ]; do \
	      PID=\$$(wp post create --post_type=product --post_status=publish --post_title=\"Sample Product \$$n\" --porcelain --path=/opt/bitnami/wordpress); \
	      PRICE=\$$((10 * \$$n)); \
	      wp post meta set \$$PID _regular_price \$$PRICE --path=/opt/bitnami/wordpress; \
	      wp post meta set \$$PID _price \$$PRICE --path=/opt/bitnami/wordpress; \
	      wp post meta set \$$PID _stock_status instock --path=/opt/bitnami/wordpress; \
	      n=\$$((\$$n+1)); \
	    done \
	  "; \
	done
	@echo ">>> Sample products created."

webmall-wp-pass:
	@if [ -z "$(SHOP)" ] || [ -z "$(PASS)" ]; then \
	  echo "Usage: make webmall-wp-pass SHOP=1 PASS=newpass"; exit 1; \
	fi
	@docker exec "$(WP_SVC_PREFIX)$(SHOP)" wp user update admin --user_pass='$(PASS)' --path=/opt/bitnami/wordpress

# ========================================
# Cleanup
# ========================================

webmall-reset-all:
	@if [ ! -d "$(WEBMALL_REPO)" ]; then echo "Submodule $(WEBMALL_REPO) not found"; exit 1; fi
	@echo ">>> Stopping and removing WebMall containers + named volumes (down -v)"
	cd "$(WEBMALL_REPO)" && docker compose --env-file "$(ENV_ABS)" -p "$(WEBMALL_PROJ)" down -v || true
	@echo ">>> Removing leftover volumes"
	@docker volume ls --format '{{.Name}}' | grep -E '^woocommerce_(wordpress|mariadb)_data_shop[1-4]$$' | xargs -r docker volume rm || true
	@docker volume ls --format '{{.Name}}' | grep -E '^esdata$$' | xargs -r docker volume rm || true

webmall-nuke:
	@$(MAKE) webmall-reset-all
	@if [ "$(NUKE_IMAGES)" = "1" ]; then \
	  echo ">>> Removing WebMall images (best-effort)"; \
	  { docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -Ei 'wordpress|mariadb|bitnami|elastic|elasticsearch|nginx' | awk '{print $$2}' | xargs -r docker rmi -f; } || true; \
	fi
	@echo ">>> WebMall nuked."
