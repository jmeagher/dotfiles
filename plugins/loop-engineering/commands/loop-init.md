---
allowed-tools: Read, Write, Bash(ls:*), Bash(cat:*)
description: Scaffold a loop-engineering project (loops/<name>/ with SPEC.md, TODO.md, LOOP_LOG.md)
argument-hint: <project-name> [description]
---

## Context

- Existing loop projects: !`ls loops 2>/dev/null || echo "none"`
- Project files: !`ls`

## Your task

Scaffold the state files for ONE named loop project. Arguments: $ARGUMENTS
— the FIRST word is the project name (required); the rest is an optional
project description.

1. If no project name was given, STOP and ask for one. The name must be a
   short kebab-case slug (lowercase letters, digits, hyphens) — it becomes the
   directory `loops/<name>/`. If the name is not a valid slug, STOP and say so.
2. If `loops/<name>/SPEC.md` already exists, STOP and tell the user it exists —
   never overwrite it. Mention `/loop-projects` to inspect existing projects.
3. Interview the user briefly (one round of questions max) for anything you
   cannot infer from the project: the goal, the 3–7 core requirements, and the
   exact shell commands to build, test, and run this project.
4. Write `loops/<name>/SPEC.md` with EXACTLY these sections:

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

5. Write `loops/<name>/TODO.md`:

```markdown
# TODO
<!-- One `- [ ]` item per line, highest priority first. /code-loop works top-down, one item per iteration. -->

- [ ] <first task>
```

   Derive initial items from the Requirements; each item must be completable in
   one loop iteration (roughly one focused change + its tests).
6. Write `loops/<name>/LOOP_LOG.md` containing only the line `# Loop Log` — it
   is append-only from here on.
7. Confirm the Verify command actually runs (`Bash` it once); if it fails on a
   fresh scaffold, that is fine — report the output so the user knows the
   starting state.
8. Tell the user: review/edit `loops/<name>/SPEC.md`, then run
   `/code-loop <name>` to start the loop.

Do only these steps — no other actions.
