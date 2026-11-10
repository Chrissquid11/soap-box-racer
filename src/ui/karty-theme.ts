/**
 * The game's own additions to the engine's theme (`@vibe/engine/ui`'s COLOUR, SIZE_U, SIZE_M): the
 * garage's and the results' sizes, in `m`, and the medals' colours -- numbers Pixi reads as colours.
 * A widget reads them here, never a literal of its own.
 */

/** Sizes in `m` (the menus' unit). */
export const KARTY_M = {
  /** The garage panel across at most, and the space around everything in it. */
  panel: 1040,
  pad: 18,
  /** The garage's side column (how it drives, Race!), and the narrowest panel that has one beside the parts. */
  side: 330,
  twoColumn: 760,
  /** A card in the garage (a slot's, the sizes', the ratings'): the room inside it, between two, its corners, its heading's row. */
  cardPad: 12,
  cardGap: 10,
  cardRadius: 12,
  cardHead: 28,
  /** One row of the course or a size: its height, and the arrow buttons' size. */
  row: 34,
  arrow: 30,
  /** A part's chip in its slot's card: its height, the room either side of its name, the gap between two. */
  chip: 34,
  chipPad: 12,
  chipGap: 7,
  /** A scroll bar's thickness, the gap left of it (in thicknesses), and a wheel's line (Firefox) in `m`. */
  scrollBar: 10,
  scrollGap: 0.8,
  wheelLine: 40,
  /** A size's percent, between its − and +. */
  sizeValue: 64,
  /** A rating's bar: its length and thickness. */
  bar: 170,
  barThick: 10,
  /** The results panel across. */
  results: 560,
  /** The course select: across, a course's row high, the gap between rows, and its medal's dot. */
  select: 600,
  selectRow: 34,
  selectGap: 5,
  medalDot: 9,
  /** Small print: blurbs, warnings, the run's explanation. */
  small: 15,
} as const;

/** Shares of the frame. */
export const KARTY_SHARE = {
  /** The garage panel's width, of the frame's: the kart on the line is seen beside it. */
  garage: 0.62,
} as const;

/** Sizes in `u` (the HUD's unit). */
export const KARTY_U = {
  /** Clear of the title and its hint, top left. */
  belowTitle: 84,
  /** The big words: the countdown, GO!, a crash. */
  shout: 64,
  shoutOutline: 5,
  /** The news under them. */
  news: 30,
} as const;

/** Colours, as numbers. */
/** Each course rating's colour (`DIFFICULTIES`: Easy, Medium, Hard, Extreme, Insane, Bonkers). */
export const DIFFICULTY_COLOURS = [0x5ee07a, 0x3fa8ff, 0xffd23f, 0xff8a1f, 0xff3b30, 0xc77dff] as const;

export const KARTY_COLOUR = {
  gold: 0xffc93c,
  silver: 0xcfd6de,
  bronze: 0xd08a4c,
  none: 0x6b7280,
  barBack: 0x2f3b58,
  barFill: 0x39ff5a,
  warn: 0xff3b30,
  bad: 0xff5a4a,
  arrow: 0x24314f,
  arrowHover: 0x1f6be0,
  /** A part's chip: as an arrow, and the part chosen lit (blue, as everything chosen is). */
  chipOn: 0x1f6be0,
  chipOnText: 0xffffff,
  chipOnEdge: 0x2fd4ff,
  /** A card on the garage's panel, and its edge. */
  card: 0x1b2540,
  cardEdge: 0x3d4f7a,
  /** A scroll bar: its track, its thumb, and the thumb under the mouse or held. */
  scrollTrack: 0x111a30,
  scrollThumb: 0x4a5f8c,
  scrollThumbHover: 0x1f6be0,
  /** What a scroll box's window is cut by (only its shape counts). */
  mask: 0xffffff,
} as const;

/**
 * The game's look (the garage's, and every screen's after it), an arcade sticker style at night: dark slate panels with
 * a pale slate rim and a drop shadow under them, cream words, bold red for what to press (white words on it), bright
 * blue rimmed cyan for what is chosen, a chunky italic condensed face for the words (`kit.ts`' `KLabel`), chequered flags for flourish;
 * words straight on the world white, outlined navy. Sizes in `m`, laid out for a frame 720 tall (where `m` is 1).
 */
