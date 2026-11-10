/**
 * The game's look, shared by every screen: its face (Barlow Condensed ExtraBold Italic, `src/assets/fonts/`,
 * loaded once by `loadKartyFont`), `KLabel` -- a `Label` in that face -- and the shapes everything is drawn from:
 * a cream sticker plate with a navy outline, a rounded box, a chequered flag, a divider, and the small glyphs the garage's
 * tabs and cards wear (a chassis, a wheel, a spring ...). Colours and sizes from `karty-theme.ts`' `KIT_*`.
 */
import { CanvasTextMetrics, type Graphics } from 'pixi.js';
import { Assets, Audio } from '@vibe/engine/assets';
import { Label, type Look } from '@vibe/engine/ui';
import { KIT_ALPHA, KIT_COLOUR, KIT_M } from './karty-theme.ts';

const FAMILY = 'Barlow Condensed';
const FACE = [FAMILY, 'Arial Narrow', 'Trebuchet MS', 'sans-serif'];

/** Every label in the face: told again once the face has loaded, so none keeps the fallback's measure. */
const faced = new Set<KLabel>();

/** A label in the game's face: chunky, condensed, leaning. Otherwise a `Label` (its look, `set`, `restyle`, `lineBox`). */
export class KLabel extends Label {
  constructor(look: Look, words = '') {
    super(look, words);
    this.face();
    faced.add(this);
  }

  override restyle(changes: Partial<Look>): this {
    const before = this.style;
    super.restyle(changes);
    if (this.style !== before) this.face();
    return this;
  }

  /** The face put on the style (a restyle makes a new one). */
  face(): void {
    this.style.fontFamily = FACE;
    this.style.fontStyle = 'italic';
    this.style.fontWeight = '800';
    this.style.update();
  }
}

let loading: Promise<void> | null = null;

/** The face loaded (once), then every label made before it drawn again in it. A face that fails leaves the fallback. */
export function loadKartyFont(): Promise<void> {
  loading ??= (async () => {
    try {
      const face = new FontFace(FAMILY, `url(${Assets.fontUrl('barlow-condensed-800i')})`, { style: 'italic', weight: '800' });
      document.fonts.add(face);
      await face.load();
    } catch (err) {
      console.warn('[ui] the game face did not load; the fallback stands in', err);
    }
    CanvasTextMetrics.clearMetrics();
  })();
  return loading;
}

/** After the face loads: every label in it drawn again (call on the Pixi side, then lay the widgets out again). */
export function refaceAll(): void {
  for (const label of faced) label.face();
}

// ── shapes ───────────────────────────────────────────────────────────────

/** A plate: a sticker -- rounded, filled (cream), a thick navy outline `m` scaled, a drop shadow down and right. */
export function plate(g: Graphics, x: number, y: number, w: number, h: number, m: number, fill: number = KIT_COLOUR.plate, edge: number = KIT_COLOUR.edge, alpha: number = KIT_ALPHA.plate): Graphics {
  const r = Math.min(KIT_M.plateRound * m, h / 2, w / 2);
  const t = Math.max(1, KIT_M.edge * m);
  const d = t * KIT_M.drop;
  g.roundRect(x + d, y + d, w, h, r).fill({ color: KIT_COLOUR.shadow, alpha: alpha * KIT_M.dropAlpha });
  return g.roundRect(x, y, w, h, r).fill({ color: fill, alpha }).roundRect(x, y, w, h, r).stroke({ color: edge, width: t });
}

/**
 * A box: in the arcade look a rounded pill (its corners a third of its height), filled; edged if asked -- then a
 * sticker, its outline half as thick again as asked and a drop shadow down and right under it. (Named for the slanted
 * boxes it drew before: every screen draws its plates, tags and buttons with it.)
 */
export function slant(g: Graphics, x: number, y: number, w: number, h: number, fill: number, edge?: number, width = 0): Graphics {
  const r = Math.max(0, Math.min(h * 0.34, w / 2));
  if (edge !== undefined && width > 0) {
    const t = width * 1.5;
    const d = t * KIT_M.drop;
    g.roundRect(x + d, y + d, w, h, r).fill({ color: KIT_COLOUR.shadow, alpha: KIT_M.dropAlpha });
    g.roundRect(x, y, w, h, r).fill(fill);
    g.roundRect(x, y, w, h, r).stroke({ color: edge, width: t });
    return g;
  }
  return g.roundRect(x, y, w, h, r).fill(fill);
}

