/**
 * The course select: after a run, the ten courses and how far through them the player is -- each its name, its best
 * time and the medal that time earned -- the next one to try lit; a press on one races it at once in the kart as it
 * is built, and Garage goes to the builder first. Shown by the race HUD once its results are put away (Continue).
 *
 * In the garage's look: a navy plate with a pale edge, its heading behind a chequered flag over an orange
 * underline, each course a card (its number in orange, a laurel in its medal's colour), the one to try next edged
 * in orange with a slanted marker.
 */
import { Container, Graphics, Rectangle } from 'pixi.js';
import { COLOUR, Pressable, SIZE_U, type ButtonState, type Units, type Widget } from '@vibe/engine/ui';
import { COURSES, difficultyOf, DIFFICULTIES, TRACKS } from '../game/courses.ts';
import { DIFFICULTY_COLOURS, KARTY_COLOUR, KARTY_M, KIT_COLOUR, KIT_M } from './karty-theme.ts';
import { glyph, KLabel, plate, slant, clicked } from './kit.ts';
import { Order, orderRace, screen, setCourse } from './live.ts';
import { bestMedal, bestTime, isOpen, openCount, resetAll, unlockAll } from './progress.ts';
import { headingWidth, placeHeading } from './screen-kit.ts';
import { SCREEN_ALPHA, SCREEN_M, SCREEN_U } from './screen-theme.ts';
import { SlantButton, touchFloor } from './slant-button.ts';
import { CourseDetail } from './course-detail.ts';
import { ScrollBox } from './scroll-box.ts';

/** Courses a column: the ten valley runs, and the ten mountain ones beside them. */
const COLUMN = 10;

const MEDAL_COLOURS = [KARTY_COLOUR.gold, KARTY_COLOUR.silver, KARTY_COLOUR.bronze, KARTY_COLOUR.none] as const;

function clockText(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  const rest = seconds - minutes * 60;
  return `${minutes}:${rest < 10 ? '0' : ''}${rest.toFixed(2)}`;
}

/** One course's row: pressed, it is raced. */
/** A row's best time (or Locked), this times the small words. */
const BEST_SCALE = 1.5;

class CourseRow {
  readonly view = new Container();
  private readonly plate = new Graphics();
  private readonly laurel = new Graphics();
  /** Its little map: the course seen from above, its road on its own grass, the start and finish marked. */
  private readonly map = new Graphics();
  private readonly num: KLabel;
  private readonly name: KLabel;
  private readonly best: KLabel;
  /** How hard it is (`DIFFICULTIES`), in its colour, after the name. */
  private readonly rating: KLabel;
  private width = 0;
  private height = 0;
  private m = 1;
  private lit = false;
  private medal: number | null = null;
  readonly press: Pressable;
  readonly course: number;

  constructor(course: number, onPress: () => void) {
    this.course = course;
    this.num = new KLabel({ size: SCREEN_M.body, fill: KIT_COLOUR.text }, String(course + 1).padStart(2, '0'));
    this.name = new KLabel({ size: SCREEN_M.body, caps: true, fill: KIT_COLOUR.text }, COURSES[course]!.name);
    this.best = new KLabel({ size: SCREEN_M.small, fill: KIT_COLOUR.dim }, '');
    const level = difficultyOf(course);
    this.rating = new KLabel({ size: SCREEN_M.small, caps: true, fill: DIFFICULTY_COLOURS[level] }, DIFFICULTIES[level]);
    this.view.addChild(this.plate, this.map, this.laurel, this.num, this.name, this.rating, this.best);
    this.press = new Pressable(this.view, { id: `course-${course}`, onPress: clicked(onPress), onState: (state) => this.draw(state) });
  }

  /** Its best and medal as they stand, and whether it is the one to try next. */
  set(lit: boolean): void {
    this.lit = lit;
    this.medal = bestMedal(this.course);
    const best = bestTime(this.course);
    const open = isOpen(this.course);
    this.view.alpha = open ? 1 : LOCKED_ALPHA;
    this.best.set(!open ? 'Locked' : best == null ? '' : clockText(best));
    this.best.restyle({ fill: this.medal == null ? KIT_COLOUR.dim : MEDAL_COLOURS[this.medal] });
    this.draw(this.press.states);
  }

