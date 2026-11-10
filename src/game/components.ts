/**
 * The game's data model: every component, relation, event and tag, in one file -- read it first, it
 * says what exists. What is made of them is a prefab (`prefabs.ts`, the files under
 * `src/assets/prefabs/`); what happens to them is `systems/`.
 *
 * Numbers go in a `component` (typed arrays, fast) -- an enum, flags, a colour, a vector, a ref to an
 * entity and an asset's key are numbers too, each with its own widget in the inspector. A yes or no is
 * a `tag`. A list, a dictionary, text or a record is a `dataComponent`. A field systems set as the game
 * runs is `runtime`: a save keeps it, a prefab file never says it. Every component at module level.
 * Which kind for what, and the options (`min`, `max`, `slider`, `label`, `help`, `group` …): the
 * `engine` skill's `fields` page.
 */
import { bool, component, enumOf, event, f32, ref, tag, u8, u16 } from '@vibe/engine';
import { Weather } from './weather.ts';

/** An axis to turn about: an enum -- a drop-down in the inspector, `"x"` in a file, `Axis.x` in code. */
export const Axis = enumOf(['y', 'x', 'z'], 'y');

/**
 * Turns about one of its own axes: `speed` in radians a second (a slider, -6 to 6: negative turns the
 * other way), `axis` which one. Both set in its prefab file, or in the inspector.
 */
export const Spin = component('Spin', {
  speed: f32(0.6, { min: -6, max: 6, slider: true, step: 0.1, label: 'Turn speed', help: 'Radians a second; negative turns the other way' }),
  axis: Axis.as('y', { help: 'Which of its own axes it turns about' }),
}, { menu: 'Motion', help: 'Turns about one of its own axes' });


/** Seconds of countdown before the kart is let go. */
export const COUNTDOWN = 3;
/** Seconds of the flyover down the course before a run from the garage (`Order.tour`): skippable. */
export const FLYOVER = 6;

/** Where a run is: in the garage (the builder up, the kart parked), counting down, racing, over the line -- or over, not finished (`Kart.out` says why). */
export const Phase = enumOf(['garage', 'countdown', 'racing', 'finished', 'over'], 'garage');

/** Why a run ended short of the line: off the road, the driver out of the kart, or the kart near enough stopped -- each too long. */
export const RunOut = enumOf(['none', 'offTrack', 'driverOut', 'stopped', 'crashed', 'wrecked', 'pond'], 'none');
/** Seconds in a row any of them may last before the run is over. */
export const OUT_FOR = 6;
/** Seconds on its side or its back (nearly still) before the run is over: time for the driver to rock it back up. */
export const CRASHED_FOR = 5;
/** Seconds on its roof (its up pointing down: ON_ITS_ROOF or less) before the run is over -- moving or not. */
export const ROOF_FOR = 2;
export const ON_ITS_ROOF = -0.5;
/** Seconds after the driver is thrown out that the run is over: no climbing back in, just long enough to watch them tumble. */
export const THROWN_FOR = 2.5;

/** What the builder asks of the race, once: start a run, back to the garage, or the same run again. */
export const Order = enumOf(['none', 'race', 'garage', 'restart', 'tour', 'skip'], 'none');

/**
 * The kart as built: an index into each of the garage's lists (`build.ts`: CHASSIS, WHEELS ...). The
 * builder writes them and bumps `version`; `assemble` turns a new version into the kart's numbers and
 * parts. `order` is the builder's request to the race, cleared once acted on.
 */
