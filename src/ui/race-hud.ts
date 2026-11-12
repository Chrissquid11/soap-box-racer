/**
 * The run on the HUD, after the HUD mockup: top left, LIVE and the game's name on a dark slanted tag, the course
 * and its run number on a cream one under it; in the middle, the big words on an orange banner between two
 * chequered flags -- the countdown, GO!, what just happened (BIG AIR, the driver overboard) -- and the news under
 * it; bottom left, the kart (its number, its name, whether its driver is aboard; its style and what is left of it);
 * bottom right, the run's time and the gold target; top middle, big, the speed in mph. Over the line, the
 * results: the three medals (race time, showmanship, survival), what went wrong and what to change, and buttons
 * to go again or back to the garage.
 * The garage itself (`garage.ts`) shows while the kart waits there.
 *
 * Told by `raceHud`, a render system the game installs (`src/game/index.ts`), which reads the kart
 * every frame and hands the world to `live.ts` for the garage; each `set` redraws only on a change.
 */
import { Container, Graphics } from 'pixi.js';
import { Camera, Transform, type World } from '@vibe/engine';
import { SIZE_U, type Units, type Widget } from '@vibe/engine/ui';
import { BODY, CHASSIS, newRating, rate, type Choice, type Rating, STARTER } from '../game/build.ts';
import { CREATIVITY_MEDALS, CREATIVITY_POINTS, racePoints, runPoints, styleMedals } from '../game/score.ts';
import { COURSES, difficultyOf, DIFFICULTIES, TRACKS } from '../game/courses.ts';
import { scoreTarget, standings, TOP_PLACES } from '../game/rivals.ts';
import { weatherOf } from '../game/weather.ts';
import { Build, Cause, ChaseCam, CRASHED_FOR, ROOF_FOR, Kart, News, OUT_FOR, PartName, PartState, Phase, RunOut } from '../game/components.ts';
import { rotate, v3 } from '../game/kart-math.ts';
import { CRAWL_OUT_FOR, crippled } from '../game/damage.ts';
import type { CourseSelect } from './course-select.ts';
import type { Garage } from './garage.ts';
import { KARTY_COLOUR, KIT_COLOUR, KIT_M } from './karty-theme.ts';
import { flag, glyph, KLabel, plate, slant } from './kit.ts';
import { Audio } from '@vibe/engine/assets';
import { SIGNATURES } from '../game/signatures.ts';
import { touchFirst } from './touch-controls.ts';

/** A touch screen: the touch controls take the bottom corners. */
const TOUCH = touchFirst();
import { League } from './league.ts';
import { Confetti } from './confetti.ts';
import { live, Order, orderRace, readBuild, screen, setCourse, setMenu, setOpen } from './live.ts';
import { bestTime, finished, isOpen, openCount } from './progress.ts';
import { flagWidth, headingWidth, placeHeading, rule } from './screen-kit.ts';
import { css, phoneSized, SCREEN_ALPHA, SCREEN_COLOUR, SCREEN_CSS, SCREEN_M, SCREEN_U } from './screen-theme.ts';
import { SlantButton } from './slant-button.ts';
import { ControlsCard } from './controls-card.ts';

/** The field's plate over the countdown, across (in `m`). */
const FIELD_W = 430;
/** The crash cam's bars, each a share of the screen's height. */
const LETTERBOX = 0.1;
const MEDAL_NAMES = ['Gold', 'Silver', 'Bronze', 'No medal'] as const;
const MEDAL_COLOURS = [KARTY_COLOUR.gold, KARTY_COLOUR.silver, KARTY_COLOUR.bronze, KARTY_COLOUR.none] as const;

/** The kart's store, as `world.store(Kart)` gives it. */
const kartStoreOf = (world: World) => world.store(Kart);
type KartStore = ReturnType<typeof kartStoreOf>;

/** The judges' three pillars for a run, each a medal and what earned it, and the total. */
interface Verdict {
  medals: [number, number, number];
  values: [string, string, string];
  total: number;
  whole: boolean;
}

/**
 * Judged on the three pillars: creativity (the kart: how outrageous it is), showmanship (the style of its jumps, in
 * the air on the way down), and speed (the time, which only counts with the driver over the line inside the kart:
 * `race` finishes no run without them). A run that ended short of the line still has its creativity and its style.
 */
function judge(kart: KartStore, e: number, rating: Rating, course: number, finishedRun: boolean, weather: number): Verdict {
  const creativity = Math.round(rating.appeal * CREATIVITY_POINTS);
  const showman = Math.round(kart.style[e]!);
  const time = kart.finishTime[e]!;
  const whole = finishedRun && kart.wheelsLost[e] === 0 && kart.bodyLost[e] === 0 && kart.ejections[e] === 0;
  // Race time: where the time places among everyone who finished.
  const race = finishedRun ? standings(course, weather, time).yourRace : 0;
  const medals: [number, number, number] = [
    medalFor(creativity, CREATIVITY_MEDALS, false),
    medalFor(showman, styleMedals(course), false),
    race >= 1 && race <= 3 ? race - 1 : 3,
  ];
  const values: [string, string, string] = [
    `${creativity} points`,
    `${showman} points`,
    finishedRun ? `${racePoints(race)} points  ·  ${ordinal(race)}  ·  ${clockText(time)}` : 'did not finish',
  ];
  const total = runPoints(rating.appeal, showman, race, whole);
  return { medals, values, total, whole };
}
/** Metres a second to miles an hour: the speed is shown in mph. */
const MPH = 2.23694;
/** The results animated in, seconds: the plate rising (from this far below, in the menus' unit) and fading up; the
 * stickers stamped on (the first after STICKER_IN, then one each STICKER_GAP, each STICKER_STAMP long, from this
 * much bigger, bouncing back this much); the buttons after BUTTONS_IN; all still after RESULTS_IN_END. */
const RESULTS_RISE = 0.35;
const RESULTS_RISE_BY = 40;
const STICKER_IN = 0.9;
const STICKER_GAP = 0.25;
const STICKER_STAMP = 0.3;
const STICKER_FROM = 1.2;
const STICKER_BOUNCE = 0.08;
const BUTTONS_IN = 0.6;
const RESULTS_IN_END = 3;
/** The most stickers the results show (the awards, and a course unlocked). */
const STICKERS = 4;
/** The results plate's share of the screen across at most, the buttons' size over the menus' unit, and the stickers'
 * tilt (radians). */
const RESULT_SHARE = 0.46;
const RESULT_SHARE_TALL = 0.94;
/** The courses where the hills first get steep (3, 4 and 5: their drops half again the first two's): the countdown
 * reminds the player to brake. */
const BRAKE_REMINDER: ReadonlySet<number> = new Set([2, 3, 4]);
/** The results plate's opacity: the world (the kart, the crowd) seen through it. */
const RESULT_ALPHA = 0.72;
const RESULT_BUTTONS = 1.45;
const STICKER_TILT = 0.07;
/** The controls card at the first race: seconds into the run it stays up; and where the browser remembers it was seen
 * (a convenience only: without storage it shows each first-course run). */
const CONTROLS_FOR = 6;
/** The controls card's size over the HUD's unit: big enough to read at a glance. */
const CONTROLS_SCALE = 1.35;
const CONTROLS_SEEN = 'soapbox-controls-seen';
let controlsSeenNow = false;
function controlsSeen(): boolean {
  if (controlsSeenNow) return true;
  try { controlsSeenNow = globalThis.localStorage?.getItem(CONTROLS_SEEN) === '1'; } catch { /* no storage: shown */ }
  return controlsSeenNow;
}
function markControlsSeen(): void {
  controlsSeenNow = true;
  try { globalThis.localStorage?.setItem(CONTROLS_SEEN, '1'); } catch { /* no storage: this session only */ }
}
/** The results' score line (Score, a new best, what it unlocked), this much bigger than body text. */
const SCORE_SCALE = 1.5;
/** The clock's size, of what it was as a corner plate: half, under the speed. */
const CLOCK_SCALE = 0.5;
/** Seconds a piece of news stays up. */
const NEWS_FOR = 1.3;
/** Seconds a part's change of state stays up in the lower third (`damage.ts`' callout). */
const THIRD_FOR = 2.6;
/** What the lower third says of each part (`PartName`'s order), damaged and failed. */
const PART_WORDS: readonly (readonly [string, string, string])[] = [
  ['Left front wheel', 'bent', 'gone'],
  ['Right front wheel', 'bent', 'gone'],
  ['Left rear wheel', 'buckled', 'gone'],
  ['Right rear wheel', 'buckled', 'gone'],
  ['Left front suspension', 'sagging', 'failed'],
  ['Right front suspension', 'sagging', 'failed'],
  ['Left rear suspension', 'sagging', 'failed'],
  ['Right rear suspension', 'sagging', 'failed'],
  ['Bodywork', 'dented', 'off'],
];
/** The lower third's words for a part now in `state` ('' for none). */
function partWords(part: number, state: number): string {
  // A wheel off: the big WHEEL LOST! banner says so already -- nothing under it.
  if (part <= PartName.wheelRR && state === PartState.failed) return '';
  const w = PART_WORDS[Math.min(part, PartName.body)]!;
  return `${w[0]} ${state === PartState.failed ? w[2] : w[1]}`;
}
/** The kart's number: the one on the driver's overalls. */
const KART_NUMBER = 7;

function clockText(seconds: number): string {
  const s = Math.max(0, seconds);
  const minutes = Math.floor(s / 60);
  const rest = s - minutes * 60;
  return `${minutes}:${rest < 10 ? '0' : ''}${rest.toFixed(2)}`;
}

/** Two digits: 06. */
/** 1st, 2nd, 3rd, 4th... */
function ordinal(n: number): string {
  const tail = n % 10 === 1 && n !== 11 ? 'st' : n % 10 === 2 && n !== 12 ? 'nd' : n % 10 === 3 && n !== 13 ? 'rd' : 'th';
  return `${n}${tail}`;
}

function two(n: number): string {
  return String(n).padStart(2, '0');
}

/** The run's clock as the HUD shows it: 00:01.56. */
function runClock(seconds: number): string {
  const s = Math.max(0, seconds);
  const minutes = Math.floor(s / 60);
  const rest = s - minutes * 60;
  return `${two(minutes)}:${rest < 10 ? '0' : ''}${rest.toFixed(2)}`;
}

/** 0 gold .. 3 none: less is better for a time, more for style. */
function medalFor(value: number, limits: readonly [number, number, number], lessIsBetter: boolean): number {
  for (let i = 0; i < 3; i++) if (lessIsBetter ? value <= limits[i]! : value >= limits[i]!) return i;
  return 3;
}

