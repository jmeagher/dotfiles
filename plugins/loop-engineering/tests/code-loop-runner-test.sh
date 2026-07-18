#!/usr/bin/env bash
# Tests bin/code-loop's headless behavior: it drives each iteration with an
# INLINE prompt (not the /code-loop slash command, which does not load under
# `claude -p`), enforces the project's Verify command itself, aborts on
# reward-hacking, and bails with FAILURE after repeated no-progress iterations.
# Loop state is per-project under loops/<name>/; the runner takes the project
# name as its first argument.
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
#   noop do nothing. CLAUDE_STUB_TODO points at the project's TODO.md.
[ "${1:-}" = "-p" ] && printf '%s' "${2:-}" > "$CLAUDE_PROMPT_LOG"
check_off() { awk '!d && /^- \[ \]/ {sub(/^- \[ \]/,"- [x]"); d=1} {print}' "$CLAUDE_STUB_TODO" > t && mv t "$CLAUDE_STUB_TODO"; }
case "${CLAUDE_STUB_MODE:-implement}" in
  implement) touch DONE; check_off; git add -A; git commit -qm "stub: implement" ;;
  hack)      echo "exit 0" > tests/x_test.sh; touch DONE; check_off; git add -A; git commit -qm "stub: hack" ;;
  noop)      : ;;
esac
echo '{"result":"stub"}'
STUB
chmod +x "$root/stubbin/claude"

# Fresh git repo with one loop project whose Verify command passes only once a
# DONE marker exists. mkproj <project> <n_items> -> prints repo dir.
mkproj() {
  local proj="$1" n="$2" p k; p=$(mktemp -d)
  ( cd "$p" || exit 1
    git init -q; git config user.email t@t; git config user.name t
    addproj "$p" "$proj" "$n"
    printf '[ -f DONE ]\n' > verify.sh
    mkdir -p tests; printf 'echo real test\n' > tests/x_test.sh
    git add -A; git commit -qm baseline ) >/dev/null 2>&1
  printf '%s' "$p"
}

# Add a loop project dir to an existing repo (no commit).
addproj() { # repo project n_items
  local p="$1" proj="$2" n="$3" k
  mkdir -p "$p/loops/$proj"
  # shellcheck disable=SC2016  # backticks are literal SPEC.md markup, not expansion
  printf '# Spec\n\n## Verification\nVerify: `bash verify.sh`\n\n## Rules\n- no cheating\n' > "$p/loops/$proj/SPEC.md"
  : > "$p/loops/$proj/TODO.md"
  for k in $(seq 1 "$n"); do printf -- '- [ ] item %s\n' "$k" >> "$p/loops/$proj/TODO.md"; done
  printf '# Loop Log\n' > "$p/loops/$proj/LOOP_LOG.md"
}

run() { # mode dir project budget -> sets RC, OUT
  OUT=$( cd "$2" && CLAUDE_STUB_MODE="$1" CLAUDE_PROMPT_LOG="$promptlog" \
         CLAUDE_STUB_TODO="loops/$3/TODO.md" \
         PATH="$root/stubbin:$PATH" bash "$RUNNER" "$3" "$4" 2>&1 ); RC=$?
}
ok() { printf 'ok   - %s\n' "$1"; }
no() { fails=$((fails + 1)); printf 'FAIL - %s\n' "$1"; }

# 1. Happy path: real work -> exit 0, TODO complete.
d=$(mkproj alpha 1); run implement "$d" alpha 5
if [ "$RC" -eq 0 ] && ! grep -q '^- \[ \]' "$d/loops/alpha/TODO.md" && printf '%s' "$OUT" | grep -q "TODO complete"; then
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
if grep -q 'loops/alpha/TODO.md' "$promptlog"; then
  ok "inline prompt references the project-scoped TODO path"
else
  no "inline prompt missing project-scoped TODO path"
fi

# 2. Missing project argument -> usage error exit 2.
d=$(mkproj alpha 1)
OUT=$( cd "$d" && PATH="$root/stubbin:$PATH" bash "$RUNNER" 2>&1 ); RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -qi "usage"; then
  ok "missing project argument exits 2 with usage"
else
  no "missing project argument (rc=$RC, out: $OUT)"
fi

# 3. Unknown project -> exit 2, lists available projects.
d=$(mkproj alpha 1)
OUT=$( cd "$d" && PATH="$root/stubbin:$PATH" bash "$RUNNER" nosuch 2>&1 ); RC=$?
if [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q "alpha"; then
  ok "unknown project exits 2 and lists available projects"
else
  no "unknown project (rc=$RC, out: $OUT)"
fi

# 4. Reward-hacking: weaken a test -> abort exit 3.
d=$(mkproj alpha 1); run hack "$d" alpha 5
if [ "$RC" -eq 3 ] && printf '%s' "$OUT" | grep -q "reward-hacking detected"; then
  ok "aborts (exit 3) when the loop modifies a protected file"
else
  no "hack guard (rc=$RC, out: $OUT)"
fi

# 5. No verified progress: noop -> FAILURE exit 1 after MAX_STRIKES.
d=$(mkproj alpha 1); run noop "$d" alpha 9
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "FAILURE"; then
  ok "bails with FAILURE after repeated no-progress iterations"
else
  no "no-progress bail (rc=$RC, out: $OUT)"
fi

# 6. Budget exhaustion: fewer iterations than items -> exit 1 with message.
d=$(mkproj alpha 2); run implement "$d" alpha 1
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "Budget exhausted"; then
  ok "budget exhaustion exits 1 with message"
else
  no "budget exhaustion (rc=$RC, out: $OUT)"
fi

# 7. Isolation: running project alpha leaves project beta's files untouched.
d=$(mkproj alpha 1); addproj "$d" beta 2
( cd "$d" && git add -A && git commit -qm "add beta" ) >/dev/null 2>&1
run implement "$d" alpha 5
if [ "$RC" -eq 0 ] && [ "$(grep -c '^- \[ \]' "$d/loops/beta/TODO.md")" -eq 2 ]; then
  ok "other project's TODO untouched"
else
  no "isolation (rc=$RC, beta TODO: $(cat "$d/loops/beta/TODO.md" 2>/dev/null))"
fi

if [ "$fails" -eq 0 ]; then echo "ALL PASS"; else echo "$fails FAILURES"; exit 1; fi
