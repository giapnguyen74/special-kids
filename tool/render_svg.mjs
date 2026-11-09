// Dev-only: render an SVG to a PNG with headless Chrome (transparent background kept).
// usage: node tool/render_svg.mjs in.svg out.png [size]
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, rmSync } from 'node:fs';
const [inp, out, sizeArg = '1024'] = process.argv.slice(2);
const size = Number(sizeArg);
const CH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const port = 9340;
rmSync('/tmp/sk-svg-prof', { recursive: true, force: true });
const chrome = spawn(CH, ['--headless=new', `--remote-debugging-port=${port}`, '--user-data-dir=/tmp/sk-svg-prof', 'about:blank'], { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));
let t; for (let i = 0; i < 50; i++) { try { t = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); break; } catch { await sleep(200); } }
const ws = new WebSocket(t.find(x => x.type === 'page').webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener('open', r));
let id = 0; const pend = new Map();
ws.addEventListener('message', e => { const m = JSON.parse(e.data); if (m.id && pend.has(m.id)) { pend.get(m.id)(m.result); pend.delete(m.id); } });
const send = (m, p = {}) => new Promise(r => { const i = ++id; pend.set(i, r); ws.send(JSON.stringify({ id: i, method: m, params: p })); });
await send('Emulation.setDeviceMetricsOverride', { width: size, height: size, deviceScaleFactor: 1, mobile: false });
await send('Emulation.setDefaultBackgroundColorOverride', { color: { r: 0, g: 0, b: 0, a: 0 } });
const src = readFileSync(inp, 'utf8');
// .svg: scaled to the output size; anything else is used as an HTML body as-is (previews).
const svg = inp.endsWith('.svg') ? src.replace('width="1024" height="1024"', `width="${size}" height="${size}"`) : src;
const html = `<html><body style="margin:0;background:transparent">${svg}</body></html>`;
await send('Page.navigate', { url: inp.endsWith('.html') ? 'file://' + inp : 'data:text/html;base64,' + Buffer.from(html).toString('base64') });
await sleep(800);
const r = await send('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: size, height: size, scale: 1 } });
writeFileSync(out, Buffer.from(r.data, 'base64'));
ws.close(); chrome.kill(); process.exit(0);