/** Each wheel as the damage callouts name it (`PartName`'s first four, `Corner`'s order). */
const WHEEL_WORDS = ['FRONT WHEEL', 'FRONT WHEEL', 'BACK WHEEL', 'BACK WHEEL'] as const;
/**
 * What damage says: short, and what it means for the kart -- which wheel, and what it does now (a bent front pulls, a
 * bent back slides; a wheel off leaves so many), the steering gone, the driver out. `part` the part it hit
 * (`Kart.callPart` as it was said), `lost` the wheels gone by then, `body` the kart's bodywork.
 */
function damageText(kind: number, part: number, _lost: number, body: number): string {
  const wheel = WHEEL_WORDS[part] ?? 'WHEEL';
  const front = part === PartName.wheelFL || part === PartName.wheelFR;
  switch (kind) {
    case News.lostWheel: return 'WHEEL LOST!';
    case News.bent: return `${wheel} BENT · ${front ? 'PULLS' : 'SLIDES'}`;
    case News.lostBody: return lossText(body);
    case News.lostSteering: return 'NO STEERING!';
    case News.thrown: return 'THROWN OUT!';
    case News.wrecked: return 'WRECKED!';
    default: return '';
  }
}

/** The damage the run says: shouted (as a bonus is) flashing reds, and said under the shouts in red. */
const DAMAGE_NEWS: ReadonlySet<number> = new Set([News.lostWheel, News.lostBody, News.thrown, News.lostSteering, News.bent, News.wrecked]);
const DAMAGE_RED_LIGHT = 0xff6a5a;

/** A bonus star grabbed, a stunt pulled or damage done: shouted with no banner, the words alone up in the world over
 * the kart -- BONUS_SIZE times the banner's words, popping in and floating up, held steady (no pulsing, wobbling or
 * flashing), in their colour: gold for a bonus, green for a stunt, red for damage, each outlined dark. A bonus
 * says what it scores: SHOWMANSHIP +n (it adds to that pillar). (The countdown and GO keep the orange banner.) */
/** The results' medal rows, top to bottom, by pillar (0 creativity, 1 showmanship, 2 race time). */
const MEDAL_ROWS = [2, 1, 0] as const;
const BONUS_SIZE = 0.87;
/** The kart's plate (its number and name, OVERBOARD after it) bottom left in the run: off. */
const KART_PLATE = false;
/** A finish in the top PODIUM places is shouted: its words this times the banner's, popping in over PODIUM_POP seconds
 * (overshooting this much), then pulsing this much, this many times a second, tilting this far (radians); sitting
 * this far down the screen (a share). */
const PODIUM = 3;
const PODIUM_SIZE = 1.7;
const PODIUM_POP = 0.45;
const PODIUM_OVER = 0.35;
const PODIUM_PULSE = 0.04;
const PODIUM_HZ = 1.2;
const PODIUM_TILT = 0.06;
const PODIUM_AT = 0.3;
/** The countdown's numbers: this times the banner's words, their black outline and their drop shadow as shares of that. */
const COUNT_SIZE = 2.4;
const COUNT_OUTLINE = 0.07;
const COUNT_DROP = 0.06;
/** A bit of the results' confetti, this times the banner's words across. */
const CONFETTI_BIT = 0.3;
/** The kart's plate, bottom left (its number and name), this times its theme size. */
const KART_SCALE = 0.7;
/** The bonus words over the star: this high above it (metres), floating up this fast (m/s); full size this near (metres),
 * held between these sizes further and nearer. */
const BONUS_LIFT = 1.6;
const BONUS_RISE = 0.8;
const BONUS_NEAR = 9;
const BONUS_FAR = [0.55, 1.3] as const;
/** How fast the words' place on screen catches up with the kart they ride over: a share a second (higher, tighter). */
const BONUS_FOLLOW = 9;
const LOCAL = v3();
const RAINBOW = [0xffe23a, 0xff9a1f, 0xff4fa8, 0x4fe0ff, 0x7dff5a, 0xffffff] as const;
const GREENS = [0x5cff4a, 0xc4ff3a, 0x2ee86f, 0xffffff, 0x9dff8a] as const;
const REDS = [0xff2a2a, 0xff7a5a, 0xffffff, 0xe0141a, 0xffb0a0] as const;
/** The popping words' looks (`Pop`'s order, from 1): their colours, and their outline. */
const POP_COLOURS: readonly (readonly number[])[] = [[], RAINBOW, GREENS, REDS];
const POP_INKS = ['', css(0x3a0a4a), css(0x06300f), css(0x2a0505)] as const;
/** How a shout is shown: on the banner, or popping up in the world as a bonus, a stunt or damage. */
const Pop = { banner: 0, bonus: 1, stunt: 2, damage: 3 } as const;
type Pop = (typeof Pop)[keyof typeof Pop];
/** Seconds the words take to pop up to full size. */
const POP_IN = 0.12;

/** The news shouted big: the showmanship (`stunts`, big air). */
const STUNT_NEWS: ReadonlySet<number> = new Set([News.bigAir, News.cleanChicane, News.reverseFinish, News.twoWheels, News.drift, News.airSpin, News.limpedHome, News.bonus, News.clearedDucks, News.righted, News.spin, News.reversing]);

/**
 * The broadcast's callouts, one at a time: every event the run says (`Kart.news`) is queued, and shown in turn for
 * NEWS_FOR seconds -- the most urgent first (damage and recovery before stunts), the same kind not again within
 * NEWS_COOLDOWN seconds, and at most NEWS_QUEUE waiting (the oldest of the least urgent dropped). A new run clears it.
 */
const NEWS_COOLDOWN = 4;
/** Samples before the shortcut's split that the HUD says which way is which. */
const SPLIT_WARN = 28;
const NEWS_QUEUE = 4;
function newsPriority(kind: number): number {
  if (kind === News.go) return 3;
  if (kind === News.lostWheel || kind === News.lostBody || kind === News.thrown || kind === News.lostSteering || kind === News.wrecked
    || kind === News.bent || kind === News.righted || kind === News.backIn || kind === News.alone) return 2;
  return 1;
}
interface Callout { kind: number; value: number; at: number; x: number; y: number; z: number; part: number; lost: number }

/** What the kart's last news says, or nothing. */
function newsText(news: number, value: number): string {
  switch (news) {
    case News.go: return 'GO!';
    case News.bigAir: return `BIG AIR +${Math.round(value)}`;
    case News.cleanChicane: return `CHICANE +${Math.round(value)}`;
    case News.reverseFinish: return `BACKWARDS! +${Math.round(value)}`;
    case News.twoWheels: return `TWO WHEELS +${Math.round(value)}`;
    case News.drift: return `DRIFT +${Math.round(value)}`;
    case News.airSpin: return `SPIN +${Math.round(value)}`;
    case News.spin: return `360! +${Math.round(value)}`;
    case News.reversing: return `REVERSING +${Math.round(value)}`;
    case News.limpedHome: return `LIMPED HOME +${Math.round(value)}`;
    case News.clearedDucks: return 'DUCKS CLEARED!';
    case News.righted: return 'BACK UP!';
    case News.bonus: return `SHOWMANSHIP +${Math.round(value)}`;
    case News.backIn: return 'Back in!';
    case News.alone: return 'No driver!';
    default: return '';
  }
}

/** Each bodywork's part, as the shout names it when it comes off (`BODY`'s order). */
const BODY_BITS = ['BODYWORK', 'ROCKET', 'WINGS', 'SOFA', 'FRYER', 'SHELL', 'BOWL', 'TOASTER', 'SAUCER', 'PRAWN', 'CAN', 'FOOT', 'WING', 'SHELL', 'CRATE', 'VAN', 'PICKUP', 'PANELS', 'FINS', 'DOORS', 'ROCKET', 'SHARK', 'TACO', 'LOGS', 'PRAM', 'SUITCASES', 'TRUMPETS', 'CHIMNEY'] as const;
/** What losing bodywork `body` costs, shouted: WINGS GONE · LESS LIFT. */
function lossText(body: number): string {
  const bo = BODY[body];
  // A body whose breakup is a joke of its own says so instead (`signatures.ts`).
  const gag = bo && SIGNATURES[bo.name]?.caption;
  if (gag) return gag;
  const name = BODY_BITS[body] ?? 'BODYWORK';
  if (!bo) return `${name} GONE`;
  const what: string[] = [];
  if (bo.wing > 0) what.push('LESS LIFT');
  if (bo.thrust > 0) what.push('NO BOOST');
  if (bo.cushion > 0) what.push('LESS GRIP ON YOU');
  if (bo.drag < 0) what.push('MORE DRAG');
  else if (bo.drag >= 0.15) what.push('LESS DRAG');
  what.push('LESS STYLE');
  return `${name} GONE · ${what[0]}`;
}

/** Seconds after crossing the finish line before the results come up. */
const RESULTS_AFTER = 2;

/** A run's countdown to its end shows once one of its reasons has lasted this many seconds. */
const WARN_AFTER = 2;
/** A kart crippled by damage and crawling: its countdown shows almost at once (its run ends after CRAWL_OUT_FOR). */
const CRAWL_WARN = 0.4;

/** The awards a finish earns, from what happened in the run (`Kart`'s record of it): at most AWARDS_SHOWN shown.
 *  - Three-Wheel Wonder: over the line with exactly three wheels on.
 *  - Backwards Into Glory: over the line going backwards.
 *  - Most Parts Lost: at least MANY_PARTS real parts lost on the way (wheels, the bodywork, the steering -- never the
 *    splinters and shards that fly off as effects).
 *  - Fastest Bathtub: a new best time on the course in the bathtub chassis, beating the last (`progress.ts`). */
const AWARDS_SHOWN = 3;
const MANY_PARTS = 3;
function awards(kart: KartStore, e: number, tubBest: boolean): string[] {
  const out: string[] = [];
  const lost = kart.wheelsLost[e]! + kart.bodyLost[e]! + (kart.steerOn[e] ? 0 : 1);
  if (kart.wheelsLost[e] === 1) out.push('Three-Wheel Wonder');
  if (kart.backwards[e]) out.push('Backwards Into Glory');
  if (lost >= MANY_PARTS) out.push('Most Parts Lost');
  if (tubBest) out.push('Fastest Bathtub');
  return out;
}

/** One thing worth knowing about the run, only when what was recorded in it says so; '' when nothing does (the
 * results' usual advice stands then). */
