DOCS_DIR := docs
HTML_DIR := $(DOCS_DIR)/_build/html
REMOTE := github:vvnraman/dotfiles

.DEFAULT: help

.PHONY: help
help: ## Show this help
help:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

.PHONY: docs
docs: ## Generate docs
docs:
	poetry run make -C $(DOCS_DIR)/ html

.PHONY: clean-docs
clean-docs: ## Clean generated docs
clean-docs:
	poetry run make -C $(DOCS_DIR)/ clean

.PHONY: gh-pages
gh-pages: ## Push generated docs to the gh-pages branch
gh-pages:
	rm -rf $(HTML_DIR)/.git
	git -C $(HTML_DIR) init
	touch $(HTML_DIR)/.nojekyll
	git -C $(HTML_DIR)/ add .
	git -C $(HTML_DIR)/ commit \
		-m "Docs generated for $(shell git rev-parse --short HEAD) $(shell date)"
	git -C $(HTML_DIR)/ remote add github $(REMOTE)
	git -C $(HTML_DIR)/ push -f github master:gh-pages

