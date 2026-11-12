/**
 * The garage: the kart builder, shown while the kart waits on the line -- the kart itself in the middle of the
 * screen, the builder round it.
 *
 *  - Across the top, a bar: the title, the course (a back arrow to the course select, its number and name), its time to win, and
 *    the kart's weight with a meter.
 *  - Down the left, a tab a slot -- chassis, wheels, suspension, steering, the driver's outfit -- the one open lit
 *    orange. A slot that has sizes (the kart's chassis, the wheels, the springs' travel) shows them first in its
 *    strip, each a − and a + about its percent, before its parts.
 *  - Over the kart, its name on a banner: its bodywork's, or its chassis' with none.
 *  - On the right, how it drives: the ratings as bars, and the warnings (which a player may ignore).
 *  - Along the bottom, the open slot's parts as cards -- a picture of each, its name and cost, the one fitted
 *    lit and ticked -- scrolling across when there are more than fit; a line over them about the part last
 *    picked; and Race!.
 *
 * Every change rebuilds the kart on the line behind it at once (`live.ts`' `setSlot`), so the build is seen as
 * it is made. The look is the kit's (`kit.ts`); the parts' pictures are their own models (`thumbs.ts`).
 */
import { Container, type FederatedPointerEvent, Graphics, Rectangle, Sprite } from 'pixi.js';
import { Audio } from '@vibe/engine/assets';
import { Pressable, SIZE_U, type ButtonState, type Units, type Widget } from '@vibe/engine/ui';
import { phoneSized, SCREEN_M, SCREEN_U } from './screen-theme.ts';
import { BODY, CHASSIS, type Choice, emptyMass, newRating, rate, type Rating, rulesBreak, SIZES, SLOTS, STARTER, unlockOf, WEIGHT_LIMIT, wheelSizeMin, WHEELS } from '../game/build.ts';
import { DIFFICULTY_COLOURS, KARTY_COLOUR, KARTY_M, KIT_ALPHA, KIT_COLOUR, KIT_M } from './karty-theme.ts';
import { divider, flag, glyph, type Glyph, KLabel, meter, plate, slant, clicked } from './kit.ts';
import { currentCourse, currentWeather, Order, orderRace, readBuild, screen, setSlot, type Slot } from './live.ts';
import { bestMedal, isOpen, openCount } from './progress.ts';
import { drawMap } from './course-select.ts';
import { CourseDetail } from './course-detail.ts';
import { SlantButton, touchFloor } from './slant-button.ts';
import { headingWidth, placeHeading } from './screen-kit.ts';
import { COURSES, difficultyOf, DIFFICULTIES } from '../game/courses.ts';
import { ScrollBox } from './scroll-box.ts';
import { thumb, type With } from './thumbs.ts';

const SLOT_KEYS: readonly Slot[] = ['chassis', 'wheels', 'suspension', 'steering', 'body', 'outfit'];
const SLOT_GLYPHS: readonly Glyph[] = ['chassis', 'wheels', 'suspension', 'steering', 'body', 'person'];
/** The chassis a body comes on: every body is a whole kart, picked as one card with its chassis. */
const baseOf = (body: number): number => BODY[body]?.on ?? 1;
/** A body's card: a themed one is its whole kart; any other is drawn sitting on its chassis, as `assemble` puts it. */
function kartPicture(body: number): Picture {
  const bo = BODY[body]!;
  if (bo.natural) return { model: bo.model, or: 'body', extra: bitsOf(body) };
  const ch = CHASSIS[baseOf(body)]!;
  return { model: ch.model, or: 'body', also: { key: bo.model, y: ch.size[1] / 2, z: bo.z } };
}

/** One card of a tab: what it shows, whether the build has it, and the slots it sets when pressed. */
interface Option {
  id: string;
  name: string;
  /** Courses won to have it. */
  unlock: number;
  blurb: string;
  picture: Picture;
  chosen: (c: Choice) => boolean;
  set: (c: Choice) => Partial<Record<Slot, number>>;
}

/** A slot's parts, a card each. */
function slotOptions(i: number): Option[] {
  const key = SLOT_KEYS[i]!;
  return byUnlock(SLOTS[i]!.parts.map((p, j) => ({ id: `garage-${key}-${j}`, name: p.name, unlock: unlockOf(key, j), blurb: p.blurb, picture: pictureOf(key, j), chosen: (c: Choice) => c[key] === j, set: () => ({ [key]: j }) })));
}

/** Cards in the order they unlock: the ones open from the start first, then by the courses won each needs (ties kept
 * in their list's order). */
function byUnlock(options: Option[]): Option[] {
  const early = (o: Option): number => {
    const i = EARLY.indexOf(o.name);
    return i < 0 ? EARLY.length : i;
  };
  return options.map((o, n) => ({ o, n })).sort((a, b) => a.o.unlock - b.o.unlock || early(a.o) - early(b.o) || a.n - b.n).map((x) => x.o);
}

/** Parts shown first among those open from the same number of wins, in this order (by name): the plank, then the
 * crate kart. */
const EARLY: readonly string[] = ['Plank', 'Crate Expectations'];

/** Bare chassis not offered in the garage any more, by name. */
const GARAGE_HIDDEN: ReadonlySet<string> = new Set(['Fruit crate', 'Shopping trolley']);

/** The kart's name over it, this times the theme's banner size. */
const BANNER_SCALE = 0.75;

/** The sizes panel's heading, by the tab it is open on. */
const SIZE_HEADS: Readonly<Record<string, string>> = { 'garage-tab-chassis': 'Chassis size', 'garage-tab-wheels': 'Wheel size', 'garage-tab-suspension': 'Springs' };

/** The next race's panel: at least this wide, and its map this wide (in `m`). */
const NEXT_W = 260;
const NEXT_MAP = 118;
/** ... and at most this share of a narrow panel (a phone's), its name beside it. */
const NEXT_MAP_SHARE = 0.45;
/** Stacked (a full-width map, `layoutNextStacked`): the map this tall for its width. */
const NEXT_MAP_TALL = 0.62;
/** Its Change course button, this much of the menus' button size. */
const NEXT_BUTTON = 0.75;

/** On a phone (`layoutPhone`): the parts' cards on its side, this much of their size (the frame is short); Race!,
 * upright, this much of its height, and on its side at most this share of the width; how it drives, on its side, at
 * most this share; and the tabs in a row all with their names when each gets this much of a tab's width. */
const PHONE_CARDS = 0.8;
const PHONE_RACE = 0.62;
const PHONE_RACE_W = 0.28;
const PHONE_SIDE = 0.34;
/** On a phone: How it drives at this much of the menus' unit and this much of its column's width -- smaller, so
 * the kart shows past it. */
const PHONE_STATS = 0.78;
/** The weight in the top bar: its icon this times the top bar's words, its meter this times the theme's thickness,
 * gold from this share of the limit. */
const WEIGHT_ICON = 1.15;
const WEIGHT_BAR = 1.8;
const WEIGHT_NEAR = 0.9;
const PHONE_STATS_W = 0.82;
const TAB_ROW_EVEN = 0.8;

/**
 * The tabs down the left, each with the sizes tweaked in it (indices into `SIZES`).
 *  - The kart: every chassis bare, and every body on the chassis it comes on -- one list, each card a whole kart.
 *    A bare chassis picked takes a body off; a body brings its chassis with it.
 *  - Then a slot each.
 */
const SIZES_OF: Partial<Record<Slot, readonly number[]>> = { wheels: [2, 3], suspension: [4] };
/** The workshop's sounds (scripts/ui-sounds.ts): a part fitted, by its tab -- the kart set down on the bench, a wheel
 * on, a spring, the steering's spanner, the driver's zip -- and how loud; a size slider's tick, at most one this often
 * (seconds). */
const FIT_SOUNDS: readonly AssetKeys.UiSfx[] = ['clunk', 'wheel', 'boing', 'ratchet', 'zip'];
const FIT_VOLUME = 0.7;
const TICK_VOLUME = 0.35;
const TICK_GAP = 0.04;
let tickAt = 0;

/** A workshop sound, a little varied in pitch each time. */
function workshop(key: AssetKeys.UiSfx, volume: number): void {
  Audio.ui(key, { volume, rate: 0.95 + Math.random() * 0.1 });
}

const TABS: readonly { name: string; glyph: Glyph; id: string; options: readonly Option[]; sizes: readonly number[] }[] = [
  {
    name: 'Kart', glyph: 'chassis', id: 'garage-tab-chassis', sizes: [0, 1],
    options: byUnlock([
      // (The fruit crate and the shopping trolley are no longer offered bare: GARAGE_HIDDEN. Bodies built on them still are.)
      ...CHASSIS.flatMap((p, j) => GARAGE_HIDDEN.has(p.name) ? [] : [{
        id: `garage-chassis-${j}`, name: p.name, unlock: unlockOf('chassis', j), blurb: p.blurb, picture: pictureOf('chassis', j),
        chosen: (c: Choice) => c.body === 0 && c.chassis === j,
        set: () => ({ chassis: j, body: 0 }),
      }]),
      ...BODY.flatMap((p, j) => {
        if (j === 0) return [];
        const on = baseOf(j);
        return [{
          id: `garage-body-${j}`, name: p.name, unlock: Math.max(unlockOf('body', j), unlockOf('chassis', on)), blurb: p.blurb, picture: kartPicture(j),
          chosen: (c: Choice) => c.body === j,
          set: () => ({ chassis: on, body: j }),
        }];
      }),
    ]),
  },
  ...[1, 2, 3, 5].map((i) => ({ name: SLOTS[i]!.name, glyph: SLOT_GLYPHS[i]!, id: `garage-tab-${SLOT_KEYS[i]}`, options: slotOptions(i), sizes: SIZES_OF[SLOT_KEYS[i]!] ?? [] })),
];
const RATINGS = [['Speed', 'speed'], ['Stability', 'stability'], ['Grip', 'grip'], ['Toughness', 'toughness'], ['Crowd appeal', 'appeal']] as const;