const CORNER_WORDS = ['front left', 'front right', 'rear left', 'rear right'] as const;
function observe(kart: KartStore, e: number, finishedRun: boolean): string {
  const cut = kart.cutHurt[e]!;
  if (cut) {
    const front = cut & 3, rear = cut & 12;
    const which = front && !rear ? 'front wheels' : rear && !front ? 'rear wheels' : 'wheels';
    const one = [0, 1, 2, 3].filter((k) => cut & (1 << k));
    return `Your ${one.length === 1 ? `${CORNER_WORDS[one[0]!]} wheel` : which} buckled on the shortcut landing.`;
  }
  if (kart.rolledAt[e]! >= 0) {
    const at = kart.rolledAt[e]!;
    return `You tipped over ${at > 0.8 ? 'in the final bend' : at > 0.45 ? 'halfway down' : 'early on'}.`;
  }
  if (finishedRun && kart.hurts[e] === 0 && !kart.tookCut[e] && TRACKS[Math.min(kart.course[e]!, TRACKS.length - 1)]!.cut) {
    return 'You finished cleanly. Try the shortcut for a faster time.';
  }
  return '';
}

/** Why a run ended short of the line, in a few words. */
function outWords(out: number): string {
  switch (out) {
    case RunOut.offTrack: return 'Off the track';
    case RunOut.driverOut: return 'Thrown out';
    case RunOut.stopped: return 'Race over';
    case RunOut.crashed: return 'Crashed out';
    case RunOut.wrecked: return 'Wrecked';
    case RunOut.pond: return 'In the duck pond';
    default: return 'Over';
  }
}

/** What to try instead, when nothing broke: one short tip. */
function outHelp(out: number): string {
  switch (out) {
    case RunOut.offTrack: return 'Brake before the bends.';
    case RunOut.driverOut: return 'Land softer, or pick a comfier seat.';
    case RunOut.stopped: return 'Steer clear and push off (W).';
    case RunOut.crashed: return 'A wider, lower kart stays on its wheels.';
    case RunOut.wrecked: return 'Hit less hard, or pick a tougher chassis.';
    case RunOut.pond: return 'Hit the jump faster and straight, or take the road round.';
    default: return '';
  }
}

/** Why the run went as it did, and the one change most likely to help -- from the last cause and the build. */
function explain(cause: number, c: Choice, r: Rating): string {
  switch (cause) {
    case Cause.wheelLanding:
      return c.suspension === 0 ? 'Wheel snapped on a landing: fit suspension.' : 'Wheel snapped on a landing: softer springs, or slower jumps.';
    case Cause.wheelKnock:
      return 'Wheel knocked off: give the hazards more room.';
    case Cause.bodyKnock:
      return `${BODY[c.body]!.name} knocked off: hit less.`;
    case Cause.thrownKnock:
      return 'Thrown out by a hit: brake before the hazards.';
    case Cause.thrownLanding:
      return c.suspension === 0 ? 'Bounced out on a landing: fit suspension.' : 'Bounced out on a landing: take the jump slower.';
    case Cause.rolled:
      return r.tip < 0.85 ? 'Rolled: too top heavy. Go wider or lower.' : 'Rolled: brake before the corners.';
    case Cause.wrecked:
      return `Wrecked: a sturdier chassis than the ${CHASSIS[c.chassis]!.name.toLowerCase()} takes more.`;
    default:
      return '';
  }
}

export class RaceHud implements Widget {
  readonly id = 'race';
  readonly view = new Container({ label: 'race' });

  // The run's HUD, shown while racing: every plate drawn into `plates`.
  private readonly run = new Container({ label: 'run' });
  private readonly plates = new Graphics();
  /** Top left: LIVE, the game's name; the course and its run number; the keys. */
  private readonly liveWord = new KLabel({ size: SCREEN_U.tagText, caps: true, fill: KIT_COLOUR.text }, 'Live');
  private readonly gameName = new KLabel({ size: SCREEN_U.tagText, caps: true, fill: KIT_COLOUR.text }, document.title);
  private readonly courseLine = new KLabel({ size: SCREEN_U.subText, caps: true, fill: SCREEN_COLOUR.creamInk }, '');
  /** The controls as keys, bottom middle: at the start of the player's first race only (`CONTROLS_FOR`). */
  private readonly controls = new ControlsCard();
  /** Bottom left: the kart's number, its name, whether its driver is aboard; the style and what is left of it. */
  private readonly kartNum = new KLabel({ size: SCREEN_U.numText, fill: KIT_COLOUR.ink }, `#${KART_NUMBER}`);
  private readonly kartName = new KLabel({ size: SCREEN_U.nameText, caps: true, fill: KIT_COLOUR.text }, '');
  private readonly kartState = new KLabel({ size: SCREEN_U.stateText, caps: true, fill: KIT_COLOUR.text }, '');
  /** Bottom right: the run's time, the gold target, the speed. */
  private readonly runLabel = new KLabel({ size: SCREEN_U.clockLabel, caps: true, fill: SCREEN_COLOUR.creamInk }, 'Time');
  private readonly time = new KLabel({ size: SCREEN_U.clockText, fill: SCREEN_COLOUR.creamInk }, '');
  /** The callouts waiting, the one on show (since when), the last event read, and when each kind last showed. */
  private readonly callouts: Callout[] = [];
  private callout: Callout | null = null;
  private calloutSince = 0;
  private lastNewsAt = -99;
  private readonly lastShown = new Map<number, number>();
  private readonly speed = new KLabel({ size: SCREEN_U.speedText, fill: KARTY_COLOUR.gold }, '');
  /** The middle: the banner's words (the countdown, GO!, a crash), and the news under it. */
  /** Whether what is shouted (or said) now is damage: drawn red. */
  private shownDamage = false;
  /** Whether what is shouted now is a bonus grabbed: its own pink, rainbow look. */
  private shownPop: Pop = Pop.banner;
  /** The countdown's numbers on show: big white words, outlined black, no banner. */
  private shownCount = false;
  /** The bonus words' place on screen when not over the star, their outline, and the rainbow colour shown (-1 none yet). */
  private bonusX = 0;
  private bonusY = 0;
  /** The words' place on screen as last drawn, eased toward where they belong; and when (`t`) and of which callout. */
  private popX = 0;
  private popY = 0;
  private popFar = 1;
  private popT = -1;
  private popOf: Callout | null = null;
  private bonusOutline = 0;
  private bonusFill = -1;
  /** The screen's size (for the bonus words placed in the world), and the chasing camera's query, made once. */
  private hudW = 0;
  private hudH = 0;
  private cams: { readonly members: ArrayLike<number>; readonly count: number } | null = null;
  private camsOf: World | null = null;
  private readonly shout = new KLabel({ size: SCREEN_U.bannerText, caps: true, fill: KIT_COLOUR.ink, align: 'center' }, '');
  /** The crash cam's letterbox, and its tag: shown while `slowmo` runs. */
  private readonly letterbox = new Graphics();
  private readonly slowTag = new KLabel({ size: SCREEN_U.tagText, caps: true, fill: KARTY_COLOUR.bad }, '● SLOW-MO');
  private slowShown = false;
  /** The broadcast's lower third, bottom left over the kart: a part's damage as it happens. */
  private readonly third = new KLabel({ size: SCREEN_U.subText, caps: true, fill: KIT_COLOUR.ink }, '');
  private readonly news = new KLabel({ size: SCREEN_U.news, fill: KIT_COLOUR.light, outline: SCREEN_U.newsOutline, outlineColour: SCREEN_CSS.ink, align: 'center' }, '');

  // The results.
  private readonly results = new Container({ label: 'results' });
  /** Seconds since the results came up (their animation in), and the menus' unit from the last layout. */
  private resultsT = 99;
  /** Over the line in the top three: the place shouted big and gold (`podiumT` seconds since), till the results. */
  private readonly podium = new KLabel({ size: SCREEN_U.bannerText, caps: true, fill: KARTY_COLOUR.gold, align: 'center' }, '');
  private podiumPlace = 0;
  private podiumT = 99;
  /** The run opened the next course: the results come up with confetti and a fanfare. */
  private qualified = false;
  private readonly confetti = new Confetti();
  private m = 1;
  private readonly panel = new Graphics();
  private readonly deco = new Graphics();
  private readonly heading = new KLabel({ size: SCREEN_M.heading, caps: true, fill: KIT_COLOUR.text, shadow: 'soft' }, '');
  private readonly medalNames: KLabel[] = [];
  private readonly medalValues: KLabel[] = [];
  private readonly why = new KLabel({ size: SCREEN_M.small, fill: KIT_COLOUR.dim }, '');
  /** The league table: the rivals who rode before, and the player (always last to ride) placed among them. */
  private readonly board = new League();
  private readonly unlocked = new KLabel({ size: SCREEN_M.body, fill: KIT_COLOUR.good }, '');
  /** The results' stickers, on the right over the world: each an award won (THREE-WHEEL WONDER ...) or the next
   * course unlocked -- tilted, chunky, the unlock red. Up to STICKERS of them; their words, and which is the unlock. */
  private readonly stickers: { view: Container; back: Graphics; words: KLabel }[] = [];
  private stickerWords: string[] = [];
  private stickerHot: boolean[] = [];
  /** Over the countdown: the field to beat, the player next to ride. */
  private readonly field = new Container({ label: 'field' });
  private readonly fieldPlate = new Graphics();
  /** The level's intro, over the field: the course (its number, its name), what opens the next and the weather, the best. */
  private readonly introName = new KLabel({ size: SCREEN_M.heading, caps: true, fill: KIT_COLOUR.text }, '');
  private readonly introGoal = new KLabel({ size: SCREEN_M.body, caps: true, fill: KIT_COLOUR.text }, '');
  private readonly introBest = new KLabel({ size: SCREEN_M.small, fill: KIT_COLOUR.dim }, '');
  private readonly fieldHead = new KLabel({ size: SCREEN_M.body, caps: true, fill: KIT_COLOUR.text }, 'The field');
  private readonly fieldBoard = new League();
  private shownField = '';
  private readonly again = new SlantButton('again', 'Retry', () => orderRace(Order.restart), 'plain');
  /** On to the course select: every course and its progress, the next one to race, or the garage. */
  private readonly onward = new SlantButton('continue', 'Continue', () => {
    // On to the next course's garage when it is open (the build kept), else the course select.
    if (this.nextOpen >= 0) {
      setCourse(this.nextOpen);
      orderRace(Order.garage);
      screen.now = 'garage';
    } else this.selecting = true;
  }, 'hot');
  /** The course after this one, when the run's finish has it open (-1: none). */
  private nextOpen = -1;
  private readonly garage = new SlantButton('garage', 'Garage', () => orderRace(Order.garage), 'plain');
  /** The flyover's Skip, bottom middle. */
  private readonly skip = new SlantButton('skip-flyover', 'Skip', () => orderRace(Order.skip), 'hot');
  /** The start's state as shown: 0 none, 1 the flyover (Skip), 2 waiting for the player (Start). */
  private shownStart = 0;
  /** The results put away for the course select, until the next run. */
  private selecting = false;
  private selectWidget: CourseSelect | null = null;

