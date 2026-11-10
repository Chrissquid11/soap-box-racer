/**
 * The garage: every part a kart can be built from, its price and what it does, and `rate` -- what a
 * build adds up to (mass, centre of gravity, drag, grip, toughness, crowd appeal), the ratings and the
 * warnings the builder shows. Plain data and arithmetic, read by both the systems (`assemble` turns a
 * build into the kart's numbers) and the builder's UI. Nothing here holds the world.
 *
 * Units: metres, kilograms, seconds. The kart faces +z; its origin is the middle of its chassis' box.
 */

export interface Part {
  readonly name: string;
  readonly cost: number;
  /** One line the builder shows under the choice. */
  readonly blurb: string;
}

export interface ChassisPart extends Part {
  readonly mass: number;
  /** The colour of what it breaks into (splinters, shards): its own, as modelled. */
  readonly colour: number;
  /** Where the driver sits along it, metres (+z forward; left out, DRIVER_Z): forward in a bin, clear of its back. */
  readonly seat?: number;
  /** The box: the kart's collider and the model's size. */
  readonly size: readonly [number, number, number];
  /** Between the left and right wheels, and the front and rear axles. */
  readonly track: number;
  readonly base: number;
  /** Frontal drag area (m²), as built: 0.6 × this × v² newtons. */
  readonly drag: number;
  /** How much knocking about it takes before it falls to bits: m/s of knock past what is felt, summed. */
  readonly hp: number;
  readonly model: string;
}

export interface WheelPart extends Part {
  readonly radius: number;
  /** The front wheels' radius as a share of the rear's (a tractor's little steering wheels); 1 if not given. */
  readonly front?: number;
  /** The smallest either end may be sized to, percent (the builder's own least if not given). */
  readonly smallest?: number;
  readonly mass: number;
  /** Friction against the road: lateral and braking grip as a share of the load. */
  readonly grip: number;
  /** m/s of hit it takes to snap one off (a landing's, or a knock on its corner). */
  readonly strength: number;
  /** How much it shimmies about at speed (trolley casters). */
  readonly wobble: number;
  /** Rolling resistance, a share of the load: big soft tyres drag, hard little ones run free. */
  readonly rolling: number;
  readonly model: string;
  /** A thin rim (a bike's, a pram's, a cart's spokes): it can buckle right over on a hard landing, short of snapping off. */
  readonly thin?: boolean;
}

export interface SuspensionPart extends Part {
  /** Metres of travel before it bottoms out. */
  readonly travel: number;
  /** How stiff: the share of its travel the kart's weight squeezes is 1 over this. */
  readonly stiff: number;
  /** Damping, as a share of critical. */
  readonly damp: number;
  /** m/s of landing it soaks up before the wheels feel it. */
  readonly soak: number;
  /** Its look at each corner, between the chassis and the wheel (stretched to fit). */
  readonly model: string;
}

export interface SteeringPart extends Part {
  /** Radians of lock, and how fast the wheels get there (radians a second). */
  readonly lock: number;
  readonly rate: number;
  /** m/s at which half its lock is left: low, it goes dull and safe at speed; high, it stays twitchy. */
  readonly fade: number;
  /** Twin brake levers in place of steering: the front wheels fixed straight, and steering pulls the lever on that side,
   * braking its rear wheel with this share of the load (the kart swings round it, slowing). 0 if not given. */
  readonly levers?: number;
  /** Its look: the model, held where the driver's hands are -- `up` metres over the seat, `ahead` along z from the kart's middle -- tipped `tilt` degrees back toward them, and turned `turns` times the wheels' angle as they steer. */
  readonly model: string;
  readonly up: number;
  readonly ahead: number;
  readonly tilt: number;
  readonly turns: number;
}

export interface BrakePart extends Part {
  /** Braking force as a share of the load: more than the wheels' grip locks them. */
  readonly force: number;
  /** Drag area (m²) it opens while braking: a parachute brakes by the air, harder the faster. */
  readonly chute: number;
}

export interface BodyPart extends Part {
  readonly mass: number;
  /** Drag area added (negative: smoother). */
  readonly drag: number;
  readonly appeal: number;
  /** m/s of knock it takes to come off. */
  readonly strength: number;
  /** Where it sits: over the chassis' top, metres along z. */
  readonly z: number;
  /** Its own centre of mass, metres above where it sits. */
  readonly lift: number;
  /** A rocket's push (newtons) while W is held, for its fuel's seconds a run. */
  readonly thrust: number;
  readonly fuel: number;
  /** Wings' lift area: in the air it holds the kart up, the faster the more -- longer jumps. */
  readonly wing: number;
  /** m/s of knock the driver can take on top of the seat's (a sofa is comfy). */
  readonly cushion: number;
  readonly model: string;
  /** A themed body: a whole kart of its own make (a white toilet, a silver toaster). */
  readonly natural?: boolean;
  /** A body that is the whole kart -- its own hull and frame round the wheels: the chassis' look is hidden under it (its box still the collider). */
  readonly cover?: boolean;
  /** The chassis (`CHASSIS`) it comes on as a kart of its own, in the garage's Kart tab (left out: the fruit crate). */
  readonly on?: number;
  /** The colours it breaks into: `burst.ts`' shards. */
  readonly debris?: readonly number[];
  /** A see-through piece of it (its model's `<part>_glass`), drawn in this material: the pram's hood. */
  readonly glass?: AssetKeys.Material;
}


