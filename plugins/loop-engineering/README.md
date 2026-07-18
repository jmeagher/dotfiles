# loop-engineering

Two development loops (from Andrew Ng's three-loop model), with support for
multiple independent loop projects per repository. Each project lives in
`loops/<name>/` with its own spec, backlog, and log.

**Agentic coding loop** — `/loop-init <name>` scaffolds a project:
`loops/<name>/SPEC.md` (goal, definition of done, verify command),
`loops/<name>/TODO.md` (prioritized backlog), `loops/<name>/LOOP_LOG.md`
(append-only run log). `/code-loop [name] [n]` works that project's backlog
one item per iteration: test-first, verify, commit, log. A Stop hook
(`hooks/verify-gate.sh`) blocks the agent from stopping until every armed
project's verify command passes, with a 3-strike escalation that forces an
honest FAILURE report instead of looping forever. For long unattended runs,
`bin/code-loop <name> [n]` re-invokes `claude -p` with a fresh context per
iteration.

**Developer feedback loop** — `/feedback [name]` shows what the loop did since
your last review, collects your reactions, and converts every item into a
durable artifact: a SPEC.md edit, a TODO.md item, or a CLAUDE.md rule.
Feedback never lives only in chat.

**Maintenance** — `/loop-projects` lists every project with its backlog
status, verify command, gate state, and last run; `/loop-projects clean
<name>` removes a project (spec dir and runtime gate state).

## Project resolution
`/code-loop` and `/feedback` take the project name as their first argument.
With no name they use the single existing project, and refuse to guess when
several exist. `/loop-init` always requires a name (a kebab-case slug).

## Guardrails
- No verify command in a project's SPEC.md → /code-loop refuses to run.
- One TODO item per iteration; hard iteration budgets everywhere. The gate's
  3-strike escalation is per session, so under `bin/code-loop` (fresh context
  each iteration) a persistently-failing item gets a fresh 3-strike budget per
  iteration, up to the runner's `[n]` cap — it does not give up after 3 total.
- Anti-reward-hacking rules in SPEC.md; the gate reports "do NOT weaken tests".
- Known limitation: the agent could edit SPEC.md/.loop to weaken the gate, or
  disarm it outright (`rm -rf .loop/<name>`). The gate prevents accidental
  premature stops, not an adversarial agent — /feedback reviews diffs, so keep
  reviewing.
- For UI work, point `Verify:` at a script that drives a browser (e.g. a
  Playwright check); the gate runs whatever command you give it.

## State files (in the target project)
| Path | Role |
|---|---|
| `loops/<name>/SPEC.md` | What to build + definition of done + verify/run commands |
| `loops/<name>/TODO.md` | Prioritized backlog; one checkbox per loop iteration |
| `loops/<name>/LOOP_LOG.md` | Append-only run + review log |
| `.loop/<name>/` | Gitignored runtime gate state (active, verify, blocks) |
