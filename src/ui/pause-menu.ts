/**
 * The pause menu: a veil over the stopped world, a navy plate with a pale edge, its heading (a chequered flag, the
 * words, an orange underline) that breathes, Resume (the one to press, hot orange) and Quit race (back to the
 * garage), and the controls as keys under them. A veil that claims every press from the game, sizes in `m`, animation in `frame` while the world under
 * it stands still (`Game.present`).
 */
import { Container, Graphics } from 'pixi.js';
import { COLOUR, menu, SIZE_M, type Units, type Widget } from '@vibe/engine/ui';
import { KIT_COLOUR, KIT_M } from './karty-theme.ts';
import { KLabel, plate } from './kit.ts';
import { hushLoops, live, Order, orderRace } from './live.ts';
import { NONE } from '@vibe/engine';
import { Kart, Phase } from '../game/components.ts';
import { headingWidth, placeHeading } from './screen-kit.ts';
import { SCREEN_M } from './screen-theme.ts';
import { SlantButton } from './slant-button.ts';
import { ControlsCard } from './controls-card.ts';
import { touchFirst } from './touch-controls.ts';
import { SENSITIVITIES, setTouchSensitivity, setTouchStyle, touchSensitivity, touchStyle } from './touch-style.ts';

/** The touch switch's words for each kind. */
const STYLE_WORDS = { dpad: 'Touch: D-pad', buttons: 'Touch: Buttons' } as const;

/** The controls under the buttons, this much bigger than the menus' unit. */
const CONTROLS_SCALE = 1.2;

export class PauseMenu implements Widget {
  readonly id = 'pause-menu';
  readonly view = new Container({ label: 'pause-menu' });

  /** Full screen and interactive: a press anywhere on it is the menu's, never the game's (`input.ts`). */
  private readonly veil = new Graphics();
  private readonly panel = new Graphics();
  /** The heading's flag and underline, which breathe with it. */
  private readonly head = new Container();
  private readonly deco = new Graphics();
  private readonly title: KLabel;
  private readonly resume: SlantButton;
  /** Out of the run and back to the garage: the run dropped, the kart on the line, the menu shut. */
  private readonly quit: SlantButton;
  /** Mid-run: start it again from the line (the keyboard's R; on a touch screen the only way, say, out of a wedge). */
  private readonly retry: SlantButton;
  private running = false;
  /** The controls, as keys, under the buttons. */
  private readonly controls = new ControlsCard(false);
  /** On a touch screen: which touch controls, the D-pad or the buttons, each press the other. */
  private readonly style: SlantButton;
  /** On a touch screen, with the D-pad: how sensitive it is, each press the next (low, medium, high). */
  private readonly sense: SlantButton;
  private readonly touch = touchFirst();
  private units: Units | null = null;
  private time = 0;
  /** The menus' unit and the heading's resting top, from the last layout. */
  private m = 1;
  private titleY = 0;

  constructor(onResume: () => void) {
    this.veil.eventMode = 'static';
    this.panel.eventMode = 'static';
    this.title = new KLabel({ size: SCREEN_M.heading, caps: true, fill: KIT_COLOUR.text, shadow: 'soft' }, 'Paused');
    this.resume = new SlantButton('resume', 'Resume', onResume, 'hot');
    this.retry = new SlantButton('retry-race', 'Retry', () => {
      orderRace(Order.restart);
      onResume();
    }, 'plain');
    this.quit = new SlantButton('quit-race', 'Quit race', () => {
      orderRace(Order.garage);
      onResume();
    }, 'plain');
    this.style = new SlantButton('touch-style', STYLE_WORDS[touchStyle()], () => {
      setTouchStyle(touchStyle() === 'dpad' ? 'buttons' : 'dpad');
      this.style.set(STYLE_WORDS[touchStyle()]);
      if (this.units) this.layout(this.units);
    }, 'plain');
    this.style.view.visible = this.touch;
    this.sense = new SlantButton('touch-sensitivity', `Sensitivity: ${SENSITIVITIES[touchSensitivity()]}`, () => {
      setTouchSensitivity((touchSensitivity() + 1) % SENSITIVITIES.length);
      this.sense.set(`Sensitivity: ${SENSITIVITIES[touchSensitivity()]}`);
      if (this.units) this.layout(this.units);
    }, 'plain');
    this.head.addChild(this.deco, this.title);
    this.view.addChild(this.veil, this.panel, this.head, this.resume.view, this.retry.view, this.quit.view, this.style.view, this.sense.view, this.controls.view);
    this.view.visible = false;
  }

  get isOpen(): boolean {
    return this.view.visible;
  }

