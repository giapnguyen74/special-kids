// Dev-only: measures frames per second on the board (idle animations + one swipe) in headless Chrome.
import { spawn } from 'node:child_process';
import { rmSync } from 'node:fs';
const [url = 'http://127.0.0.1:14322/'] = process.argv.slice(2);
const CH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const port = 9335;
rmSync('/tmp/sk-fps-prof', { recursive: true, force: true });
const chrome = spawn(CH, ['--headless=new', `--remote-debugging-port=${port}`, '--user-data-dir=/tmp/sk-fps-prof', '--enable-gpu', '--use-angle=metal', '--ignore-gpu-blocklist', '--enable-gpu-rasterization', '--enable-unsafe-swiftshader=false', '--disable-frame-rate-limit', '--disable-gpu-vsync', 'about:blank'], { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));
let targets;
for (let i = 0; i < 50; i++) { try { targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); break; } catch { await sleep(200); } }
const ws = new WebSocket(targets.find(t => t.type === 'page').webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener('open', r));
let id = 0; const pending = new Map();
ws.addEventListener('message', e => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); } });
const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
await send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 1 });
await send('Page.navigate', { url });
await sleep(6000);
const touch = (type, x, y) => send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y }] });
const tap = async (x, y) => { await touch('touchStart', x, y); await sleep(60); await touch('touchEnd'); await sleep(1200); };
const startGame = async () => { await tap(195, 360); await tap(195, 494); await sleep(2000); };
const fpsDef = true;
const fps = async label => {
  const r = await send('Runtime.evaluate', { awaitPromise: true, expression: `new Promise(res => { let n = 0; const t0 = performance.now(); const f = () => { n++; if (performance.now() - t0 < 3000) requestAnimationFrame(f); else res(Math.round(n / 3)); }; requestAnimationFrame(f); })` });
  console.log(label, r.result.value, 'fps');
};
await fps('hub (bubbles only):');
await startGame();
await fps('board idle:');
// swipe a few times during measurement
const swipes = (async () => { for (let k = 0; k < 4; k++) { const y = 330 + k * 51; await touch('touchStart', 143, y); for (let s = 1; s <= 6; s++) { await sleep(16); await touch('touchMove', 143 - 9 * s, y); } await touch('touchEnd'); await sleep(700); } })();
await fps('board with matches:');
await swipes;
ws.close(); chrome.kill(); process.exit(0);
