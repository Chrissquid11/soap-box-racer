/**
 * The base project's pause menu: a veil over the stopped world, a panel, a
 * title that breathes, and a Resume button. The worked example of a menu --
 * a veil that claims every press from the game, sizes in `m`, animation in
 * `frame` while the world under it stands still (`Game.present`).
 */
import { Container, Graphics } from 'pixi.js';
import { COLOUR, Label, menu, PillButton, SIZE_M, type Units, type Widget } from '@vibe/engine/ui';

export class PauseMenu implements Widget {
  readonly id = 'pause-menu';
  readonly view = new Container({ label: 'pause-menu' });

  /** Full screen and interactive: a press anywhere on it is the menu's, never the game's (`input.ts`). */
  private readonly veil = new Graphics();
  private readonly panel = new Graphics();
  private readonly title: Label;
  private readonly resume: PillButton;
  private time = 0;
  /** The menus' unit and the title's resting top, from the last layout. */
  private m = 1;
  private titleY = 0;

  constructor(onResume: () => void) {
    this.veil.eventMode = 'static';
    this.title = new Label({ size: SIZE_M.title, caps: true, tracking: 0.08, fill: COLOUR.accent, outline: SIZE_M.titleOutline, shadow: 'hard' }, 'Paused');
    this.resume = new PillButton('resume', 'Resume', onResume);
    this.view.addChild(this.veil, this.panel, this.title, this.resume.view);
    this.view.visible = false;
  }

  get isOpen(): boolean {
    return this.view.visible;
  }

  show(on: boolean): void {
    this.view.visible = on;
    this.time = 0;
  }

  layout(units: Units): void {
    const { m } = units;
    this.m = m;
    this.veil.clear().rect(0, 0, units.width, units.height).fill(COLOUR.veil);

    this.title.restyle({ size: SIZE_M.title * m, outline: SIZE_M.titleOutline * m });
    this.resume.layout(m);

    const width = menu(units, SIZE_M.panelMin, SIZE_M.panelVw, SIZE_M.panelMax);
    const pad = SIZE_M.padScreen * m;
    const height = pad + this.title.lineBox.height + SIZE_M.gap * m * 2 + this.resume.height + SIZE_M.press * m + pad;
    const x = (units.width - width) / 2;
    const y = (units.height - height) / 2;
    this.panel
      .clear()
      .roundRect(x, y + SIZE_M.panelDrop * m, width, height, SIZE_M.panelRadius * m)
      .fill(COLOUR.panelEdge)
      .roundRect(x, y, width, height, SIZE_M.panelRadius * m)
      .fill(COLOUR.panel);

    this.titleY = y + pad;
    this.title.position.set(x + (width - this.title.lineBox.width) / 2, this.titleY);
    this.resume.view.position.set(x + (width - this.resume.width) / 2, y + pad + this.title.lineBox.height + SIZE_M.gap * m * 2);
  }

  frame(dt: number): void {
    this.time += dt;
    // The world is stopped under it; the menu still moves.
    this.title.y = Math.round(this.titleY + Math.sin(this.time * 2.4) * SIZE_M.titleBob * this.m);
  }
}
