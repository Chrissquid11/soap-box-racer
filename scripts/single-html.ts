/**
 * Packs the release build (dist/, from `npm run build`) into ONE html file anyone can open straight off their disk
 * (file://) and play: `node scripts/single-html.ts [out.html]` (default dist-single/soap-box-racer.html).
 *
 * A browser will not load a module script, a model or a sound from file:// by URL, so every file of dist/ is carried
 * inside the page (base64) and served from memory:
 *   - the JavaScript chunks become blob: modules, found by an import map (each chunk's imports of another rewritten
 *     to a bare `@sbr/<name>` the map knows), and `import.meta.url` in them reads as the page's own assets/ folder;
 *   - every other file (models, sounds, wasm, fonts, packs) is answered from memory when the game asks for it --
 *     fetch, XMLHttpRequest, an <img>'s src and a FontFace's url() -- by its path under the page's folder;
 *   - the stylesheet is inlined, its url()s data: URIs.
 * The Poki SDK's <script> (from the web) is left out: offline there is no web.
 */
import { mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { basename, dirname, join, relative } from 'node:path';

const dist = new URL('../dist/', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const out = process.argv[2] ?? join(dist, '..', 'dist-single', 'soap-box-racer.html');

const TYPES: Record<string, string> = {
  js: 'text/javascript', css: 'text/css', json: 'application/json', glb: 'model/gltf-binary', ogg: 'audio/ogg',
  mp3: 'audio/mpeg', wav: 'audio/wav', wasm: 'application/wasm', woff2: 'font/woff2', woff: 'font/woff',
  ttf: 'font/ttf', svg: 'image/svg+xml', png: 'image/png', jpg: 'image/jpeg', webp: 'image/webp', ktx2: 'image/ktx2',
  bin: 'application/octet-stream', txt: 'text/plain', md: 'text/markdown',
};
const typeOf = (f: string): string => TYPES[f.split('.').pop()!.toLowerCase()] ?? 'application/octet-stream';

function walk(dir: string): string[] {
  const files: string[] = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) files.push(...walk(p));
    else files.push(p);
  }
  return files;
}

const all = walk(dist).map((p) => relative(dist, p).replace(/\\/g, '/')).filter((p) => p !== 'index.html' && !p.endsWith('README.md'));
const chunks = all.filter((p) => p.startsWith('assets/') && p.endsWith('.js'));
const chunkNames = new Set(chunks.map((p) => basename(p)));
const escape = (s: string): string => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// The chunks: imports of one another made bare (@sbr/<name>), import.meta.url their own place under the page.
const code: Record<string, string> = {};
for (const p of chunks) {
  let js = readFileSync(join(dist, p), 'utf8');
  for (const name of chunkNames) {
    js = js.replace(new RegExp(`(["'\`])(?:\\./|assets/)${escape(name)}\\1`, 'g'), `$1@sbr/${name}$1`);
  }
  js = js.replace(/import\.meta\.url/g, `(globalThis.__sbrBase+${JSON.stringify(p)})`);
  code[basename(p)] = js;
}

// Everything else, as base64.
const files: Record<string, [string, string]> = {};
for (const p of all) {
  // (The chunks too: a few -- the decoders' wrappers -- are fetched as text, not imported.)
  if (p.endsWith('.css')) continue;
  files[p] = [typeOf(p), readFileSync(join(dist, p)).toString('base64')];
}

// The stylesheet, inlined: its url()s data: URIs.
let css = '';
for (const p of all.filter((f) => f.endsWith('.css'))) {
  css += readFileSync(join(dist, p), 'utf8').replace(/url\((['"]?)([^'")]+)\1\)/g, (m, _q, u: string) => {
    if (u.startsWith('data:') || u.startsWith('http')) return m;
    const target = join(dirname(p), u).replace(/\\/g, '/');
    const hit = files[target];
    return hit ? `url(data:${hit[0]};base64,${hit[1]})` : m;
  });
}

const html = readFileSync(join(dist, 'index.html'), 'utf8');
const entry = /<script type="module"[^>]*src="\.\/assets\/([^"]+)"[^>]*><\/script>/.exec(html)?.[1];
if (!entry) throw new Error('no entry module in dist/index.html');

