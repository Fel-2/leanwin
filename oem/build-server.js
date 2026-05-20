const http = require('http');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const ROOT = 'C:\\builds';
const PS = 'powershell.exe';
const CMD = 'cmd.exe';
const TOKEN = process.env.LEANWIN_TOKEN || '';

// Discover Python install dirs (version drift: choco may install Python3xx).
const pythonDirs = () => {
  const found = [];
  for (const base of ['C:\\', 'C:\\Users\\builder\\AppData\\Local\\Programs\\Python\\']) {
    try {
      for (const name of fs.readdirSync(base)) {
        if (/^Python3\d+$/i.test(name)) {
          const full = path.join(base, name);
          found.push(full, path.join(full, 'Scripts'));
        }
      }
    } catch {}
  }
  return found;
};

// Ensure dev tools are in PATH (scheduled tasks may not load user profile)
const TOOL_DIRS = [
  'C:\\Users\\builder\\.cargo\\bin',
  'C:\\ProgramData\\mingw64\\mingw64\\bin',
  'C:\\Program Files\\nodejs',
  'C:\\Program Files (x86)\\WiX Toolset v3.14\\bin',
  'C:\\nvm',
  ...pythonDirs(),
];
const userPath = TOOL_DIRS.filter(d => { try { return fs.statSync(d).isDirectory(); } catch { return false; } }).join(';');
process.env.PATH = process.env.PATH + ';' + userPath;

if (!fs.existsSync(ROOT)) fs.mkdirSync(ROOT, { recursive: true });

const ok = (res, data) => { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(data)); };
const fail = (res, code, msg) => { res.writeHead(code, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ ok: false, stderr: msg })); };

const execCmd = (cmd, cwd, cb) => {
  // cmd.exe uses & (not ;) for chaining. Convert ; to & for common commands.
  // Prefix with 'ps:' to force PowerShell when needed (e.g., for PS cmdlets).
  const usePs = cmd.startsWith('ps:');
  const shell = usePs ? PS : CMD;
  let cleanCmd = usePs ? cmd.slice(3) : cmd.replace(/ ; /g, ' & ');
  exec(cleanCmd, { cwd, shell, timeout: 600000 }, (err, stdout, stderr) => {
    // cmd.exe sets err only on actual failures (exit code != 0).
    // PowerShell may set err for stderr output even on success —
    // trust the exit code from err.code.
    const code = err ? (typeof err.code === 'number' ? err.code : 1) : 0;
    cb({ ok: code === 0, stdout: stdout || '', stderr: stderr || '', exitCode: code });
  });
};

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET,POST,OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type,X-Auth-Token' };

  if (req.method === 'OPTIONS') { res.writeHead(204, cors); return res.end(); }

  // GET /health — unauthenticated readiness probe for CI
  if (req.method === 'GET' && url.pathname === '/health') {
    return ok(res, { ok: true, service: 'leanwin-build-server' });
  }

  // Optional auth: if LEANWIN_TOKEN is set, require matching X-Auth-Token header.
  if (TOKEN && req.headers['x-auth-token'] !== TOKEN) {
    return fail(res, 401, 'unauthorized');
  }

  // POST /exec — run a command, return {ok,stdout,stderr,exitCode}
  if (req.method === 'POST' && url.pathname === '/exec') {
    let body = '';
    req.on('data', c => body += c);
    req.on('end', () => {
      try {
        const { cmd, cwd = ROOT } = JSON.parse(body);
        if (!cmd) return fail(res, 400, 'missing cmd');
        execCmd(cmd, cwd, result => ok(res, result));
      } catch (e) { fail(res, 400, e.message); }
    });
    return;
  }

  // POST /upload?dest=C:\path\to\file — stream raw body to destination
  if (req.method === 'POST' && url.pathname === '/upload') {
    const dest = url.searchParams.get('dest');
    if (!dest) return fail(res, 400, 'missing dest param');
    const dir = path.dirname(dest);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    const ws = fs.createWriteStream(dest);
    req.pipe(ws);
    ws.on('finish', () => ok(res, { ok: true, path: dest }));
    ws.on('error', e => fail(res, 500, e.message));
    return;
  }

  // GET /download?path=C:\path\to\file — stream artifact back
  if (req.method === 'GET' && url.pathname === '/download') {
    const filePath = url.searchParams.get('path');
    if (!filePath) return fail(res, 400, 'missing path');
    try {
      if (!fs.existsSync(filePath)) return fail(res, 404, 'file not found');
      const stat = fs.statSync(filePath);
      res.writeHead(200, {
        'Content-Type': 'application/octet-stream',
        'Content-Length': stat.size,
        'Content-Disposition': `attachment; filename="${path.basename(filePath)}"`,
      });
      fs.createReadStream(filePath).pipe(res);
    } catch (e) { fail(res, 500, e.message); }
    return;
  }

  fail(res, 404, 'unknown endpoint — try /exec /upload /download');
});

server.listen(PORT, () => console.log(`Build server listening on port ${PORT}`));
process.on('uncaughtException', e => console.error('uncaught:', e));