export const Build = component('Build', {
  chassis: u8(0, { max: 5, help: 'Plank (the start), fruit crate, bathtub, shopping trolley, wheelie bin, canoe' }),
  wheels: u8(0, { max: 7, help: 'Pram, trolley casters, bike, skateboard, tractor, slicks, cart, lawnmower' }),
  suspension: u8(1, { max: 3, help: 'Bolted on, bed springs, shocks, pogo springs' }),
  steering: u8(0, { max: 3, help: 'Rope reins, go-kart wheel, bike handlebars, twin brake levers' }),
  body: u8(0, { max: 27, help: 'Nothing (a bare chassis), rocket sled, flying trolley, couch potato, air fryer, snail, toilet, toaster, flying saucer, prawn, drinks can, giant foot, formula racer, streamliner, crate, camper van, pickup, steel truck, space fighter, gull-wing, moon rocket, shark, taco, stone-age, pram, city car, go-kart, tank engine' }),
  outfit: u8(0, { max: 8, help: 'The driver\'s outfit: racer, chicken, banana, viking, granny, chef, giant baby, caveman, hot sauce' }),
  chassisWidth: u8(100, { min: 60, max: 160, step: 10, help: 'Chassis width, percent: its box across, its track, weight and drag' }),
  chassisLength: u8(100, { min: 60, max: 160, step: 10, help: 'Chassis length, percent: its box along, its wheelbase and weight' }),
  frontSize: u8(100, { min: 50, max: 200, step: 10, help: 'The front wheels scaled, percent' }),
  rearSize: u8(100, { min: 50, max: 200, step: 10, help: 'The rear wheels scaled, percent' }),
  springSize: u8(100, { min: 50, max: 200, step: 10, help: 'The suspension\'s travel scaled, percent: longer soaks up more' }),
  course: u8(0, { max: 19, help: 'Which of the twenty courses: 0 the first, 19 the last' }),
  version: u16(1),
  /** How many courses are open to race (the page's progress, told by the garage): a locked one only shows. */
  open: u8(1),
  order: Order.as('none'),
  /** A menu is up over the garage (the course select): Enter is the menu's, not the race's. */
  menu: bool(false),
}, { runtime: ['version', 'order', 'open', 'menu'], menu: 'Karts', help: 'What the kart is built from' });

/** Why the last thing went wrong: what the results screen explains. */
export const Cause = enumOf(['none', 'wheelLanding', 'wheelKnock', 'bodyKnock', 'thrownKnock', 'thrownLanding', 'rolled', 'wrecked'], 'none');

/** A part's damage (each wheel, each suspension corner, the bodywork): whole, damaged, or failed (`damage.ts`). */
export const PartState = enumOf(['healthy', 'damaged', 'failed'], 'healthy');
/** Which part a damage callout is about: the four wheels, the four suspension corners (in `Corner`'s order), the bodywork. */
export const PartName = enumOf(['wheelFL', 'wheelFR', 'wheelRL', 'wheelRR', 'springFL', 'springFR', 'springRL', 'springRR', 'body'], 'wheelFL');

/** The last thing worth shouting about, for the HUD. */
export const News = enumOf(['none', 'go', 'bigAir', 'lostWheel', 'lostBody', 'thrown', 'backIn', 'alone', 'righted', 'lostSteering', 'wrecked', 'bent', 'cleanChicane', 'reverseFinish', 'twoWheels', 'drift', 'airSpin', 'limpedHome', 'bonus', 'clearedDucks', 'spin', 'reversing'], 'none');

/**
 * A homemade kart: one rigid body (the chassis' box) held up by four raycast wheels (`Wheel`
 * children) -- springs, grip, skids and brakes in `vehicle`, knocks in `impacts`, the driver thrown
 * and climbing back in `driver`, the run's clock and the finish in `race`. Every field is the
 * systems': what `assemble` worked out from the `Build`, the run's state, and its score.
 */
