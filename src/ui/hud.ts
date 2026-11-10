/**
 * The HUD over everything: a pause button and a sound button top right, each a see-through black rounded square with a faint pale
 * edge and a white glyph. (The game's name and the course, top left, are the run HUD's: `race-hud.ts`.) Icons
 * rasterised at their on-screen size and tinted, `Pressable`s, `layout` in `u`, state set on change.
 */
import { Container, Graphics, Sprite } from 'pixi.js';
import { Assets } from '@vibe/engine/assets';
import { bakedMargin, type ButtonState, type CanvasUi, COLOUR, ICON_SHADOW, icon, Pressable, SIZE_U, type Units, type Widget } from '@vibe/engine/ui';
import { KIT_COLOUR, KIT_M } from './karty-theme.ts';
import { clicked } from './kit.ts';
import { SCREEN_ALPHA, SCREEN_COLOUR, SCREEN_U } from './screen-theme.ts';

/** A slanted square showing one icon, white and tinted. */
class IconButton {
  readonly view: Container;
  readonly press: Pressable;
  private readonly plate = new Graphics();
  private readonly glyph = new Sprite();
  /** The slash across it when it is off (the sound button, muted). */
  private readonly slash = new Graphics();
  private size: number = SCREEN_U.button;
  private u = 1;
  private off = false;
  private readonly url: string;
  private readonly ui: CanvasUi;

  constructor(id: string, url: string, ui: CanvasUi, onPress: () => void) {
    this.url = url;
    this.ui = ui;
    this.view = new Container({ label: id });
    this.view.addChild(this.plate, this.glyph, this.slash);
    this.press = new Pressable(this.view, { id, onPress: clicked(onPress), onState: (state) => this.draw(state) });
  }

  /** Across, the lean included. */
  get width(): number {
    return this.size * (1 + KIT_M.lean);
  }

  layout(u: number): void {
    this.u = u;
    this.size = SCREEN_U.button * u;
    const inner = this.size * SCREEN_U.glyph;
    // Asked for at the size it is drawn; a resize asks again and gets a new texture. It comes back
    // later, outside any Pixi work: set on the Pixi side, as every change to what is drawn is.
    void icon(this.url, inner, inner, this.ui.resolution, { paint: COLOUR.icon, shadow: ICON_SHADOW }).then((texture) => {
      this.ui.onPixiSide(() => {
        this.glyph.texture = texture;
        const margin = bakedMargin(texture);
        this.glyph.position.set((this.width - inner) / 2 - margin, (this.size - inner) / 2 - margin);
      });
    });
    this.draw(this.press.states);
  }

  /** Drawn with a slash across it. */
  setOff(off: boolean): void {
    if (off === this.off) return;
    this.off = off;
    this.draw(this.press.states);
  }

  private draw(state: Readonly<ButtonState>): void {
    const s = this.size;
    const w = this.width;
    // See-through black, darker under the pointer; a faint pale edge.
    const r = Math.max(0, Math.min(s * 0.34, w / 2));
    this.plate.clear().roundRect(0, 0, w, s, r)
      .fill({ color: KIT_COLOUR.shadow, alpha: state.hover ? SCREEN_ALPHA.iconHover : SCREEN_ALPHA.iconBack })
      .stroke({ color: KIT_COLOUR.text, alpha: SCREEN_ALPHA.iconEdge, width: Math.max(1, SCREEN_U.edge * this.u) });
    this.glyph.alpha = state.down ? SCREEN_ALPHA.held : 1;
    this.slash.clear();
    if (this.off) {
      const a = s * 0.24;
      const x = (w - s) / 2;
      this.slash.moveTo(x + a, a).lineTo(x + s - a, s - a).stroke({ color: SCREEN_COLOUR.soundOff, width: s * 0.1, cap: 'round' });
    }
  }
}

export interface HudActions {
  pause(): void;
  toggleSound(): void;
}

export class Hud implements Widget {
  readonly id = 'hud';
  readonly view = new Container({ label: 'hud' });

  private readonly pauseButton: IconButton;
  private readonly soundButton: IconButton;

  constructor(ui: CanvasUi, actions: HudActions) {
    this.pauseButton = new IconButton('pause', Assets.iconUrl('pause'), ui, actions.pause);
    this.soundButton = new IconButton('sound', Assets.iconUrl('speaker'), ui, actions.toggleSound);
    this.view.addChild(this.pauseButton.view, this.soundButton.view);
  }

  /** The sound button drawn on or off. */
  setMuted(muted: boolean): void {
    this.soundButton.setOff(muted);
  }

  layout(units: Units): void {
    const { u, safe } = units;
    const inset = SIZE_U.inset * u;
    const top = Math.max(inset, safe.top);
    const right = units.width - Math.max(inset, safe.right);

    this.soundButton.layout(u);
    this.pauseButton.layout(u);
    const w = this.soundButton.width;
    this.soundButton.view.position.set(right - w, top);
    this.pauseButton.view.position.set(right - 2 * w - SCREEN_U.buttonGap * u, top);
  }
}
