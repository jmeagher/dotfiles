
# Supply chain protection: block pip install/download of packages < 10 days old.
#
# This shell function intercepts bare `pip` / `pip3` invocations only.
# The following paths BYPASS this function and are covered by PIP_UPLOADED_PRIOR_TO
# in ~/.zshenv instead (which is inherited by all processes):
#   - python -m pip install
#   - ./venv/bin/pip install
#   - pipx install
#   - scripts, Makefiles, IDE tasks
#
# If pip < 26.0 is detected, the flag is not injected (unknown option = hard fail),
# and a warning is printed instead so the user knows protection is absent.
# Bypass: command pip install <pkg>

_pip_age_cutoff() {
  date -u -v-10d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -d '10 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null
}

_pip_supports_age_gate() {
  local ver
  ver=$(command "${1:-pip}" --version 2>/dev/null | awk '{print $2}' | cut -d. -f1)
  [ -n "$ver" ] && [ "$ver" -ge 26 ] 2>/dev/null
}

pip() {
  local subcmd="$1"
  case "$subcmd" in
    install|download)
      shift
      if _pip_supports_age_gate pip; then
        local cutoff
        cutoff="$(_pip_age_cutoff)"
        if [ -n "$cutoff" ]; then
          command pip "$subcmd" --uploaded-prior-to "$cutoff" "$@"
        else
          echo "WARNING: could not compute age cutoff; running pip without age gate" >&2
          command pip "$subcmd" "$@"
        fi
      else
        echo "WARNING: pip < 26.0 detected; --uploaded-prior-to not supported." >&2
        echo "         Age gate is inactive for this pip. Upgrade: pip install --upgrade pip" >&2
        command pip "$subcmd" "$@"
      fi
      ;;
    *)
      command pip "$@"
      ;;
  esac
}

pip3() {
  local subcmd="$1"
  case "$subcmd" in
    install|download)
      shift
      if _pip_supports_age_gate pip3; then
        local cutoff
        cutoff="$(_pip_age_cutoff)"
        if [ -n "$cutoff" ]; then
          command pip3 "$subcmd" --uploaded-prior-to "$cutoff" "$@"
        else
          echo "WARNING: could not compute age cutoff; running pip3 without age gate" >&2
          command pip3 "$subcmd" "$@"
        fi
      else
        echo "WARNING: pip3 < 26.0 detected; --uploaded-prior-to not supported." >&2
        echo "         Age gate is inactive. Upgrade: pip3 install --upgrade pip" >&2
        command pip3 "$subcmd" "$@"
      fi
      ;;
    *)
      command pip3 "$@"
      ;;
  esac
}