export const CHASSIS: readonly ChassisPart[] = [
  { name: 'Plank', cost: 10, blurb: 'Light, low and nimble. Nothing to hold on to.', mass: 22, size: [0.6, 0.12, 1.7], track: 0.95, base: 1.35, drag: 0.32, hp: 12, colour: 0xe6c99a, model: 'karts/parts#chassis_plank' },
  { name: 'Fruit crate', cost: 20, blurb: 'The sensible choice. Smells of apples.', mass: 38, size: [0.85, 0.35, 1.8], track: 1.0, base: 1.4, drag: 0.44, hp: 18, colour: 0xddbb88, model: 'karts/parts#chassis_crate' },
  { name: 'Bathtub', cost: 30, blurb: 'Heavy, wide and planted. Fast once it gets going.', mass: 55, size: [1.0, 0.5, 1.9], track: 1.2, base: 1.5, drag: 0.56, hp: 35, colour: 0x7cbcdc, model: 'karts/parts#chassis_tub' },
  { name: 'Shopping trolley', cost: 15, blurb: 'Tall, light and rattly. Corners on two wheels.', mass: 18, size: [0.6, 0.6, 0.95], track: 1.05, base: 1.1, drag: 0.4, hp: 21, colour: 0xc9ced6, model: 'karts/parts#chassis_trolley' },
  { name: 'Wheelie bin', cost: 12, blurb: 'Sit in the bin. Very tall, very silly.', mass: 14, size: [0.6, 0.75, 0.72], track: 1.12, base: 1.0, drag: 0.34, hp: 15, colour: 0x3f8f4c, seat: -0.04, model: 'karts/parts#chassis_bin' },
  { name: 'Canoe', cost: 25, blurb: 'Long and slippery. Wonderful straight, slow to turn.', mass: 30, size: [0.7, 0.3, 2.7], track: 0.8, base: 2.1, drag: 0.26, hp: 20, colour: 0xd08a52, model: 'karts/parts#chassis_canoe' },
];

export const WHEELS: readonly WheelPart[] = [
  { name: 'Pram wheels', cost: 10, blurb: 'Decent grip. Not built for landings: the rims buckle.', thin: true, radius: 0.18, mass: 2, grip: 1.0, strength: 7.5, wobble: 0, rolling: 0.015, model: 'karts/parts#wheel_pram' },
  { name: 'Trolley casters', cost: 5, blurb: 'Cheap, tiny and not very grippy.', radius: 0.11, mass: 1, grip: 0.78, strength: 4.5, wobble: 1, rolling: 0.026, model: 'karts/parts#wheel_trolley' },
  { name: 'Bike wheels', cost: 25, blurb: 'Big and grippy. Raises the kart. Thin rims buckle on a bad landing.', thin: true, radius: 0.3, smallest: 80, mass: 3, grip: 1.15, strength: 8.5, wobble: 0, rolling: 0.01, model: 'karts/parts#wheel_bike' },
  { name: 'Skateboard wheels', cost: 8, blurb: 'Tiny and quick. Every bump finds the chassis.', radius: 0.06, mass: 0.5, grip: 0.8, strength: 5.5, wobble: 0.3, rolling: 0.005, model: 'karts/parts#wheel_skate' },
  { name: 'Toy Tractor tyres', cost: 30, blurb: 'Chunky, heavy, unbreakable. A little monster truck.', radius: 0.315, front: 0.5, mass: 9, grip: 1.3, strength: 13, wobble: 0, rolling: 0.03, model: 'karts/parts#wheel_tractor' },
  { name: 'Go-kart slicks', cost: 35, blurb: 'Proper racing rubber. Grips like glue, hates a hard landing.', radius: 0.14, mass: 2.5, grip: 1.35, strength: 9, wobble: 0, rolling: 0.006, model: 'karts/parts#wheel_slick' },
  { name: 'Cart wheels', cost: 12, blurb: 'Wood and iron. Slides everywhere; the old spokes give on a hard landing.', thin: true, radius: 0.24, mass: 6, grip: 0.76, strength: 11, wobble: 0.15, rolling: 0.02, model: 'karts/parts#wheel_cart' },
  { name: 'Lawnmower wheels', cost: 15, blurb: 'Chunky little treads. Grip on anything, a bit draggy.', radius: 0.13, mass: 1.5, grip: 1.1, strength: 7, wobble: 0, rolling: 0.025, model: 'karts/parts#wheel_mower' },
  { name: 'Plywood discs', cost: 6, blurb: 'Jigsawed out of an old sheet of ply. Nearly round. No tyre, so no grip to speak of.', radius: 0.22, mass: 3, grip: 0.74, strength: 8, wobble: 0.35, rolling: 0.018, model: 'karts/parts#wheel_disc' },
];

export const SUSPENSION: readonly SuspensionPart[] = [
  { name: 'Bolted on', cost: 0, blurb: 'No suspension. Every bump goes straight to the wheels.', travel: 0.04, stiff: 6, damp: 0.25, soak: 0, model: 'karts/parts#spring_bolted' },
  { name: 'Bed springs', cost: 10, blurb: 'Soft and bouncy. Soaks up landings.', travel: 0.16, stiff: 2.2, damp: 0.2, soak: 3.6, model: 'karts/parts#spring_bed' },
  { name: 'Shock absorbers', cost: 25, blurb: 'Firm and controlled. The pro\'s pick.', travel: 0.2, stiff: 2.8, damp: 0.6, soak: 4.5, model: 'karts/parts#spring' },
  { name: 'Pogo springs', cost: 15, blurb: 'Boing. Lands anything, bounces everywhere.', travel: 0.35, stiff: 1.6, damp: 0.06, soak: 7, model: 'karts/parts#spring_pogo' },
];

export const STEERING: readonly SteeringPart[] = [
  { name: 'Rope reins', cost: 0, blurb: 'Slow and lazy. Goes numb at speed, so it never catches you out.', lock: 0.4, rate: 1.3, fade: 6, model: 'karts/parts#steer_rope', up: 0.32, ahead: 0.02, tilt: 0, turns: 1 },
  { name: 'Go-kart wheel', cost: 15, blurb: 'Razor sharp, even flat out. Easy to overcorrect.', lock: 0.62, rate: 6, fade: 20, model: 'karts/parts#steer_wheel', up: 0.34, ahead: 0.12, tilt: -40, turns: 3 },
  { name: 'Bike handlebars', cost: 8, blurb: 'In between: quick enough, hard to overdo.', lock: 0.54, rate: 3.6, fade: 12, model: 'karts/parts#steer_bars', up: 0.36, ahead: 0.14, tilt: -15, turns: 1.2 },
  // lock: how far the levers pull (1 all the way; wear snaps it down like any steering's); rate: how fast a hand pulls one.
  { name: 'Twin brake levers', cost: 10, blurb: 'Pull one lever to slow that rear wheel and swing the kart around. Great for hairpins, but every turn costs speed.', lock: 1, rate: 4, fade: 999, levers: 1.6, model: 'karts/parts#steer_levers', up: 0.3, ahead: 0.06, tilt: 0, turns: 0 },
];