  /** Laid out `width` across and `height` high (at least a row; a finger's on a phone). */
  layout(m: number, width: number, height: number): void {
    this.m = m;
    this.width = width;
    this.height = height;
    this.num.restyle({ size: SCREEN_M.body * m });
    this.name.restyle({ size: SCREEN_M.body * m });
    this.best.restyle({ size: SCREEN_M.small * m * BEST_SCALE });
    this.rating.restyle({ size: SCREEN_M.small * m });
    const pad = KIT_M.space * m;
    const mark = SCREEN_M.rowMark * m;
    this.num.position.set(mark + pad, (this.height - this.num.lineBox.height) / 2);
    const mapH = Math.min(this.height, SCREEN_M.row * m) * 0.8;
    const mapW = SCREEN_M.rowMap * m;
    drawMap(this.map, this.course, mark + pad + SCREEN_M.rowNum * m, (this.height - mapH) / 2, mapW, mapH, m);
    const laurel = SCREEN_M.rowLaurel * m;
    const bestX = width - pad - laurel - pad * 0.5 - this.best.lineBox.width;
    this.best.position.set(bestX, (this.height - this.best.lineBox.height) / 2);
    // The name in what is left between the map and its time (or the laurel): cut short with '…' rather than run under them.
    const nameX = mark + pad + SCREEN_M.rowNum * m + mapW + pad;
    // The name, then its rating: the name cut short first, the rating left out where even that leaves no room.
    const end = (this.best.text ? bestX : width - pad - laurel) - pad;
    const ratingW = this.rating.lineBox.width + pad;
    const rated = end - nameX - ratingW > SCREEN_M.rowNum * m * 2;
    this.rating.visible = rated;
    ellipsize(this.name, COURSES[this.course]!.name, end - nameX - (rated ? ratingW : 0));
    this.name.position.set(nameX, (this.height - this.name.lineBox.height) / 2);
    this.rating.position.set(nameX + this.name.lineBox.width + pad, this.name.y + this.name.lineBox.height - this.rating.lineBox.height);
    this.draw(this.press.states);
  }

  private draw(state: Readonly<ButtonState>): void {
    const m = this.m;
    const w = this.width;
    const h = this.height;
    const r = SCREEN_M.rowRound * m;
    const g = this.plate.clear();
    g.roundRect(0, 0, w, h, r).fill(state.hover ? KIT_COLOUR.cardHover : KIT_COLOUR.card);
    g.roundRect(0, 0, w, h, r).stroke({ color: this.lit || state.hover ? KIT_COLOUR.pick : this.medal != null ? MEDAL_COLOURS[this.medal] : KIT_COLOUR.edge, width: Math.max(1, (this.lit ? SCREEN_M.rowLit * 1.4 : KIT_M.edge * 0.8) * m) });
    // The one to try next: a blue marker at its left.
    if (this.lit) slant(g, r * 0.5, h * 0.2, SCREEN_M.rowMark * m, h * 0.6, KIT_COLOUR.pick);
    const laurel = SCREEN_M.rowLaurel * m;
    this.laurel.clear();
    glyph(this.laurel, 'gold', w - KIT_M.space * m - laurel, (h - laurel) / 2, laurel, this.medal == null ? KIT_COLOUR.groove : MEDAL_COLOURS[this.medal]);
    this.view.alpha = (state.down ? SCREEN_ALPHA.held : 1) * (isOpen(this.course) ? 1 : LOCKED_ALPHA);
  }
}

export class CourseSelect implements Widget {
  readonly id = 'course-select';
  readonly view = new Container({ label: 'course-select' });

