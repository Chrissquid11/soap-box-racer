/**
 * Makes the workshop's sounds, procedurally -- tones, noise and envelopes, no recordings -- as WAV masters in
 * AssetsSource/audio/ui/ (the asset pipeline exports each to src/assets/audio/ui/*.ogg, played with `Audio.ui`).
 * Run it after changing a recipe: `node scripts/ui-sounds.ts`. Seeded: the same files every time.
 *
 *   clunk    a kart (chassis, bodywork) set down on the bench: a wooden thud and a settle
 *   wheel    a wheel fitted: a rubber thump, a little bounce, the hub ticking round
 *   boing    suspension fitted: a spring twanging
 *   ratchet  steering (or brakes) fitted: a spanner's ratchet, click-click-click
 *   zip      the driver's outfit or paint changed: a zip pulled up
 *   denied   a locked part pressed: two low dull bonks
 *   tab      a workshop tab opened: a soft paper swish
 *   tick     a size slider moved a step: a tiny tick
 *   honk     RACE!: a bicycle horn, honk-honk
 */
import { mkdirSync, writeFileSync } from 'node:fs';

const RATE = 22050;
const dir = new URL('../AssetsSource/audio/ui/', import.meta.url);
mkdirSync(dir, { recursive: true });

let seed = 4242;
const rnd = (): number => {
  seed = (Math.imul(seed, 1103515245) + 12345) >>> 0;
  return seed / 4294967296 * 2 - 1;
};
const TAU = Math.PI * 2;
const buf = (s: number): Float32Array => new Float32Array(Math.floor(s * RATE));

function norm(b: Float32Array, peak: number): Float32Array {
  let m = 0;
  for (const v of b) m = Math.max(m, Math.abs(v));
  if (m > 0) for (let i = 0; i < b.length; i++) b[i] = (b[i]! / m) * peak;
  // A few milliseconds faded out at the end: no click.
  const f = Math.min(b.length, Math.floor(0.004 * RATE));
  for (let i = 0; i < f; i++) b[b.length - 1 - i]! *= i / f;
  return b;
}

/** Into `b` from `at` seconds: a tone gliding from `f0` to `f1` Hz (exponentially, over `glide` s), decaying over `decay`
 * s after an `attack`, `amp` loud; `shape` 0 a sine, 1 rich (a few harmonics). */
function tone(b: Float32Array, at: number, len: number, f0: number, f1: number, glide: number, attack: number, decay: number, amp: number, shape = 0): void {
  let ph = 0;
  const start = Math.floor(at * RATE);
  for (let i = 0; i < len * RATE && start + i < b.length; i++) {
    const t = i / RATE;
    const f = f1 + (f0 - f1) * Math.exp(-t / glide);
    ph += (TAU * f) / RATE;
    const e = t < attack ? t / attack : Math.exp(-(t - attack) / decay);
    const w = shape === 0 ? Math.sin(ph) : Math.sin(ph) + 0.5 * Math.sin(2 * ph) + 0.3 * Math.sin(3 * ph) + 0.15 * Math.sin(4 * ph);
    b[start + i]! += w * e * amp;
  }
}