  private units: Units | null = null;
  private shownCentis = -1;
  private shownMph = -1;
  private shownCourse = -1;
  /** The build the kart's name was read from (its body and chassis), and whether its driver is out. */
  private shownLook = -1;
  private shownOut = false;
  private shownShout = '';
  private shownNews = '';
  private shownThird = '';
  private shownResults = '';
  /** Each medal row's medal, for its laurel's colour. */
  private readonly medalShown = [3, 3, 3];
  private readonly choice: Choice = { ...STARTER };
  private readonly rating: Rating = newRating();
  private garageWidget: Garage | null = null;

  constructor() {
    for (const name of ['Creativity', 'Showmanship', 'Race time']) {
      const n = new KLabel({ size: SCREEN_M.rowText, fill: KIT_COLOUR.dim }, name);
      const v = new KLabel({ size: SCREEN_M.rowText, caps: true, fill: KIT_COLOUR.text }, '');
      this.medalNames.push(n);
      this.medalValues.push(v);
    }
    for (let i = 0; i < STICKERS; i++) {
      const sticker = { view: new Container({ label: `sticker-${i}` }), back: new Graphics(), words: new KLabel({ size: SCREEN_M.heading, caps: true, fill: KIT_COLOUR.text, align: 'center' }, '') };
      sticker.view.addChild(sticker.back, sticker.words);
      sticker.view.visible = false;
      this.stickers.push(sticker);
    }
    this.results.addChild(this.panel, this.deco, this.heading, this.unlocked, this.board.view, ...this.medalNames, ...this.medalValues, this.why, ...this.stickers.map((st) => st.view), this.again.view, this.onward.view, this.garage.view, this.confetti.view);
    this.field.addChild(this.fieldPlate, this.introName, this.introGoal, this.introBest, this.fieldHead, this.fieldBoard.view);
    this.field.visible = false;
    this.skip.view.visible = false;
    this.results.visible = false;
    this.panel.eventMode = 'static';
    this.letterbox.visible = false;
    this.slowTag.visible = false;
    this.kartNum.visible = this.kartName.visible = this.kartState.visible = KART_PLATE;
    this.run.addChild(this.letterbox, this.slowTag, this.plates, this.field, this.skip.view, this.liveWord, this.gameName, this.courseLine, this.controls.view, this.kartNum, this.kartName, this.kartState, this.runLabel, this.time, this.speed, this.shout, this.news, this.third, this.podium);
    this.run.visible = false;
    this.view.addChild(this.run, this.results);
  }


  /** The garage widget, shown and hidden with the phase. */
  attach(garage: Garage): void {
    this.garageWidget = garage;
  }

  /** The course select, shown after the results once Continue is pressed. */
  attachSelect(select: CourseSelect): void {
    this.selectWidget = select;
  }

  /** The kart the furthest course was set for, once, as the game began. */
  private startedKart = -1;

