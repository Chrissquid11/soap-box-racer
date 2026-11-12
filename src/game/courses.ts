/**
 * The ten courses, easiest first. Each is designed here, deterministically, from its difficulty (0 to 9):
 * longer, steeper and twistier as it goes, its road narrower and its hay walls lower (so the hard ones
 * can be left by the side), with more and bigger hazards -- mid-course jumps from the fifth on. A course
 * is its control points (the road's centre line), its look, its hazards and its medal times.
 *
 * Every other course is a city street (`urban`): the same road, but between terraced houses and lamp posts, behind
 * red and white water barriers, on pavements and cobbles instead of fields. And the features of a proper soapbox
 * course come in as the courses go on: a steep wooden start ramp on some (`startRamp`), long steep straights
 * between the hazards to gather speed (acceleration zones), bone rattlers (washboard ridges across the road) and
 * wedges (a ramp under one side only, tipping the kart) -- with the kickers, the chicanes and the berms. The later
 * courses add the suspension shatterers and the chaos: a big-air jump, a stair set to rattle down, a gravel trap
 * (deep loose stones that drag a kart down, often at the end of a fast straight), a foam section through a car wash
 * (buried in suds, the road slick with soap), a disco tunnel, and a near-vertical drop off the start.
 *
 * The same designs are the course models: `scripts/courses.ts` writes each as a Gladius script,
 * `AssetsSource/models/courses/cNN.lua`, which builds the road along these points with the shared
 * library `_course.lua` -- run `node scripts/courses.ts` after a change here, and `courses.test.ts` checks
 * the scripts still match. Plain data and arithmetic; nothing here holds the world.
 */
import { CUT_MOUTH, GRID_BACK, sampleTrack, SUB, type Track, WIDTH_LEAST, widthProfile, withShortcut } from './track.ts';
/** How far behind the line the kart waited when the medals were set (samples), and the pace a pushed-off kart averages
 * over the run up beyond that (m/s): `idealTime` allows for any more. */
const GRID_TUNED = 3;
const PUSHED_PACE = 2.2;
/** The road behind the start line falls this much a metre to it: the kart waits on a gentle slope, never a hump. */
const GRID_FALL = 0.03;

/** The run-out past the finish line: a point every this many metres, two of them (about 24 m in all) -- short: the
 * race is over, the road only has to stop the karts. */
const RUN_OUT_STEP = 12;

/** What stands on a course, as `populate` and the `course` system place it. */
export const HazardKind = ['ramp', 'jump', 'bin', 'cone', 'bale', 'rattler', 'wedge', 'stairs', 'gravel', 'foam', 'tunnel', 'kicker', 'splash'] as const;
export type HazardKind = (typeof HazardKind)[number];

export interface Hazard {
  readonly kind: HazardKind;
  /** Which sample of the centre line it stands at, and metres across it (+ to the right). */
  readonly sample: number;
  readonly across: number;
  /** A ramp's, jump's, wedge's or rattler's scale: across (the road's width over its own) and up. 1 for everything else. */
  readonly width: number;
  readonly height: number;
}

export interface Course {
  readonly name: string;
  readonly blurb: string;
  /** 0 for the first, 9 for the last. */
  readonly difficulty: number;
  readonly points: readonly (readonly [number, number, number])[];
  /** Half the road's width as designed, metres: at the start, the finish and a shortcut's junctions. */
  readonly halfWidth: number;
  /** Each sample's share of `halfWidth`: the road narrowing and widening along the course (`track.ts`' widthProfile). */
  readonly widths: readonly number[];
  readonly wallHeight: number;
  readonly startPoint: number;
  readonly finishPoint: number;
  /** Linear colours for the Gladius script: the road, the grass and the hay walls. */
  readonly road: readonly [number, number, number];
  readonly grass: readonly [number, number, number];
  readonly hay: readonly [number, number, number];
  readonly hazards: readonly Hazard[];
  /** Race-time medals, seconds: gold, silver, bronze. */
  readonly medals: readonly [number, number, number];
  /** Each point's berm: how far the outside of the bend there is built up, metres (+ the right edge, - the left; `track.ts`). */
  readonly berms: readonly number[];
  /** Its model's key. */
  readonly model: string;
  /** A city street: houses, lamp posts and water barriers, not fields and hay. */
  readonly urban: boolean;
  /** Its walls straw bales alone, each backed by a steel crowd barrier (the first courses). */
  readonly railed: boolean;
  /** No walls at all: its edges lined end to end with loose straw bales instead (`course.ts` lays them; the first course). */
  readonly bare: boolean;
  /** A steep wooden start ramp: the road plunges off the start grid. */
  readonly startRamp: boolean;
  /** Snow on the land (its grass white): the only courses it snows on (`weather.ts`). */
  readonly snowy: boolean;
  /** A second route (`Shortcut`), or null. */
  readonly shortcut: Shortcut | null;
}

/**
 * A shortcut: a straight road leaving the main one at sample `from` and rejoining it at `to`, cutting across a bend
 * the main road loops round -- shorter, but over a jump with a gap (the duck pond) between its lip and its landing, and
 * a rough landing after. Its places along it are shares of its length (0 at `from`, 1 at `to`): the pond's gap from
 * `pondFrom` to `pondTo` (no road there: water below), the jump's lip at `pondFrom`, the rough patch from
 * `roughFrom` to `roughTo`. The course model builds it (`_course.lua`), the race measures progress along it
 * (`track.ts`' routeAt), the course system lays its jump and its ducks (`course.ts`).
 */
export interface Shortcut {
  readonly from: number;
  readonly to: number;
  readonly halfWidth: number;
  readonly pondFrom: number;
  readonly pondTo: number;
  readonly roughFrom: number;
  readonly roughTo: number;
  /** The jump's height scale (`JUMP`'s). */
  readonly jump: number;
}

/**
 * The duck-pond shortcut's layout, for a valley course listed in SHORTCUT_COURSES -- none of the first ten, where the
 * player learns the road first (so none, as the courses stand). At a fork the main road bears away right, round the duck pond in a wide half
 * circle, while the shortcut -- short (FETE_NECK metres, the road round about 1.6 times that), narrower than the road
 * and fenced -- runs nearly straight on, FETE_SPLIT off the road coming in, across to where the road round comes back,
 * over the pond; the road on leaves the join FETE_REJOIN off the shortcut's line. Taking it is the gamble: the jump
 * over the pond's gap (FETE_GAP metres) landed, it is far quicker than the road round (`shortcut.test.ts`); missed,
 * the run is over in the water. The road round drops gently (FETE_ROUND_DROP), so the shortcut straight across is no
 * steeper than the road and meets it level; both forks are wide mouths, no wall nose between the roads.
 */
const FETE_NECK = 100;
const FETE_SPLIT = (15 * Math.PI) / 180;
const FETE_REJOIN = (15 * Math.PI) / 180;
/** The road round: this many points on its half circle between the fork and where it rejoins; and the road on from
 * the rejoin, this many (the finish three from the end). */
const FETE_ROUND = 4;
const FETE_AFTER = 7;
const FETE_LINE: readonly (readonly [number, number])[] = ((): [number, number][] => {
  const r2 = (x: number): number => Math.round(x * 100) / 100;
  const fork = [0, -90] as const;
  // The shortcut's way (u: the road coming in, down -z, turned FETE_SPLIT to its left, -x) and the road round's side
  // (v: to its right).
  const ux = -Math.sin(FETE_SPLIT), uz = -Math.cos(FETE_SPLIT);
  const vx = -uz, vz = ux;
  const at = (s: number, t: number): [number, number] => [r2(fork[0] + s * ux + t * vx), r2(fork[1] + s * uz + t * vz)];
  const half = FETE_NECK / 2;
  const round: [number, number][] = [];
  for (let k = 1; k <= FETE_ROUND; k++) {
    const a = Math.PI * (1 - k / (FETE_ROUND + 1));
    round.push(at(half + half * Math.cos(a), half * Math.sin(a)));
  }
  const out = at(FETE_NECK, 0);
  // On from the join: leaving FETE_REJOIN off the shortcut's line (toward the road round's side, between the two),
  // then easing back round to run down -z.
  const after: [number, number][] = [];
  let h = Math.atan2(ux, uz) + FETE_REJOIN;
  let [x, z] = out;
  // Enough of them for a straight run-in to the final jump and the finish.
  for (let k = 0; k < FETE_AFTER; k++) {
    x += Math.sin(h) * 30;
    z += Math.cos(h) * 30;
    after.push([r2(x), r2(z)]);
    h += (-Math.PI - h) * 0.35;
  }
  return [[0, 20], [0, 0], [0, -30], [0, -60], [fork[0], fork[1]], ...round, out, ...after];
})();
/** The shortcut: from the fork (point 4) to where it rejoins, samples. */
const FETE_SHORTCUT = { from: 4 * SUB, to: (5 + FETE_ROUND) * SUB, halfWidth: 3.2, jump: 1.1 } as const;
const FETE_GAP = 13;
/** Round the pond the road drops this share of what it would: the shortcut across, which drops as far in a much
 * shorter run, kept from plunging (and from meeting the road again with a jolt). */
