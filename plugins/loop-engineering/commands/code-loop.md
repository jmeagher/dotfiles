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
