# claude-mux build
#
# `claude-mux` is a GENERATED, COMMITTED artifact: the single file that curl and
# Homebrew fetch. Source of truth is src/*.sh. Edit the fragments, run `make
# build`, then commit both src/ and the rebuilt claude-mux together.
#
# NEVER edit claude-mux directly. A direct edit is silently reverted by the next
# `make build`; the pre-commit hook and `make check` guard against it.
#
# Explicit MODULES list (not `src/*.sh`): glob order is lexical and a stray file
# in src/ would be swept in. The list pins concatenation order, which is
# load-bearing (the script runs top-to-bottom with imperative blocks interleaved
# between function defs, so module order = byte order of the shipped file).

MODULES = src/00-defaults.sh src/10-flags.sh src/20-config.sh \
          src/30-helpers.sh src/35-validate-deps.sh src/40-shutdown.sh \
          src/50-restore-state.sh src/55-session-launch.sh src/60-discovery.sh \
          src/70-start-launch.sh src/75-tip-notices.sh src/80-templates-restore.sh \
          src/90-dispatch.sh

.PHONY: build check lint smoke install-hooks

build: $(MODULES)
	cat $(MODULES) > claude-mux
	chmod +x claude-mux

# Drift guard: the committed artifact must match a fresh build from src/.
# Fails if a fragment was edited without rebuilding, or claude-mux was hand-edited.
check: build
	git diff --exit-code claude-mux

# Lint the BUILT file, not the fragments (fragments reference vars/functions
# defined in sibling fragments, so per-fragment shellcheck floods false positives).
lint: build
	bash -n claude-mux
	command -v shellcheck >/dev/null 2>&1 && shellcheck claude-mux || echo "shellcheck not installed; skipping"

# Point git at the tracked hooks (run once per clone; the drift guard is inert otherwise).
install-hooks:
	git config core.hooksPath .githooks
	@echo "core.hooksPath -> .githooks (pre-commit drift guard active)"

# Read-only smoke pass against the built file.
smoke: build
	./claude-mux --guide >/dev/null
	./claude-mux --commands >/dev/null
	./claude-mux --config-help >/dev/null
	./claude-mux --list-templates >/dev/null
	@echo "smoke OK"
