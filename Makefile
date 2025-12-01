PROJECT   := dotfiles

.DEFAULT: help

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

.PHONY: info
info: ## Show project info
info:
	uv run $(PROJECT) info

.PHONY: docs
docs: ## Generate docs
docs:
	uv run $(PROJECT) docs

.PHONY: clean
clean: ## Clean generated docs
clean:
	uv run $(PROJECT) clean

.PHONY: live
live: ## Generate live docs
live:
	uv run $(PROJECT) live

.PHONY: nvim
nvim: ## Sync with neovim config. Append `-- args=--no-dry-run` for actual sync.
nvim:
	uv run $(PROJECT) nvim $(args)

