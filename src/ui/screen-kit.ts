/**
 * Shapes the general screens add to `kit.ts`'s: a heading with its chequered flag before it and its orange
 * underline under it, and a thin rule across a plate. Every size handed in, in pixels (a constant times the unit).
 */
import type { Graphics } from 'pixi.js';
import { flag, slant, type KLabel } from './kit.ts';
import { KIT_COLOUR, KIT_M } from './karty-theme.ts';

/** How wide a flag of `KIT_M`'s squares is, at a square of `cell`. */
export function flagWidth(cell: number): number {
  if (KIT_M.flagCols === 0) return 0;
  return cell * KIT_M.flagCols + cell * KIT_M.flagRows * KIT_M.lean;
}

/** How wide a heading is with its flag before it. */
export function headingWidth(label: KLabel, cell: number, room: number): number {
  const f = flagWidth(cell);
  return (f > 0 ? f + room : 0) + label.lineBox.width;
}

/**
 * A heading at (x, y): its flag (light squares hot orange), its words after, the underline under them. Draws into
 * `g` (cleared by the caller), places the label, and answers the block's height.
 */
export function placeHeading(g: Graphics, label: KLabel, x: number, y: number, cell: number, room: number, under: number, drop: number): number {
  const box = label.lineBox;
  const fh = cell * KIT_M.flagRows;
  flag(g, x, y + (box.height - fh) / 2, cell, KIT_M.flagCols, KIT_M.flagRows, KIT_COLOUR.hot);
  const f = flagWidth(cell);
  const lx = x + (f > 0 ? f + room : 0);
  label.position.set(lx, y);
  const uy = y + box.height + drop;
  slant(g, lx - under, uy, box.width + under * 2, under, KIT_COLOUR.hot);
  return box.height + drop + under;
}

/** A thin rule across, in the dim edge's colour. */
export function rule(g: Graphics, x: number, y: number, w: number, thick: number): Graphics {
  return g.rect(x, y, w, Math.max(1, thick)).fill(KIT_COLOUR.edgeDim);
}
