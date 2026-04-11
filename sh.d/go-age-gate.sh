
# Supply chain protection for Go modules

if command -v go > /dev/null 2>&1; then

  # go-cooldown proxy (github.com/imjasonh/go-cooldown) provides age-gating
  # at the GOPROXY level. If running locally, set:
  #   export GOPROXY=http://localhost:8080/10d,direct
  # The proxy returns 404 for modules newer than the window, causing go to
  # fall back to the next proxy or fail. Start it with:
  #   UPSTREAM_PROXY=https://proxy.golang.org go-cooldown
  #
  # Without go-cooldown, go-check-age below is an advisory check.

  # Advisory check: query proxy.golang.org for a module's publish timestamp.
  # Usage: go-check-age <module-path> [min-days]
  # Example: go-check-age golang.org/x/text 10
  go-check-age() {
    local pkg="${1:?Usage: go-check-age <module-path> [min-days]}"
    local min_days="${2:-10}"

    local info ts pkg_epoch now_epoch age_days

    info=$(curl -sf "https://proxy.golang.org/${pkg}/@latest" 2>/dev/null)
    if [ -z "$info" ]; then
      echo "WARNING: Could not query proxy.golang.org for $pkg" >&2
      return 1
    fi

    ts=$(printf '%s' "$info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Time',''))" 2>/dev/null)
    if [ -z "$ts" ]; then
      echo "WARNING: No timestamp in proxy response for $pkg" >&2
      return 1
    fi

    pkg_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null \
                || date -d "$ts" +%s 2>/dev/null)
    now_epoch=$(date +%s)
    age_days=$(( (now_epoch - pkg_epoch) / 86400 ))

    if [ "$age_days" -lt "$min_days" ]; then
      echo "BLOCKED: $pkg is only ${age_days} days old (minimum: ${min_days} days)" >&2
      echo "  To override: command go get $pkg" >&2
      return 1
    fi

    echo "OK: $pkg is ${age_days} days old (minimum: ${min_days})"
  }

  if command -v govulncheck > /dev/null 2>&1; then
    alias go-vulncheck='govulncheck ./...'
  fi

fi
