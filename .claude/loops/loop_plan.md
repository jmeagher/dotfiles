# Development Loops (Agentic Coding Loop + Developer Feedback Loop) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first two loops from the loop-engineering article as a reusable Claude Code plugin in this dotfiles repo: an agentic coding loop (`/loop-init` + `/code-loop` + a Stop-hook verification gate + an outer fresh-context runner) and a developer feedback loop (`/feedback`).

**Architecture:** One new plugin, `plugins/loop-engineering/`, following the existing jpm/jmeagher-notifications conventions (commands as `.md` files with `allowed-tools` frontmatter, hooks via `hooks/hooks.json` + `${CLAUDE_PLUGIN_ROOT}` script, explicit registration in `.claude-plugin/marketplace.json`). Loop state lives in files inside the *target* project (`SPEC.md`, `TODO.md`, `LOOP_LOG.md`, and a gitignored `.loop/` runtime dir), never in conversation context. Completion is gated deterministically: a Stop hook runs the project's verify command and blocks the agent from stopping until it passes or an escalation budget is exhausted.

**Tech Stack:** Claude Code plugin system (commands, hooks), bash + jq for the hook and runner, `claude -p` headless mode for the outer loop.

## Design rationale (from research)

Ranked principles this plan implements (sources: Boris Cherny / howborisusesclaudecode.com, Geoff Huntley's Ralph Wiggum pattern, Anthropic's ralph-wiggum plugin README, SpecBench reward-hacking findings, GitHub Spec Kit):

1. **Verification is the product.** A loop without a machine-checkable "something that says no" is just an agent talking to itself. `/code-loop` refuses to run without a verify command in SPEC.md.
2. **Gate completion with a Stop hook, not model self-report.** Exit code 2 + stderr feeds failures back to Claude; exit 0 permits stop.
3. **Hard budgets everywhere.** Max iterations per session, escalation counter in the hook (3 consecutive failed-verify blocks → forced stop with FAILURE report). Never string-match a "completion promise."
4. **State lives in files, not context.** `SPEC.md` (what + definition of done + verify commands), `TODO.md` (prioritized backlog), `LOOP_LOG.md` (append-only run log), `.loop/` (runtime gate state). Fresh context per iteration in the outer runner avoids context rot.
5. **One task per iteration.** Prevents context exhaustion, placeholder code, and duplicate implementations.
6. **Anti-reward-hacking rules are written into the spec and the gate.** "All checks stay enabled; never modify tests, the verifier, `.loop/`, or the Verification section of SPEC.md to make verification pass."
7. **The developer feedback loop's output is always a durable artifact** — a SPEC.md diff, a TODO.md item, or a CLAUDE.md rule — never only a chat reply.

