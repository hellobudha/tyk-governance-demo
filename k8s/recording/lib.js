const { chromium } = require('playwright');
const { spawn, spawnSync } = require('child_process');
const fs = require('fs'); const path = require('path');
const FFMPEG = require('ffmpeg-static');
const REC = __dirname; const REPO = '/Users/budha/projects/tyk-governance-demo'; const K8S = REPO + '/k8s';
const OUT = process.env.OUT_DIR || K8S + '/videos';
const DASH = 'http://localhost:3100';
const W = 1920, H = 816, TOP = 64, FULLH = 1080;
const sleep = ms => new Promise(r => setTimeout(r, ms));

const SAY = [[/kubectl/g, 'kube control'], [/\bTyk\b/g, 'Tyke'], [/\bOWASP\b/g, 'oh wasp'], [/\bOAS\b/g, 'O A S'], [/\bJSON\b/g, 'jason'],
  [/\bYAML\b/g, 'yammel'], [/\bCI\b/g, 'C I'], [/\bUUIDs?\b/g, m => m.endsWith('s') ? 'U U I Ds' : 'U U I D'], [/\bHTTPS\b/g, 'H T T P S'], [/\bHTTP\b/g, 'H T T P'],
  [/x-tyk-api-gateway/g, 'x tyke API gateway'], [/ConfigMaps?/g, m => m.endsWith('s') ? 'config maps' : 'config map'], [/operationIds?/g, m => m.endsWith('s') ? 'operation I Ds' : 'operation I D'],
  [/\bTLS\b/g, 'T L S'], [/\bIDs\b/g, 'I Ds'], [/\bID\b/g, 'I D'], [/\bGitOps\b/g, 'git ops'], [/\bAPIs\b/g, 'A P Eyes'], [/Ines/g, 'Eenez'], [/\bvs\.?\b/g, 'versus']];
function speakable(t) { let s = t; for (const [re, rep] of SAY) s = s.replace(re, rep); return s; }
function tts(text, file) {
  const r = spawnSync('say', ['-v', 'Daniel', '-r', '170', '-o', file, speakable(text)]); if (r.status !== 0) throw new Error('say failed');
  const info = spawnSync('afinfo', [file]).stdout.toString(); const m = info.match(/estimated duration: ([\d.]+)/); return m ? parseFloat(m[1]) : 3;
}
function sh(cmd) { return new Promise(res => { const p = spawn('bash', ['-c', cmd], { cwd: K8S, env: process.env });
  let out = ''; p.stdout.on('data', d => out += d); p.stderr.on('data', d => out += d); p.on('close', code => res({ code, out })); }); }