export const Kart = component('Kart', {
  phase: Phase.as('garage'),
  // The course loaded (255: none yet), and the entity its track and hazards hang under.
  course: u8(255),
  courseRoot: ref(),
  // The garage's room round it while it is built (`garageRoom`), and the course it was last set on (255: none).
  room: ref(),
  roomCourse: u8(255),
  clock: f32(),
  progress: f32(-1),
  // On the course's shortcut now (`race`'s routeAt), and taken it this run.
  onCut: bool(false),
  tookCut: bool(false),
  // What happened in the run, for the results' awards and their one observation: every part damaged or failed by a
  // knock or a landing (`hurts`); the corners (a bit each, fl fr rl rr) whose wheels were hurt on the shortcut; the
  // share of the course down when it rolled over (-1 never); seconds driven with a wheel gone, how far, and its speed
  // the moment the first went; and over the line going backwards.
  hurts: u16(),
  /** Every knock against anything on the course (a wall, a prop, a bale -- not a ramp, not the road under it) counted,
   * the last one's closing speed (m/s), and whether it was something soft (a hay bale): heard (`sounds.ts`). */
  bumps: u16(),
  bumpSpeed: f32(),
  bumpSoft: u8(),
  cutHurt: u8(),
  rolledAt: f32(-1),
  limpFor: f32(),
  limpDist: f32(),
  lossSpeed: f32(),
  backwards: bool(false),
  // The rival ghost chased on this course (`ghost`): its entity, and whether the player has hidden it (G).
  ghost: ref(),
  ghostOff: bool(false),
  // Over the duck pond this run (`race`: its news once).
  ducks: bool(false),
  finishTime: f32(),
  built: u16(),
  // What the build adds up to (assemble).
  mass: f32(100),
  comY: f32(),
  comZ: f32(),
  halfTrack: f32(0.5),
  halfBase: f32(0.7),
  // How far its back is behind its middle, metres (`build.ts`' Rating.behind): where the teammate pushes from.
  halfBack: f32(0.9),
  halfHeight: f32(0.2),
  rideY: f32(0.4),
  seatY: f32(),
  radius: f32(0.2),
  travel: f32(0.1),
  spring: f32(),
  damper: f32(),
  grip: f32(1),
  strength: f32(6),
  soak: f32(),
  lock: f32(0.4),
  steerRate: f32(2),
  /** m/s at which half the steering's lock is left (`STEERING`'s fade). */
  steerFade: f32(11),
  /** Twin brake levers (`STEERING`'s levers): the front wheels straight, steering brakes that side's rear wheel this hard. 0: steers. */
  levers: f32(),
  /** Radians the front wheels sit off straight, as badly as it was put together: it pulls to one side (`assemble`). */
  pull: f32(),
  /** Whether the kart as built is within the rules (`rulesBreak`: the budget, the weight, the sizes): only then may it race. */
  legal: bool(true),
  brake: f32(0.4),
  drag: f32(0.4),
  wobble: f32(),
  /** Its wheels have thin rims (`WheelPart.thin`): they buckle on a hard landing. */
  thin: bool(false),
  seatGrip: f32(9),
  bodyStrength: f32(99),
  appeal: f32(),
  // Driving.
  steer: f32(),
  lean: f32(),
  speed: f32(),
  upY: f32(1),
  lastVX: f32(),
  lastVY: f32(),
  lastVZ: f32(),
  accelX: f32(),
  accelY: f32(),
  accelZ: f32(),
  // How much of a change in spin the kart takes, about its own x, y and z: the box's inertia over the true one.
  turnX: f32(1),
  turnY: f32(1),
  turnZ: f32(1),
  lastWX: f32(),
  lastWY: f32(),
  lastWZ: f32(),
  air: f32(),
  /** Seconds in the air of the landing it just made (`vehicle` sets it, `fx` takes it: dust, bolts shaken loose), and
   * how hard the camera shakes now (`chaseCam`, easing out). */
  landed: f32(),
  shake: f32(),
  // The new parts: rolling resistance, the parachute, the rocket (its fuel left), the wings.
  rolling: f32(0.015),
  chute: f32(),
  thrust: f32(),
  fuel: f32(),
  fuelMax: f32(),
  boosting: bool(false),
  wing: f32(),
  tucked: bool(false),
  // The driver.
  thrown: Cause.as('none'),
  ejected: bool(false),
  ejectTime: f32(),
  ragdoll: ref(),
  torso: ref(),
  /** Its steering part, made under it the first time it is built (`assemble`). */
  steering: ref(),
  stuck: f32(),
  /** Seconds it has been upside down, on its roof, in a row (`ROOF_FOR` of it and the run is over). */
  roofFor: f32(),
  // Wear: what the knocks and landings have done to it, against what its chassis takes (`hp`, assemble). Half gone
  // and the steering snaps off; past that, parts shake loose and fall off one by one (`shed` of them so far, `wear`)
  // -- but it drives on. Only `smash` -- one massive knock or landing, or right off the side of the course -- wrecks
  // it, in bits, and the run starts again WRECK seconds later.
  damage: f32(),
  hp: f32(50),
  shed: u8(),
  shedClock: f32(-99),
  smash: bool(false),
  // How long, in a row, it has been off the road, without its driver, and near enough stopped: too long, and the run
  // is over (`race`), why in `out`.
  offFor: f32(),
  /** The longest it has been in the air since it went off the side (`race`: it breaks up only once it comes down). */
  offAir: f32(),
  /** Seconds left of the flyover down the course before the countdown (0, none): the countdown waits for it. */
  flyover: f32(),
  /** Waiting at the line for the player to start (after the flyover, the field on show): the countdown waits too. */
  waiting: bool(false),
  outFor: f32(),
  stillFor: f32(),
  out: RunOut.as('none'),
  // The weather on this visit to the course (`weather.ts`, dealt by `race` each time its garage is come to), how many
  // visits there have been, and which side the crosswind blows from (+1 the road's left, -1 its right).
  weather: Weather.as('sunny'),
  visits: u16(),
  windSide: f32(1),
  /** The course the weather was dealt for (255: none yet). */
  weatherFor: u8(255),
  /** Its teammate at the start (`pusher`), while there is one. */
  pusher: ref(),
  // A ramp's grace, seconds: set while a wheel rides a ramp or jump, held through the flight off it, running down once
  // it is back on the road. While it lasts nothing on the way over a ramp throws the driver, snaps a wheel, wears it or
  // counts as a roll, and in the air it levels itself to land on its wheels (`vehicle`, `impacts`).
  grace: f32(),
  steerOn: bool(true),
  wrecked: bool(false),
  wreckedAt: f32(),
  // The bodywork, and the score.
  bodyOn: bool(true),
  /** How battered the bodywork is, 0 new to 1 hanging on by a thread: every knock it takes short of coming off adds to it -- it chips, dents and sags the more (`rattle`, `wear`), and comes off the sooner. */
  bodyDamage: f32(),
  /** Where the last knock it felt struck it, in its own frame: across (-1 its right .. 1 its left) and along (-1 its
   * tail .. 1 its nose), as shares of its half track and half base (`impacts`). 0, 0: nothing yet, or square on. The
   * side that got hit is the side that suffers: the bodywork sags that way (`rattle`), the wheel nearest it goes
   * first (`wear`). */
  hitSide: f32(),
  hitEnd: f32(),
  /** The crash cam: game seconds of slow motion left after a big crash (`slowmo`), the crashes counted so far this run
   * (so each sets it off once), and when the last one began. */
  slowFor: f32(),
  crashes: u16(),
  slowAt: f32(-99),
  style: f32(),
  jumps: u8(),
  wheelsLost: u8(),
  bodyLost: u8(),
  ejections: u8(),
  rollovers: u8(),
  cause: Cause.as('none'),
  causeSpeed: f32(),
  news: News.as('none'),
  newsAt: f32(-99),
  newsValue: f32(),
  // Where in the world the news happened, for the ones said there (a bonus star grabbed: over the star).
  newsX: f32(),
  newsY: f32(),
  newsZ: f32(),
  // The stunts it is pulling (`stunts`): seconds on two wheels and sliding sideways so far, its turn about its up in the
  // air so far (radians), the chicanes it touched and those it is through (a bit each, `Chicane.index`), where it was
  // along the road last tick, how many repeatable stunts it has scored (each the less), and whether its finish is judged.
  twoFor: f32(),
  driftFor: f32(),
  /** Seconds the driver has been pushing it uphill (`vehicle`'s UPHILL_*): their legs give out, gentler the slope the later. */
  uphillFor: f32(),
  airYaw: f32(),
  // On its wheels: its turn about its up so far (radians) and how long it has turned too slowly to be spinning; how
  // long it has rolled backwards.
  groundYaw: f32(),
  groundCalm: f32(),
  backFor: f32(),
  chicaneHits: u8(),
  chicaneDone: u8(),
  lastProgress: f32(-1),
  repeats: u8(),
  finishJudged: bool(false),
  /** Whether its build has suspension to take a landing (not bolted on): without, a hard landing is the wheel's. */
  sprung: bool(true),
  /** The bodywork's damage (`PartState`), and the clock when it last changed (its cooldown runs from it). */
  bodyState: PartState.as('healthy'),
  bodyAt: f32(-99),
  /** The last change of a part's state, for the HUD's lower third: which part, to what, when (clock); -99 none. */
  callPart: PartName.as('wheelFL'),
  callState: PartState.as('healthy'),
  callAt: f32(-99),
}, { runtime: true, menu: 'Karts', help: 'A homemade kart: its numbers, its run and its score' });

