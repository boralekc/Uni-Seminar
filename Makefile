# ========================================
# WebMall Agents Makefile (root, thin)
# ========================================

MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/sh
.DEFAULT_GOAL := help

include make/common.mk
include make/env.mk
include make/webmall.mk
include make/browser.mk
include make/browseruse.mk
include make/occam.mk
include make/cleanup.mk

.PHONY: help
help:
	@echo "Make targets:"
	@echo "  env-init-root                 Create ./.env from ./.env.example"
	@echo "  env-init-runner               Create runner/.env from runner/.env.example"
	@echo "  env-init-both                 Create both env files"
	@echo "    (use FORCE=1 to overwrite existing)"
	@echo "  env-check-root                Validate root .env (used by compose)"
	@echo "  env-check-compose             Show key values from ./.env for compose"
	@echo "  env-print-root                Print root .env (masking OPENAI key)"
	@echo "  env-print-runner              Print runner/.env (masking OPENAI key)"
	@echo "  submodules-init               Init git submodules (recursive)"
	@echo "  submodules-update             Update submodules to remote (recursive)"
	@echo "  net                           Create docker network $$(printf "%s" "$(NETWORK)")"
	@echo ""
	@echo "  up-browser / down-browser / ps-browser / logs-browser / browser-run-once / browser-attach-webmall"
	@echo "  up-browseruse / down-browseruse / ps-browseruse / logs-browseruse / browseruse-run-once / browseruse-attach-webmall"
	@echo "  up-occam / down-occam / ps-occam / logs-occam / occam-attach-webmall"
	@echo "  up-agents / down-agents"
	@echo ""
	@echo "  up-webmall / down-webmall / ps-webmall / logs-webmall"
	@echo "  webmall-init-admins / webmall-seed-sample / webmall-fix-urls / webmall-wp-pass SHOP=1 PASS=newpass"
	@echo "  webmall-reset-all / webmall-nuke"
	@echo ""
	@echo "  clean-results / prune-dangling / nuke-all (with NUKE_IMAGES/NUKE_RESULTS)"
	@echo ""
	@echo "Tips:"
	@echo "  - 'FORCE=1 make env-init-<target>' to overwrite existing env files"
	@echo "  - All docker compose commands read env from: $$(printf "%s" "$(ENV)")"