const FETE_ROUND_DROP = 0.5;
/** The courses laid out round the duck pond with its shortcut: none of the first ten. */
const SHORTCUT_COURSES: readonly number[] = [];
/** Every course about this share of the length its design would give it: a valley course fewer points raced over, a
 * mountain course's legs their points closer together (its hairpins kept). */
const SHORTER = 0.8;
/** A valley course's line drawn again at most this many times when it would come back over itself. */
const REDRAWS = 6;
/** A mountain course's legs this share of their designed length (its hairpins as they were): the whole about SHORTER. */
const MOUNTAIN_LEGS = 0.64;

const NAMES = [
  ['Training Course', 'The Cotswolds, England. A gentle first run down the bunting-strung hill, past the cake stall.'],
  ['Bristol Bombdown', 'Bristol, England. Down the terraced streets past the coloured houses. One cheeky ramp.'],
  ['Kerry Cliffs', 'County Kerry, Ireland. Narrower, steeper, and the bins are out.'],
  ['Lisbon Lurch', 'Lisbon, Portugal. Cobbles and tram lines all the way down to the river. Brake before the bends.'],
  ['Outback Rattler', 'The Outback, Australia. Red dirt and a jump halfway down. Land it straight.'],
  ['Montmartre Mayhem', 'Paris, France. Off the top of the hill, down past the cafes. The start ramp is steep.'],
  ['Savannah Slide', 'The Maasai Mara, Kenya. Barely a road. Hairpins and hazards.'],
  ['Valparaiso Velocity', 'Valparaiso, Chile. Painted houses stacked up the hill. Very fast, very narrow.'],
  ['Lava Field Luge', 'Iceland. Black roads over the moss: jumps, hairpins and a long way down.'],
  ['San Francisco Sling', 'San Francisco, USA. The championship street run. Steep, long, and rattly. Good luck.'],
  // The mountain courses: switchbacks down a steep face, hairpin after hairpin.
  ['Alpine Zigzag', 'The Swiss Alps. Down the mountain face, one hairpin at a time.'],
  ['Genoa Gauntlet', 'Genoa, Italy. Narrow lanes zigzagging down to the port.'],
  ['Pyrenean Pinball', 'The Pyrenees, France and Spain. It winds. Then it winds the other way.'],
  ['Edinburgh Old Town', 'Edinburgh, Scotland. Down the Old Town closes, steep and stony. Brake early.'],
  ['Andes Hairpins', 'The Andes, Peru. Count the hairpins. If you can.'],
  ['Sheffield Switchback', 'Sheffield, England. Seven hills, and this street is the steepest.'],
  ['Himalayan Hurtle', 'The Himalayas, Nepal. Start in the clouds. End in a hedge.'],
  ['Dunedin Drop', 'Dunedin, New Zealand. One of the steepest streets in the world, then more.'],
  ['Kiwi Corkscrew', 'The Southern Alps, New Zealand. Steep, golden, and the hairpins bite.'],
  ['Hong Kong Hurtle', 'Hong Kong. The final run, down the Peak between the towers. Everything at once.'],
] as const;

/**
 * Each course's look, its place's own: the road, the land round it, the hay. (Never the sky's pale blue-grey for
 * the land, which the distance fog melts into: snow is whiter.)
 */
const LOOKS: readonly (readonly [readonly [number, number, number], readonly [number, number, number], readonly [number, number, number]])[] = [
  [[0.3, 0.22, 0.13], [0.2, 0.46, 0.1], [0.85, 0.62, 0.22]],       // Cotswolds: green fields
  [[0.1, 0.1, 0.11], [0.42, 0.4, 0.37], [0.8, 0.06, 0.04]],        // Bristol: tarmac, paving
  [[0.26, 0.24, 0.2], [0.12, 0.42, 0.1], [0.82, 0.6, 0.2]],        // Kerry: the greenest green
  [[0.38, 0.34, 0.28], [0.62, 0.56, 0.46], [0.85, 0.07, 0.05]],    // Lisbon: cobbles, limestone
  [[0.55, 0.22, 0.1], [0.62, 0.42, 0.18], [0.85, 0.6, 0.25]],      // the Outback: red dirt
  [[0.16, 0.16, 0.17], [0.5, 0.47, 0.42], [0.08, 0.2, 0.7]],       // Paris: tarmac, pale stone
  [[0.45, 0.3, 0.18], [0.62, 0.55, 0.22], [0.85, 0.6, 0.22]],      // Kenya: dry savannah
  [[0.2, 0.19, 0.18], [0.46, 0.38, 0.32], [0.9, 0.35, 0.03]],      // Valparaiso: worn concrete
  [[0.12, 0.12, 0.13], [0.3, 0.42, 0.16], [0.75, 0.5, 0.2]],       // Iceland: black lava, moss
  [[0.12, 0.12, 0.13], [0.44, 0.44, 0.45], [0.85, 0.06, 0.04]],    // San Francisco: tarmac, concrete
  // The mountains.
  [[0.3, 0.29, 0.27], [0.18, 0.42, 0.12], [0.86, 0.6, 0.2]],       // Swiss Alps: alpine meadow
  [[0.3, 0.28, 0.25], [0.55, 0.48, 0.38], [0.85, 0.07, 0.05]],     // Genoa: old stone
  [[0.3, 0.27, 0.22], [0.28, 0.4, 0.14], [0.82, 0.56, 0.18]],      // Pyrenees
  [[0.22, 0.21, 0.2], [0.34, 0.32, 0.3], [0.06, 0.25, 0.75]],      // Edinburgh: dark stone setts
  [[0.36, 0.27, 0.2], [0.46, 0.4, 0.22], [0.86, 0.46, 0.16]],      // Andes: high brown grass
  [[0.11, 0.11, 0.12], [0.4, 0.37, 0.33], [0.85, 0.06, 0.04]],     // Sheffield: tarmac, millstone
  [[0.3, 0.3, 0.32], [0.8, 0.84, 0.88], [0.9, 0.3, 0.12]],         // Himalayas: snow
  [[0.14, 0.14, 0.15], [0.46, 0.45, 0.43], [0.95, 0.5, 0.02]],     // Dunedin: tarmac, concrete
  [[0.3, 0.28, 0.26], [0.62, 0.52, 0.24], [0.82, 0.4, 0.14]],      // New Zealand: golden tussock
  [[0.1, 0.1, 0.11], [0.5, 0.5, 0.52], [0.85, 0.06, 0.04]],        // Hong Kong: tarmac, concrete
];

/** The same small seeded generator everywhere: the same course every build. */
function lcg(seed: number): () => number {
  let s = seed >>> 0;
  return () => {
    s = (Math.imul(s, 1103515245) + 12345) >>> 0;
    return s / 4294967296;
  };
}

const round = (x: number): number => Math.round(x * 100) / 100;

/** Every course's road this much narrower than its design's first width. */
const NARROW = 0.7;
/** The NARROW the berms (`bermsOf`) were tuned on: their heights scaled with the road's width since. */
const BERM_TUNED_ON = 0.78;
/** The berms: metres of build-up for each radian a metre the road turns at a point (its curvature), the most there
 * is and the least worth building, and how far (metres) from a ramp's or jump's middle the road stays flat (a
 * kicker lies flat across the road). */
const BERM_PER_CURVE = 45;
const BERM_MOST = 1.1;
const BERM_LEAST = 0.12;
const BERM_CLEAR = 14;
/** The feature berms from course 6 on: the tightest bends built up steep -- this high at the bend's point (metres;
 * across a road some 6.6 m wide, about 30 degrees), a share of it at the points either side -- each at least
 * BERM_APART points from the next. */
