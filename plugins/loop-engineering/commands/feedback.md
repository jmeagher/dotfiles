---
description: Developer feedback loop for one project — review the current product, turn every piece of feedback into a durable artifact (SPEC.md diff, TODO.md item, or CLAUDE.md rule), then optionally relaunch /code-loop
argument-hint: "[project]"
---

## Context

- Loop projects: !`ls loops 2>/dev/null || echo "NONE — run /loop-init <name> first"`
- Commits: !`git log --oneline -15`

## Your task

Run one developer-feedback-loop review for ONE project. This loop exists to
inject the human's context advantage — their feedback outranks the spec.
Arguments (optional project name): $ARGUMENTS

1. Resolve the project: use the argument if it names a directory under
   `loops/`; with no argument, use the single existing project. If zero or
   several projects exist and none was named, STOP and list them (or point at
   `/loop-init <name>`). Set PROJ = `loops/<project>` and read `PROJ/SPEC.md`,
   `PROJ/TODO.md`, and the portion of `PROJ/LOOP_LOG.md` since the last
   `## REVIEW` entry.
2. **Present the current state** (keep it tight): what the loop completed since
   the last REVIEW entry, what verification currently says (run the Verify
   command from `PROJ/SPEC.md` and report the real result), and how to see the
   product (the `Run:` command — offer to launch it).
3. **Collect feedback.** Ask the user for their reactions: what's wrong, what's
   missing, what changed their mind. Free-form; iterate until they say they're
   done.
4. **Convert EVERY feedback item into exactly one durable artifact** — never
   leave feedback as conversation only:
   - Changed/clarified requirement or done-criterion → edit `PROJ/SPEC.md`
     (Requirements or Definition of Done).
   - New or reprioritized work → insert an item into `PROJ/TODO.md` at the
     right priority position, following SPEC.md's TODO item-quality rules:
     tag it `- [ ] [INVESTIGATE] <question>` if it's an open question rather
     than ready-to-build work; otherwise make it a plain implementation item
     that is fully actionable from SPEC.md plus that single line alone. If
     the feedback only makes sense alongside another TODO item or a past
     investigation's finding, add an explicit `(ref: <exact text of the
     other item>)` pointer rather than leaving the connection implicit. If a
     single piece of feedback bundles more than one focused change, split it
     into multiple items now rather than filing one compound item.
   - A correction the agent should apply to every future run (style, process,
     recurring mistake) → append a rule to `CLAUDE.md`.
   Show the user each edit as you make it.
5. **Record the review:** append to `PROJ/LOOP_LOG.md`:

```markdown
## REVIEW <date -Iseconds output>
- Feedback: <item> → <artifact changed>
```

6. Offer next steps: run `/code-loop <project>` now, or stop here.

Do only these steps — no other actions.
