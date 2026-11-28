// Run: node --test herdr-app/mods/quota-resume/
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseLimit, nextOccurrence, limitVisible, hasLimitMenu, backoffMs } from "./detect.js";

// Local-time helper: tests run in whatever TZ the machine has, so build dates locally.
const at = (y, mo, d, h = 0, mi = 0, s = 0) => new Date(y, mo - 1, d, h, mi, s);
const NOW = at(2026, 11, 27, 13, 0); // Fri 1:00pm

test("session banner with middle dot", () => {
  const r = parseLimit("some output\n5-hour limit reached ∙ resets 3pm\n> ", NOW);
  assert.equal(r.kind, "session");
  assert.deepEqual(r.resetAt, at(2026, 11, 27, 15, 0));
});

test("session banner with hyphen and minutes", () => {
  const r = parseLimit("5-hour limit reached - resets 3:45pm", NOW);
  assert.equal(r.kind, "session");
  assert.deepEqual(r.resetAt, at(2026, 11, 27, 15, 45));
});

test("newer wording: hit your session limit", () => {
  const r = parseLimit("You've hit your session limit · resets 3:45pm", NOW);
  assert.equal(r.kind, "session");
  assert.deepEqual(r.resetAt, at(2026, 11, 27, 15, 45));
});

test("reset earlier than now rolls to tomorrow", () => {
  const r = parseLimit("5-hour limit reached ∙ resets 2am", NOW);
  assert.deepEqual(r.resetAt, at(2026, 11, 28, 2, 0));
});

test("12am and 12pm", () => {
  assert.deepEqual(parseLimit("5-hour limit reached ∙ resets 12am", NOW).resetAt, at(2026, 11, 28, 0, 0));
  assert.deepEqual(parseLimit("5-hour limit reached ∙ resets 12pm", at(2026, 11, 27, 9, 0)).resetAt, at(2026, 11, 27, 12, 0));
});

test("24h clock", () => {
  assert.deepEqual(parseLimit("5-hour limit reached ∙ resets 15:30", NOW).resetAt, at(2026, 11, 27, 15, 30));
});

test("a banner a few minutes stale is due now, not tomorrow", () => {
  const now = at(2026, 11, 27, 15, 4);
  const r = parseLimit("5-hour limit reached ∙ resets 3pm", now);
  assert.deepEqual(r.resetAt, at(2026, 11, 27, 15, 0));
});

test("weekly limit is recognised and not treated as session", () => {
  const r = parseLimit("You've hit your weekly limit · resets Mon 12:00am", NOW);
  assert.equal(r.kind, "weekly");
  assert.deepEqual(r.resetAt, at(2026, 11, 30, 0, 0)); // Mon after Fri 27th
});

test("unlabeled limit far in the future counts as weekly", () => {
  const r = parseLimit("Usage limit reached ∙ resets Sun 9am", NOW);
  assert.equal(r.kind, "weekly");
});

test("unlabeled limit within five hours counts as session", () => {
  const r = parseLimit("Usage limit reached ∙ resets 4pm", NOW);
  assert.equal(r.kind, "session");
});

test("timezone in parentheses is honoured", () => {
  const r = parseLimit("5-hour limit reached ∙ resets 3pm (UTC)", NOW);
  assert.equal(r.kind, "session");
  // 3pm UTC on the 27th or 28th, whichever is next after NOW.
  const t = r.resetAt.getTime();
  assert.equal(new Date(t).getUTCHours(), 15);
  assert.equal(new Date(t).getUTCMinutes(), 0);
  assert.ok(t > NOW.getTime() - 10 * 60000);
});

test("unknown timezone falls back to local time instead of throwing", () => {
  const r = parseLimit("5-hour limit reached ∙ resets 3pm (Not/AZone)", NOW);
  assert.deepEqual(r.resetAt, at(2026, 11, 27, 15, 0));
});

test("server-side throttling is not a quota", () => {
  assert.equal(parseLimit("Server is temporarily limiting requests (not your usage limit) · Rate limited", NOW), null);
});

test("ordinary output is not a limit", () => {
  assert.equal(parseLimit("The rate limit config resets after 5 retries\n> ", NOW), null);
  assert.equal(parseLimit("", NOW), null);
});

test("ANSI escapes are ignored", () => {
  const r = parseLimit("\x1b[31m5-hour limit reached\x1b[0m ∙ resets 3pm", NOW);
  assert.equal(r.kind, "session");
});

test("credits continuing is not a stop", () => {
  assert.equal(parseLimit("5-hour limit resets 3pm - continuing with usage credits", NOW), null);
});

test("only the last banner counts", () => {
  const r = parseLimit("5-hour limit reached ∙ resets 1:30pm\nworking...\n5-hour limit reached ∙ resets 6pm", at(2026, 11, 27, 13, 5));
  assert.deepEqual(r.resetAt, at(2026, 11, 27, 18, 0));
});

test("limitVisible only looks at the bottom of the screen", () => {
  const stale = "5-hour limit reached ∙ resets 3pm\n" + "x\n".repeat(40);
  assert.equal(limitVisible(stale, 15), false);
  assert.equal(limitVisible("x\n".repeat(40) + "5-hour limit reached ∙ resets 3pm\n> ", 15), true);
});

test("hasLimitMenu", () => {
  assert.equal(hasLimitMenu("What do you want to do?\n 1. Stop and wait for limit to reset\n 2. Upgrade"), true);
  assert.equal(hasLimitMenu("> "), false);
});

test("nextOccurrence weekday", () => {
  assert.deepEqual(nextOccurrence({ hour: 0, minute: 0, weekday: 1 }, NOW), at(2026, 11, 30, 0, 0));
  // same weekday later today
  assert.deepEqual(nextOccurrence({ hour: 18, minute: 0, weekday: 5 }, NOW), at(2026, 11, 27, 18, 0));
});

test("backoff grows and caps", () => {
  assert.equal(backoffMs(0), 60000);
  assert.ok(backoffMs(1) > backoffMs(0));
  assert.equal(backoffMs(20), backoffMs(10));
});
