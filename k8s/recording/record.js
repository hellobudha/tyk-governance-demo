const { recordAct, login, chromium } = require('./lib.js');
const ACTS = require('./acts.js');
(async () => {
  const want = process.argv.slice(2); const acts = want.length ? ACTS.filter(a => want.includes(a.id)) : ACTS;
  const browser = await chromium.launch(); await login(browser);
  for (const a of acts) { console.log(`== recording ${a.id} ${a.file}`); await recordAct(a, browser); }
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