/** A chequered flag, `cols` by `rows` squares of `cell`, leaning as the words do; its light squares `light`. */
export function flag(g: Graphics, x: number, y: number, cell: number, cols: number, rows: number, light: number, dark: number = KIT_COLOUR.flagDark): Graphics {
  const k = KIT_M.lean;
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const top = y + r * cell;
      const shift = (rows - r) * cell * k;
      const left = x + c * cell + shift;
      g.poly([left, top, left + cell, top, left + cell - cell * k, top + cell, left - cell * k, top + cell]).fill((r + c) % 2 === 0 ? light : dark);
    }
  }
  return g;
}

/** A thin upright divider. */
export function divider(g: Graphics, x: number, y: number, h: number, m: number, colour: number = KIT_COLOUR.edgeDim): Graphics {
  return g.rect(x, y, Math.max(1, KIT_M.edge * m), h).fill(colour);
}

/** A meter: its groove, and `share` of it filled. */
export function meter(g: Graphics, x: number, y: number, w: number, h: number, share: number, fill: number, groove: number = KIT_COLOUR.groove): Graphics {
  g.roundRect(x, y, w, h, h / 2).fill(groove);
  const s = Math.max(0, Math.min(1, share));
  if (s > 0) g.roundRect(x, y, Math.max(h, w * s), h, h / 2).fill(fill);
  return g;
}

// ── glyphs ───────────────────────────────────────────────────────────────

/** The glyphs: each drawn in a box `s` across with its top left at (x, y), strokes `s` / 12 thick. */
export type Glyph = 'chassis' | 'wheels' | 'suspension' | 'steering' | 'brakes' | 'body' | 'seat' | 'paint' | 'sizes' | 'none' | 'chute' | 'shoe' | 'lever' | 'person' | 'gold' | 'warn' | 'weight';

