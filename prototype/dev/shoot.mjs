// Dev-only: drives headless Chrome via DevTools protocol, waits real time, takes screenshots.
// usage: node dev/shoot.mjs <outDir> <step>[,<step>...] [lang]
import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';

const [outDir = '/tmp/sbshots', stepsArg = 'home', lang = 'en'] = process.argv.slice(2);
const CH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const port = 9333;
const chrome = spawn(CH, ['--headless=new', `--remote-debugging-port=${port}`, '--window-size=900,900',
  '--user-data-dir=/tmp/sb-chrome-prof', '--hide-scrollbars', 'about:blank'], { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));

let targets;
for (let i = 0; i < 50; i++) {
  try { targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); break; } catch { await sleep(200); }
}
const page = targets.find(t => t.type === 'page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener('open', r));
let id = 0;
const pending = new Map();
ws.addEventListener('message', e => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); }
  if (m.method === 'Runtime.consoleAPICalled') {
    const txt = m.params.args.map(a => a.value).join(' ');
    if (!/HARNESS/.test(txt)) console.log('console:', txt);
  }
  if (m.method === 'Runtime.exceptionThrown') console.log('EXCEPTION:', JSON.stringify(m.params.exceptionDetails).slice(0, 500));
});
const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
await send('Runtime.enable');
await send('Page.enable');

const waits = { home: 1500, intro: 2000, game: 7000, win: 45000, choice: 47000, build: 49000, say: 52000, reward: 55000 };
for (const step of stepsArg.split(',')) {
  await send('Page.navigate', { url: `http://127.0.0.1:14321/dev/harness.html?step=${step}&lang=${lang}` });
  // poll until the harness says done or timeout
  const t0 = Date.now();
  while (Date.now() - t0 < (waits[step] || 60000) + 30000) {
    await sleep(1000);
    const r = await send('Runtime.evaluate', { expression: 'window.__done === true' });
    if (r.result.value) break;
  }
  await sleep(800);
  const shot = await send('Page.captureScreenshot', { format: 'png', clip: { x: 20, y: 20, width: 390, height: 844, scale: 1 } });
  writeFileSync(`${outDir}/${step}${lang === 'vi' ? '_vi' : ''}.png`, Buffer.from(shot.data, 'base64'));
  console.log('shot', step, Math.round((Date.now() - t0) / 1000) + 's');
}
ws.close();
chrome.kill();
process.exit(0);
