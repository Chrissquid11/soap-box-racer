/**
 * The general screens' sizes and colours, in the garage's look (`karty-theme.ts`' `KIT_*`): the run's HUD, the
 * results, the course select, the pause menu and the HUD's buttons. Sizes in `m` (menus, laid out for a frame 720
 * tall) or `u` (the HUD); colours as numbers, and the few a `Look` takes as CSS strings made from them.
 */
import { KIT_COLOUR } from './karty-theme.ts';

/** A colour number as the CSS string a `Look`'s outline or shadow takes. */
export function css(n: number): string {
  return '#' + n.toString(16).padStart(6, '0');
}

/** Whether the frame is a phone's (its short side under `SCREEN_M.phone`). */
export function phoneSized(units: { readonly width: number; readonly height: number }): boolean {
  return Math.min(units.width, units.height) < SCREEN_M.phone;
}

/** Sizes in `m`. */
export const SCREEN_M = {
  /** The narrowest screen (CSS pixels at one unit) the menus fit across: narrower (a phone held upright), their unit
   * shrinks to fit its width as well as its height (`ui/index.ts`). */
  fitWidth: 600,
  /** A phone: a screen whose short side is under this many CSS pixels. Its menus' unit is never under `phoneUnit`
   * (shrunk further, the words would be too small to read), and every screen lays itself out for it (`phoneSized`). */
  phone: 540,
  phoneUnit: 0.8,
  /** The least height (CSS pixels, not units) of anything pressed on a touch screen or a phone: a finger's. */
  touch: 44,
  /** A page arrow's button (‹ ›) across. */
  arrowW: 76,
  /** The course select's two columns (a phone on its side): each at least this across. */
  selectCol: 300,
  /** The results plate across, the course select's, and the pause plate's (least, most). */
  results: 600,
  select: 620,
  pauseMin: 300,
  pauseMax: 400,
  /** A screen's heading, and the plate's padding round everything in it. */
  heading: 44,
  platePad: 22,
  /** The orange underline under a heading: its thickness, and how far under the words' box (up is less). */
  under: 4,
  underDrop: -4,
  /** Between a heading's flag and its words. */
  flagRoom: 12,
  /** A results row (a medal's): its words, its laurel, and the room between rows. */
  rowText: 21,
  laurel: 24,
  rowRoom: 8,
  /** A thin rule across a plate, and the room either side of it. */
  ruleRoom: 12,
  /** Body text, and small print. */
  body: 19,
  small: 15,
  /** Between two lines in a block. */
  lineRoom: 6,
  /** A course's row: high, between two, its number's column, its laurel, its corners, the lit one's edge. */
  row: 38,
  rowGap: 6,
  rowNum: 34,
  rowLaurel: 34,
  rowRound: 6,
  rowLit: 2.5,
  /** The lit row's slanted marker, across. */
  rowMark: 10,
  /** The row's little map of its course: across (it is as high as the row, less a margin). */
  rowMap: 58,
  /** The map's road: its dark edge and its middle, across; its start and finish dots' radii (the finish's dark middle). */
  mapEdge: 7.5,
  /** ... at their full size on a map this high or more; a smaller map (a row's) drawn thinner, down to MAP_THIN of it. */
  mapFull: 110,
  mapRoad: 5,
  mapDot: 5.5,
  mapDotMiddle: 2.6,
  /** A slanted button: high, its words, the room either side of them, at least across, its edge, how far it sinks. */
  button: 50,
  buttonText: 26,
  buttonPadX: 24,
  buttonMin: 150,
  buttonEdge: 2,
  buttonSink: 4,
  /** Between two buttons, and a primary button's flag's square. */
  buttonGap: 14,
  buttonCheck: 5,
} as const;

