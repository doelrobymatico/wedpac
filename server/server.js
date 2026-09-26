'use strict';
// Palet Pelaminan server: serves index.html and keeps one shared palette so
// several devices see the same colours. No dependencies; runs on Node 12+.
//
// Environment:
//   PORT            port to listen on (default 8080)
//   HOST            address to bind (default 127.0.0.1, behind a reverse proxy)
//   PALET_PASSWORD  password for HTTP Basic auth; empty disables auth
//   DATA_DIR        where palette.json is stored (default ./data)

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = Number(process.env.PORT) || 8080;
const HOST = process.env.HOST || '127.0.0.1';
const PASSWORD = process.env.PALET_PASSWORD || '';
const ROOT = path.join(__dirname, '..');
const DATA_DIR = process.env.DATA_DIR || path.join(ROOT, 'data');
const DATA_FILE = path.join(DATA_DIR, 'palette.json');
const INDEX_FILE = path.join(ROOT, 'index.html');
const MAX_BODY = 64 * 1024;
const ROLES = ['panggung', 'bunga', 'gaun', 'jas', 'seserahan', 'keluarga', 'bridesmaid', 'panitia', 'custom'];

function loadDoc() {
  try {
    const d = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    if (d && Array.isArray(d.items) && Number.isInteger(d.version)) return d;
  } catch (e) { /* first run or unreadable file: start empty */ }
  return { version: 0, updatedAt: null, items: null };
}

function saveDoc(d) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  const tmp = DATA_FILE + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(d));
  fs.renameSync(tmp, DATA_FILE);
}

function validItems(items) {
  if (!Array.isArray(items) || items.length < 1 || items.length > 40) return false;
  return items.every(it => it && typeof it === 'object'
    && ROLES.indexOf(it.role) !== -1
    && typeof it.name === 'string' && it.name.length > 0 && it.name.length <= 40
    && typeof it.hex === 'string' && /^#[0-9A-F]{6}$/i.test(it.hex));
}

const sha = s => crypto.createHash('sha256').update(String(s)).digest();
const PASS_HASH = sha(PASSWORD);
function authorized(req) {
  if (!PASSWORD) return true;
  const m = /^Basic\s+(.+)$/i.exec(req.headers.authorization || '');
  if (!m) return false;
  const decoded = Buffer.from(m[1], 'base64').toString('utf8');
  const pass = decoded.slice(decoded.indexOf(':') + 1);
  return crypto.timingSafeEqual(sha(pass), PASS_HASH);
}

function send(res, status, body, type) {
  res.writeHead(status, {
    'Content-Type': type || 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'no-referrer',
    'X-Frame-Options': 'DENY'
  });
  res.end(typeof body === 'string' || Buffer.isBuffer(body) ? body : JSON.stringify(body));
}

let doc = loadDoc();

const server = http.createServer((req, res) => {
  const url = (req.url || '/').split('?')[0];

  if (!authorized(req)) {
    res.setHeader('WWW-Authenticate', 'Basic realm="Palet Pelaminan", charset="UTF-8"');
    // small delay slows down password guessing
    setTimeout(() => send(res, 401, { error: 'Password salah' }), 400);
    return;
  }

  if ((url === '/' || url === '/index.html') && (req.method === 'GET' || req.method === 'HEAD')) {
    fs.readFile(INDEX_FILE, (err, buf) => {
      if (err) return send(res, 500, { error: 'index.html tidak ditemukan' });
      send(res, 200, req.method === 'HEAD' ? '' : buf, 'text/html; charset=utf-8');
    });
    return;
  }

  if (url === '/api/palette') {
    if (req.method === 'GET') return send(res, 200, doc);
    if (req.method === 'PUT') {
      let size = 0;
      const chunks = [];
      req.on('data', c => {
        size += c.length;
        if (size > MAX_BODY) { send(res, 413, { error: 'Data terlalu besar' }); req.destroy(); return; }
        chunks.push(c);
      });
      req.on('end', () => {
        if (res.headersSent) return;
        let body;
        try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch (e) { return send(res, 400, { error: 'JSON tidak valid' }); }
        if (!body || !validItems(body.items)) return send(res, 400, { error: 'Data palet tidak valid' });
        const next = {
          version: doc.version + 1,
          updatedAt: new Date().toISOString(),
          items: body.items.map(it => ({ role: it.role, name: it.name, hex: it.hex.toUpperCase() }))
        };
        try { saveDoc(next); } catch (e) { return send(res, 500, { error: 'Gagal menyimpan: ' + e.message }); }
        doc = next;
        send(res, 200, doc);
      });
      return;
    }
    res.setHeader('Allow', 'GET, PUT');
    return send(res, 405, { error: 'Metode tidak didukung' });
  }

  send(res, 404, { error: 'Tidak ditemukan' });
});

server.listen(PORT, HOST, () => {
  console.log(`Palet Pelaminan berjalan di http://${HOST}:${PORT}` + (PASSWORD ? ' (dengan password)' : ' (TANPA password)'));
});
