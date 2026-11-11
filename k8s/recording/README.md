# Recording the walkthrough videos

Re-creates `../videos/*.mp4`: five narrated videos, one per part of the story, recorded against the live
`kestrel` cluster. Playwright drives the real Tyk Dashboard and a local stage page (openers, terminal and
file views) in a 1920×816 capture. The title bar (day, story time, part title, running timer) and the step
footer are composed around that capture afterwards with ffmpeg, so they never cover the screen. macOS `say`
(voice Daniel) speaks the narration. Every `kubectl` command and script runs for real at record time.

| File | Purpose |
|---|---|
| `acts.js` | The script: the five parts, each beat's subtitle and narration, and what happens on screen. |
| `lib.js` | Runner: narration timing, shell commands, Dashboard helpers, per-step chrome rendering, ffmpeg composition. |
| `chrome.html` | Title bar, step progress strip and footer, rendered to a transparent PNG per step. |
| `stage.html` | Animated slate (day slides in while a clock ticks through the story time), problem slide, openers (flow, stats, cast), quote and week-recap cards, terminal and file views. Tyk colours, Inter and Roboto. |
| `overlay.js` | Injected into Dashboard pages: highlight box with dimmed surroundings, visible cursor. |
| `fonts/` | Inter, Roboto and Roboto Mono embedded as data URIs, plus a TTF for ffmpeg's timer. |
| `transcripts.js` | Rebuilds `../videos/TRANSCRIPTS.md` and the `.srt` subtitle files, timed against the speech in each recorded video. Run it after re-recording. |

Requires macOS (for `say` and `afinfo`) and the stack from `../scripts/up.sh`.

```bash
cd ~/projects/tyk-governance-demo/k8s/recording
npm install
PLAYWRIGHT_BROWSERS_PATH=$PWD/browsers npx playwright install chromium
../scripts/reset.sh && ../scripts/seed.sh            # parts must start from Monday's state
PLAYWRIGHT_BROWSERS_PATH=$PWD/browsers node record.js   # all five parts, in order; or e.g. node record.js 03
node transcripts.js                                     # refresh transcripts and subtitles
```

Parts change cluster state in sequence, so record a single part only from the state it starts in (part 02,
for example, needs manifests 20 and 21 applied). `OUT_DIR` overrides the output folder.