  /** The kart as it stands this frame. */
  show(world: World, e: number): void {
    const kart = world.store(Kart);
    setOpen(openCount());
    const phase = kart.phase[e]!;
    // A new game (the page loaded, or the world built afresh): the furthest course unlocked, ready in the garage.
    if (e !== this.startedKart && phase === Phase.garage) {
      this.startedKart = e;
      setCourse(Math.max(0, Math.min(COURSES.length, openCount()) - 1));
      // ... and the kart put on its line (as every other change of course is): else it waits where the last course's
      // line was -- over (or in) the new course's ground -- and the garage shows the last course's weather.
      orderRace(Order.garage);
    }
    const clock = kart.clock[e]!;
    const racing = phase !== Phase.garage;
    // Off the course: the course select or the garage, each its own screen.
    this.garageWidget?.setVisible(!racing && screen.now === 'garage', e);
    setMenu(!racing && screen.now === 'courses');
    this.run.visible = racing;
    let moved = false;
    // The crash cam: letterboxed, tagged, while the slow motion runs.
    const slowNow = kart.slowFor[e]! > 0;
    if (slowNow !== this.slowShown) {
      this.slowShown = slowNow;
      this.letterbox.visible = slowNow;
      this.slowTag.visible = slowNow;
      moved = true;
    }

    // The course, its run number, and its gold target.
    const course = Math.min(kart.course[e]!, COURSES.length - 1);
    const sky = kart.weather[e]!;
    if (course * 16 + sky !== this.shownCourse) {
      this.shownCourse = course * 16 + sky;
      this.courseLine.set(sky === 0 ? `${two(course + 1)}  ${COURSES[course]!.name}` : `${two(course + 1)}  ${COURSES[course]!.name}  ·  ${weatherOf(sky).name}`);
      moved = true;
    }
    // The kart's name: its bodywork's, or its chassis's with none; and whether its driver is aboard.
    const build = world.store(Build);
    const body = build.body[e]!, chassis = build.chassis[e]!;
    const look = body * 100 + chassis;
    if (look !== this.shownLook) {
      this.shownLook = look;
      this.kartName.set(body > 0 && BODY[body] ? BODY[body]!.name : CHASSIS[chassis]?.name ?? '');
      moved = true;
    }
    const out = kart.ejected[e]! !== 0;
    if (out !== this.shownOut) {
      this.shownOut = out;
      this.kartState.set(out ? 'Overboard' : '');
      this.kartState.restyle({ fill: out ? KARTY_COLOUR.bad : KIT_COLOUR.text });
      moved = true;
    }

    const centis = Math.floor((phase === Phase.finished ? kart.finishTime[e]! : Math.max(0, clock)) * 100);
    // The clock and the speed change every frame: the whole HUD laid out again only when one's length changes (its
    // plate then needs to grow or shrink), never just for a digit -- a layout redraws every plate and measures every
    // label, too much to do sixty times a second.
    if (centis !== this.shownCentis) {
      this.shownCentis = centis;
      const was = this.time.text.length;
      this.time.set(runClock(centis / 100));
      if (this.time.text.length !== was) moved = true;
    }
    // The speed hidden on the grid (nought, and the arch's start lights are where it would stand): shown from GO.
    const speedOn = phase !== Phase.countdown;
    if (speedOn !== this.speed.visible) {
      this.speed.visible = speedOn;
      moved = true;
    }
    // The clock only once the kart is at the start: never over the flyover or the wait for Start.
    const clockOn = !(phase === Phase.countdown && kart.waiting[e]! !== 0);
    if (clockOn !== this.time.visible) {
      this.time.visible = clockOn;
      this.runLabel.visible = clockOn;
      moved = true;
    }
    const mph = Math.round(kart.speed[e]! * MPH);
    if (mph !== this.shownMph) {
      this.shownMph = mph;
      const was = this.speed.text.length;
      this.speed.set(`${mph} MPH`);
      if (this.speed.text.length !== was) moved = true;
    }

    // The big words: the countdown, then news while it is fresh.
    let shout = '';
    let news = '';
    let damage = false;
    let pop: Pop = Pop.banner;
    let go = false;
    const waiting = phase === Phase.countdown && kart.waiting[e]! !== 0;
    const flying = waiting && kart.flyover[e]! > 0;
    const startState = waiting ? (flying ? 1 : 2) : 0;
    if (startState !== this.shownStart) {
      this.shownStart = startState;
      this.skip.view.visible = waiting;
      this.skip.set(flying ? 'Skip' : 'Start');
      moved = true;
    }
    // Before a run (the grid, the countdown): nothing of the last run's callouts kept -- its GO among them, which this
    // run's GO, said at the same moment of its clock, would otherwise look like.
    if (waiting || phase === Phase.countdown || phase === Phase.garage) this.clearCallouts();
    if (waiting) {
      news = '';
    } else if (phase === Phase.countdown) {
      shout = String(Math.ceil(-clock));
      const warn = weatherOf(sky).warning;
      // Two short lines: what opens the next course, then the weather's one warning.
      const goal = course + 1 < COURSES.length && !isOpen(course + 1) ? `Finish top ${TOP_PLACES} to progress` : '';
      // The first of the steeper hills (BRAKE_REMINDER): a reminder first.
      const brake = BRAKE_REMINDER.has(course) ? "Don't forget to brake!" : '';
      news = [brake, goal, warn].filter(Boolean).join('\n');
    } else if (racing && phase !== Phase.over) {
      // Where it happened: over the star for a bonus, else where the kart is as it is said.
      const atBonus = kart.news[e] === News.bonus;
      const where = world.store(Transform);
      const shown = this.nextCallout(kart.news[e]!, kart.newsValue[e]!, kart.newsAt[e]!, clock,
        atBonus ? kart.newsX[e]! : where.px[e]!, atBonus ? kart.newsY[e]! : where.py[e]!, atBonus ? kart.newsZ[e]! : where.pz[e]!,
        kart.callPart[e]!, kart.wheelsLost[e]!);
      if (shown) {
        damage = DAMAGE_NEWS.has(shown.kind);
        const text = damage ? damageText(shown.kind, shown.part, shown.lost, build.body[e]!) : newsText(shown.kind, shown.value);
        // The big ones shouted: the stunts, and every breakage.
        if (shown.kind === News.go || STUNT_NEWS.has(shown.kind) || damage) shout = text;
        // GO! in the countdown's style: big white words, outlined black.
        // What is shouted is not said again under it: the line under the shout only for what is not shouted.
        if (shown.kind === News.go) go = true;
        else if (!shout) news = text;
        if (shout) pop = shown.kind === News.bonus ? Pop.bonus : damage ? Pop.damage : shown.kind === News.go ? Pop.banner : Pop.stunt;
      }
    }
    // Coming up to the split (the course's shortcut): which way is which, in time to choose.
    const cut = TRACKS[course]!.cut;
    if (phase === Phase.racing && !news && cut && kart.progress[e]! > cut.from - SPLIT_WARN && kart.progress[e]! < cut.from) {
      news = 'Split ahead  ·  Straight on: jump the duck pond  ·  Bear right: the road round';
    }
    if (phase === Phase.racing && !news && !kart.wrecked[e]) {
      // The run's end coming: a countdown once one of them has lasted a while.
      const off = kart.offFor[e]!, still = kart.stillFor[e]!;
      const worst = Math.max(off, still);
      if (kart.roofFor[e]! > 0.3 && !kart.ejected[e]) news = `Upside down!  ${Math.max(0, Math.ceil(ROOF_FOR - kart.roofFor[e]!))}`;
      else if (kart.stuck[e]! > 0.4 && !kart.ejected[e]) news = `Rocking it upright...  ${Math.max(0, Math.ceil(CRASHED_FOR - kart.stuck[e]!))}`;
      else if (worst > (worst === still && crippled(kart, e) ? CRAWL_WARN : WARN_AFTER)) {
        const left = Math.max(0, Math.ceil((worst === still && crippled(kart, e) ? CRAWL_OUT_FOR : OUT_FOR) - worst));
        news = worst === off ? `Off track!  ${left}` : `Get moving!  ${left}`;
      }
    }
    // The field over the countdown: who rode before, the player next.
    const fieldNow = waiting;
    if (fieldNow !== this.field.visible) {
      this.field.visible = fieldNow;
      moved = true;
    }
    // The controls, the first race only: from the countdown to CONTROLS_FOR seconds in, once ever (then remembered).
    const first = course === 0 && !controlsSeen() && !TOUCH;
    const controlsNow = first && ((phase === Phase.countdown && !waiting) || (phase === Phase.racing && clock < CONTROLS_FOR));
    if (first && phase === Phase.racing && clock >= CONTROLS_FOR) markControlsSeen();
    if (controlsNow !== this.controls.view.visible) {
      this.controls.view.visible = controlsNow;
      moved = true;
    }
    const fieldKey = fieldNow ? `${course}:${sky}:${look}` : '';
    if (fieldNow && fieldKey !== this.shownField) {
      this.shownField = fieldKey;
      this.fieldBoard.fill(course, sky, this.kartName.text, body, chassis);
      this.fieldBoard.play(false);
      this.introName.set(`${String(course + 1).padStart(2, '0')} / ${COURSES.length}  ${COURSES[course]!.name}  ·  ${DIFFICULTIES[difficultyOf(course)]}`);
      // What opens the next course: a top-three finish, or the score target.
      const goal = course + 1 < COURSES.length ? `Top ${TOP_PLACES} or ${scoreTarget(course)} pts unlocks next  ·  ` : '';
      this.introGoal.set(`${goal}${weatherOf(sky).name}`);
      const best = bestTime(course);
      this.introBest.set(best != null ? `Best ${best.toFixed(2)} s` : 'No best yet');
      moved = true;
    }
    // The lower third: the last part to change state, while fresh. Each change once.
    const third = racing && phase !== Phase.garage && kart.callAt[e]! > -1 && clock - kart.callAt[e]! < THIRD_FOR ? partWords(kart.callPart[e]!, kart.callState[e]!) : '';
    if (third !== this.shownThird) {
      this.shownThird = third;
      this.third.set(third);
      this.third.visible = third !== '';
      moved = true;
    }
    const counting = (phase === Phase.countdown && !waiting) || go;
    if (shout !== this.shownShout || news !== this.shownNews || damage !== this.shownDamage || pop !== this.shownPop || counting !== this.shownCount) {
      this.shownPop = pop;
      this.shownCount = counting;
      this.shownShout = shout;
      this.shownNews = news;
      this.shownDamage = damage;
      this.shout.set(shout);
      this.news.set(news);
      moved = true;
    }

    // The results, once over the line -- or the run over short of it; then, on Continue, the course select (the next
    // course lit: the one after, over the line; this one again, short of it).
    const over = phase === Phase.over;
    const done = phase === Phase.finished;
    // A new run: its results judged afresh when it ends -- even one ending just as the last did (the same time, the
    // same reason: the simulation is deterministic), which must still be recorded, placed and scored.
    if (!done && !over) {
      this.selecting = false;
      this.shownResults = '';
    }
    // Over the line, a moment to watch it cross (and the confetti fly) before the results come up.
    const settled = over || (done && clock - kart.finishTime[e]! >= RESULTS_AFTER);
    const resultsNow = settled && !this.selecting;
    // Up again (after a run, or back from the course select): animated in afresh.
    if (resultsNow && !this.results.visible) {
      this.board.play(true);
      this.resultsT = 0;
      // Through to the next course: a fanfare and confetti over it all.
      if (this.qualified && done) {
        Audio.sfx('unlock', { volume: 0.8, rate: 1 });
        Audio.sfx('fanfare', { volume: 0.6, rate: 1.06 });
        this.confetti.burst();
        this.qualified = false;
      }
    }
    // The podium shout: over the line, till the results.
    this.podium.visible = done && !resultsNow && this.podiumPlace > 0;
    this.results.visible = resultsNow;
    // The run's own HUD (the kart's plates, the clock, the speed ...) away under the results, and under the course
    // select after them: the results' panel, stickers and buttons have the screen to themselves.
    if (settled) this.run.visible = false;
    const here = Math.min(kart.course[e]!, COURSES.length - 1);
    this.selectWidget?.setVisible(((done || over) && this.selecting) || (!racing && screen.now === 'courses'), done ? Math.min(here + 1, COURSES.length - 1) : here);
    if (over) {
      const key = `over:${e}:${centis}:${kart.out[e]}`;
      if (key !== this.shownResults) {
        this.shownResults = key;
        readBuild(this.choice);
        rate(this.choice, this.rating);
        const c = Math.min(kart.course[e]!, COURSES.length - 1);
        // Still judged on its kart and its style; no time without a finish.
        const v = judge(kart, e, this.rating, c, false, kart.weather[e]!);
        this.heading.set(outWords(kart.out[e]!));
        this.unlocked.set(`Total Score ${v.total}`);
        this.unlocked.restyle({ fill: KARTY_COLOUR.warn });
        this.board.fill(c, kart.weather[e]!, this.kartName.text, build.body[e]!, build.chassis[e]!, v.total, null);
        this.board.play(true);
        this.resultsT = 0;
        for (let i = 0; i < 3; i++) {
          this.medalShown[i] = v.medals[i]!;
          this.medalValues[i]!.set(`${MEDAL_NAMES[v.medals[i]!]}  ·  ${v.values[i]}`);
          this.medalValues[i]!.restyle({ fill: MEDAL_COLOURS[v.medals[i]!] });
        }
        this.why.set(observe(kart, e, false) || (kart.cause[e] !== Cause.none ? explain(kart.cause[e]!, this.choice, this.rating) : outHelp(kart.out[e]!)));
        this.nextOpen = -1;
        this.onward.set('Courses');
        // Failed: nowhere onward to go -- Retry or the garage only.
        this.onward.view.visible = false;
        this.stickerWords = [];
        this.stickerHot = [];
        moved = true;
      }
    }
    if (done) {
      // Judged once, the moment it crosses: what it does in the run-out after (the bales are there to be hit) is not held against it.
      const key = `fin:${e}:${Math.round(kart.finishTime[e]! * 100)}`;
      if (key !== this.shownResults) {
        this.shownResults = key;
        readBuild(this.choice);
        rate(this.choice, this.rating);
        const time = kart.finishTime[e]!;
        const c = Math.min(kart.course[e]!, COURSES.length - 1);
        // Once a run: over the line opens the next course, and keeps a best.
        const w = kart.weather[e]!;
        const v = judge(kart, e, this.rating, c, true, w);
        const fin = finished(c, time, v.total, w, build.chassis[e]!);
        const place = fin.place;
        // Which condition opened the next course (or what it would take), and the run's awards.
        const next = c + 1 < COURSES.length ? COURSES[c + 1]!.name : '';
        const how = fin.by === 'top' ? 'a top-three finish' : `${v.total} pts, past the ${scoreTarget(c)} target`;
        const unlock = !next ? '' : fin.opened ? `  ·  ${next} unlocked by ${how}!` : isOpen(c + 1) ? '' : `  ·  Top ${TOP_PLACES} or ${scoreTarget(c)} pts opens ${next}`;
        const extra = fin.mastered ? '  ·  Mastered: first place!' : fin.best ? '  ·  New best!' : '';
        const won = awards(kart, e, fin.tubBest).slice(0, AWARDS_SHOWN);
        this.unlocked.set(fin.opened && next ? `Next race unlocked  ·  Total Score ${v.total}${extra}` : `Total Score ${v.total}${extra}${unlock}`);
        // Green when the next course is open (opened now, or already); red when it is still to earn.
        this.unlocked.restyle({ fill: !next || isOpen(c + 1) ? KIT_COLOUR.good : KARTY_COLOUR.warn });
        this.qualified = fin.opened && next !== '';
        this.podiumPlace = place <= PODIUM ? place : 0;
        this.podiumT = 0;
        if (this.podiumPlace > 0) {
          this.podium.set(place === 1 ? '1st place!' : `${ordinal(place)} place!`);
          Audio.sfx('fanfare', { volume: 0.9, rate: 1 });
          Audio.sfx('start_cheer', { volume: 0.28, rate: 1 });
        }
        this.stickerWords = [...won, ...(fin.opened ? [`${ordinal(place)} place`] : [])].slice(-STICKERS);
        this.stickerHot = this.stickerWords.map(() => false);
        this.nextOpen = next && isOpen(c + 1) ? c + 1 : -1;
        this.onward.set(this.nextOpen >= 0 ? 'Next course' : 'Courses');
        this.onward.view.visible = true;
        this.board.fill(c, w, this.kartName.text, build.body[e]!, build.chassis[e]!, v.total, time);
        this.board.play(true);
        this.resultsT = 0;
        for (let i = 0; i < 3; i++) {
          this.medalShown[i] = v.medals[i]!;
          this.medalValues[i]!.set(`${MEDAL_NAMES[v.medals[i]!]}  ·  ${v.values[i]}`);
          this.medalValues[i]!.restyle({ fill: MEDAL_COLOURS[v.medals[i]!] });
        }
        // Over the line in one piece is worth the most of all.
        // Over the line on three wheels: worth shouting about.
        // Opened the next course: QUALIFIED! over everything; else the place.
        this.heading.set(fin.opened && next ? 'Qualified!' : `${ordinal(place)} place${place === 1 ? '!' : ''}`);
        this.why.set(observe(kart, e, true) || explain(kart.cause[e]!, this.choice, this.rating));
        moved = true;
      }
    }
    // The karts' pictures, as their models load.
    if (this.results.visible) this.board.retry();
    if (this.field.visible) this.fieldBoard.retry();
    if (moved && this.units) this.layout(this.units);
    if (this.shownPop !== Pop.banner && this.shownShout) this.animateBonus(world, e, clock - this.calloutSince);
  }

