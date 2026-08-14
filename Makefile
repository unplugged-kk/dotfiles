# dotfiles Makefile - validation and maintenance helpers.
#
#   make check          - everything below (fast, no network)
#   make validate       - nix flake check + build dry-run
#   make check-secrets  - scan tracked tree for secrets
#   make check-json     - parse all JSON/JSONC config files
#   make check-skills   - scan ~/.agents/skills with SkillSpector (security)
#   make lint-context   - lint agent config files with agnix
#   make install-hooks  - point git at .githooks/ (pre-commit secrets guard)
#   make clean          - remove nix build artifacts

SHELL := /bin/bash
REPO_ROOT := $(shell pwd)

.PHONY: all validate check check-secrets check-json check-skills lint-context install-hooks clean

all: check

## Nix evaluation + dry-run build (no activation). Fast; needs nix on PATH.
validate:
	@echo "==> nix flake check --no-build"
	nix flake check --no-build
	@echo "==> darwin-rebuild build --dry-run (via flake)"
	@nix build .#darwinConfigurations.mac.system --dry-run 2>&1 | tail -5 || true

## Secrets guard against tracked files. Fails if a secret is present.
check-secrets:
	@echo "==> secrets scan (tracked tree)"
	./scripts/check-secrets.sh --tree

## Parse every JSON / JSONC config in home/ to catch syntax errors.
check-json:
	@echo "==> JSON/JSONC syntax check"
	./scripts/check-json.sh

## Scan the canonical skill folder for vulnerabilities (NVIDIA SkillSpector).
## Static-only (--no-llm): fast, no API key, contents stay local.
check-skills:
	@echo "==> SkillSpector scan of ~/.agents/skills (static)"
	@if command -v skillspector >/dev/null 2>&1; then \
	  skillspector scan "$$HOME/.agents/skills/" --no-llm --format terminal; \
	else \
	  echo "skillspector not installed - run: uv tool install 'skillspector @ git+https://github.com/NVIDIA/skillspector.git'"; \
	fi

## Lint agent config files (CLAUDE.md, AGENTS.md, SKILL.md, hooks, MCP).
## Validates the shared AGENTS.md + all skill files + MCP configs.
lint-context:
	@echo "==> agnix lint of agent configs"
	@if command -v agnix >/dev/null 2>&1; then \
	  agnix --strict "$$HOME/.agents/skills/" || true; \
	  agnix --strict . || true; \
	else \
	  echo "agnix not installed - run: npm install -g agnix"; \
	fi

## All fast checks.
check: check-secrets check-json

## Point git at .githooks/ (pre-commit runs the secrets guard).
install-hooks:
	@git config core.hooksPath .githooks
	@echo "installed .githooks (core.hooksPath = .githooks)"

clean:
	rm -rf result result-*
	@echo "cleaned build artifacts"