function compactTables(text) {
  const L = text.split('\n'); const out = [];
  for (let i = 0; i < L.length; i++) {
    if (!/^NAME\s{2,}\S/.test(L[i])) { out.push(L[i]); continue; }
    let j = i + 1; while (j < L.length && L[j].trim() && !/^(==|NAME\s{2,}|[{>])/.test(L[j])) j++;
    const head = L[i], rows = L.slice(i + 1, j); const starts = [];
    head.replace(/\S+/g, (m, k) => { if (k === 0 || /\s{2}$/.test(head.slice(0, k)) || head[k - 1] === ' ' && starts.length) starts.push(k); return m; });
    const spans = starts.map((st, k) => [st, k + 1 < starts.length ? starts[k + 1] : Infinity]);
    const empty = spans.map(([a, b]) => rows.length > 0 && rows.every(r => r.slice(a, b === Infinity ? undefined : b).trim() === ''));
    const cut = l => spans.map(([a, b], k) => empty[k] ? '' : l.slice(a, b === Infinity ? undefined : b)).join('').replace(/\s+$/, '');
    out.push(cut(head)); rows.forEach(r => out.push(cut(r))); i = j - 1;
  }
  return out.join('\n');
}

function helpers(page) {
  let onStage = false;
  const h = {
    page, sh, sleep,
    async stage() { if (!onStage) { await page.goto('file://' + REC + '/stage.html'); await sleep(150); onStage = true; } },
    async opener(o) { await h.stage(); await page.evaluate(o => stage.opener(o), o); },
    async slate(o) { await h.stage(); await page.evaluate(o => stage.slate(o), o); },
    async problem(o) { await h.stage(); await page.evaluate(o => stage.problem(o), o); },
    async quote(o) { await h.stage(); await page.evaluate(o => stage.quote(o), o); },
    async week(o) { await h.stage(); await page.evaluate(o => stage.week(o), o); },
    async term(o = {}) { await h.stage(); await page.evaluate(o => stage.term(o), o); },
    async run(cmd, o = {}) {
      await h.stage(); const job = sh(o.run || cmd);
      await page.evaluate(c => stage.type(c), cmd);
      const r = await job; let out = o.raw ? r.out : compactTables(r.out); if (o.filter) out = o.filter(out);
      await page.evaluate(t => stage.out(t), out);
      if (o.hl) await page.evaluate(p => stage.hl(p), o.hl);
      return r;
    },
    async termHl(patterns) { await page.evaluate(p => stage.hl(p), patterns); },
    async file(p, o = {}) { await h.stage(); const content = fs.readFileSync(path.join(REPO, p), 'utf8');
      const lang = o.lang || (p.endsWith('.json') ? 'json' : p.endsWith('.sh') ? 'bash' : 'yaml');
      await page.evaluate(o => stage.file(o), { path: p, content, lang, hl: o.hl || [] }); },
    async fileHl(subs) { await page.evaluate(s => stage.fileHl(s), subs); await sleep(600); },
    async dash(p, o = {}) { onStage = false; await page.goto(DASH + p, { waitUntil: 'domcontentloaded' });
      if (o.waitFor) await page.locator(o.waitFor).first().waitFor({ timeout: 20000 }).catch(() => {});
      await sleep(o.settle ?? 2600); await page.evaluate(() => { document.querySelectorAll('.tyk-debugger, [class*=debugger]').forEach(e => e.style.display = 'none'); }).catch(() => {}); },
    async hlBox(text, minW) { const b = await page.evaluate(([t, m]) => window.__ov.boxOf(t, m), [text, minW]); await sleep(400);
      const b2 = await page.evaluate(([t, m]) => window.__ov.boxOf(t, m), [text, minW]); await page.evaluate(b => window.__ov.hl(b, 8), b2 || b); },
    async hlLoc(loc, pad = 8) { const l = loc.first(); await l.evaluate(el => el.scrollIntoView({ block: 'center' })); await sleep(450);
      const b = await l.boundingBox(); await page.evaluate(([b, p]) => window.__ov.hl(b, p), [b, pad]); },
    async unhl() { await page.evaluate(() => window.__ov && window.__ov.hl(null)).catch(() => {}); },
    async click(loc) { const l = loc.first(); await l.evaluate(el => el.scrollIntoView({ block: 'center' })); await sleep(350); const b = await l.boundingBox();
      await page.evaluate(([x, y]) => window.__ov.cursor(x, y), [b.x + b.width / 2, b.y + b.height / 2]); await sleep(900);
      await page.evaluate(() => window.__ov.ripple()); await sleep(150); await l.click(); await sleep(600); },
    async cursorOff() { await page.evaluate(() => window.__ov && window.__ov.cursor(0, 0, false)).catch(() => {}); },
  };
  return h;
}

async function renderChrome(browser, beats, meta, dir) {
  const ctx = await browser.newContext({ viewport: { width: W, height: FULLH } }); const p = await ctx.newPage();
  await p.goto('file://' + REC + '/chrome.html'); await p.evaluate(() => document.fonts.ready); await sleep(300);
  const total = beats.filter(b => b.step).length; let idx = 0, time = meta.time || '', who = meta.who || 'both', day = meta.day;
  for (const b of beats) {
    if (b.step) idx++; if (b.at) time = b.at; if (b.who) who = b.who; if (b.day) day = b.day;
    await p.evaluate(o => setChrome(o), { day, time, title: meta.title, who, step: b.step || '', stepIndex: idx, stepTotal: total, text: b.cap || b.say || '' });
    await sleep(60); b.png = path.join(dir, `c${b.i}.png`); await p.screenshot({ path: b.png, omitBackground: true });
  }
  await ctx.close();
}

async function recordAct(act, browser) {
  const tmp = path.join(REC, 'tmp', act.id); fs.rmSync(tmp, { recursive: true, force: true }); fs.mkdirSync(tmp, { recursive: true });
  const beats = act.beats.map((b, i) => ({ ...b, i }));
  for (const b of beats) if (b.say) { b.audio = path.join(tmp, `b${b.i}.aiff`); b.dur = tts(b.say, b.audio); }
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, recordVideo: { dir: tmp, size: { width: W, height: H } }, storageState: path.join(REC, 'state.json'), bypassCSP: true });
  await ctx.addInitScript({ path: path.join(REC, 'overlay.js') });
  const page = await ctx.newPage(); const t0 = Date.now();
  const h = helpers(page);
  for (const b of beats) {
    if (b.pre) await b.pre(h);
    b.start = (Date.now() - t0) / 1000;
    const minMs = Math.max(b.hold ?? 0, b.audio ? b.dur * 1000 + (b.pad ?? 1100) : 1500);
    await Promise.all([b.do ? b.do(h) : null, sleep(minMs)]);
    if (b.post) await b.post(h);
    console.log(`  [${act.id}] beat ${b.i + 1}/${beats.length} at ${((Date.now() - t0) / 1000).toFixed(1)}s`);
  }
  await sleep(1200); const end = (Date.now() - t0) / 1000;
  const video = page.video(); await ctx.close(); const webm = await video.path();
  await renderChrome(browser, beats, act, tmp);
  fs.mkdirSync(OUT, { recursive: true }); const out = path.join(OUT, act.file);
  const audio = beats.filter(b => b.audio);
  const args = ['-y', '-f', 'lavfi', '-i', `color=c=0x06060D:s=${W}x${FULLH}:r=30`, '-i', webm];
  audio.forEach(b => args.push('-i', b.audio)); beats.forEach(b => args.push('-i', b.png));
  const nA = audio.length; let f = `[0:v][1:v]overlay=0:${TOP}:shortest=1[v0]`; let v = 'v0';
  beats.forEach((b, k) => { const s = Math.max(0, b.start - 0.05).toFixed(2), e = (k + 1 < beats.length ? beats[k + 1].start - 0.05 : end + 5).toFixed(2);
    f += `;[${v}][${2 + nA + k}:v]overlay=0:0:enable='between(t,${s},${e})'[v${k + 1}]`; v = `v${k + 1}`; });
  const font = path.join(REC, 'fonts', 'RobotoMono-Medium.ttf');
  f += `;[${v}]drawtext=fontfile=${font}:text='%{pts\\:gmtime\\:0\\:%M\\\\\\:%S}':fontsize=22:fontcolor=0xC4C4D4:x=${W - 40 - 72}:y=21[vout]`;
  f += ';' + audio.map((b, i) => `[${2 + i}:a]aresample=48000,adelay=${Math.round(b.start * 1000)}|${Math.round(b.start * 1000)}[a${i}]`).join(';') + ';' + audio.map((b, i) => `[a${i}]`).join('') + `amix=inputs=${nA}:normalize=0:dropout_transition=0[aout]`;
  args.push('-filter_complex', f, '-map', '[vout]', '-map', '[aout]', '-c:v', 'libx264', '-preset', 'medium', '-crf', '21', '-pix_fmt', 'yuv420p', '-r', '30', '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', '-shortest', out);
  const r = spawnSync(FFMPEG, args); if (r.status !== 0) { console.log(r.stderr.toString().slice(-3000)); throw new Error('ffmpeg failed'); }
  const d = spawnSync(FFMPEG, ['-i', out]).stderr.toString().match(/Duration: ([\d:.]+)/);
  console.log(`  -> ${out} (${d ? d[1] : '?'}, ${(fs.statSync(out).size / 1e6).toFixed(1)} MB)`);
  return out;
}
async function login(browser) {
  const ctx = await browser.newContext({ viewport: { width: W, height: H } }); const p = await ctx.newPage();
  await p.goto(DASH + '/'); await p.fill('input[type=email], input[name=username], #username', 'rob.whitfield@kestrelcharging.example');
  await p.fill('input[type=password]', 'kestrel-demo-2026'); await p.click('button[type=submit]'); await p.waitForTimeout(3500);
  await ctx.storageState({ path: path.join(REC, 'state.json') }); await ctx.close();
}
module.exports = { recordAct, login, chromium, sh, sleep, K8S, REPO };
