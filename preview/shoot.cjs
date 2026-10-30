const path = require('path');
const puppeteer = require('puppeteer-core');

const sections = [
    'catalog',
    'manufacturing',
    'bench',
    'materials',
    'stock',
    'dashboard',
    'employees',
    'recipes',
    'finance',
    'sales',
    'mfg',
    'settings',
    'loading',
    'toast',
];

const port = process.env.PREVIEW_PORT || '8765';
const outDir = path.join(__dirname, 'screenshots');

(async () => {
    const browser = await puppeteer.launch({
        executablePath: process.env.CHROME_PATH || '/usr/bin/google-chrome',
        headless: 'new',
        args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu'],
    });
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
    for (const section of sections) {
        const url = `http://127.0.0.1:${port}/preview/index.html?section=${section}&clean=1`;
        await page.goto(url, { waitUntil: 'networkidle0' });
        await page.waitForFunction(() => document.documentElement.dataset.ready === '1', { timeout: 8000 });
        const file = path.join(outDir, `${section}.png`);
        await page.screenshot({ path: file });
        console.log(file);
    }
    await browser.close();
})().catch((error) => {
    console.error(error);
    process.exit(1);
});
