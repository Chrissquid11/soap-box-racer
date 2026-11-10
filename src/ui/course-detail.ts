/**
 * A course up close, over the course select (a tap on a course's little map): its map big, the main features marked
 * along the road -- jumps, ramps, side kickers, the gravel traps and the foam, the disco tunnel, the stairs and the
 * rough patches, the shortcut over the duck pond -- with a key to them, its name, its blurb and its best time; Race
 * (when it is open) and Back.
 */
import { Container, Graphics } from 'pixi.js';
import { COLOUR, type Units } from '@vibe/engine/ui';
import { COURSES, type HazardKind, TRACKS } from '../game/courses.ts';
import { drawMap, type MapView } from './course-select.ts';
import { KARTY_COLOUR, KIT_COLOUR } from './karty-theme.ts';
import { KLabel, plate } from './kit.ts';
import { bestTime, isOpen } from './progress.ts';
import { SCREEN_M } from './screen-theme.ts';
import { SlantButton } from './slant-button.ts';

/** The features the map marks, in the key's order: which hazards each covers, its colour, its mark's shape. */
interface Feature { readonly name: string; readonly kinds: readonly HazardKind[]; readonly colour: number; readonly shape: 'tri' | 'dot' | 'bar' | 'square' }
const FEATURES: readonly Feature[] = [
  { name: 'Jump', kinds: ['jump'], colour: KIT_COLOUR.hot, shape: 'tri' },
  { name: 'Ramp', kinds: ['ramp', 'wedge'], colour: KARTY_COLOUR.gold, shape: 'tri' },
  { name: 'Side kicker', kinds: ['kicker'], colour: KIT_COLOUR.pick, shape: 'tri' },
  { name: 'Gravel trap', kinds: ['gravel'], colour: KARTY_COLOUR.bronze, shape: 'bar' },
  { name: 'Foam', kinds: ['foam'], colour: KIT_COLOUR.pickLight, shape: 'bar' },
  { name: 'Disco tunnel', kinds: ['tunnel'], colour: KARTY_COLOUR.silver, shape: 'square' },
  { name: 'Stairs', kinds: ['stairs'], colour: KIT_COLOUR.text, shape: 'square' },
  { name: 'Rough patch', kinds: ['rattler'], colour: KARTY_COLOUR.bronze, shape: 'dot' },
  { name: 'Obstacles', kinds: ['bin', 'cone', 'bale'], colour: KIT_COLOUR.dim, shape: 'dot' },
];

function clockText(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  const rest = seconds - minutes * 60;
  return `${minutes}:${rest < 10 ? '0' : ''}${rest.toFixed(2)}`;
}

/** One feature's mark at (x, y), `s` across. */
function mark(g: Graphics, f: Feature, x: number, y: number, s: number, ink: number): void {
  const edge = Math.max(1, s * 0.14);
  if (f.shape === 'tri') g.poly([x, y - s * 0.6, x + s * 0.55, y + s * 0.4, x - s * 0.55, y + s * 0.4]).fill(f.colour).stroke({ color: ink, width: edge });
  else if (f.shape === 'square') g.rect(x - s * 0.42, y - s * 0.42, s * 0.84, s * 0.84).fill(f.colour).stroke({ color: ink, width: edge });
  else if (f.shape === 'bar') g.roundRect(x - s * 0.6, y - s * 0.25, s * 1.2, s * 0.5, s * 0.2).fill(f.colour).stroke({ color: ink, width: edge });
  else g.circle(x, y, s * 0.3).fill(f.colour).stroke({ color: ink, width: edge * 0.7 });
}

export class CourseDetail {
  readonly view = new Container({ label: 'course-detail' });
  private readonly veil = new Graphics();
  private readonly panel = new Graphics();
  private readonly map = new Graphics();
  private readonly marks = new Graphics();
  private readonly keyMarks = new Graphics();
  private readonly name = new KLabel({ size: SCREEN_M.heading, caps: true, fill: KIT_COLOUR.text }, '');
  private readonly blurb = new KLabel({ size: SCREEN_M.small, fill: KIT_COLOUR.dim }, '');
  private readonly best = new KLabel({ size: SCREEN_M.body, fill: KIT_COLOUR.good }, '');
  private readonly keyWords: KLabel[] = [];
  private readonly race: SlantButton;
  private readonly back: SlantButton;
  private course = 0;
  private units: Units | null = null;