/** What a part's card shows: a model's picture, or a glyph. */
type Picture = { model: string; or: Glyph; also?: With; extra?: readonly string[] } | { glyph: Glyph };
/** A body's bits that come off on their own (`BODY`'s bits), as the parts its picture draws with it: `<model>_<part>`. */
function bitsOf(body: number): readonly string[] {
  const bo = BODY[body];
  return bo?.bits ? bo.bits.map((b) => `${bo.model}_${b.part}`) : [];
}

function pictureOf(slot: Slot, j: number): Picture {
  const part = SLOTS[SLOT_KEYS.indexOf(slot)]!.parts[j]!;
  const model = 'model' in part ? (part as { model: string }).model : '';
  switch (slot) {
    case 'chassis':
    case 'wheels':
    case 'suspension':
    case 'steering':
      return { model, or: slot };
    case 'body':
      return model ? { model, or: 'body', extra: bitsOf(j) } : { glyph: 'none' };
    case 'outfit':
      return { model, or: 'person' };
    default:
      return { glyph: 'none' };
  }
}

/** A slot's tab down the left: its glyph and name; the one open orange, pointing at the kart. */
class Tab {
  readonly view = new Container();
  private readonly back = new Graphics();
  private readonly icon = new Graphics();
  private readonly words: KLabel;
  private readonly kind: Glyph;
  private on = false;
  private point = true;
  private w = 1;
  private h = 1;
  private m = 1;
  readonly press: Pressable;

  constructor(id: string, name: string, kind: Glyph, onPress: () => void) {
    this.kind = kind;
    this.words = new KLabel({ size: KIT_M.tabText, caps: true, fill: KIT_COLOUR.text }, name);
    this.view.addChild(this.back, this.icon, this.words);
    this.press = new Pressable(this.view, { id, onPress: () => {
      workshop('tab', 0.6);
      onPress();
    }, onState: (state) => this.draw(state) });
  }

  /** `point`: the chosen one points right, at the kart (down the left); in a row across (a phone), it does not. */
  layout(m: number, w: number, h: number, point = true): void {
    this.m = m;
    this.w = w;
    this.h = h;
    this.point = point;
    // Its words as big as fit beside the glyph, a little smaller if need be; where even that will not fit (a narrow
    // tab in a row across), the glyph alone, in its middle.
    const s = Math.min(KIT_M.tabIcon * m, h * 0.62);
    const room = w - h * 0.22 - s - h * 0.28 - h * 0.22;
    let size = Math.min(KIT_M.tabText * m, h * 0.46);
    this.words.restyle({ size });
    for (let i = 0; i < 3 && this.words.lineBox.width > room; i++) this.words.restyle({ size: (size *= 0.9) });
    this.words.visible = this.words.lineBox.width <= room;
    this.draw(this.press.states);
  }

  choose(on: boolean): void {
    if (on === this.on) return;
    this.on = on;
    this.draw(this.press.states);
  }

  private draw(state: Readonly<ButtonState>): void {
    const { w, h, m } = this;
    const g = this.back.clear();
    if (this.on) {
      // Blue, chosen: a sticker, its right end a point toward the kart.
      const p = this.point ? KIT_M.tabPoint * m : 0;
      const r = KIT_M.cardRound * m;
      const t = Math.max(1, KIT_M.edge * m);
      const d = t * KIT_M.drop;
      const shape = [r, 0, w - p, 0, w, h / 2, w - p, h, r, h, 0, h - r, 0, r];
      g.poly(shape.map((v) => v + d)).fill({ color: KIT_COLOUR.shadow, alpha: KIT_M.dropAlpha });
      g.poly(shape).fill(KIT_COLOUR.pick).poly(shape).stroke({ color: KIT_COLOUR.edge, width: t, join: 'round' });
    } else {
      plate(g, 0, 0, w, h, m, state.hover ? KIT_COLOUR.cardHover : KIT_COLOUR.plate, state.hover ? KIT_COLOUR.pick : KIT_COLOUR.edge);
    }
    // The glyph in a round badge on the left.
    const s = Math.min(KIT_M.tabIcon * m, h * 0.62);
    const ix = this.words.visible ? h * 0.22 : (w - s) / 2;
    const iy = (h - s) / 2;
    this.icon.clear();
    if (this.on) this.icon.circle(ix + s / 2, h / 2, s * 0.62).fill(KIT_COLOUR.ink);
    glyph(this.icon, this.kind, ix, iy, s, this.on ? KIT_COLOUR.pick : KIT_COLOUR.glyph);
    this.words.restyle({ fill: this.on ? KIT_COLOUR.ink : KIT_COLOUR.text });
    this.words.position.set(ix + s + h * 0.28, (h - this.words.lineBox.height) / 2);
    this.view.alpha = state.down ? 0.8 : 1;
  }
}

/** One part's card: its picture and name (locked: faint, and the wins it needs); pressed, it is fitted; the one fitted lit and ticked. */
class Card {
  readonly view = new Container();
  private readonly back = new Graphics();
  private readonly art = new Graphics();
  private readonly shot = new Sprite();
  private readonly name: KLabel;
  private readonly cost: KLabel;
  private readonly picture: Picture;
  private locked = false;
  private drawn = false;
  private on = false;
  private w = 1;
  private h = 1;
  private m = 1;
  readonly press: Pressable;

  constructor(id: string, name: string, picture: Picture, onPress: () => void) {
    // (No click: the part's own sound plays as it is fitted -- `Garage.pick`.)
    this.picture = picture;
    this.name = new KLabel({ size: KIT_M.cardText, fill: KIT_COLOUR.text }, name);
    this.cost = new KLabel({ size: KIT_M.cardText, fill: KIT_COLOUR.hot }, '');
    this.view.addChild(this.back, this.art, this.shot, this.name, this.cost);
    this.press = new Pressable(this.view, { id, onPress, onState: (state) => this.draw(state) });
  }

  layout(m: number, w: number, h: number): void {
    this.m = m;
    this.w = w;
    this.h = h;
    // The name and cost along the bottom, made smaller until they fit.
    const room = w - KIT_M.space * m * 1.6;
    let size = KIT_M.cardText * m;
    for (let i = 0; i < 6; i++) {
      this.name.restyle({ size });
      this.cost.restyle({ size });
      if (this.name.lineBox.width + size * 0.4 + this.cost.lineBox.width <= room) break;
      size *= 0.88;
    }
    const lineY = h - KIT_M.space * m * 0.7 - this.name.lineBox.height;
    const total = this.name.lineBox.width + size * 0.4 + this.cost.lineBox.width;
    this.name.position.set((w - total) / 2, lineY);
    this.cost.position.set((w - total) / 2 + this.name.lineBox.width + size * 0.4, lineY);
    this.drawPicture();
    this.draw(this.press.states);
  }

  /** Its picture: the model's, once it can be had; a glyph or a paint swatch otherwise. */
  private drawPicture(): void {
    const { m, w } = this;
    // (Never below nothing: laid out before its size is known -- locked before its first layout -- a negative size
    // would flip the picture, and Pixi's width keeps a flip.)
    const s = Math.max(1, Math.min(KIT_M.thumb * m, this.name.y - KIT_M.space * m * 0.5));
    const x = (w - s) / 2;
    const y = KIT_M.space * m * 0.6;
    const p = this.picture;
    this.art.clear();
    if ('model' in p) {
      const texture = thumb(p.model, p.also, p.extra);
      if (texture) {
        this.drawn = true;
        // A soft pale disc behind it: a dark part (a black wheel) still stands out from the card.
        this.art.circle(x + s / 2, y + s / 2, s * 0.46).fill({ color: KIT_COLOUR.text, alpha: PICTURE_DISC });
        this.shot.texture = texture;
        this.shot.visible = true;
        // A little bigger than its box: the picture has room round the model.
        const big = s * 1.18;
        this.shot.scale.set(big / Math.max(1, texture.width), big / Math.max(1, texture.height));
        this.shot.position.set((w - big) / 2, y + (s - big) / 2);
        return;
      }
      this.shot.visible = false;
      glyph(this.art, p.or, x + s * 0.2, y + s * 0.2, s * 0.6);
      return;
    }
    this.shot.visible = false;
    this.art.circle(x + s / 2, y + s / 2, s * 0.42).fill({ color: KIT_COLOUR.text, alpha: KIT_ALPHA.shine });
    glyph(this.art, p.glyph, x + s * 0.2, y + s * 0.2, s * 0.6);
  }

  /** Its model's picture tried again, if it was not to be had when last laid out. */
  retry(): void {
    if (!this.drawn && 'model' in this.picture) this.drawPicture();
  }

