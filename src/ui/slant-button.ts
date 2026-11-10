/**
 * The game's button: a rounded sticker, sunk into its shade when held. `hot` is the one to press -- bold green, white
 * italic caps, a chequered flag before its words, like the garage's RACE! -- and `plain` the others: cream, navy
 * words; both outlined navy. A `Pressable` with a look, as the engine's `PillButton` is, and the
 * same shape to use: `view`, `press`, `width`, `height`, `set`, `layout(m)`.
 */
import { Container, Graphics } from 'pixi.js';
import { Pressable, type ButtonState } from '@vibe/engine/ui';
import { flag, KLabel, slant, clicked } from './kit.ts';
import { KIT_COLOUR, KIT_M } from './karty-theme.ts';
import { flagWidth } from './screen-kit.ts';
import { SCREEN_ALPHA, SCREEN_M } from './screen-theme.ts';

export type SlantKind = 'hot' | 'plain';

/** The least height of anything pressed, CSS pixels: a finger's on a touch screen or a phone, else none. Set by the UI
 * hook (`index.ts`) before each layout; every button, row and tab of the game's screens is at least this high. */
let floor = 0;

export function setTouchFloor(px: number): void {
  floor = px;
}

export function touchFloor(): number {
  return floor;
}

export class SlantButton {
  readonly view: Container;
  readonly press: Pressable;
  private readonly bg = new Graphics();
  private readonly label: KLabel;
  private readonly kind: SlantKind;
  /** Words '‹' or '›': a bold drawn arrow instead (the font's are tiny), pointing that way. */
  private readonly arrow: -1 | 0 | 1;
  private m = 1;
  /** At least this wide (pixels): a column of buttons made one width. */
  minWidth = 0;

  constructor(id: string, words: string, onPress: () => void, kind: SlantKind = 'hot') {
    this.kind = kind;
    this.arrow = words === '‹' ? -1 : words === '›' ? 1 : 0;
    this.view = new Container({ label: id });
    this.label = new KLabel({ size: SCREEN_M.buttonText, caps: true, fill: kind === 'hot' ? KIT_COLOUR.ink : KIT_COLOUR.text }, words);
    this.view.addChild(this.bg, this.label);
    this.press = new Pressable(this.view, { id, onPress: clicked(onPress), onState: (state) => this.draw(state) });
  }

  private get lean(): number {
    return KIT_M.lean * this.height;
  }

  private get flagRoom(): number {
    const f = flagWidth(SCREEN_M.buttonCheck * this.m);
    return this.kind === 'hot' && f > 0 ? f + SCREEN_M.buttonGap * this.m * KIT_M.lean * 2 : 0;
  }

  /** Its size, the shade under it left out. */
  get width(): number {
    // An arrow: a square-ish button, its words (none) no matter.
    if (this.arrow !== 0) return Math.max(SCREEN_M.arrowW * this.m, this.height * KIT_M.arrowShape);
    return Math.max(this.minWidth, SCREEN_M.buttonMin * this.m, this.label.lineBox.width + this.flagRoom + SCREEN_M.buttonPadX * this.m * 2 + this.lean);
  }

  get height(): number {
    return Math.max(SCREEN_M.button * this.m, floor);
  }

  /** New words. Call `layout` after, if they change its width. */
  set(words: string): void {
    this.label.set(words);
  }

  /** Sized from the menus' unit (`units.m`). */
  layout(m: number): void {
    this.m = m;
    this.label.restyle({ size: SCREEN_M.buttonText * m });
    this.draw(this.press.states);
  }

  private draw(state: Readonly<ButtonState>): void {
    const m = this.m;
    const w = this.width;
    const h = this.height;
    const sink = SCREEN_M.buttonSink * m;
    const down = state.down ? sink : 0;
    const hot = this.kind === 'hot';
    const g = this.bg.clear();
    // The shade under it, which a press sinks into.
    slant(g, 0, sink, w, h, hot ? KIT_COLOUR.goDark : KIT_COLOUR.edge);
    const face = state.disabled ? KIT_COLOUR.groove : hot ? (state.hover ? KIT_COLOUR.goLight : KIT_COLOUR.go) : state.hover ? KIT_COLOUR.cardHover : KIT_COLOUR.card;
    slant(g, 0, down, w, h, face, KIT_COLOUR.edge, SCREEN_M.buttonEdge * m);
    const box = this.label.lineBox;
    const room = this.flagRoom;
    const left = (w - box.width - room) / 2;
    if (hot) {
      const cell = SCREEN_M.buttonCheck * m;
      flag(g, left, down + (h - cell * KIT_M.flagRows) / 2, cell, KIT_M.flagCols, KIT_M.flagRows, face, KIT_COLOUR.ink);
    }
    this.label.position.set(left + room, (h - box.height) / 2 + down);
    this.label.visible = this.arrow === 0;
    if (this.arrow !== 0) {
      // A chunky chevron in the middle, the words' colour, a little forward of centre the way it points.
      const cx = w / 2, cy = h / 2 + down, a = h * 0.22, d = this.arrow;
      g.poly([cx + d * a * 0.9, cy, cx - d * a * 0.5, cy - a, cx - d * a * 0.5, cy + a]).fill(hot ? KIT_COLOUR.ink : KIT_COLOUR.text);
    }
    this.view.alpha = state.down ? SCREEN_ALPHA.held : 1;
  }
}