  private readonly veil = new Graphics();
  private readonly panel = new Graphics();
  private readonly deco = new Graphics();
  private readonly title = new KLabel({ size: SCREEN_M.heading, caps: true, fill: KIT_COLOUR.text, shadow: 'soft' }, 'Choose a course');
  private readonly progress = new KLabel({ size: SCREEN_M.body, fill: KIT_COLOUR.good }, '');
  /** ... and after it the golds won, in gold. */
  private readonly golds = new KLabel({ size: SCREEN_M.body, fill: KARTY_COLOUR.gold }, '');
  private readonly rows: CourseRow[] = [];
  private readonly garage: SlantButton;
  /** A page of COLUMN courses at a time, and the buttons to turn it. */
  private page = 0;
  private readonly prev: SlantButton;
  private readonly next: SlantButton;
  /** Opens every course, and every part with them. */
  private readonly unlock: SlantButton;
  /** Locks every course but the first and forgets every best: a new game -- pressed twice (it asks first). */
  private readonly lock: SlantButton;
  /** When the lock was pressed once (asking), or -1; a second press within LOCK_ASK seconds resets. */
  private lockAsked = -1;
  /** The course lit as the one to try next. */
  private lit = 0;
  private units: Units | null = null;
  /** A tap on a course's little map: its bigger map, its features marked (`course-detail.ts`). */
  private readonly mapHits: Container[] = [];
  /** The page's rows, scrolling when they run past the frame (a phone). */
  private readonly list = new ScrollBox('y');
  private readonly detail: CourseDetail;

  constructor() {
    this.veil.eventMode = 'static';
    this.panel.eventMode = 'static';
    this.view.addChild(this.veil, this.panel, this.deco, this.title, this.progress, this.golds, this.list.view);
    for (let c = 0; c < COURSES.length; c++) {
      const row = new CourseRow(c, () => {
        // A locked course only shows it is locked: nothing to race yet.
        if (!isOpen(c)) return;
        // Picked: on to the garage, to build the kart for it (off the course at the line, if a run had ended).
        setCourse(c);
        orderRace(Order.garage);
        screen.now = 'garage';
      });
      this.rows.push(row);
      this.list.content.addChild(row.view);
    }
    this.garage = new SlantButton('select-garage', 'Garage', () => {
      orderRace(Order.garage);
      screen.now = 'garage';
    }, 'plain');
    this.prev = new SlantButton('select-prev', '‹', () => this.turn(-1), 'plain');
    this.next = new SlantButton('select-next', '›', () => this.turn(1), 'plain');
    this.unlock = new SlantButton('select-unlock', 'Unlock all', () => {
      unlockAll();
      this.refresh();
    }, 'plain');
    this.lock = new SlantButton('select-lock', 'Lock all', () => {
      const now = performance.now() / 1000;
      if (this.lockAsked >= 0 && now - this.lockAsked < LOCK_ASK) {
        this.lockAsked = -1;
        this.lock.set('Lock all');
        resetAll();
        // Back to the first course, the only one open now: never left on a locked one.
        setCourse(0);
        orderRace(Order.garage);
        this.lit = 0;
        this.page = 0;
        this.refresh();
        return;
      }
      this.lockAsked = now;
      this.lock.set('Sure? Tap again');
      if (this.units) this.layout(this.units);
    }, 'plain');
    this.view.addChild(this.garage.view, this.prev.view, this.next.view, this.unlock.view, this.lock.view);
    // Over each row's map, its own button: the course's detail, not a race.
    for (let c = 0; c < COURSES.length; c++) {
      const hit = new Container({ label: `course-map-${c}` });
      new Pressable(hit, { id: `course-map-${c}`, onPress: clicked(() => this.detail.show(c)), onState: () => {} });
      this.mapHits.push(hit);
      this.list.content.addChild(hit);
    }
    this.detail = new CourseDetail((c) => {
      setCourse(c);
      orderRace(Order.garage);
      screen.now = 'garage';
    });
    this.view.addChild(this.detail.view);
    this.view.visible = false;
  }

  /** Shown or not; shown, its progress read afresh, `next` (the course to try next) lit. */
  setVisible(on: boolean, next: number): void {
    if (on && !this.view.visible) {
      // A course still locked (a fresh save, the kart left set to a later course) is never the one lit: the furthest
      // course open instead -- on its page.
      this.lit = isOpen(next) ? next : Math.max(0, Math.min(COURSES.length, openCount()) - 1);
      this.page = Math.floor(this.lit / COLUMN);
      this.refresh();
    }
    this.view.visible = on;
    if (!on) this.detail.hide();
  }

