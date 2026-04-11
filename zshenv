# ~/.zshenv — sourced for ALL zsh instances: interactive, non-interactive, scripts, Makefiles.
# Keep this file to env-var exports only. No aliases, no functions, no prompts.
#
# PURPOSE: supply chain age-gate env vars must live here (not in .zshrc / sh.d)
# because shell functions defined in sh.d are NOT inherited by subshells, Makefiles,
# VS Code tasks, or any non-interactive process.

# --- uv (Python) ---
# Overrides user config AND per-project uv.toml; survives --no-config.
export UV_EXCLUDE_NEWER="10 days"

# --- pip (Python) ---
# Inherited by: python -m pip, pipx-launched pip, venv pip, Makefile pip calls.
# Requires pip >= 26.0; older pip silently ignores unknown env vars.
# Recomputed each shell start so the window rolls forward automatically.
export PIP_UPLOADED_PRIOR_TO="$(date -u -v-10d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '10 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"

# --- npm ---
# Env vars beat per-project .npmrc files (which could set min-release-age=0).
export NPM_CONFIG_MIN_RELEASE_AGE=10
export NPM_CONFIG_IGNORE_SCRIPTS=true

# --- Homebrew ---
# Prevent silent tap updates pulling in new (unreviewed) formula versions.
export HOMEBREW_NO_AUTO_UPDATE=1
# Uncomment to enable formula-age checks in the brew() wrapper (requires ~2GB tap clone):
#   export HOMEBREW_NO_INSTALL_FROM_API=1
# After setting, run once: brew tap homebrew/core