  /** `onRace`: the course picked to race (it is open). */
  constructor(onRace: (course: number) => void) {
    this.veil.eventMode = 'static';
    this.panel.eventMode = 'static';
    for (const f of FEATURES) this.keyWords.push(new KLabel({ size: SCREEN_M.small, fill: KIT_COLOUR.text }, f.name));
    this.race = new SlantButton('detail-race', 'Race', () => {
      this.hide();
      onRace(this.course);
    });
    this.back = new SlantButton('detail-back', 'Back', () => this.hide(), 'plain');
    this.view.addChild(this.veil, this.panel, this.map, this.marks, this.keyMarks, this.name, this.blurb, this.best, ...this.keyWords, this.race.view, this.back.view);
    this.view.visible = false;
  }

  /** Shown for course `c`. */
  show(c: number): void {
    this.course = c;
    const course = COURSES[c]!;
    this.name.set(`${String(c + 1).padStart(2, '0')}  ${course.name}`);
    this.blurb.set(course.blurb);
    const best = bestTime(c);
    const open = isOpen(c);
    this.best.set(!open ? 'Locked' : best == null ? 'Not raced yet' : `Best ${clockText(best)}`);
    this.best.restyle({ fill: open ? KIT_COLOUR.good : KARTY_COLOUR.warn });
    this.race.view.visible = open;
    this.view.visible = true;
    if (this.units) this.layout(this.units);
  }

  hide(): void {
    this.view.visible = false;
  }

  layout(units: Units): void {
    this.units = units;
    if (!this.view.visible) return;
    const { width, height, m } = units;
    this.veil.clear().rect(0, 0, width, height).fill(COLOUR.veil);
    const pad = SCREEN_M.platePad * m;
    const w = Math.min(SCREEN_M.select * m * 1.25, width - pad * 2);
    const x = (width - w) / 2;
    this.name.restyle({ size: SCREEN_M.heading * m * 0.8 });
    this.blurb.restyle({ size: SCREEN_M.small * m, wrap: w - pad * 2 });
    this.best.restyle({ size: SCREEN_M.body * m });
    this.race.layout(m);
    this.back.layout(m);
    // The map as big as fits: most of the height left once the words, the key and the buttons have theirs.
    const keyRow = SCREEN_M.small * m * 1.6;
    const keyCols = w > SCREEN_M.select * m ? 3 : 2;
    const course = COURSES[this.course]!;
    const shown = FEATURES.filter((f) => course.hazards.some((h) => f.kinds.includes(h.kind)));
    const keyH = Math.ceil((shown.length + (course.shortcut ? 1 : 0)) / keyCols) * keyRow;
    const words = this.name.lineBox.height + this.blurb.lineBox.height + this.best.lineBox.height + pad * 1.5;
    const buttons = this.race.height + pad;
    // The map and, beside it, the course side on (its drop, start to finish) with its features along it.
    const room = Math.max(SCREEN_M.row * m * 3, Math.min((w - pad * 2) * 0.62, height - pad * 4 - words - keyH - buttons));
    const mapH = room;
    const h = pad + words + mapH + pad * 0.6 + keyH + pad * 0.6 + buttons + pad * 0.5;
    const top = Math.max(pad * 0.5, (height - h) / 2);
    plate(this.panel.clear(), x, top, w, h, m);
    let y = top + pad;
    this.name.position.set(x + (w - this.name.lineBox.width) / 2, y);
    y += this.name.lineBox.height + pad * 0.3;
    this.blurb.position.set(x + (w - this.blurb.lineBox.width) / 2, y);
    y += this.blurb.lineBox.height + pad * 0.3;
    this.best.position.set(x + (w - this.best.lineBox.width) / 2, y);
    y += this.best.lineBox.height + pad * 0.9;
    // The map, and its features marked on it.
    const mapW = Math.min(mapH, (w - pad * 3) * 0.42);
    const view = drawMap(this.map, this.course, x + pad, y, mapW, mapH, m * 1.6);
    this.drawMarks(view, m);
    this.drawProfile(x + pad * 2 + mapW, y, w - pad * 3 - mapW, mapH, m);
    y += mapH + pad * 0.6;
    // The key: each feature this course has, its mark and its name, in columns.
    const kg = this.keyMarks.clear();
    const colW = (w - pad * 2) / keyCols;
    const s = SCREEN_M.small * m;
    let n = 0;
    for (let i = 0; i < FEATURES.length; i++) {
      const f = FEATURES[i]!;
      const label = this.keyWords[i]!;
      label.visible = shown.includes(f);
      if (!label.visible) continue;
      label.restyle({ size: SCREEN_M.small * m });
      const kx = x + pad + (n % keyCols) * colW, ky = y + Math.floor(n / keyCols) * keyRow;
      mark(kg, f, kx + s * 0.6, ky + keyRow * 0.4, s, KIT_COLOUR.ink);
      label.position.set(kx + s * 1.6, ky + keyRow * 0.4 - label.lineBox.height / 2);
      n++;
    }
    if (course.shortcut) {
      const kx = x + pad + (n % keyCols) * colW, ky = y + Math.floor(n / keyCols) * keyRow;
      kg.moveTo(kx, ky + keyRow * 0.4).lineTo(kx + s * 1.2, ky + keyRow * 0.4).stroke({ color: KIT_COLOUR.good, width: Math.max(2, s * 0.25) });
      kg.circle(kx + s * 0.6, ky + keyRow * 0.4, s * 0.28).fill(KIT_COLOUR.pickLight);
      this.shortcutWord.restyle({ size: SCREEN_M.small * m });
      this.shortcutWord.position.set(kx + s * 1.6, ky + keyRow * 0.4 - this.shortcutWord.lineBox.height / 2);
      this.shortcutWord.visible = true;
    } else this.shortcutWord.visible = false;
    y += keyH + pad * 0.6;
    // Back on the left, Race on the right.
    this.back.view.position.set(x + pad, y);
    this.race.view.position.set(x + w - pad - this.race.width, y);
  }