  /** Locked till `need` courses are won: faint, the wins it needs where its tag is. */
  lock(locked: boolean, need: number): void {
    if (locked === this.locked) return;
    this.locked = locked;
    this.cost.set(locked ? `Win ${need}` : '');
    this.layout(this.m, this.w, this.h);
    this.draw(this.press.states);
  }

  choose(on: boolean): void {
    if (on === this.on) return;
    this.on = on;
    this.draw(this.press.states);
  }

  private draw(state: Readonly<ButtonState>): void {
    const { w, h, m } = this;
    const g = this.back.clear();
    const r = KIT_M.cardRound * m;
    const fill = state.hover ? KIT_COLOUR.cardHover : KIT_COLOUR.card;
    // A sticker: its drop shadow, its cream face, a navy outline -- blue and thick, ticked, when it is the one chosen.
    const edge = Math.max(1, KIT_M.edge * m);
    g.roundRect(edge * KIT_M.drop, edge * KIT_M.drop, w, h, r).fill({ color: KIT_COLOUR.shadow, alpha: KIT_M.dropAlpha });
    g.roundRect(0, 0, w, h, r).fill({ color: fill, alpha: KIT_ALPHA.bar });
    if (this.on) {
      g.roundRect(0, 0, w, h, r).stroke({ color: KIT_COLOUR.pick, width: Math.max(2, edge * 1.6) });
      // The tick, in a blue badge in the top right corner -- inside the card, so the strip's scroll window never clips it.
      const t = KIT_M.tick * m;
      const cx = w - t * 0.72, cy = t * 0.72;
      g.circle(cx, cy, t * 0.62).fill(KIT_COLOUR.pick).circle(cx, cy, t * 0.62).stroke({ color: KIT_COLOUR.ink, width: Math.max(1.5, t / 9) });
      g.moveTo(cx - t * 0.27, cy + t * 0.01).lineTo(cx - t * 0.07, cy + t * 0.23).lineTo(cx + t * 0.29, cy - t * 0.23).stroke({ color: KIT_COLOUR.ink, width: Math.max(1.5, t / 7), cap: 'round', join: 'round' });
    } else {
      g.roundRect(0, 0, w, h, r).stroke({ color: state.hover ? KIT_COLOUR.pick : KIT_COLOUR.edge, width: edge });
    }
    // Locked: its picture still shown (a little dimmed, so you can see what is coming), its name faint, and a padlock
    // in the top right corner.
    this.shot.alpha = this.locked ? LOCKED_PICTURE : 1;
    this.art.alpha = this.locked ? LOCKED_PICTURE : 1;
    this.name.alpha = this.locked ? LOCKED_ALPHA : 1;
    if (this.locked) {
      const t = KIT_M.tick * m;
      const lx = w - t * 1.05, ly = t * 0.45, lw = t * 0.7, lh = t * 0.55;
      g.roundRect(lx + lw * 0.2, ly - lh * 0.55, lw * 0.6, lh * 0.9, lw * 0.3).stroke({ color: KIT_COLOUR.text, width: Math.max(1.5, t / 8) });
      g.roundRect(lx, ly, lw, lh, t * 0.08).fill(KIT_COLOUR.text);
      g.circle(lx + lw / 2, ly + lh * 0.45, Math.max(1, t * 0.07)).fill(KIT_COLOUR.ink);
    }
    this.view.alpha = state.down ? 0.8 : 1;
  }
}

/** Courses won so far: what opens the parts. */
function wins(): number {
  return Math.max(0, openCount() - 1);
}

/** A locked part's card, this faint. */
const LOCKED_ALPHA = 0.4;
/** A locked part's picture, this bright: dimmed, still plain to see. */
const LOCKED_PICTURE = 0.7;
/** The pale disc behind a part's picture, this strong. */
const PICTURE_DISC = 0.22;

/**
 * A size's card: its name, its percent, and a bar under them to slide it -- the knob dragged, or the bar pressed
 * where it should go -- held to the size's steps.
 */
class SizeCard {
  readonly view = new Container();
  private readonly back = new Graphics();
  private readonly bar = new Graphics();
  readonly name: KLabel;
  readonly value: KLabel;
  private readonly min: number;
  private readonly max: number;
  private readonly step: number;
  private at = 100;
  private dragging = false;
  private hover = false;
  private w = 1;
  private h = 1;
  private m = 1;
  /** The bar's run, in the card: where it starts, how long, its middle's height. */
  private x0 = 0;
  private len = 1;
  private by = 0;

  constructor(name: string, min: number, max: number, step: number, onSet: (to: number) => void) {
    this.min = min;
    this.max = max;
    this.step = step;
    this.name = new KLabel({ size: KIT_M.sideText, fill: KIT_COLOUR.text }, name.replace(/^Chassis (\w)/, (_, c: string) => c.toUpperCase()));
    this.value = new KLabel({ size: KIT_M.sizeText, fill: KIT_COLOUR.pickLight }, '');
    this.view.addChild(this.back, this.name, this.value, this.bar);
    this.bar.eventMode = 'static';
    this.bar.cursor = 'pointer';
    /** To where `x` (in the card) is along the bar. */
    const slideTo = (x: number): void => {
      const share = Math.max(0, Math.min(1, (x - this.x0) / this.len));
      const to = Math.round((this.min + share * (this.max - this.min)) / this.step) * this.step;
      if (to !== this.at) onSet(Math.max(this.min, Math.min(this.max, to)));
    };
    // The drag followed on the page (the UI layer sends no moves off the bar): where it began, in the card and
    // in the page's CSS pixels, and how many of the card's units a CSS pixel is.
    let id = -1, fromX = 0, fromClient = 0, scale = 1;
    const onMove = (ev: PointerEvent): void => {
      if (ev.pointerId === id) slideTo(fromX + (ev.clientX - fromClient) * scale);
    };
    const onUp = (ev: PointerEvent): void => {
      if (ev.pointerId !== id) return;
      id = -1;
      this.dragging = false;
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
      window.removeEventListener('pointercancel', onUp);
      this.draw();
    };
    this.bar.on('pointerdown', (e: FederatedPointerEvent) => {
      e.stopPropagation();
      const native = e.nativeEvent as PointerEvent;
      const el = native.target instanceof HTMLElement ? native.target : null;
      const drawn = el?.getBoundingClientRect().width;
      const css = el?.clientWidth;
      scale = (css && drawn ? css / drawn : 1) / Math.max(1e-6, this.view.worldTransform.a);
      fromX = this.view.toLocal(e.global).x;
      fromClient = native.clientX;
      id = native.pointerId;
      this.dragging = true;
      slideTo(fromX);
      window.addEventListener('pointermove', onMove);
      window.addEventListener('pointerup', onUp);
      window.addEventListener('pointercancel', onUp);
      this.draw();
    });
    this.bar.on('pointerover', () => { this.hover = true; this.draw(); });
    this.bar.on('pointerout', () => { this.hover = false; this.draw(); });
  }

  /** Its percent now. */
  set(to: number): void {
    this.at = to;
    this.value.set(`${to}%`);
    if (this.w > 1) this.layout(this.m, this.w, this.h);
  }

  /** Its height laid out across `w` at the unit `m`: its words' line and its slider's. */
  static height(m: number): number {
    return KIT_M.sideHead * m * 1.2 + KIT_M.stepper * m * 0.9;
  }

  /** Laid out as a row `w` across, `h` high: its name left, its percent right, the slider the width under them. */
  layout(m: number, w: number, h: number): void {
    this.m = m;
    this.w = w;
    this.h = h;
    this.back.clear();
    this.name.restyle({ size: KIT_M.sideHead * m * 0.85 });
    this.name.position.set(0, 0);
    this.value.restyle({ size: KIT_M.sideHead * m * 0.85 });
    this.value.position.set(w - this.value.lineBox.width, 0);
    const knob = KIT_M.stepper * m * 0.6;
    this.x0 = knob / 2;
    this.len = Math.max(1, w - knob);
    this.by = h - knob / 2 - KIT_M.edge * m;
    this.draw();
  }

  private draw(): void {
    const m = this.m;
    const knob = KIT_M.stepper * m * 0.6;
    const thick = KIT_M.meterThick * m;
    const share = (this.at - this.min) / Math.max(1, this.max - this.min);
    const kx = this.x0 + share * this.len;
    const g = this.bar.clear();
    // Its hit area: the whole run, a knob high (a finger's on a phone).
    const hit = Math.max(knob, touchFloor());
    g.rect(this.x0 - knob / 2, this.by - hit / 2, this.len + knob, hit).fill({ color: KIT_COLOUR.bar, alpha: 0.001 });
    g.roundRect(this.x0, this.by - thick / 2, this.len, thick, thick / 2).fill(KIT_COLOUR.bar);
    // Blue, the garage's picking colour: a size is a choice, not a warning.
    g.roundRect(this.x0, this.by - thick / 2, Math.max(thick, kx - this.x0), thick, thick / 2).fill(KIT_COLOUR.pick);
    // A tick at 100%, the size as the part comes.
    const plain = this.x0 + ((100 - this.min) / Math.max(1, this.max - this.min)) * this.len;
    g.rect(plain - Math.max(1, KIT_M.edge * m) / 2, this.by - thick * 1.4, Math.max(1, KIT_M.edge * m), thick * 2.8).fill(KIT_COLOUR.edge);
    const lit = this.hover || this.dragging;
    g.circle(kx, this.by, knob / 2).fill(lit ? KIT_COLOUR.pickLight : KIT_COLOUR.text).circle(kx, this.by, knob / 2).stroke({ color: KIT_COLOUR.pick, width: Math.max(1.5, KIT_M.edge * m * 2) });
  }
}