/** Sizes in `u`: the run's HUD, laid out after the HUD mockup. */
export const SCREEN_U = {
  /** A HUD plate's pale edge, and the room inside a plate either side of its words. */
  edge: 1.5,
  /** The touch controls (`touch-controls.ts`): a big button's height, the gap between two, its words, its edge (a
   * share of its height). */
  touchButton: 96,
  touchGap: 14,
  /** The steer arrows (bottom middle): across and high, times a big button's height. */
  steerW: 1.5,
  steerH: 1.3,
  touchText: 24,
  touchEdge: 0.04,
  /** The virtual D-pad: across, its thumb knob (a share of its radius), and the dead middle
   * (a share of its radius) where a thumb presses nothing. */
  touchPad: 190,
  /** The ring's line, a share of its radius. */
  touchPadRing: 0.06,
  touchPadKnob: 0.32,
  /** The dead middle at each sensitivity (`touch-style.ts`: low, medium, high). */
  touchPadDead: [0.55, 0.4, 0.25],
  platePadX: 16,
  /** Between two things side by side on a plate, and a flag's square on it. */
  room: 10,
  check: 4,

  /** Top left, the tag: high, its words, the LIVE dot's radius. */
  tagH: 42,
  tagText: 26,
  dot: 6,
  /** Under it, the course's line: high, its words, how far right of the tag it sits, its three slashes' thickness. */
  subH: 30,
  subText: 19,
  subShift: 8,
  slash: 3,
  /** The keys' help under them, and the room above it. */
  keys: 13,
  keysRoom: 6,
  keysOutline: 2.5,

  /** Top right, the pause and sound buttons: square, between two, the glyph's share of the square. */
  button: 50,
  buttonGap: 8,
  glyph: 0.55,

  /** The banner in the middle: high, its words, its flags' square, down the frame as a share of its height. */
  bannerH: 70,
  bannerText: 52,
  bannerCheck: 6,
  bannerAt: 0.3,
  /** The news under it: its words, outline, drop, the room above it, its wrap as a share of the frame's width. */
  news: 28,
  newsOutline: 4,
  newsDrop: 3,
  newsRoom: 10,
  newsWrap: 0.8,

  /** Bottom left, the kart: the number's box across, the plates' height, the number's words, the name's, ONBOARD's. */
  numW: 104,
  kartH: 62,
  numText: 48,
  nameText: 34,
  stateText: 21,
  /** The thin slash between the name and ONBOARD: its thickness. */
  thinSlash: 2,
  /** The orange underline under it: thickness, room above it. */
  under: 3.5,
  underRoom: 4,
  /** The style and the kart's condition, under it all: words, room above, the meter across and thick. */
  chipText: 18,
  chipRoom: 5,
  meter: 130,
  meterThick: 8,

  /** Bottom right, the clock: high, RUN TIME's words, the time's. */
  clockH: 60,
  clockLabel: 28,
  clockText: 44,
  /** Under it, the gold target: high, its words, its orange bar across, how far left of the clock it sits. */
  goldH: 38,
  goldText: 22,
  goldBar: 7,
  goldShift: 10,
  /** The speed, big at the top middle (mph). */
  speedText: 46,
} as const;

/** Colours, as numbers. */
export const SCREEN_COLOUR = {
  /** The slash across the sound button, muted, and the LIVE dot. */
  soundOff: 0xff5a4a,
  live: 0xff3b30,
  /** The cream plates (the course's line, the clock), and their words. */
  cream: 0x1b2540,
  creamInk: 0xf6efe0,
} as const;

/** Colours as CSS strings, for a `Look`'s outline and shadow. */
export const SCREEN_CSS = {
  /** The outline round words straight on the world (and any shadow under words): navy. */
  ink: css(KIT_COLOUR.shadow),
} as const;

/** Opacities. */
export const SCREEN_ALPHA = {
  /** A button held down. */
  held: 0.85,
  /** A shadow under a label. */
  drop: 0.6,
  /** A touch control at rest: the world shows through it. */
  touch: 0.72,
  /** The pause and sound buttons' see-through black (`hud.ts`), under the pointer, and their faint edge. */
  /** The touch D-pad: its ring's see-through fill, the ring, the knob. */
  padFill: 0.2,
  padRing: 0.55,
  padKnob: 0.85,
  iconBack: 0.4,
  iconHover: 0.6,
  iconEdge: 0.35,
} as const;

/** The results' confetti (`confetti.ts`): how many bits, their colours; thrown at this share of the screen's height a
 * second (and up to this much more), this many degrees up (and up to this much more); falling at this share a second
 * squared, slowed by the air, swaying this share as they flutter this many times a second, spinning up to this fast
 * (radians a second); gone after this many seconds, fading over the last of them. */
export const CONFETTI_UI = {
  count: 90,
  colours: [0xff4d6d, 0x3fa8ff, 0xffd23f, 0x5ee07a, 0xffffff, 0xb46bff],
  speedMin: 1.1,
  speedMore: 0.8,
  angleMin: 55,
  angleMore: 30,
  gravity: 0.9,
  drag: 1.4,
  sway: 0.06,
  flutterHz: 1.6,
  spin: 14,
  life: 4.5,
  fade: 1,
} as const;
