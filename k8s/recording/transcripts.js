// Rebuilds ../videos/TRANSCRIPTS.md and one .srt subtitle file per video.
// Narration text comes from acts.js. Timings come from the recorded videos: ffmpeg finds the speech in each
// audio track, and macOS `say` regenerates each line to measure its length, so cues line up with what is heard.
// Run after re-recording:  node transcripts.js   (needs `npm install` here, macOS say/afinfo)
const fs = require('fs'), path = require('path'), { spawnSync } = require('child_process');
const REC = __dirname, VID = path.join(__dirname, '..', 'videos');
const libSrc = fs.readFileSync(REC + '/lib.js', 'utf8');
const SAY = eval(libSrc.match(/const SAY = (\[[\s\S]*?\]\]);/)[1]);
const speakable = t => { let s = t; for (const [re, rep] of SAY) s = s.replace(re, rep); return s; };
const rate = libSrc.match(/'-r', '(\d+)'/)[1], voice = libSrc.match(/'-v', '([^']+)'/)[1];
function align() {
const ACTS = require(REC + '/acts.js');
const out = [];
for (const act of ACTS) {
    const FF = require('ffmpeg-static');
  const sil = spawnSync(FF, ['-hide_banner', '-i', path.join(VID, act.file), '-af', 'silencedetect=noise=-45dB:d=0.75', '-vn', '-f', 'null', '-'])
    .stderr.toString().split('\n').map(l => l.match(/(silence_(?:start|end)): ([\d.]+)/)).filter(Boolean).map(m => [m[1], m[2]]);
  const segs = []; let cur = 0;                     // speech segments between silences
  for (const [k, v] of sil) { const t = parseFloat(v); if (k === 'silence_start') { if (t - cur > 0.05) segs.push([cur, t]); cur = Infinity; } else cur = t; }
  const total = parseFloat(spawnSync(require('ffmpeg-static'), ['-i', path.join(VID, act.file)]).stderr.toString().match(/Duration: (\d+):(\d+):([\d.]+)/).slice(1).reduce((a, x, i) => a + parseFloat(x) * [3600, 60, 1][i], 0));
  if (cur !== Infinity && total - cur > 0.3) segs.push([cur, total]);
  const beats = act.beats.filter(b => b.say).map(b => {
    const f = path.join(require('os').tmpdir(), 'kestrel-tts.aiff'); spawnSync('say', ['-v', voice, '-r', rate, '-o', f, speakable(b.say)]);
    const d = parseFloat(spawnSync('afinfo', [f]).stdout.toString().match(/estimated duration: ([\d.]+)/)[1]);
    return { text: b.cap || b.say, step: b.step || '', pre: b.pre ? b.pre.toString() : '', at: b.at || '', who: b.who || '', dur: d, slate: !!(b.pre && /slate|problem|opener|quote|week/.test(b.pre.toString()) && !b.step) };
  });
  let prevEnd = 0; const rows = [];
  for (const b of beats) {
    const inside = segs.find(([s, e]) => s <= prevEnd + 0.15 && e > prevEnd + 0.6);
    const start = inside && prevEnd > 0 ? prevEnd + 0.3 : (segs.find(([s]) => s >= prevEnd - 0.2) || [prevEnd])[0];
    rows.push({ ...b, start, end: start + b.dur }); prevEnd = start + b.dur;
  }
  out.push({ id: act.id, file: act.file, day: act.day, title: act.title, segs: segs.length, total, rows });
  console.log(act.id, act.file, 'narrated beats', beats.length, 'speech segments', segs.length, 'last line ends', prevEnd.toFixed(1) + 's');
}
return out;
}

const A = align();
const ts = (t, ms) => { const h = Math.floor(t / 3600), m = Math.floor(t % 3600 / 60), s = Math.floor(t % 60), x = Math.round((t % 1) * 1000);
  return ms ? `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')},${String(x).padStart(3, '0')}` : `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`; };