const BERM_FEATURE = 2.1;
const BERM_SHOULDER = 0.6;
const BERM_APART = 4;
/** How many feature berms a course has, by its index: none on the first five, one to course 12, two after. */
const featureBerms = (d: number): number => (d >= 12 ? 2 : d >= 5 ? 1 : 0);
/** Whether a course's land is snow: its grass near white. */
const isSnowy = (grass: readonly [number, number, number]): boolean => Math.min(grass[0], grass[1], grass[2]) > 0.7;
/** Which courses are city streets: every other one. */
const isUrban = (d: number): boolean => d % 2 === 1;
/** Which courses are walled with straw bales and steel crowd barriers alone: the first three. */
const isRailed = (d: number): boolean => d < 3;
/** Which course has no walls, only loose straw bales lining its edges: the first. */
const isBare = (d: number): boolean => d === 0;
/** Which courses start off a steep wooden ramp: every third from the third. It drops this much a metre more than the
 * road after it (on top of the road's own slope). */
const hasStartRamp = (d: number): boolean => d % 3 === 2;
const START_RAMP_DROP = 0.24;
/** An acceleration zone: from the fourth course, a long straight this many points long, this much steeper than the
 * road round it -- somewhere to wind it right up between the hazards. */
const ZONE_POINTS = 3;
const ZONE_STEEP = 1.5;
/** Bone rattlers (across the whole road) from the fourth course, a second from the eighth; wedges (a ramp under one
 * side, this share of the road wide) from the fifth, a second from the ninth. Counted by the
 * course's place in its set of ten. */
const rattlers = (set: number): number => (set >= 7 ? 2 : set >= 3 ? 1 : 0);
const wedges = (set: number): number => (set >= 8 ? 2 : set >= 4 ? 1 : 0);
const WEDGE_SHARE = 0.42;
/** A rattler's and a wedge's length as laid (metres): what `course.ts` lays them over. */
export const RATTLER = { w: 1, l: 8 } as const;
export const WEDGE_LONG = 0.6;
/** The later courses' features, by the course's place in its set of ten: a stair set from the sixth, a gravel trap
 * from the fifth, a foam section from the seventh, a disco tunnel from the eighth; the middle jump big air from the
 * seventh (this high a scale); and from the fifth mountain course, a start ramp near vertical (this much more drop a
 * metre). Their lengths as modelled (`course/props.lua`, metres) and their models' widths. */
const STAIRS_FROM = 5, GRAVEL_FROM = 4, FOAM_FROM = 6, TUNNEL_FROM = 7, BIG_AIR_FROM = 6;
const BIG_AIR = 1.65;
const VERTICAL_FROM = 4;
const VERTICAL_DROP = 0.65;
export const FEATURE_LONG = { stairs: 11, gravel: 14, foam: 18, tunnel: 24, splash: 24 } as const;
/**
 * Side kickers: little launch ramps (the jump's lip shape) over part of the road only, hard against one edge -- the
 * rest of the road beside them clear, so a kart can go round. Each this wide (metres; never more than KICK_SHARE of
 * the road's half width), this high a scale of the jump's lip, this far in from the edge; a star in the air past each
 * (`course`' bonuses), for whoever takes it. KICKERS(d) of them on course d.
 */
export const KICK_W = 3.2;
export const KICK_H = 0.6;
const KICK_SHARE = 0.7;
const KICK_EDGE = 0.25;
/** Samples a kicker keeps from anything laid flat (a jump, a ramp, a rattler, gravel ... another kicker), and from
 * anything standing on its side of the road (a cone, a bale, a bin) -- the other side may have one: it is the way round. */
const KICK_CLEAR_FLAT = 10;
const KICK_CLEAR_STANDING = 5;
const kickers = (d: number): number => 3 + Math.floor(d / 3);
/**
 * Lays course `d`'s side kickers among the hazards already placed (last, so none of those moves): each at a sample
 * `pick` gives, against the edge on a side drawn from `rnd`, where `ok` allows (the grid, the finish, a shortcut's
 * junction) and clear of the rest (KICK_CLEAR_*, in samples times `scale`).
 */
function layKickers(hazards: Hazard[], n: number, halfWidth: number, rnd: () => number, pick: () => number, ok: (s: number) => boolean, scale: number): void {
  for (let i = 0; i < n; i++) {
    for (let t = 0; t < 300; t++) {
      const side = rnd() < 0.5 ? -1 : 1;
      const k = kickerAt(halfWidth, side);
      const at = pick();
      if (!ok(at)) continue;
      const clear = hazards.every((h) => {
        const apart = Math.abs(h.sample - at);
        if (laidFlat(h.kind)) return apart >= KICK_CLEAR_FLAT * scale;
        return apart >= KICK_CLEAR_STANDING * scale || (Math.sign(h.across) !== side && Math.abs(h.across - k.across) > k.width / 2 + 1.2);
      });
      if (!clear) continue;
      hazards.push({ kind: 'kicker', sample: at, across: round(k.across), width: round(k.width / JUMP.w), height: KICK_H });
      break;
    }
  }
}
/** A side kicker's width (metres) and where across the road its middle is, on a road `halfWidth` either side, on `side`. */
function kickerAt(halfWidth: number, side: number): { width: number; across: number } {
  const width = Math.min(KICK_W, halfWidth * KICK_SHARE);
  return { width, across: side * (halfWidth - KICK_EDGE - width / 2) };
}

/** How narrow course `d`'s road may get, a share of its designed width: the first course, where the player learns
 * the road, only a little narrower in places; the second more; from the third on, as narrow as WIDTH_LEAST. */
const narrowest = (d: number): number => 1 - (1 - WIDTH_LEAST) * Math.min(1, 0.4 + 0.3 * d);
/** How many narrow squeezes (`track.ts`' pinches) course `d`'s road has: none on the first two, nor on every third; one
 * on the other hill courses, two on the other mountain ones. */
const pinchesOf = (d: number): number => (d < 2 || d % 3 === 0 ? 0 : d >= 10 ? 2 : 1);

/**
 * Course `d`'s road widths (`track.ts`' widthProfile, a share of `halfWidth` a sample) and its hazards fitted to them:
 * laid out on the road at its designed width, each then held to the road's width where it stands -- what is laid
 * across the road on a stretch of one width (levelled), as wide a share of the road as it was; what stands on it as
 * far a share across; a side kicker against the edge as `kickerAt` puts it; the disco tunnel its room outside the
 * walls. The start, the finish and a shortcut's junctions keep the designed width.
 */
function fitWidths(track: Track, d: number, halfWidth: number, hazards: readonly Hazard[], cut: Shortcut | null): { widths: number[]; hazards: Hazard[] } {
  const keep: [number, number][] = cut ? [[cut.from - CUT_MOUTH, cut.from + CUT_MOUTH], [cut.to - CUT_MOUTH, cut.to + CUT_MOUTH]] : [];
  const level = hazards.filter((h) => laidFlat(h.kind)).map((h) => ({ sample: h.sample, half: laidLength(h) / 2 }));
  const widths = widthProfile(track, d, keep, level, narrowest(d), pinchesOf(d));
  const fitted = hazards.map((h): Hazard => {
    const f = widths[Math.max(0, Math.min(widths.length - 1, h.sample))]!;
    if (f === 1) return h;
    switch (h.kind) {
      case 'kicker': {
        const k = kickerAt(halfWidth * f, Math.sign(h.across));
        return { ...h, across: round(k.across), width: round(k.width / JUMP.w) };
      }
      case 'tunnel': return { ...h, width: round((halfWidth * f + TUNNEL_ROOM) / TUNNEL_HALF) };
      case 'cone': case 'bale': case 'bin': return { ...h, across: round(h.across * f) };
      default: return { ...h, across: round(h.across * f), width: round(h.width * f) };
    }
  });
  return { widths, hazards: fitted };
}
export const FEATURE_WIDE = { gravel: 8, foam: 8, tunnel: 11, splash: 8 } as const;
/** The disco tunnel's half width inside as modelled, and how far it stands outside the walls. */
export const TUNNEL_HALF = 5.5;
export const TUNNEL_ROOM = 1.0;
/**
 * The splash pool (`course/props.lua`' splash): a slippery painted ramp up at each end, a shallow pool between them that
 * sprays up and drags a kart back a little. On courses 2, 6, 10, 11, 14 and 17 (SPLASH_COURSES: those with room),
 * the road made near level for it (`levelStretch`) on its straightest stretch. Its pool's half length (metres; the rest
 * of FEATURE_LONG.splash its ramps).
 */