  /** A displayed frame (real seconds): the league tables and the results animated in -- the plate rising and fading
   * up, the stickers stamped on one after another, the buttons last. */
  frame(dt: number): void {
    if (this.field.visible) this.fieldBoard.frame(dt);
    if (this.podium.visible) {
      // Popped in big and bouncing, then a steady wobble.
      this.podiumT += dt;
      const k = Math.min(1, this.podiumT / PODIUM_POP);
      const pop = k < 1 ? 1 + Math.sin(k * Math.PI) * PODIUM_OVER - (1 - k) * (1 - k) : 1 + Math.sin(this.podiumT * PODIUM_HZ * Math.PI * 2) * PODIUM_PULSE;
      this.podium.scale.set(Math.max(0, pop));
      this.podium.rotation = Math.sin(this.podiumT * PODIUM_HZ * Math.PI) * PODIUM_TILT;
    }
    this.confetti.frame(dt);
    if (!this.results.visible) return;
    this.board.frame(dt);
    if (this.resultsT > RESULTS_IN_END) return;
    this.resultsT += dt;
    const t = this.resultsT;
    const rise = Math.min(1, t / RESULTS_RISE);
    const ease = 1 - (1 - rise) * (1 - rise) * (1 - rise);
    this.results.alpha = ease;
    this.results.y = (1 - ease) * RESULTS_RISE_BY * this.m;
    for (let i = 0; i < this.stickers.length; i++) {
      const k = Math.min(1, Math.max(0, (t - STICKER_IN - i * STICKER_GAP) / STICKER_STAMP));
      // Stamped: big and faint, down hard, a little bounce.
      const s = k <= 0 ? 0 : 1 + (1 - k) * (1 - k) * STICKER_FROM - Math.sin(k * Math.PI) * STICKER_BOUNCE;
      this.stickers[i]!.view.scale.set(s);
      this.stickers[i]!.view.alpha = Math.min(1, k * 2);
    }
    const b = Math.min(1, Math.max(0, (t - BUTTONS_IN) / RESULTS_RISE));
    this.again.view.alpha = b;
    this.onward.view.alpha = b;
    this.garage.view.alpha = b;
  }

  /** The popping words, `t` seconds after they came up, riding over the kart `e` (projected through the chase camera,
   * their place on screen eased after it -- BONUS_FOLLOW -- so they glide with it, never jitter or jump; held where they
   * were while it is behind the camera): popped in (overshooting), then steady, floating up, in the first of their
   * colours -- scaled about their middle, smaller the further off. */
  private animateBonus(world: World, e: number, t: number): void {
    const label = this.shout;
    const colours = POP_COLOURS[this.shownPop]!;
    const colour = 0;
    if (colour !== this.bonusFill) {
      this.bonusFill = colour;
      label.restyle({ fill: colours[colour]! });
    }
    const box = label.lineBox;
    label.pivot.set(this.bonusOutline + box.width / 2, this.bonusOutline + box.height / 2);
    // Where: over the star, rising as it goes.
    const c = this.callout;
    const fresh = c !== this.popOf || t < this.popT;
    let x = fresh ? this.bonusX : this.popX, y = fresh ? this.bonusY : this.popY, far = fresh ? 1 : this.popFar;
    let seen = false;
    // (Asked of this world: a rebuild of the game -- a live swap -- makes a new one, the old query left behind.)
    if (c && (this.cams === null || this.camsOf !== world)) {
      this.cams = world.query({ with: [ChaseCam, Transform, Camera] });
      this.camsOf = world;
    }
    const cams = this.cams;
    if (c && cams && cams.count > 0 && this.hudW > 0) {
      const cam = cams.members[0]!;
      const at = world.store(Transform), lens = world.store(Camera);
      const dx = at.px[e]! - at.px[cam]!, dy = at.py[e]! + BONUS_LIFT + t * BONUS_RISE - at.py[cam]!, dz = at.pz[e]! - at.pz[cam]!;
      // Into the camera's own axes (its turn undone): it looks down its -z.
      rotate(-at.qx[cam]!, -at.qy[cam]!, -at.qz[cam]!, at.qw[cam]!, dx, dy, dz, LOCAL);
      if (LOCAL.z < -0.5) {
        const k = Math.tan(((lens.fov[cam]! || 60) * Math.PI) / 360);
        const wantX = (1 + LOCAL.x / (-LOCAL.z * k * (this.hudW / this.hudH))) * this.hudW / 2;
        const wantY = (1 - LOCAL.y / (-LOCAL.z * k)) * this.hudH / 2;
        const wantFar = Math.max(BONUS_FAR[0], Math.min(BONUS_FAR[1], BONUS_NEAR / -LOCAL.z));
        const ease = fresh ? 1 : 1 - Math.exp(-BONUS_FOLLOW * Math.max(0, t - this.popT));
        x += (wantX - x) * ease;
        y += (wantY - y) * ease;
        far += (wantFar - far) * ease;
        seen = true;
      }
    }
    if (seen || fresh) {
      this.popX = x;
      this.popY = y;
      this.popFar = far;
    }
    this.popT = t;
    this.popOf = c;
    // Popping in: from nothing, past full size, back.
    const s0 = Math.min(1, t / POP_IN) - 1;
    const pop = 1 + 2.7 * s0 * s0 * s0 + 1.7 * s0 * s0;
    label.scale.set(Math.max(0, pop) * far);
    label.rotation = 0;
    label.position.set(x, y);
  }

  /** The callout to show now: the event just said queued (once), the one on show kept for its while, then the most
   * urgent waiting. A run started afresh (its clock back before the last event) clears them all. */
  private clearCallouts(): void {
    if (this.callouts.length === 0 && this.callout === null && this.lastNewsAt === -99) return;
    this.callouts.length = 0;
    this.callout = null;
    this.lastShown.clear();
    this.lastNewsAt = -99;
  }

  private nextCallout(kind: number, value: number, at: number, clock: number, x: number, y: number, z: number, part: number, lost: number): Callout | null {
    if (at < this.lastNewsAt - 0.001 || clock < this.calloutSince - 0.001) {
      this.callouts.length = 0;
      this.callout = null;
      this.lastShown.clear();
      this.lastNewsAt = -99;
    }
    if (kind !== News.none && at > this.lastNewsAt) {
      this.lastNewsAt = at;
      const last = this.lastShown.get(kind);
      const waiting = this.callouts.find((c) => c.kind === kind);
      // Points earned -- a star, a stunt -- are never left unsaid: no cooldown; one of the same kind up or waiting
      // takes this one's points on top (two stars in a row: one pop with both), the one up shown afresh.
      const earned = kind === News.bonus || STUNT_NEWS.has(kind);
      if (earned && this.callout?.kind === kind && clock - this.calloutSince < NEWS_FOR) {
        this.callout.value += value;
        this.callout.x = x; this.callout.y = y; this.callout.z = z;
        this.calloutSince = clock;
      } else if (earned && waiting) {
        waiting.value += value;
        waiting.at = at;
        waiting.x = x; waiting.y = y; waiting.z = z;
      } else if (earned || (!waiting && (last === undefined || at - last >= NEWS_COOLDOWN))) {
        this.callouts.push({ kind, value, at, x, y, z, part, lost });
        if (this.callouts.length > NEWS_QUEUE) {
          // Drop the oldest of the least urgent.
          let drop = 0;
          for (let i = 1; i < this.callouts.length; i++) if (newsPriority(this.callouts[i]!.kind) < newsPriority(this.callouts[drop]!.kind)) drop = i;
          this.callouts.splice(drop, 1);
        }
      }
    }
    if (this.callout && clock - this.calloutSince < NEWS_FOR) return this.callout;
    this.callout = null;
    if (this.callouts.length === 0) return null;
    let best = 0;
    for (let i = 1; i < this.callouts.length; i++) if (newsPriority(this.callouts[i]!.kind) > newsPriority(this.callouts[best]!.kind)) best = i;
    this.callout = this.callouts.splice(best, 1)[0]!;
    this.calloutSince = clock;
    this.lastShown.set(this.callout.kind, clock);
    return this.callout;
  }

  layout(units: Units): void {
    this.units = units;
    this.m = units.m;
    // The podium shout, about its middle; the confetti over the whole screen.
    const size = SCREEN_U.bannerText * units.u * PODIUM_SIZE;
    this.podium.restyle({
      size,
      outline: size * COUNT_OUTLINE,
      outlineColour: SCREEN_CSS.ink,
      shadow: { distance: size * COUNT_DROP, blur: 0, alpha: SCREEN_ALPHA.drop, colour: SCREEN_CSS.ink },
    });
    this.podium.pivot.set(this.podium.lineBox.width / 2, this.podium.lineBox.height / 2);
    this.podium.position.set(units.width / 2, units.height * PODIUM_AT);
    this.confetti.layout(units.width, units.height, SCREEN_U.bannerText * units.u * CONFETTI_BIT);
    this.layoutRun(units);
    this.layoutResults(units);
  }

