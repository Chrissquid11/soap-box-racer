/**
 * Makes the game's sound effects, procedurally -- noise, tones and envelopes, no recordings -- as WAV masters in
 * AssetsSource/audio/sfx/ (the asset pipeline exports each to src/assets/audio/sfx/*.ogg). Run it after changing a
 * recipe: `node scripts/sounds.ts`. Seeded: the same files every time.
 *
 *   roll        a loop: wheels rumbling on the road (the game plays it louder and higher with speed)
 *   wind        a loop: air rushing past (louder with speed)
 *   rattle      a loop: loose, damaged parts clattering
 *   scrape      a loop: a bare axle's metal on the road
 *   knock       a light knock: a thud and a rattle of wood
 *   crash       a heavy hit: a crunch and splinters
 *   gasp        the crowd's intake of breath after a big incident
 *   cheer       the crowd cheering a jump or a finish
 *   splash      into the duck pond
 *   beep, go    the start's countdown beep (each red lamp) and GO (green)
 *   chime       a bonus star collected
 */
import { mkdirSync, writeFileSync } from 'node:fs';

const RATE = 22050;
const dir = new URL('../AssetsSource/audio/sfx/', import.meta.url);
mkdirSync(dir, { recursive: true });

let seed = 12345;
const rnd = (): number => {
  seed = (Math.imul(seed, 1103515245) + 12345) >>> 0;
  return seed / 4294967296 * 2 - 1;
};

/** A one-pole low pass over a buffer, in place: `k` the share of each new sample (smaller, darker). */
function lowpass(b: Float32Array, k: number): Float32Array {
  let y = 0;
  for (let i = 0; i < b.length; i++) b[i] = y += (b[i]! - y) * k;
  return b;
}
function noise(n: number): Float32Array {
  const b = new Float32Array(n);
  for (let i = 0; i < n; i++) b[i] = rnd();
  return b;
}
/** Peak-normalised to `peak`. */
function norm(b: Float32Array, peak = 0.9): Float32Array {
  let m = 0;
  for (const v of b) m = Math.max(m, Math.abs(v));
  if (m > 0) for (let i = 0; i < b.length; i++) b[i] = (b[i]! / m) * peak;
  return b;
}
/** A loop's ends crossfaded over `fade` seconds, so it repeats without a click. */
function loopable(b: Float32Array, fade = 0.08): Float32Array {
  const f = Math.floor(fade * RATE);
  const out = b.slice(0, b.length - f);
  for (let i = 0; i < f; i++) {
    const t = i / f;
    out[i] = b[i]! * t + b[b.length - f + i]! * (1 - t);
  }
  return out;
}
function wav(name: string, b: Float32Array): void {
  const data = Buffer.alloc(b.length * 2);
  for (let i = 0; i < b.length; i++) data.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(b[i]! * 32767))), i * 2);
  const head = Buffer.alloc(44);
  head.write('RIFF', 0);
  head.writeUInt32LE(36 + data.length, 4);
  head.write('WAVE', 8);
  head.write('fmt ', 12);
  head.writeUInt32LE(16, 16);
  head.writeUInt16LE(1, 20);
  head.writeUInt16LE(1, 22);
  head.writeUInt32LE(RATE, 24);
  head.writeUInt32LE(RATE * 2, 28);
  head.writeUInt16LE(2, 32);
  head.writeUInt16LE(16, 34);
  head.write('data', 36);
  head.writeUInt32LE(data.length, 40);
  writeFileSync(new URL(`${name}.wav`, dir), Buffer.concat([head, data]));
  console.info(`${name}.wav  ${(b.length / RATE).toFixed(2)} s`);
}
const env = (n: number, attack: number, decay: number): ((i: number) => number) => (i) => {
  const t = i / RATE;
  return t < attack ? t / attack : Math.exp(-(t - attack) / decay);
};
const sec = (s: number): number => Math.floor(s * RATE);