**Why build this instead of using the official ralph-wiggum plugin or `/loop`?** ralph-wiggum gates on an exact-match completion-promise string (brittle, and it's model self-report); `/loop` handles cadence but not verification. This plugin gates on the *project's actual verify command* and adds the feedback-loop half, which no existing plugin covers. The built-ins remain composable with it (e.g. `/loop 30m /feedback` nudges).

**Known limitation (accepted for personal tooling):** the gated agent could in principle edit SPEC.md's Verification section or `.loop/verify` to weaken the gate — or simply run `rm -f .loop/active`, the same disarm step it is given for legitimate completion. The gate's honest value is preventing *accidental* premature stops (by far the common failure), not stopping an adversarial agent. Mitigations: the rule is stated in every prompt, `/code-loop` snapshots the verify command at arm time, and `/feedback` reviews diffs so a weakened verifier is visible to the human. A cryptographic gate is out of scope.

## Global Constraints

- Never commit to main — all work on feature branch `loop-engineering-plugin`.
- New plugin MUST be registered in `.claude-plugin/marketplace.json` (`source: "./plugins/loop-engineering"`, `category: "productivity"`) — the marketplace does not auto-scan.
- Plugin manifest shape: `{name, version, description, author: {name}, license}` in `plugins/<name>/.claude-plugin/plugin.json`.
- Command `.md` convention: YAML frontmatter with `allowed-tools` + `description`; body has `## Context` (with `` !`cmd` `` live injection) and `## Your task` sections.
- Hook convention: `hooks/hooks.json` referencing scripts via `${CLAUDE_PLUGIN_ROOT}`; scripts read hook JSON from stdin and must exit 0 fast when not applicable (the Stop hook fires in EVERY project once the plugin is installed).
- All bash must pass `shellcheck`. Install it first if missing: `command -v shellcheck || brew install shellcheck`.
- The `.loop/` runtime dir in target projects is gitignored via a self-contained `.loop/.gitignore` containing `*` (same pattern as the remember plugin's `.remember/`).

---

### Task 1: Plugin scaffold + marketplace registration

**Files:**
- Create: `plugins/loop-engineering/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

**Interfaces:**
- Produces: an installable (empty) plugin named `loop-engineering` that Tasks 2–6 add commands/hooks to.

- [ ] **Step 1: Create feature branch**

```bash
cd /Users/jmeagher/devel/dotfiles
git switch -c loop-engineering-plugin
```

- [ ] **Step 2: Write the plugin manifest**

Create `plugins/loop-engineering/.claude-plugin/plugin.json`:

```json
{
  "name": "loop-engineering",
  "version": "0.1.0",
  "description": "Development loops: agentic coding loop with verification gate, and developer feedback loop",
  "author": {
    "name": "jmeagher"
  },
  "license": "MIT"
}
```

- [ ] **Step 3: Register in the marketplace index**

In `.claude-plugin/marketplace.json`, add to the `plugins` array (after the existing `jpm` entry):

```json
{
  "name": "loop-engineering",
  "description": "Development loops: agentic coding loop with verification gate, and developer feedback loop",
  "version": "0.1.0",
  "author": {
    "name": "jmeagher"
  },
  "source": "./plugins/loop-engineering",
  "category": "productivity"
}
```

- [ ] **Step 4: Validate JSON**

Run: `jq . .claude-plugin/marketplace.json plugins/loop-engineering/.claude-plugin/plugin.json`
Expected: both documents print with no parse error.

- [ ] **Step 5: Commit**

```bash
git add plugins/loop-engineering .claude-plugin/marketplace.json
git commit -m "feat(loop-engineering): scaffold plugin and register in marketplace"
```

---

### Task 2: `/loop-init` command — scaffold loop state files in a target project

**Files:**
- Create: `plugins/loop-engineering/commands/loop-init.md`

**Interfaces:**
- Produces: in the *target* project, `SPEC.md` (sections: Goal, Requirements, Definition of Done, Verification, Rules), `TODO.md` (checkbox backlog), `LOOP_LOG.md` (append-only). Tasks 3–6 consume these exact section names: `/code-loop` parses `## Verification` for the `Verify:` line; the Stop hook reads `.loop/verify`; `/feedback` appends `## REVIEW` entries to `LOOP_LOG.md`.

- [ ] **Step 1: Write the command file**

Create `plugins/loop-engineering/commands/loop-init.md`:

````markdown
---
allowed-tools: Read, Write, Bash(ls:*), Bash(cat:*)
description: Scaffold loop-engineering state files (SPEC.md, TODO.md, LOOP_LOG.md) in the current project
---

## Context

- Existing SPEC.md: !`cat SPEC.md 2>/dev/null || echo "MISSING"`
- Existing TODO.md: !`cat TODO.md 2>/dev/null || echo "MISSING"`
- Project files: !`ls`

## Your task

Scaffold the loop state files for this project. Arguments (optional project description): $ARGUMENTS

1. If SPEC.md already exists, STOP and tell the user it exists — never overwrite it.
2. Interview the user briefly (one round of questions max) for anything you cannot infer from the project: the goal, the 3–7 core requirements, and the exact shell commands to build, test, and run this project.
3. Write `SPEC.md` with EXACTLY these sections:

```markdown
# Spec: <project name>

## Goal
<one paragraph>

## Requirements
- <requirement>

## Definition of Done
- [ ] `<verify command>` exits 0
- [ ] <each measurable criterion — numbers, not adjectives>

## Verification
Verify: `<single command that builds + tests; exits non-zero on any failure>`
Run: `<command to launch the app locally>`

## Rules
- All checks stay enabled. Never modify tests, linters, the Verification
  section of this file, or anything under .loop/ to make verification pass.
- No placeholder or stub implementations. Complete, working code only.
- One TODO item per iteration: implement, verify, commit, update TODO.md.
- When a decision changes the spec, edit this file in the same commit.
- If you learn a project-specific lesson, append it to CLAUDE.md.
```

4. Write `TODO.md`:

```markdown
# TODO
<!-- One `- [ ]` item per line, highest priority first. /code-loop works top-down, one item per iteration. -->

- [ ] <first task>
```

   Derive initial items from the Requirements; each item must be completable in one loop iteration (roughly one focused change + its tests).
5. Write `LOOP_LOG.md` containing only the line `# Loop Log` — it is append-only from here on.
6. Confirm the Verify command actually runs (`Bash` it once); if it fails on a fresh scaffold, that is fine — report the output so the user knows the starting state.
7. Tell the user: review/edit SPEC.md, then run `/code-loop` to start the loop.

Do only these steps — no other actions.
````

- [ ] **Step 2: Validate frontmatter and structure**

Run: `head -5 plugins/loop-engineering/commands/loop-init.md`
Expected: first line `---`, contains `allowed-tools:` and `description:` keys, closes with `---`.

- [ ] **Step 3: Commit**

```bash
git add plugins/loop-engineering/commands/loop-init.md
git commit -m "feat(loop-engineering): /loop-init scaffolding command"
```

---

### Task 3: Stop-hook verification gate (TDD)

**Files:**
- Create: `plugins/loop-engineering/hooks/verify-gate.sh`
- Create: `plugins/loop-engineering/hooks/session-cleanup.sh`
- Create: `plugins/loop-engineering/hooks/hooks.json`
- Test: `plugins/loop-engineering/tests/verify-gate-test.sh`

**Interfaces:**
- Consumes: `.loop/active` (marker file; gate is armed iff present), `.loop/verify` (the verify command, one line), `.loop/blocks` (consecutive-failure counter) — all written by `/code-loop` (Task 4) in the target project's cwd.
- Produces: Stop-hook behavior — verify runs FIRST, so a passing project always unblocks even with a stale counter: exit 0 (allow stop) when the gate is disarmed or verify passes; exit 2 with failure output on stderr (Claude must continue) when verify fails; the **3rd consecutive failure** disarms the gate and issues one final exit-2 demanding a FAILURE report. A SessionStart hook clears stale gate state left by crashed/abandoned runs, so an armed-but-dead gate can never trap an unrelated future session.

- [ ] **Step 1: Write the failing test script**

Create `plugins/loop-engineering/tests/verify-gate-test.sh`:

```bash
#!/usr/bin/env bash
# Tests for verify-gate.sh and session-cleanup.sh. Each case runs in its own temp dir.
set -u
HOOKS_DIR="$(cd "$(dirname "$0")/../hooks" && pwd)"
GATE="$HOOKS_DIR/verify-gate.sh"
CLEANUP="$HOOKS_DIR/session-cleanup.sh"
fails=0

run_gate() { # $1=tmpdir — feeds Stop-hook JSON on stdin, stderr captured
  printf '{"hook_event_name":"Stop","cwd":"%s","stop_hook_active":false}' "$1" \
    | "$GATE" >/dev/null 2>"$1/stderr.txt"
}

new_case() { # $1=setup commands, run inside a fresh temp dir; echoes the dir
  local tmp; tmp=$(mktemp -d)
  ( cd "$tmp" && eval "$1" )
  echo "$tmp"
}

check() { # $1=name $2=expected $3=actual
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 — expected $2, got $3"
    fails=$((fails + 1))
  fi
}

# 1. Gate not armed → allow stop immediately.
t=$(new_case "true")
run_gate "$t"; check "disarmed gate allows stop" 0 $?

# 2. Armed, verify passes → allow stop and disarm.
t=$(new_case "mkdir .loop && touch .loop/active && echo 'true' > .loop/verify")
run_gate "$t"; check "passing verify allows stop" 0 $?
[ ! -f "$t/.loop/active" ]; check "passing verify disarms gate" 0 $?

# 3. Verify-before-escalate: passing verify with a stale maxed counter still allows stop.
t=$(new_case "mkdir .loop && touch .loop/active && echo 'true' > .loop/verify && echo 3 > .loop/blocks")
run_gate "$t"; check "stale counter with passing verify allows stop" 0 $?

# 4. Armed, verify fails → block (exit 2), counter incremented to 1.
t=$(new_case "mkdir .loop && touch .loop/active && echo 'false' > .loop/verify")
run_gate "$t"; check "failing verify blocks stop" 2 $?
check "blocks counter incremented" "1" "$(cat "$t/.loop/blocks")"

# 5. Third consecutive failure → final block that disarms and demands a FAILURE report.
t=$(new_case "mkdir .loop && touch .loop/active && echo 'false' > .loop/verify && echo 2 > .loop/blocks")
run_gate "$t"; check "third failure still blocks" 2 $?
[ ! -f "$t/.loop/active" ]; check "third failure disarms gate" 0 $?
grep -q "FAILURE report" "$t/stderr.txt"; check "third failure demands FAILURE report" 0 $?

# 6. Malformed/missing verify file while armed → fail safe: allow stop (never trap the user).
t=$(new_case "mkdir .loop && touch .loop/active")
run_gate "$t"; check "missing verify file allows stop" 0 $?

# 7. Backtick residue from sloppy extraction is stripped, not treated as command substitution.
t=$(new_case "mkdir .loop && touch .loop/active && printf '%s\n' '\`true\`' > .loop/verify")
run_gate "$t"; check "backtick-wrapped verify still runs" 0 $?

# 8. SessionStart cleanup clears stale gate state.
t=$(new_case "mkdir .loop && touch .loop/active && echo 2 > .loop/blocks")
printf '{"hook_event_name":"SessionStart","cwd":"%s"}' "$t" | "$CLEANUP" >/dev/null 2>&1
check "session cleanup exits 0" 0 $?
[ ! -f "$t/.loop/active" ] && [ ! -f "$t/.loop/blocks" ]; check "session cleanup removes gate state" 0 $?

[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILURES"; exit 1; }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash plugins/loop-engineering/tests/verify-gate-test.sh`
Expected: FAIL on every case (the hook scripts do not exist yet).

- [ ] **Step 3: Write the hook scripts**

Create `plugins/loop-engineering/hooks/verify-gate.sh`:

```bash
#!/usr/bin/env bash
# Stop-hook verification gate for the loop-engineering plugin.
# Allows the agent to stop only when the project's verify command passes,
# or after MAX_BLOCKS consecutive failures (then demands a FAILURE report).
# stop_hook_active is deliberately NOT checked: the docs' "exit 0 if true"
# pattern would defeat the gate; the blocks counter bounds re-blocking instead.
set -u
MAX_BLOCKS=3

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
cd "$cwd" || exit 0

# Gate only applies while /code-loop has armed it in this project.
[ -f .loop/active ] || exit 0
# Strip backtick residue in case extraction from SPEC.md was sloppy.
verify_cmd=$(head -1 .loop/verify 2>/dev/null | tr -d '`')
[ -n "$verify_cmd" ] || exit 0   # fail safe: never trap a session on broken state

# Verify FIRST: a passing project always unblocks, even if a stale counter
# is left over from a crashed run.
if output=$(bash -c "$verify_cmd" 2>&1); then
  rm -f .loop/active .loop/blocks
  exit 0
fi

blocks=$(cat .loop/blocks 2>/dev/null || echo 0)
case "$blocks" in (*[!0-9]*|'') blocks=0;; esac
blocks=$((blocks + 1))

if [ "$blocks" -ge "$MAX_BLOCKS" ]; then
  rm -f .loop/active .loop/blocks
  echo "Verification has failed $MAX_BLOCKS consecutive times. The gate is now DISARMED. Append a FAILURE report to LOOP_LOG.md (what is broken, what you tried, what a human should look at), then stop." >&2
  exit 2
fi

echo "$blocks" > .loop/blocks
{
  echo "STOP BLOCKED: verify command failed ($blocks/$MAX_BLOCKS): $verify_cmd"
  echo "Fix the failure (do NOT weaken tests or the verifier), update LOOP_LOG.md, then try again. Output (last 2000 chars):"
  printf '%s' "$output" | tail -c 2000
} >&2
exit 2
```

Create `plugins/loop-engineering/hooks/session-cleanup.sh`:

```bash
#!/usr/bin/env bash
# SessionStart hook: a fresh session is never legitimately mid-gate, so clear
# any stale gate state left by a crashed or abandoned /code-loop run.
# (Sessions spawned by bin/code-loop re-arm via /code-loop after this fires.)
set -u
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] && [ -d "$cwd/.loop" ] || exit 0
rm -f "$cwd/.loop/active" "$cwd/.loop/blocks"
exit 0
```

- [ ] **Step 4: Run tests to verify they pass, and shellcheck**

Run: `bash plugins/loop-engineering/tests/verify-gate-test.sh && shellcheck plugins/loop-engineering/hooks/verify-gate.sh plugins/loop-engineering/hooks/session-cleanup.sh plugins/loop-engineering/tests/verify-gate-test.sh`
Expected: `ALL PASS`, shellcheck clean.

- [ ] **Step 5: Register the hooks**

Create `plugins/loop-engineering/hooks/hooks.json`. The explicit `timeout` (seconds) makes slow verify suites fail loudly at a known bound instead of silently hitting the default and failing open:

```json
{
  "description": "Verification gate for /code-loop: Stop is blocked until the project's verify command passes; SessionStart clears stale gate state.",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/verify-gate.sh",
            "timeout": 600
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/session-cleanup.sh"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 6: Make scripts executable and commit**

```bash
chmod +x plugins/loop-engineering/hooks/verify-gate.sh plugins/loop-engineering/hooks/session-cleanup.sh plugins/loop-engineering/tests/verify-gate-test.sh
git add plugins/loop-engineering/hooks plugins/loop-engineering/tests
git commit -m "feat(loop-engineering): Stop-hook verification gate with escalation budget and stale-state cleanup"
```

---

### Task 4: `/code-loop` command — the agentic coding loop

**Files:**
- Create: `plugins/loop-engineering/commands/code-loop.md`

**Interfaces:**
- Consumes: `SPEC.md` (`## Verification` section's `Verify:` line, `## Rules`), `TODO.md` checkbox items, from Task 2's templates.
- Produces: `.loop/active`, `.loop/verify`, `.loop/blocks` (consumed by Task 3's gate); appended `LOOP_LOG.md` entries of the form `## <ISO timestamp> — <task> — <PASS|FAIL>` (no commit sha — the log line ships in the same commit it describes, so the sha cannot be known); one git commit per completed TODO item.

- [ ] **Step 1: Write the command file**

Create `plugins/loop-engineering/commands/code-loop.md`:

````markdown
---
description: Run the agentic coding loop — one TODO item per iteration, verified and committed, gated by the Stop-hook verify gate
---

## Context

- Spec: !`cat SPEC.md 2>/dev/null || echo "MISSING — run /loop-init first"`
- Backlog: !`cat TODO.md 2>/dev/null || echo "MISSING — run /loop-init first"`
- Recent log: !`tail -20 LOOP_LOG.md 2>/dev/null`
- Branch: !`git branch --show-current`

## Your task

Run the agentic coding loop. Max iterations this session: $ARGUMENTS (default 5 if empty or not a number).

**Preflight — do these before any code change:**
1. If SPEC.md or TODO.md is MISSING, or SPEC.md's `## Verification` section has no `Verify:` line with a backticked command, STOP and tell the user to run `/loop-init`. Refuse to loop without a verify command.
2. If on main/master, create and switch to a feature branch named after the top TODO item.
3. Arm the verification gate:
   - `mkdir -p .loop && printf '*\n' > .loop/.gitignore`
   - Extract the verify command deterministically (do NOT paraphrase it):
     ``sed -n 's/^Verify: `\(.*\)`.*/\1/p' SPEC.md | head -n1 > .loop/verify``
     Then `cat .loop/verify` — it must be a non-empty command with no backticks. If empty, STOP and tell the user SPEC.md's `Verify:` line is malformed.
   - `touch .loop/active` and `rm -f .loop/blocks`.

**Iterate — repeat up to the max-iterations budget:**
4. Take the TOPMOST unchecked item in TODO.md. Work on ONLY that item this iteration.
5. Implement it test-first: write the failing test, see it fail, implement, see it pass. Follow every rule in SPEC.md's `## Rules` section — in particular: no placeholders, and never touch tests/verifier/`.loop/` to make checks pass.
6. Run the Verify command. If it fails, fix and re-run — do not proceed on red.
7. On green: mark the item `- [x]` in TODO.md, append one line to LOOP_LOG.md — `## <date -Iseconds output> — <item> — PASS` — and commit everything for this item (code, tests, TODO.md, LOOP_LOG.md) in one commit.
8. If an iteration reveals new necessary work, add it as a new `- [ ]` item to TODO.md (prioritized, not appended blindly) instead of expanding the current task.

**Finish — when TODO.md has no unchecked items OR the iteration budget is spent:**
9. Run the Verify command one final time and report its real output.
10. Disarm the gate: `rm -f .loop/active .loop/blocks`.
11. Append a session summary to LOOP_LOG.md: items completed, items remaining, verify status, anything a human should review. Then give the user a 3-line summary and suggest `/feedback` for review.

If verification cannot be made to pass after honest attempts, the Stop-hook gate will force a FAILURE report — write it honestly rather than weakening checks.

Do only these steps — no other actions.
````

- [ ] **Step 2: Validate frontmatter**

Run: `head -4 plugins/loop-engineering/commands/code-loop.md`
Expected: frontmatter with `description:`; no `allowed-tools` key. (Note: `allowed-tools` only *pre-approves* tools, it never restricts — it is omitted here because there is no fixed safe set worth pre-approving for an arbitrary coding loop, not because it would limit anything.)

- [ ] **Step 3: Commit**

```bash
git add plugins/loop-engineering/commands/code-loop.md
git commit -m "feat(loop-engineering): /code-loop agentic coding loop command"
```

---

### Task 5: `/feedback` command — the developer feedback loop

**Files:**
- Create: `plugins/loop-engineering/commands/feedback.md`

**Interfaces:**
- Consumes: `SPEC.md` (`Run:` line for launching the app), `LOOP_LOG.md` (entries since the last `## REVIEW`), git history.
- Produces: edits to `SPEC.md` / `TODO.md` / `CLAUDE.md`, plus an appended `## REVIEW <ISO timestamp>` entry in `LOOP_LOG.md` recording every decision.

- [ ] **Step 1: Write the command file**

Create `plugins/loop-engineering/commands/feedback.md`:

````markdown
---
description: Developer feedback loop — review the current product, turn every piece of feedback into a durable artifact (SPEC.md diff, TODO.md item, or CLAUDE.md rule), then optionally relaunch /code-loop
---

## Context

- Spec: !`cat SPEC.md 2>/dev/null || echo "MISSING — run /loop-init first"`
- Backlog: !`cat TODO.md 2>/dev/null`
- Log since last review: !`awk '/^## REVIEW/{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' LOOP_LOG.md 2>/dev/null | tail -40`
- Commits: !`git log --oneline -15`

## Your task

Run one developer-feedback-loop review. This loop exists to inject the human's context advantage — their feedback outranks the spec.

1. If SPEC.md is MISSING, stop and point the user at `/loop-init`.
2. **Present the current state** (keep it tight): what the loop completed since the last REVIEW entry, what verification currently says (run the Verify command from SPEC.md and report the real result), and how to see the product (the `Run:` command — offer to launch it).
3. **Collect feedback.** Ask the user for their reactions: what's wrong, what's missing, what changed their mind. Free-form; iterate until they say they're done.
4. **Convert EVERY feedback item into exactly one durable artifact** — never leave feedback as conversation only:
   - Changed/clarified requirement or done-criterion → edit `SPEC.md` (Requirements or Definition of Done).
   - New or reprioritized work → insert a `- [ ]` item into `TODO.md` at the right priority position.
   - A correction the agent should apply to every future run (style, process, recurring mistake) → append a rule to `CLAUDE.md`.
   Show the user each edit as you make it.
5. **Record the review:** append to LOOP_LOG.md:

```markdown
## REVIEW <date -Iseconds output>
- Feedback: <item> → <artifact changed>
```

6. Offer next steps: run `/code-loop` now, or stop here.

Do only these steps — no other actions.
````

- [ ] **Step 2: Validate the awk context line**

Run (in any dir with a fake log):

```bash
tmp=$(mktemp -d) && printf '# Loop Log\n## 2026-07-12 — a — PASS — abc\n## REVIEW 2026-07-12\n- x\n## 2026-07-13 — b — PASS — def\n' > "$tmp/LOOP_LOG.md" && (cd "$tmp" && awk '/^## REVIEW/{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' LOOP_LOG.md)
```

Expected output starts at the `## REVIEW 2026-07-12` line (everything before the last REVIEW is dropped).

- [ ] **Step 3: Commit**

```bash
git add plugins/loop-engineering/commands/feedback.md
git commit -m "feat(loop-engineering): /feedback developer feedback loop command"
```

---

### Task 6: Outer fresh-context runner — `bin/code-loop`

**Files:**
- Create: `bin/code-loop`
- Test: `plugins/loop-engineering/tests/code-loop-runner-test.sh`

**Interfaces:**
- Consumes: `TODO.md` in the cwd (unchecked `- [ ]` items as the continue condition); the `/code-loop` command from Task 4 (invoked with budget `1` — one task per fresh context).
- Produces: an executable in `~/bin` (this repo's `bin/` is symlinked there by `setup.sh`) for long unattended runs: `code-loop [max_iterations]`.

- [ ] **Step 1: Write the failing test**

Create `plugins/loop-engineering/tests/code-loop-runner-test.sh`:

```bash
#!/usr/bin/env bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/loop-engineering/tests/code-loop-runner-test.sh`
Expected: FAIL (bin/code-loop does not exist).

- [ ] **Step 3: Write the runner**

Create `bin/code-loop`:

```bash
#!/usr/bin/env bash
# Outer agentic-coding-loop runner: fresh Claude context per iteration
# (avoids context rot; state lives in SPEC.md/TODO.md/LOOP_LOG.md/git).
# Usage: code-loop [max_iterations]   (run from the target project root)
set -euo pipefail

max="${1:-10}"
[ -f TODO.md ] && [ -f SPEC.md ] || { echo "SPEC.md/TODO.md not found — run /loop-init first" >&2; exit 2; }

for i in $(seq 1 "$max"); do
  if ! grep -q '^- \[ \]' TODO.md; then
    echo "TODO complete after $((i - 1)) iteration(s)."
    exit 0
  fi
  echo "=== iteration $i/$max: $(grep -m1 '^- \[ \]' TODO.md) ==="
  # In -p mode unlisted tools are auto-denied (no prompt possible), so Bash must
  # be explicitly allowed or the loop cannot verify, branch, or commit.
  # That grants unrestricted shell — only run this in projects you trust.
  claude -p "/code-loop 1" --permission-mode acceptEdits \
    --allowedTools "Bash,Read,Edit,Write" --output-format json \
    | jq -r '.result // "no result"' || echo "iteration $i: claude exited non-zero — continuing" >&2
done

if grep -q '^- \[ \]' TODO.md; then
  echo "Budget exhausted ($max iterations); unchecked items remain. Review LOOP_LOG.md, then re-run or /feedback."
  exit 1
fi
echo "TODO complete after $max iteration(s)."
```

- [ ] **Step 4: Run tests to verify they pass, and shellcheck**

Run: `chmod +x bin/code-loop && bash plugins/loop-engineering/tests/code-loop-runner-test.sh && shellcheck bin/code-loop plugins/loop-engineering/tests/code-loop-runner-test.sh`
Expected: `ALL PASS`, shellcheck clean.

- [ ] **Step 5: Commit**

```bash
git add bin/code-loop plugins/loop-engineering/tests/code-loop-runner-test.sh
git commit -m "feat(loop-engineering): outer fresh-context runner bin/code-loop"
```

---

### Task 7: Install, end-to-end smoke test, README

**Files:**
- Create: `plugins/loop-engineering/README.md`

**Interfaces:**
- Consumes: everything from Tasks 1–6.

- [ ] **Step 1: Install the plugin**

```bash
claude plugin marketplace update jmeagher-dotfiles
claude plugin install loop-engineering@jmeagher-dotfiles
```

Expected: install succeeds; `/loop-init`, `/code-loop`, `/feedback` appear in a new session's command list.

- [ ] **Step 2: End-to-end smoke test in a sandbox project**

In a scratch directory (NOT this repo), create a trivial target: a git-initialized dir with one shell script and a `Verify:` command of `bash test.sh`. Then, in an interactive Claude session there:

1. Run `/loop-init` — confirm SPEC.md/TODO.md/LOOP_LOG.md are created with the exact template sections, and `.loop/` is not yet present.
2. Seed TODO.md with two tiny items (e.g. "make test.sh assert hello.sh prints hello", "add --shout flag").
3. Run `/code-loop 2` — confirm: one commit per item, LOOP_LOG.md gains one `PASS` line per item, `.loop/active` is gone afterwards, and TODO items are checked off.
4. Sabotage check (the important one): set `.loop/verify` to `false`, `touch .loop/active`, then ask Claude something trivial and let it try to stop. Expected: the Stop hook blocks with the failure message (1/3, then 2/3); the third consecutive failure demands a FAILURE report and disarms. Then confirm stale-state recovery: re-arm the gate the same way, quit, start a NEW session in the sandbox — `.loop/active` must be gone (SessionStart cleanup) and stopping must not be blocked.
5. Run `/feedback`, give one piece of feedback of each kind (spec change, new task, recurring rule) — confirm SPEC.md, TODO.md, and CLAUDE.md each get the corresponding edit and LOOP_LOG.md gains a `## REVIEW` entry.
6. From the sandbox root, run `code-loop 2` (the outer runner) with one unchecked TODO item remaining — confirm it iterates headlessly (a real `claude -p` run: expect a new commit and a LOOP_LOG.md PASS line) and exits 0 with "TODO complete". If `code-loop` is not on PATH yet, re-run `bash setup.sh` in the dotfiles repo first (it symlinks `bin/` into `~/bin`) or invoke it by absolute path.

Record any deviation and fix before proceeding — do not rationalize failures.

- [ ] **Step 3: Write the README**

Create `plugins/loop-engineering/README.md`:

```markdown
# loop-engineering

Two development loops (from Andrew Ng's three-loop model):

**Agentic coding loop** — `/loop-init` scaffolds SPEC.md (goal, definition of
done, verify command), TODO.md (prioritized backlog), LOOP_LOG.md (append-only
run log). `/code-loop [n]` works the backlog one item per iteration: test-first,
verify, commit, log. A Stop hook (`hooks/verify-gate.sh`) blocks the agent from
stopping until the project's verify command passes, with a 3-strike escalation
that forces an honest FAILURE report instead of looping forever. For long
unattended runs, `bin/code-loop [n]` re-invokes `claude -p "/code-loop 1"` with
a fresh context per iteration.

**Developer feedback loop** — `/feedback` shows what the loop did since your
last review, collects your reactions, and converts every item into a durable
artifact: a SPEC.md edit, a TODO.md item, or a CLAUDE.md rule. Feedback never
lives only in chat.

## Guardrails
- No verify command in SPEC.md → /code-loop refuses to run.
- One TODO item per iteration; hard iteration budgets everywhere.
- Anti-reward-hacking rules in SPEC.md; the gate reports "do NOT weaken tests".
- Known limitation: the agent could edit SPEC.md/.loop to weaken the gate, or
  disarm it outright (`rm -f .loop/active`). The gate prevents accidental
  premature stops, not an adversarial agent — /feedback reviews diffs, so keep
  reviewing.
- For UI work, point `Verify:` at a script that drives a browser (e.g. a
  Playwright check); the gate runs whatever command you give it.

## State files (in the target project)
| File | Role |
|---|---|
| SPEC.md | What to build + definition of done + verify/run commands |
| TODO.md | Prioritized backlog; one checkbox per loop iteration |
| LOOP_LOG.md | Append-only run + review log |
| .loop/ | Gitignored runtime gate state (active, verify, blocks) |
```

- [ ] **Step 4: Commit and open PR**

```bash
git add plugins/loop-engineering/README.md
git commit -m "docs(loop-engineering): README and smoke-test fixes"
git log main..HEAD --oneline   # verify scope before pushing
git remote -v                  # confirm github.com → use gh (glab if gitlab)
git push -u origin loop-engineering-plugin
gh pr create --title "Add loop-engineering plugin: agentic coding loop + developer feedback loop" --body "Implements the first two loops from the loop-engineering article. See plugins/loop-engineering/README.md.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

---

## Out of scope (deliberately)

- **External feedback loop** (loop 3 in the article) — alpha testers, A/B testing.
- **Evals datasets** — SPEC.md's Definition of Done is the poor-man's eval; add a real eval harness only when a project repeatedly fails the same way (per the article).
- **Browser-verification scaffolding** — the article's coding loop checks UI work in a browser; this is supported (point `Verify:` at a Playwright script) but v0.1 ships no scaffolding for it.
- **Cryptographic gate integrity** — see Known limitation.
- **Scheduling/cadence** — compose with built-ins instead: `/loop 30m /feedback`-style nudges already exist.
