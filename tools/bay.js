// Demo Medicine Call bay.
//
// The phone posts one alert here. This process sends one WhatsApp message
// with the Twilio token and keeps one row for the notification bay.
// The token is read from tools/keys.local.sh and is never written back.
//
//   node tools/bay.js
//
// Open http://<this-machine>:8090/alerts.html on the laptop.

'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', 'portal');
const port = Number(process.env.BAY_PORT || 8090);
const alerts = [];

function loadKeys() {
  const file = path.join(__dirname, 'keys.local.sh');
  if (!fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const match = line.match(/^export\s+([A-Z0-9_]+)=(.*)$/);
    if (!match || process.env[match[1]]) continue;
    let value = match[2].trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[match[1]] = value;
  }
}

function clock() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${p(d.getHours())}:${p(d.getMinutes())}`;
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

function medicinesOf(body) {
  if (!body || !Array.isArray(body.medicines)) return null;
  const out = [];
  for (const item of body.medicines) {
    if (!item || typeof item.name !== 'string' || item.name.trim() === '') {
      return null;
    }
    const pills = Number(item.pills);
    if (!Number.isInteger(pills) || pills < 1 || pills > 4) return null;
    out.push({ name: item.name.trim(), pills });
  }
  return out.length ? out : null;
}

function whatsAppBody(medicines) {
  const list = medicines
    .map((m) => `${m.name} (${m.pills} ${m.pills === 1 ? 'tablet' : 'tablets'})`)
    .join(', ');
  return `RapidRX medicine alert: ${list}.`;
}

function plus(n) {
  return n.startsWith('+') ? n : `+${n}`;
}

async function sendWhatsApp(to, body) {
  const sid = process.env.TWILIO_ACCOUNT_SID || '';
  const token = process.env.TWILIO_AUTH_TOKEN || '';
  const from = process.env.TWILIO_WHATSAPP_FROM || '';
  if (!to) return 'no-number';
  if (!sid || !token || !from) return 'missing-from';
  const auth = Buffer.from(`${sid}:${token}`).toString('base64');
  const form = new URLSearchParams({
    From: `whatsapp:${plus(from)}`,
    To: `whatsapp:${plus(to)}`,
    Body: body,
  });
  const response = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
    {
      method: 'POST',
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: form,
    },
  );
  return response.ok ? 'sent' : 'failed';
}

function sendJson(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Cache-Control': 'no-store',
  });
  res.end(JSON.stringify(body));
}

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.ico': 'image/x-icon',
};

function serveFile(res, urlPath) {
  let file = path.join(root, urlPath);
  if (!file.startsWith(root)) {
    res.writeHead(403).end();
    return;
  }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) {
    file = path.join(file, 'index.html');
  }
  if (!fs.existsSync(file)) {
    res.writeHead(404).end('not found');
    return;
  }
  res.writeHead(200, {
    'Content-Type': types[path.extname(file)] || 'application/octet-stream',
    'Cache-Control': 'no-store',
  });
  fs.createReadStream(file).pipe(res);
}

loadKeys();

http
  .createServer(async (req, res) => {
    const url = decodeURIComponent((req.url || '/').split('?')[0]);
    if (req.method === 'OPTIONS') {
      res.writeHead(204, {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      });
      res.end();
      return;
    }
    if (url === '/api/demo-alerts' && req.method === 'GET') {
      sendJson(res, 200, alerts);
      return;
    }
    if (url === '/api/demo-alert' && req.method === 'POST') {
      let parsed;
      try {
        parsed = JSON.parse(await readBody(req));
      } catch (_) {
        sendJson(res, 400, { bay: false, whatsapp: 'failed' });
        return;
      }
      const medicines = medicinesOf(parsed);
      if (!medicines) {
        sendJson(res, 400, { bay: false, whatsapp: 'failed' });
        return;
      }
      const to = typeof parsed.to === 'string' ? parsed.to : '';
      let whatsapp = 'failed';
      try {
        whatsapp = await sendWhatsApp(to, whatsAppBody(medicines));
      } catch (_) {
        whatsapp = 'failed';
      }
      alerts.unshift({
        kind: 'medicine_alert',
        medicine: medicines.map((m) => m.name).join(', '),
        time: clock(),
        medicines,
      });
      if (alerts.length > 20) alerts.length = 20;
      sendJson(res, 200, { bay: true, whatsapp });
      return;
    }
    serveFile(res, url === '/' ? '/index.html' : url);
  })
  .listen(port, '0.0.0.0', () => {
    console.log(`Medicine demo bay at http://localhost:${port}/alerts.html`);
  });