export const KIT_M = {
  /** The edge round a plate, and a divider's thickness. */
  edge: 2.6,
  /** A plate's corners, a card's, a tab's. */
  plateRound: 16,
  cardRound: 12,
  /** How far a slanted box leans: its top's shift over its height (the flags' squares, and the room the words leave). */
  lean: 0.1,
  /** An arrow button (‹ ›): at least this many times as wide as it is high. */
  arrowShape: 1.3,
  /** A sticker's drop shadow: down and right, as a share of its outline's thickness; its opacity. */
  drop: 1.6,
  dropAlpha: 0.32,
  /** A chequer's square, and a flag's squares across and down. (No flags now: 0 across, and each is left out and takes
   * no room.) */
  check: 6,
  flagCols: 0,
  flagRows: 3,
  /** The space round everything, and between groups. */
  pad: 14,
  space: 10,

  /** The top bar: its height, the title's size, its items', their small print, the dividers' room either side. */
  topBar: 62,
  title: 40,
  topText: 25,
  topSmall: 13,
  topRoom: 18,
  /** A meter under a top-bar figure: its length and thickness. */
  meter: 140,
  meterThick: 6,
  /** The course's arrows, square. */
  arrow: 30,

  /** The slot tabs down the left: across, at most high, between two, the icon's box, the words. */
  tabW: 180,
  tabH: 50,
  tabMin: 34,
  tabGap: 8,
  tabIcon: 26,
  tabText: 21,
  /** How far the chosen tab's point reaches past its edge. */
  tabPoint: 14,

  /** How it drives, on the right: across, its heading, its rows, a bar's thickness, a row's height. */
  side: 320,
  sideHead: 28,
  sideText: 18,
  sideBar: 9,
  sideRow: 30,

  /** The kart's name, its banner over the kart. */
  banner: 48,
  bannerPad: 22,

  /** The strip along the bottom: high, the slot's name in it, and its column. */
  strip: 168,
  stripTitle: 38,
  stripTitleW: 150,
  /** A part's card: across, high, between two, its picture's box, its words, the chosen one's tick. */
  cardW: 142,
  cardH: 136,
  cardGap: 10,
  thumb: 92,
  cardText: 16,
  tick: 24,
  /** A size's card: its figure, and its buttons. */
  sizeText: 30,
  stepper: 34,

  /** Race!: across, high, its words, and the key on it. */
  raceW: 270,
  raceH: 96,
  raceText: 48,
  keyText: 15,
  keyPad: 6,

  /** The line about the part last picked, over the strip. */
  note: 15,

  /** The controls card (`controls-card.ts`): a key cap square, its letter, between two caps, between two groups,
   * a group's word under its caps, and the room round it all on its plate. */
  cap: 34,
  capText: 20,
  capGap: 5,
  capGroup: 22,
  capLabel: 14,
  capPad: 12,

  /** The general screens: a heading, body text, small print, a plate's padding, a button's words. */
  head: 34,
  body: 19,
  small: 15,
  platePad: 18,
  button: 24,
  buttonH: 48,
} as const;

/** The look's colours, as numbers. */
export const KIT_COLOUR = {
  /** The bars across the top and bottom, a plate, a card or tab (all dark slate), and their pale slate rim. */
  bar: 0x1b2540,
  plate: 0x1b2540,
  card: 0x1b2540,
  cardHover: 0x26345a,
  edge: 0x4a5f8c,
  edgeDim: 0x2e3b5c,
  /** The red: what to press, the run's accents; its shade and its glow. */
  hot: 0xe2282d,
  hotDark: 0x9c1218,
  hotLight: 0xff5a4f,
  /** The green: the buttons that go on -- Race!, Next course, Resume, Start; its shade and its glow. */
  go: 0x22b83f,
  goDark: 0x10702a,
  goLight: 0x3fdc5c,
  /** The blue: what is chosen (a tab, a part, a course, you on a board); its glow. */
  pick: 0x2fa8ff,
  pickLight: 0x7fd8ff,
  /** Words: cream on the dark panels, and the quieter ones; `ink` the words on red or blue (white); `light` words straight on the
   * world (white, outlined navy). */
  text: 0xf6efe0,
  dim: 0x9fb0d0,
  ink: 0xffffff,
  light: 0xffffff,
  /** A rating's bar and its groove; a meter's groove. */
  good: 0x39ff5a,
  groove: 0x2f3b58,
  /** A chequered flag's dark squares, and a key cap. */
  flagDark: 0x0a1028,
  key: 0xfcf1d8,
  /** A part with no picture: the glyph drawn in its stead. */
  glyph: 0xe8eefc,
  /** A sticker's drop shadow. */
  shadow: 0x050914,
} as const;

/** The look's opacities. */
export const KIT_ALPHA = {
  /** The bars and plates over the world. */
  bar: 0.97,
  plate: 0.97,
  /** A card a part with no picture behind its glyph. */
  shine: 0.08,
} as const;