/** The brakes, the same on every kart: a lever on a tyre, firm enough to stop, gentle enough not to lock good tyres. */
export const BRAKE: BrakePart = { name: 'Brakes', cost: 0, blurb: '', force: 0.9, chute: 0 };

export const BODY: readonly BodyPart[] = [
  { name: 'Nothing', cost: 0, blurb: 'Bare and honest.', mass: 0, drag: 0, appeal: 0, strength: 99, z: 0, lift: 0, thrust: 0, fuel: 0, wing: 0, cushion: 0, model: '' },
  { name: 'Rocket Sled', cost: 35, blurb: 'A plank and a real rocket booster. Hold W: three seconds of very bad idea.', on: 0, mass: 8, drag: 0.04, appeal: 4, strength: 6, z: -0.55, lift: 0.25, thrust: 900, fuel: 3, wing: 0, cushion: 0, model: 'karts/parts#deco_booster', debris: [0xf2402e, 0xfabf0f, 0xf7f7f5] },
  { name: 'Flying Trolley', cost: 25, blurb: 'A shopping trolley with glider wings. Hangs in the air off the jumps; mind the landing.', on: 3, mass: 6, drag: 0.1, appeal: 3, strength: 4, z: -0.1, lift: 0.3, thrust: 0, fuel: 0, wing: 1.6, cushion: 0, model: 'karts/parts#deco_wings', debris: [0xf2e0b8, 0xd9140d, 0x2650bf] },
  { name: 'Couch Potato', cost: 20, blurb: 'An old sofa bolted to a plank. Heavy, comfy, and very hard to fall out of.', on: 1, mass: 30, drag: 0.35, appeal: 3, strength: 12, z: -0.3, lift: 0.3, thrust: 0, fuel: 0, wing: 0, cushion: 4, model: 'karts/couch#couch', natural: true, cover: true, debris: [0x6b5444, 0x8a6e5a, 0x9a7048, 0x80858c] },
  // The themed karts: each a whole kart of its own, its own undercarriage and all (karts/<name>.lua), with a joke and a knack.
  { name: 'Air Fryer Force One', cost: 20, blurb: 'A giant air fryer: you sit in the basket, among the chips.', mass: 12, drag: 0.25, appeal: 4, strength: 8, z: 0, lift: 0.35, thrust: 0, fuel: 0, wing: 0, cushion: 1.5, model: 'karts/fryer#fryer', natural: true, cover: true, debris: [0x151517, 0xd8dadf, 0xf2c14e, 0xff7a1a] },
  { name: 'Escargot Fast', cost: 20, blurb: 'A racing snail. Fast, for a snail. The shell takes the knocks behind you.', mass: 10, drag: 0.2, appeal: 4, strength: 9, z: 0, lift: 0.45, thrust: 0, fuel: 0, wing: 0, cushion: 2, model: 'karts/snail#snail', natural: true, cover: true, debris: [0x8bd13a, 0xa64fd6, 0x7a4a24, 0xf6d21f] },
  { name: 'Bog Standard', cost: 15, blurb: 'Flushed with success. Sat in the bowl, you are hard to throw out.', mass: 14, drag: 0.22, appeal: 5, strength: 10, z: 0, lift: 0.25, thrust: 0, fuel: 0, wing: 0, cushion: 3, model: 'karts/toilet#toilet', natural: true, cover: true, debris: [0xf4f6f6, 0x1aa79a, 0x2b6fe0, 0xb8bec4] },
  { name: 'The Bread Bull', cost: 15, blurb: 'A toaster, you popping up between two slices. Boxy in the wind.', mass: 9, drag: 0.32, appeal: 4, strength: 8, z: 0, lift: 0.25, thrust: 0, fuel: 0, wing: 0, cushion: 2, model: 'karts/toaster#toaster', natural: true, cover: true, debris: [0xd9dde2, 0xc98a3c, 0x8a5a2b, 0x1b1b1b] },
  { name: 'Abduction Reduction', cost: 30, blurb: 'A flying saucer with a cow aboard. It nearly flies: floats off the jumps.', mass: 10, drag: 0.28, appeal: 5, strength: 5, z: 0, lift: 0.45, thrust: 0, fuel: 0, wing: 1.1, cushion: 0, model: 'karts/saucer#saucer', natural: true, cover: true, debris: [0xb9c0c9, 0x55e0ff, 0x7ad94a, 0x3a3f4a] },
  { name: 'The Existential Prawn', cost: 25, blurb: 'On its back, staring into space. Surprisingly slippery.', mass: 8, drag: 0.1, appeal: 5, strength: 6, z: 0, lift: 0.3, thrust: 0, fuel: 0, wing: 0, cushion: 0, model: 'karts/prawn#prawn', natural: true, cover: true, debris: [0xff8a5c, 0xffd35a, 0xdff3ff, 0xcfd4da] },
  { name: 'Fizz Bomb', cost: 20, blurb: 'A giant drinks can on a tube frame. Long, smooth and very shaken up.', mass: 9, drag: 0.12, appeal: 4, strength: 7, z: 0, lift: 0.3, thrust: 0, fuel: 0, wing: 0, cushion: 1, model: 'karts/can#can', natural: true, cover: true, debris: [0x1f4fd6, 0xd4d8de, 0x2a5ce8, 0x222222] },
  { name: 'Foot Loose', cost: 20, blurb: 'A giant bare foot. You sit up in the ankle; the toes take the knocks out front.', mass: 12, drag: 0.26, appeal: 5, strength: 9, z: 0, lift: 0.4, thrust: 0, fuel: 0, wing: 0, cushion: 2, model: 'karts/foot#foot', natural: true, cover: true, debris: [0xf2ad80, 0xc71217, 0xf7eed6, 0x111111] },
  { name: "Pole Vault", cost: 25, blurb: "A proper single-seater, wings and all. Slippery and sharp; the nose doesn't like a kerb.", mass: 9, drag: 0.08, appeal: 5, strength: 6, z: 0, lift: 0.25, thrust: 0, fuel: 0, wing: 0, cushion: 1, model: 'karts/f1#f1', natural: true, cover: true, debris: [0x2e86e8, 0xffc20e, 0x111111, 0xf2f2f2] },
  { name: "Gravity Well", cost: 30, blurb: "A navy torpedo with the legroom of a budget airline. Once it rolls, nothing on the hill catches it.", mass: 16, drag: 0.05, appeal: 5, strength: 9, z: 0, lift: 0.2, thrust: 0, fuel: 0, wing: 0, cushion: 2, model: 'karts/streamliner#streamliner', natural: true, cover: true, debris: [0x1b2a5c, 0x0a0a0c, 0xff6a10, 0xc0c4cc] },
  { name: "Crate Expectations", cost: 10, blurb: "A greengrocer's crate on Dad's shelf plank, steered on rope reins. Light, creaky and honest.", mass: 8, drag: 0.3, appeal: 1, strength: 5, z: 0, lift: 0.45, thrust: 0, fuel: 0, wing: 0, cushion: 0.5, model: 'karts/crate#crate', natural: true, cover: true, debris: [0xf0b060, 0xe09a48, 0x8c5a22, 0xb0b4ba] },
  { name: "Hippy Van", cost: 20, blurb: "A flower-power camper, patched with whatever was lying about. So chilled it barely notices a crash. Big, boxy and catches the wind.", mass: 16, drag: 0.34, appeal: 5, strength: 9, z: 0, lift: 0.35, thrust: 0, fuel: 0, wing: 0, cushion: 3, model: 'karts/van#van', natural: true, cover: true, debris: [0x7ba889, 0xf3e9c6, 0xc9ccd2, 0xf2b21b] },
  { name: "Old Faithful", cost: 20, blurb: "Grandad's pickup, held together with tape, tin and a plank. Slow off the line, takes a knock without a whimper.", mass: 14, drag: 0.24, appeal: 5, strength: 10, z: 0, lift: 0.35, thrust: 0, fuel: 0, wing: 0, cushion: 2, model: 'karts/pickup#pickup', natural: true, cover: true, debris: [0xf26a10, 0xb84c08, 0x9ea2a8, 0xd01818] },
  { name: "The Cyber Shed", cost: 25, blurb: "A skipful of sheet metal riveted into a wedge. The windows are painted on; the wedge cuts the air.", mass: 13, drag: 0.12, appeal: 5, strength: 11, z: 0, lift: 0.5, thrust: 0, fuel: 0, wing: 0, cushion: 0.5, model: 'karts/steeltruck#steeltruck', natural: true, cover: true, debris: [0xa4a6ab, 0x6b6e73, 0x2a1714, 0x212124] },
  { name: "Teapot One", cost: 30, blurb: "Three cereal boxes and a tea tray, Nan's teapot riding shotgun. The cardboard fins glide off the jumps.", mass: 11, drag: 0.12, appeal: 5, strength: 6, z: 0, lift: 0.55, thrust: 0, fuel: 0, wing: 1.2, cushion: 1.5, model: 'karts/starfighter#starfighter', natural: true, cover: true, debris: [0xf2f2eb, 0xfa7014, 0x0a999e, 0xfcd11f] },
  { name: "Gull Throttle", cost: 25, blurb: "An eighties steel wedge with its doors stuck open. Heavy and square: it shoulders rivals aside.", mass: 17, drag: 0.3, appeal: 5, strength: 11, z: 0, lift: 0.35, thrust: 0, fuel: 0, wing: 0, cushion: 1, model: 'karts/gullwing#gullwing', natural: true, cover: true, debris: [0xbdc2c9, 0x0f0f12, 0xff730f, 0xf2450f] },
  { name: "Lunar Tick", cost: 25, blurb: "One small step off the start line. Slippery as a nose cone and twice as pointy.", mass: 12, drag: 0.08, appeal: 5, strength: 7, z: 0, lift: 0.45, thrust: 0, fuel: 0, wing: 0, cushion: 1.5, model: 'karts/moonrocket#moonrocket', natural: true, cover: true, debris: [0xededeb, 0x38383d, 0x0b1a63, 0xc8102e] },
  { name: "Great White Hope", cost: 25, blurb: "A shark with its mouth open and you in its back. Bites into the corners and never lets go.", mass: 15, drag: 0.18, appeal: 5, strength: 10, z: 0, lift: 0.4, thrust: 0, fuel: 0, wing: 0, cushion: 2, model: 'karts/sharkkart#sharkkart', natural: true, cover: true, debris: [0x7a879b, 0xe6dcc8, 0xd7262e, 0xffc814] },
  { name: "Shell Suit", cost: 15, blurb: "A giant taco, extra lettuce. Crunchy outside, soft centre: lands softly, hates a headwind.", mass: 10, drag: 0.32, appeal: 5, strength: 5, z: 0, lift: 0.6, thrust: 0, fuel: 0, wing: 0, cushion: 3, model: 'karts/taco#taco', natural: true, cover: true, debris: [0xffc41f, 0x5ec92a, 0xe8261c, 0xff8c00] },
  { name: "Rock Bottom", cost: 25, blurb: "Logs, rope and a stone roller up front. Heavy as a quarry and shrugs off knocks.", mass: 18, drag: 0.32, appeal: 5, strength: 11, z: 0, lift: 0.45, thrust: 0, fuel: 0, wing: 0, cushion: 3, model: 'karts/stoneage#stoneage', natural: true, cover: true, debris: [0x754522, 0x6b7078, 0xdbb775, 0xf0d9a8] },
  { name: "Pram Pushing", cost: 15, blurb: "A wicker pram with a hood like a nanny's umbrella. The padded tub soaks up every bump.", mass: 9, drag: 0.28, appeal: 5, strength: 6, z: 0, lift: 0.55, thrust: 0, fuel: 0, wing: 0, cushion: 3.5, model: 'karts/pram#pram', natural: true, cover: true, debris: [0xf2e8d1, 0xed7399, 0xf5f5f2, 0x73adf2], glass: 'karts/hood' },
  { name: "Moving Violation", cost: 20, blurb: "Leaving home with the whole loft on the roof. Nippy in the corners, rolls if you look at it funny.", mass: 11, drag: 0.3, appeal: 5, strength: 7, z: 0, lift: 0.75, thrust: 0, fuel: 0, wing: 0, cushion: 2, model: 'karts/minicar#minicar', natural: true, cover: true, debris: [0x9bdb24, 0x6b3a1a, 0x9c1a1f, 0xedeff3] },
  { name: "Bolt From The Blue", cost: 20, blurb: "Blows its own trumpet twice. Light, sharp steering and a good straight-line toot.", mass: 11, drag: 0.12, appeal: 5, strength: 7, z: 0, lift: 0.3, thrust: 0, fuel: 0, wing: 0, cushion: 1.5, model: 'karts/gokart#gokart', natural: true, cover: true, debris: [0xdb1717, 0xf5f5f0, 0x143dd1, 0x0d0d0f] },
  { name: 'Full Steam', cost: 25, blurb: 'A little green tank engine, chimney and all. Heavy, planted and very loud in spirit.', mass: 18, drag: 0.3, appeal: 5, strength: 11, z: 0, lift: 0.4, thrust: 0, fuel: 0, wing: 0, cushion: 1.5, model: 'karts/engine#engine', natural: true, cover: true, debris: [0x1d5c2a, 0xc71217, 0xd4a017, 0x111111] },
];

