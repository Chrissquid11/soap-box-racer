/**
 * Makes the game's music and its menu sounds, procedurally -- oscillators, noise and envelopes, no recordings -- as
 * WAV masters the asset pipeline exports to .ogg. Run it after changing a tune: `node scripts/music.ts`. The same
 * files every time.
 *
 *   music/race      the run: a bright, bouncy loop, 150 bpm, C major (C G Am F)
 *   music/garage    the garage and the menus: a relaxed loop, 100 bpm, F major sevenths
 *   ui/click        a button pressed: a short wooden tick
 *   sfx/fanfare     over the finish line: a brassy climb and a held chord
 *   sfx/unlock      a course unlocked: a rising sweep and a bell
 *
 * Each loop is an exact number of bars long and its tails wrap round to its start, so it repeats without a seam.
 */
import { mkdirSync, writeFileSync } from 'node:fs';

const RATE = 32000;

let seed = 777;
const rnd = (): number => {
  seed = (Math.imul(seed, 1103515245) + 12345) >>> 0;
  return seed / 4294967296 * 2 - 1;
};

function wav(folder: string, name: string, b: Float32Array, peak: number): void {
  let m = 0;
  for (const v of b) m = Math.max(m, Math.abs(v));
  const k = m > 0 ? peak / m : 0;
  const data = Buffer.alloc(b.length * 2);
  for (let i = 0; i < b.length; i++) data.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(b[i]! * k * 32767))), i * 2);
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
  const dir = new URL(`../AssetsSource/audio/${folder}/`, import.meta.url);
  mkdirSync(dir, { recursive: true });
  writeFileSync(new URL(`${name}.wav`, dir), Buffer.concat([head, data]));
  console.info(`${folder}/${name}.wav  ${(b.length / RATE).toFixed(2)} s`);
}

/** A note's frequency from its MIDI number. */
const hz = (n: number): number => 440 * Math.pow(2, (n - 69) / 12);

/** A track: samples added in, wrapping round its end when `loop`. */
class Track {
  readonly b: Float32Array;
  readonly loop: boolean;
  constructor(seconds: number, loop: boolean) {
    this.b = new Float32Array(Math.round(seconds * RATE));
    this.loop = loop;
  }
  add(i: number, v: number): void {
    const n = this.b.length;
    if (this.loop) this.b[((i % n) + n) % n] += v;
    else if (i >= 0 && i < n) this.b[i] += v;
  }
  /** A voice from `at` seconds, `len` long: `wave(t)` shaped by an attack and a release. */
  note(at: number, len: number, wave: (t: number) => number, vol: number, attack = 0.005, release = 0.08): void {
    const s = Math.round(at * RATE), n = Math.round((len + release) * RATE);
    for (let i = 0; i < n; i++) {
      const t = i / RATE;
      const a = t < attack ? t / attack : t < len ? 1 : Math.max(0, 1 - (t - len) / release);
      this.add(s + i, wave(t) * a * vol);
    }
  }
}

// The instruments.
const square = (f: number, bright = 0.5) => (t: number): number => {
  const p = 2 * Math.PI * f * t;
  return Math.sin(p) + bright * (Math.sin(3 * p) / 3 + Math.sin(5 * p) / 5 + Math.sin(7 * p) / 7);
};
const pluck = (f: number, decay: number) => (t: number): number => {
  const p = 2 * Math.PI * f * t;
  return (Math.sin(p) + 0.35 * Math.sin(2 * p)) * Math.exp(-t / decay);
};
const keys = (f: number) => (t: number): number => {
  const p = 2 * Math.PI * f * t;
  // An electric piano: the tone, a soft bell partial dying quickly.
  return (Math.sin(p) + 0.25 * Math.sin(p * 4.01) * Math.exp(-t / 0.15)) * Math.exp(-t / 1.2);
};
const vibrato = (f: number, bright: number) => (t: number): number => square(f * (1 + 0.006 * Math.sin(2 * Math.PI * 5.5 * t) * Math.min(1, t * 4)), bright)(t);

function kick(tr: Track, at: number, vol: number): void {
  tr.note(at, 0.18, (t) => Math.sin(2 * Math.PI * (50 + 90 * Math.exp(-t / 0.03)) * t) * Math.exp(-t / 0.09), vol, 0.001, 0.02);
}
function snare(tr: Track, at: number, vol: number): void {
  let y = 0;
  tr.note(at, 0.16, (t) => (y += (rnd() - y) * 0.6) * Math.exp(-t / 0.06) + Math.sin(2 * Math.PI * 190 * t) * Math.exp(-t / 0.03) * 0.5, vol, 0.001, 0.02);
}
function hat(tr: Track, at: number, vol: number): void {
  let last = 0;
  tr.note(at, 0.04, () => { const n = rnd(); const h = n - last; last = n; return h; }, vol, 0.001, 0.02);
}