/** Race!: a big green plate (Enter presses it too). */
class RaceButton {
  readonly view = new Container();
  private readonly back = new Graphics();
  private readonly words = new KLabel({ size: KIT_M.raceText, caps: true, fill: KIT_COLOUR.ink }, 'Race!');
  private ready = true;
  private bad = false;
  private w = 1;
  private h = 1;
  private m = 1;
  readonly press: Pressable;

  constructor(onPress: () => void) {
    this.view.addChild(this.back, this.words);
    // RACE!: a bicycle horn, honk-honk (a dull bonk when it cannot go).
    this.press = new Pressable(this.view, { id: 'race', onPress: () => {
      workshop(this.ready ? 'honk' : 'denied', 0.8);
      onPress();
    }, onState: (state) => this.draw(state) });
  }

  /** What it says: Race!, or why it cannot (locked, over budget). */
  set(words: string, ready: boolean, bad: boolean): void {
    this.words.set(words);
    this.ready = ready;
    this.bad = bad;
    if (this.w > 1) this.layout(this.m, this.w, this.h);
  }

  layout(m: number, w: number, h: number): void {
    this.m = m;
    this.w = w;
    this.h = h;
    const flagW = KIT_M.check * m * KIT_M.flagCols;
    // The words as big as fit.
    let size = Math.min(KIT_M.raceText * m, h * 0.6);
    for (let i = 0; i < 8; i++) {
      this.words.restyle({ size });
      if (this.words.lineBox.width <= w - flagW - h * 0.7) break;
      size *= 0.88;
    }
    this.draw(this.press.states);
  }

  private draw(state: Readonly<ButtonState>): void {
    const { w, h, m } = this;
    const g = this.back.clear();
    const drop = KIT_M.keyPad * m * 0.8;
    const face = !this.ready ? (this.bad ? KARTY_COLOUR.bad : KIT_COLOUR.card) : state.hover ? KIT_COLOUR.goLight : KIT_COLOUR.go;
    const shade = !this.ready ? KIT_COLOUR.bar : KIT_COLOUR.goDark;
    const sink = state.down ? drop * 0.7 : 0;
    slant(g, 0, drop, w, h - drop, shade);
    slant(g, 0, sink, w, h - drop, face, KIT_COLOUR.edge, Math.max(1, KIT_M.edge * m));
    const cell = KIT_M.check * m;
    const fy = sink + (h - drop - cell * KIT_M.flagRows) / 2;
    flag(g, h * 0.3, fy, cell, KIT_M.flagCols, KIT_M.flagRows, this.ready ? KIT_COLOUR.ink : KIT_COLOUR.edge, this.ready ? KIT_COLOUR.go : KIT_COLOUR.card);
    const flagW = cell * KIT_M.flagCols;
    const left = h * 0.3 + flagW + KIT_M.space * m;
    const right = w - h * 0.32;
    this.words.position.set(left + (right - left - this.words.lineBox.width) / 2, sink + (h - drop - this.words.lineBox.height) / 2);
    this.words.restyle({ fill: this.ready ? KIT_COLOUR.ink : KIT_COLOUR.dim });
  }
}

export class Garage implements Widget {
  readonly id = 'garage';
  readonly view = new Container({ label: 'garage' });

  // The top bar.
  private readonly topBack = new Graphics();
  private readonly title = new KLabel({ size: KIT_M.title, caps: true, fill: KIT_COLOUR.text }, 'The garage');
  /** Back to the course select, its own screen: the garage builds the kart for the course picked there. */
  private readonly weight = new KLabel({ size: KIT_M.topText * 0.8, fill: KIT_COLOUR.text }, '');
  private course = 0;

  // Down the left.
  private readonly tabs: Tab[] = [];
  /** Under the tabs: the next race -- the course the kart is built for, its little map, its name, and how far through
   * the courses the player is (done, and golds). */
  private readonly nextBack = new Graphics();
  private readonly nextDeco = new Graphics();
  private readonly nextMap = new Graphics();
  private readonly nextHead = new KLabel({ size: KIT_M.sideHead, caps: true, fill: KIT_COLOUR.text }, 'Next race');
  private readonly nextName = new KLabel({ size: KIT_M.sideText, caps: true, fill: KIT_COLOUR.text }, '');
  private readonly nextProgress = new KLabel({ size: KIT_M.small, fill: KIT_COLOUR.good }, '');
  /** ... and after it the golds won, in gold. */
  /** The next race's rating (`DIFFICULTIES`), in its colour, under its name. */
  private readonly nextRating = new KLabel({ size: KIT_M.small, caps: true, fill: KIT_COLOUR.text }, '');
  private readonly nextGolds = new KLabel({ size: KIT_M.small, fill: KARTY_COLOUR.gold }, '');
  /** Under the next race: off to the course select, to choose another. */
  private readonly changeCourse = new SlantButton('garage-change-course', 'Change course', () => { screen.now = 'courses'; }, 'plain');
  /** The course the next race's map was last drawn for, and where (drawn again only when either changes). */
  private nextShownFor = -1;
  /** Where the next race's panel and the sizes' end, as last laid out (their top, hidden). */
  private nextEnd = 0;
  private sizeEnd = 0;
  private nextMapAt = '';
  /** A tap on the next race's map: that course up close (`course-detail.ts`), over the garage. */
  private readonly mapHit = new Container({ label: 'garage-next-map' });
  private readonly detail = new CourseDetail(() => orderRace(Order.race));
  private open = 0;

  // Over the kart.
  private readonly bannerBack = new Graphics();
  private readonly banner = new KLabel({ size: KIT_M.banner, caps: true, fill: KIT_COLOUR.text }, '');

  // On the right.
  private readonly sideBack = new Graphics();
  private readonly sideHead = new KLabel({ size: KIT_M.sideHead, caps: true, fill: KIT_COLOUR.text }, 'How it drives');
  private readonly ratingNames = RATINGS.map(([name]) => new KLabel({ size: KIT_M.sideText, fill: KIT_COLOUR.text }, name));
  private readonly warnHead = new KLabel({ size: KIT_M.sideHead * 0.85, caps: true, fill: KIT_COLOUR.dim }, 'Notes');
  private readonly warnLines: KLabel[] = [];
  private readonly warnBox = new Container();

  // Along the bottom.
  private readonly stripBack = new Graphics();
  private readonly stripTitle = new KLabel({ size: KIT_M.stripTitle, caps: true, fill: KIT_COLOUR.text }, '');
  private readonly cardsBox = new ScrollBox('x');
  /** A tab's cards, each tab's in a row of its own: only the open tab's shown. */
  private readonly rows: { view: Container; cards: Card[]; options: readonly Option[] }[] = [];
  private readonly sizeRow = new Container();
  /** The sizes' panel: its plate and its heading. */
  private readonly sizeBack = new Graphics();
  private readonly sizeHead = new KLabel({ size: KIT_M.sideHead, caps: true, fill: KIT_COLOUR.text }, '');
  private readonly sizeCards: SizeCard[] = [];
  private readonly noteBack = new Graphics();
  private readonly note = new KLabel({ size: KIT_M.note, fill: KIT_COLOUR.text }, '');
  private readonly race: RaceButton;

  private readonly choice: Choice = { ...STARTER };
  private readonly rating: Rating = newRating();
  private shown = '';
  /** The kart the build shown is read from. */
  private kart = -1;
  private units: Units | null = null;

  constructor() {
    this.topBack.eventMode = 'static';
    this.stripBack.eventMode = 'static';
    this.sideBack.eventMode = 'static';
    this.view.addChild(this.nextBack, this.nextDeco, this.nextMap, this.nextHead, this.nextName, this.nextRating, this.nextProgress, this.nextGolds, this.changeCourse.view, this.mapHit);
    // mcp: projectNone('opens the course detail: the course select's map buttons (course-map-N) do the same')
    new Pressable(this.mapHit, { id: 'garage-next-map', onPress: clicked(() => this.detail.show(this.course)), onState: () => {} });
    this.view.addChild(this.topBack, this.title, this.weight);

    TABS.forEach((t, i) => {
      const tab = new Tab(t.id, t.name, t.glyph, () => this.openTab(i));
      this.tabs.push(tab);
      this.view.addChild(tab.view);
    });

    this.view.addChild(this.bannerBack, this.banner);
    // (The kart's name banner over it is not shown: its card below and the note already name it.)
    this.bannerBack.visible = false;
    this.banner.visible = false;
    this.view.addChild(this.sideBack, this.sideHead, ...this.ratingNames, this.warnHead, this.warnBox);

    for (const t of TABS) {
      const row = new Container();
      const cards = t.options.map((o) => new Card(o.id, o.name, o.picture, () => this.pick(o)));
      if (cards.length) row.addChild(...cards.map((c) => c.view));
      this.rows.push({ view: row, cards, options: t.options });
      this.cardsBox.content.addChild(row);
    }
    SIZES.forEach((size, i) => {
      const card = new SizeCard(size.name, size.min, size.max, size.step, (to) => this.resize(i, to));
      this.sizeCards.push(card);
      this.sizeRow.addChild(card.view);
    });

    this.race = new RaceButton(() => {
      if (isOpen(this.course) && rulesBreak(this.rating) === '') orderRace(Order.tour);
    });
    // The sizes stand still beside the cards, which scroll on their own.
    this.view.addChild(this.stripBack, this.stripTitle, this.cardsBox.view, this.noteBack, this.note, this.race.view, this.sizeBack, this.sizeHead, this.sizeRow);
  }


