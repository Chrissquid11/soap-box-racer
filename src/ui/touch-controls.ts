/**
 * Touch controls, on a phone or a tablet only (a coarse pointer and touch: never on a PC with a mouse), one of two
 * kinds as the player chose (`touch-style.ts`, the pause menu's switch): a floating virtual D-pad -- a thumb down
 * anywhere on the screen puts it there, unseen between touches (up push (W),
 * down brake (S), left and right steer (A, D), a diagonal two at once), or big slanted buttons (the default) -- steer left and
 * right bottom middle; push and brake bottom right. Held, each holds its key down in the game's input (`game.loop.input.edge`), exactly as the keyboard
 * would: the simulation reads keys and nothing else, and a finger is one more way to press them. Several at once
 * (steer and push) work, a finger each. Shown from the countdown to the finish; never over the garage, the course
 * select or the results.
 */
import { Container, Graphics, Rectangle, type FederatedPointerEvent } from 'pixi.js';
import type { UiHook } from '@vibe/engine/boot';
import { Pressable, type ButtonState, type Units, type Widget } from '@vibe/engine/ui';
import { Kart, Phase } from '../game/components.ts';
import { KIT_COLOUR } from './karty-theme.ts';
import { KLabel, slant } from './kit.ts';
import { live } from './live.ts';
import { SCREEN_ALPHA, SCREEN_U } from './screen-theme.ts';
import { touchSensitivity, touchStyle, type TouchStyle } from './touch-style.ts';

/** The game the UI is made over (what `UiHook` is handed). */
type Game = Parameters<UiHook>[0];

/** Is this a touch device (a finger the main pointer)? A PC with a touch screen and a mouse keeps its keys.
 * (`?touch` on the address shows them anywhere, to try them with a mouse.) */
export function touchFirst(): boolean {
  try {
    if (new URLSearchParams(location.search).has('touch')) return true;
    return navigator.maxTouchPoints > 0 && matchMedia('(pointer: coarse)').matches;
  } catch {
    return false;
  }
}

type Shape = 'left' | 'right' | 'word';

/** One held button: its key, its shape (an arrow, or a word), its plate. */
class HoldButton {
  readonly view: Container;
  readonly press: Pressable;
  private readonly plate = new Graphics();
  private readonly mark = new Graphics();
  private readonly label: KLabel | null;
  private held = false;
  w = 0;
  h = 0;
  private readonly code: string;
  private readonly shape: Shape;
  private readonly game: Game;
  private readonly hot: boolean;

  constructor(id: string, code: string, shape: Shape, words: string, game: Game, hot = false) {
    this.code = code;
    this.shape = shape;
    this.game = game;
    this.hot = hot;
    this.view = new Container({ label: id });
    this.label = shape === 'word' ? new KLabel({ size: SCREEN_U.touchText, caps: true, fill: KIT_COLOUR.text }, words) : null;
    this.view.addChild(this.plate, this.mark);
    if (this.label) this.view.addChild(this.label);
    // (The Pressable claims the touch for the UI, so the game never also sees it as a click.)
    // mcp: projectNone('a touch-screen key: the keyboard's own keys do the same, and the playtest tools press those')
    this.press = new Pressable(this.view, { id, onPress: () => {}, onState: (_state: Readonly<ButtonState>) => this.draw() });
    // Held while any finger that came down on it is still down -- however far it drifts (a thumb on a steer button
    // wanders): a tap's rules, which let go past a few pixels, are not a held key's.
    this.view.on('pointerdown', (e) => this.finger(e.pointerId, true));
    for (const up of ['pointerup', 'pointerupoutside', 'pointercancel'] as const) this.view.on(up, (e) => this.finger(e.pointerId, false));
  }

  private readonly fingers = new Set<number>();

  private finger(id: number, down: boolean): void {
    if (down) this.fingers.add(id);
    else this.fingers.delete(id);
    const held = this.fingers.size > 0;
    if (held !== this.held) {
      this.held = held;
      this.game.loop.input.edge(this.code, held);
    }
    this.draw();
  }

  /** Let go (hidden mid-press): the key comes up. */
  release(): void {
    this.fingers.clear();
    if (!this.held) return;
    this.held = false;
    this.game.loop.input.edge(this.code, false);
    this.draw();
  }

  layout(w: number, h: number, u: number): void {
    this.w = w;
    this.h = h;
    this.label?.restyle({ size: SCREEN_U.touchText * u });
    this.draw();
  }

  private draw(): void {
    const { w, h } = this;
    const fill = this.held ? KIT_COLOUR.hotLight : this.hot ? KIT_COLOUR.hot : KIT_COLOUR.bar;
    const g = this.plate.clear();
    slant(g, 0, 0, w, h, fill, KIT_COLOUR.edge, Math.max(1, h * SCREEN_U.touchEdge));
    this.plate.alpha = this.held ? 1 : SCREEN_ALPHA.touch;
    const m = this.mark.clear();
    if (this.shape === 'left' || this.shape === 'right') {
      const s = Math.min(w, h) * 0.32, cx = w / 2, cy = h / 2, d = this.shape === 'left' ? -1 : 1;
      m.poly([cx + d * s, cy, cx - d * s * 0.7, cy - s, cx - d * s * 0.7, cy + s]).fill(KIT_COLOUR.text);
    }
    if (this.label) this.label.position.set((w - this.label.lineBox.width) / 2, (h - this.label.lineBox.height) / 2);
  }
}