/**
 * The driver's seat, the same in every kart: low and tucked down into its chassis -- steady, and the hardest to be
 * thrown out of. The m/s of knock that throws them out of it, before a body's cushion.
 */
export const SEAT_GRIP = 8;

/** What the driver wears: each its own model (`AssetsSource/models/karts/driver*.lua`), the same skeleton and clips. */
export interface OutfitPart {
  name: string;
  cost: number;
  blurb: string;
  model: string;
}

export const OUTFITS: readonly OutfitPart[] = [
  { name: 'Racer', cost: 0, blurb: 'Racing suit, helmet and goggles. Looks the part, at least.', model: 'karts/driver' },
  { name: 'Chicken', cost: 0, blurb: 'Why did the chicken cross the finish line? It fell out at the top.', model: 'karts/driver_chicken' },
  { name: 'Banana', cost: 0, blurb: 'Bruises easily. Slips nicely.', model: 'karts/driver_banana' },
  { name: 'Viking', cost: 0, blurb: 'Horns, a beard and no fear. Valhalla is at the bottom of the hill.', model: 'karts/driver_viking' },
  { name: 'Granny', cost: 0, blurb: 'Dressing gown, curlers and slippers. Popped out for milk.', model: 'karts/driver_granny' },
  { name: 'Chef', cost: 0, blurb: 'Whites, checks and a tall hat. Cooking with gas.', model: 'karts/driver_chef' },
  { name: 'The Giant Baby', cost: 0, blurb: 'Nappy, bib and dummy. Has never been told no.', model: 'karts/driver_baby' },
  { name: 'Caveman', cost: 0, blurb: 'Invented the wheel this morning. Still testing it.', model: 'karts/driver_caveman' },
  { name: 'Hot Sauce', cost: 0, blurb: 'Extra hot. Handle with care. Do not shake.', model: 'karts/driver_hotsauce' },
];

