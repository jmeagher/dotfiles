#!/usr/bin/env bash
# shellcheck disable=SC2015
# SC2015: Intentional pattern — lines use [ ... ] && ... || { ...; } for control flow.
# Tests bin/code-loop using a stub `claude` that checks off one TODO item per call.
set -u
RUNNER="$(cd "$(dirname "$0")/../../.." && pwd)/bin/code-loop"
fails=0
tmp=$(mktemp -d)

mkdir -p "$tmp/stubbin"
cat > "$tmp/stubbin/claude" <<'EOF'
#!/usr/bin/env bash
# Stub: mark the first unchecked TODO item done, echo a fake JSON result.
# awk (not sed) — GNU sed's 0,/re/ address form does not exist on macOS BSD sed.
awk '!done && /^- \[ \]/ { sub(/^- \[ \]/, "- [x]"); done = 1 } { print }' TODO.md > TODO.md.new
mv TODO.md.new TODO.md
echo '{"result":"stub iteration"}'
EOF
chmod +x "$tmp/stubbin/claude"

touch "$tmp/SPEC.md"   # the runner preflights for SPEC.md too
printf '# TODO\n- [ ] task one\n- [ ] task two\n' > "$tmp/TODO.md"

( cd "$tmp" && PATH="$tmp/stubbin:$PATH" bash "$RUNNER" 5 > out.txt 2>&1 )
rc=$?

[ "$rc" -eq 0 ] || { echo "FAIL: expected exit 0, got $rc"; fails=$((fails+1)); }
grep -q '^- \[ \]' "$tmp/TODO.md" && { echo "FAIL: unchecked items remain"; fails=$((fails+1)); }
grep -q "TODO complete" "$tmp/out.txt" || { echo "FAIL: missing completion message"; fails=$((fails+1)); }

# Budget exhaustion: 1 iteration on a 2-item list must exit 1 and say so.
printf '# TODO\n- [ ] a\n- [ ] b\n' > "$tmp/TODO.md"
( cd "$tmp" && PATH="$tmp/stubbin:$PATH" bash "$RUNNER" 1 > out2.txt 2>&1 )
[ $? -eq 1 ] && grep -q "Budget exhausted" "$tmp/out2.txt" || { echo "FAIL: budget exhaustion case"; fails=$((fails+1)); }

[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILURES"; exit 1; }
