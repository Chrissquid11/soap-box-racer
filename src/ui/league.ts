/**
 * The league table: a course's field of rivals and the player placed among them, a slanted strip a row -- the
 * place on a chip (gold, silver, bronze for the top three), a picture of the kart, the rider, its name, the points at the
 * right and the time beside them (the points place it); the
 * player's row hot orange. Before a run (`time` left out) the player rides last, below the field; after it, in
 * the place their time earns. Shown on the results and over the countdown (`race-hud.ts`).
 *
 * Animated in (`play`, then `frame` each displayed frame): the rows slide in from the right one after another,
 * overshooting a little; after a run the player's row then climbs up from the bottom to the place it earned, the
 * rivals it passes dropping a row each as it goes by, and gives a bounce as it lands.
 */
import { Container, Graphics, Sprite } from 'pixi.js';
import { BODY, CHASSIS } from '../game/build.ts';
import { placeOf, rivalsOf, standings } from '../game/rivals.ts';
import { thumb } from './thumbs.ts';
import { KARTY_COLOUR, KIT_COLOUR, KIT_M } from './karty-theme.ts';
import { KLabel, slant } from './kit.ts';

/** Sizes in `m`: a row high, between rows, the place chip across, the words, the kart's, the room inside a row. */
const ROW = 30;
const GAP = 4;
const CHIP = 42;
/** The kart's picture, across (as high), a little taller than the row. */
const PIC = 40;
const TEXT = 17;
const SMALL = 13;
const PAD = 12;
const MEDALS = [KARTY_COLOUR.gold, KARTY_COLOUR.silver, KARTY_COLOUR.bronze] as const;
/** The animation, seconds: between one row and the next sliding in, each one's slide, how far it comes from (in
 * rows' heights), the pause before the player's row climbs, the climb (a row's worth each, at least CLIMB_MIN), and
 * the bounce as it lands (how much bigger, at most). */
const STAGGER = 0.06;
const SLIDE = 0.35;
const SLIDE_FROM = 12;
const CLIMB_WAIT = 0.25;
const CLIMB_ROW = 0.12;
const CLIMB_MIN = 0.4;
const LAND = 0.35;
const LAND_POP = 0.06;

/** Eased out, overshooting a touch: 0 to 1. */
function back(t: number): number {
  const c = 1.7, u = Math.min(1, Math.max(0, t)) - 1;
  return 1 + (c + 1) * u * u * u + c * u * u;
}

/** Eased in and out: 0 to 1. */
function smooth(t: number): number {
  const v = Math.min(1, Math.max(0, t));
  return v * v * (3 - 2 * v);
}

interface Row {
  /** The row whole (its strip, chip, picture, words): moved and faded as one by the animation. */
  view: Container;
  g: Graphics;
  place: KLabel;
  rider: KLabel;
  kart: KLabel;
  time: KLabel;
  points: KLabel;
  chip: number;
  /** The kart's look: its bodywork and chassis (`BODY`, `CHASSIS`), and its picture once drawn. */
  body: number;
  chassis: number;
  pic: Sprite;
  drawn: string;
}

/** A kart's picture: a themed body alone, else the bodywork on its chassis (none: the chassis). Null till loaded. */
function kartThumb(body: number, chassis: number) {
  const bo = BODY[body];
  if (bo && bo.natural) return thumb(bo.model);
  const ch = CHASSIS[bo && body > 0 ? bo.on ?? 1 : chassis] ?? CHASSIS[1]!;
  return bo && body > 0 ? thumb(ch.model, { key: bo.model, y: ch.size[1] / 2, z: bo.z }) : thumb(ch.model);
}

/** 0:21.80 */
export function lapText(seconds: number): string {
  const s = Math.max(0, seconds);
  const minutes = Math.floor(s / 60);
  const rest = s - minutes * 60;
  return `${minutes}:${rest < 10 ? '0' : ''}${rest.toFixed(2)}`;
}

export class League {
  readonly view = new Container({ label: 'league' });
  private readonly rows: Row[] = [];
  /** The player's row. */
  private you = -1;
  /** Seconds into the animation (past its end: still), whether the player's row climbs, a row's height and gap. */
  private t = 99;
  private climb = false;
  private step = 0;
  private x = 0;
  private w = 0;
  private rowH = 0;

