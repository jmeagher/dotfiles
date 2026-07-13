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
