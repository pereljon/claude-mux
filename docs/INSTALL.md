# Installation

## Requirements

- macOS (Apple Silicon or Intel)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## curl (recommended)

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Downloads the binary, installs it to `~/bin`, adds it to `PATH`, and runs interactive setup. Works on macOS and Linux (Linux: LaunchAgent step skipped).

To update:

```bash
claude-mux --update     # works from inside any session, or from the terminal
```

## Homebrew (macOS alternative)

```bash
brew tap pereljon/tap
brew trust pereljon/tap   # see note below
brew install claude-mux
claude-mux --install
```

**Trust the tap.** Recent Homebrew skips updating untrusted third-party taps, printing `Warning: Skipping pereljon/tap because it is not trusted` on `brew update`. Until you run `brew trust pereljon/tap`, Homebrew won't refresh the tap, so `brew update` / `brew upgrade claude-mux` won't see new releases. This is a one-time, per-tap step.

To update:

```bash
brew upgrade claude-mux
```

## Manual

```bash
./install.sh
```

`install.sh` copies the binary to `~/bin` and adds it to `PATH`. After that, run:

```bash
claude-mux --install
```

The interactive setup asks where your Claude projects live, whether to start a home session at login, and which model to use. It creates `~/.claude-mux/config` and installs the LaunchAgent.

Use `--non-interactive` to skip prompts and accept defaults.

Options:

```bash
claude-mux --install --non-interactive                     # skip prompts, use defaults
claude-mux --install --base-dir ~/work/claude              # use a different base directory
claude-mux --install --launchagent-mode none               # disable LaunchAgent behavior
claude-mux --install --home-model haiku                    # use Haiku for home session
claude-mux --install --no-launchagent                      # skip LaunchAgent installation entirely
```

The LaunchAgent runs `claude-mux --autolaunch` at login with a 45-second startup delay to allow system services to initialize.

## Uninstall

```bash
claude-mux --uninstall
```

This removes tip hooks and permission rules from all projects, unloads the LaunchAgent, and optionally removes `~/.claude-mux/`. It reports the binary path so you can delete it manually (or `brew uninstall claude-mux` if installed via Homebrew).
