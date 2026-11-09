// Dev-only: drives the Flutter web build in headless Chrome (phone viewport) and takes screenshots.
// usage: node tool/drive_web.mjs <url> <outDir> "<script>"
//   script: semicolon-separated steps: shot:name | tap:x,y | swipe:x1,y1,x2,y2 | wait:ms
import { spawn } from 'node:child_process';
import { writeFileSync, rmSync } from 'node:fs';

const [url, outDir, script] = process.argv.slice(2);
const CH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const port = 9334;
rmSync('/tmp/sk-chrome-prof', { recursive: true, force: true });
const chrome = spawn(CH, ['--headless=new', `--remote-debugging-port=${port}`, '--user-data-dir=/tmp/sk-chrome-prof',
  '--autoplay-policy=no-user-gesture-required', 'about:blank'], { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));

let targets;
for (let i = 0; i < 50; i++) {
  try { targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); break; } catch { await sleep(200); }
}
const ws = new WebSocket(targets.find(t => t.type === 'page').webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener('open', r));
let id = 0;
const pending = new Map();
ws.addEventListener('message', e => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result ?? m.error); pending.delete(m.id); }
  if (m.method === 'Runtime.exceptionThrown') console.log('EXCEPTION:', m.params.exceptionDetails.stackTrace?.callFrames?.map(f => f.functionName).join(' < ').slice(0, 900));
  if (m.method === 'Runtime.consoleAPICalled' && (m.params.type === 'error' || /SKDBG/.test(JSON.stringify(m.params.args)))) console.log('console.error:', m.params.args.map(a => a.value ?? a.description).join(' ').slice(0, 400));
});
const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
await send('Runtime.enable');
await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
await send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 1 });
await send('Page.navigate', { url });
await sleep(6000);

const touch = async (type, x, y) => send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y }] });
for (const step of script.split(';').map(s => s.trim()).filter(Boolean)) {
  const [cmd, arg = ''] = step.split(':');
  const n = arg.split(',').map(Number);
  if (cmd === 'wait') await sleep(n[0]);
  if (cmd === 'tap') { await touch('touchStart', n[0], n[1]); await sleep(60); await touch('touchEnd'); await sleep(400); }
  if (cmd === 'hold') { await touch('touchStart', n[0], n[1]); await sleep(n[2] || 2000); await touch('touchEnd'); await sleep(400); }
  if (cmd === 'swipe') {
    await touch('touchStart', n[0], n[1]);
    for (let k = 1; k <= 6; k++) { await sleep(16); await touch('touchMove', n[0] + (n[2] - n[0]) * k / 6, n[1] + (n[3] - n[1]) * k / 6); }
    await touch('touchEnd');
  }
  if (cmd === 'probe') {
    const t0 = Date.now();
    const r = await send('Runtime.evaluate', { awaitPromise: true, expression: `new Promise(r => { const t = performance.now(); setTimeout(() => r(Math.round(performance.now() - t)), 500); })` });
    console.log('probe', arg, 'setTimeout(500) took', r.result?.value, 'ms; round trip', Date.now() - t0, 'ms');
  }
  if (cmd === 'shot') {
    const r = await send('Page.captureScreenshot', { format: 'png' });
    writeFileSync(`${outDir}/${arg}.png`, Buffer.from(r.data, 'base64'));
    console.log('shot', arg);
  }
}
ws.close();
chrome.kill();
process.exit(0);
