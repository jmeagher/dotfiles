# quota-resume (herdr-app mod)

Resumes Claude Code agents that stopped on the 5-hour usage limit.

Every 5 s it looks at `claude-code` agents that are not working. When one shows a
limit banner (`5-hour limit reached ∙ resets 3pm`) at the bottom of its screen it
waits until the reset time plus 30 s, re-checks the banner is still there, and runs
`hc send <terminal> continue`. The agent going back to `working` counts as success;
otherwise it retries with backoff (1, 2, 4, 8, 10 min) and gives up after 5 tries.

- Weekly limits only notify; they are never auto-resumed.
- If the banner has left the bottom of the screen (you resumed it yourself), it stands down.
- If Claude's post-limit options menu is open, it sends Esc first (unverified wording).
- Click the bottom strip to pause/resume everything (stored in localStorage).
- The last real banner screen is saved to `~/.config/herdr-app/data/quota-resume-last-capture.txt`
  so the parser can be tuned against real output.

Logic is in `detect.js` (pure, tested). Run the tests with:

    node --test herdr-app/mods/quota-resume/

Install: `sh herdr-app/setup.sh` links the mod into `~/.config/herdr-app/mods/`.
Then `herdr-app check ~/.config/herdr-app/mods/quota-resume`.
