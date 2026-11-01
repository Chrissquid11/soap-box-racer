/**
 * The base project's HUD: the game's name and a hint top left, a pause button
 * and a sound button top right. A worked example of a widget -- `Label`s,
 * icons rasterised at their on-screen size and tinted, `Pressable`s, `layout`
 * in `u`, state set on change -- for a game to replace.
 */
import { Container, Graphics, Sprite } from 'pixi.js';
import { Assets } from '@vibe/engine/assets';
import { ALPHA, bakedMargin, type ButtonState, type CanvasUi, COLOUR, ICON_SHADOW, icon, Label, Pressable, SIZE_U, type Units, type Widget } from '@vibe/engine/ui';

/** A round button showing one icon, white and tinted. */
class IconButton {
  readonly view: Container;
  readonly press: Pressable;
  private readonly plate = new Graphics();
  private readonly glyph = new Sprite();
  /** The slash across it when it is off (the sound button, muted). */
  private readonly slash = new Graphics();
  private size: number = SIZE_U.button;
  private off = false;
  private readonly url: string;
  private readonly ui: CanvasUi;

  constructor(id: string, url: string, ui: CanvasUi, onPress: () => void) {
    this.url = url;
    this.ui = ui;
    this.view = new Container({ label: id });
    this.view.addChild(this.plate, this.glyph, this.slash);
    this.press = new Pressable(this.view, { id, onPress, onState: (state) => this.draw(state) });
  }

  layout(u: number): void {
    this.size = SIZE_U.button * u;
    const inner = this.size * 0.62;
    // Asked for at the size it is drawn; a resize asks again and gets a new texture. It comes back
    // later, outside any Pixi work: set on the Pixi side, as every change to what is drawn is.
    void icon(this.url, inner, inner, this.ui.resolution, { paint: COLOUR.icon, shadow: ICON_SHADOW }).then((texture) => {
      this.ui.onPixiSide(() => {
        this.glyph.texture = texture;
        const at = (this.size - inner) / 2 - bakedMargin(texture);
        this.glyph.position.set(at, at);
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
    this.plate.clear().circle(s / 2, s / 2, s / 2).fill({ color: COLOUR.ink, alpha: state.hover ? ALPHA.plateHover : ALPHA.plate });
    this.glyph.alpha = state.down ? ALPHA.held : 1;
    this.slash.clear();
    if (this.off) {
      const a = s * 0.22;
      this.slash.moveTo(a, a).lineTo(s - a, s - a).stroke({ color: COLOUR.soundOff, width: s * 0.1, cap: 'round' });
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

  private readonly title: Label;
  private readonly hint: Label;
  private readonly pauseButton: IconButton;
  private readonly soundButton: IconButton;

  constructor(ui: CanvasUi, actions: HudActions) {
    // At one unit until the first layout sizes them.
    this.title = new Label({ size: SIZE_U.hud, caps: true, tracking: 0.06, outline: SIZE_U.outline, shadow: 'hud' }, document.title);
    this.hint = new Label({ size: SIZE_U.hint, face: 'ui', fill: COLOUR.textDim, shadow: 'soft' }, 'Drag to turn  ·  Esc to pause');
    this.pauseButton = new IconButton('pause', Assets.iconUrl('pause'), ui, actions.pause);
    this.soundButton = new IconButton('sound', Assets.iconUrl('speaker'), ui, actions.toggleSound);
    this.view.addChild(this.title, this.hint, this.pauseButton.view, this.soundButton.view);
  }

  /** The sound button drawn on or off. */
  setMuted(muted: boolean): void {
    this.soundButton.setOff(muted);
  }

  layout(units: Units): void {
    const { u, safe } = units;
    const inset = SIZE_U.inset * u;
    const left = Math.max(inset, safe.left);
    const top = Math.max(inset, safe.top);
    const right = units.width - Math.max(inset, safe.right);

    this.title.restyle({ size: SIZE_U.hud * u, outline: SIZE_U.outline * u });
    this.hint.restyle({ size: SIZE_U.hint * u });
    this.title.position.set(left, top);
    this.hint.position.set(left, top + this.title.lineBox.height + SIZE_U.hintGap * u);

    this.soundButton.layout(u);
    this.pauseButton.layout(u);
    const size = SIZE_U.button * u;
    this.soundButton.view.position.set(right - size, top);
    this.pauseButton.view.position.set(right - 2 * size - SIZE_U.gap * u, top);
  }
}
