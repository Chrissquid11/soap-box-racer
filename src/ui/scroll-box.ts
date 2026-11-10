/**
 * A scroll box: a window `w` by `h` onto `content`, which may be taller (or, along `x`, wider) -- what runs past
 * its end is cut off and reached by scrolling: the mouse wheel over it, the scroll bar along its far side (down its
 * right, or along its bottom; its thumb dragged, or its track pressed a page at a time), or a finger dragged along
 * the content (a drag past `SLOP` presses none of the buttons it started on: `Pressable`'s own rule). The bar is
 * shown only while there is more than fits. Presses outside the window never reach the content cut off there.
 */
import { Container, type FederatedPointerEvent, type FederatedWheelEvent, Graphics, Rectangle } from 'pixi.js';
import { KARTY_COLOUR, KARTY_M } from './karty-theme.ts';

/** How far a finger may drag, CSS pixels, before it scrolls rather than presses: the engine's own `SLOP` (`button.ts`). */
const SLOP = 12;

/** A drag under way: the pointer's, where it started (CSS pixels of the page) and the scroll then. */
interface Drag {
  id: number;
  at: number;
  from: number;
  /** The UI's pixels per CSS pixel of the page: the canvas may be drawn scaled (the studio's game view). */
  scale: number;
  thumb: boolean;
  moved: boolean;
}

export class ScrollBox {
  readonly view = new Container({ label: 'scroll-box' });
  /** What scrolls: lay it out from its top left, `inner` across (or, along x, `inner` high). */
  readonly content = new Container();
  private readonly clip = new Graphics();
  private readonly track = new Graphics();
  private readonly thumb = new Graphics();
  private w = 0;
  private h = 0;
  /** The content's length along the axis. */
  private tall = 0;
  private bar = 0;
  private scroll = 0;
  private hover = false;
  private drag: Drag | null = null;

  private readonly axis: 'x' | 'y';

  /** `y` scrolls up and down, `x` across. */
  constructor(axis: 'x' | 'y' = 'y') {
    this.axis = axis;
    this.view.addChild(this.content, this.clip, this.track, this.thumb);
    this.content.mask = this.clip;
    this.view.eventMode = 'static';
    this.view.on('wheel', (e: FederatedWheelEvent) => {
      if (this.tall <= this.span) return;
      // Across, a wheel turned up and down scrolls too; lines (Firefox) or pages, as pixels.
      const d = this.axis === 'x' && Math.abs(e.deltaX) > Math.abs(e.deltaY) ? e.deltaX : e.deltaY;
      const by = e.deltaMode === 1 ? d * KARTY_M.wheelLine * this.unit() : e.deltaMode === 2 ? d * this.span : d;
      this.scrollTo(this.scroll + by);
    });
    // A finger dragged over the content scrolls it.
    this.view.on('pointerdown', (e: FederatedPointerEvent) => {
      if (e.pointerType !== 'mouse' && this.tall > this.span) this.grab(e, false);
    });
    this.thumb.eventMode = 'static';
    this.thumb.cursor = 'grab';
    this.thumb.on('pointerdown', (e: FederatedPointerEvent) => {
      e.stopPropagation();
      this.grab(e, true);
    });
    this.thumb.on('pointerover', () => this.setHover(true));
    this.thumb.on('pointerout', () => this.setHover(false));
    this.track.eventMode = 'static';
    this.track.cursor = 'pointer';
    // The track pressed: a page toward where it was pressed.
    this.track.on('pointerdown', (e: FederatedPointerEvent) => {
      e.stopPropagation();
      const p = this.track.toLocal(e.global);
      const at = this.axis === 'y' ? p.y : p.x;
      const { start } = this.thumbBox();
      this.scrollTo(this.scroll + (at < start ? -1 : 1) * this.span * 0.9);
    });
  }

  /** The window's length along the axis. */
  private get span(): number {
    return this.axis === 'y' ? this.h : this.w;
  }

  /** Its window less the bar's room, across the axis: the content's width (or, along x, its height). */
  get inner(): number {
    const across = this.axis === 'y' ? this.w : this.h;
    return Math.max(0, across - this.bar - this.bar * KARTY_M.scrollGap);
  }

  /** Whether there is more than fits: the bar shown. */
  get overflows(): boolean {
    return this.tall > this.span + 0.5;
  }