/** The slots, in the builder's order, each its list. */
export const SLOTS = [
  { name: 'Chassis', parts: CHASSIS },
  { name: 'Wheels', parts: WHEELS },
  { name: 'Suspension', parts: SUSPENSION },
  { name: 'Steering', parts: STEERING },
  { name: 'Bodywork', parts: BODY },
  { name: 'Driver', parts: OUTFITS },
] as const;

/**
 * What each part needs to be had in the garage: courses won (a part's index in its slot's list). No budget: the
 * parts open up as the courses are won -- the starter kit and a few oddities from the start, the exotic last.
 */
export const UNLOCKS = {
  // (The presets' parts -- the bathtub, lawnmower wheels, shock absorbers, handlebars --
  // open from the start: every preset can be raced on the first course.)
  chassis: [0, 0, 0, 1, 0, 3],
  wheels: [0, 0, 3, 1, 6, 8, 2, 0],
  suspension: [0, 0, 0, 2],
  steering: [0, 3, 0],
  body: [0, 7, 5, 3, 6, 8, 10, 9, 12, 14, 11, 0, 3, 6, 0, 2, 1, 5, 9, 7, 4, 3, 1, 8, 2, 6, 0, 4],
  outfit: [0, 0, 2, 5, 8, 1, 4, 3, 6],
} as const;
/** Courses won to have part `j` of `slot` (a slot with no list: always). */
export function unlockOf(slot: string, j: number): number {
  const list = (UNLOCKS as Record<string, readonly number[]>)[slot];
  return list?.[j] ?? 0;
}
/** The rules: a kart weighs no more than this empty, kilograms (176 lb) -- the driver not counted. */
export const WEIGHT_LIMIT = 80;
/** The rules' sizes, metres: the most a kart may be across, along and tall, and the least it rides above the ground. */
export const MAX_WIDTH = 2;
export const MAX_LENGTH = 6;
export const MAX_HEIGHT = 2.5;
export const MIN_CLEARANCE = 0.1;
/** Tall karts' centres of mass brought down (`rate`): from this height (metres), this much a metre over it, never below
 * this share of the chassis' ride height. */
const TALL_FROM = 1.5;
const TALL_LOWER = 0.2;
const COM_FLOOR = 0.9;
/** Crowd appeal (`rate`): its body's look (0..5) times APPEAL_LOOK, and how wobbly (5 less stability) and slippy (5
 * less grip) it is, times theirs -- so the hardest karts to drive are the crowd's favourites. */