/** Which corner a wheel is on: front left, front right, rear left, rear right (+x is the kart's left). */
export const Corner = enumOf(['fl', 'fr', 'rl', 'rr'], 'fl');

/** A wheel of its parent kart: where it is (`corner`) and, as the kart runs, its spring and spin. */
export const Wheel = component('Wheel', {
  corner: Corner.as('fl'),
  compression: f32(),
  spin: f32(),
  angle: f32(),
  attached: bool(true),
  grounded: bool(false),
  /** Seconds it has been on the road without a break (`vehicle`): long enough, and pressed into it is a dip, not a landing. */
  onRoad: f32(),
  locked: bool(false),
  /** Its radius as built (the front and rear wheels may differ), metres. */
  radius: f32(0.2),
  /** How bent it is, 0 true to 1 as bent as a wheel gets and still turns: knocks and hard landings bend it short of
   * snapping it off. A bent wheel wobbles on its axle, leans, grips less and drags (`vehicle`, `rattle`). */
  /** Where it touches the road this tick (world metres) and how fast its tyre slides across it there (m/s): `fx`'s dust and skid marks. */
  hitX: f32(), hitY: f32(), hitZ: f32(),
  slip: f32(),
  /** Where it last laid a skid mark (`trails`: the next one a step on from it). */
  markX: f32(), markZ: f32(),
  bent: f32(),
  /** The wheel's damage and its corner's suspension's (`PartState`), and the clock when each last changed (their
   * cooldowns run from it): `damage.ts` sets them, `vehicle` drives on them. */
  state: PartState.as('healthy'),
  stateAt: f32(-99),
  spring: PartState.as('healthy'),
  springAt: f32(-99),
  /** Its tyre against a wall last tick (`vehicle`): only the moment it first meets one is a knock, not the scrape after. */
  walled: bool(false),
}, { runtime: ['compression', 'spin', 'angle', 'attached', 'grounded', 'onRoad', 'locked', 'radius', 'bent', 'hitX', 'hitY', 'hitZ', 'slip', 'markX', 'markZ', 'state', 'stateAt', 'spring', 'springAt', 'walled'], menu: 'Karts', help: 'A kart\'s wheel' });

