# AGENTS.md

Guidance for coding agents working in this repository.

## 1) Repository model
This project has two roles:
1. Chezmoi-managed dotfiles state (`home/`) for Linux + Windows.
2. A Python CLI (`python/src/dotfiles/main.py`) that drives docs and sync workflows.

Interpretation rule:
- `home/` is declarative desired state for `$HOME`.
- `python/src/` is imperative automation.

Key top-level files:
- `.chezmoiroot` -> `home`
- `python/pyproject.toml` -> packaging + script entrypoint
- `Makefile` -> wrappers for `uv run --project "python" dotfiles ...`
- `docs/` -> Sphinx documentation sources
- `README.rst` -> user-facing workflow notes

Generated artifacts (do not edit unless explicitly asked):
- `docs/_build/`
- `dist/`
- `__pycache__/`

## 2) Build/lint/test/verify commands
Run from repo root: `/home/vvnraman/.local/share/chezmoi`.

### Environment setup
- `uv sync --project python` - install/update dependencies.

### Build and package
- `uv build --project python` - build wheel/sdist into `dist/`.
- `uv run --project python dotfiles info` - quick CLI sanity check.

### Docs build and preview
- `make docs` or `uv run --project python dotfiles docs` - build HTML docs.
- `make live` or `uv run --project python dotfiles live` - live docs server.
- `make clean` or `uv run --project python dotfiles clean` - clean docs outputs.
- `uv run --project python dotfiles publish --dry-run` - preview docs publish commands.

### Lint/type checks
Configured tooling in `python/pyproject.toml`:
- BasedPyright config is present under `[tool.basedpyright]`.

Commands:
- `uv run --project python basedpyright` - run type checks for configured include/exclude.
- `uv run --project python basedpyright src ../docs` - targeted check.

Note:
- No dedicated `ruff`, `black`, `isort`, or `flake8` config is present currently.

### Tests
Current state:
- No committed automated test suite (`tests/` not present).

Practical verification commands:
- `uv run --project python dotfiles --help`
- `uv run --project python dotfiles info`
- `uv run --project python dotfiles docs`

If pytest tests are added later, use:
- All tests: `uv run --project python pytest`
- Single test file: `uv run --project python pytest tests/test_x.py`
- Single test: `uv run --project python pytest tests/test_x.py::test_name`

### Chezmoi verification
- `chezmoi status` - show managed target drift.
- `chezmoi diff` - preview destination changes.
- `chezmoi apply --dry-run` - safe preview apply.
- `chezmoi apply` - apply to `$HOME`.

## 3) Chezmoi conventions and structure
Preserve existing naming:
- `dot_*` => regular file/dir content
- `symlink_*` => symlink declarations
- `*.tmpl` => Go template files

Shared template/data locations:
- `home/.chezmoitemplates/os-config.tmpl`
- `home/.chezmoitemplates/user-config.tmpl`
- `home/.chezmoidata/fzf-fragments.toml`

Pattern for machine-specific behavior:
1. Compute normalized keys (`os-config`, `user-config`).
2. Use symlink templates to select concrete overlays.
3. Keep base files common; isolate differences in overlays.

Examples:
- Bash overlay selectors: `home/dot-bash/overlays/symlink_*.tmpl`
- Fish overlay selectors: `home/dot_config/fish/symlink_*.tmpl`
- Git OS selector: `home/dot_config/git/symlink_config.tmpl`

## 4) Python style guidelines
Scope: primarily `python/src/dotfiles/main.py`.

### Imports
- Group stdlib imports first, then third-party imports.
- Prefer explicit imports; avoid wildcard imports.
- Keep imports at module top unless local import is justified.

### Formatting/layout
- Follow PEP 8 and existing local formatting style.
- Keep functions command-focused and readable.
- Preserve existing CLI print conventions and UX tone.
- Use constants for repeated paths/literals.

### Types
- Add type hints for parameters and return values.
- Prefer modern built-in generics (`list[str]`, `str | None`).
- Keep BasedPyright output clean for changed code.

### Naming
- Functions/variables: `snake_case`.
- Constants: `UPPER_SNAKE_CASE`.
- CLI command functions should be verb-based (`docs`, `clean`, `publish`, etc.).

### Error handling
- Validate preconditions early and return early on failure.
- Handle subprocess failures intentionally.
- Catch narrow exceptions where possible.
- Surface actionable user-facing error messages.

### CLI safety
- Preserve `dry_run` support for potentially destructive operations.
- Preserve worktree/branch safety checks in sync/publish flows.
- Do not silently alter side effects in `publish` and `nvim` commands.

## 5) Shell/Fish/Tmux editing guidelines
- Keep bash/fish behavior aligned where intentionally mirrored.
- Prefer shared template/data fragments over duplicated strings.
- Keep shell syntax consistent with each file's shell language.
- Put OS-specific behavior in overlays when possible.
- Avoid breaking login shell startup paths (`.profile`, `.bashrc`, fish config chain).

## 6) Docs guidelines
- Source docs live under `docs/` as `.rst`.
- Keep toctree structure coherent (`intro`, `how-to`, `explanation`, `reference`, `tutorials`).
- Under `reference`, keep `project/` maintained with a clear overview in `project/index.rst`, plus `changelog.rst` and `plan.rst`.
- Keep project changelog entries concise (3-5 word summaries) and linked to dated files.
- Do not hand-edit files under `docs/_build/`.