  private openTab(i: number): void {
    if (i === this.open) return;
    this.open = i;
    this.cardsBox.top();
    const fitted = TABS[i]!.options.find((o) => o.chosen(this.choice));
    if (fitted) this.note.set(`${TABS[i]!.name}: ${fitted.name}${fitted.blurb ? `. ${fitted.blurb}` : ''}`);
    this.shown = '';
    this.refresh();
  }

  /** One size slid to `to` (its bar holds it to what it may be). */
  private resize(i: number, to: number): void {
    const size = SIZES[i]!;
    const least = size.key === 'frontSize' || size.key === 'rearSize' ? wheelSizeMin(this.choice.wheels) : size.min;
    if (to < least) to = least;
    if (to === this.choice[size.key]) return;
    this.choice[size.key] = to;
    setSlot(size.key, to);
    this.note.set(`${size.name}: ${to}%${to === least && least > size.min ? ` (as small as ${WHEELS[this.choice.wheels]!.name.toLowerCase()} go)` : ''}`);
    const now = performance.now() / 1000;
    if (now - tickAt > TICK_GAP) {
      tickAt = now;
      workshop('tick', TICK_VOLUME);
    }
    this.refresh();
  }

  /** A card pressed: the slots it sets, set (a body, its chassis too). */
  private pick(o: Option): void {
    if (o.unlock > wins()) {
      workshop('denied', 0.7);
      this.note.set(`${o.name}: locked. Win ${o.unlock} course${o.unlock === 1 ? '' : 's'} to unlock it.`);
      return;
    }
    const changes = o.set(this.choice);
    for (const key of Object.keys(changes) as Slot[]) {
      const to = changes[key]!;
      this.choice[key] = to;
      setSlot(key, to);
    }
    // Wheels that go no smaller than some size: the ends sized below it brought up to it.
    const least = wheelSizeMin(this.choice.wheels);
    for (const key of ['frontSize', 'rearSize'] as const) {
      if (this.choice[key] < least) {
        this.choice[key] = least;
        setSlot(key, least);
      }
    }
    this.note.set(`${o.name}: ${o.blurb}`);
    workshop(FIT_SOUNDS[this.open] ?? 'clunk', FIT_VOLUME);
    this.refresh();
  }

  /**
   * Shown in the garage only; the build read from the kart as it is -- each time the garage opens, and
   * whenever the kart is another (a scene loaded, the game rebuilt), so it never shows a build of before.
   */
  setVisible(on: boolean, kart: number): void {
    if (on && (!this.view.visible || kart !== this.kart)) {
      this.kart = kart;
      readBuild(this.choice);
      this.course = currentCourse();
      this.shown = '';
      this.cardsBox.top();
      this.refresh();
    }
    this.view.visible = on;
  }

  private refresh(): void {
    const won = wins();
    rate(this.choice, this.rating);
    const r = this.rating;
    const key = `${SLOT_KEYS.map((k) => this.choice[k]).join()}:${SIZES.map((s) => this.choice[s.key]).join()}:${this.course}:${isOpen(this.course)}:${this.open}:${currentWeather()}:${won}`;
    if (key === this.shown) return;
    this.shown = key;
    this.tabs.forEach((tab, i) => tab.choose(i === this.open));
    this.rows.forEach((row, i) => {
      row.view.visible = i === this.open;
      row.cards.forEach((card, j) => {
        const o = row.options[j]!;
        card.choose(o.chosen(this.choice));
        card.lock(o.unlock > won, o.unlock);
      });
    });
    const sizes = TABS[this.open]!.sizes;
    this.sizeCards.forEach((c, i) => (c.view.visible = sizes.includes(i)));
    SIZES.forEach((size, i) => this.sizeCards[i]!.set(this.choice[size.key]));
    this.stripTitle.set(TABS[this.open]!.name);

    // The next race: this course, and the player's progress through them all.
    this.nextName.set(COURSES[this.course]!.name);
    const level = difficultyOf(this.course);
    this.nextRating.set(DIFFICULTIES[level]);
    this.nextRating.restyle({ fill: DIFFICULTY_COLOURS[level] });
    let done = 0, golds = 0;
    for (let c = 0; c < COURSES.length; c++) {
      const medal = bestMedal(c);
      if (medal != null) done++;
      if (medal === 0) golds++;
    }
    this.nextProgress.set(`${done} / ${COURSES.length} complete  ·`);
    this.nextGolds.set(`  ${golds} gold`);
    this.nextShownFor = -1;

    const open = isOpen(this.course);
    const empty = Math.round(emptyMass(r));
    this.weight.set(`${empty} / ${WEIGHT_LIMIT} kg`);
    this.weight.restyle({ fill: empty > WEIGHT_LIMIT ? KARTY_COLOUR.bad : KIT_COLOUR.text });

    const body = BODY[this.choice.body]!;
    this.banner.set(this.choice.body > 0 ? body.name : SLOTS[0].parts[this.choice.chassis]!.name);

    // The warnings: a line each, made as many as are wanted.
    const lines = r.warnings.length ? r.warnings : ['None'];
    while (this.warnLines.length < lines.length) {
      const l = new KLabel({ size: KIT_M.sideText, fill: KIT_COLOUR.text }, '');
      this.warnLines.push(l);
      this.warnBox.addChild(l);
    }
    this.warnLines.forEach((l, i) => {
      l.visible = i < lines.length;
      if (i < lines.length) l.set(lines[i]!);
      l.restyle({ fill: r.warnings.length ? KIT_COLOUR.text : KIT_COLOUR.dim });
    });

    const broken = rulesBreak(r);
    this.race.set(!open ? 'Locked' : broken || 'Race!', open && broken === '', open && broken !== '');
    if (this.units) this.layout(this.units);
  }

  /** Laid out at the menus' unit: the bars across the top and bottom, the tabs and the ratings either side of the kart. */
  layout(units: Units): void {
    this.units = units;
    this.detail.layout(units);
    this.view.addChild(this.detail.view);   // (on top of everything)
    if (phoneSized(units)) {
      this.layoutPhone(units);
      return;
    }
    this.title.visible = true;
    this.stripTitle.visible = true;
    const { m, safe, width, height } = units;
    const pad = KIT_M.pad * m;
    const left = Math.max(pad, safe.left);
    const right = width - Math.max(pad, safe.right);
    const topH = KIT_M.topBar * m + safe.top;
    const stripH = KIT_M.strip * m;
    const stripY = height - Math.max(0, safe.bottom) - stripH;
    // Clear of the pause and sound buttons, top right (the HUD's, in u).
    const keep = (SCREEN_U.button * 2 + SCREEN_U.buttonGap + SIZE_U.inset) * units.u;
    this.layoutTop(m, left, Math.max(left, width - Math.max(keep, safe.right)), safe.top, topH);
    const sideW = Math.min(KIT_M.side * m, (right - left) * 0.34);
    const tabW = Math.min(KIT_M.tabW * m, (right - left) * 0.24);
    const bodyTop = topH + pad;
    const bodyBottom = stripY - pad - KIT_M.note * m * 2.2;
    this.layoutTabs(m, left, bodyTop, tabW, bodyBottom);
    const sideEnd = this.layoutSide(m, right - sideW, bodyTop, sideW, bodyBottom);
    this.layoutSizes(m, right - sideW, sideEnd + pad, sideW, bodyBottom);
    this.layoutBanner(m, left + tabW + pad, right - sideW - pad, bodyTop);
    this.layoutStrip(m, left, right, stripY, stripH, height);
  }