const boot = `
(() => {
  const base = new URL('.', location.href).href;
  globalThis.__sbrBase = base;
  const code = JSON.parse(document.getElementById('sbr-code').textContent);
  const files = JSON.parse(document.getElementById('sbr-files').textContent);
  const blobs = new Map();
  const blobOf = (path) => {
    let b = blobs.get(path);
    if (b) return b;
    const f = files[path];
    if (!f) return null;
    const bin = atob(f[1]);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    b = new Blob([bytes], { type: f[0] });
    blobs.set(path, b);
    return b;
  };
  const urls = new Map();
  const urlOf = (path) => { let u = urls.get(path); if (!u) { const b = blobOf(path); if (!b) return null; u = URL.createObjectURL(b); urls.set(path, u); } return u; };
  // A URL under the page's folder that is one of the packed files: its path, else null.
  const pathOf = (input) => {
    try {
      const href = new URL(typeof input === 'string' ? input : input.url ?? String(input), base).href.split(/[?#]/)[0];
      if (!href.startsWith(base)) return null;
      const p = decodeURIComponent(href.slice(base.length));
      return files[p] ? p : null;
    } catch { return null; }
  };
  // The modules: a blob each, found through the import map.
  const imports = {};
  for (const name in code) {
    const u = URL.createObjectURL(new Blob([code[name]], { type: 'text/javascript' }));
    imports['@sbr/' + name] = u;
    imports[base + 'assets/' + name] = u;
    // (The preloader resolves a dependency's @sbr/<name> against the chunk's folder: that too.)
    imports[base + 'assets/@sbr/' + name] = u;
  }
  const map = document.createElement('script');
  map.type = 'importmap';
  map.textContent = JSON.stringify({ imports });
  document.currentScript.after(map);
  // Asked for by the game: answered from memory.
  const realFetch = globalThis.fetch.bind(globalThis);
  globalThis.fetch = (input, init) => {
    const p = pathOf(input);
    if (!p) return realFetch(input, init);
    const b = blobOf(p);
    return Promise.resolve(new Response(b, { status: 200, headers: { 'Content-Type': files[p][0], 'Content-Length': String(b.size) } }));
  };
  const open = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url, ...rest) {
    const p = pathOf(url);
    return open.call(this, method, p ? urlOf(p) : url, ...rest);
  };
  const src = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
  Object.defineProperty(HTMLImageElement.prototype, 'src', {
    get() { return src.get.call(this); },
    set(v) { const p = pathOf(v); src.set.call(this, p ? urlOf(p) : v); },
    configurable: true,
  });
  const RealFontFace = globalThis.FontFace;
  if (RealFontFace) {
    globalThis.FontFace = function (family, source, desc) {
      if (typeof source === 'string') source = source.replace(/url\\((['"]?)([^'")]+)\\1\\)/g, (m, q, u) => { const p = pathOf(u); return p ? 'url(' + urlOf(p) + ')' : m; });
      return new RealFontFace(family, source, desc);
    };
    globalThis.FontFace.prototype = RealFontFace.prototype;
  }
})();
`;

const json = (v: unknown): string => JSON.stringify(v).replace(/<\/script/gi, '<\\/script');
let page = html
  .replace(/<script src="https:\/\/game-cdn\.poki\.com[^"]*"><\/script>\s*/, '')
  .replace(/<script type="module"[^>]*src="\.\/assets\/[^"]+"[^>]*><\/script>\s*/, '')
  .replace(/<link rel="modulepreload"[^>]*>\s*/g, '')
  .replace(/<link rel="stylesheet"[^>]*>\s*/g, '');
// (A function, not a string: the code is full of `$&`-like runs a replacement string would expand.)
page = page.replace('</head>', () => `<style>${css}</style>
<script type="application/json" id="sbr-code">${json(code)}</script>
<script type="application/json" id="sbr-files">${json(files)}</script>
<script>${boot}</script>
<script type="module">import '@sbr/${entry}';</script>
</head>`);

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, page);
console.info(`${out}  ${(page.length / 1048576).toFixed(1)} MB  (${chunks.length} modules, ${Object.keys(files).length} files)`);
