
# Supply chain protection for Homebrew.
# Wraps 'brew install', 'brew reinstall', and 'brew upgrade' with an age check.
# Blocks bare 'brew upgrade' (no args) because it upgrades all formulae at once.
# Bypass: command brew install <formula>

if command -v brew > /dev/null 2>&1; then

  # Internal helper: check one formula/cask name against the local tap.
  # Returns 0 (OK), 1 (blocked), 2 (tap not available — caller decides).
  _brew_check_age() {
    local name="$1"
    local min_days="${2:-10}"
    local is_cask="${3:-}"

    local tap_path subdir
    tap_path="$(brew --prefix)/Library/Taps/homebrew"

    if [ -n "$is_cask" ]; then
      subdir="$tap_path/homebrew-cask/Casks"
      # Cask files live under a single-letter subdirectory
      local first_char
      first_char="$(printf '%s' "$name" | cut -c1)"
      local formula_file="$subdir/$first_char/$name.rb"
      [ -f "$formula_file" ] || formula_file="$subdir/$name.rb"
    else
      subdir="$tap_path/homebrew-core/Formula"
      local first_char
      first_char="$(printf '%s' "$name" | cut -c1)"
      local formula_file="$subdir/$first_char/$name.rb"
      [ -f "$formula_file" ] || formula_file="$subdir/$name.rb"
    fi

    if [ ! -d "$tap_path/homebrew-core" ] && [ -z "$is_cask" ]; then
      # Tap not cloned; caller handles this
      return 2
    fi

    if [ ! -f "$formula_file" ]; then
      echo "INFO: No local formula file found for '$name'; skipping age check." >&2
      return 0
    fi

    # Use committer date (%ci) — harder to backdate than author date (%ai)
    local commit_date
    local tap_dir
    tap_dir="$(dirname "$(dirname "$formula_file")")"
    commit_date=$(git -C "$tap_dir" log -1 --format="%ci" -- "$formula_file" 2>/dev/null | awk '{print $1}')

    if [ -z "$commit_date" ]; then
      echo "WARNING: Could not determine formula age for '$name'; allowing install." >&2
      return 0
    fi

    local formula_epoch now_epoch age_days
    formula_epoch=$(date -j -f "%Y-%m-%d" "$commit_date" +%s 2>/dev/null \
                    || date -d "$commit_date" +%s 2>/dev/null)
    now_epoch=$(date +%s)
    age_days=$(( (now_epoch - formula_epoch) / 86400 ))

    if [ "$age_days" -lt "$min_days" ]; then
      echo "BLOCKED: '$name' formula last modified ${age_days} days ago (minimum: ${min_days})." >&2
      echo "         Wait $((min_days - age_days)) more days, or bypass: command brew $subcmd $name" >&2
      return 1
    fi

    return 0
  }

  _brew_tap_missing_message() {
    echo "BLOCKED: homebrew-core tap not cloned; cannot verify formula age." >&2
    echo "  To enable age checks (one-time, ~2 GB):" >&2
    echo "    export HOMEBREW_NO_INSTALL_FROM_API=1  # add to ~/.zshenv" >&2
    echo "    brew tap homebrew/core" >&2
    echo "  To bypass age check: command brew $*" >&2
  }

  brew() {
    local subcmd="$1"
    case "$subcmd" in

      install|reinstall)
        shift
        local is_cask=""
        local names=()
        for arg in "$@"; do
          case "$arg" in
            --cask) is_cask="1" ;;
            --*) ;;   # skip other flags
            *) names+=("$arg") ;;
          esac
        done

        if [ -n "$is_cask" ]; then
          echo "INFO: Cask installs cannot be age-checked; proceeding." >&2
        else
          for name in "${names[@]:-}"; do
            [ -z "$name" ] && continue
            _brew_check_age "$name" 10 "$is_cask"
            local rc=$?
            if [ $rc -eq 2 ]; then
              _brew_tap_missing_message "$subcmd" "$@"
              return 1
            elif [ $rc -ne 0 ]; then
              return 1
            fi
          done
        fi
        command brew "$subcmd" "$@"
        ;;

      upgrade)
        if [ $# -eq 1 ]; then
          # bare 'brew upgrade' — upgrades everything; too risky to do unreviewed
          echo "BLOCKED: 'brew upgrade' (no arguments) upgrades all formulae at once." >&2
          echo "  Upgrade packages individually after checking age:" >&2
          echo "    brew outdated" >&2
          echo "    brew upgrade <formula>   # age-gated per-formula" >&2
          echo "  To bypass: command brew upgrade" >&2
          return 1
        fi
        shift
        for arg in "$@"; do
          case "$arg" in --*) continue ;; esac
          _brew_check_age "$arg" 10
          local rc=$?
          if [ $rc -eq 2 ]; then
            _brew_tap_missing_message "upgrade" "$@"
            return 1
          elif [ $rc -ne 0 ]; then
            return 1
          fi
        done
        command brew upgrade "$@"
        ;;

      *)
        command brew "$@"
        ;;
    esac
  }

fi