const APPEAL_LOOK = 0.3;
const APPEAL_WOBBLY = 0.55;
const APPEAL_SLIPPY = 0.3;
/** A seated driver's head, metres over the seat. */
const DRIVER_HEAD = 0.95;
/** A tyre's width, as a share of its radius (a tractor tyre's is about half its radius). */
const TYRE_WIDE = 0.5;
/**
 * Each body's own size, metres, in `BODY`'s order: across, up over the chassis' top, along (about its `z`). A themed
 * body's grows with its chassis' size, as it is drawn. As its model has it, near enough.
 */
const BODY_SIZE: readonly (readonly [number, number, number])[] = [
  [0, 0, 0],            // Nothing
  [0.55, 0.55, 1.25],   // Rocket Sled: the booster
  [1.96, 0.45, 0.5],    // Flying Trolley: the wings
  [1.16, 0.49, 1.62],   // Couch Potato: the sofa on its plank deck
  [1.2, 1.1, 1.7],      // Air Fryer Force One
  [1.15, 1.3, 2.0],     // Escargot Fast
  [0.95, 1.1, 1.7],     // Bog Standard
  [1.05, 1.0, 1.6],     // The Bread Bull
  [1.75, 0.9, 2.2],     // Abduction Reduction
  [1.05, 0.8, 2.4],     // The Existential Prawn
  [1.05, 1.0, 2.4],     // Fizz Bomb
  [1.05, 1.15, 2.0],    // Foot Loose
  [1.46, 0.98, 2.9],  // Pole Vault
  [0.84, 0.64, 3.06],  // Gravity Well
  [1.07, 0.35, 2],  // Crate Expectations
  [1.29, 1.44, 2.5],  // Hippy Van
  [1.22, 1.12, 2.72],  // Old Faithful
  [1.23, 0.92, 2.68],  // The Cyber Shed
  [1.66, 0.68, 2.73],  // Teapot One
  [1.64, 1.24, 2.42],  // Gull Throttle
  [1.07, 0.63, 2.16],  // Lunar Tick
  [1.39, 1.3, 2.72],  // Great White Hope
  [1.36, 0.93, 2.13],  // Shell Suit
  [1.85, 1.44, 2.85],  // Rock Bottom
  [1.31, 1.17, 2.66],  // Pram Pushing
  [1.57, 1.59, 2.76],  // Moving Violation
  [1.42, 0.7, 2.78],  // Bolt From The Blue
  [1.42, 1.17, 2.77], // Full Steam: the tank engine
];
export const DRIVER_MASS = 70;
/** The driver's centre of mass, metres above the seat. */
const DRIVER_LIFT = 0.3;

/** A build: an index into each slot's list, in `SLOTS`' order. */
export interface Choice {
  chassis: number;
  wheels: number;
  suspension: number;
  steering: number;
  body: number;
  /** The driver's outfit (`OUTFITS`): only the look. */
  outfit: number;
  /** Sizes, percent: the chassis' width and length, the front wheels, the rear wheels and the suspension's travel (`SIZES`). */
  chassisWidth: number;
  chassisLength: number;
  frontSize: number;
  rearSize: number;
  springSize: number;
}

/** The sizes the builder offers, in its order: each a percent, from `min` to `max` in `step`s (as `Build`'s fields). */
export const SIZES = [
  { key: 'chassisWidth', name: 'Chassis width', min: 60, max: 160, step: 10 },
  { key: 'chassisLength', name: 'Chassis length', min: 60, max: 160, step: 10 },
  { key: 'frontSize', name: 'Front wheels', min: 50, max: 200, step: 10 },
  { key: 'rearSize', name: 'Rear wheels', min: 50, max: 200, step: 10 },
  { key: 'springSize', name: 'Spring travel', min: 50, max: 200, step: 10 },
] as const;

/** The least percent a wheel may be sized to, front or rear: the builder's own, or more for a wheel that says so (bike wheels). */
export function wheelSizeMin(wheels: number): number {
  return Math.max(SIZES[2].min, WHEELS[wheels]?.smallest ?? 0);
}

/**
 * Three ready-made builds, each good at one thing and paying for it -- picked in the garage's Presets tab and changed
 * from there as the player likes. Every one is within the rules and can finish the first course (`presets.test.ts`).
 *  - Speed: a plank on pram wheels, bolted on -- quickest on the smooth road round, but its thin rims buckle and
 *    nothing soaks a landing.
 *  - Stunt: a fruit crate on lawnmower treads and shock absorbers -- built for the shortcut's jump and rough landing,
 *    heavier and draggier on the smooth.
 *  - Stable: a bathtub on lawnmower treads and bed springs -- wide, low and planted; predictable, middling quick, it
 *    never gets much air.
 */
export const PRESETS: readonly { name: string; blurb: string; choice: Partial<Choice> }[] = [
  { name: 'Speed build', blurb: 'Quickest on the smooth road round. Thin rims buckle and nothing soaks a landing.',
    choice: { chassis: 0, wheels: 0, suspension: 0, steering: 2, body: 0 } },
  { name: 'Stunt build', blurb: 'Tough treads and shocks for the pond jump. Heavier and draggier on the smooth.',
    choice: { chassis: 1, wheels: 7, suspension: 2, steering: 2, body: 0 } },
  { name: 'Stable build', blurb: 'Wide, low and planted. Predictable, middling quick, never much air.',
    choice: { chassis: 2, wheels: 7, suspension: 1, steering: 2, body: 0 } },
];

export const STARTER: Choice = {
  chassis: 0, wheels: 0, suspension: 1, steering: 0, body: 0, outfit: 0,
  chassisWidth: 100, chassisLength: 100, frontSize: 100, rearSize: 100, springSize: 100,
};

/**
 * A build's parts as its sizes make them: the chassis' box, track and base, the wheels' radius at each
 * end, the travel. Filled by `sized` (one object, reused).
 */
