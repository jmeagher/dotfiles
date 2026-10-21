# subagent-status

A Claude Code mod that shows the subagents running under a session in a side panel. Open it with `/subagents`.

Each subagent gets three lines:

```
● running researcher · Explore
  task: Survey the auth module
  ↳ Read: a.ts
```

- Line 1: colored status mark and word, name, agent type.
- Line 2: the task description.
- Line 3: the tool call in flight (`↳`), the last one (`last:`), or the outcome (`done in 12s`, `failed after 4s`).

Finished agents stay listed for 10 minutes (up to 20 rows). Tool details are reduced to a description, file basename or hostname, with a redaction pass for anything credential-shaped.

## Requirements

- The side dock needs the fullscreen layout: start Claude Code with `CLAUDE_CODE_NO_FLICKER=1`. On the main screen the pane opens above the prompt instead.
- The dock needs a terminal at least 110 columns wide (144 for the automatic open at session start).

## Known limits

- The panel background comes from the engine's theme key `composerSidebarBackground`; a mod cannot make it transparent. Set that key in a custom `/theme` to match the terminal background.

## Install

```
claude plugin marketplace update jmeagher-dotfiles
claude plugin install subagent-status@jmeagher-dotfiles
```

## Development

```
claude plugin validate plugins/subagent-status
claude plugin test plugins/subagent-status
```