  private readonly shortcutWord = (() => {
    const l = new KLabel({ size: SCREEN_M.small, fill: KIT_COLOUR.text }, 'Shortcut & duck pond');
    this.view.addChild(l);
    return l;
  })();

  /**
   * The course side on, in the box (x, y, w, h): its road's height from the start line to the finish (the drop to
   * scale up and down, stretched along), the ground under it, START and FINISH at its ends, each feature's mark on
   * the road where it stands -- spread out along the way as the map, seen from above, cannot.
   */
  private drawProfile(x: number, y: number, w: number, h: number, m: number): void {
    const g = this.marks;
    const course = COURSES[this.course]!;
    const t = TRACKS[this.course]!;
    const s0 = Math.max(0, t.start), s1 = Math.min(t.samples - 1, t.finish);
    let lo = Infinity, hi = -Infinity;
    for (let i = s0; i <= s1; i++) { lo = Math.min(lo, t.sy[i]!); hi = Math.max(hi, t.sy[i]!); }
    const inset = SCREEN_M.small * m * 1.4;
    const px = (i: number): number => x + inset + ((i - s0) / Math.max(1, s1 - s0)) * (w - inset * 2);
    const py = (i: number): number => y + inset + ((hi - t.sy[i]!) / Math.max(1, hi - lo)) * (h - inset * 2.6);
    g.roundRect(x, y, w, h, SCREEN_M.rowRound * m).fill({ color: KIT_COLOUR.card, alpha: 0.9 }).stroke({ color: KIT_COLOUR.edge, width: Math.max(1, m) });
    // The ground under the road, then the road on it.
    g.moveTo(px(s0), y + h - inset * 0.5);
    for (let i = s0; i <= s1; i += 2) g.lineTo(px(i), py(i));
    g.lineTo(px(s1), py(s1)).lineTo(px(s1), y + h - inset * 0.5).closePath().fill({ color: KARTY_COLOUR.bronze, alpha: 0.35 });
    g.moveTo(px(s0), py(s0));
    for (let i = s0; i <= s1; i += 2) g.lineTo(px(i), py(i));
    g.lineTo(px(s1), py(s1)).stroke({ color: KIT_COLOUR.text, width: Math.max(2, m * 2.4), cap: 'round', join: 'round' });
    // Start and finish.
    const dot = SCREEN_M.small * m * 0.45;
    g.circle(px(s0), py(s0), dot).fill(KARTY_COLOUR.gold);
    g.circle(px(s1), py(s1), dot).fill(KIT_COLOUR.text).circle(px(s1), py(s1), dot * 0.5).fill(KIT_COLOUR.ink);
    this.startWord.restyle({ size: SCREEN_M.small * m });
    this.finishWord.restyle({ size: SCREEN_M.small * m });
    this.startWord.position.set(px(s0) - dot, py(s0) + dot * 1.4);
    this.finishWord.position.set(px(s1) - this.finishWord.lineBox.width + dot, py(s1) - dot * 1.4 - this.finishWord.lineBox.height);
    // The features on the road, standing just over it.
    const sz = SCREEN_M.small * m * 1.05;
    for (const pass of [1, 0]) {
      for (const hz of course.hazards) {
        const f = FEATURES.find((q) => q.kinds.includes(hz.kind));
        if (!f || (f.name === 'Obstacles' ? 0 : 1) === pass) continue;
        const i = Math.max(s0, Math.min(s1, hz.sample));
        mark(g, f, px(i), py(i) - sz * 0.7, f.name === 'Obstacles' ? sz * 0.7 : sz, KIT_COLOUR.ink);
      }
    }
    if (t.cut) {
      const a = Math.max(s0, t.cut.from), b = Math.min(s1, t.cut.to);
      g.moveTo(px(a), py(a) + sz * 0.6).lineTo(px(b), py(b) + sz * 0.6).stroke({ color: KIT_COLOUR.good, width: Math.max(2, m * 2) });
    }
  }