  constructor() {
    for (let i = 0; i <= rivalsOf(0).length; i++) {
      const row: Row = {
        view: new Container({ label: `league-row-${i}` }),
        g: new Graphics(),
        place: new KLabel({ size: TEXT, fill: KIT_COLOUR.text }, ''),
        rider: new KLabel({ size: TEXT, caps: true, fill: KIT_COLOUR.text }, ''),
        kart: new KLabel({ size: SMALL, fill: KIT_COLOUR.dim }, ''),
        time: new KLabel({ size: SMALL, fill: KIT_COLOUR.dim }, ''),
        points: new KLabel({ size: TEXT, fill: KIT_COLOUR.text }, ''),
        chip: KIT_COLOUR.edgeDim,
        body: 0,
        chassis: 1,
        pic: new Sprite(),
        drawn: '',
      };
      row.pic.visible = false;
      this.rows.push(row);
      row.view.addChild(row.g, row.pic, row.place, row.rider, row.kart, row.time, row.points);
      this.view.addChild(row.view);
    }
  }

  /** Start the animation over: the rows sliding in, and (`climb`, after a run) the player's row climbing to its place. */
  play(climb: boolean): void {
    this.t = 0;
    this.climb = climb && this.you < this.rows.length - 1;
    this.frame(0);
  }

  /** The animation's last second (seconds): when it is all in place. */
  private get length(): number {
    const slid = (this.rows.length - 1) * STAGGER + SLIDE;
    return this.climb ? slid + CLIMB_WAIT + this.climbFor + LAND : slid;
  }

  private get climbFor(): number {
    return Math.max(CLIMB_MIN, (this.rows.length - 1 - this.you) * CLIMB_ROW);
  }

  /** A displayed frame: `dt` real seconds on. */
  frame(dt: number): void {
    if (this.t > this.length + 1) return;
    this.t += dt;
    const n = this.rows.length, last = n - 1;
    const slid = last * STAGGER + SLIDE;
    // Where the player's row is, in rows: from the bottom up to its place.
    const c = this.climb ? smooth((this.t - slid - CLIMB_WAIT) / this.climbFor) : 1;
    const at = last + (this.you - last) * c;
    for (let i = 0; i < n; i++) {
      const row = this.rows[i]!;
      // Each in from the right, in turn (the player's last of all, from the bottom row, when it climbs).
      const order = this.climb ? (i === this.you ? last : i < this.you ? i : i - 1) : i;
      const k = (this.t - order * STAGGER) / SLIDE;
      const dx = (1 - back(k)) * SLIDE_FROM * this.rowH;
      row.view.alpha = Math.min(1, Math.max(0, k * 2));
      let dy = 0;
      if (this.climb) {
        // The player's row where it has got to; a rival below its place a row up till it has been passed.
        if (i === this.you) dy = (at - this.you) * this.step;
        else if (i > this.you) dy = -(1 - Math.min(1, Math.max(0, i - at))) * this.step;
      }
      row.view.position.set(dx, dy);
      // Landed: a bounce.
      let s = 1;
      if (this.climb && i === this.you) {
        const l = (this.t - slid - CLIMB_WAIT - this.climbFor) / LAND;
        if (l > 0 && l < 1) s = 1 + Math.sin(l * Math.PI) * LAND_POP;
      }
      row.view.scale.set(s);
      if (s !== 1) {
        // Grown about its middle.
        const cx = this.x + this.w / 2, cy = this.rowTop(i) + this.rowH / 2;
        row.view.position.set(dx - cx * (s - 1), dy - cy * (s - 1));
      }
    }
  }

  private top = 0;

  private rowTop(i: number): number {
    return this.top + i * this.step;
  }

