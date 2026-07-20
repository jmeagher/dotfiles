---
description: Run the agentic coding loop for one project — one TODO item per iteration, verified and committed, gated by the Stop-hook verify gate
argument-hint: "[project] [max-iterations]"
---

## Context

- Loop projects: !`ls loops 2>/dev/null || echo "NONE — run /loop-init <name> first"`
- Branch: !`git branch --show-current`

## Your task

Run the agentic coding loop for ONE project. Arguments: $ARGUMENTS

**Resolve the project and budget — before anything else:**
1. Parse the arguments as `[project] [max-iterations]`:
   - If the first token names a directory under `loops/`, that is the project;
     an optional second numeric token is the iteration budget.
   - If the only token is a number, it is the budget — usable only when exactly
     one project exists.
   - With no project token: if exactly one project exists, use it; if zero or
     several exist, STOP and tell the user to run `/loop-init <name>` or pick
     one (list them). Never guess among multiple projects.
   - Budget defaults to 5.
2. Set PROJ = `loops/<project>`. Read `PROJ/SPEC.md`, `PROJ/TODO.md`, and the
   last ~20 lines of `PROJ/LOOP_LOG.md` before proceeding.

**Preflight — do these before any code change:**
3. If `PROJ/SPEC.md` or `PROJ/TODO.md` is missing, or SPEC.md's
   `## Verification` section has no `Verify:` line with a backticked command,
   STOP and tell the user to run `/loop-init <project>`. Refuse to loop without
   a verify command.
4. If on main/master, create and switch to a feature branch named
   `<project>-<top TODO item slug>`.
5. Arm the verification gate (state is per-project under `.loop/<project>/`):
   - `mkdir -p .loop/<project> && printf '*\n' > .loop/.gitignore`
   - Extract the verify command deterministically (do NOT paraphrase it):
     ``sed -n 's/^Verify: `\(.*\)`.*/\1/p' PROJ/SPEC.md | head -n1 > .loop/<project>/verify``
     Then `cat .loop/<project>/verify` — it must be a non-empty command with no
     backticks. If empty, STOP and tell the user SPEC.md's `Verify:` line is
     malformed.
   - `touch .loop/<project>/active` and `rm -f .loop/<project>/blocks`.

**Iterate — repeat up to the max-iterations budget:**
6. Take the TOPMOST unchecked item in `PROJ/TODO.md`. Work on ONLY that item
   this iteration.
7. Branch on item type:
   - **`[INVESTIGATE]` item:** research the open question (read code, run
     read-only commands, consult SPEC.md) and produce a written finding —
     never product code. Record the finding as one or both of: a note
     appended to `PROJ/LOOP_LOG.md`, or new implementation item(s) inserted
     into `PROJ/TODO.md` that point back at this investigation via
     `(ref: <exact text of this item>)`. Then proceed to step 8.
   - **Implementation item (no tag):** before touching code, confirm the
     line is fully actionable from `PROJ/SPEC.md` plus that single line
     alone. If it silently depends on missing context (another item, an
     unresolved investigation, an assumption not stated in SPEC.md), do NOT
     guess — stop this iteration's implementation, rewrite the item in
     `PROJ/TODO.md` (add an explicit `(ref: ...)` pointer, or split it into
     smaller self-contained items per SPEC.md's TODO item-quality rules),
     then restart step 6 against the revised topmost item. Otherwise
     implement it test-first: write the failing test, see it fail,
     implement, see it pass. Follow every rule in SPEC.md's `## Rules`
     section — in particular: no placeholders, and never touch
     tests/verifier/`.loop/` to make checks pass.
8. Run the Verify command. If it fails, fix and re-run — do not proceed on red.
9. On green: mark the item `- [x]` in `PROJ/TODO.md`, append one line to
   `PROJ/LOOP_LOG.md` — `## <date -Iseconds output> — <item> — PASS` — and
   commit everything for this item (code, tests, TODO.md, LOOP_LOG.md) in one
   commit.
10. If an iteration reveals new necessary work, add it as new item(s) to
    `PROJ/TODO.md` (prioritized, not appended blindly) instead of expanding
    the current task — following SPEC.md's TODO item-quality rules: tag
    `[INVESTIGATE]` for open questions, keep every implementation item
    self-contained (actionable from SPEC.md + that line alone), add
    explicit `(ref: ...)` pointers for any cross-item dependency, and split
    anything bundling more than one focused change into separate items.

**Finish — when the TODO has no unchecked items OR the iteration budget is spent:**
11. Run the Verify command one final time and report its real output.
12. Disarm the gate: `rm -f .loop/<project>/active .loop/<project>/blocks`.
13. Append a session summary to `PROJ/LOOP_LOG.md`: items completed, items
    remaining, verify status, anything a human should review. Then give the
    user a 3-line summary and suggest `/feedback <project>` for review.

If verification cannot be made to pass after honest attempts, the Stop-hook
gate will force a FAILURE report — write it honestly rather than weakening
checks.

Do only these steps — no other actions.