// The race: 150 bpm, 8 bars of C G Am F twice over, a bass on the eighths, a lead over it.
{
  const bpm = 150, beat = 60 / bpm, bars = 16;
  const tr = new Track(bars * 4 * beat, true);
  const chords = [[48, 52, 55], [43, 47, 50], [45, 48, 52], [41, 45, 48]];
  // The lead: a phrase a bar, two eighths a step (-1 a rest), in C major's notes.
  const phrases = [
    [72, 76, 79, 76, 74, 72, 74, -1],
    [71, 74, 79, 74, 71, 67, 71, -1],
    [72, 76, 81, 79, 76, 72, 76, 79],
    [77, 76, 74, 72, 74, -1, 72, -1],
    [79, 79, 76, 79, 81, 79, 76, -1],
    [74, 74, 71, 74, 79, 77, 74, -1],
    [76, 76, 72, 76, 81, 79, 76, 72],
    [77, 79, 81, 77, 72, -1, -1, -1],
  ];
  for (let bar = 0; bar < bars; bar++) {
    const t0 = bar * 4 * beat;
    const ch = chords[bar % 4]!;
    for (let s = 0; s < 8; s++) {
      const t = t0 + s * beat / 2;
      tr.note(t, beat * 0.4, pluck(hz(ch[0]! - 12 + (s % 4 === 3 ? 7 : 0)), 0.18), 0.55, 0.003, 0.03);
      hat(tr, t, s % 2 ? 0.12 : 0.18);
    }
    for (let q = 0; q < 4; q++) {
      if (q % 2 === 0) kick(tr, t0 + q * beat, 0.9);
      else snare(tr, t0 + q * beat, 0.35);
      // Off-beat chord stabs.
      for (const n of ch) tr.note(t0 + q * beat + beat / 2, beat * 0.22, square(hz(n + 12), 0.3), 0.07, 0.003, 0.05);
    }
    // The lead sits out the first two bars, then plays.
    if (bar >= 2) {
      const ph = phrases[(bar - 2) % 8]!;
      ph.forEach((n, s) => { if (n > 0) tr.note(t0 + s * beat / 2, beat * 0.45, vibrato(hz(n), 0.45), 0.2, 0.01, 0.06); });
    }
  }
  wav('music', 'race', tr.b, 0.5);
}

// The garage: 100 bpm, swung, Fmaj7 Em7 Dm7 Cmaj7, electric piano, a walking bass, brushed hats.
{
  const bpm = 100, beat = 60 / bpm, bars = 8;
  const tr = new Track(bars * 4 * beat, true);
  const chords = [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]];
  const swing = beat * 0.62;
  const melody = [
    [76, -1, 77, 76, 72, -1, -1, -1],
    [74, -1, 76, 74, 71, -1, 67, -1],
    [72, -1, 74, 72, 69, -1, 72, 74],
    [71, -1, 67, -1, 64, -1, -1, -1],
  ];
  for (let bar = 0; bar < bars; bar++) {
    const t0 = bar * 4 * beat;
    const ch = chords[bar % 4]!;
    // Chords on beat 1 and the "and" of 2.
    for (const n of ch) {
      tr.note(t0, beat * 1.4, keys(hz(n)), 0.09, 0.01, 0.3);
      tr.note(t0 + beat + swing, beat * 1.2, keys(hz(n)), 0.07, 0.01, 0.3);
    }
    const walk = [ch[0]! - 12, ch[1]! - 12, ch[2]! - 12, ch[1]! - 12];
    walk.forEach((n, q) => tr.note(t0 + q * beat, beat * 0.8, pluck(hz(n), 0.35), 0.4, 0.005, 0.05));
    for (let q = 0; q < 4; q++) {
      hat(tr, t0 + q * beat, 0.06);
      hat(tr, t0 + q * beat + swing, 0.04);
      if (q === 0 || q === 2) kick(tr, t0 + q * beat, 0.35);
    }
    if (bar >= 4) {
      const ph = melody[bar % 4]!;
      ph.forEach((n, s) => { if (n > 0) tr.note(t0 + Math.floor(s / 2) * beat + (s % 2 ? swing : 0), beat * 0.5, keys(hz(n)), 0.14, 0.01, 0.2); });
    }
  }
  wav('music', 'garage', tr.b, 0.45);
}

// A button: a short wooden tick.
{
  const tr = new Track(0.08, false);
  tr.note(0, 0.04, (t) => (Math.sin(2 * Math.PI * 1800 * t) * 0.7 + rnd() * 0.4) * Math.exp(-t / 0.008), 1, 0.0005, 0.01);
  wav('ui', 'click', tr.b, 0.6);
}

// Over the line: G C E G climbing, then a held C major chord.
{
  const tr = new Track(1.8, false);
  [67, 72, 76, 79].forEach((n, i) => tr.note(i * 0.11, 0.1, vibrato(hz(n), 0.7), 0.4, 0.005, 0.04));
  for (const n of [72, 76, 79, 84]) tr.note(0.46, 0.9, vibrato(hz(n), 0.7), 0.25, 0.02, 0.35);
  kick(tr, 0.46, 0.5);
  wav('sfx', 'fanfare', tr.b, 0.75);
}

// A course unlocked: a rising sweep, then a bell.
{
  const tr = new Track(1.3, false);
  tr.note(0, 0.35, (t) => Math.sin(2 * Math.PI * (400 * t + 900 * t * t)) * 0.5, 0.5, 0.01, 0.05);
  tr.note(0.36, 0.05, (t) => (Math.sin(2 * Math.PI * hz(84) * t) + 0.5 * Math.sin(2 * Math.PI * hz(84) * 2.76 * t)) * Math.exp(-t / 0.4), 0.6, 0.002, 0.9);
  wav('sfx', 'unlock', tr.b, 0.75);
}