/** Into `b` from `at`: a burst of noise, low passed (`k`, smaller darker; `high` true: high passed instead). */
function hiss(b: Float32Array, at: number, len: number, k: number, attack: number, decay: number, amp: number, high = false): void {
  let y = 0, last = 0;
  const start = Math.floor(at * RATE);
  for (let i = 0; i < len * RATE && start + i < b.length; i++) {
    const t = i / RATE;
    const n = rnd();
    y += (n - y) * k;
    const v = high ? n - last : y;
    last = n;
    const e = t < attack ? t / attack : Math.exp(-(t - attack) / decay);
    b[start + i]! += v * e * amp;
  }
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

// clunk: a wooden thud, then a smaller one as it settles.
{
  const b = buf(0.32);
  tone(b, 0, 0.3, 150, 62, 0.03, 0.002, 0.06, 1);
  hiss(b, 0, 0.08, 0.25, 0.001, 0.02, 0.6);
  tone(b, 0.085, 0.2, 130, 70, 0.02, 0.002, 0.04, 0.45);
  hiss(b, 0.085, 0.05, 0.3, 0.001, 0.012, 0.25);
  wav('clunk', norm(b, 0.9));
}
// wheel: a rubber thump, a bounce, the hub ticking round and slowing.
{
  const b = buf(0.5);
  tone(b, 0, 0.2, 210, 90, 0.025, 0.003, 0.05, 1);
  tone(b, 0.11, 0.15, 180, 95, 0.02, 0.003, 0.035, 0.4);
  let at = 0.16, gap = 0.028;
  for (let k = 0; k < 8; k++) {
    hiss(b, at, 0.01, 0.9, 0.0005, 0.002, 0.35 * (1 - k / 9), true);
    tone(b, at, 0.02, 2600, 2600, 1, 0.0005, 0.004, 0.12 * (1 - k / 9));
    at += gap;
    gap *= 1.12;
  }
  wav('wheel', norm(b, 0.85));
}
// boing: a spring's twang, wobbling and dying away.
{
  const b = buf(0.55);
  let ph = 0;
  for (let i = 0; i < b.length; i++) {
    const t = i / RATE;
    const f = 200 * (1 + 0.35 * Math.exp(-t / 0.12) * Math.sin(TAU * 16 * t)) * (1 + 0.4 * Math.exp(-t / 0.03));
    ph += (TAU * f) / RATE;
    const e = Math.min(1, t / 0.004) * Math.exp(-t / 0.18);
    b[i] = (Math.sin(ph) + 0.25 * Math.sin(2 * ph)) * e;
  }
  hiss(b, 0, 0.03, 0.6, 0.001, 0.008, 0.3);
  wav('boing', norm(b, 0.8));
}
// ratchet: a spanner, six quick clicks.
{
  const b = buf(0.26);
  for (let k = 0; k < 6; k++) {
    const at = k * 0.036 + (k % 2) * 0.004;
    hiss(b, at, 0.012, 0.9, 0.0003, 0.0025, 0.8, true);
    tone(b, at, 0.03, 3100 - k * 60, 2900, 0.01, 0.0005, 0.006, 0.35);
    tone(b, at, 0.03, 900, 700, 0.01, 0.0005, 0.008, 0.2);
  }
  wav('ratchet', norm(b, 0.8));
}
// zip: a zip pulled up -- its teeth clicking faster and higher.
{
  const b = buf(0.24);
  let t = 0, rate = 70;
  while (t < 0.22) {
    hiss(b, t, 0.008, 0.7, 0.0003, 0.0018, 0.6, true);
    tone(b, t, 0.01, 1200 + rate * 6, 1200 + rate * 6, 1, 0.0003, 0.002, 0.15);
    t += 1 / rate;
    rate = Math.min(400, rate * 1.09);
  }
  hiss(b, 0, 0.24, 0.35, 0.05, 0.12, 0.12);
  wav('zip', norm(b, 0.7));
}
// denied: two low, dull bonks.
{
  const b = buf(0.3);
  tone(b, 0, 0.12, 165, 150, 0.05, 0.004, 0.05, 1, 1);
  tone(b, 0.13, 0.15, 125, 112, 0.05, 0.004, 0.06, 1, 1);
  // Dulled: a low pass.
  let y = 0;
  for (let i = 0; i < b.length; i++) b[i] = y += (b[i]! - y) * 0.18;
  wav('denied', norm(b, 0.75));
}
// tab: a soft paper swish with a tick.
{
  const b = buf(0.16);
  hiss(b, 0, 0.16, 0.45, 0.025, 0.04, 0.7, true);
  tone(b, 0, 0.02, 1800, 1500, 0.01, 0.0005, 0.005, 0.3);
  wav('tab', norm(b, 0.55));
}
// tick: a slider's step.
{
  const b = buf(0.03);
  tone(b, 0, 0.03, 2200, 1900, 0.01, 0.0003, 0.004, 1);
  hiss(b, 0, 0.006, 0.9, 0.0002, 0.0012, 0.4, true);
  wav('tick', norm(b, 0.5));
}
// honk: a bicycle horn's rubber bulb, twice.
{
  const b = buf(0.5);
  for (const at of [0, 0.22]) {
    tone(b, at, 0.2, 470, 400, 0.04, 0.008, 0.09, 1, 1);
    tone(b, at, 0.2, 940, 800, 0.04, 0.008, 0.07, 0.3, 1);
    hiss(b, at, 0.15, 0.3, 0.01, 0.05, 0.12);
  }
  wav('honk', norm(b, 0.85));
}