  /** Its rows and progress read afresh. */
  private refresh(): void {
    const next = this.lit;
    {
      let golds = 0, medals = 0, done = 0;
      for (let c = 0; c < COURSES.length; c++) {
        const medal = bestMedal(c);
        if (medal != null) done++;
        if (medal != null && medal < 3) medals++;
        if (medal === 0) golds++;
        this.rows[c]!.set(c === next);
      }
      this.progress.set(`${done} / ${COURSES.length} done  ·`);
      this.golds.set(`  ${golds} gold`);
      this.unlock.view.visible = openCount() < COURSES.length;
      if (this.units) this.layout(this.units);
    }
  }

  /** The page turned by `by`, held within the pages there are. */
  private turn(by: number): void {
    this.page = Math.max(0, Math.min(this.pages() - 1, this.page + by));
    this.list.top();
    if (this.units) this.layout(this.units);
  }

  private pages(): number {
    return Math.ceil(this.rows.length / COLUMN);
  }

  layout(units: Units): void {
    this.units = units;
    // Laid out at the menus' unit; if that runs off the frame, again, smaller, to fit.
    const tall = this.place(units, units.m);
    if (tall > units.height && tall > 0) this.place(units, (units.m * units.height) / tall * 0.96);
  }

  /** Everything placed at the unit `m`; answers the panel's height. */
  private place(units: Units, m: number): number {
    const { width, height } = units;
    this.veil.clear().rect(0, 0, width, height).fill(COLOUR.veil);
    const pad = SCREEN_M.platePad * m;
    this.title.restyle({ size: SCREEN_M.heading * m });
    this.progress.restyle({ size: SCREEN_M.body * m });
    this.golds.restyle({ size: SCREEN_M.body * m });
    const progressW = this.progress.lineBox.width + this.golds.lineBox.width;
    this.garage.layout(m);
    this.prev.layout(m);
    this.next.layout(m);
    // (Lock all and Unlock all small, either side of the progress line: clear of the heading.)
    this.unlock.layout(m * SIDE_BUTTONS);
    this.lock.layout(m * SIDE_BUTTONS);
    this.lock.view.visible = openCount() > 1;
    const cell = KIT_M.check * m, room = SCREEN_M.flagRoom * m, under = SCREEN_M.under * m, drop = SCREEN_M.underDrop * m;
    const line = SCREEN_M.lineRoom * m, gap = SCREEN_M.ruleRoom * m;
    // A row at least a finger high on a phone.
    const rowH = Math.max(SCREEN_M.row * m, touchFloor()), rowGap = SCREEN_M.rowGap * m;
    const headH = this.title.lineBox.height + drop + under;
    const perPage = Math.min(COLUMN, this.rows.length);
    const buttonsH = this.garage.height + SCREEN_M.buttonSink * m;
    // The progress line, Lock all left of it and Unlock all right; where they would crowd it (a phone upright), the
    // two buttons on a line of their own under it.
    const sideW = Number(this.lock.view.visible) * this.lock.width + Number(this.unlock.view.visible) * this.unlock.width;
    const sideH = Number(this.lock.view.visible || this.unlock.view.visible) * this.unlock.height;
    // Ten courses a page (the valley runs, then the mountain ones): in one column, or in two side by side when one
    // would run off the frame and two fit across (a phone on its side).
    const fixedH = pad + headH + line + gap + gap + buttonsH + pad;
    const oneTall = fixedH + Math.max(this.progress.lineBox.height, sideH) + perPage * (rowH + rowGap);
    const cols = oneTall > height && width >= (SCREEN_M.selectCol * 2 + SCREEN_M.platePad * 4) * m ? 2 : 1;
    // (On its side, a phone's frame is short: the plate kept between the pause and sound buttons, not under them.)
    const hudW = (SCREEN_U.button * 2 + SCREEN_U.buttonGap + SIZE_U.inset * 2) * units.u;
    const w = Math.min(SCREEN_M.select * m * cols, width - 2 * pad, width > height ? width - 2 * hudW : width);
    const x = (width - w) / 2;
    const colGap = pad * 0.6;
    const rowW = (w - 2 * pad - colGap * (cols - 1)) / cols;
    const crowded = sideH > 0 && sideW + progressW + gap * 4 > w - 2 * pad;
    const progressH = crowded ? this.progress.lineBox.height + line + sideH : Math.max(this.progress.lineBox.height, sideH);
    const perCol = Math.ceil(perPage / cols);
    // Clear of the pause and sound buttons (the HUD's, top right) where the plate reaches under them.
    const hudTop = x + w > width - hudW ? Math.max(units.safe.top, SIZE_U.inset * units.u) + SCREEN_U.button * units.u : 0;
    const roomTop = Math.max(pad * 0.5, hudTop);
    const listAll = perCol * (rowH + rowGap) - rowGap;
    // The rows as many as fit; the rest reached by scrolling (at least three rows shown).
    const listH = Math.max(Math.min(listAll, rowH * 3), Math.min(listAll, height - roomTop - pad * 0.5 - (fixedH + progressH)));
    const h = fixedH + progressH + listH;
    const top = Math.max(roomTop, (height - h) / 2);
    plate(this.panel.clear(), x, top, w, h, m);
    this.deco.clear();
    let y = top + pad;
    placeHeading(this.deco, this.title, x + (w - headingWidth(this.title, cell, room)) / 2, y, cell, room, under, drop);
    y += headH + line;
    const sideY = crowded ? y + this.progress.lineBox.height + line : y + (progressH - sideH) / 2;
    this.progress.position.set(x + (w - progressW) / 2, crowded ? y : y + (progressH - this.progress.lineBox.height) / 2);
    this.golds.position.set(this.progress.x + this.progress.lineBox.width, this.progress.y);
    y += progressH + gap;
    // The list: the rows, scrolling if they run past it (a scroll bar down its right then, the rows narrower for it).
    const scrolls = listAll > listH + 0.5;
    const bar = scrolls ? KARTY_M.scrollBar * m : 0;
    this.list.layout(w - 2 * pad + (scrolls ? bar * (1 + KARTY_M.scrollGap) : 0), listH, bar);
    this.list.view.position.set(x + pad, y);
    this.list.fit(listAll);
    const at = (i: number): { rx: number; ry: number } => {
      const n = i % COLUMN;
      const col = Math.floor(n / perCol);
      return { rx: col * (rowW + colGap), ry: (n % perCol) * (rowH + rowGap) };
    };
    this.rows.forEach((row, i) => {
      const on = Math.floor(i / COLUMN) === this.page;
      row.view.visible = on;
      if (!on) return;
      row.layout(m, rowW, rowH);
      const { rx, ry } = at(i);
      row.view.position.set(rx, ry);
    });
    // Each map's button over its map, on this page only.
    const mapX = SCREEN_M.rowMark * m + KIT_M.space * m + SCREEN_M.rowNum * m;
    this.mapHits.forEach((hit, i) => {
      const on = Math.floor(i / COLUMN) === this.page;
      hit.visible = on;
      if (!on) return;
      hit.hitArea = new Rectangle(0, 0, SCREEN_M.rowMap * m, rowH);
      const { rx, ry } = at(i);
      hit.position.set(rx + mapX, ry);
    });
    this.detail.layout(units);
    y += listH;
    // The one lit kept in sight.
    if (Math.floor(this.lit / COLUMN) === this.page) {
      const { ry } = at(this.lit);
      this.list.show(ry, ry + rowH);
    }
    y += gap;
    // The page's arrows either side, the garage between them.
    this.garage.view.position.set(x + (w - this.garage.width) / 2, y);
    this.prev.view.position.set(x + pad, y);
    this.next.view.position.set(x + w - pad - this.next.width, y);
    // Unlock all at the progress line's right, Lock all at its left.
    this.unlock.view.position.set(x + w - pad - this.unlock.width, sideY);
    this.lock.view.position.set(x + pad, sideY);
    this.prev.view.alpha = this.page > 0 ? 1 : 0.3;
    this.next.view.alpha = this.page < this.pages() - 1 ? 1 : 0.3;
    return h + pad;
  }
}