  /** The window `w` by `h`, the bar `bar` thick; the content `tall` long as laid out. The scroll kept, held to what there is. */
  layout(w: number, h: number, bar: number): void {
    this.w = w;
    this.h = h;
    this.bar = bar;
    this.view.hitArea = new Rectangle(0, 0, w, h);
    this.clip.clear().rect(0, 0, w, h).fill(KARTY_COLOUR.mask);
  }

  /** The content's length along the axis, once laid out at `inner` across. */
  fit(tall: number): void {
    this.tall = tall;
    this.scrollTo(this.scroll);
  }

  /** Back to its start. */
  top(): void {
    this.scrollTo(0);
  }

  /** Scrolled just enough that `from`..`to` (along the axis, in the content) is in the window. */
  show(from: number, to: number): void {
    if (from < this.scroll) this.scrollTo(from);
    else if (to > this.scroll + this.span) this.scrollTo(to - this.span);
  }

  private unit(): number {
    return this.bar / KARTY_M.scrollBar;
  }

  private scrollTo(to: number): void {
    this.scroll = Math.max(0, Math.min(Math.max(0, this.tall - this.span), to));
    if (this.axis === 'y') this.content.y = -this.scroll;
    else this.content.x = -this.scroll;
    this.draw();
  }

  /** The thumb's start and length on the track. */
  private thumbBox(): { start: number; length: number } {
    const span = this.span;
    const length = Math.max(this.bar * 3, (span * span) / Math.max(1, this.tall));
    const room = span - length;
    const start = this.tall > span ? (this.scroll / (this.tall - span)) * room : 0;
    return { start, length };
  }

  private setHover(on: boolean): void {
    this.hover = on;
    this.draw();
  }

  private draw(): void {
    const show = this.overflows;
    this.track.visible = this.thumb.visible = show;
    if (!show) return;
    const r = this.bar / 2;
    const { start, length } = this.thumbBox();
    const lit = this.hover || (this.drag?.thumb ?? false);
    const thumbFill = lit ? KARTY_COLOUR.scrollThumbHover : KARTY_COLOUR.scrollThumb;
    if (this.axis === 'y') {
      const x = this.w - this.bar;
      this.track.clear().roundRect(x, 0, this.bar, this.h, r).fill(KARTY_COLOUR.scrollTrack);
      this.thumb.clear().roundRect(x, start, this.bar, length, r).fill(thumbFill);
    } else {
      const y = this.h - this.bar;
      this.track.clear().roundRect(0, y, this.w, this.bar, r).fill(KARTY_COLOUR.scrollTrack);
      this.thumb.clear().roundRect(start, y, length, this.bar, r).fill(thumbFill);
    }
  }

  /** A pointer down on the thumb or the content: followed on the page until it lets go. */
  private grab(e: FederatedPointerEvent, thumb: boolean): void {
    const native = e.nativeEvent as PointerEvent;
    const el = native.target instanceof HTMLElement ? native.target : null;
    const rect = el?.getBoundingClientRect();
    const drawn = this.axis === 'y' ? rect?.height : rect?.width;
    const css = this.axis === 'y' ? el?.clientHeight : el?.clientWidth;
    const scale = css && drawn ? css / drawn : 1;
    this.drag = { id: native.pointerId, at: this.axis === 'y' ? native.clientY : native.clientX, from: this.scroll, scale, thumb, moved: false };
    window.addEventListener('pointermove', this.onMove);
    window.addEventListener('pointerup', this.onUp);
    window.addEventListener('pointercancel', this.onUp);
    this.draw();
  }

  private readonly onMove = (ev: PointerEvent): void => {
    const d = this.drag;
    if (!d || ev.pointerId !== d.id) return;
    const by = ((this.axis === 'y' ? ev.clientY : ev.clientX) - d.at) * d.scale;
    if (d.thumb) {
      const { length } = this.thumbBox();
      const room = Math.max(1, this.span - length);
      this.scrollTo(d.from + (by * (this.tall - this.span)) / room);
    } else if (d.moved || Math.abs(by) > SLOP) {
      d.moved = true;
      this.scrollTo(d.from - by);
    }
  };

  private readonly onUp = (ev: PointerEvent): void => {
    if (!this.drag || ev.pointerId !== this.drag.id) return;
    this.drag = null;
    window.removeEventListener('pointermove', this.onMove);
    window.removeEventListener('pointerup', this.onUp);
    window.removeEventListener('pointercancel', this.onUp);
    this.draw();
  };
}
