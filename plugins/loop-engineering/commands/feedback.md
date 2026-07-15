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
