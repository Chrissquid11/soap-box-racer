/**
 * Part damage: each wheel, each suspension corner and the bodywork is healthy, damaged or failed (`PartState`), and
 * what it is changes how the kart drives (`vehicle`) and looks (`rattle`, `fx`), and the HUD says so (`race-hud`'s
 * lower third). Knocks (`impacts`) find the corner or panel they hit from the contact point in the kart's own frame;
 * landings (`vehicle`) are the corner that took the load -- its suspension's, or with none, its wheel's.
 *
 * A hit softer than `light` does nothing. A meaningful hit damages a healthy part, and fails a damaged one; one as
 * hard as the part is tough (`severe`) fails it at once. After a part changes, `cooldown` seconds pass before it can
 * change again: one scrape, or one landing over several physics frames, is one hit.
 *
 * Every number to tune is in DAMAGE. The driving penalties are each a fixed share of the part's own stats for the
 * state it is in -- never stacked tick on tick.
 */
import type { Entity, Store } from '@vibe/engine';
import { type Kart, PartState } from './components.ts';

export const DAMAGE = {
  // ── What counts as a hit ─────────────────────────────────────────────────────────────────────────────────────
  /** m/s along the contact normal (a knock's closing speed, the kart's share of it) under which nothing is damaged. */
  light: 3,
  /** Seconds after a part's state changes before another hit can change it again. */
  cooldown: 0.6,
  /** Metres (across the ground, in the kart's frame) from a wheel's corner within which a knock is that wheel's;
   * further, it is the bodywork's. */
  cornerReach: 0.55,
  /** A damaged wheel's axle is cracked: the next knock or landing on it need only be this share of `light` (or of
   * `landingLight`) to snap it clean off. Homemade axles: one bend and they are on borrowed time. */
  crackedAxle: 0.6,
  /** A knock at least this × the wheels' toughness (`Kart.strength`, from the wheel part) fails a wheel at once. */
  wheelSevere: 1.5,
  /** A knock at least this × the bodywork's toughness (`Kart.bodyStrength`) past `light` fails the bodywork at once. */
  bodySevere: 1,
  /** A landing: m/s into the road past what the springs soak (`Kart.soak`, from the suspension part) before it is a hit. */
  landingLight: 1.8,
  /** A landing at least this × `Kart.strength` past the soak fails the part that took it at once. */
  landingSevere: 1.15,
  /** A landing off a ramp or a jump: m/s of it forgiven on top of the soak (`Kart.soak`: the suspension part times
   * its spring travel size), before `landingLight` and `landingSevere` judge the rest. The small ramps land at about
   * 5 m/s into the road and are never a hit; the big jumps 9 to 14 -- on bed springs that bends or breaks a
   * corner, on pogo springs nothing, bolted on it goes to the wheels (their part times their size: `Kart.strength`). */
  jumpAllowance: 6,
  /** A landing on springs: the share of it (past the soak) its wheel takes as well -- all of it with travel this short
   * or shorter (metres: bolted on is 0.04), none with this much or more (pogo springs, 0.35), in between in a line.
   * Bed springs at full size (0.16) pass on about half, shock absorbers (0.2) a third; the spring travel size slider
   * moves it. Short travel: wheels bent and off after a jump. */
  shortTravel: 0.04,
  fullTravel: 0.3,

  // ── Wrecked: only by one massive hit ─────────────────────────────────────────────────────────────────────────
  /** One knock at least this many m/s (along its normal, the kart's share) plus the chassis' toughness (`Kart.hp`:
   * its part times its size) wrecks the kart outright -- in bits. A fruit crate at full size: about 16 m/s, a
   * head-on into a wall near full speed. Anything less dents, bends and knocks parts off, but it drives on. */
  wreckKnock: 10,
  /** One landing at least this many m/s into the road past the springs' soak (and a jump's allowance) wrecks it. */
  wreckLanding: 13,
  /** Worn (`Kart.damage` over `Kart.hp`) to each of these shares, one more part shakes loose and falls off -- the
   * bodywork first, then a wheel at a time -- while it drives on. Past the last, each `shedEvery` more sheds another. */
  shedAt: [0.85, 1, 1.3] as readonly number[],
  shedEvery: 0.4,

  // ── What a damaged or failed part does to the driving ────────────────────────────────────────────────────────
  /** A damaged front wheel: toed out this far (radians) -- the kart pulls toward its side, a little; countersteer
   * holds it -- with this much more rolling drag, and this share of its grip. */
  frontToe: 0.06,
  frontDrag: 1.5,
  frontGrip: 0.92,
  /** A damaged rear wheel: this share of its grip (the rear steps out sooner), shimmying this far (radians) a turn. */
  rearGrip: 0.6,
  rearWobble: 0.035,
  /** A failed wheel is gone (it rolls away): its bare axle stub holds the corner up this share of the wheel's radius
   * (so the corner sits down low), with no grip, scraping on the road with this friction (a share of the load on it):
   * the kart slower, and dragged toward that corner. */
  stubLift: 0.35,
  stubScrape: 0.45,
  /** A suspension corner, damaged and failed: its spring's share (it sags), its damper's (it settles slowly and
   * bounces), and the grip it loses for each m/s its corner is bouncing (so rough ground costs, smooth hardly). */
  springDamaged: { spring: 0.8, damper: 0.3, rough: 0.04 },
  springFailed: { spring: 0.55, damper: 0.06, rough: 0.12 },
  /** The most grip a bouncing corner can lose. */
  roughMax: 0.55,

  // ── How it looks ────────────────────────────────────────────────────────────────────────────────────────────
  /** How bent a damaged wheel is drawn (`Wheel.bent`, 0 to 1: its lean and buckle, `rattle`), front and rear. */
  frontBentLook: 0.45,
  rearBentLook: 0.6,
  /** How battered damaged bodywork is drawn (`Kart.bodyDamage`: its dent and sag, `rattle`; its scuffs, `wear`). */
  bodyDentLook: 0.6,
  /** Seconds the Fizz Bomb sprays when its can is damaged (`fx`). */
  fizzFor: 0.8,
} as const;

