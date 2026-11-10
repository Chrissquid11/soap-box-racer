/**
 * The controls, shown as keys: each control a key cap or two (cream, a navy rim, the letter on it) with what it does
 * under them -- W push, A D steer, S brake, R retry -- side by side on a dark plate. The run's HUD shows it
 * bottom middle at the start of the player's first race; the pause menu shows it always. Sizes in a unit the owner
 * gives (`layout`): the HUD's `u`, the menus' `m`.
 */
import { Container, Graphics } from 'pixi.js';
import { KIT_COLOUR, KIT_M } from './karty-theme.ts';
import { KLabel, plate } from './kit.ts';

/** Each control: its keys, and what it does. */
const CONTROLS: readonly (readonly [readonly string[], string])[] = [
  [['W'], 'Push'],
  [['A', 'D'], 'Steer'],
  [['S'], 'Brake'],
  [['R'], 'Retry'],
];

export class ControlsCard {
  readonly view = new Container({ label: 'controls' });
  private readonly back = new Graphics();
  private readonly caps = new Graphics();
  private readonly letters: KLabel[][] = [];
  private readonly words: KLabel[] = [];
  private w = 0;
  private h = 0;

  /** On its own dark plate (over the world), or bare (on a menu's plate already). */
  private readonly framed: boolean;

  /** `framed`: on its own dark plate; false, bare. */
  constructor(framed = true) {
    this.framed = framed;
    this.view.addChild(this.back, this.caps);
    for (const [keys, word] of CONTROLS) {
      const row = keys.map((k) => new KLabel({ size: KIT_M.capText, caps: true, fill: KIT_COLOUR.shadow }, k));
      this.letters.push(row);
      const label = new KLabel({ size: KIT_M.capLabel, caps: true, fill: KIT_COLOUR.text }, word);
      this.words.push(label);
      this.view.addChild(...row, label);
    }
  }

  get width(): number {
    return this.w;
  }

  get height(): number {
    return this.h;
  }

  /** Laid out at the unit `k` (its top left at its view's origin). */
  layout(k: number): void {
    const cap = KIT_M.cap * k, gap = KIT_M.capGap * k, group = KIT_M.capGroup * k, pad = this.framed ? KIT_M.capPad * k : 0;
    const g = this.caps.clear();
    let x = pad;
    let wordH = 0;
    for (const word of this.words) {
      word.restyle({ size: KIT_M.capLabel * k });
      wordH = Math.max(wordH, word.lineBox.height);
    }
    for (let i = 0; i < CONTROLS.length; i++) {
      const row = this.letters[i]!;
      const capsW = row.length * cap + (row.length - 1) * gap;
      const word = this.words[i]!;
      const colW = Math.max(capsW, word.lineBox.width);
      let cx = x + (colW - capsW) / 2;
      for (const letter of row) {
        // A key cap: its shade under it, its cream face, its rim, its letter in the middle.
        const r = cap * 0.22;
        g.roundRect(cx, pad + cap * 0.1, cap, cap, r).fill(KIT_COLOUR.shadow);
        g.roundRect(cx, pad, cap, cap, r).fill(KIT_COLOUR.key).roundRect(cx, pad, cap, cap, r).stroke({ color: KIT_COLOUR.edge, width: Math.max(1, KIT_M.edge * k * 0.8) });
        letter.restyle({ size: KIT_M.capText * k });
        letter.position.set(cx + (cap - letter.lineBox.width) / 2, pad + (cap - letter.lineBox.height) / 2);
        cx += cap + gap;
      }
      word.position.set(x + (colW - word.lineBox.width) / 2, pad + cap * 1.2);
      x += colW + group;
    }
    this.w = x - group + pad;
    this.h = pad + cap * 1.2 + wordH + pad;
    this.back.clear();
    if (this.framed) plate(this.back, 0, 0, this.w, this.h, k);
  }
}