const SPLASH_COURSES: readonly number[] = [1, 5, 9, 10, 13, 16];
/** A mountain course's stretches levelled for it (each a leg's, SEG * MOUNTAIN_LEGS long). */
const SPLASH_SPAN = 3;
const splashes = (d: number): boolean => SPLASH_COURSES.includes(d);
/** The splash pool as modelled, metres long (laid stretched to FEATURE_LONG.splash, `course.ts`). */
export const SPLASH_MODEL = 16;
export const SPLASH_POOL = 4.9 * (FEATURE_LONG.splash / SPLASH_MODEL);
/**
 * Makes `span` stretches of a design near level for the splash pool: from point `lo` to `hi`, among those `ok` allows, the
 * straightest (the least turn from the stretch before it to the one after), its fall cut to POOL_FALL of what it was
 * (or `keep`) and the rest taken by the two stretches after it (`ys`, the points' heights, changed in place; the course drops as
 * far in all). The stretch's first point, or -1.
 */
const POOL_FALL = 0.1;
function levelStretch(xz: readonly (readonly [number, number])[], ys: number[], lo: number, hi: number, ok: (k: number) => boolean, span = 1, keep = POOL_FALL): number {
  const heading = (k: number): number => Math.atan2(xz[k + 1]![0] - xz[k]![0], xz[k + 1]![1] - xz[k]![1]);
  let best = -1, bestTurn = Infinity;
  for (let k = Math.max(1, lo); k <= hi && k + span + 2 < ys.length; k++) {
    if (!ok(k)) continue;
    // The turn into it and out of it, and along it.
    let turn = 0;
    for (let j = k - 1; j < k + span; j++) {
      const a = heading(j), b = heading(j + 1);
      turn += Math.abs(Math.atan2(Math.sin(b - a), Math.cos(b - a)));
    }
    if (turn < bestTurn) { bestTurn = turn; best = k; }
  }
  if (best < 0) return -1;
  const fall = ys[best]! - ys[best + span]!;
  const lift = fall * (1 - keep);
  // The stretch: near level, falling evenly. The next: its own fall and half the rest; after it, as it was less the
  // other half.
  for (let i = 1; i <= span; i++) ys[best + i] = ys[best]! - (fall * keep * i) / span;
  ys[best + span + 1] = ys[best + span + 1]! + lift / 2;
  return best;
}

/** Laid flat along the road from foot to foot, across all of it or (a wedge) part: never stood on it as a prop is. */
export function laidFlat(kind: HazardKind): boolean {
  return kind === 'ramp' || kind === 'jump' || kind === 'kicker' || kind === 'wedge' || kind === 'rattler' || kind === 'stairs' ||
    kind === 'gravel' || kind === 'foam' || kind === 'tunnel' || kind === 'splash';
}
/** How long one is laid, metres: a ramp's and a jump's scaled with their height. */
export function laidLength(h: Hazard): number {
  switch (h.kind) {
    case 'wedge': return RAMP.l * WEDGE_LONG;
    case 'rattler': return RATTLER.l;
    case 'stairs': case 'gravel': case 'foam': case 'tunnel': case 'splash': return FEATURE_LONG[h.kind];
    case 'jump': case 'kicker': return JUMP.l * h.height;
    default: return RAMP.l * h.height;
  }
}

/**
 * Each point's berm: the outside of every bend built up, steeper the tighter the bend -- the turn at a point over the
 * road's length about it, smoothed over its neighbours, so a berm rises into a bend and falls away after it -- and
 * flat where a ramp or jump stands, on the start grid and from the finish on. From course 6 on, the tightest bends
 * (`featureBerms`) are built up steep: the course's proper berms.
 */
function bermsOf(points: readonly (readonly [number, number, number])[], hazards: readonly Hazard[], finishPoint: number, features = 0): number[] {
  const n = points.length;
  const turn = new Array<number>(n).fill(0);
  // How far along each point is, metres (straight from one to the next: near enough the curve).
  const along = new Array<number>(n).fill(0);
  for (let k = 1; k < n; k++) along[k] = along[k - 1]! + Math.hypot(points[k]![0] - points[k - 1]![0], points[k]![2] - points[k - 1]![2]);
  for (let k = 1; k < n - 1; k++) {
    const ax = points[k]![0] - points[k - 1]![0], az = points[k]![2] - points[k - 1]![2];
    const bx = points[k + 1]![0] - points[k]![0], bz = points[k + 1]![2] - points[k]![2];
    // + turning toward the road's right (across +, `track.ts`): the outside is then the left edge. A radian a metre.
    const run = (along[k + 1]! - along[k - 1]!) / 2 || 1;
    turn[k] = Math.atan2(ax * bz - az * bx, ax * bx + az * bz) / run;
  }
  const flat = new Array<boolean>(n).fill(false);
  for (let k = 0; k < n; k++) if (k <= 2 || k >= finishPoint - 1) flat[k] = true;
  for (const h of hazards) {
    if (!laidFlat(h.kind)) continue;
    // The kicker's place along the road, metres: its sample's point and the share of the way to the next.
    const p = Math.min(n - 1, Math.floor(h.sample / SUB));
    const at = along[p]! + ((h.sample % SUB) / SUB) * ((along[Math.min(n - 1, p + 1)]! - along[p]!));
    for (let k = 0; k < n; k++) if (Math.abs(along[k]! - at) < BERM_CLEAR + 6) flat[k] = true;
  }
  const out = new Array<number>(n).fill(0);
  for (let k = 0; k < n; k++) {
    if (flat[k]) continue;
    const t = (turn[Math.max(0, k - 1)]! + 2 * turn[k]! + turn[Math.min(n - 1, k + 1)]!) / 4;
    const h = Math.min(BERM_MOST, Math.abs(t) * BERM_PER_CURVE);
    out[k] = h < BERM_LEAST ? 0 : round(-Math.sign(t) * h);
  }
  // The feature berms: the tightest bends clear of the kickers and the ends, steep, rising in and falling away.
  const taken: number[] = [];
  for (let f = 0; f < features; f++) {
    let best = -1;
    for (let k = 2; k < n - 2; k++) {
      if (flat[k] || flat[k - 1] || flat[k + 1] || taken.some((j) => Math.abs(j - k) < BERM_APART)) continue;
      if (best < 0 || Math.abs(turn[k]!) > Math.abs(turn[best]!)) best = k;
    }
    if (best < 0) break;
    taken.push(best);
    const side = -Math.sign(turn[best]!) || 1;
    out[best] = round(side * BERM_FEATURE);
    out[best - 1] = round(side * Math.max(Math.abs(out[best - 1]!), BERM_FEATURE * BERM_SHOULDER));
    out[best + 1] = round(side * Math.max(Math.abs(out[best + 1]!), BERM_FEATURE * BERM_SHOULDER));
  }
  // As steep across the road as on the wider road they were tuned on (BERM_TUNED_ON): lower on a narrower one.
  for (let k = 0; k < n; k++) out[k] = round(out[k]! * (NARROW / BERM_TUNED_ON));
  return out;
}

/**
 * The ramp's and the jump's shapes, as `course/props.lua` models them, before their scaling: w wide, l long, at most
 * h high, centred on their length, their height along it `kickerRise(hump, s)` (a share of h, s from 0 at the near
 * foot to 1 at the far end).
 *
 *  - The jump: flat at its foot, so a kart meets no kink rolling onto it, curving up over the first `RAMP_CURVE` of
 *    the way, then straight on up to a lip to fly off.
 *  - The ramp: a roller -- one smooth wave up and back down, no corner anywhere. A kart rides over it on its wheels
 *    up to about 60 km/h; faster, it floats off the crest and comes down on the far side going the way it slopes --
 *    never launched nose first onto the flat.
 */
export const RAMP = { w: 4, l: 18, h: 0.45, hump: true } as const;
export const JUMP = { w: 10, l: 5, h: 1.1, hump: false } as const;
export function kickerRise(hump: boolean, s: number): number {
  return hump ? (1 - Math.cos(2 * Math.PI * s)) / 2 : rampRise(s);
}
export const RAMP_CURVE = 0.55;
const RAMP_K = 1 / (RAMP_CURVE * (2 - RAMP_CURVE));
export function rampRise(s: number): number {
  if (s <= RAMP_CURVE) return RAMP_K * s * s;
  return RAMP_K * RAMP_CURVE * RAMP_CURVE + 2 * RAMP_K * RAMP_CURVE * (s - RAMP_CURVE);
}

