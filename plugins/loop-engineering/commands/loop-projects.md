---
allowed-tools: Read, Bash(ls:*), Bash(cat:*), Bash(grep:*), Bash(tail:*), Bash(rm:*), Bash(git:*)
description: List loop-engineering projects with their status, or clean one up (loops/<name>/ plus its runtime gate state)
argument-hint: "[clean <project>]"
---

## Context

- Loop projects: !`ls loops 2>/dev/null || echo "NONE"`
- Armed gates: !`ls .loop 2>/dev/null || echo "none"`

## Your task

Project maintenance for the loop-engineering plugin. Arguments: $ARGUMENTS

**No arguments → LIST.** For each directory under `loops/`, report one line:

- **name** — `<done>/<total>` TODO items done, verify command present/missing,
  gate armed or not (`.loop/<name>/active` exists), and the timestamp of the
  last `LOOP_LOG.md` entry (last `## ` line), or `never run`.

Gather this with `grep -c '^- \[x\]' loops/<name>/TODO.md`,
`grep -c '^- \[ \]'`, ``grep -c '^Verify: `' loops/<name>/SPEC.md``, and
`tail` of the log. If `loops/` is missing or empty, say so and point at
`/loop-init <name>`. End by mentioning `/loop-projects clean <name>`.

**`clean <project>` → CLEAN.** Remove one project completely:

1. If `loops/<project>` does not exist, STOP and list what does.
2. Show the user what will be removed: the project's done/remaining TODO
   counts, and whether `loops/<project>` has uncommitted changes
   (`git status --porcelain -- loops/<project>`). If there are unchecked TODO
   items or uncommitted changes, ask for confirmation before deleting;
   otherwise proceed.
3. Delete the runtime gate state first, then the project directory — always
   from the parent, never `cd` into either:
   - `rm -rf .loop/<project>`
   - `git rm -r loops/<project>` if tracked (commit it as
     `Remove loop project <project>`), else `rm -rf loops/<project>`.
4. Confirm what was removed and list the remaining projects.

Anything else in the arguments → show usage: `/loop-projects` to list,
`/loop-projects clean <name>` to remove one.

Do only these steps — no other actions.