export interface Sized {
  /** The chassis' scale across (`scaleX`: its width and track), along (`scaleZ`: its length and wheelbase) and their
   * mean (`scale`: its height, toughness and price); its box, track, wheelbase, mass and drag at them. */
  scale: number;
  scaleX: number;
  scaleZ: number;
  sizeX: number;
  sizeY: number;
  sizeZ: number;
  track: number;
  base: number;
  mass: number;
  drag: number;
  /** The front and rear wheels' radius, and the four wheels' mass together. */
  front: number;
  rear: number;
  wheelMass: number;
  /** The wheels' toughness and rolling resistance, their sizes' average. */
  strength: number;
  rolling: number;
  /** The suspension's travel and what it soaks up. */
  travel: number;
  soak: number;
  /** The three sized parts' price. */
  cost: number;
  /** How much knocking about the chassis takes, at its size (and the bodywork's padding). */
  hp: number;
}

export function newSized(): Sized {
  return { scale: 1, scaleX: 1, scaleZ: 1, sizeX: 0, sizeY: 0, sizeZ: 0, track: 0, base: 0, mass: 0, drag: 0, front: 0, rear: 0, wheelMass: 0, strength: 0, rolling: 0, travel: 0, soak: 0, cost: 0, hp: 0 };
}

/** The build's sized parts into `out`. A bigger chassis weighs as its area, and drags as its front (its width by its height); a bigger wheel is heavier, tougher, and rolls more freely. */
export function sized(c: Choice, out: Sized): Sized {
  const ch = CHASSIS[c.chassis]!;
  const wh = WHEELS[c.wheels]!;
  const su = SUSPENSION[c.suspension]!;
  const sx = c.chassisWidth / 100;
  const sz = c.chassisLength / 100;
  const s = Math.sqrt(sx * sz);
  const least = wheelSizeMin(c.wheels);
  const f = Math.max(least, c.frontSize) / 100;
  const r = Math.max(least, c.rearSize) / 100;
  const p = c.springSize / 100;
  const w = (f + r) / 2;
  out.scale = s;
  out.scaleX = sx;
  out.scaleZ = sz;
  out.sizeX = ch.size[0] * sx;
  out.sizeY = ch.size[1] * s;
  out.sizeZ = ch.size[2] * sz;
  out.track = ch.track * sx;
  out.base = ch.base * sz;
  out.mass = ch.mass * sx * sz;
  out.drag = ch.drag * sx * s;
  const ff = f * (wh.front ?? 1);
  out.front = wh.radius * ff;
  out.rear = wh.radius * r;
  out.wheelMass = wh.mass * 2 * (ff * ff + r * r);
  out.strength = wh.strength * Math.sqrt(w);
  out.rolling = wh.rolling / w;
  out.travel = su.travel * p;
  out.soak = su.soak * p;
  out.cost = Math.round(ch.cost * (sx + sz) / 2 + wh.cost * w + su.cost * p);
  out.hp = ch.hp * s;
  return out;
}

const scratch = newSized();

/** What a build adds up to, filled in by `rate` (one object, reused: read it, don't keep it). */
export interface Rating {
  cost: number;
  mass: number;
  /** The whole kart's centre of mass: height above the ground at rest, and along z. */
  comY: number;
  comZ: number;
  /** Where the chassis' middle sits at rest, above the ground. */
  rideY: number;
  drag: number;
  /** How far sideways it can lean before it tips: half the track over the centre's height. */
  tip: number;
  /** 0 to 5 each. */
  speed: number;
  stability: number;
  grip: number;
  toughness: number;
  appeal: number;
  /** Its size as built, metres: across, along, from the ground to its highest point (its driver's head or its
   * bodywork's top), and from the ground to the chassis' underside, at rest. */
  width: number;
  length: number;
  /** How far it reaches behind its middle (the chassis' centre), metres: its back -- the chassis, a rear tyre or the
   * bodywork, whichever sticks out furthest. */
  behind: number;
  height: number;
  clearance: number;
  /** What the builder warns of, a line each. */
  warnings: string[];
}

/** A rating to fill in (`rate`). */
export function newRating(): Rating {
  return { cost: 0, mass: 0, comY: 0, comZ: 0, rideY: 0, drag: 0, tip: 0, speed: 0, stability: 0, grip: 0, toughness: 0, appeal: 0, width: 0, length: 0, behind: 0, height: 0, clearance: 0, warnings: [] };
}

const clamp5 = (x: number): number => Math.max(0, Math.min(5, x));