// The loops.
{
  const n = sec(2.1);
  const b = lowpass(noise(n), 0.05);
  // Grit: little ticks of the road's texture over the rumble.
  for (let i = 0; i < n; i++) if (rnd() > 0.995) b[i] = b[i]! + rnd() * 0.5;
  for (let i = 0; i < n; i++) b[i] = b[i]! * (0.85 + 0.15 * Math.sin((i / RATE) * 2 * Math.PI * 9));
  wav('roll', norm(loopable(lowpass(b, 0.3)), 0.7));
}
{
  const n = sec(3.1);
  const b = lowpass(noise(n), 0.12);
  for (let i = 0; i < n; i++) b[i] = b[i]! * (0.7 + 0.3 * Math.sin((i / RATE) * 2 * Math.PI * 0.7));
  wav('wind', norm(loopable(b, 0.2), 0.6));
}
{
  const n = sec(1.6);
  const b = new Float32Array(n);
  // Wooden clatter: short knocks at uneven intervals, each a decaying burst.
  let t = 0;
  while (t < n - sec(0.06)) {
    const len = sec(0.03 + Math.abs(rnd()) * 0.03);
    const amp = 0.4 + Math.abs(rnd()) * 0.6;
    for (let i = 0; i < len; i++) b[t + i] = b[t + i]! + rnd() * amp * Math.exp(-i / (len * 0.3));
    t += sec(0.04 + Math.abs(rnd()) * 0.09);
  }
  wav('rattle', norm(loopable(lowpass(b, 0.35), 0.05), 0.6));
}
{
  const n = sec(1.8);
  const b = noise(n);
  // Metal on tarmac: bright noise with a squeal riding on it.
  for (let i = 0; i < n; i++) {
    const tt = i / RATE;
    b[i] = b[i]! * 0.6 + Math.sin(2 * Math.PI * (1900 + 200 * Math.sin(tt * 7)) * tt) * 0.25 * (0.6 + 0.4 * Math.sin(tt * 13));
  }
  wav('scrape', norm(loopable(lowpass(b, 0.6), 0.1), 0.55));
}
// The hits.
{
  const n = sec(0.35);
  const e = env(n, 0.003, 0.06);
  const b = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    b[i] = (Math.sin(2 * Math.PI * 95 * t) * 0.8 + rnd() * 0.5) * e(i);
  }
  wav('knock', norm(lowpass(b, 0.25), 0.8));
}
{
  const n = sec(0.9);
  const e = env(n, 0.002, 0.16);
  const b = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    b[i] = (Math.sin(2 * Math.PI * 60 * t) * 0.7 + rnd()) * e(i);
    // Splinters: crackles in the tail.
    if (t > 0.05 && rnd() > 0.97) b[i] = b[i]! + rnd() * Math.exp(-t * 4);
  }
  wav('crash', norm(lowpass(b, 0.45), 0.95));
}
// The crowd: many voices as band-limited noise, swelling.
{
  const n = sec(1.1);
  const b = lowpass(noise(n), 0.18);
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    // A sharp intake, then held, falling away.
    const a = t < 0.12 ? t / 0.12 : Math.exp(-(t - 0.12) / 0.45);
    b[i] = b[i]! * a * (0.8 + 0.2 * Math.sin(2 * Math.PI * 4 * t));
  }
  wav('gasp', norm(b, 0.7));
}
{
  const n = sec(2.4);
  const b = lowpass(noise(n), 0.22);
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    const a = t < 0.35 ? t / 0.35 : Math.exp(-(t - 0.35) / 1.1);
    // Whoops riding on the roar: a few voices rising.
    let whoop = 0;
    for (let v = 0; v < 5; v++) {
      const st = 0.1 + v * 0.27;
      if (t > st && t < st + 0.5) whoop += Math.sin(2 * Math.PI * (500 + v * 90 + (t - st) * 500) * t) * Math.sin(Math.PI * (t - st) / 0.5) * 0.12;
    }
    b[i] = (b[i]! + whoop) * a;
  }
  wav('cheer', norm(b, 0.75));
}
{
  const n = sec(1.2);
  const b = noise(n);
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    // The smack, then the water thrown up falling back.
    const smack = Math.exp(-t / 0.05);
    const fall = t > 0.1 ? Math.exp(-(t - 0.1) / 0.35) * 0.6 : 0;
    b[i] = b[i]! * (smack + fall) + Math.sin(2 * Math.PI * 80 * t) * smack * 0.6;
  }
  wav('splash', norm(lowpass(b, 0.5), 0.9));
}

// The start: a countdown beep for each red lamp, and a brighter, longer one for GO (green).
function tone(seconds: number, freq: number, decay: number, bright: number): Float32Array {
  const n = sec(seconds);
  const b = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    const a = Math.min(1, t / 0.005) * Math.exp(-t / decay);
    // A soft square: the tone and its odd harmonics, the higher ones fainter.
    const s = Math.sin(2 * Math.PI * freq * t) + bright * (Math.sin(2 * Math.PI * freq * 3 * t) / 3 + Math.sin(2 * Math.PI * freq * 5 * t) / 5);
    b[i] = s * a;
  }
  return b;
}
wav('beep', norm(tone(0.22, 660, 0.12, 0.6), 0.7));
wav('go', norm(tone(0.6, 1320, 0.28, 0.5), 0.75));
// A bonus star: three bright notes climbing, with a sparkle over them.
{
  const n = sec(0.7);
  const b = new Float32Array(n);
  const notes = [1046.5, 1318.5, 1568];
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    let s = 0;
    notes.forEach((f, k) => {
      const st = k * 0.07;
      if (t > st) s += Math.sin(2 * Math.PI * f * t) * Math.exp(-(t - st) / 0.18) * (k === 2 ? 1 : 0.7);
    });
    s += Math.sin(2 * Math.PI * 3136 * t) * Math.exp(-t / 0.3) * 0.15 * (0.5 + 0.5 * Math.sin(2 * Math.PI * 18 * t));
    b[i] = s;
  }
  wav('chime', norm(b, 0.7));
}

