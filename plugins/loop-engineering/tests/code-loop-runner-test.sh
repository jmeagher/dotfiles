#!/usr/bin/env bash
# Tests bin/code-loop's headless behavior: it drives each iteration with an
# INLINE prompt (not the /code-loop slash command, which does not load under
# `claude -p`), enforces the project's Verify command itself, aborts on
# reward-hacking, and bails with FAILURE after repeated no-progress iterations.
#
# Uses a git-committing stub `claude` on PATH, driven by CLAUDE_STUB_MODE, so
# the runner's real gate/hack/progress logic is exercised deterministically.
set -u
RUNNER="$(cd "$(dirname "$0")/../../.." && pwd)/bin/code-loop"
fails=0
root=$(mktemp -d)
promptlog="$root/prompt.txt"

mkdir -p "$root/stubbin"
cat > "$root/stubbin/claude" <<'STUB'
#!/usr/bin/env bash
# $1=-p $2=<prompt>. Record the prompt, then act per CLAUDE_STUB_MODE:
#   implement (default) do real work + commit; hack weaken a test + commit;
#   noop do nothing.
[ "${1:-}" = "-p" ] && printf '%s' "${2:-}" > "$CLAUDE_PROMPT_LOG"
check_off() { awk '!d && /^- \[ \]/ {sub(/^- \[ \]/,"- [x]"); d=1} {print}' TODO.md > t && mv t TODO.md; }
case "${CLAUDE_STUB_MODE:-implement}" in
  implement) touch DONE; check_off; git add -A; git commit -qm "stub: implement" ;;
  hack)      echo "exit 0" > tests/x_test.sh; touch DONE; check_off; git add -A; git commit -qm "stub: hack" ;;
  noop)      : ;;
esac
echo '{"result":"stub"}'
STUB
chmod +x "$root/stubbin/claude"

# Fresh git project whose Verify command passes only once a DONE marker exists.
mkproj() { # n_items -> prints project dir
  local n="$1" p k; p=$(mktemp -d)
  ( cd "$p" || exit 1
    git init -q; git config user.email t@t; git config user.name t
    # shellcheck disable=SC2016  # backticks are literal SPEC.md markup, not expansion
    printf '# Spec\n\n## Verification\nVerify: `bash verify.sh`\n\n## Rules\n- no cheating\n' > SPEC.md
    printf '[ -f DONE ]\n' > verify.sh
    mkdir -p tests; printf 'echo real test\n' > tests/x_test.sh
    : > TODO.md; for k in $(seq 1 "$n"); do printf -- '- [ ] item %s\n' "$k" >> TODO.md; done
    git add -A; git commit -qm baseline ) >/dev/null 2>&1
  printf '%s' "$p"
}

run() { # mode dir budget -> sets RC, OUT
  OUT=$( cd "$2" && CLAUDE_STUB_MODE="$1" CLAUDE_PROMPT_LOG="$promptlog" \
         PATH="$root/stubbin:$PATH" bash "$RUNNER" "$3" 2>&1 ); RC=$?
}
ok() { printf 'ok   - %s\n' "$1"; }
no() { fails=$((fails + 1)); printf 'FAIL - %s\n' "$1"; }

# 1. Happy path: real work -> exit 0, TODO complete.
d=$(mkproj 1); run implement "$d" 5
if [ "$RC" -eq 0 ] && ! grep -q '^- \[ \]' "$d/TODO.md" && printf '%s' "$OUT" | grep -q "TODO complete"; then
  ok "happy path completes (exit 0, TODO checked off)"
else
  no "happy path (rc=$RC, out: $OUT)"
fi
# ...driven by an inline prompt, not the slash command.
if grep -q '/code-loop' "$promptlog"; then
  no "prompt must NOT invoke the /code-loop slash command"
else
  ok "drives an inline prompt, not /code-loop"
fi
if grep -q 'bash verify.sh' "$promptlog"; then
  ok "inline prompt embeds the Verify command"
else
  no "inline prompt missing the Verify command"
fi

# 2. Reward-hacking: weaken a test -> abort exit 3.
d=$(mkproj 1); run hack "$d" 5
if [ "$RC" -eq 3 ] && printf '%s' "$OUT" | grep -q "reward-hacking detected"; then
  ok "aborts (exit 3) when the loop modifies a protected file"
else
  no "hack guard (rc=$RC, out: $OUT)"
fi

# 3. No verified progress: noop -> FAILURE exit 1 after MAX_STRIKES.
d=$(mkproj 1); run noop "$d" 9
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "FAILURE"; then
  ok "bails with FAILURE after repeated no-progress iterations"
else
  no "no-progress bail (rc=$RC, out: $OUT)"
fi

# 4. Budget exhaustion: fewer iterations than items -> exit 1 with message.
d=$(mkproj 2); run implement "$d" 1
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "Budget exhausted"; then
  ok "budget exhaustion exits 1 with message"
else
  no "budget exhaustion (rc=$RC, out: $OUT)"
fi

if [ "$fails" -eq 0 ]; then echo "ALL PASS"; else echo "$fails FAILURES"; exit 1; fi