/**
 * How much harder than gravity alone the slope pulls a kart on its wheels down the road: its pull along the ground
 * times 1 + this (`vehicle`). 0.59 makes it 1.6 times: every kart about 1.26 times as fast (a tenth slower than it
 * was, at 0.96), gathering speed and flat out against the air -- and only along the ground, so a jump flies and
 * lands as gravity has it.
 */
export const DOWNHILL = 0.59;
/**
 * The tyres' friction against the road, a share of the load (`vehicle`): a little grippier with the speed, so the
 * corners keep up -- but under a sensible kart's tipping point, so it slides wide before it rolls.
 */
export const TYRE_GRIP = 0.84;

/**
 * Race-time medals (gold, silver, bronze) as multiples of a course's `idealTime`. The ideal is a point mass on the
 * centre line: on the valley runs (the first ten) their gravel, foam, stairs, rattlers and kickers cost a real kart
 * far more than it allows -- a well-driven good build finishes about 1.15 to 1.25 times it -- while on the mountain
 * runs the bermed hairpins are quicker than it assumes (1.0 to 1.1 flat out, 1.1 to 1.25 careful). Each set's gold
 * sits where a good build on a good line just makes it; bronze is a clean careful finish.
 */
export const VALLEY_MEDALS = [1.15, 1.32, 1.6] as const;
export const MOUNTAIN_MEDALS = [1.03, 1.2, 1.5] as const;
const medalsOf = (ideal: number, set: readonly [number, number, number]): readonly [number, number, number] =>
  [Math.round(ideal * set[0]), Math.round(ideal * set[1]), Math.round(ideal * set[2])] as const;

/**
 * The starter kart's best time down a track, as a point mass on its line: pushed off to walking pace, then
 * gravity down the slope (and `DOWNHILL`) against air drag and rolling, never faster into a bend than its tyres hold
 * (braking ahead of it, as a good driver does), from the start line to the finish.
 */
export function idealTime(track: Track): number {
  const G = 9.81;
  const MASS = 116, DRAG = 0.6 * 0.44, ROLL = 0.015;
  const { start, finish } = track;
  const most = cornerSpeeds(track);
  let v = 4;
  // The run up to the line from where the kart waits, past the GRID_TUNED samples the medals were set with: walked
  // and pushed, at the pace a pushed-off kart averages there (measured: the rival's run, 2.2 m/s).
  let time = 0;
  for (let i = Math.max(0, start - GRID_BACK); i < start - GRID_TUNED; i++) {
    time += Math.hypot(track.sx[i + 1]! - track.sx[i]!, track.sz[i + 1]! - track.sz[i]!) / PUSHED_PACE;
  }
  for (let i = start; i < finish; i++) {
    const ds = Math.hypot(track.sx[i + 1]! - track.sx[i]!, track.sz[i + 1]! - track.sz[i]!);
    const fall = track.sy[i]! - track.sy[i + 1]!;
    const along = Math.hypot(ds, fall);
    const a = G * (fall / along) * (1 + DOWNHILL) - (DRAG / MASS) * v * v - ROLL * G;
    const next = Math.min(most[i + 1]!, Math.sqrt(Math.max(16, v * v + 2 * a * along)));
    time += along / Math.max(0.5, (v + next) / 2);
    v = next;
  }
  return time;
}

/**
 * The fastest the starter kart may be at each sample of a track, m/s: no faster into a bend than its tyres hold,
 * and braking ahead of each (as a good driver does). What the medals assume, and what the sim's autopilot keeps to.
 */
export function cornerSpeeds(track: Track): Float64Array {
  const G = 9.81;
  const GRIP = TYRE_GRIP, BRAKE = 0.4 * G;
  const { start, finish } = track;
  // How fast each sample may be taken: the bend's radius from the turn between its neighbours.
  const most = new Float64Array(track.samples).fill(60);
  for (let i = start + 1; i < finish; i++) {
    const turn = Math.abs(Math.atan2(track.tx[i - 1]! * track.tz[i + 1]! - track.tz[i - 1]! * track.tx[i + 1]!, track.tx[i - 1]! * track.tx[i + 1]! + track.tz[i - 1]! * track.tz[i + 1]!));
    const ds = Math.hypot(track.sx[i + 1]! - track.sx[i - 1]!, track.sz[i + 1]! - track.sz[i - 1]!);
    if (turn > 1e-4) most[i] = Math.sqrt(GRIP * G * (ds / turn));
  }
  // Braking ahead of each bend: back from the finish, no faster than can be shed before the next -- and downhill the
  // slope takes its share of the brakes (on the steepest, much of them).
  for (let i = finish - 1; i >= start; i--) {
    const ds = Math.hypot(track.sx[i + 1]! - track.sx[i]!, track.sz[i + 1]! - track.sz[i]!);
    const grade = Math.max(0, (track.sy[i]! - track.sy[i + 1]!) / Math.max(0.01, ds));
    const shed = Math.max(BRAKE * 0.25, BRAKE - G * grade);
    most[i] = Math.min(most[i]!, Math.sqrt(most[i + 1]! ** 2 + 2 * shed * ds));
  }
  return most;
}