  private readonly startWord = (() => {
    const l = new KLabel({ size: SCREEN_M.small, caps: true, fill: KARTY_COLOUR.gold }, 'Start');
    this.view.addChild(l);
    return l;
  })();

  private readonly finishWord = (() => {
    const l = new KLabel({ size: SCREEN_M.small, caps: true, fill: KIT_COLOUR.text }, 'Finish');
    this.view.addChild(l);
    return l;
  })();

  /** Each feature's mark where it stands along the road; the shortcut a green line across, its pond blue. */
  private drawMarks(v: MapView, m: number): void {
    const g = this.marks.clear();
    const course = COURSES[this.course]!;
    const t = TRACKS[this.course]!;
    const s = SCREEN_M.small * m * 0.9;
    const cut = t.cut;
    if (cut) {
      const ax = v.ox + cut.ax * v.k, ay = v.oy - cut.az * v.k, bx = v.ox + cut.bx * v.k, by = v.oy - cut.bz * v.k;
      g.moveTo(ax, ay).lineTo(bx, by).stroke({ color: KIT_COLOUR.good, width: Math.max(2, s * 0.3), cap: 'round' });
      const mid = (cut.pondFrom + cut.pondTo) / 2;
      g.circle(ax + (bx - ax) * mid, ay + (by - ay) * mid, s * 0.55).fill(KIT_COLOUR.pickLight).stroke({ color: KIT_COLOUR.ink, width: Math.max(1, s * 0.1) });
    }
    // Obstacles first (small, many), the big features over them.
    for (const pass of [1, 0]) {
      for (const h of course.hazards) {
        const f = FEATURES.find((q) => q.kinds.includes(h.kind));
        if (!f || (f.name === 'Obstacles' ? 0 : 1) === pass) continue;
        const i = Math.max(0, Math.min(t.samples - 1, h.sample));
        mark(g, f, v.px(i), v.py(i), f.name === 'Obstacles' ? s * 0.7 : s, KIT_COLOUR.ink);
      }
    }
  }
}
