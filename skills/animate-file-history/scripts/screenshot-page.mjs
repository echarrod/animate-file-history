#!/usr/bin/env node
// Screenshot a URL once it has really finished loading, and say whether the result is usable.
// Usage: screenshot-page.mjs URL OUT.png [--size 1280x800] [--timeout 30000] [--fallback-origin https://prod.example]
//   [--rewrite 'REGEX=>URL']  retry a failed image from another host, e.g. a storage URL via the CDN prod uses
// Needs `playwright-core` (resolved from the cwd or from $PLAYWRIGHT_DIR) and Chrome (channel "chrome").
// Assets the dev server cannot serve (platform-hosted, gitignored, uploaded) come from --fallback-origin.
// Waits for network idle, fonts and every <img> to settle, dismisses a cookie banner if there is one, then
// prints one JSON line {ok, reason, brokenImages, broken, text} and exits 0 (usable), 3 (error page) or 4 (blank).
import { createRequire } from "node:module";
import { resolve } from "node:path";

const [url, out, ...rest] = process.argv.slice(2);
if (!url || !out) { console.error("usage: screenshot-page.mjs URL OUT.png [--size WxH] [--timeout MS]"); process.exit(2); }
const opt = (name, def) => { const i = rest.indexOf(name); return i >= 0 ? rest[i + 1] : def; };
const [width, height] = opt("--size", "1280x800").split("x").map(Number);
const timeout = Number(opt("--timeout", 30000));
const fallback = opt("--fallback-origin", "");
const rewrite = opt("--rewrite", "");
const [rewriteFrom, rewriteTo] = rewrite ? [new RegExp(rewrite.split("=>")[0]), rewrite.split("=>")[1]] : [];

const require = createRequire(resolve(process.env.PLAYWRIGHT_DIR || process.cwd(), "noop.js"));
const { chromium } = require("playwright-core");

const ERROR_PATTERNS = [
  /couldn.?t load in this browser/i, /application error/i, /something went wrong/i, /cannot get \//i,
  /failed to compile/i, /\b(404|500)\b.*(not found|error)/i, /vite.*error|\[plugin:/i, /unhandled runtime error/i,
];

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width, height } });
if (fallback || rewrite) {
  await page.route("**/*", async (route) => {
    const req = route.request();
    const u = new URL(req.url());
    if (!["image", "font", "media"].includes(req.resourceType())) return route.continue();
    if (u.origin !== new URL(url).origin) {
      if (!rewrite || !rewriteFrom.test(req.url())) return route.continue();
      const first = await route.fetch().catch(() => null);
      if (first && first.status() < 400) return route.fulfill({ response: first });
      const mirrored = await route.fetch({ url: req.url().replace(rewriteFrom, rewriteTo) }).catch(() => null);
      return mirrored && mirrored.status() < 400 ? route.fulfill({ response: mirrored }) : route.fulfill(first ? { response: first } : { status: 404 });
    }
    if (!fallback) return route.continue();
    const local = await route.fetch().catch(() => null);
    // A SPA dev server answers unknown paths with index.html (200), so judge by content type too.
    if (local && local.status() < 400 && !/text\/html/i.test(local.headers()["content-type"] || "")) return route.fulfill({ response: local });
    const remote = await route.fetch({ url: fallback + u.pathname + u.search }).catch(() => null);
    return remote && remote.status() < 400 ? route.fulfill({ response: remote }) : route.fulfill(local ? { response: local } : { status: 404 });
  });
}
let reason = "";
try {
  await page.goto(url, { waitUntil: "load", timeout });
  await page.waitForLoadState("networkidle", { timeout }).catch(() => {});
  await page.evaluate(() => document.fonts?.ready).catch(() => {});
  // Dismiss a cookie/consent banner so it doesn't cover every frame (best effort).
  const banner = page.getByRole("button", { name: /^(reject|decline|accept|got it|dismiss|close)\b/i }).first();
  if (await banner.isVisible().catch(() => false)) await banner.click({ timeout: 2000 }).catch(() => {});
  // Lazy and animated images: wait until every <img> has loaded or failed, then let animations settle.
  await page.waitForFunction(() => [...document.images].every((i) => i.complete), null, { timeout: 15000 }).catch(() => {});
  await page.waitForTimeout(1500);
  await page.waitForLoadState("networkidle", { timeout: 5000 }).catch(() => {});
} catch (e) {
  reason = `navigation failed: ${String(e.message).split("\n")[0]}`;
}

const text = ((await page.evaluate(() => document.body?.innerText || "").catch(() => "")) || "").trim().replace(/\s+/g, " ");
const broken = await page.evaluate(
  () => [...document.images].filter((i) => i.complete && i.naturalWidth === 0 && i.currentSrc).map((i) => i.currentSrc),
).catch(() => []);
const brokenImages = broken.length;
await page.screenshot({ path: out });
await browser.close();

let code = 0;
if (reason) code = 3;
else if (ERROR_PATTERNS.some((re) => re.test(text.slice(0, 400)))) { reason = "error page"; code = 3; }
else if (text.length < 20) { reason = "blank page"; code = 4; }
console.log(JSON.stringify({ ok: code === 0, reason, brokenImages, broken: broken.slice(0, 5), text: text.slice(0, 120) }));
process.exit(code);