function design(d: number): Course {
  const rnd = lcg(1000 + d * 7919);
  // Control points: longer as it goes, and longer again from the fifth, room for its features.
  // (A shortcut course's line is its own, FETE_LINE, as many points as it has.)
  const pond = SHORTCUT_COURSES.includes(d);
  // (Shortened by SHORTER: the points raced over, not the start's two or the run-out's.)
  const designed = 14 + Math.round(d * 1.2) + (d >= GRAVEL_FROM ? Math.round((d - 2) * 1.25) : 0);
  const count = pond ? FETE_LINE.length : Math.round((designed - 4) * SHORTER) + 4;
  const seg = 30;                                  // metres between them
  const slope = 0.105 + d * 0.009;                 // drop a metre, on average
  const turn = 0.25 + d * 0.06;                    // most a heading may change a point, radians
  // Narrow: a homemade course is as wide as the field it was laid out in allowed.
  const halfWidth = round((5.5 - d * 0.25) * NARROW);
  const wallHeight = round(0.85 - d * 0.045);

  // The line: a flat start, then a wandering descent that never comes back across itself -- from the fourth course
  // with a long straight somewhere past the middle (an acceleration zone).
  const zoneFrom = d >= 3 ? Math.floor(count * 0.45) : -1;
  const inZone = (k: number): boolean => zoneFrom > 0 && k >= zoneFrom && k < zoneFrom + ZONE_POINTS;
  // Drawn again (the generator running on) when a point found no clear place -- a road that would come back over
  // itself -- up to REDRAWS times.
  const xz: [number, number][] = [];
  for (let draw = 0; draw < REDRAWS; draw++) {
    xz.splice(0, xz.length, [0, 20], [0, 0]);
    let heading = Math.PI;
    let bend = 0;
    let cramped = false;
    for (let k = 2; k < count; k++) {
      let placed = false;
      for (let attempt = 0; attempt < 60 && !placed; attempt++) {
        const wander = bend * 0.45 + (rnd() * 2 - 1) * turn * (attempt < 30 ? 0.9 : 0.5);
        const want = inZone(k) && attempt < 30 ? 0 : wander;
        const h = heading + want;
        const [px, pz] = xz[k - 1]!;
        const x = px + Math.sin(h) * seg;
        const z = pz + Math.cos(h) * seg;
        let clear = true;
        for (let j = 0; j < k - 2 && clear; j++) clear = Math.hypot(xz[j]![0] - x, xz[j]![1] - z) > 4 * halfWidth + 30;
        if (clear || attempt === 59) {
          if (!clear) cramped = true;
          xz.push([round(x), round(z)]);
          heading = h;
          bend = want;
          placed = true;
        }
      }
    }
    if (!cramped) break;
  }
  // A shortcut course (SHORTCUT_COURSES): the duck pond's line, the main road looping round it.
  if (pond) xz.splice(0, xz.length, ...FETE_LINE.map(([x, z]) => [x, z] as [number, number]));
  // The heights: down from the top, the run-out after the finish climbing a little to stop karts.
  const finishPoint = count - 3;
  const ys: number[] = new Array(count).fill(0);
  let y = 0;
  for (let k = 2; k <= finishPoint; k++) {
    // Never a flat stretch: a kart must still be rolling at the final jump.
    // (Round the fete's duck pond, gentler: the shortcut straight across drops as far as the road round, in less.)
    const fete = pond && k > FETE_SHORTCUT.from / SUB && k <= FETE_SHORTCUT.to / SUB ? FETE_ROUND_DROP : 1;
    y -= seg * slope * (0.7 + 0.6 * rnd()) * (inZone(k) ? ZONE_STEEP : 1) * fete;
    // Off the start ramp: the first stretch plunges.
    if (k === 2 && hasStartRamp(d)) y -= seg * (d >= VERTICAL_FROM + 4 ? START_RAMP_DROP * 1.6 : START_RAMP_DROP);
    ys[k] = y;
  }
  // The run-out short (RUN_OUT_STEP a point, two of them): straight on from the finish, climbing a little to stop karts.
  {
    const [fx, fz] = xz[finishPoint]!, [bx, bz] = xz[finishPoint - 1]!;
    const len = Math.hypot(fx - bx, fz - bz) || 1;
    const ux = (fx - bx) / len, uz = (fz - bz) / len;
    for (let k = 1; k <= 2; k++) xz[finishPoint + k] = [round(fx + ux * RUN_OUT_STEP * k), round(fz + uz * RUN_OUT_STEP * k)];
  }
  // Behind the start line, a gentle fall to it (GRID_FALL): level there, the road's curve humped up behind the line,
  // and a kart waiting back on its far side was pushed off uphill.
  ys[0] = GRID_FALL * 20;
  ys[finishPoint + 1] = y + 0.4;
  ys[finishPoint + 2] = y + 1.2;
  const top = -y;
  let points = xz.map(([x, z], k) => [x, round(ys[k]! + top), z] as const);

  let track = sampleTrack(points, halfWidth, 1, finishPoint);
  const startLine = track.start;
  const finishLine = track.finish;

  // The hazards, on samples kept apart.
  const hazards: Hazard[] = [];
  // Each kept its own gap from the others, and theirs from it: a cone keeps a ramp's room, never sat on its far slope.
  const taken: { s: number; gap: number }[] = [];
  const free = (s: number, gap: number): boolean => taken.every((t) => Math.abs(t.s - s) >= Math.max(gap, t.gap));
  // The shortcut, on the fete's course: the run-up to the fork and where it rejoins kept clear of the hazards (room
  // to choose, and nothing to land from mid-turn), and the road round the pond between them too -- the long way round
  // the safe one, the shortcut the risk.
  const shortcut = pond ? feteShortcut(track) : null;
  const junction = (s: number): boolean => shortcut !== null && s > shortcut.from - 20 && s < shortcut.to + 10;
  const put = (kind: HazardKind, s: number, across: number, width = 1, height = 1, gap = 4): boolean => {
    if (s < startLine + 18 || s > finishLine - 6 || !free(s, gap) || junction(s)) return false;
    hazards.push({ kind, sample: s, across: round(across), width: round(width), height: round(height) });
    taken.push({ s, gap });
    return true;
  };
  const pick = (): number => startLine + 18 + Math.floor(rnd() * (finishLine - startLine - 30));
  const side = (): number => (rnd() < 0.5 ? -1 : 1) * (halfWidth - 2.2) * (0.6 + 0.4 * rnd());
  // The final jump, the whole road wide, bigger every course.
  put('jump', finishLine - 13, 0, (2 * halfWidth) / 10, 1 + d * 0.06, 12);
  // The splash pool (`splashes`), before the rest (they keep clear of it): the straightest stretch from one point to the
  // next -- clear of the start, the finish, the acceleration zone and the fete's pond -- made near level (its fall taken
  // by the stretches after it), the road drawn again so, and the pool in its middle.
  const pool = splashes(d) && !pond
    ? levelStretch(xz, ys, 4, finishPoint - 5, (k) => !inZone(k) && !inZone(k + 1) && free(k * SUB + SUB / 2, 4) && !junction(k * SUB + SUB / 2))
    : -1;
  if (pool >= 0) {
    points = xz.map(([x, z], k) => [x, round(ys[k]! + top), z] as const);
    track = sampleTrack(points, halfWidth, 1, finishPoint);
    put('splash', pool * SUB + SUB / 2, 0, (2 * halfWidth) / FEATURE_WIDE.splash, 1, 4);
  }
  // Jumps halfway down from the fifth course on.
  for (let j = 0; j < Math.floor((d - 2) / 2); j++) {
    // The first of them big air on the later courses: a far bigger lip, a long way down.
    const big = j === 0 && d >= BIG_AIR_FROM;
    for (let t = 0; t < 20; t++) if (put('jump', pick(), 0, (2 * halfWidth) / 10, big ? BIG_AIR : 0.8 + d * 0.05, big ? 16 : 12)) break;
  }
  const many = (kind: HazardKind, n: number, at: () => number, gap: number, width = 1): void => {
    for (let i = 0; i < n; i++) for (let t = 0; t < 200; t++) if (put(kind, pick(), at(), width, 1, gap)) break;
  };
  // Ramps the whole road wide, as the jumps are: no edge to catch a wheel on, so none tips a kart over beside it.
  // (`side` still drawn, so every course's other hazards fall where they did.)
  // The features before the ramps and the rest, so each finds its room. The disco tunnel in the acceleration zone,
  // where the road runs dead straight; the gravel trap at its end if there is room, else anywhere.
  if (d >= TUNNEL_FROM) {
    // Its middle somewhere along the zone, clear of a jump there.
    for (let o = 0; o <= ZONE_POINTS * SUB - 8; o += 2) {
      if (put('tunnel', zoneFrom * SUB + 4 + o, 0, (halfWidth + TUNNEL_ROOM) / TUNNEL_HALF, 1, 6)) break;
    }
  }
  if (d >= GRAVEL_FROM) {
    const after = (zoneFrom + ZONE_POINTS) * SUB + 2;
    if (!put('gravel', after, 0, (2 * halfWidth) / FEATURE_WIDE.gravel, 1, 4)) many('gravel', 1, () => 0, 4, (2 * halfWidth) / FEATURE_WIDE.gravel);
  }
  if (d >= STAIRS_FROM) many('stairs', 1, () => 0, 4, 2 * halfWidth);
  if (d >= FOAM_FROM) many('foam', 1, () => 0, 5, (2 * halfWidth) / FEATURE_WIDE.foam);
  // The bone rattlers, the whole road wide, and the wedges, under one side.
  many('rattler', rattlers(d), () => 0, 4, 2 * halfWidth);
  many('wedge', wedges(d), () => (rnd() < 0.5 ? -1 : 1) * halfWidth * (1 - WEDGE_SHARE), 5, (2 * halfWidth * WEDGE_SHARE) / RAMP.w);
  many('ramp', 1 + Math.floor(d / 2), () => (side(), 0), 4, (2 * halfWidth) / RAMP.w);
  // Cones in long lines: a funnel slanting in from one edge to near the middle, or a lane line down the road --
  // 5 to 9 of them a line (more on the later courses), a cone every sample.
  const coneLine = (): boolean => {
    const s = pick();
    const len = 5 + Math.min(4, Math.floor(d / 2));
    const step = 1;
    for (let i = 0; i < len; i++) if (!free(s + i * step, 2)) return false;
    const side = rnd() < 0.5 ? -1 : 1;
    const funnel = rnd() < 0.6;
    let laidCones = 0;
    for (let i = 0; i < len; i++) {
      const f = i / (len - 1);
      const across = funnel ? side * (halfWidth - 0.7 - f * halfWidth * 0.75) : side * halfWidth * 0.35;
      if (put('cone', s + i * step, across, 1, 1, 0.5)) laidCones++;
    }
    return laidCones > 0;
  };
  for (let i = 0; i < 2 + Math.floor(d / 3); i++) for (let t = 0; t < 300; t++) if (coneLine()) break;
  many('bale', 2 + d, () => (rnd() < 0.5 ? -1 : 1) * (halfWidth - 1.2), 3);
  // Side kickers, last, so every other hazard falls where it did.
  layKickers(hazards, kickers(d), halfWidth, rnd, pick, (s) => s >= startLine + 18 && s <= finishLine - 10 && !junction(s), 1);
  hazards.sort((a, b) => a.sample - b.sample);
  // The road narrowing and widening along the course, and the hazards fitted to it.
  const fit = fitWidths(track, d, halfWidth, hazards, shortcut);

  // Medal times from an ideal run: gold a little over it, bronze well over.
  const medals = medalsOf(idealTime(track), VALLEY_MEDALS);

  const [name, blurb] = NAMES[d]!;
  const [road, grass, hay] = LOOKS[d]!;
  return {
    name, blurb, difficulty: d, points, halfWidth, widths: fit.widths, wallHeight, startPoint: 1, finishPoint,
    road, grass, hay, hazards: fit.hazards, medals, berms: forksFlat(bermsOf(points, fit.hazards, finishPoint, featureBerms(d)), shortcut), model: `courses/c${String(d + 1).padStart(2, '0')}`,
    urban: isUrban(d), railed: isRailed(d), bare: isBare(d), startRamp: hasStartRamp(d), snowy: isSnowy(grass), shortcut,
  };
}

