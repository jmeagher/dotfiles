// Pure logic for quota-resume: find Claude Code's usage-limit banner on a
// terminal screen and work out when the limit lifts. No `herdr` imports, so it
// runs under `node --test` as well as inside the app.
//
// Banner wordings seen in the wild (they vary by Claude Code version):
//   5-hour limit reached ∙ resets 3pm
//   You've hit your session limit · resets 3:45pm (America/Chicago)
//   You've hit your weekly limit · resets Mon 12:00am
// The reset time has no date, and the weekly limit uses the same banner.

// A banner this long past its reset time is "due now", not "tomorrow": the
// screen can be read a little after the moment it names.
const STALE_SLACK_MS = 10 * 60000;
// Longest a 5-hour window can be left on the clock, with slack for a late banner.
const SESSION_MAX_MS = 5.5 * 3600000;

const WEEKDAYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];

// A line is a limit banner when it says the limit was hit and when it resets.
const LIMIT_RE = /limit reached|hit your [\w\s-]*limit|usage limit/i;
const RESETS_RE = /\bresets?\b/i;
const NOT_A_STOP_RE = /continuing with (?:usage )?credits|temporarily limiting requests|not your usage limit/i;
const TIME_RE = /\bresets?\s+(?:on\s+)?(?:(sun|mon|tue|wed|thu|fri|sat)[a-z]*\.?,?\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?(?:\s*\(([^)]+)\))?/i;
const MENU_RE = /stop and wait for limit to reset|upgrade your plan|rate-limit-options|switch to extra usage|buy more usage/i;

export function stripAnsi(s) {
  return String(s ?? "").replace(/\x1b\[[0-9;?]*[ -/]*[@-~]/g, "").replace(/\x1b\][^\x07]*(?:\x07|\x1b\\)/g, "");
}

function isBanner(line) {
  return LIMIT_RE.test(line) && RESETS_RE.test(line) && !NOT_A_STOP_RE.test(line);
}

function bannerIndex(lines) {
  for (let i = lines.length - 1; i >= 0; i--) if (isBanner(lines[i])) return i;
  return -1;
}

// --- time zones ---------------------------------------------------------------

function validTz(tz) {
  if (!tz || typeof Intl === "undefined") return null;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: tz });
    return tz;
  } catch {
    return null;
  }
}

function partsInTz(date, tz) {
  const f = new Intl.DateTimeFormat("en-US", {
    timeZone: tz, hourCycle: "h23", year: "numeric", month: "numeric", day: "numeric",
    hour: "numeric", minute: "numeric", second: "numeric",
  });
  const p = {};
  for (const { type, value } of f.formatToParts(date)) p[type] = Number(value);
  return { y: p.year, m: p.month, d: p.day, h: p.hour % 24, mi: p.minute, s: p.second };
}

function tzOffsetMs(tz, t) {
  const p = partsInTz(new Date(t), tz);
  return Date.UTC(p.y, p.m - 1, p.d, p.h, p.mi, p.s) - Math.floor(t / 1000) * 1000;
}

// The instant at which the wall clock in `tz` (or local time) reads y-m-d h:mi.
function instant(tz, y, m, d, h, mi) {
  if (!tz) return new Date(y, m - 1, d, h, mi);
  const guess = Date.UTC(y, m - 1, d, h, mi);
  const first = guess - tzOffsetMs(tz, guess);
  return new Date(guess - tzOffsetMs(tz, first));
}

function calendarDay(from, tz) {
  if (!tz) return { y: from.getFullYear(), m: from.getMonth() + 1, d: from.getDate() };
  const p = partsInTz(from, tz);
  return { y: p.y, m: p.m, d: p.d };
}

// --- scheduling ---------------------------------------------------------------

/** The first instant after `from` at which the clock reads hour:minute (on `weekday`, 0=Sun, if given). */
export function nextOccurrence({ hour, minute, weekday = null, tz = null }, from) {
  const zone = validTz(tz);
  const base = calendarDay(from, zone);
  for (let k = -1; k <= 8; k++) {
    const day = new Date(Date.UTC(base.y, base.m - 1, base.d + k));
    if (weekday !== null && day.getUTCDay() !== weekday) continue;
    const c = instant(zone, day.getUTCFullYear(), day.getUTCMonth() + 1, day.getUTCDate(), hour, minute);
    if (c.getTime() > from.getTime()) return c;
  }
  return null;
}

/** How long to wait before retry number `attempt` (0-based): 1m, 2m, 4m, 8m, then 10m. */
export function backoffMs(attempt) {
  return Math.min(60000 * 2 ** Math.min(attempt, 4), 600000);
}

// --- detection ----------------------------------------------------------------

/**
 * Find the last limit banner in `text`.
 * Returns null when there is none, else
 *   { kind: "session" | "weekly", resetAt: Date | null, line }
 * `resetAt` is null when the banner names a time we could not read.
 */
export function parseLimit(text, now = new Date()) {
  const lines = stripAnsi(text).split("\n");
  const i = bannerIndex(lines);
  if (i < 0) return null;
  const line = lines[i].trim();

  let kind = /weekly|week|7-day/i.test(line) ? "weekly" : /5-hour|session|hour/i.test(line) ? "session" : null;
  const m = TIME_RE.exec(line);
  if (!m) return { kind: kind ?? "session", resetAt: null, line };

  const [, wd, hh, mm, ap, tzRaw] = m;
  let hour = Number(hh);
  const minute = mm ? Number(mm) : 0;
  const ampm = ap?.toLowerCase();
  // "resets 5 retries" and similar: a bare number is not a time.
  if (!ampm && !mm) return { kind: kind ?? "session", resetAt: null, line };
  if (ampm) {
    if (hour < 1 || hour > 12) return { kind: kind ?? "session", resetAt: null, line };
    hour = (hour % 12) + (ampm === "pm" ? 12 : 0);
  }
  if (hour > 23 || minute > 59) return { kind: kind ?? "session", resetAt: null, line };

  const weekday = wd ? WEEKDAYS.indexOf(wd.toLowerCase()) : null;
  const tz = validTz(tzRaw?.trim());
  const from = new Date(now.getTime() - (weekday === null ? STALE_SLACK_MS : 0));
  const resetAt = nextOccurrence({ hour, minute, weekday, tz }, from);
  if (!kind) kind = weekday !== null || resetAt - now > SESSION_MAX_MS ? "weekly" : "session";
  return { kind, resetAt, line };
}

/** True when a limit banner is among the last `tail` lines: the one on screen now, not one in scrollback. */
export function limitVisible(text, tail = 15) {
  const lines = stripAnsi(text).split("\n");
  while (lines.length && !lines[lines.length - 1].trim()) lines.pop();
  return bannerIndex(lines.slice(-tail)) >= 0;
}

/** True when the screen shows the menu Claude Code offers after hitting a limit. */
export function hasLimitMenu(text) {
  return MENU_RE.test(stripAnsi(text));
}