/** The kart's chassis look, its driver sat in it, and its bodywork: the parts `assemble` dresses. */
export const ChassisLook = tag('ChassisLook');
export const Seat = tag('Seat');
export const Bodywork = tag('Bodywork');
/** A ramp or a jump: a kart riding one, and flying off it, is given its grace (`Kart.grace`). */
export const Kicker = tag('Kicker');

/** The kart's steering -- reins, wheel or handlebars -- in the driver's hands, turned as they steer (`steerLook`). */
export const SteeringLook = tag('SteeringLook');

/** What came off: thrown drivers, lost wheels and bodywork. Swept away when the run starts again. */
export const Debris = tag('Debris');
/** A spark (`sparks.ts`): an effect (`Fx`) drawn as a glowing streak along its flight, falling, gone in a moment. */
export const Spark = tag('Spark');
/** Scenery not drawn far from the camera (`crowd`' farHide): the course's loose hay bales, the pensioners' chairs. */
export const FarHide = tag('FarHide');
/** The wheelie bin's lid (`karts/parts#bin_lid`), hung open down its back from its hinge: shown on the bin alone
 * (`assemble`), flapping as it rattles down the hill (`rattle`). */
export const BinLid = tag('BinLid');
/** A body's see-through piece (`BODY.glass`: the pram's hood), drawn in its own see-through material (`assemble`);
 * gone with the bodywork (`impacts`' shatterBody). */
