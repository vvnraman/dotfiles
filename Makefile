PROJECT   := dotfiles
PYTHON_PROJECT_DIR := python
UV_RUN := uv run --project "$(PYTHON_PROJECT_DIR)"
dotfiles := $(UV_RUN) $(PROJECT)

.DEFAULT: help

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

.PHONY: dotfiles
dotfiles: ## Run dotfiles CLI
dotfiles:
	$(dotfiles) $(args)

.PHONY: info
info: ## Show project info
info:
	$(UV_RUN) $(PROJECT) info

.PHONY: docs
docs: ## Generate docs
docs:
	$(UV_RUN) $(PROJECT) docs

.PHONY: clean
clean: ## Clean generated docs
clean:
	$(UV_RUN) $(PROJECT) clean

.PHONY: live
live: ## Generate live docs
live:
	$(UV_RUN) $(PROJECT) live

.PHONY: nvim-info
nvim-info: ## Information about runtime neovim config
nvim-info:
	$(UV_RUN) $(PROJECT) nvim info

.PHONY: nvim-sync
nvim-sync: ## Sync with neovim config. Append `-- args=--no-dry-run` for actual sync.
nvim-sync:
	$(UV_RUN) $(PROJECT) nvim sync $(args)

.PHONY: pytest
pytest: ## Run python test suite
pytest:
	$(UV_RUN) --group dev pytest python/tests

.PHONY: install
install: ## Install dotfiles tool; example: make install args='--dirty-install-path /tmp/dotfiles-bin --no-dry-run'
install:
	$(UV_RUN) python/scripts/install_tool.py $(args)

.PHONY: install-dev
install-dev: ## Install editable dotfiles-dev from current branch
install-dev:
	$(UV_RUN) python/scripts/install_tool.py --dev --no-dry-run $(args)

.PHONY: build
build: ## Build python package artifacts
build:
	uv build --project "$(PYTHON_PROJECT_DIR)"

.PHONY: lint
lint: ## Run basedpyright, black, and isort checks
lint:
	cd python && uv run basedpyright
	cd python && uv run --group dev black --check src tests ../docs
	cd python && uv run --group dev isort --profile black --check-only src tests ../docs

.PHONY: format
format: ## Format python and docs imports/style
format:
	cd python && uv run --group dev isort --profile black src tests ../docs
	cd python && uv run --group dev black src tests ../docs