  /**
   * On a phone, either way up: everything at least a finger high, the kart's name and its parts big enough to read.
   *  - Upright: the title along the top; the tabs in a row across under it (the open one with its name, the others
   *    their glyphs); how it drives and, beside it, the open tab's sizes (or the next race); the kart's name; along the
   *    bottom the parts, scrolling across, and under them Change course and Race!.
   *  - On its side: the tabs across the top bar (no title: no room); the next race (or the sizes) down the left, how it
   *    drives down the right, the kart between them; along the bottom the parts, and Race! with Change course under it
   *    at their right.
   */
  private layoutPhone(units: Units): void {
    const { m, safe, width, height } = units;
    const pad = KIT_M.pad * m;
    const gap = KIT_M.tabGap * m;
    const floor = touchFloor();
    const left = Math.max(pad, safe.left);
    const right = width - Math.max(pad, safe.right);
    const bottom = height - Math.max(pad, safe.bottom);
    const upright = height > width;
    // Clear of the pause and sound buttons, top right (the HUD's, in u).
    const keep = (SCREEN_U.button * 2 + SCREEN_U.buttonGap + SIZE_U.inset * 2) * units.u;
    const keepRight = Math.max(left, width - Math.max(keep, safe.right));
    const tabH = Math.max(KIT_M.tabMin * m, floor);
    let bodyTop: number;
    if (upright) {
      const topH = Math.max(KIT_M.topBar * m, SCREEN_U.button * units.u + SIZE_U.inset * units.u * 2) + safe.top;
      this.layoutTop(m, left, keepRight, safe.top, topH);
      this.layoutTabRow(m, left, right, topH + gap, tabH);
      bodyTop = topH + gap + tabH + pad;
    } else {
      const topH = tabH + gap * 2 + safe.top;
      this.layoutTop(m, left, keepRight, safe.top, topH, false);
      this.layoutTabRow(m, left, keepRight - pad, safe.top + gap, tabH);
      bodyTop = topH + pad;
    }
    this.stripTitle.visible = false;

    // Along the bottom: the parts, Race! and Change course.
    this.changeCourse.layout(m * NEXT_BUTTON);
    this.changeCourse.view.visible = true;
    const bar = KARTY_M.scrollBar * m * 0.7;
    const cardH = KIT_M.cardH * m * (upright ? 1 : PHONE_CARDS);
    const boxH = cardH + bar * (1 + KARTY_M.scrollGap);
    let stripY: number, boxX: number, boxY: number, boxW: number;
    let divX = -1;
    if (upright) {
      // Change course and Race! in a row under the parts.
      const raceH = Math.max(KIT_M.raceH * m * PHONE_RACE, floor);
      const raceY = bottom - raceH;
      const changeW = this.changeCourse.width;
      this.changeCourse.view.position.set(left, raceY + (raceH - this.changeCourse.height) / 2);
      this.race.layout(m, right - left - changeW - pad, raceH);
      this.race.view.position.set(left + changeW + pad, raceY);
      boxX = left;
      boxW = right - left;
      boxY = raceY - pad - boxH;
      stripY = boxY - pad * 0.8;
    } else {
      // Race! at the parts' right, Change course under it.
      stripY = bottom - boxH - pad * 0.6;
      const raceW = Math.min(KIT_M.raceW * m, (right - left) * PHONE_RACE_W);
      const changeH = this.changeCourse.height + SCREEN_M.buttonSink * m * NEXT_BUTTON;
      const raceH = Math.max(floor, bottom - stripY - pad * 0.6 - changeH - gap);
      this.race.layout(m, raceW, raceH);
      this.race.view.position.set(right - raceW, stripY + pad * 0.6);
      this.changeCourse.view.position.set(right - raceW + (raceW - this.changeCourse.width) / 2, stripY + pad * 0.6 + raceH + gap);
      boxX = left;
      boxW = right - raceW - pad * 1.2 - boxX;
      divX = right - raceW - pad * 0.6;
      boxY = stripY + pad * 0.6;
    }
    const g = this.stripBack.clear();
    g.rect(0, stripY, width + 1, height - stripY + 1).fill({ color: KIT_COLOUR.bar, alpha: KIT_ALPHA.bar });
    g.rect(0, stripY, width + 1, Math.max(1, KIT_M.edge * m)).fill(KIT_COLOUR.edgeDim);
    if (divX >= 0) divider(g, divX, stripY + pad, height - stripY - pad * 2, m);
    this.placeCards(m, boxX, boxY, boxW, boxH, bar, cardH);
    // The note over the parts upright, room kept for it under the panels; on its side, between the panels.
    const colW = upright ? (right - left - pad) / 2 : Math.min(KIT_M.side * m, (right - left) * PHONE_SIDE);
    if (upright) this.placeNote(m, boxX, boxW, stripY - pad * 0.5);
    else this.placeNote(m, left + colW + pad, right - left - (colW + pad) * 2, stripY - pad * 0.5);
    const middle = upright ? stripY - pad - KIT_M.note * m * 2.2 : stripY - pad * 0.6;
    // (Over the strip, which it sits in; the course's detail still over everything.)
    this.view.addChild(this.changeCourse.view, this.detail.view);

    // The middle: how it drives, and the sizes or the next race beside it.
    const sizes = TABS[this.open]!.sizes.length > 0;
    const statsW = colW * PHONE_STATS_W;
    const sideX = upright ? left : right - statsW;
    const sideEnd = this.layoutSide(m * PHONE_STATS, sideX, bodyTop, statsW, middle, true);
    const otherX = upright ? left + colW + pad : left;
    this.layoutSizes(m, otherX, bodyTop, colW, middle);
    this.layoutNext(m, otherX, bodyTop, colW, sizes ? bodyTop : middle, false);
    const otherEnd = sizes ? this.sizeEnd : this.nextEnd;
    // The kart's name: upright, under the shorter panel (the kart seen past the panels); on its side, between them.
    if (upright) {
      const under = otherEnd <= sideEnd;
      this.layoutBanner(m, under ? otherX : sideX, under ? otherX + colW : sideX + statsW, Math.min(sideEnd, otherEnd));
    }
    else this.layoutBanner(m, left + colW + pad, right - colW - pad, bodyTop - KIT_M.space * m);
  }

  /** The tabs in a row across, from `x0` to `x1`, `h` high: evenly where every one has room for its name; else the
   * open one with its name, the others their glyphs alone. */
  private layoutTabRow(m: number, x0: number, x1: number, y: number, h: number): void {
    const n = this.tabs.length;
    const gap = KIT_M.tabGap * m * 0.6;
    const room = x1 - x0 - gap * (n - 1);
    const even = room / n;
    const narrow = Math.max(h * KIT_M.arrowShape, Math.min(even, KIT_M.tabMin * m * 2));
    const wide = even >= KIT_M.tabW * m * TAB_ROW_EVEN;
    let x = x0;
    this.tabs.forEach((tab, i) => {
      const w = wide ? even : i === this.open ? room - narrow * (n - 1) : narrow;
      tab.layout(m, w, h, false);
      tab.view.position.set(x, y);
      x += w + gap;
    });
  }

  private layoutTop(m: number, left: number, right: number, safeTop: number, topH: number, titled = true): void {
    const g = this.topBack.clear();
    g.rect(0, 0, (this.units?.width ?? right) + 1, topH).fill({ color: KIT_COLOUR.bar, alpha: KIT_ALPHA.bar });
    g.rect(0, topH - Math.max(1, KIT_M.edge * m), (this.units?.width ?? right) + 1, Math.max(1, KIT_M.edge * m)).fill(KIT_COLOUR.edgeDim);
    this.title.visible = titled;
    if (!titled) {
      this.weight.visible = false;
      return;
    }
    const rowH = topH - safeTop;
    const mid = safeTop + rowH / 2;
    const room = KIT_M.topRoom * m;

    // The title: a flag, the words, an orange bar under them.
    const cell = KIT_M.check * m;
    flag(g, left, mid - (cell * KIT_M.flagRows) / 2, cell, KIT_M.flagCols, KIT_M.flagRows, KIT_COLOUR.hot);
    let x = left + cell * (KIT_M.flagCols + 1.5);
    this.title.restyle({ size: KIT_M.title * m });
    this.title.position.set(x, mid - this.title.lineBox.height / 2 - rowH * 0.04);
    slant(g, x - cell, this.title.y + this.title.lineBox.height * 0.96, this.title.lineBox.width + cell * 1.5, Math.max(2, KIT_M.meterThick * m * 0.7), KIT_COLOUR.hot);
    x += this.title.lineBox.width + room;

    // The weight: its icon big at the left, the kilos over a thick meter beside it -- in the top middle of the frame,
    // when it clears the title and the buttons. The meter green, gold near the limit, red over it.
    this.weight.restyle({ size: KIT_M.topText * m * 0.8 });
    const meterW = KIT_M.meter * m;
    const icon = KIT_M.topText * m * WEIGHT_ICON;
    const thick = KIT_M.meterThick * m * WEIGHT_BAR;
    const textX = icon * 1.25;
    const weightW = textX + Math.max(meterW, this.weight.lineBox.width);
    const centre = (this.units?.width ?? right) / 2;
    x = Math.max(x + room, centre - weightW / 2);
    const showWeight = x + weightW <= right;
    this.weight.visible = showWeight;
    if (showWeight) {
      const blockH = this.weight.lineBox.height + thick * 1.6;
      const top = mid - blockH / 2;
      glyph(g, 'weight', x, mid - icon / 2, icon, KIT_COLOUR.text);
      this.weight.position.set(x + textX, top);
      const load = emptyMass(this.rating) / WEIGHT_LIMIT;
      const colour = load > 1.006 ? KARTY_COLOUR.bad : load > WEIGHT_NEAR ? KARTY_COLOUR.gold : KIT_COLOUR.good;
      meter(g, x + textX, top + this.weight.lineBox.height + thick * 0.6, weightW - textX, thick, load, colour);
    }
  }

  private layoutTabs(m: number, x: number, top: number, w: number, bottom: number): void {
    const gap = KIT_M.tabGap * m;
    const n = this.tabs.length;
    const h = Math.max(KIT_M.tabMin * m, Math.min(KIT_M.tabH * m, (bottom - top - gap * (n - 1)) / n));
    const step = Math.min(h + gap, (bottom - top) / n);
    this.tabs.forEach((tab, i) => {
      tab.layout(m, w, Math.min(h, step - gap * 0.5));
      tab.view.position.set(x, top + i * step);
    });
    this.layoutNext(m, x, top + n * step + gap * 1.5, Math.max(w * 1.25, NEXT_W * m), bottom);
  }