/** Lock all and Unlock all, this much of the menus' button size. */
const SIDE_BUTTONS = 0.62;

/** Seconds a first press of Lock all waits for its second. */
const LOCK_ASK = 3;

/** A locked course's row, this faint. */
const LOCKED_ALPHA = 0.45;

/** `words` into `label`, cut short with '…' to no wider than `room` (nothing at all where not even a letter fits). */
export function ellipsize(label: KLabel, words: string, room: number): void {
  label.set(words);
  if (label.lineBox.width <= room) return;
  let lo = 0, hi = words.length - 1;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    label.set(`${words.slice(0, mid).trimEnd()}…`);
    if (label.lineBox.width <= room) lo = mid;
    else hi = mid - 1;
  }
  label.set(lo > 0 ? `${words.slice(0, lo).trimEnd()}…` : '');
}

/** A linear colour (a course's look) as the hex Pixi draws, times `k`. */
function hex(c: readonly [number, number, number], k = 1): number {
  const s = (v: number): number => Math.max(0, Math.min(255, Math.round(Math.pow(Math.max(0, v * k), 1 / 2.2) * 255)));
  return (s(c[0]) << 16) | (s(c[1]) << 8) | s(c[2]);
}

/**
 * A course's little map into `g`, in the box (x, y, w, h): its ground in its own grass colour, the road its centre
 * line seen from above (fitted to the box, kept square), dark-edged in its road colour, a gold dot at the start and
 * a chequered one at the finish.
 */