/** The road at a shortcut's forks left unbanked, so the shortcut leaves it and rejoins it level. */
function forksFlat(berms: number[], cut: Shortcut | null): number[] {
  if (cut) for (const at of [cut.from, cut.to]) berms[Math.round(at / SUB)] = 0;
  return berms;
}

/** The fete's shortcut on its track: the pond's gap in the middle, the rough landing just past it. */
function feteShortcut(track: Track): Shortcut {
  const { from, to } = FETE_SHORTCUT;
  const len = Math.hypot(track.sx[to]! - track.sx[from]!, track.sz[to]! - track.sz[from]!);
  // The run-up to the jump's lip, the pond's gap, then the rough landing -- ended before the road it rejoins.
  const pondFrom = 0.55;
  const pondTo = pondFrom + FETE_GAP / len;
  return {
    ...FETE_SHORTCUT, pondFrom, pondTo: Math.round(pondTo * 1000) / 1000,
    roughFrom: Math.round((pondTo + 3 / len) * 1000) / 1000, roughTo: Math.round(Math.min(0.94, pondTo + 7 / len) * 1000) / 1000,
  };
}

/**
 * A mountain course (`d` 10 to 19): switchbacks down a steep face. Legs across the slope, each steep and winding,
 * each turned into the next by a hairpin -- a tight half turn, nearly flat, the road coming back on itself below --
 * the legs swinging left and right of the fall line so the road zigzags down. More hairpins, steeper legs and a
 * narrower road as it goes; the hazards only on the legs (never in a hairpin), the jumps only where the road runs
 * on straight after them.
 */
/** A mountain course's points, about: as long a road as its model can be built for. */
const POINTS = 52;

function designAlpine(d: number): Course {
  const k = d - 10;
  const rnd = lcg(5000 + d * 7919);
  const halfWidth = round((4.8 - k * 0.12) * NARROW);
  const wallHeight = round(0.95 - k * 0.025);
  // More legs each course, and so more hairpins, on a road of about the same length (a longer one will not build:
  // the course model has a budget) -- the legs shorter, the bends coming quicker.
  const legs = 4 + Math.floor(k / 4);
  const pins = legs - 1;
  const legPoints = Math.max(3, Math.floor((POINTS - 9 - pins * 4) / legs));
  const legSlope = 0.22 + k * 0.008;               // drop a metre down a leg (the hardest a little gentler than they were)
  const pinSlope = 0.07;                           // and round a hairpin
  const wiggle = 0.22 + k * 0.02;                  // the most a leg's heading wanders a point, radians
  const fall = Math.PI;                            // straight down the mountain: -z
  // How far off straight across the slope a leg runs down: a little, so legs below are clear of those above.
  const across = 0.32 + rnd() * 0.08;

  // Every point the same distance on from the last: the road's spline through them never overshoots into a loop,
  // as it does where long gaps meet short ones (a hairpin's tight points after a leg's long ones).
  const SEG = 12;
  const xz: [number, number][] = [[0, SEG], [0, 0]];
  const ys: number[] = [GRID_FALL * SEG, 0];   // a gentle fall to the start line (as the hill courses')
  /** The hairpins, as points (first, last): no hazard stands in one, or just before it. */
  const pinSpans: [number, number][] = [];
  let heading = fall;
  let y = 0;
  const step = (h: number, seg: number, slope: number): void => {
    const [px, pz] = xz[xz.length - 1]!;
    xz.push([round(px + Math.sin(h) * seg), round(pz + Math.cos(h) * seg)]);
    y -= seg * slope * (0.85 + 0.3 * rnd());
    ys.push(y);
    heading = h;
  };
  // From `heading` round to `to`: a hairpin when it is a big turn (tight -- about 16 m round -- and nearly flat),
  // else a sweep.
  const turnTo = (to: number): void => {
    const total = to - heading;
    const pin = Math.abs(total) > 1.6;
    const each = pin ? 0.75 : 0.3;
    const n = Math.max(1, Math.ceil(Math.abs(total) / each));
    const from = heading;
    const startsAt = xz.length - 1;
    for (let i = 1; i <= n; i++) step(from + (total * i) / n, SEG, pin ? pinSlope : legSlope * 0.6);
    if (pin) pinSpans.push([startsAt, xz.length - 1]);
  };
  /** The acceleration zone's points (first, last), if it has one. */
  let zoneSpan: [number, number] | null = null;
  for (let l = 0; l < legs; l++) {
    const side = l % 2 === 0 ? 1 : -1;
    turnTo(fall + side * (Math.PI / 2 - across));
    const base = heading;
    // The leg: its points winding about its line, the last one long and straight (the final jump on it).
    const last = l === legs - 1;
    const points = last ? legPoints + 3 : legPoints;
    // The second leg, from the third mountain course: an acceleration zone, dead straight and steeper.
    const zone = k >= 2 && l === 1;
    if (zone) zoneSpan = [xz.length - 1, xz.length - 1 + points];
    let bend = 0;
    for (let p = 0; p < points; p++) {
      const calm = (last && p >= points - 4) || zone;
      // A new wander every other point: bends, not a shiver.
      if (p % 2 === 0) bend = calm ? bend * 0.3 : bend * 0.4 + (rnd() * 2 - 1) * wiggle;
      // (Each leg's points closer together, MOUNTAIN_LEGS: a shorter course, its hairpins all still there -- but the
      // first after a start ramp's plunge its full length, room to settle before the first hairpin.)
      step(base + bend, SEG * (l === 0 && hasStartRamp(d) ? 1 : MOUNTAIN_LEGS), legSlope * (zone ? ZONE_STEEP * 0.8 : 1));
    }
  }
  // The run-out after the finish, short, climbing a little to stop karts.
  const finishPoint = xz.length - 1;
  for (let i = 0; i < 2; i++) step(heading, SEG, -1.2 / (2 * SEG));

  // The whole drop held to the course's own -- more every course -- the bends and legs keeping their shares of it.
  const want = 105 + k * 8;
  const fell = -Math.min(...ys);
  // Off the start ramp: the start deck raised above the rest, its first stretch a plunge -- near vertical on the later
  // ones.
  const deck = hasStartRamp(d) ? SEG * (k >= VERTICAL_FROM ? VERTICAL_DROP : START_RAMP_DROP * 1.6) : 0;
  // (The rest of the road takes the drop less the deck's: the whole course drops what it would without one.)
  const lay = (i: number): number => round((ys[i]! + fell) * ((want - deck) / fell) + (i < 2 ? deck : 0));
  let points = xz.map(([x, z], i) => [x, lay(i), z] as const);

  let track = sampleTrack(points, halfWidth, 1, finishPoint);
  const startLine = track.start;
  const finishLine = track.finish;
  // Samples are closer than the valley courses' (SUB a point, the points closer): gaps in samples scaled to match.
  const F = 30 / SEG;
  // A hairpin as samples, with room before it to brake (and none in it): where no hazard may stand.
  const pinSamples = pinSpans.map(([a, b]) => [a * SUB - 3 * F, b * SUB + 1 * F] as const);
  const onLeg = (s: number, room = 0): boolean => pinSamples.every(([a, b]) => s + room < a || s > b);

  const hazards: Hazard[] = [];
  const taken: { s: number; gap: number }[] = [];
  const free = (s: number, gap: number): boolean => taken.every((t) => Math.abs(t.s - s) >= Math.max(gap, t.gap));
  const put = (kind: HazardKind, s: number, acrossM: number, width = 1, height = 1, gap = 4 * F, room = 0): boolean => {
    if (s < startLine + 18 * F || s > finishLine - 6 * F || !free(s, gap) || !onLeg(s, room)) return false;
    hazards.push({ kind, sample: s, across: round(acrossM), width: round(width), height: round(height) });
    taken.push({ s, gap });
    return true;
  };
  const pick = (): number => startLine + Math.round(18 * F) + Math.floor(rnd() * (finishLine - startLine - 30 * F));
  // The final jump, on the last (straight) leg; a jump mid-course on every third course, with road after it.
  put('jump', finishLine - Math.round(13 * F), 0, (2 * halfWidth) / 10, 1.1 + k * 0.03, 12 * F);
  // The splash pool (`splashes`), before the rest (they keep clear of it): the straightest SPLASH_SPAN stretches on a
  // leg -- clear of the hairpins and the acceleration zone -- made near level, the road drawn again so, and the pool in
  // their middle.
  const clearOf = (j: number, [a, b]: readonly [number, number]): boolean => j + 4 < a || j - 1 > b;
  const pool = splashes(d)
    ? levelStretch(xz, ys, 4, finishPoint - 8, (j) => (!zoneSpan || clearOf(j, zoneSpan)) && pinSpans.every((p) => clearOf(j, p)) && free(j * SUB + SPLASH_SPAN * SUB / 2, 4.5 * F), SPLASH_SPAN, 0.04)
    : -1;
  if (pool >= 0) {
    points = xz.map(([x, z], i) => [x, lay(i), z] as const);
    track = sampleTrack(points, halfWidth, 1, finishPoint);
    put('splash', pool * SUB + SPLASH_SPAN * SUB / 2, 0, (2 * halfWidth) / FEATURE_WIDE.splash, 1, 4.5 * F);
  }
  for (let j = 0; j < Math.floor((k + 2) / 3); j++) {
    const big = j === 0 && k >= BIG_AIR_FROM;
    for (let t = 0; t < 40; t++) if (put('jump', pick(), 0, (2 * halfWidth) / 10, big ? BIG_AIR : 0.8 + k * 0.03, (big ? 16 : 12) * F, 40 * F)) break;
  }
  const many = (kind: HazardKind, n: number, at: () => number, gap: number, width = 1): void => {
    for (let i = 0; i < n; i++) for (let t = 0; t < 200; t++) if (put(kind, pick(), at(), width, 1, gap * F)) break;
  };
  // The features before the ramps and the rest, so each finds its room; the disco tunnel on the straight leg.
  if (k >= TUNNEL_FROM && zoneSpan) {
    const [a, b] = zoneSpan;
    put('tunnel', Math.round(((a + b) / 2) * SUB), 0, (halfWidth + TUNNEL_ROOM) / TUNNEL_HALF, 1, 6 * F);
  }
  if (k >= GRAVEL_FROM) many('gravel', 1, () => 0, 4, (2 * halfWidth) / FEATURE_WIDE.gravel);
  if (k >= STAIRS_FROM) many('stairs', 1, () => 0, 4, 2 * halfWidth);
  if (k >= FOAM_FROM) many('foam', 1, () => 0, 5, (2 * halfWidth) / FEATURE_WIDE.foam);
  many('rattler', rattlers(k), () => 0, 4, 2 * halfWidth);
  many('wedge', wedges(k), () => (rnd() < 0.5 ? -1 : 1) * halfWidth * (1 - WEDGE_SHARE), 5, (2 * halfWidth * WEDGE_SHARE) / RAMP.w);
  many('ramp', 1 + Math.floor(k / 3), () => 0, 4, (2 * halfWidth) / RAMP.w);
  // Cones in long lines: a funnel slanting in from one edge to near the middle, or a lane line down the road --
  // 5 to 9 of them a line (more on the later courses), a cone every few metres.
  const coneLine = (): boolean => {
    const s = pick();
    const len = 5 + Math.min(4, Math.floor(k / 2));
    const step = Math.max(1, Math.round(F));
    for (let i = 0; i < len; i++) if (!free(s + i * step, 2 * F)) return false;
    const side = rnd() < 0.5 ? -1 : 1;
    const funnel = rnd() < 0.6;
    let laidCones = 0;
    for (let i = 0; i < len; i++) {
      const f = i / (len - 1);
      const across = funnel ? side * (halfWidth - 0.7 - f * halfWidth * 0.75) : side * halfWidth * 0.35;
      if (put('cone', s + i * step, across, 1, 1, 0.5)) laidCones++;
    }
    return laidCones > 0;
  };
  for (let i = 0; i < 2 + Math.floor(k / 3); i++) for (let t = 0; t < 300; t++) if (coneLine()) break;
  many('bale', 2 + Math.floor(k / 2), () => (rnd() < 0.5 ? -1 : 1) * (halfWidth - 1.2), 3);
  // Side kickers, last, so every other hazard falls where it did.
  layKickers(hazards, kickers(k), halfWidth, rnd, pick, (s) => s >= startLine + 18 * F && s <= finishLine - 10 * F, F);
  hazards.sort((a, b) => a.sample - b.sample);
  const fit = fitWidths(track, d, halfWidth, hazards, null);

  const medals = medalsOf(idealTime(track), MOUNTAIN_MEDALS);
  const [name, blurb] = NAMES[d]!;
  const [road, grass, hay] = LOOKS[d]!;
  return {
    name, blurb, difficulty: d, points, halfWidth, widths: fit.widths, wallHeight, startPoint: 1, finishPoint,
    road, grass, hay, hazards: fit.hazards, medals, berms: bermsOf(points, fit.hazards, finishPoint, featureBerms(d)), model: `courses/c${String(d + 1).padStart(2, '0')}`,
    urban: isUrban(d), railed: isRailed(d), bare: isBare(d), startRamp: hasStartRamp(d), snowy: isSnowy(grass), shortcut: null,
  };
}