/** The D-pad's four ways: their keys, and which way each points (x, y on the screen). */
const WAYS = [
  { code: 'KeyW', x: 0, y: -1 },
  { code: 'KeyS', x: 0, y: 1 },
  { code: 'KeyA', x: -1, y: 0 },
  { code: 'KeyD', x: 1, y: 0 },
] as const;
/** A way is pressed while the thumb is within this many degrees of it (past 45: a diagonal presses two). */
const WAY_COS = Math.cos((62 * Math.PI) / 180);

/** The virtual D-pad, floating: a thumb down anywhere on the screen (`catcher`, under the HUD's own buttons) brings it
 * there, centred under the thumb, and presses the way (or two ways) the thumb is pushed from its middle; it stays put
 * till the thumb lifts. Seen only while a thumb is on it: a faint ring and a knob under the thumb. */
class DPad {
  readonly view = new Container({ label: 'touch-dpad' });
  /** The whole screen: where a thumb going down starts the pad. */
  readonly catcher = new Container({ label: 'touch-dpad-catcher' });
  private homeX = 0;
  private homeY = 0;
  private readonly base = new Graphics();
  private readonly knob = new Graphics();
  private readonly game: Game;
  private readonly held = [false, false, false, false];
  private finger = -1;
  private r = 1;
  private kx = 0;
  private ky = 0;

  constructor(game: Game) {
    this.game = game;
    this.view.addChild(this.base, this.knob);
    this.base.visible = false;
    this.knob.visible = false;
    this.view.eventMode = 'none';
    // Interactive: a press on it is the UI's, never the game's.
    this.catcher.eventMode = 'static';
    this.catcher.on('pointerdown', (e) => {
      if (this.finger >= 0) return;
      this.finger = e.pointerId;
      // The pad under the thumb.
      const at = this.catcher.toLocal(e.global);
      this.view.position.set(at.x - this.r, at.y - this.r);
      this.base.visible = true;
      this.knob.visible = true;
      this.move(e);
    });
    // (Its own moves, not Pixi's global ones: the engine's UI turns those off. The catcher covers the screen, so every
    // move of the thumb is over it.)
    this.catcher.on('pointermove', (e) => {
      if (e.pointerId === this.finger) this.move(e);
    });
    for (const up of ['pointerup', 'pointerupoutside', 'pointercancel'] as const) {
      this.catcher.on(up, (e) => {
        if (e.pointerId === this.finger) this.release();
      });
    }
  }

  /** Thumbs taken (the run on) or not (a menu, the Start button up): the screen left to the rest. */
  active(on: boolean): void {
    this.catcher.eventMode = on ? 'static' : 'none';
    if (!on) this.release();
  }

  /** The screen it floats over, and where it rests (its top left). */
  cover(width: number, height: number, homeX: number, homeY: number): void {
    this.catcher.hitArea = new Rectangle(0, 0, width, height);
    this.homeX = homeX;
    this.homeY = homeY;
    if (this.finger < 0) this.view.position.set(homeX, homeY);
  }

  private move(e: FederatedPointerEvent): void {
    // The thumb from the pad's middle, in the screen's terms (the catcher never moves).
    const at = this.catcher.toLocal(e.global);
    // (It stays where the thumb came down till the thumb lifts: pushed past its rim, the knob waits on the rim.)
    const dx = at.x - (this.view.x + this.r), dy = at.y - (this.view.y + this.r);
    const d = Math.hypot(dx, dy);
    const far = Math.min(d, this.r * (1 - SCREEN_U.touchPadKnob));
    this.kx = d > 0 ? (dx / d) * far : 0;
    this.ky = d > 0 ? (dy / d) * far : 0;
    const live = d > this.r * SCREEN_U.touchPadDead[touchSensitivity()]!;
    for (let i = 0; i < WAYS.length; i++) this.set(i, live && (dx * WAYS[i]!.x + dy * WAYS[i]!.y) / d > WAY_COS);
    this.draw();
  }

  private set(i: number, on: boolean): void {
    if (this.held[i] === on) return;
    this.held[i] = on;
    this.game.loop.input.edge(WAYS[i]!.code, on);
  }

  /** Let go (the thumb up, or hidden mid-press): every way comes up. */
  release(): void {
    this.finger = -1;
    this.view.position.set(this.homeX, this.homeY);
    this.base.visible = false;
    this.knob.visible = false;
    for (let i = 0; i < WAYS.length; i++) this.set(i, false);
    this.kx = 0;
    this.ky = 0;
    this.draw();
  }

  get size(): number {
    return this.r * 2;
  }