/** A small map's road, at least this share of a big one's thickness. */
const MAP_THIN = 0.45;

export function drawMap(g: Graphics, course: number, x: number, y: number, w: number, h: number, m: number): MapView {
  const c = COURSES[course]!;
  const t = TRACKS[course]!;
  g.clear();
  g.roundRect(x, y, w, h, SCREEN_M.rowRound * m * 0.6).fill(hex(c.grass, 1.05));
  let x0 = Infinity, x1 = -Infinity, z0 = Infinity, z1 = -Infinity;
  for (let i = 0; i < t.samples; i += 4) {
    x0 = Math.min(x0, t.sx[i]!); x1 = Math.max(x1, t.sx[i]!);
    z0 = Math.min(z0, t.sz[i]!); z1 = Math.max(z1, t.sz[i]!);
  }
  const pad = Math.min(w, h) * 0.12;
  const k = Math.min((w - 2 * pad) / Math.max(1, x1 - x0), (h - 2 * pad) / Math.max(1, z1 - z0));
  const ox = x + w / 2 - ((x0 + x1) / 2) * k, oy = y + h / 2 + ((z0 + z1) / 2) * k;
  // Seen from above with the road running down the page: x across, z up it (flipped, so the start is at the top).
  const px = (i: number): number => ox + t.sx[i]! * k;
  const py = (i: number): number => oy - t.sz[i]! * k;
  const line = (width: number, colour: number): void => {
    g.moveTo(px(0), py(0));
    for (let i = 4; i < t.samples; i += 4) g.lineTo(px(i), py(i));
    g.lineTo(px(t.samples - 1), py(t.samples - 1));
    g.stroke({ width, color: colour, cap: 'round', join: 'round' });
  };
  // Thick and bold on a big map; thinner on a small one (a row's), so the road still reads as a line.
  const z = Math.max(MAP_THIN, Math.min(1, Math.min(w, h) / (SCREEN_M.mapFull * m))) * m;
  line(Math.max(1.5, SCREEN_M.mapEdge * z), hex(c.road, 0.45));
  line(Math.max(1, SCREEN_M.mapRoad * z), hex(c.road, 1.5));
  const s = Math.max(0, Math.min(t.samples - 1, t.start)), f = Math.max(0, Math.min(t.samples - 1, t.finish));
  g.circle(px(s), py(s), Math.max(1.5, SCREEN_M.mapDot * z)).fill(KARTY_COLOUR.gold);
  g.circle(px(f), py(f), Math.max(1.5, SCREEN_M.mapDot * z)).fill(KIT_COLOUR.text);
  g.circle(px(f), py(f), Math.max(0.8, SCREEN_M.mapDotMiddle * z)).fill(KIT_COLOUR.ink);
  return { px, py, k, ox, oy };
}

/** Where a map put the course: a sample's place on it, and its scale (pixels a metre) and origin. */
export interface MapView {
  px(i: number): number;
  py(i: number): number;
  readonly k: number;
  readonly ox: number;
  readonly oy: number;
}