  show(on: boolean): void {
    this.view.visible = on;
    this.time = 0;
    // The world stops under the menu, and with it what sets the run's sound loops: silenced till it runs again.
    if (on) hushLoops();
    // Retry only with a run on.
    const world = live.world;
    const phase = world && live.kart !== NONE && world.alive(live.kart) ? world.store(Kart).phase[live.kart] : Phase.garage;
    this.running = on && (phase === Phase.countdown || phase === Phase.racing);
    if (on && this.units) this.layout(this.units);
  }

  layout(units: Units): void {
    // Laid out at the menus' unit; if that runs off the frame (a phone on its side), again, smaller, to fit.
    const tall = this.place(units, units.m);
    if (tall > units.height && tall > 0) this.place(units, (units.m * units.height) / tall * 0.96);
  }

  /** Everything placed at the unit m; answers the plate's height. */
  private place(units: Units, m: number): number {
    this.m = m;
    this.units = units;
    this.veil.clear().rect(0, 0, units.width, units.height).fill(COLOUR.veil);

    this.title.restyle({ size: SCREEN_M.heading * m });
    this.resume.layout(m);
    this.quit.layout(m);
    this.retry.layout(m);
    this.retry.view.visible = this.running;
    this.style.layout(m);
    this.sense.layout(m);
    // The sensitivity only for the D-pad.
    const sensing = this.touch && touchStyle() === 'dpad';
    this.sense.view.visible = sensing;
    // A column of buttons, one width: the widest's.
    const column = [this.resume, this.retry, this.quit, this.style, this.sense];
    for (const b of column) b.minWidth = 0;
    const widest = Math.max(...column.filter((b) => b.view.visible).map((b) => b.width));
    for (const b of column) {
      b.minWidth = widest;
      b.layout(m);
    }

    // The keys only where there is a keyboard to press them: not on a touch screen.
    this.controls.view.visible = !this.touch;
    this.controls.layout(m * CONTROLS_SCALE);
    const controlsH = this.touch ? 0 : SCREEN_M.buttonGap * m * 2 + this.controls.height;
    const pad = SCREEN_M.platePad * m;
    const width = Math.min(units.width - pad, Math.max(menu(units, SCREEN_M.pauseMin, SIZE_M.panelVw, SCREEN_M.pauseMax), this.touch ? 0 : this.controls.width + pad * 2));
    const gap = SCREEN_M.buttonGap * m;
    const cell = KIT_M.check * m;
    const room = SCREEN_M.flagRoom * m;
    const under = SCREEN_M.under * m;
    const headH = this.title.lineBox.height + SCREEN_M.underDrop * m + under;
    const sink = SCREEN_M.buttonSink * m;
    const height = pad + headH + gap * 2 + this.resume.height + sink + gap + this.quit.height + sink + controlsH + pad
      + Number(this.touch) * (this.style.height + sink + gap) + Number(sensing) * (this.sense.height + sink + gap)
      + Number(this.running) * (this.retry.height + sink + gap);
    const x = (units.width - width) / 2;
    const y = Math.max(0, (units.height - height) / 2);
    plate(this.panel.clear(), x, y, width, height, m);

    // The heading drawn at the head's origin, the head moved to centre it: it bobs as one.
    this.deco.clear();
    placeHeading(this.deco, this.title, 0, 0, cell, room, under, SCREEN_M.underDrop * m);
    this.titleY = y + pad;
    this.head.position.set(x + (width - headingWidth(this.title, cell, room)) / 2, this.titleY);

    const resumeY = y + pad + headH + gap * 2;
    this.resume.view.position.set(x + (width - this.resume.width) / 2, resumeY);
    let below = resumeY + this.resume.height + sink + gap;
    if (this.running) {
      this.retry.view.position.set(x + (width - this.retry.width) / 2, below);
      below += this.retry.height + sink + gap;
    }
    this.quit.view.position.set(x + (width - this.quit.width) / 2, below);
    below += this.quit.height + sink + gap;
    if (this.touch) {
      this.style.view.position.set(x + (width - this.style.width) / 2, below);
      below += this.style.height + sink + gap;
    }
    if (sensing) {
      this.sense.view.position.set(x + (width - this.sense.width) / 2, below);
      below += this.sense.height + sink + gap;
    }
    this.controls.view.position.set(x + (width - this.controls.width) / 2, below + gap);
    return height;
  }

  frame(dt: number): void {
    this.time += dt;
    // The world is stopped under it; the menu still moves.
    this.head.y = Math.round(this.titleY + Math.sin(this.time * 2.4) * SIZE_M.titleBob * this.m);
  }
}