  layout(across: number): void {
    this.r = across / 2;
    this.draw();
  }

  private draw(): void {
    const r = this.r;
    // A faint ring where the thumb came down, and a knob under the thumb (hot while it pushes).
    this.base.clear().circle(r, r, r)
      .fill({ color: KIT_COLOUR.shadow, alpha: SCREEN_ALPHA.padFill })
      .stroke({ color: KIT_COLOUR.light, alpha: SCREEN_ALPHA.padRing, width: Math.max(1, r * SCREEN_U.touchPadRing) });
    this.knob.clear().circle(r + this.kx, r + this.ky, r * SCREEN_U.touchPadKnob)
      .fill({ color: this.held[0] ? KIT_COLOUR.hot : KIT_COLOUR.light, alpha: SCREEN_ALPHA.padKnob });
  }
}

export class TouchControls implements Widget {
  readonly id = 'touch-controls';
  readonly view = new Container({ label: 'touch-controls' });
  private readonly left: HoldButton;
  private readonly right: HoldButton;
  private readonly push: HoldButton;
  private readonly brake: HoldButton;
  private readonly all: HoldButton[];
  private readonly buttons = new Container({ label: 'touch-buttons' });
  private readonly pad: DPad;
  private readonly touch = touchFirst();
  private style: TouchStyle = touchStyle();
  /** Whether the floating pad takes touches now. */
  private takes = true;

  constructor(game: Game) {
    this.left = new HoldButton('touch-left', 'KeyA', 'left', '', game);
    this.right = new HoldButton('touch-right', 'KeyD', 'right', '', game);
    this.push = new HoldButton('touch-push', 'KeyW', 'word', 'Push', game, true);
    this.brake = new HoldButton('touch-brake', 'KeyS', 'word', 'Brake', game);
    this.all = [this.left, this.right, this.push, this.brake];
    for (const b of this.all) this.buttons.addChild(b.view);
    this.pad = new DPad(game);
    this.view.addChild(this.buttons, this.pad.catcher, this.pad.view);
    this.showStyle();
    this.view.visible = false;
  }

  /** Shown on a touch device from the countdown through the finish: never over a menu or the results. */
  sync(): void {
    let show = false, waiting = false;
    const world = live.world;
    if (this.touch && world) {
      const kart = world.store(Kart);
      const p = kart.phase[live.kart];
      waiting = p === Phase.countdown && kart.waiting[live.kart] !== 0;
      // Only once the kart is on the start line: never over the flyover or the wait for Start.
      show = (p === Phase.countdown && !waiting) || p === Phase.racing;
    }
    // The floating pad takes the screen's touches only with the run on: never over the flyover's Skip or Start.
    const takes = show && !waiting && this.style === 'dpad';
    if (takes !== this.takes) {
      this.takes = takes;
      this.pad.active(takes);
    }
    // The player's choice, changed in the pause menu: the other kind let go, this one shown.
    if (this.style !== touchStyle()) {
      this.style = touchStyle();
      this.letGo();
      this.showStyle();
    }
    if (show === this.view.visible) return;
    this.view.visible = show;
    if (!show) this.letGo();
  }

  private showStyle(): void {
    this.pad.view.visible = this.style === 'dpad';
    this.pad.catcher.visible = this.style === 'dpad';
    this.buttons.visible = this.style === 'buttons';
  }

  private letGo(): void {
    for (const b of this.all) b.release();
    this.pad.release();
  }

  layout(units: Units): void {
    const { u, safe, width, height } = units;
    const big = SCREEN_U.touchButton * u, gap = SCREEN_U.touchGap * u;
    const left = Math.max(gap, safe.left + gap), right = width - Math.max(gap, safe.right + gap);
    const bottom = height - Math.max(gap * 1.5, safe.bottom + gap);
    // The D-pad, bottom left.
    this.pad.layout(SCREEN_U.touchPad * u);
    this.pad.cover(width, height, left, bottom - this.pad.size);
    // Bottom middle: steer, the two arrows side by side about the screen's middle.
    const sw = big * SCREEN_U.steerW, sh = big * SCREEN_U.steerH;
    this.left.layout(sw, sh, u);
    this.right.layout(sw, sh, u);
    const mid = width / 2;
    this.left.view.position.set(mid - gap / 2 - sw, bottom - sh);
    this.right.view.position.set(mid + gap / 2, bottom - sh);
    // Bottom right: push (the big one), brake beside it -- or, where that would run into the arrows (a phone held
    // upright), brake stacked above push.
    this.push.layout(big * 1.25, big * 1.15, u);
    this.brake.layout(big * 1.05, big, u);
    this.push.view.position.set(right - big * 1.25, bottom - big * 1.15);
    const beside = right - big * 1.25 - gap - big * 1.05;
    if (beside >= mid + gap / 2 + sw + gap) this.brake.view.position.set(beside, bottom - big);
    else this.brake.view.position.set(right - big * 1.25 + (big * 1.25 - big * 1.05) / 2, bottom - big * 1.15 - gap - big);
  }
}
