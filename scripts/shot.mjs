// Usage: node shot.mjs <url> <out.png> <width> [waitMs]  — headless Chrome via CDP, full-page screenshot.
import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';
const [url, out, width = '1440', waitMs = '8000', js = ''] = process.argv.slice(2);
const port = 9333 + Math.floor(Math.random() * 500);
const chrome = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
  '--headless=new', '--disable-gpu', `--remote-debugging-port=${port}`, '--user-data-dir=/tmp/chrome-shot-r4k-' + port,
  `--window-size=${width},1200`, 'about:blank'], { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));
let target;
for (let i = 0; i < 40 && !target; i++) {
  try { target = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find(t => t.type === 'page'); } catch { await sleep(250); }
}
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener('open', r));
let id = 0; const pending = new Map();
ws.addEventListener('message', e => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } });
const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
await send('Page.enable');
await send('Runtime.enable');
ws.addEventListener('message', e => { const m = JSON.parse(e.data); if (m.method === 'Runtime.exceptionThrown') console.log('JSERROR', JSON.stringify(m.params.exceptionDetails).slice(0, 400)); });
await send('Emulation.setDeviceMetricsOverride', { width: +width, height: 1200, deviceScaleFactor: 1, mobile: +width < 600 });
await send('Page.navigate', { url });
await sleep(+waitMs);
if (js) { const r = await send('Runtime.evaluate', { expression: js }); if (r.result && r.result.exceptionDetails) console.log('EVALERROR', JSON.stringify(r.result.exceptionDetails).slice(0, 400)); else console.log('EVAL', JSON.stringify(r.result && r.result.result && r.result.result.value).slice(0, 1500)); await sleep(2500); }
const { result: { contentSize } } = await send('Page.getLayoutMetrics');
const h = Math.min(Math.ceil(contentSize.height), 6000);
await send('Emulation.setDeviceMetricsOverride', { width: +width, height: h, deviceScaleFactor: 1, mobile: +width < 600 });
await sleep(1500);
const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true });
writeFileSync(out, Buffer.from(shot.result.data, 'base64'));
const loc = await send('Runtime.evaluate', { expression: 'location.href + " | " + document.title' });
console.log('saved', out, h, loc.result.result.value.slice(0, 120));
ws.close(); chrome.kill();
process.exit(0);
