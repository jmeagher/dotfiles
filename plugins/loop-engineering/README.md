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
