// quota-resume: when a Claude Code agent stops on its 5-hour usage limit, wait
// for the reset time on its banner and then send it "continue".
//
// Safe by construction:
//  - only `claude-code` agents, only the 5-hour/session limit (weekly just notifies);
//  - acts only while the banner is still on the bottom of the screen, so a pane
//    you have already resumed or moved on from is left alone;
//  - after sending, success is the agent going back to "working"; otherwise it
//    retries with backoff and gives up after MAX_ATTEMPTS.
// Click the strip to pause/resume the whole thing.

import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { agents, hc, exec, theme, notify, checking, appHome } from "herdr";
import * as fs from "fs/promises";
import { parseLimit, limitVisible, hasLimitMenu, backoffMs } from "./detect.js";

const TICK_MS = 5000;
const READ_LINES = 40;
const TAIL_LINES = 15;
const MARGIN_MS = 30000; // wait a little past the stated reset
const SESSION_MAX_MS = 5.5 * 3600000; // a 5-hour banner cannot name a time further out than this
const UNPARSED_RETRY_MS = 5 * 60000; // banner without a readable time: try again in 5 minutes
const MAX_ATTEMPTS = 5;
const MESSAGE = "continue";
const ENABLED_KEY = "quota-resume:enabled";

const isClaude = (a) => /claude/i.test(a.app ?? "");

function clock(d) {
  const h = d.getHours();
  const m = String(d.getMinutes()).padStart(2, "0");
  return `${h % 12 || 12}:${m}${h < 12 ? "am" : "pm"}`;
}

function readEnabled() {
  try {
    return localStorage.getItem(ENABLED_KEY) !== "0";
  } catch {
    return true;
  }
}

export default class QuotaResume extends View {
  init(_props, cx) {
    this.enabled = readEnabled();
    this.tracks = new Map(); // address -> { status, armed, nextTry, attempts, sent }
    this.waiting = []; // what the strip shows
    this.busy = false;
    if (checking()) return;
    cx.timer.every(TICK_MS, (cx) => this.tick(cx));
    this.tick(cx);
  }

  tick(cx) {
    if (this.busy) return;
    this.busy = true;
    cx.spawn(async (cx) => {
      try {
        await this.scan();
      } catch (e) {
        console.log("quota-resume: tick failed", String(e));
      } finally {
        this.busy = false;
        cx.notify();
      }
    });
  }

  async screen(address) {
    const r = await hc(["read", address, "--lines", String(READ_LINES)]);
    return r.code === 0 ? r.stdout : null;
  }

  async scan() {
    const now = new Date();
    const list = agents().filter(isClaude);
    const live = new Set(list.map((a) => a.address));
    for (const k of this.tracks.keys()) if (!live.has(k)) this.tracks.delete(k);

    for (const a of list) {
      const tr = this.tracks.get(a.address) ?? { status: null, armed: null, attempts: 0 };
      this.tracks.set(a.address, tr);
      const changed = tr.status !== a.status;
      tr.status = a.status;
      const name = a.space_name ? `${a.space_name}/${a.tab_name ?? a.address}` : a.address;

      if (a.status === "working") {
        if (tr.armed && tr.sent) notify({ title: "Claude resumed", body: `${name} is working again`, level: "success" });
        tr.armed = null;
        tr.sent = false;
        tr.attempts = 0;
        continue;
      }

      // Not working: look for a fresh banner when the state just changed (or we have never looked).
      if (!tr.armed && (changed || tr.scanned === undefined)) {
        tr.scanned = true;
        await this.arm(a, tr, name, now);
      }

      if (tr.armed && this.enabled && now.getTime() >= tr.armed.resetAt.getTime() + MARGIN_MS && now.getTime() >= (tr.nextTry ?? 0)) {
        await this.resume(a, tr, name, now);
      }
    }

    this.waiting = [...this.tracks.entries()]
      .filter(([, t]) => t.armed)
      .map(([addr, t]) => ({ addr, resetAt: t.armed.resetAt }));
  }

  async arm(a, tr, name, now) {
    const text = await this.screen(a.address);
    if (!text || !limitVisible(text, TAIL_LINES)) return;
    const p = parseLimit(text, now);
    if (!p) return;
    this.capture(a.address, text);

    if (p.kind === "weekly" || (p.resetAt && p.resetAt.getTime() - now.getTime() > SESSION_MAX_MS)) {
      notify({ title: "Claude weekly limit", body: `${name}: ${p.line}. Not auto-resuming.`, level: "warning" });
      tr.scanned = true;
      return;
    }
    const guessed = !p.resetAt;
    tr.armed = { resetAt: p.resetAt ?? new Date(now.getTime() + UNPARSED_RETRY_MS - MARGIN_MS), line: p.line, guessed };
    tr.attempts = 0;
    tr.sent = false;
    tr.nextTry = 0;
    notify({
      title: "Claude hit its 5-hour limit",
      body: guessed ? `${name}: couldn't read the reset time; will retry in 5 min` : `${name}: will send "${MESSAGE}" at ${clock(p.resetAt)}`,
      level: "info",
    });
  }

  async resume(a, tr, name, now) {
    const text = await this.screen(a.address);
    // The banner is gone from the bottom: someone already dealt with it, or the pane moved on.
    if (!text || !limitVisible(text, TAIL_LINES)) {
      tr.armed = null;
      return;
    }
    if (tr.attempts >= MAX_ATTEMPTS) {
      notify({ title: "Claude did not resume", body: `${name}: gave up after ${MAX_ATTEMPTS} tries`, level: "error" });
      tr.armed = null;
      return;
    }
    // After a limit Claude Code can show an options menu; close it so the text goes to the prompt.
    if (hasLimitMenu(text)) {
      await hc(["keys", a.address, "esc"]);
      await exec("sleep", ["0.7"]);
    }
    const r = await hc(["send", a.address, MESSAGE]);
    tr.attempts += 1;
    tr.sent = r.code === 0;
    tr.nextTry = now.getTime() + backoffMs(tr.attempts - 1);
    if (r.code !== 0) console.log("quota-resume: send failed", a.address, r.stderr);
  }

  // Keep the last real limit screen: useful for tuning the parser against real banners.
  capture(address, text) {
    console.log(`quota-resume: limit banner on ${address}`);
    fs.writeFile(`${appHome()}/data/quota-resume-last-capture.txt`, `${new Date().toISOString()} ${address}\n${text}\n`).catch(() => {});
  }

  render() {
    const t = theme();
    const n = this.waiting.length;
    const first = n ? this.waiting.reduce((x, y) => (x.resetAt < y.resetAt ? x : y)) : null;
    const label = !this.enabled
      ? "quota-resume paused"
      : n
        ? `quota-resume: ${n} waiting, next ${clock(first.resetAt)}`
        : "quota-resume on";
    return h_flex()
      .id("quota-resume")
      .size_full()
      .px(10)
      .gap(6)
      .items_center()
      .bg(t.chrome)
      .text_size(11)
      .text_color(n ? t.working : t.dim)
      .cursor_pointer()
      .on_click((_e, cx) => {
        this.enabled = !this.enabled;
        try {
          localStorage.setItem(ENABLED_KEY, this.enabled ? "1" : "0");
        } catch {}
        cx.notify();
      })
      .child(div().size(6).rounded(3).bg(this.enabled ? (n ? t.working : t.done) : t.dim))
      .child(label);
  }
}
