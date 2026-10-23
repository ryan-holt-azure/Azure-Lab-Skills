// Halsted Logistics "Shipment Tracker" — tiny dependency-free Node.js app for
// Lab 13 (App Service). It shows which slot/instance served you and can test
// outbound VNet integration with /net?target=<private IP>.
//
// LAB 13: change APP_VERSION below to 'v2' (and the colour) before deploying
// to the staging slot.
const http = require('http');
const os = require('os');

const APP_VERSION = 'v1';
const BANNER_COLOUR = '#1f6feb'; // v2: try '#2da44e'

const port = process.env.PORT || 8080;

// Only allow outbound tests to private (RFC 1918) addresses — this is a lab
// diagnostic, not a general-purpose proxy.
const PRIVATE = /^(10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3})$/;

function page(res) {
  const env = process.env.APP_ENV || '(APP_ENV not set)';
  const banner = process.env.FEATURE_BANNER || '';
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`<!doctype html><html><head><title>HLG Tracker ${APP_VERSION}</title></head>
<body style="font-family:system-ui,sans-serif;margin:2rem">
<div style="background:${BANNER_COLOUR};color:#fff;padding:1rem;border-radius:8px">
<h1 style="margin:0">Halsted Logistics — Shipment Tracker ${APP_VERSION}</h1></div>
<table style="margin-top:1rem;border-collapse:collapse" cellpadding="6">
<tr><td><b>APP_ENV</b> (slot setting — sticks to the slot)</td><td>${env}</td></tr>
<tr><td><b>FEATURE_BANNER</b> (normal setting — swaps with code)</td><td>${banner}</td></tr>
<tr><td><b>Instance</b></td><td>${os.hostname()}</td></tr>
<tr><td><b>WEBSITE_HOSTNAME</b></td><td>${process.env.WEBSITE_HOSTNAME || 'local'}</td></tr>
<tr><td><b>Served at</b></td><td>${new Date().toISOString()}</td></tr>
</table>
<p>Outbound VNet test: <code>/net?target=10.30.1.4</code></p>
</body></html>`);
}

function netTest(target, res) {
  if (!PRIVATE.test(target || '')) {
    res.writeHead(400, { 'Content-Type': 'text/plain' });
    return res.end('target must be a private IPv4 address, e.g. /net?target=10.30.1.4');
  }
  const req = http.get({ host: target, port: 80, path: '/', timeout: 4000 }, (r) => {
    let body = '';
    r.on('data', (c) => (body += c));
    r.on('end', () => {
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(`REACHED ${target} (HTTP ${r.statusCode})\n\n${body.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim()}`);
    });
  });
  req.on('timeout', () => req.destroy(new Error('timeout after 4s')));
  req.on('error', (e) => {
    res.writeHead(502, { 'Content-Type': 'text/plain' });
    res.end(`FAILED to reach ${target}: ${e.message}\nIs VNet integration configured? Is there a route and an NSG allow?`);
  });
}

http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/health') { res.writeHead(200); return res.end('ok'); }
  if (url.pathname === '/net') return netTest(url.searchParams.get('target'), res);
  return page(res);
}).listen(port, () => console.log(`HLG tracker ${APP_VERSION} listening on ${port}`));