/** The build's numbers into `out` (made once by the caller). */
export function rate(c: Choice, out: Rating): Rating {
  const wh = WHEELS[c.wheels]!;
  const su = SUSPENSION[c.suspension]!;
  const st = STEERING[c.steering]!;
  const br = BRAKE;
  const bo = BODY[c.body]!;

  const z = sized(c, scratch);
  out.cost = z.cost + st.cost + br.cost + bo.cost;
  // The chassis rides with its bottom on its springs: the wheels' radius (the two ends' average: odd wheels tilt
  // it) and the travel the weight leaves.
  const radius = (z.front + z.rear) / 2;
  out.rideY = radius + z.sizeY / 2 + z.travel * (1 - 1 / su.stiff);
  const top = out.rideY + z.sizeY / 2;
  const seatY = top - (c.chassis === 0 ? 0 : z.sizeY * 0.6);
  const parts: readonly (readonly [number, number, number])[] = [
    [z.mass, out.rideY, 0],
    [z.wheelMass, radius, 0],
    [DRIVER_MASS, seatY + DRIVER_LIFT, -0.25],
    [bo.mass, top + bo.lift, bo.z],
  ];
  let m = 0;
  let my = 0;
  let mz = 0;
  for (const [pm, py, pz] of parts) {
    m += pm;
    my += pm * py;
    mz += pm * pz;
  }
  out.mass = m;
  out.comY = my / m;
  out.comZ = mz / m;
  out.drag = z.drag + bo.drag;
  out.tip = z.track / 2 / out.comY;
  // Its size: the chassis' box, the wheels out at its corners, the bodywork on top, the driver's head.
  const tyre = Math.max(z.front, z.rear) * TYRE_WIDE;
  const bs = BODY_SIZE[c.body] ?? [0, 0, 0];
  const growX = bo.natural ? z.scaleX : 1, growY = bo.natural ? z.scale : 1, growZ = bo.natural ? z.scaleZ : 1;
  const bodyZ = bo.z * z.scaleZ;
  const bodyHalf = (bs[2] * growZ) / 2;
  const ahead = Math.max(z.sizeZ / 2, z.base / 2 + z.front, bs[2] > 0 ? bodyZ + bodyHalf : 0);
  const behind = Math.max(z.sizeZ / 2, z.base / 2 + z.rear, bs[2] > 0 ? bodyHalf - bodyZ : 0);
  out.width = Math.max(z.sizeX, z.track + tyre, bs[0] * growX);
  out.length = ahead + behind;
  out.behind = behind;
  out.height = Math.max(top + bs[1] * growY, seatY + DRIVER_HEAD, 2 * Math.max(z.front, z.rear));
  out.clearance = out.rideY - z.sizeY / 2;
  // A tall kart is built bottom-heavy (its weight slung low, ballast in the floor): its centre of mass brought down
  // TALL_LOWER for each metre it stands over TALL_FROM -- never below COM_FLOOR of the chassis' ride height -- so it
  // is less ready to tip. Its tip and its stability rating follow.
  const tall = Math.max(0, out.height - TALL_FROM);
  out.comY = Math.max(out.rideY * COM_FLOOR, out.comY - tall * TALL_LOWER);
  out.tip = z.track / 2 / out.comY;

  // Terminal speed on an average slope, against the stiffest and the slipperiest builds.
  const terminal = Math.sqrt((m * 9.81 * 0.09) / (0.6 * out.drag));
  out.speed = clamp5((terminal - 12) / 2.4 + bo.thrust / 450);
  out.stability = clamp5((out.tip - 0.5) * 7);
  out.grip = clamp5(wh.grip * 3.2 + (su.damp > 0.4 ? 0.8 : 0) + (st.rate > 3 ? 0.4 : 0) - 0.6);
  out.toughness = clamp5((z.strength + z.soak) / 2.6 * 0.7 + z.hp / 15);
  const odd = Math.max(z.front, z.rear) / Math.min(z.front, z.rear);
  // The crowd loves a handful: the harder it is to drive and keep upright (low stability, low grip), the more they
  // cheer it -- its body's own look a smaller share (APPEAL_*), and a little more for an oddity (huge or tiny wheels,
  // no damping, odd ends, a stretched or squashed chassis).
  out.appeal = clamp5(bo.appeal * APPEAL_LOOK + (5 - out.stability) * APPEAL_WOBBLY + (5 - out.grip) * APPEAL_SLIPPY
    + (radius > 0.4 || radius < 0.08 ? 0.5 : 0) + (su.damp < 0.1 ? 0.4 : 0)
    + (odd >= 1.6 ? 0.5 : 0) + (Math.max(z.scaleX, z.scaleZ) >= 1.4 || Math.min(z.scaleX, z.scaleZ) <= 0.7 ? 0.3 : 0));

  const w = out.warnings;
  w.length = 0;
  const empty = Math.round(out.mass - DRIVER_MASS);
  if (empty > WEIGHT_LIMIT) w.push(`Too heavy by ${empty - WEIGHT_LIMIT} kg`);
  const m2 = (v: number): string => v.toFixed(2);
  if (out.width > MAX_WIDTH) w.push(`Too wide: ${m2(out.width)} / ${MAX_WIDTH} m`);
  if (out.length > MAX_LENGTH) w.push(`Too long: ${m2(out.length)} / ${MAX_LENGTH} m`);
  if (out.height > MAX_HEIGHT) w.push(`Too tall: ${m2(out.height)} / ${MAX_HEIGHT} m`);
  if (out.clearance < MIN_CLEARANCE) w.push(`Too low: ${Math.round(out.clearance * 100)} / ${MIN_CLEARANCE * 100} cm`);
  if (out.tip < 0.85) w.push('Top heavy: rolls easily');
  if (z.travel < 0.05 && z.strength < 8) w.push('No suspension: wheels snap');
  if (odd >= 1.6) w.push(z.front > z.rear ? 'Nose in the air' : 'Leans on its nose');
  if (z.front + z.rear > z.base * 0.95) w.push('Wheels nearly touch');
  else if (wh.wobble > 0.1) w.push('Wobbles at speed');
  if (br.force > wh.grip) w.push('Brakes lock: brake gently');
  if (st.rate > 3 && wh.wobble > 0) w.push('Twitchy steering');
  if (wh.name === 'Skateboard wheels') w.push('Low: ramps scrape');
  if (wh.thin) w.push('Thin rims buckle on landings');
  if (su.damp < 0.1) w.push('Bouncy: light steering');
  if (bo.thrust > 0) w.push(`Rocket: hold W (${bo.fuel}s)`);
  if (bo.wing > 0) w.push('Wings: long glides');
  if (radius > 0.4 && out.tip < 1) w.push('Big wheels: rolly');
  return out;
}

/** Showmanship medals, style points (more is better): gold, silver, bronze, on the first course -- more jumps later raise them (race-hud.ts). Race-time medals are each course's own (courses.ts). */
export const STYLE_MEDALS = [650, 380, 180] as const;

/** The kart's weight empty, kilograms: all of it but its driver. */
export function emptyMass(r: Rating): number {
  return r.mass - DRIVER_MASS;
}

/** Whether a build may race by the rules -- within the weight limit and the sizes -- or why not. */
export function rulesBreak(r: Rating): '' | 'Too heavy' | 'Too wide' | 'Too long' | 'Too tall' | 'Too low' {
  if (Math.round(emptyMass(r)) > WEIGHT_LIMIT) return 'Too heavy';
  if (r.width > MAX_WIDTH) return 'Too wide';
  if (r.length > MAX_LENGTH) return 'Too long';
  if (r.height > MAX_HEIGHT) return 'Too tall';
  if (r.clearance < MIN_CLEARANCE) return 'Too low';
  return '';
}