// The crowd, bigger. Many voices: band-limited noise in two registers, swelling and falling, with claps (short bright
// ticks at uneven times), whoops (rising voices) and whistles (a held high tone sliding).
function crowd(seconds: number, shape: (t: number) => number, claps: number, whoops: number, whistles: number): Float32Array {
  const n = sec(seconds);
  const low = lowpass(noise(n), 0.12);
  const high = lowpass(noise(n), 0.35);
  const b = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    b[i] = (low[i]! * 0.8 + high[i]! * 0.35) * (0.85 + 0.15 * Math.sin(2 * Math.PI * 3.3 * t + Math.sin(t * 1.7)));
  }
  // Claps.
  for (let c = 0; c < claps; c++) {
    const at = Math.floor(Math.abs(rnd()) * (n - sec(0.03)));
    const len = sec(0.012);
    const amp = 0.3 + Math.abs(rnd()) * 0.5;
    for (let i = 0; i < len; i++) b[at + i] = b[at + i]! + rnd() * amp * (1 - i / len);
  }
  // Whoops: voices rising, each its own pitch and moment.
  for (let w = 0; w < whoops; w++) {
    const st = Math.abs(rnd()) * seconds * 0.8, len = 0.35 + Math.abs(rnd()) * 0.4, f0 = 380 + Math.abs(rnd()) * 420;
    const s0 = sec(st), sl = sec(len);
    for (let i = 0; i < sl && s0 + i < n; i++) {
      const t = i / RATE;
      const f = f0 * (1 + 0.6 * (t / len));
      b[s0 + i] = b[s0 + i]! + Math.sin(2 * Math.PI * f * t + Math.sin(2 * Math.PI * 6 * t) * 0.6) * Math.sin(Math.PI * t / len) * 0.13;
    }
  }
  // Whistles: two-finger, high, sliding up then down.
  for (let w = 0; w < whistles; w++) {
    const st = Math.abs(rnd()) * seconds * 0.7, len = 0.5 + Math.abs(rnd()) * 0.5;
    const s0 = sec(st), sl = sec(len);
    let ph = 0;
    for (let i = 0; i < sl && s0 + i < n; i++) {
      const t = i / RATE;
      ph += (2 * Math.PI * (2300 + 500 * Math.sin(Math.PI * t / len))) / RATE;
      b[s0 + i] = b[s0 + i]! + Math.sin(ph) * Math.sin(Math.PI * t / len) * 0.08;
    }
  }
  for (let i = 0; i < n; i++) b[i] = b[i]! * shape(i / RATE);
  return b;
}
// A big roar: up fast, held, slowly away -- the start and the finish.
wav('roar', norm(crowd(3.6, (t) => (t < 0.3 ? t / 0.3 : Math.exp(-(t - 0.3) / 1.8)), 160, 9, 3), 0.85));
// "Ooooh!" at a crash: a low rising groan of many voices, then cheering and laughing at it.
{
  const n = sec(2.2);
  const b = crowd(2.2, (t) => (t < 0.15 ? t / 0.15 : t < 0.7 ? 1 : Math.exp(-(t - 0.7) / 0.8)), 50, 5, 1);
  // The "ooh": a vowel -- formants near 400 and 800 Hz over a buzz of many voices -- sliding up, the first 0.7 s.
  for (let i = 0; i < sec(0.8); i++) {
    const t = i / RATE;
    const a = Math.min(1, t / 0.08) * (t < 0.6 ? 1 : 1 - (t - 0.6) / 0.2);
    let v = 0;
    for (let k = 0; k < 6; k++) {
      const f = (150 + k * 23) * (1 + 0.25 * t);
      v += Math.sin(2 * Math.PI * f * t + k) * 0.5 + Math.sin(2 * Math.PI * f * 2.7 * t + k) * 0.2;
    }
    b[i] = b[i]! + v * a * 0.12;
  }
  wav('ooh', norm(lowpass(b.subarray(0, n), 0.6), 0.85));
}
// The crowd waiting: a murmur, chatter, the odd clap -- a loop.
wav('murmur', norm(loopable(crowd(4.2, () => 0.6, 12, 2, 0), 0.3), 0.5));