  /** The field on `course` in `weather`, and the player in `kart` (built of `body` on `chassis`): their run's `points`
   * and `time` (null, no finish) -- left out before it. */
  fill(course: number, weather: number, kart: string, body: number, chassis: number, points?: number, time: number | null = null): void {
    const before = points === undefined;
    // The rivals' points as the player's time places among theirs (before it, as they stood).
    const rivals = standings(course, weather, before ? undefined : time).field;
    this.you = before ? this.rows.length - 1 : placeOf(course, points, weather, time) - 1;
    let r = 0;
    for (let i = 0; i < this.rows.length; i++) {
      const row = this.rows[i]!;
      const you = i === this.you;
      if (you) {
        row.rider.set('You');
        row.kart.set(kart);
        row.body = body;
        row.chassis = chassis;
        row.points.set(before ? 'Next' : `${points} pts`);
        row.time.set(before ? '' : time === null ? 'DNF' : lapText(time));
      } else {
        const rival = rivals[r++];
        row.rider.set(rival?.rider ?? '');
        row.kart.set(rival?.kart ?? '');
        row.body = rival?.body ?? 0;
        row.chassis = 1;
        row.points.set(rival ? `${rival.points} pts` : '');
        row.time.set(!rival || rival.time === null ? 'DNF' : lapText(rival.time));
      }
      const medal = i < 3 && !(before && you);
      row.chip = medal ? MEDALS[i]! : you ? KIT_COLOUR.edge : KIT_COLOUR.edgeDim;
      row.place.set(before && you ? '–' : String(i + 1));
      row.place.restyle({ fill: medal ? KIT_COLOUR.ink : KIT_COLOUR.text });
      const ink = you ? KIT_COLOUR.ink : KIT_COLOUR.text;
      row.rider.restyle({ fill: ink });
      row.points.restyle({ fill: ink });
      row.time.restyle({ fill: you ? KIT_COLOUR.ink : KIT_COLOUR.dim });
      row.kart.restyle({ fill: you ? KIT_COLOUR.ink : KIT_COLOUR.dim });
    }
    this.retry();
  }

  /** Each row's kart picture, where it can be had now (a model still loading: tried again next frame). */
  retry(): void {
    for (const row of this.rows) {
      const want = `${row.body}:${row.chassis}`;
      if (row.drawn === want) continue;
      const texture = kartThumb(row.body, row.chassis);
      if (!texture) continue;
      row.pic.texture = texture;
      row.pic.visible = true;
      row.drawn = want;
    }
  }

  /** How high it is at the unit `m`. */
  height(m: number): number {
    return this.rows.length * ROW * m + (this.rows.length - 1) * GAP * m;
  }

  /** Laid out at (x, y), `w` across, at the unit `m`: answers its height. */
  place(x: number, y: number, w: number, m: number): number {
    const h = ROW * m, gap = GAP * m, chip = CHIP * m, pad = PAD * m;
    this.x = x;
    this.w = w;
    this.top = y;
    this.rowH = h;
    this.step = h + gap;
    const lean = (h * KIT_M.lean) / 2;
    const mid = (l: KLabel, top: number): number => top + (h - l.lineBox.height) / 2;
    for (let i = 0; i < this.rows.length; i++) {
      const row = this.rows[i]!;
      const you = i === this.you;
      const ry = y + i * (h + gap);
      const g = row.g.clear();
      slant(g, x, ry, w, h, you ? KIT_COLOUR.pick : i % 2 === 0 ? KIT_COLOUR.card : KIT_COLOUR.cardHover, KIT_COLOUR.edge, Math.max(1, m));
      slant(g, x, ry, chip, h, row.chip);
      row.place.restyle({ size: TEXT * m });
      row.rider.restyle({ size: TEXT * m });
      row.kart.restyle({ size: SMALL * m });
      row.time.restyle({ size: SMALL * m });
      row.points.restyle({ size: TEXT * m });
      row.place.position.set(x + (chip - row.place.lineBox.width) / 2, mid(row.place, ry));
      const pic = PIC * m;
      row.pic.width = pic;
      row.pic.height = pic;
      row.pic.position.set(x + chip + pad * 0.5, ry + (h - pic) / 2);
      const rx = x + chip + pad * 0.5 + pic + pad * 0.5;
      row.rider.position.set(rx, mid(row.rider, ry));
      // The points at the right, the time before them.
      const px = x + w - lean - pad - row.points.lineBox.width;
      row.points.position.set(px, mid(row.points, ry));
      const tx = px - pad * 0.8 - row.time.lineBox.width;
      row.time.position.set(tx, mid(row.time, ry) + m);
      const kx = rx + row.rider.lineBox.width + pad * 0.8;
      row.kart.position.set(kx, mid(row.kart, ry) + m);
      // The kart's name only where it fits before the time.
      row.kart.visible = kx + row.kart.lineBox.width < tx - pad;
    }
    this.frame(0);
    return this.height(m);
  }
}