### 6.0 How-to and reference writing preferences
- Prefer task-first runbook style: show runnable commands first, then short context.
- Keep pages concise and scannable: short sections, direct headings, minimal prose.
- Include operational guardrails explicitly (dry-run vs destructive behavior, branch/worktree preconditions).
- Include practical defaults and real-world usage notes when they affect command choice.
- For CLI reference pages, prefer generated command output snapshots under `docs/generated/` and include them with `literalinclude`.
- Exclude non-essential narrative (long rationale, abstract architecture, generic commentary) from how-to/reference pages.

### 6.1 Project changelog file conventions (`docs/reference/project/changelog/`)
- Use dated filename format: `YYYY-MM-mmm-<slug>.rst` (example: `2026-02-feb-restructure-bash-config-modules.rst`).
- In `changelog.rst`, visible labels must use month-key style (`YYYY-MM-mmm - ...`), not full day dates.
- In each dated changelog page:
  - Title remains `YYYY-MM mmm - <summary>`.
  - First subsection heading must be `YYYY-MM-DD - Day`.
  - Immediately after that heading, add exactly one plain sentence line (no `Summary:` prefix).
  - Use section heading `Change summary` (never `What changed in this commit`).
  - Use `:ref:` links to connect changelog entries to explanation pages and explanation pages back to changelog entries.

### 6.2 Explanation docs: mandatory writing style (`docs/explanation/`)
Write explanation pages as operational runbooks for maintainers.

Required style:
- Prefer procedural wording: use verbs like `loads`, `sources`, `includes`, `resolves`.
- Focus on runtime behavior and include order, not abstract architecture claims.
- Remove non-essential narrative (generic benefits, long rationale, repeated path explanations).
- Keep sections compact and scannable; avoid paragraph-heavy descriptions when a list is clearer.

Do not:
- Repeat full relative paths in bullets when the path is already shown in a file tree.
- Add broad statements that cannot be verified from config files.
- Keep sections that don't help a maintainer trace behavior.

### 6.3 Explanation docs: required structure pattern
For tool pages (bash, fish, tmux, git, lazygit), use this order unless a tool-specific exception is requested:
1. One concise intro stating intent and scope.
2. `High-level structure` with a compact tree block.
3. Short bullets using basenames only.
4. Load-order section(s):
   - implicit startup order (if relevant for the tool runtime), then
   - explicit repo-controlled load/include order.
5. `Relevant changelogs` with links to project entries.

Tool-specific defaults:
- `bash`: include both implicit (`.bash_profile`/`.profile`/`.bashrc`) and explicit `bashrc` layering.
- `fish`: include implicit startup order plus explicit OS/user overlay sourcing.
- `tmux` and `git`: prioritize explicit OS/user/environment include order.
- `lazygit`: keep focus on high-level structure unless explicit load behavior changes.

### 6.4 Literal include requirements
When documenting source/include edges, use `literalinclude` snippets from actual config files.

Each such snippet must include:
- `:lineno-match:`
- `:emphasize-lines:` highlighting the include/source/resolve line(s)
- `:caption:` with basename only (no full path)

Additional rules:
- Keep snippet ranges tight; include only lines needed to demonstrate the behavior.
- Ensure emphasized line numbers match the displayed snippet range.
- Rebuild docs after edits (`uv run --project python dotfiles docs`) and resolve warnings before finishing.

### 6.5 Explanation docs: layout generation and section conventions
Preserve the current explanation-page layout workflow for tool pages.

Directory layout section rules:
- Use heading `Directory layout`.
- Keep this section layout-only; do not add explanatory prose under the heading.
- Wrap the layout include in a `sphinx-design` dropdown.
- Dropdown label must be exactly `Show layout`.
- Use generated layout files from `docs/generated/`.
- For generated layout includes, use `:caption:` with the relative config directory path.
- Render generated layout includes with `:language: sh`.

Load-order heading rule:
- Use heading `Load order` (not tool-specific variants like `Git load order`).

Sphinx-generated layout implementation rules:
- Implement layout generation in Sphinx hooks within `docs/conf.py`.
- Generate snapshots into `docs/generated/`.
- Command preference order must be:
  1. `lsd --almost-all --tree`
  2. `tree`
  3. `ls -al <config-dir>/*`
- Resolve available tool choice once per build when possible.
- Write generated files only when content changes to prevent live-reload loops.
- Keep generated layout artifact extension as `.txt`.

## 7) Git and branch assumptions
- Existing scripts assume `master` in multiple places; keep this unless explicitly changing policy.
- Avoid destructive git operations unless explicitly requested.
- Avoid committing generated artifacts by default.
- Respect clean-worktree checks in workflows (especially `dotfiles nvim`).

## 8) Cursor/Copilot rules status
Checked these locations:
- `.cursor/rules/**`
- `.cursorrules`
- `.github/copilot-instructions.md`

Current status: no Cursor or Copilot rule files are present.
If such files are added later, treat them as authoritative and merge their guidance here.
