import { test as base, chromium } from '@playwright/test';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

export interface HarnessConfig {
  devSiteUrl: string;
  port?: number;
  webParts: string[];
}

const repoRoot = path.join(__dirname, '..', '..');
export const harness: HarnessConfig = JSON.parse(
  fs.readFileSync(path.join(repoRoot, '.github', 'spfx-harness.json'), 'utf8'),
);

export const isPlaceholder = (value: string): boolean => !value || value.includes('<');

export function manifestsUrl(): string {
  const rel = fs.existsSync(path.join(repoRoot, 'temp', 'build', 'manifests.js'))
    ? 'temp/build/manifests.js'
    : 'temp/manifests.js';
  return `https://localhost:${harness.port ?? 4321}/${rel}`;
}

export function workbenchUrl(): string {
  const site = harness.devSiteUrl.replace(/\/$/, '');
  return `${site}/_layouts/15/workbench.aspx?debug=true&noredir=true&debugManifestsFile=${encodeURIComponent(manifestsUrl())}`;
}

export function screenshotPath(name: string): string {
  const dir = path.join(repoRoot, '.spfx-dev', 'screenshots');
  fs.mkdirSync(dir, { recursive: true });
  return path.join(dir, `${name.replace(/[^a-z0-9-]+/gi, '-').toLowerCase()}.png`);
}

// Separate Edge profile for tests: your normal Edge profile (all work sessions) is never touched.
// Windows usually signs it in automatically with your work account; if not, run once with
// SPFX_PW_SIGNIN=1 and sign in by hand.
// TLS stays on: trust the dev certificate once with `pwsh -File scripts/dev.ps1 trust`
// (Edge uses the Windows certificate store), so https://localhost loads without errors.
const profileDir = process.env.SPFX_PW_PROFILE ?? path.join(os.homedir(), '.pw-edge-profile');

export const test = base.extend({
  context: async ({}, use) => {
    const context = await chromium.launchPersistentContext(profileDir, {
      channel: 'msedge',
      headless: process.env.SPFX_PW_HEADLESS === '1',
      viewport: { width: 1440, height: 900 },
    });
    await use(context);
    await context.close();
  },
  page: async ({ context }, use) => {
    const page = context.pages()[0] ?? (await context.newPage());
    await use(page);
  },
});

export { expect } from '@playwright/test';