  /** The next race's panel, under the tabs, when there is room: a plate, its heading flagged and underlined, the
   * course's map beside its name, a rule, the progress. */
  private layoutNext(m: number, x: number, top: number, w: number, bottom: number, withButton = true): void {
    // Stacked where it fits (a full-width map); else the map beside the name, as on a phone.
    if (withButton) {
      this.layoutNextStacked(m, x, top, w, bottom);
      if (this.nextEnd > top) return;
    }
    const pad = KIT_M.platePad * m;
    // (On a phone -- no button -- its map narrower in a narrow panel, to leave its name room.)
    const mapW = withButton ? NEXT_MAP * m : Math.min(NEXT_MAP * m, (w - pad * 3) * NEXT_MAP_SHARE);
    this.nextHead.restyle({ size: KIT_M.sideHead * m });
    this.nextName.restyle({ size: KIT_M.sideText * m, wrap: w - pad * 3 - mapW });
    this.nextRating.restyle({ size: KIT_M.sideText * m * 0.85 });
    this.nextProgress.restyle({ size: KIT_M.sideText * m });
    this.nextGolds.restyle({ size: KIT_M.sideText * m });
    const mapH = NEXT_MAP * m * 0.62;
    const headH = this.nextHead.lineBox.height + KIT_M.edge * m * 3;
    this.changeCourse.layout(m * NEXT_BUTTON);
    const button = withButton ? this.changeCourse.height + SCREEN_M.buttonSink * m * NEXT_BUTTON + pad * 0.8 : pad * 0.2;
    const h = pad + headH + pad * 0.6 + Math.max(mapH, this.nextName.lineBox.height) + pad * 0.8 + this.nextProgress.lineBox.height + pad * 0.6 + button;
    const fits = top + h <= bottom;
    for (const v of [this.nextBack, this.nextDeco, this.nextMap, this.nextHead, this.nextName, this.nextRating, this.nextProgress, this.nextGolds, this.mapHit]) v.visible = fits;
    if (withButton) this.changeCourse.view.visible = fits;
    this.nextEnd = fits ? top + h : top;
    if (!fits) return;
    plate(this.nextBack.clear(), x, top, w, h, m);
    const d = this.nextDeco.clear();
    let y = top + pad * 0.8;
    placeHeading(d, this.nextHead, x + (w - headingWidth(this.nextHead, KIT_M.check * m, KIT_M.space * m)) / 2, y, KIT_M.check * m, KIT_M.space * m, KIT_M.edge * m * 1.4, -KIT_M.edge * m);
    y += headH + pad * 0.6;
    if (this.nextShownFor !== this.course || this.nextMapAt !== `${x},${y},${m}`) {
      drawMap(this.nextMap, this.course, x + pad, y, mapW, mapH, m);
      this.nextShownFor = this.course;
      this.nextMapAt = `${x},${y},${m}`;
    }
    this.mapHit.hitArea = new Rectangle(x + pad, y, mapW, mapH);
    const nameH = this.nextName.lineBox.height + this.nextRating.lineBox.height;
    this.nextName.position.set(x + pad * 2 + mapW, y + (mapH - nameH) / 2);
    this.nextRating.position.set(x + pad * 2 + mapW, this.nextName.y + this.nextName.lineBox.height);
    y += Math.max(mapH, this.nextName.lineBox.height) + pad * 0.4;
    d.rect(x + pad, y, w - pad * 2, Math.max(1, KIT_M.edge * m * 0.5)).fill(KIT_COLOUR.edgeDim);
    y += pad * 0.4;
    this.nextProgress.position.set(x + (w - this.nextProgress.lineBox.width - this.nextGolds.lineBox.width) / 2, y);
    this.nextGolds.position.set(this.nextProgress.x + this.nextProgress.lineBox.width, y);
    y += this.nextProgress.lineBox.height + pad * 0.6;
    if (withButton) this.changeCourse.view.position.set(x + (w - this.changeCourse.width) / 2, y);
  }

  /** The next race, stacked down its panel: the heading, the course's name under it, its map the panel's width, the
   * progress (the golds in gold), and Change course. */
  private layoutNextStacked(m: number, x: number, top: number, w: number, bottom: number): void {
    const pad = KIT_M.platePad * m;
    const inner = w - pad * 2;
    this.nextHead.restyle({ size: KIT_M.sideHead * m });
    this.nextName.restyle({ size: KIT_M.sideText * m, wrap: inner });
    this.nextRating.restyle({ size: KIT_M.sideText * m * 0.85 });
    this.nextProgress.restyle({ size: KIT_M.sideText * m });
    this.nextGolds.restyle({ size: KIT_M.sideText * m });
    const mapW = inner;
    const mapH = mapW * NEXT_MAP_TALL;
    const headH = this.nextHead.lineBox.height + KIT_M.edge * m * 3;
    this.changeCourse.layout(m * NEXT_BUTTON);
    const button = this.changeCourse.height + SCREEN_M.buttonSink * m * NEXT_BUTTON;
    const h = pad * 0.8 + headH + pad * 0.3 + this.nextName.lineBox.height + this.nextRating.lineBox.height + pad * 0.5 + mapH + pad * 0.6
      + this.nextProgress.lineBox.height + pad * 0.7 + button + pad * 0.8;
    const fits = top + h <= bottom;
    for (const v of [this.nextBack, this.nextDeco, this.nextMap, this.nextHead, this.nextName, this.nextRating, this.nextProgress, this.nextGolds, this.mapHit]) v.visible = fits;
    this.changeCourse.view.visible = fits;
    this.nextEnd = fits ? top + h : top;
    if (!fits) return;
    plate(this.nextBack.clear(), x, top, w, h, m);
    const d = this.nextDeco.clear();
    let y = top + pad * 0.8;
    placeHeading(d, this.nextHead, x + (w - headingWidth(this.nextHead, KIT_M.check * m, KIT_M.space * m)) / 2, y, KIT_M.check * m, KIT_M.space * m, KIT_M.edge * m * 1.4, -KIT_M.edge * m);
    y += headH + pad * 0.3;
    this.nextName.position.set(x + (w - this.nextName.lineBox.width) / 2, y);
    y += this.nextName.lineBox.height;
    this.nextRating.position.set(x + (w - this.nextRating.lineBox.width) / 2, y);
    y += this.nextRating.lineBox.height + pad * 0.5;
    if (this.nextShownFor !== this.course || this.nextMapAt !== `${x},${y},${m},${mapW}`) {
      drawMap(this.nextMap, this.course, x + pad, y, mapW, mapH, m);
      this.nextShownFor = this.course;
      this.nextMapAt = `${x},${y},${m},${mapW}`;
    }
    this.mapHit.hitArea = new Rectangle(x + pad, y, mapW, mapH);
    y += mapH + pad * 0.6;
    this.nextProgress.position.set(x + (w - this.nextProgress.lineBox.width - this.nextGolds.lineBox.width) / 2, y);
    this.nextGolds.position.set(this.nextProgress.x + this.nextProgress.lineBox.width, y);
    y += this.nextProgress.lineBox.height + pad * 0.7;
    this.changeCourse.view.position.set(x + (w - this.changeCourse.width) / 2, y);
  }

  /** The open tab's sizes, in a panel under how it drives: its heading (the tab's: SIZE_HEADS), a row each -- when
   * the tab has any and there is room. */
  private layoutSizes(m: number, x: number, top: number, w: number, bottom: number): void {
    const sizes = TABS[this.open]!.sizes;
    const pad = KIT_M.platePad * m;
    this.sizeHead.set(SIZE_HEADS[TABS[this.open]!.id] ?? 'Sizes');
    this.sizeHead.restyle({ size: KIT_M.sideHead * m });
    const rowH = SizeCard.height(m);
    const headH = this.sizeHead.lineBox.height + pad * 0.5;
    const h = pad + headH + pad * 0.5 + sizes.length * (rowH + pad * 0.5) + pad * 0.5;
    const fits = sizes.length > 0 && top + h <= bottom;
    this.sizeRow.visible = fits;
    this.sizeHead.visible = fits;
    this.sizeEnd = fits ? top + h : top;
    const g = this.sizeBack.clear();
    if (!fits) return;
    plate(g, x, top, w, h, m);
    this.sizeHead.position.set(x + pad, top + pad);
    g.rect(x + pad, top + pad + headH, w - pad * 2, Math.max(1, KIT_M.edge * m)).fill(KIT_COLOUR.edge);
    this.sizeRow.position.set(x + pad, top + pad + headH + pad);
    this.sizeCards.forEach((c, i) => (c.view.visible = sizes.includes(i)));
    sizes.forEach((si, n) => {
      const c = this.sizeCards[si]!;
      c.layout(m, w - pad * 2, rowH);
      c.view.position.set(0, n * (rowH + pad * 0.5));
    });
  }