export const BodyGlass = tag('BodyGlass');

/** A course hazard that can be knocked about, and is put back where it stood for every run. */
/** The teammate who pushes the kart off at the start (`pusher`): the kart they push, what they are doing (0 ready at
 * the line, 1 running and pushing, 2 let go, stumbling, 3 flat on their face), since when (the kart's clock), and where
 * they let go, facing which way. */
export const Pusher = component('Pusher', {
  kart: ref(),
  state: u8(),
  since: f32(),
  x: f32(), y: f32(), z: f32(),
  yaw: f32(),
  /** How hard they shove, m/s² on the kart, while they push. */
  push: f32(3.2, { min: 0, max: 10, help: 'How hard they shove the kart, m/s²' }),
}, { runtime: ['kart', 'state', 'since', 'x', 'y', 'z', 'yaw'], menu: 'Karts', help: 'The teammate pushing the kart off at the start' });

/** A piece of a chicane's wall (`course`): which chicane (its bit in `Kart.chicaneHits`), and the road's sample past
 * its end -- through to there without touching any of its pieces is a clean chicane (`stunts`). */
export const Chicane = component('Chicane', {
  index: u8(),
  exit: u16(),
}, { runtime: true, menu: 'Course', help: 'A piece of a chicane: go through it without a touch for style' });

/** A rival's ghost (`ghost`): the kart it races beside, and which reference run it replays (`ghost-runs.ts`). Never
 * collides: it has no body. */
export const Ghost = component('Ghost', {
  kart: ref(),
  run: u8(),
}, { runtime: true, menu: 'Karts', help: 'A rival ghost replaying a recorded run' });

/** A set of the disco tunnel's lights (`disco`): 0 or 1, the two flashed by turns. */
/** One of the start arch's three lamps (`startLights` lights them through the countdown): 0 the first lit. */
export const StartLamp = component('StartLamp', {
  index: u8(0, { max: 2, help: 'Which lamp: 0 the first lit, 2 the last' }),
}, { menu: 'Course', help: 'A start light on the arch, lit red through the countdown and green at GO' });

export const Disco = component('Disco', {
  set: u8(0, { max: 1, help: 'Which set: the two flash by turns' }),
}, { menu: 'Course', help: 'A set of the disco tunnel lights, strobing' });

/** A bonus to collect (`bonus`): a gold star on the course, often somewhere risky -- in the air over a jump, up a
 * berm's high side, squeezed between a hazard and the wall. Driven through, it is the kart's style points. */
export const Bonus = component('Bonus', {
  value: u16(50, { max: 500, help: 'Style points it is worth' }),
  taken: bool(false),
  baseY: f32(),
  placed: bool(false),
}, { runtime: ['taken', 'baseY', 'placed'], menu: 'Course', help: 'A gold star to collect for style points' });

export const Prop = component('Prop', {
  homeX: f32(), homeY: f32(), homeZ: f32(),
  homeQX: f32(), homeQY: f32(), homeQZ: f32(), homeQW: f32(1),
  placed: bool(false),
}, { runtime: true, menu: 'Course', help: 'Knocked about, and put back for each run' });

/** A prop that bursts apart when hit hard enough (a hay bale): gone for the rest of the run, back for the next. */
export const Breakable = component('Breakable', {
  /** m/s of knock that bursts it. */
  strength: f32(5, { min: 0, max: 30 }),
  /** Hit this hard this tick (`impacts`), m/s: `props` bursts it. */
  struck: f32(),
  broken: bool(false),
}, { runtime: ['struck', 'broken'], menu: 'Course', help: 'Bursts apart when hit hard, and is back for the next run' });

