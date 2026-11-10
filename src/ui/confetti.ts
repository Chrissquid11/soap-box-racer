/**
 * Confetti over a screen: paper bits thrown up from the bottom corners, tumbling and fluttering down -- the results'
 * celebration when a run opens the next course (`race-hud.ts`). Drawn in one Graphics, its bits made once and reused;
 * `burst` throws them, `frame` moves them in real seconds.
 */
import { Graphics } from 'pixi.js';
import { CONFETTI_UI } from './screen-theme.ts';

interface Bit {
  x: number;
  y: number;
  vx: number;
  vy: number;
  turn: number;
  spin: number;
  flutter: number;
  colour: number;
}

export class Confetti {
  readonly view = new Graphics();
  private readonly bits: Bit[] = [];
  private t = 99;
  private w = 1;
  private h = 1;
  private size = 1;

  constructor() {
    for (let i = 0; i < CONFETTI_UI.count; i++) this.bits.push({ x: 0, y: 0, vx: 0, vy: 0, turn: 0, spin: 0, flutter: 0, colour: 0 });
    this.view.eventMode = 'none';
  }

  /** The screen it falls over, and a bit's size (pixels). */
  layout(width: number, height: number, size: number): void {
    this.w = width;
    this.h = height;
    this.size = size;
  }

  /** Thrown: half from each bottom corner, up and in. */
  burst(): void {
    this.t = 0;
    const colours = CONFETTI_UI.colours;
    for (let i = 0; i < this.bits.length; i++) {
      const b = this.bits[i]!;
      const side = i % 2 === 0 ? -1 : 1;
      b.x = side < 0 ? 0 : this.w;
      b.y = this.h;
      const speed = this.h * (CONFETTI_UI.speedMin + Math.random() * CONFETTI_UI.speedMore);
      const angle = (CONFETTI_UI.angleMin + Math.random() * CONFETTI_UI.angleMore) * (Math.PI / 180);
      b.vx = -side * Math.cos(angle) * speed;
      b.vy = -Math.sin(angle) * speed;
      b.turn = Math.random() * Math.PI * 2;
      b.spin = (Math.random() - 0.5) * CONFETTI_UI.spin;
      b.flutter = Math.random() * Math.PI * 2;
      b.colour = colours[i % colours.length]!;
    }
  }

  frame(dt: number): void {
    const g = this.view.clear();
    if (this.t > CONFETTI_UI.life) return;
    this.t += dt;
    const fade = Math.min(1, Math.max(0, (CONFETTI_UI.life - this.t) / CONFETTI_UI.fade));
    const s = this.size;
    for (let i = 0; i < this.bits.length; i++) {
      const b = this.bits[i]!;
      // Falling, held back by the air: fluttering side to side as it comes down.
      b.vy += this.h * CONFETTI_UI.gravity * dt;
      const drag = Math.exp(-CONFETTI_UI.drag * dt);
      b.vx *= drag;
      b.vy *= drag;
      b.flutter += dt * CONFETTI_UI.flutterHz * Math.PI * 2;
      b.x += (b.vx + Math.sin(b.flutter) * this.h * CONFETTI_UI.sway) * dt;
      b.y += b.vy * dt;
      b.turn += b.spin * dt;
      // A paper bit: a rectangle turned, squashed as it flips.
      const c = Math.cos(b.turn), sn = Math.sin(b.turn), flip = Math.abs(Math.cos(b.flutter)) * 0.8 + 0.2;
      const hx = s * 0.5, hy = s * 0.3 * flip;
      g.poly([
        b.x - c * hx + sn * hy, b.y - sn * hx - c * hy,
        b.x + c * hx + sn * hy, b.y + sn * hx - c * hy,
        b.x + c * hx - sn * hy, b.y + sn * hx + c * hy,
        b.x - c * hx - sn * hy, b.y - sn * hx + c * hy,
      ]).fill({ color: b.colour, alpha: fade });
    }
  }
}
