const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const output = path.join(root, 'build', 'preview');
fs.mkdirSync(output, { recursive: true });
const chrome = process.env.CHROME_PATH || [
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
].find(fs.existsSync);
if (!chrome) throw new Error('Chrome или Edge не найден');
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function main() {
  const server = spawn(process.execPath, ['dev-server.js', '--host', '127.0.0.1', '--port', '7102'], {
    cwd: root, stdio: ['ignore', 'pipe', 'inherit'],
  });
  const profile = path.join(output, 'chrome-profile');
  fs.rmSync(profile, { recursive: true, force: true });
  const browser = spawn(chrome, [
    '--headless=new', '--disable-gpu', '--disable-dev-shm-usage', '--hide-scrollbars', '--no-first-run',
    '--remote-debugging-port=9223', `--user-data-dir=${profile}`, '--window-size=500,900', 'about:blank',
  ], { stdio: ['ignore', 'ignore', 'ignore'] });
  let ws;
  try {
    await new Promise((resolve) => server.stdout.once('data', resolve));
    let targets;
    for (let i = 0; i < 100; i++) {
      try {
        targets = await (await fetch('http://127.0.0.1:9223/json/list')).json();
        if (targets.some((target) => target.type === 'page')) break;
      } catch {}
      await delay(100);
    }
    const page = targets?.find((target) => target.type === 'page');
    if (!page) throw new Error('CDP-вкладка не запустилась');
    ws = new WebSocket(page.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
      ws.addEventListener('open', resolve, { once: true });
      ws.addEventListener('error', reject, { once: true });
    });
    let sequence = 0;
    const pending = new Map();
    const errors = [];
    ws.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.id) {
        const handler = pending.get(message.id);
        if (handler) {
          pending.delete(message.id);
          message.error ? handler.reject(new Error(JSON.stringify(message.error))) : handler.resolve(message.result);
        }
      }
      if (message.method === 'Runtime.exceptionThrown') {
        errors.push(message.params.exceptionDetails.exception?.description || message.params.exceptionDetails.text);
      }
      if (message.method === 'Runtime.consoleAPICalled' && message.params.type === 'error') {
        errors.push(message.params.args.map((arg) => arg.value || arg.description).join(' '));
      }
    });
    const send = (method, params = {}) => new Promise((resolve, reject) => {
      const id = ++sequence;
      pending.set(id, { resolve, reject });
      ws.send(JSON.stringify({ id, method, params }));
    });
    await send('Page.enable');
    await send('Runtime.enable');
    await send('Emulation.setDeviceMetricsOverride', {
      width: 430, height: 900, deviceScaleFactor: 1, mobile: true,
    });
    for (let tab = 0; tab < 5; tab++) {
      await send('Page.navigate', { url: `http://127.0.0.1:7102/?tab=${tab}` });
      await delay(7000);
      const state = await send('Runtime.evaluate', {
        expression: `JSON.stringify({title:document.title,width:innerWidth,height:innerHeight,text:document.body.innerText.slice(0,300)})`,
        returnByValue: true,
      });
      const shot = await send('Page.captureScreenshot', { format: 'png', fromSurface: true });
      const file = path.join(output, `tab-${tab}.png`);
      fs.writeFileSync(file, Buffer.from(shot.data, 'base64'));
      console.log(`tab ${tab}: ${state.result.value} -> ${file}`);
    }
    if (errors.length) {
      console.error('Browser errors:', errors.join('\n---\n'));
      process.exitCode = 1;
    }
  } finally {
    if (ws) ws.close();
    browser.kill();
    server.kill();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
