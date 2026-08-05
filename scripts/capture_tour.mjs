// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Novaza Solution JSC
// Last-touched: 2026-08-05 — captures the product tour as PNG frames for the README GIF.
//
// Drives a real browser against a running Freehold Mail stack: signs in, starts the
// in-product tour, and screenshots every step. The tour is advanced with ArrowRight,
// which the overlay handles natively (components/tour/tour-overlay.tsx), rather than by
// matching button labels that change with the interface language.
//
// This produces frames only. Assemble them with scripts/make_gif.sh.
//
// Prerequisites: npm i playwright && npx playwright install chromium
//
// Usage:
//   FREEHOLD_URL=https://mail.example.com \
//   FREEHOLD_USER=you@example.com FREEHOLD_PASSWORD=... \
//   node scripts/capture_tour.mjs

import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';

const URL = process.env.FREEHOLD_URL ?? 'https://mail.freehold.demo:17443';
const USER = process.env.FREEHOLD_USER ?? 'ana@freehold.demo';
// No default: scripts/seed_demo.py prints the password it generated. Passing it in
// keeps this repository free of a working credential.
const PASSWORD = process.env.FREEHOLD_PASSWORD;
const OUT = process.env.FREEHOLD_FRAMES ?? 'docs/media/frames';
const MAX_STEPS = Number(process.env.FREEHOLD_MAX_STEPS ?? 24);

// A 16:10 desktop frame. Wide enough that the three-pane layout is not collapsed, small
// enough that the resulting GIF stays under a megabyte or two.
const VIEWPORT = { width: 1440, height: 900 };

async function signIn(page) {
  await page.goto(URL, { waitUntil: 'networkidle', timeout: 45000 });
  await page.waitForSelector('#username', { timeout: 30000 });
  // Clear the tour flags here, before signing in. Doing it after login would need a
  // reload, and reloading drops the session.
  await page.evaluate(() => {
    localStorage.removeItem('tour_completed');
    localStorage.removeItem('tour_current_step');
  });
  await page.fill('#username', USER);
  await page.fill('#password', PASSWORD);
  await page.click('button:has-text("Sign in")');
  // The mailbox is ready once the list the tour points at exists.
  await page.waitForSelector('[data-tour="email-list"]', { timeout: 45000 });
  await page.waitForTimeout(2500);
}

async function startTour(page) {
  // Entry point is the welcome banner (components/ui/welcome-banner.tsx).
  const trigger = page.getByRole('button', { name: /start tour/i });
  await trigger.waitFor({ timeout: 15000 });
  await trigger.click();
  await page.waitForTimeout(1500);
}

// The overlay renders a dialog per step; when the tour ends it disappears.
async function tourIsOpen(page) {
  return (await page.locator('[role="dialog"], [data-tour-overlay]').count()) > 0;
}

async function main() {
  if (!PASSWORD) {
    throw new Error('FREEHOLD_PASSWORD is not set — use the password seed_demo.py printed');
  }
  await mkdir(OUT, { recursive: true });
  const browser = await chromium.launch({
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  // A demo stack uses a self-signed certificate; this script only ever runs against one.
  const context = await browser.newContext({
    viewport: VIEWPORT,
    ignoreHTTPSErrors: true,
    deviceScaleFactor: 1,
  });
  const page = await context.newPage();

  try {
    await signIn(page);
    await page.screenshot({ path: `${OUT}/00-inbox.png` });
    console.log('  captured 00-inbox');

    await startTour(page);

    let frame = 1;
    for (; frame <= MAX_STEPS; frame += 1) {
      if (!(await tourIsOpen(page))) break;
      const name = String(frame).padStart(2, '0');
      await page.screenshot({ path: `${OUT}/${name}-step.png` });
      console.log(`  captured ${name}-step`);
      await page.keyboard.press('ArrowRight');
      // Steps that change page or open a panel need time to settle before the next shot.
      await page.waitForTimeout(1400);
    }
    console.log(`\nCaptured ${frame - 1} tour frames into ${OUT}/`);
  } finally {
    await context.close();
    await browser.close();
  }
}

main().catch((err) => {
  console.error(`capture failed: ${err.message}`);
  process.exit(1);
});