export function glyph(g: Graphics, kind: Glyph, x: number, y: number, s: number, colour: number = KIT_COLOUR.glyph): Graphics {
  const w = Math.max(1, s / 12);
  const line = { color: colour, width: w, cap: 'round' as const, join: 'round' as const };
  const cx = x + s / 2, cy = y + s / 2;
  switch (kind) {
    case 'chassis': {
      // A frame in perspective: two rails, crossbars, axle stubs.
      g.poly([x + s * 0.12, y + s * 0.62, x + s * 0.56, y + s * 0.82, x + s * 0.9, y + s * 0.5, x + s * 0.46, y + s * 0.32], true).stroke(line);
      g.moveTo(x + s * 0.29, y + s * 0.7).lineTo(x + s * 0.68, y + s * 0.41).stroke(line);
      for (const [px, py] of [[0.12, 0.62], [0.56, 0.82], [0.9, 0.5], [0.46, 0.32]] as const) g.circle(x + s * px, y + s * py, s * 0.06).fill(colour);
      break;
    }
    case 'wheels': {
      g.circle(cx, cy, s * 0.42).stroke(line).circle(cx, cy, s * 0.24).stroke(line).circle(cx, cy, s * 0.07).fill(colour);
      for (let i = 0; i < 6; i++) {
        const a = (i / 6) * Math.PI * 2;
        g.moveTo(cx + Math.cos(a) * s * 0.08, cy + Math.sin(a) * s * 0.08).lineTo(cx + Math.cos(a) * s * 0.24, cy + Math.sin(a) * s * 0.24).stroke(line);
      }
      break;
    }
    case 'suspension': {
      // A coil, leaning.
      g.moveTo(x + s * 0.3, y + s * 0.12);
      for (let i = 0; i < 6; i++) {
        const t = y + s * (0.18 + i * 0.12);
        g.lineTo(x + s * (i % 2 === 0 ? 0.74 : 0.26), t + s * 0.06);
      }
      g.lineTo(x + s * 0.7, y + s * 0.9).stroke(line);
      break;
    }
    case 'steering': {
      g.circle(cx, cy, s * 0.4).stroke(line).circle(cx, cy, s * 0.1).stroke(line);
      g.moveTo(cx - s * 0.1, cy).lineTo(cx - s * 0.4, cy).stroke(line);
      g.moveTo(cx + s * 0.1, cy).lineTo(cx + s * 0.4, cy).stroke(line);
      g.moveTo(cx, cy + s * 0.1).lineTo(cx, cy + s * 0.4).stroke(line);
      break;
    }
    case 'brakes': {
      g.circle(cx, cy, s * 0.4).stroke(line).circle(cx, cy, s * 0.12).stroke(line);
      for (let i = 0; i < 8; i++) {
        const a = (i / 8) * Math.PI * 2;
        g.circle(cx + Math.cos(a) * s * 0.27, cy + Math.sin(a) * s * 0.27, s * 0.03).fill(colour);
      }
      // The calliper, over its rim.
      g.moveTo(cx + Math.cos(-Math.PI * 0.85) * s * 0.4, cy + Math.sin(-Math.PI * 0.85) * s * 0.4).arc(cx, cy, s * 0.4, -Math.PI * 0.85, -Math.PI * 0.45).stroke({ ...line, width: w * 3 });
      break;
    }
    case 'body': {
      // A shell on its side: a can, say.
      g.roundRect(x + s * 0.12, y + s * 0.3, s * 0.7, s * 0.4, s * 0.2).stroke(line);
      g.ellipse(x + s * 0.76, cy, s * 0.1, s * 0.2).stroke(line);
      g.moveTo(x + s * 0.3, y + s * 0.3).lineTo(x + s * 0.5, y + s * 0.7).stroke(line);
      break;
    }
    case 'seat': {
      g.poly([x + s * 0.3, y + s * 0.12, x + s * 0.44, y + s * 0.12, x + s * 0.5, y + s * 0.6, x + s * 0.84, y + s * 0.6, x + s * 0.84, y + s * 0.74, x + s * 0.36, y + s * 0.74], true).stroke(line);
      g.moveTo(x + s * 0.44, y + s * 0.74).lineTo(x + s * 0.38, y + s * 0.9).stroke(line);
      g.moveTo(x + s * 0.76, y + s * 0.74).lineTo(x + s * 0.82, y + s * 0.9).stroke(line);
      break;
    }
    case 'paint': {
      // A pot, a drip, a brush across it.
      g.roundRect(x + s * 0.2, y + s * 0.38, s * 0.5, s * 0.48, s * 0.06).stroke(line);
      g.moveTo(x + s * 0.2, y + s * 0.5).lineTo(x + s * 0.7, y + s * 0.5).stroke(line);
      g.moveTo(x + s * 0.5, y + s * 0.42).lineTo(x + s * 0.86, y + s * 0.1).stroke({ ...line, width: w * 1.6 });
      g.circle(x + s * 0.3, y + s * 0.6, s * 0.05).fill(colour);
      break;
    }
    case 'sizes': {
      g.moveTo(x + s * 0.15, y + s * 0.85).lineTo(x + s * 0.85, y + s * 0.15).stroke(line);
      g.moveTo(x + s * 0.55, y + s * 0.15).lineTo(x + s * 0.85, y + s * 0.15).lineTo(x + s * 0.85, y + s * 0.45).stroke(line);
      g.moveTo(x + s * 0.15, y + s * 0.55).lineTo(x + s * 0.15, y + s * 0.85).lineTo(x + s * 0.45, y + s * 0.85).stroke(line);
      break;
    }
    case 'none': {
      g.circle(cx, cy, s * 0.36).stroke(line);
      g.moveTo(cx - s * 0.25, cy + s * 0.25).lineTo(cx + s * 0.25, cy - s * 0.25).stroke(line);
      break;
    }
    case 'chute': {
      g.moveTo(cx - s * 0.38, y + s * 0.46).arc(cx, y + s * 0.46, s * 0.38, Math.PI, 0).stroke(line);
      g.moveTo(cx - s * 0.38, y + s * 0.46).lineTo(cx + s * 0.38, y + s * 0.46).stroke(line);
      for (const k of [-0.38, -0.13, 0.13, 0.38]) g.moveTo(cx + k * s, y + s * 0.46).lineTo(cx, y + s * 0.86).stroke(line);
      break;
    }
    case 'shoe': {
      g.poly([x + s * 0.14, y + s * 0.3, x + s * 0.38, y + s * 0.3, x + s * 0.48, y + s * 0.5, x + s * 0.82, y + s * 0.58, x + s * 0.88, y + s * 0.72, x + s * 0.14, y + s * 0.72], true).stroke(line);
      g.moveTo(x + s * 0.14, y + s * 0.82).lineTo(x + s * 0.88, y + s * 0.82).stroke(line);
      break;
    }
    case 'lever': {
      g.circle(x + s * 0.38, y + s * 0.66, s * 0.22).stroke(line);
      g.moveTo(x + s * 0.5, y + s * 0.46).lineTo(x + s * 0.82, y + s * 0.12).stroke({ ...line, width: w * 1.6 });
      g.circle(x + s * 0.82, y + s * 0.12, s * 0.06).fill(colour);
      break;
    }
    case 'person': {
      g.circle(cx, y + s * 0.3, s * 0.18).fill(colour);
      g.roundRect(x + s * 0.2, y + s * 0.54, s * 0.6, s * 0.4, s * 0.2).fill(colour);
      break;
    }
    case 'weight': {
      // A kettlebell: a round-shouldered weight, its handle a ring over it.
      g.moveTo(x + s * 0.34, y + s * 0.36).arc(cx, y + s * 0.3, s * 0.2, Math.PI * 0.85, Math.PI * 0.15).stroke({ ...line, width: w * 2.2 });
      g.poly([x + s * 0.22, y + s * 0.42, x + s * 0.78, y + s * 0.42, x + s * 0.92, y + s * 0.9, x + s * 0.08, y + s * 0.9]).fill(colour);
      break;
    }
    case 'gold': {
      // A medal: a ribbon in a V from the top (red and blue), a round disc in the medal's colour hanging from it, a
      // darker ring round its face and a star in the middle.
      const r = s * 0.27, my = y + s * 0.64;
      g.poly([x + s * 0.24, y + s * 0.04, x + s * 0.44, y + s * 0.04, x + s * 0.56, y + s * 0.42, x + s * 0.4, y + s * 0.46]).fill(KIT_COLOUR.hot);
      g.poly([x + s * 0.76, y + s * 0.04, x + s * 0.56, y + s * 0.04, x + s * 0.44, y + s * 0.42, x + s * 0.6, y + s * 0.46]).fill(KIT_COLOUR.pick);
      g.circle(cx, my, r).fill(colour).circle(cx, my, r).stroke({ color: KIT_COLOUR.shadow, width: w * 1.2 });
      g.circle(cx, my, r * 0.72).stroke({ color: KIT_COLOUR.shadow, width: w * 0.7, alpha: 0.35 });
      const star: number[] = [];
      for (let i = 0; i < 10; i++) {
        const a = -Math.PI / 2 + (i * Math.PI) / 5;
        const k = i % 2 === 0 ? r * 0.5 : r * 0.22;
        star.push(cx + Math.cos(a) * k, my + Math.sin(a) * k);
      }
      g.poly(star).fill({ color: KIT_COLOUR.shadow, alpha: 0.35 });
      break;
    }
    case 'warn': {
      g.poly([cx, y + s * 0.08, x + s * 0.94, y + s * 0.88, x + s * 0.06, y + s * 0.88], true).fill(colour);
      g.roundRect(cx - s * 0.045, y + s * 0.34, s * 0.09, s * 0.3, s * 0.04).fill(KIT_COLOUR.shadow);
      g.circle(cx, y + s * 0.75, s * 0.055).fill(KIT_COLOUR.shadow);
      break;
    }
  }
  return g;
}

/** A button's press with its click: every button of the game's UI is pressed through this. */
export function clicked(onPress: () => void): () => void {
  return () => {
    Audio.ui('click', { volume: 0.6, rate: 1 });
    onPress();
  };
}