const str = (src, key) => { const m = src.match(new RegExp(key + ": (?:'((?:[^'\\\\]|\\\\.)*)'|\"((?:[^\"\\\\]|\\\\.)*)\")")); return m ? (m[1] ?? m[2]).replace(/\\(['"])/g, '$1') : ''; };
const WHO = { ines: 'Ines Ferreira, backend engineer, Payments squad', rob: 'Rob Whitfield, API platform lead', both: 'Kestrel Charging' };
// split text into subtitle cues of at most ~84 chars, breaking at sentence then clause boundaries
function cues(text, start, end) {
  const parts = []; for (const sent of text.match(/[^.!?]+[.!?]+["']?|[^.!?]+$/g).map(x => x.trim())) {
    if (sent.length <= 84) { parts.push(sent); continue; }
    const clauses = sent.split(/(?<=[,;:])\s+/); let buf = '';
    for (const cl of clauses) {
      if ((buf + ' ' + cl).trim().length <= 84) { buf = (buf + ' ' + cl).trim(); continue; }
      if (buf) parts.push(buf); buf = '';
      if (cl.length <= 84) { buf = cl; continue; }
      for (const w of cl.split(/\s+/)) { if ((buf + ' ' + w).trim().length > 84 && buf) { parts.push(buf); buf = w; } else buf = (buf + ' ' + w).trim(); }
    }
    if (buf) parts.push(buf); }
  const total = parts.reduce((a, p) => a + p.length, 0); let t = start;
  return parts.map(p => { const d = (end - start) * p.length / total; const c = { start: t, end: t + d, text: p }; t += d; return c; });
}
const wrap = s => { if (s.length <= 42) return s; const mid = s.length / 2; let best = -1; for (let i = 0; i < s.length; i++) if (s[i] === ' ' && (best < 0 || Math.abs(i - mid) < Math.abs(best - mid))) best = i; return best < 0 ? s : s.slice(0, best) + '\n' + s.slice(best + 1); };
let md = `# Kestrel Charging governance series: transcripts

Narrated transcripts of the five videos in this folder, one week at Kestrel Charging told through Tyk API
Governance on Kubernetes. Timestamps are minutes and seconds from the start of each video, measured against
the narration in the recorded audio. "On screen" lines are text shown in the video but not read word for word.
The narration is synthetic (macOS text-to-speech). A subtitle file (.srt) with the same name sits beside each
video for players and video platforms that load captions.

`;
for (const a of A) {
  const dur = ts(a.total); md += `## Part ${+a.id} · ${a.title}\n\n**${a.file}** · ${dur} · ${a.day}\n\n`;
  let n = 0; const srt = [];
  for (const r of a.rows) {
    const line = str(r.pre, 'line'), problem = str(r.pre, 'problem'), shows = str(r.pre, 'shows');
    const isSlate = /h\.slate\(/.test(r.pre), isProblem = /h\.problem\(/.test(r.pre);
    if (isSlate) { const day = str(r.pre, 'day'), time = str(r.pre, 'time'), who = (r.pre.match(/who: '(\w+)'/) || [])[1] || 'both';
      md += `**[${ts(r.start)}] On screen:** ${day}, ${time} · ${WHO[who]}  \n${line}\n\n`; }
    if (/h\.opener\(/.test(r.pre)) { const title = str(r.pre, 'title'), sub = str(r.pre, 'sub'); md += `**[${ts(r.start)}] On screen:** ${title}${sub ? ' ' + sub : ''}\n\n`; }
    if (/h\.quote\(/.test(r.pre)) { const q = str(r.pre, 'text'), by = str(r.pre, 'by'), note = str(r.pre, 'note'); md += `**[${ts(r.start)}] On screen:** ${q}${by ? ' (' + by + ')' : ''}${note ? '  \n' + note : ''}\n\n`; }
    if (/h\.week\(/.test(r.pre)) { const t = str(r.pre, 'title'); md += `**[${ts(r.start)}] On screen:** ${t}\n\n`; }
    if (isProblem) md += `**[${ts(r.start)}] On screen, the problem:** ${problem}  \n**What this part shows:** ${shows}\n\n`;
    md += `**[${ts(r.start)}]${r.step ? ' ' + r.step : ''}**  \n${r.text}\n\n`;
    for (const c of cues(r.text, r.start, r.end)) srt.push(`${++n}\n${ts(c.start, 1)} --> ${ts(Math.max(c.start + 0.8, c.end - 0.05), 1)}\n${wrap(c.text)}\n`);
  }
  fs.writeFileSync(path.join(VID, a.file.replace('.mp4', '.srt')), srt.join('\n'));
  console.log(a.file.replace('.mp4', '.srt'), n, 'cues');
}
fs.writeFileSync(path.join(VID, 'TRANSCRIPTS.md'), md.trimEnd() + '\n');
console.log('TRANSCRIPTS.md', md.split(/\s+/).length, 'words');