  /** The run's HUD: the tag and course top left, the banner and news in the middle, the kart bottom left, the clock bottom right. */
  private layoutRun(units: Units): void {
    const { u, safe, width, height } = units;
    this.hudW = width;
    this.hudH = height;
    const inset = SIZE_U.inset * u;
    // The crash cam's bars across the top and bottom, its tag in the bottom one.
    const boxBar = height * LETTERBOX;
    this.letterbox.clear().rect(0, 0, width, boxBar).fill(KIT_COLOUR.bar).rect(0, height - boxBar, width, boxBar).fill(KIT_COLOUR.bar);
    this.slowTag.restyle({ size: SCREEN_U.tagText * u });
    this.slowTag.position.set((width - this.slowTag.lineBox.width) / 2, height - boxBar + (boxBar - this.slowTag.lineBox.height) / 2);
    const left = Math.max(inset, safe.left);
    const top = Math.max(inset, safe.top);
    const right = width - Math.max(inset, safe.right);
    const bottom = height - Math.max(inset, safe.bottom);
    const px = SCREEN_U.platePadX * u;
    const room = SCREEN_U.room * u;
    const cell = SCREEN_U.check * u;
    const edge = Math.max(1, SCREEN_U.edge * u);
    const lean = KIT_M.lean;
    const g = this.plates.clear();
    const midY = (label: KLabel, y: number, h: number): number => y + (h - label.lineBox.height) / 2;

    for (const label of [this.liveWord, this.gameName]) label.restyle({ size: SCREEN_U.tagText * u });
    this.courseLine.restyle({ size: SCREEN_U.subText * u });
    this.kartNum.restyle({ size: SCREEN_U.numText * u * KART_SCALE });
    this.kartName.restyle({ size: SCREEN_U.nameText * u * KART_SCALE });
    this.kartState.restyle({ size: SCREEN_U.stateText * u * KART_SCALE });
    this.runLabel.restyle({ size: SCREEN_U.clockLabel * u * CLOCK_SCALE });
    this.time.restyle({ size: SCREEN_U.clockText * u * CLOCK_SCALE });
    this.speed.restyle({ size: SCREEN_U.speedText * u });

    // Top left, the tag: a red dot, LIVE, a flag, the game's name -- on a dark slanted plate.
    const tagH = SCREEN_U.tagH * u;
    const dotR = SCREEN_U.dot * u;
    const fw = flagWidth(cell);
    const tagIn = (tagH * lean) / 2 + px;
    const tagW = tagIn * 2 + dotR * 2 + room + this.liveWord.lineBox.width + room + fw + room + this.gameName.lineBox.width;
    slant(g, left, top, tagW, tagH, KIT_COLOUR.bar, KIT_COLOUR.edge, edge);
    let x = left + tagIn;
    g.circle(x + dotR, top + tagH / 2, dotR).fill(SCREEN_COLOUR.live);
    x += dotR * 2 + room;
    this.liveWord.position.set(x, midY(this.liveWord, top, tagH));
    x += this.liveWord.lineBox.width + room;
    flag(g, x, top + (tagH - cell * KIT_M.flagRows) / 2, cell, KIT_M.flagCols, KIT_M.flagRows, KIT_COLOUR.hot);
    x += fw + room;
    this.gameName.position.set(x, midY(this.gameName, top, tagH));

    // Under it, the course and its run on a plate of its own.
    const subH = SCREEN_U.subH * u;
    const subX = left + SCREEN_U.subShift * u;
    const subY = top + tagH;
    const subIn = (subH * lean) / 2 + px;
    const subW = subIn * 2 + this.courseLine.lineBox.width;
    slant(g, subX, subY, subW, subH, SCREEN_COLOUR.cream);
    this.courseLine.position.set(subX + subIn, midY(this.courseLine, subY, subH));
    // The controls, bottom middle, clear of the bottom corners' plates.
    this.controls.layout(u * CONTROLS_SCALE);
    this.controls.view.position.set((width - this.controls.width) / 2, bottom - this.controls.height);

    // The middle: the banner, hot orange, a dark flag either side of its words; the news under it.
    const bannerY = height * SCREEN_U.bannerAt;
    let newsY = bannerY;
    if (this.shownShout) {
      const bh = SCREEN_U.bannerH * u;
      const bcell = SCREEN_U.bannerCheck * u;
      const bfw = flagWidth(bcell);
      const bIn = (bh * lean) / 2 + px;
      const popping = this.shownPop;
      if (popping !== Pop.banner) {
        // A bonus, a stunt or damage: no banner -- its words alone, big, outlined dark, turned about their middle
        // (`animateBonus` places them in the world, pops, wobbles, bounces and colours them every frame).
        const outline = SCREEN_U.newsOutline * u * 2.2;
        this.shout.restyle({ size: SCREEN_U.bannerText * u * BONUS_SIZE, fill: POP_COLOURS[popping]![0]!, outline, outlineColour: POP_INKS[popping]! });
        this.bonusOutline = outline;
        this.bonusX = width / 2;
        this.bonusY = bannerY + bh / 2;
        this.bonusFill = -1;
      } else if (this.shownCount) {
        // The countdown (and GO!): the words alone, big and white, a thick black outline and a drop shadow.
        const size = SCREEN_U.bannerText * u * COUNT_SIZE;
        this.shout.restyle({
          size,
          fill: KIT_COLOUR.ink,
          outline: size * COUNT_OUTLINE,
          outlineColour: SCREEN_CSS.ink,
          shadow: { distance: size * COUNT_DROP, blur: 0, alpha: SCREEN_ALPHA.drop, colour: SCREEN_CSS.ink },
        });
        this.shout.scale.set(1);
        this.shout.rotation = 0;
        this.shout.position.set((width - this.shout.lineBox.width) / 2, bannerY + bh / 2 - this.shout.lineBox.height / 2);
      } else {
        // (Its words sized first: the banner is as wide as they are.)
        this.shout.restyle({ size: SCREEN_U.bannerText * u });
        const bw = bIn * 2 + bfw * 2 + room * 2 + this.shout.lineBox.width;
        const bx = (width - bw) / 2;
        slant(g, bx, bannerY, bw, bh, KIT_COLOUR.hot, KIT_COLOUR.hotLight, edge);
        const fy = bannerY + (bh - bcell * KIT_M.flagRows) / 2;
        const light = KIT_COLOUR.hot;
        flag(g, bx + bIn, fy, bcell, KIT_M.flagCols, KIT_M.flagRows, light, KIT_COLOUR.ink);
        this.shout.restyle({ size: SCREEN_U.bannerText * u, fill: KIT_COLOUR.ink, outline: undefined, outlineColour: SCREEN_CSS.ink, shadow: undefined });
        this.shout.scale.set(1);
        this.shout.rotation = 0;
        this.shout.position.set(bx + bIn + bfw + room, midY(this.shout, bannerY, bh));
        flag(g, bx + bw - bIn - bfw, fy, bcell, KIT_M.flagCols, KIT_M.flagRows, light, KIT_COLOUR.ink);
      }
      newsY = Math.max(bannerY + bh, this.shownCount ? this.shout.y + this.shout.lineBox.height : bannerY) + SCREEN_U.newsRoom * u;
    }
    this.news.restyle({
      fill: this.shownDamage ? DAMAGE_RED_LIGHT : KIT_COLOUR.text,
      size: SCREEN_U.news * u,
      outline: SCREEN_U.newsOutline * u,
      wrap: width * SCREEN_U.newsWrap,
      shadow: { distance: SCREEN_U.newsDrop * u, blur: 0, alpha: SCREEN_ALPHA.drop, colour: SCREEN_CSS.ink },
    });
    this.news.position.set((width - this.news.lineBox.width) / 2, newsY);

    // Bottom left, small, the kart: its number on red, joined to a plate with its name / OVERBOARD.
    const kartH = SCREEN_U.kartH * u * KART_SCALE;
    // On a touch screen, above the steering buttons there (`touch-controls.ts`).
    const touchRoom = TOUCH ? (SCREEN_U.touchButton * 1.62 + SCREEN_U.touchGap * 3) * u : 0;
    const kartY = bottom - kartH - touchRoom;
    const numW = SCREEN_U.numW * u * KART_SCALE;
    // (The kart's plate -- its number and name -- is not shown in the run: only its place, for the lower third above.)
    if (KART_PLATE) slant(g, left, kartY, numW, kartH, KIT_COLOUR.hot, KIT_COLOUR.hotLight, edge);
    this.kartNum.position.set(left + (numW - this.kartNum.lineBox.width) / 2, midY(this.kartNum, kartY, kartH));
    const nameX = left + numW - kartH * lean + edge * 2;
    const nameIn = (kartH * lean) / 2 + px;
    const thin = kartH * 0.5 * lean;
    // OVERBOARD after a slash, only while it is so.
    const stated = this.shownOut;
    const stateW = room * 2 + thin + this.kartState.lineBox.width;
    const nameW = nameIn * 2 + this.kartName.lineBox.width + stateW * Number(stated);
    if (KART_PLATE) slant(g, nameX, kartY, nameW, kartH, KIT_COLOUR.bar, KIT_COLOUR.edge, edge);
    x = nameX + nameIn;
    this.kartName.position.set(x, midY(this.kartName, kartY, kartH));
    x += this.kartName.lineBox.width + room;
    if (KART_PLATE && stated) g.moveTo(x + thin, kartY + kartH * 0.25).lineTo(x, kartY + kartH * 0.75).stroke({ color: KIT_COLOUR.text, width: Math.max(1, SCREEN_U.thinSlash * u) });
    x += thin + room;
    this.kartState.position.set(x, midY(this.kartState, kartY, kartH));
    // The lower third, above the kart: the part's damage in cream on a red plate, a dark tab at its left.
    this.third.restyle({ size: SCREEN_U.subText * u });
    if (this.shownThird) {
      const thirdH = SCREEN_U.subH * u;
      const thirdY = kartY - SCREEN_U.underRoom * u * 2 - thirdH;
      const thirdIn = (thirdH * lean) / 2 + px;
      const tab = SCREEN_U.slash * u * 2;
      const thirdW = thirdIn * 2 + tab + room + this.third.lineBox.width;
      slant(g, left, thirdY, thirdW, thirdH, KARTY_COLOUR.bad, KIT_COLOUR.edge, edge);
      slant(g, left + thirdIn - px / 2, thirdY + thirdH * 0.2, tab, thirdH * 0.6, KIT_COLOUR.bar);
      this.third.position.set(left + thirdIn + tab + room, midY(this.third, thirdY, thirdH));
    }

    // Top middle, big: the speed, in miles an hour, gold on a navy sticker (as the clock under it).
    const speedPadX = SCREEN_U.platePadX * u * 1.3, speedPadY = SCREEN_U.room * u * 0.4;
    const speedW = this.speed.lineBox.width + speedPadX * 2, speedH = this.speed.lineBox.height + speedPadY * 2;
    if (this.speed.visible) slant(g, (width - speedW) / 2, top, speedW, speedH, KIT_COLOUR.bar, KIT_COLOUR.edge, edge);
    this.speed.position.set((width - this.speed.lineBox.width) / 2, top + speedPadY);
    // The clock, small, under the speed in the top middle: TIME and the run's time.
    const clockH = SCREEN_U.clockH * u * CLOCK_SCALE;
    const clockY = top + speedH + SCREEN_U.room * u * 0.6;
    const clockIn = (clockH * lean) / 2 + px;
    const clockW = clockIn * 2 + this.runLabel.lineBox.width + room * 1.5 + this.time.lineBox.width;
    const clockX = (width - clockW) / 2;
    if (this.time.visible) slant(g, clockX, clockY, clockW, clockH, SCREEN_COLOUR.cream, KIT_COLOUR.edge, edge);
    this.runLabel.position.set(clockX + clockIn, midY(this.runLabel, clockY, clockH));
    this.time.position.set(clockX + clockW - clockIn - this.time.lineBox.width, midY(this.time, clockY, clockH));

    // The flyover's Skip (then Start), bottom middle.
    const sm = units.m;
    this.skip.layout(sm);
    const skipY = bottom - this.skip.height;
    this.skip.view.position.set((width - this.skip.width) / 2, skipY);

    // The field, over the countdown: a plate at the right, its heading, the table.
    const fm = units.m * 0.85;
    const fpad = SCREEN_M.platePad * fm;
    const fieldW = Math.min(FIELD_W * fm, width * 0.46);
    this.fieldHead.restyle({ size: SCREEN_M.body * fm });
    this.introName.restyle({ size: SCREEN_M.heading * fm * 0.8, wrap: fieldW - 2 * fpad });
    this.introGoal.restyle({ size: SCREEN_M.body * fm * 0.85, wrap: fieldW - 2 * fpad });
    this.introBest.restyle({ size: SCREEN_M.small * fm });
    const fRoom = SCREEN_M.lineRoom * fm;
    const introH = this.introName.lineBox.height + fRoom + this.introGoal.lineBox.height + fRoom + this.introBest.lineBox.height + SCREEN_M.ruleRoom * fm;
    const fh = fpad + introH + this.fieldHead.lineBox.height + fRoom + this.fieldBoard.height(fm) + fpad;
    const fx = right - fieldW, fy = Math.max(top, (height - fh) / 2 - height * 0.08);
    plate(this.fieldPlate.clear(), fx, fy, fieldW, fh, fm);
    let iy = fy + fpad;
    this.introName.position.set(fx + fpad, iy);
    iy += this.introName.lineBox.height + fRoom;
    this.introGoal.position.set(fx + fpad, iy);
    iy += this.introGoal.lineBox.height + fRoom;
    this.introBest.position.set(fx + fpad, iy);
    iy += this.introBest.lineBox.height + SCREEN_M.ruleRoom * fm;
    this.fieldHead.position.set(fx + fpad, iy);
    this.fieldBoard.place(fx + fpad, iy + this.fieldHead.lineBox.height + fRoom, fieldW - 2 * fpad, fm);
  }