  /** How it drives, on the right: answers where its plate ends. */
  private layoutSide(m: number, x: number, top: number, w: number, bottom: number, compact = false): number {
    const pad = KIT_M.platePad * m;
    const g = this.sideBack.clear();
    let y = top + pad;
    // (Compact, on a phone: no heading -- the ratings say what it is -- to save the room.)
    this.sideHead.visible = !compact;
    this.sideHead.restyle({ size: KIT_M.sideHead * m });
    this.sideHead.position.set(x + pad, y);
    if (!compact) y += this.sideHead.lineBox.height + pad * 0.5;
    const ruleY = y;
    if (!compact) y += pad * 0.7;

    // The ratings: a name, a bar to the right edge.
    let nameW = 0;
    for (const l of this.ratingNames) {
      l.restyle({ size: KIT_M.sideText * m });
      nameW = Math.max(nameW, l.lineBox.width);
    }
    // (Compact, on a phone: the rows only as high as their words, to leave the warnings room.)
    const rowH = compact ? this.ratingNames[0]!.lineBox.height * 1.2 : Math.max(KIT_M.sideRow * m, this.ratingNames[0]!.lineBox.height * 1.25);
    const barX = x + pad + nameW + pad;
    const barW = Math.max(KIT_M.sideBar * m * 4, x + w - pad - barX);
    const thick = KIT_M.sideBar * m;
    const bars: [number, number][] = [];
    RATINGS.forEach(([, field], i) => {
      const l = this.ratingNames[i]!;
      l.position.set(x + pad, y + (rowH - l.lineBox.height) / 2);
      bars.push([y + (rowH - thick) / 2, Math.max(0, Math.min(1, this.rating[field] / 5))]);
      y += rowH;
    });
    y += pad * 0.4;
    const rule2Y = y;
    y += pad * 0.8;

    // Its notes (the build's warnings, put quietly): a heading, then a line each with a dot before it.
    this.warnHead.restyle({ size: KIT_M.sideHead * m * 0.85 });
    this.warnHead.position.set(x + pad, y);
    // (No room for even the heading, a short frame's: the warnings left out.)
    const warned = y + this.warnHead.lineBox.height <= bottom - pad * 0.5;
    this.warnHead.visible = warned;
    y += this.warnHead.lineBox.height + pad * 0.5;
    const bullets: number[] = [];
    const wrap = w - pad * 2 - KIT_M.sideText * m;
    for (const l of this.warnLines) {
      if (!l.visible) continue;
      l.restyle({ size: KIT_M.sideText * m, wrap });
      // (A line that would run off the plate's foot left out: a short frame, a phone's.)
      l.renderable = y + l.lineBox.height <= bottom - pad * 0.5;
      if (!l.renderable) continue;
      l.position.set(x + pad + KIT_M.sideText * m, y);
      bullets.push(y + Math.min(l.lineBox.height, KIT_M.sideText * m * 1.2) / 2);
      y += l.lineBox.height + pad * 0.3;
    }
    y += pad * 0.7;

    const h = Math.min(y, bottom) - top;
    plate(g, x, top, w, h, m);
    // Drawn over the plate: redraw what was drawn before it.
    if (!compact) g.rect(x + pad, ruleY, w - pad * 2, Math.max(1, KIT_M.edge * m)).fill(KIT_COLOUR.edge);
    g.rect(x + pad, rule2Y, w - pad * 2, Math.max(1, KIT_M.edge * m)).fill(KIT_COLOUR.edgeDim);
    for (const [by, share] of bars) meter(g, barX, by, barW, thick, share, share < 0.3 ? KARTY_COLOUR.bad : KIT_COLOUR.good);
    const dot = KIT_M.sideText * m * 0.14;
    for (const by of bullets) g.circle(x + pad + dot * 1.6, by, dot).fill(KIT_COLOUR.dim);
    return top + h;
  }

  private layoutBanner(m: number, from: number, to: number, top: number): void {
    const g = this.bannerBack.clear();
    const room = to - from;
    // (Smaller than the screens' headings: the kart's name, not a title.)
    let size = KIT_M.banner * m * BANNER_SCALE;
    for (let i = 0; i < 8; i++) {
      this.banner.restyle({ size });
      if (this.banner.lineBox.width + KIT_M.bannerPad * m * 2 + KIT_M.check * m * KIT_M.flagCols * 2 <= room) break;
      size *= 0.88;
    }
    const pad = KIT_M.bannerPad * m;
    const h = this.banner.lineBox.height * 1.15;
    const w = this.banner.lineBox.width + pad * 2;
    const cell = KIT_M.check * m * 1.4;
    const flagW = cell * KIT_M.flagCols;
    const x = from + (room - w - flagW) / 2;
    const y = top + KIT_M.space * m;
    slant(g, x, y, w, h, KIT_COLOUR.bar, KIT_COLOUR.text, Math.max(1.5, KIT_M.edge * m * 1.6));
    flag(g, x + w + cell * 0.2, y + (h - cell * KIT_M.flagRows) / 2, cell, KIT_M.flagCols, KIT_M.flagRows, KIT_COLOUR.hot);
    this.banner.position.set(x + pad, y + (h - this.banner.lineBox.height) / 2);
  }

  private layoutStrip(m: number, left: number, right: number, y: number, h: number, frameH: number): void {
    const g = this.stripBack.clear();
    const fullW = (this.units?.width ?? right) + 1;
    g.rect(0, y, fullW, frameH - y + 1).fill({ color: KIT_COLOUR.bar, alpha: KIT_ALPHA.bar });
    g.rect(0, y, fullW, Math.max(1, KIT_M.edge * m)).fill(KIT_COLOUR.edgeDim);
    const pad = KIT_M.pad * m;

    // The slot's name, a grey flag under it.
    const titleW = Math.min(KIT_M.stripTitleW * m, (right - left) * 0.16);
    let size = KIT_M.stripTitle * m;
    for (let i = 0; i < 8; i++) {
      this.stripTitle.restyle({ size });
      if (this.stripTitle.lineBox.width <= titleW) break;
      size *= 0.9;
    }
    const cell = KIT_M.check * m;
    const blockH = this.stripTitle.lineBox.height + cell * 3.4;
    this.stripTitle.position.set(left, y + (h - blockH) / 2);
    flag(g, left, this.stripTitle.y + this.stripTitle.lineBox.height + cell * 0.6, cell, KIT_M.flagCols + 3, 2, KIT_COLOUR.edge, KIT_COLOUR.bar);

    // Race!, on the right, a divider before it.
    const raceW = Math.min(KIT_M.raceW * m, (right - left) * 0.24);
    const raceH = Math.min(KIT_M.raceH * m, h - pad * 2);
    this.race.layout(m, raceW, raceH);
    this.race.view.position.set(right - raceW, y + (h - raceH) / 2);
    divider(g, right - raceW - pad * 1.2, y + pad, h - pad * 2, m);

    // Between: the cards, scrolling across.
    const boxX = left + titleW + pad;
    const boxW = Math.max(KIT_M.cardW * m, right - raceW - pad * 2.4 - boxX);
    const bar = KARTY_M.scrollBar * m * 0.7;
    const boxH = h - pad;
    this.placeCards(m, boxX, y + pad * 0.6, boxW, boxH, bar, KIT_M.cardH * m);
    this.placeNote(m, boxX, boxW, y - pad * 0.5);
  }

  /** The open tab's cards in their scroll box at (x, y), `w` by `h` (its bar `bar` thick), each at most `cardMax` high. */
  private placeCards(m: number, x: number, y: number, w: number, h: number, bar: number, cardMax: number): void {
    const pad = KIT_M.pad * m;
    this.cardsBox.layout(w, h, bar);
    const cardH = Math.min(cardMax, this.cardsBox.inner - pad * 0.2);
    const cardW = Math.min(KIT_M.cardW * m, cardH * 1.1);
    const gap = KIT_M.cardGap * m;
    // The open tab's parts, scrolling (its sizes are in their own panel, on the right).
    this.cardsBox.view.position.set(x, y);
    const row = this.rows[this.open]!;
    row.cards.forEach((card, j) => {
      card.layout(m, cardW, cardH);
      card.view.position.set(j * (cardW + gap), 0);
    });
    this.cardsBox.fit(row.cards.length * (cardW + gap) - gap);
    // The card fitted kept in sight.
    const chosen = row.options.findIndex((o) => o.chosen(this.choice));
    if (chosen >= 0) this.cardsBox.show(chosen * (cardW + gap), chosen * (cardW + gap) + cardW);
  }

  /** The line about the part last picked, over the cards (`x` and `w` across), its foot at `foot`. */
  private placeNote(m: number, x: number, w: number, foot: number): void {
    const pad = KIT_M.pad * m;
    const ng = this.noteBack.clear();
    this.note.restyle({ size: KIT_M.note * m, wrap: Math.max(1, w) });
    const nw = this.note.lineBox.width + pad * 2;
    const nh = this.note.lineBox.height + pad * 0.6;
    const nx = x + (w - nw) / 2;
    const ny = foot - nh;
    if (this.note.text) ng.roundRect(nx, ny, nw, nh, nh / 2).fill({ color: KIT_COLOUR.bar, alpha: KIT_ALPHA.plate }).roundRect(nx, ny, nw, nh, nh / 2).stroke({ color: KIT_COLOUR.edgeDim, width: Math.max(1, KIT_M.edge * m) });
    this.note.position.set(nx + pad, ny + pad * 0.3);
  }

  /** Each frame while shown: a part's picture still waiting on its model tried again. */
  frame(): void {
    if (!this.view.visible) return;
    for (const card of this.rows[this.open]!.cards) card.retry();
  }
}
