import type { Page } from '@playwright/test';
import { expect, harness, isPlaceholder, screenshotPath, test, workbenchUrl } from './fixtures';

// Read-only smoke test: opens the hosted workbench on the DEV site with the local bundle,
// adds each configured web part and takes screenshots. Never saves pages or list data.
// Selectors for the workbench toolbox are best effort: tune them on the first run if needed.

async function openWorkbench(page: Page, errors: string[]): Promise<void> {
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });
  page.on('pageerror', (err) => errors.push(String(err)));

  await page.goto(workbenchUrl(), { waitUntil: 'domcontentloaded' });
  if (/login\.microsoftonline\.com/.test(page.url())) {
    throw new Error('Not signed in. Run once with SPFX_PW_SIGNIN=1 and sign in in the Edge window.');
  }
  const loadDebug = page.getByRole('button', { name: /load debug scripts/i });
  if (await loadDebug.isVisible({ timeout: 15_000 }).catch(() => false)) {
    await loadDebug.click();
  }
  await page.waitForLoadState('networkidle', { timeout: 60_000 }).catch(() => undefined);
}

const bundleErrors = (errors: string[]): string[] =>
  errors.filter((e) => /localhost:\d+|manifests\.js|\.bundle\.js|sp-loader/i.test(e));

test.describe('SPFx workbench smoke', () => {
  test.skip(isPlaceholder(harness.devSiteUrl), 'Set devSiteUrl in .github/spfx-harness.json');

  test('sign in once (only with SPFX_PW_SIGNIN=1)', async ({ page }) => {
    test.skip(process.env.SPFX_PW_SIGNIN !== '1', 'Set SPFX_PW_SIGNIN=1 to sign in the test profile');
    test.setTimeout(300_000);
    await page.goto(harness.devSiteUrl);
    await page.waitForURL((url) => /sharepoint\.com/.test(url.host), { timeout: 280_000 });
    await expect(page).toHaveURL(/sharepoint\.com/);
  });

  test('workbench loads the local bundle', async ({ page }) => {
    const errors: string[] = [];
    await openWorkbench(page, errors);
    await page.screenshot({ path: screenshotPath('workbench'), fullPage: true });
    expect(bundleErrors(errors), 'console errors from the local bundle').toEqual([]);
  });

  for (const title of harness.webParts.filter((t) => !isPlaceholder(t))) {
    test(`web part renders: ${title}`, async ({ page }) => {
      const errors: string[] = [];
      await openWorkbench(page, errors);

      await page.getByRole('button', { name: /add a new web part/i }).first().click({ timeout: 30_000 });
      const search = page.getByRole('searchbox').or(page.getByPlaceholder(/search/i)).first();
      await search.fill(title);
      await page.getByRole('button', { name: title }).or(page.getByText(title, { exact: true })).first().click();
      await page.waitForTimeout(5_000);

      await page.screenshot({ path: screenshotPath(`webpart-${title}`), fullPage: true });
      await expect(page.getByText(/something went wrong|error loading the web part/i)).toHaveCount(0);
      expect(bundleErrors(errors), 'console errors from the local bundle').toEqual([]);
    });
  }
});