  /** The results, as the mock-up lays them: the plate (the heading, the score, the board, the medals) in the middle,
   * see-through (RESULT_ALPHA), the world seen through it, the stickers on the left, and the buttons big along the
   * bottom -- at the menus' unit, or smaller if the plate runs off the screen (the leaderboard makes it tall). */
  private layoutResults(units: Units): void {
    const tall = this.placeResults(units, units.m);
    // (A phone on its side has its buttons down the right: the plate may have the whole height.)
    const room = resultsSide(units) ? units.height - SCREEN_M.platePad * units.m * 2 : units.height - this.onward.height * RESULT_BUTTONS - SCREEN_M.platePad * units.m * 3;
    if (tall > room && tall > 0) this.placeResults(units, (units.m * room) / tall * 0.96);
  }

  /** The results plate placed at the unit `m`; answers its height. */
  private placeResults(units: Units, m: number): number {
    const { width, height } = units;
    const pad = SCREEN_M.platePad * m;
    // Garage, Retry, and on: big -- but smaller where they will not all fit (a phone): along the bottom, across the
    // frame; or, a phone on its side (`resultsSide`), down the right, under the pause and sound buttons, the plate
    // beside them.
    const side = resultsSide(units);
    const slots = this.onward.view.visible ? 3 : 2;
    const buttons = [this.garage, this.again, this.onward].slice(0, slots);
    let bm = m * RESULT_BUTTONS;
    for (const b of buttons) b.layout(bm);
    const hudTop = (SCREEN_U.button + SIZE_U.inset * 2) * units.u + units.safe.top;
    const across = buttons.reduce((sum, b) => sum + b.width, 0) + pad * (slots + 2);
    const down = buttons.reduce((sum, b) => sum + b.height + SCREEN_M.buttonSink * bm, 0) + pad * (slots - 1);
    const fit = side ? (height - hudTop - pad) / down : width / across;
    if (fit < 1) {
      bm *= fit;
      for (const b of buttons) b.layout(bm);
    }
    const columnW = side ? Math.max(...buttons.map((b) => b.width)) + pad * 1.5 : 0;
    // (A tall screen, a phone upright: nearly its whole width; on its side, what the buttons leave.)
    const w = side ? Math.min(SCREEN_M.results * m, width - columnW - pad * 3) : Math.min(SCREEN_M.results * m, width * (height > width ? RESULT_SHARE_TALL : RESULT_SHARE));
    const x = side ? (width - columnW - w) / 2 : (width - w) / 2;
    const hcell = KIT_M.check * m, room = SCREEN_M.flagRoom * m, under = SCREEN_M.under * m, drop = SCREEN_M.underDrop * m;
    const line = SCREEN_M.lineRoom * m, ruleRoom = SCREEN_M.ruleRoom * m, rowRoom = SCREEN_M.rowRoom * m;
    const laurel = SCREEN_M.laurel * m;
    this.heading.restyle({ size: SCREEN_M.heading * m });
    this.unlocked.restyle({ size: SCREEN_M.body * m * SCORE_SCALE, wrap: w - 2 * pad });
    for (let i = 0; i < 3; i++) {
      this.medalNames[i]!.restyle({ size: SCREEN_M.rowText * m });
      this.medalValues[i]!.restyle({ size: SCREEN_M.rowText * m });
    }
    this.why.restyle({ size: SCREEN_M.small * m, wrap: w - 2 * pad });
    const boardH = this.board.height(m);
    const whyH = this.why.text ? this.why.lineBox.height + ruleRoom * 2 : 0;
    const headH = this.heading.lineBox.height + drop + under;
    const rowH = Math.max(laurel, this.medalNames[0]!.lineBox.height);
    const sink = SCREEN_M.buttonSink * bm;
    const h = pad + headH + line + this.unlocked.lineBox.height + ruleRoom * 2
      + boardH + ruleRoom * 2
      + 3 * rowH + 2 * rowRoom + ruleRoom * 2
      + whyH - ruleRoom + pad;
    // The buttons along the bottom; the plate in what is left above them.
    const buttonsY = side ? height : height - pad * 1.5 - buttons[0]!.height - sink;
    // (Clear of the pause and sound buttons over its top right corner -- on its side, nowhere near them.)
    const top = side ? Math.max(pad * 0.5, (height - h) / 2) : Math.max(pad + (SCREEN_U.button + SIZE_U.inset) * units.u, (buttonsY - pad - h) / 2);
    plate(this.panel.clear(), x, top, w, h, m, KIT_COLOUR.plate, KIT_COLOUR.edge, RESULT_ALPHA);
    const d = this.deco.clear();
    let y = top + pad;
    placeHeading(d, this.heading, x + (w - headingWidth(this.heading, hcell, room)) / 2, y, hcell, room, under, drop);
    y += headH + line;
    this.unlocked.position.set(x + (w - this.unlocked.lineBox.width) / 2, y);
    y += this.unlocked.lineBox.height + ruleRoom;
    rule(d, x + pad, y, w - 2 * pad, KIT_M.edge * m);
    y += ruleRoom;
    // The league table.
    y += this.board.place(x + pad, y, w - 2 * pad, m);
    y += ruleRoom;
    rule(d, x + pad, y, w - 2 * pad, KIT_M.edge * m);
    y += ruleRoom;
    // Each medal: its laurel in the medal's colour, its name, what earned it.
    // (Shown race time first, then showmanship, then creativity: MEDAL_ROWS.)
    for (let r = 0; r < 3; r++) {
      const i = MEDAL_ROWS[r]!;
      glyph(d, 'gold', x + pad, y + (rowH - laurel) / 2, laurel, MEDAL_COLOURS[this.medalShown[i]!]!);
      this.medalNames[i]!.position.set(x + pad + laurel + room, y + (rowH - this.medalNames[i]!.lineBox.height) / 2);
      this.medalValues[i]!.position.set(x + w - pad - this.medalValues[i]!.lineBox.width, y + (rowH - this.medalValues[i]!.lineBox.height) / 2);
      y += rowH + (r < 2 ? rowRoom : 0);
    }
    y += ruleRoom;
    rule(d, x + pad, y, w - 2 * pad, KIT_M.edge * m);
    y += ruleRoom;
    if (this.why.text) this.why.position.set(x + (w - this.why.lineBox.width) / 2, y);
    // Garage, Retry, and on (Next course / Courses, the one to press): big, along the bottom, spread across.
    // (Failed, no onward button: the other two in halves.) On its side, down the right, the one to press first.
    if (side) {
      let by = Math.max(hudTop, (height - down * Math.min(1, fit)) / 2);
      for (let i = slots - 1; i >= 0; i--) {
        const b = buttons[i]!;
        b.view.position.set(width - Math.max(pad, units.safe.right) - columnW + pad * 0.5 + (columnW - pad * 1.5 - b.width) / 2, by);
        by += b.height + sink + pad;
      }
    } else if (fit < 1) {
      // (Squeezed across: as much room either side of each.)
      const spare = (width - buttons.reduce((sum, b) => sum + b.width, 0)) / (slots + 1);
      let bx = spare;
      for (const b of buttons) {
        b.view.position.set(bx, buttonsY);
        bx += b.width + spare;
      }
    } else {
      const third = (width - pad * 3) / slots;
      buttons.forEach((b, i) => b.view.position.set(pad * 1.5 + third * i + (third - b.width) / 2, buttonsY));
    }
    // The stickers, down the left over the world: tilted this way and that, the unlock red.
    const sx = x * 0.5;
    // (On a tall screen the plate is nearly the width: no room beside it for them.)
    const tall = height > width;
    let sy = top + pad;
    for (let i = 0; i < STICKERS; i++) {
      const st = this.stickers[i]!;
      const words = this.stickerWords[i];
      st.view.visible = words !== undefined && !tall;
      if (words === undefined) continue;
      const hot = this.stickerHot[i]!;
      st.words.set(words);
      st.words.restyle({ size: SCREEN_M.heading * m * 0.9, fill: hot ? KIT_COLOUR.ink : KIT_COLOUR.text, wrap: x * 0.5 });
      const sw = st.words.lineBox.width + pad * 2, sh = st.words.lineBox.height + pad * 1.2;
      slant(st.back.clear(), -sw / 2, -sh / 2, sw, sh, hot ? KIT_COLOUR.hot : KIT_COLOUR.bar, KIT_COLOUR.edge, KIT_M.edge * m * 1.4);
      st.words.position.set(-st.words.lineBox.width / 2, -st.words.lineBox.height / 2);
      st.view.rotation = (i % 2 === 0 ? -1 : 1) * STICKER_TILT;
      st.view.position.set(Math.max(pad + sw / 2, sx), sy + sh / 2);
      sy += sh + pad * 1.4;
    }
    return h;
  }
}

/** The one on show, put here by the `ui` hook: the page's, kept across a rebuild of the game. */
let shown: RaceHud | null = null;

export function showRaceHud(widget: RaceHud): RaceHud {
  shown = widget;
  return widget;
}

/** The game entry's install: each frame, the kart told to the HUD, and the world to the garage. */
export function raceHud(world: World): () => void {
  live.world = world;
  world.system({
    name: 'race-hud',
    phase: 'render',
    read: [Kart, Build],
    update({ members, count }) {
      if (count === 0) return;
      const e = members[0];
      live.kart = e;
      shown?.show(world, e);
    },
  });
  return () => {
    if (live.world === world) live.world = null;
  };
}


/** The results on a phone on its side: the frame too short for the buttons under the plate, so they go down its right. */
function resultsSide(units: Units): boolean {
  return phoneSized(units) && units.width > units.height;
}
