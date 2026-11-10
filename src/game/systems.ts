/**
 * The game's systems, registered in order: one line each, one system a file in `systems/`.
 * Apart from `index.ts` so a worker can register the same systems over the same data without the
 * models, the scene or anything else of the page (`worker.ts`).
 *
 *   mendKart    5 Hz          a kart that lost the game's components (a failed live swap) given them back
 *   mendCamera  5 Hz          the main camera that lost its ChaseCam given one on the kart
 *   spin        60 Hz         everything with a Spin turns about its axis
 *   course      60 Hz         the chosen course loaded: its track and hazards, the old one gone
 *   race        60 Hz         the run: garage, countdown, the clock, the finish (driver aboard); R, B, falling off
 *   assemble    60 Hz         a new build turned into the kart's numbers and parts
 *   vehicle     60 Hz         springs, tyres, skids, brakes, drag, push, lean, the true centre of mass; landings, air
 *   pusher      60 Hz         the teammate at the start: crouched at the line, sprinting and shoving at GO, then flat on their face
 *   disco       30 Hz         the disco tunnel's lights strobing by turns
 *   startLights 30 Hz         the start arch's lamps: red one by one through the countdown, all green at GO
 *   ghost       60 Hz, late   the rival ghost: a recorded run replayed on the race clock, see-through, colliding with nothing (G hides it)
 *   impacts     60 Hz         knocks: bodywork and wheels off, the driver thrown, rollovers
 *   driver      60 Hz         the ragdoll thrown and the driver climbing back in (never into a kart on its side)
 *   wear        60 Hz         a kart falling to bits: scuffed and dulled, its steering snapped, parts shed, wrecked into planks
 *   stunts      60 Hz         showmanship: clean chicanes, two wheels, drifts, air spins, reverse finishes
 *   bonus       60 Hz         the gold stars on the course: spun, bobbed, collected for style points
 *   props       60 Hz         the course's hazards put back for each run
 *   sweep       60 Hz         debris cleared for each run
 *   ragdollLimit 60 Hz        no part of a thrown driver spins like a propeller
 *   driverPose  15 Hz         the seated driver's clip: sit, lean into the turn, tuck, brace in the air, cheer
 *   wheelLook   60 Hz, late   each wheel drawn on its spring, steered and spinning
 *   steerLook   60 Hz, late   the reins, wheel or handlebars in the driver's hands, turned as they steer
 *   rattle      60 Hz, late   homemade: every part a little crooked, rattling with speed, the wheels buckled
 *   slowmo      60 Hz         the crash cam: slow motion for a moment after every big crash
 *   trails      60 Hz         dust off the wheels, skid marks, sparks, landing bursts, the themed karts' own effects
 *   fxMove      60 Hz         every puff and mark moved, grown or faded, back to its pool
 *   crowd       60 Hz, late   the spectators by the course cheering: wild near the kart, swaying further off
 *   garageRoom  60 Hz         the workshop round the kart while it is built, the course hidden till the run
 *   chaseCam    60 Hz, late   the camera behind the kart, circling it in the garage
 */
import type { World } from '@vibe/engine';
import { assemble } from './systems/assemble.ts';
import { course } from './systems/course.ts';
import { chaseCam } from './systems/chase-cam.ts';
import { garageRoom } from './systems/garage-room.ts';
import { driver } from './systems/driver.ts';
import { impacts } from './systems/impacts.ts';
import { props, sweep } from './systems/props.ts';
import { race } from './systems/race.ts';
import { spin } from './systems/spin.ts';
import { vehicle } from './systems/vehicle.ts';
import { wheelLook } from './systems/wheel-look.ts';
import { driverPose } from './systems/driver-pose.ts';
import { ragdollLimit } from './systems/ragdoll-limit.ts';
import { steerLook } from './systems/steer-look.ts';
import { rattle } from './systems/rattle.ts';
import { wear } from './systems/wear.ts';
import { slowmo } from './systems/slowmo.ts';
import { fxMove, trails } from './systems/fx.ts';
import { crowd, farHide } from './systems/crowd.ts';
import { mendCamera, mendKart } from './systems/mend.ts';
import { stunts } from './systems/stunts.ts';
import { bonus } from './systems/bonus.ts';
import { pusher } from './systems/pusher.ts';
import { disco } from './systems/disco.ts';
import { startLights } from './systems/start-lights.ts';
import { ghost } from './systems/ghost.ts';

/** Registration order is the order within a dependency level, and what `world.describe()` lists. */
export function registerSystems(world: World): void {
  mendKart(world);
  mendCamera(world);
  spin(world);
  course(world);
  garageRoom(world);
  race(world);
  assemble(world);
  vehicle(world);
  pusher(world);
  disco(world);
  startLights(world);
  ghost(world);
  impacts(world);
  driver(world);
  wear(world);
  stunts(world);
  bonus(world);
  slowmo(world);
  trails(world);
  fxMove(world);
  crowd(world);
  farHide(world);
  props(world);
  sweep(world);
  ragdollLimit(world);
  driverPose(world);
  wheelLook(world);
  steerLook(world);
  rattle(world);
  chaseCam(world);
}
