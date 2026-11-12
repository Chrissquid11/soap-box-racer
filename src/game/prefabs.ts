/**
 * What the game makes: its prefabs, one token each, by key -- `prefab('crate')` is
 * `src/assets/prefabs/crate.prefab`, which says what the thing is built from: its entities, their
 * components and numbers, its model. A token (and a node, `Crate.node('lid')`) at module level; in a
 * system `ctx.cmd.instantiate(Crate)`, outside one `world.instantiate(Crate)`. Never a `kind(`.
 */
import { prefab } from '@vibe/engine';

/** The placeholder crate: spins (`Spin`) where it is put. */
export const Crate = prefab('crate');

/**
 * A crate with a body (`RigidBody`, `BoxCollider`): the physics stage drops it, and it tumbles and comes to rest on
 * the floor. Its numbers are the physics' -- never move it by its `Transform` every tick; push it (`Forces`).
 */
export const FallingCrate = prefab('falling-crate');

/** The floor: a collider with no body, so it never moves -- what the falling crate lands on. */
export const Floor = prefab('floor');

/** The camera the game is seen through (`Camera`, main): still, looking at the crate. Move it by its `Transform`. */
export const MainCamera = prefab('camera/main');

/**
 * A course's track: its model (`courses/cNN`, set as it is made by the `course` system) drawn and collided
 * with as it is (`MeshCollider`): road, hay walls, valley, trees.
 */
export const CourseTrack = prefab('course/track');
/** One part of a course's model made solid (`course` lays one for each part a kart can hit): a collider, no look. */
export const CourseSolid = prefab('course/solid');
/**
 * A solid block under the road (or behind a wall), never drawn: the course lays a run of them so nothing that
 * slips through the road's thin surface can fall -- a backstop, a hair under what is ridden.
 */
export const Underlay = prefab('course/underlay');
/** The workshop the kart is built in: stood round it in the garage, the course out of sight (`garageRoom`). Drawn only. */
export const GarageRoom = prefab('garage/shed');

/**
 * The homemade kart: one rigid body (its chassis' box) on four raycast wheels, its driver, its
 * bodywork -- dressed from its `Build` by `assemble`.
 */
export const HomemadeKart = prefab('karts/kart');

/** The camera that chases the kart (`ChaseCam`), and circles it in the garage. */
export const ChaseCamera = prefab('camera/chase');

/** The thrown driver: ten bodies on joints (knees and elbows hinged), and its parts by node, for their starting speed. */
export const Ragdoll = prefab('karts/ragdoll');
export const RagSkin = Ragdoll.node('skin');
export const RagTorso = Ragdoll.node('torso');
export const RagHead = Ragdoll.node('head');
export const RagArmL = Ragdoll.node('arm left');
export const RagArmR = Ragdoll.node('arm right');
export const RagLegL = Ragdoll.node('leg left');
export const RagLegR = Ragdoll.node('leg right');
export const RagForeArmL = Ragdoll.node('forearm left');
export const RagForeArmR = Ragdoll.node('forearm right');
export const RagShinL = Ragdoll.node('shin left');
export const RagShinR = Ragdoll.node('shin right');

/** The kart's steering -- reins, wheel or handlebars -- made under it by `assemble` the first time it is built, and turned by `steerLook`. */
export const SteeringPart = prefab('karts/steering');

/** What comes off a kart: a wheel, the bodywork. Debris, swept away for the next run. */
export const LooseWheel = prefab('karts/loose-wheel');
/** A spark: metal scraping the road, a knock on a wall (`sparks.ts`; `karts/spark.prefab`). */
export const SparkFx = prefab('karts/spark');
/** The teammate who pushes the kart off at the start (`pusher`): `karts/teammate.prefab`. */
export const Teammate = prefab('karts/teammate');
export const LooseBody = prefab('karts/loose-body');
/** A body's signature piece that rolls off ahead of the kart (`impacts`' SIGNATURES: the snail's shell): a ball. */
export const LooseShell = prefab('karts/loose-shell');
/** A kart falling to bits: a splinter knocked off by a hit, a broken plank when it is wrecked. Pooled; debris too. */
export const Splinter = prefab('karts/bit');
export const BrokenPlank = prefab('karts/plank');
/** A shard of a kart's bodywork or frame (or a bolt): what a wreck or a knocked-off body bursts into, tinted as what it broke off. */
export const Shard = prefab('karts/shard');

/** The course's hazards: a kicker ramp, the big final jump (static), and bins, cones and bales to knock about. */
export const Ramp = prefab('course/ramp');
export const Jump = prefab('course/jump');
export const Rattler = prefab('course/rattler');
export const Stairs = prefab('course/stairs');
export const Gravel = prefab('course/gravel');
export const Foam = prefab('course/foam');
export const Splash = prefab('course/splash');
export const Tunnel = prefab('course/tunnel');
/** A giant foam duck bobbing on the fete's duck pond (`course`): only the look. */
export const Duck = prefab('course/duck');
/** A rival's ghost kart, see-through (`ghost`). */
export const GhostKart = prefab('karts/ghost');
export const Bin = prefab('course/bin');
export const Cone = prefab('course/cone');
export const Bale = prefab('course/bale');
/** The square bales lining the course's edges, thickest round the bends: knocked about, or burst apart when hit hard. */
export const HayBale = prefab('course/hay-bale');
/** The effects: a puff of dust (or a spark) and a skid mark, pooled (`fx`). */
export const Puff = prefab('karts/puff');
export const ClingBit = prefab('karts/cling');
export const Mark = prefab('karts/mark');
/** A stack of old tyres: the chicanes' walls, knocked about and put back for each run. (Laid now as loose tyres.) */
export const TyreStack = prefab('course/tyre-stack');
/** One old tyre, lying flat: the chicanes' stacks are three of them, each a body of its own that is knocked about
 * separately (`course` stacks them). */
export const Tyre = prefab('course/tyre');
/** A gold star to collect (`bonus`), laid by `course` in the risky places. */
export const BonusStar = prefab('course/bonus');
/** The inflatable arch over the start line (drawn only: its legs stand outside the walls). */
export const StartArch = prefab('course/start-arch');
/** One of the start arch's three lamps: on the arch, swaying with it, lit by `startLights`. */
export const StartLampPart = prefab('course/start-lamp');
/** A spectator behind the walls: the driver's own figure in one of the outfits, cheering (`crowd` picks its clip). */
export const Spectator = prefab('course/fan');
/** A pensioner's folding deck chair, set under them in the crowd (`course`). */
export const FoldingChair = prefab('course/chair');
