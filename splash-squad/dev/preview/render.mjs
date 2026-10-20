import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright-core';

const root = path.dirname(new URL(import.meta.url).pathname);
const outDir = process.argv[2];
const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  const file = path.join(root, decodeURIComponent(url.pathname));
  if (!file.startsWith(root) || !fs.existsSync(file)) { res.writeHead(404); res.end(); return; }
  const ext = path.extname(file);
  const type = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json' }[ext] || 'application/octet-stream';
  res.writeHead(200, { 'Content-Type': type }); fs.createReadStream(file).pipe(res);
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const port = server.address().port;

const exprs = ['Idle','Aiming','Fire','Hit','Flying','Wet','Win'];
const hairs = ['Spiky','BowlCut','Ponytail','Curly'];
const hats = ['None','Tricorn','VikingHorns','Cap','Crown','Flower'];
const sheets = {
  lineup: { cols: 1, tileW: 1800, tileH: 760, title: 'Lineup (rest pose)', tiles: [{ scene: 'lineup', label: 'Polly, Bjorn, Captain Max, Pip, Kai, Rae, Mo', mode: 'lineup' }] },
  faces: { cols: 7, tileW: 260, tileH: 250, title: 'Expressions (head close-ups)', tiles: ['Pip','Max','Polly','Mo','Rae'].flatMap(id => exprs.map(e => ({ scene: `face_${id}_${e}`, label: `${id} ${e}`, mode: 'head' }))) },
  bodies: { cols: 3, tileW: 520, tileH: 620, title: 'Heroes full body', tiles: [{ scene: 'face_Pip_Idle', label: 'Pip', mode: 'full' }, { scene: 'face_Max_Idle', label: 'Captain Max', mode: 'full' }, { scene: 'face_Polly_Idle', label: 'Polly', mode: 'full' }] },
  hats: { cols: 1, tileW: 1500, tileH: 360, title: 'Hair x hats', tiles: hairs.map(h => ({ scene: `hats_${h}`, label: h + ': ' + hats.join(', '), mode: 'full' })) },
  poses: { cols: 3, tileW: 560, tileH: 420, title: 'Animation poses (Pip + Max)', tiles: ['idle','aim','fire_windup','fire_release','hit','win_air','win_land','flying','water','sinking','landing'].map(p => ({ scene: `pose_${p}`, label: p, mode: 'full' })) },
};
const only = process.argv[3] ? process.argv[3].split(',') : Object.keys(sheets);
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || '/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell', args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1900, height: 1000 } });
page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') console.log('PAGE', m.type(), m.text()); });
page.on('pageerror', e => console.log('PAGEERROR', e.message));
for (const name of only) {
  const spec = sheets[name];
  await page.goto(`http://127.0.0.1:${port}/render.html?spec=${encodeURIComponent(JSON.stringify(spec))}`);
  await page.waitForFunction(() => document.title === 'done', null, { timeout: 240000 });
  const el = await page.$('#sheet');
  await el.screenshot({ path: path.join(outDir, `${name}.png`) });
  console.log('wrote', name);
}
await browser.close(); server.close();