/** A suspension corner's handling, from its state. */
export function springOf(state: number): { readonly spring: number; readonly damper: number; readonly rough: number } {
  return state === PartState.failed ? DAMAGE.springFailed : state === PartState.damaged ? DAMAGE.springDamaged : HEALTHY;
}
const HEALTHY = { spring: 1, damper: 1, rough: 0 } as const;

/**
 * A hit of `speed` m/s on a part in state `now` that last changed at `at` (clock seconds), `clock` now: its state
 * after. Softer than `light`, inside the part's cooldown, or already failed: unchanged. `severe` m/s or harder:
 * failed at once.
 */
export function struck(now: number, at: number, clock: number, speed: number, light: number, severe: number): number {
  if (now === PartState.failed || clock - at < DAMAGE.cooldown) return now;
  // Already damaged: a cracked axle (or a bent spring) gives at a lighter knock.
  if (speed < (now === PartState.damaged ? light * DAMAGE.crackedAxle : light)) return now;
  if (speed >= severe) return PartState.failed;
  return now + 1;
}

/** The share of a landing its wheel takes as well as its spring, for the suspension's travel (metres). */
export function travelShare(travel: number): number {
  return Math.min(1, Math.max(0, (DAMAGE.fullTravel - travel) / (DAMAGE.fullTravel - DAMAGE.shortTravel)));
}

/** The share of its wear (`Kart.damage / Kart.hp`) at which the kart sheds its `n`th part (from 0). */
export function shedShare(n: number): number {
  const at = DAMAGE.shedAt;
  return n < at.length ? at[n]! : at[at.length - 1]! + (n - at.length + 1) * DAMAGE.shedEvery;
}

/** Tell the HUD: `part` (`PartName`) is now `state`, this moment. */
export function callOut(kart: Store<typeof Kart.schema>, e: Entity, part: number, state: number): void {
  kart.callPart[e] = part;
  kart.callState[e] = state;
  kart.callAt[e] = kart.clock[e]!;
}

/**
 * A kart crippled by damage -- a wheel off, its bodywork gone, or most of its toughness spent -- that is hardly moving
 * is not going to get down the hill: its run ends quickly. Under CRAWL m/s (about 5.6 mph) for CRAWL_OUT_FOR seconds
 * in a row (a whole kart gets OUT_FOR, and only near enough stopped). `race` ends it; the HUD counts it down.
 */
export const CRAWL = 2.5;
export const CRAWL_OUT_FOR = 2.5;
/** Spent past this share of its toughness (`Kart.damage` over `Kart.hp`), a kart counts as crippled. */
const CRIPPLED_WORN = 0.6;
interface Hurts { wheelsLost: ArrayLike<number>; bodyLost: ArrayLike<number>; damage: ArrayLike<number>; hp: ArrayLike<number> }
export function crippled(kart: Hurts, e: number): boolean {
  return kart.wheelsLost[e]! > 0 || kart.bodyLost[e]! > 0 || kart.damage[e]! > kart.hp[e]! * CRIPPLED_WORN;
}