/** The courses: the ten valley runs, then the ten mountain ones. */
export const COURSES: readonly Course[] = Array.from({ length: 20 }, (_, d) => (d < 10 ? design(d) : designAlpine(d)));

/** How hard each course is, as the course select and the garage say it -- rated on its average grade, its steepest
 * drop and how much it turns: the gentle valley pair Easy (about 10%), the first steep ones Medium (15-17%), the long
 * valley runs Hard (18-21%), the first hairpin mountains Extreme (23-29%), the near-sheer ones Insane (29-35%), and the
 * last three -- drops past vertical, a thousand degrees of turning -- Bonkers. */
export const DIFFICULTIES = ['Easy', 'Medium', 'Hard', 'Extreme', 'Insane', 'Bonkers'] as const;
const DIFFICULTY: readonly number[] = [0, 0, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5, 5, 5];

/** Course `c`'s rating: 0 (Easy) to 5 (Bonkers). */
export function difficultyOf(c: number): number {
  return DIFFICULTY[Math.max(0, Math.min(DIFFICULTY.length - 1, c))]!;
}

/** Each course's centre line, sampled: what the race measures and places the kart by. */
export const TRACKS: readonly Track[] = COURSES.map((c) => withShortcut(sampleTrack(c.points, c.halfWidth, c.startPoint, c.finishPoint, c.berms, c.widths), c.shortcut));

/** What the road is at each sample of each course: 0 the road, 1 a gravel trap, 2 the foam section's soapy road, 4 the
 * splash pool's wet painted ramps (as slippery), 3 the splash pool's water (`vehicle`: gravel drags and grips a little less; soap
 * hardly grips; water drags a little and sprays up, `fx`). */
export const Surface = { road: 0, gravel: 1, soap: 2, water: 3, paint: 4 } as const;
const SURFACES: readonly Uint8Array[] = COURSES.map((c, i) => {
  const t = TRACKS[i]!;
  const out = new Uint8Array(t.samples);
  const along = new Float64Array(t.samples);
  for (let k = 1; k < t.samples; k++) along[k] = along[k - 1]! + Math.hypot(t.sx[k]! - t.sx[k - 1]!, t.sz[k]! - t.sz[k - 1]!);
  for (const h of c.hazards) {
    if (h.kind !== 'gravel' && h.kind !== 'foam' && h.kind !== 'splash') continue;
    const mid = along[Math.max(0, Math.min(t.samples - 1, h.sample))]!;
    const half = FEATURE_LONG[h.kind] / 2;
    for (let k = 0; k < t.samples; k++) {
      const off = Math.abs(along[k]! - mid);
      if (off > half) continue;
      out[k] = h.kind === 'gravel' ? Surface.gravel : h.kind === 'foam' ? Surface.soap : off <= SPLASH_POOL ? Surface.water : Surface.paint;
    }
  }
  return out;
});
/** The surface at `progress` (a sample, `Kart.progress`) on course `course`. */
export function surfaceAt(course: number, progress: number): number {
  const s = SURFACES[Math.max(0, Math.min(SURFACES.length - 1, course))]!;
  const k = Math.round(progress);
  return k < 0 || k >= s.length ? Surface.road : s[k]!;
}

export { SUB };
