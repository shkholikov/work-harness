import { defineConfig } from '@playwright/test';

// Smoke tests against the SharePoint hosted workbench with the local dev server.
// Uses the installed Edge and a separate test profile (see tests/e2e/fixtures.ts).
export default defineConfig({
  testDir: './tests/e2e',
  timeout: 120_000,
  workers: 1, // one persistent Edge profile can only be opened once
  retries: 0,
  reporter: [['line']],
  outputDir: '.spfx-dev/e2e-results',
  use: { trace: 'retain-on-failure' },
});