/** A run started again (a restart, or a new run from the garage): what was knocked about goes back. */
export const RaceReset = event('RaceReset', { kart: ref() });

/**
 * A camera chasing a kart (`target`): `distance` behind it, `height` up, looking `look` above it,
 * swinging round after it `follow` times a second. In the garage it circles the kart slowly.
 */
export const ChaseCam = component('ChaseCam', {
  target: ref(Kart),
  distance: f32(4.8, { min: 2, max: 20, slider: true, help: 'Metres behind the kart' }),
  height: f32(1.9, { min: 0.5, max: 10, slider: true, help: 'Metres above the kart' }),
  look: f32(0.8, { min: 0, max: 4, help: 'Metres above the kart it looks at' }),
  follow: f32(4, { min: 0.5, max: 20, help: 'How quickly it catches up, per second' }),
  yaw: f32(),
  x: f32(), y: f32(), z: f32(),
  ready: bool(false),
  /** The share of the way out to it the camera keeps, short of what is between it and the kart: eased, so a sight
   * line that grazes something (a bale, the arch, a crest) does not jerk it in and out frame by frame. */
  keep: f32(1),
  /** In the garage, turned by hand: the drag's last x (-1 not dragging), and seconds since the last turn by hand. */
  dragX: f32(-1),
  idle: f32(99),
}, { runtime: ['yaw', 'x', 'y', 'z', 'ready', 'keep', 'dragX', 'idle'], menu: 'Karts', help: 'Chases a kart' });

/** The driver's skinned body when thrown: posed bone by bone from the ragdoll's bodies (`ragdoll-skin.ts`). */
export const RagdollSkin = tag('RagdollSkin');

/** Which of the driver's bones a ragdoll body moves: the hips (and the spine on them), the head, an arm, a leg. */
export const Bone = enumOf(['hips', 'head', 'armL', 'armR', 'legL', 'legR', 'foreArmL', 'foreArmR', 'shinL', 'shinR'], 'hips');

/** A ragdoll body, and the bone of the driver's skin it moves. */
export const RagdollBone = component('RagdollBone', {
  bone: Bone.as('hips', { help: 'The bone of the driver\'s skin this body moves' }),
}, { menu: 'Karts', help: 'A ragdoll body: the bone it moves' });

/** A kart's suspension spring, seen: at one corner, stretched each frame between the chassis and that wheel. */
export const Spring = component('Spring', {
  corner: Corner.as('fl', { help: 'The wheel it holds up' }),
}, { menu: 'Karts', help: 'A spring drawn between the chassis and its wheel' });

/**
 * A puff of dust, a spark, a skid mark: a short-lived effect `fx` moves and grows (or shrinks) and puts back in its
 * pool when its life is up -- drifting at its velocity (m/s), slowing by `drag` a second, pulled down by `fall`
 * (m/s²), its size easing from `from` to `to` (metres, its scale) over its `life` (seconds). A mark keeps its own
 * length and width (`sx`/`sz` as laid) and only its fade-out shrink.
 */
export const Fx = component('Fx', {
  vx: f32(), vy: f32(), vz: f32(),
  drag: f32(),
  fall: f32(),
  from: f32(0.2),
  to: f32(0.6),
  life: f32(1),
  age: f32(),
  mark: bool(false),
}, { runtime: true, menu: 'Karts', help: 'A short-lived effect: dust, a spark, a skid mark' });

/** A spectator by the course (`crowd` animates it): where it stands, and its own beat (so a crowd is not in step). */
/** Who a spectator is (`course` dresses them, `crowd` moves them as their sort would). */
export const FanRole = enumOf(['adult', 'kid', 'flag', 'placard', 'filmer', 'pensioner', 'costume', 'mechanic', 'marshal'], 'adult');
export const Fan = component('Fan', {
  role: FanRole.as('adult'),
  baseY: f32(),
  // The way they face the road (radians about up), as placed: they turn their heads from it to follow the kart.
  baseYaw: f32(),
  yaw: f32(),
  beat: f32(),
  placed: bool(false),
}, { runtime: true, menu: 'Course', help: 'A spectator at the village fete' });
