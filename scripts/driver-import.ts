/**
 * The driver from polyperfect's Low Poly Animated People: one of the pack's rigged people (the mechanic, in overalls)
 * made into a driver the game can sit in a kart, push off the line and throw out -- the same bones by name, rest pose,
 * hips height and clips as the driver library's figures (`AssetsSource/models/karts/_driver.lua`), so it swaps in for
 * any outfit: the seat's clips (sit, lean_left, lean_right, tuck, brace, cheer), the teammate's on foot (ready, push,
 * stagger, flat; `pusher.ts`), and the ragdoll's bones (`ragdoll-skin.ts`).
 *
 * The pack has no sitting, pushing or falling animations, so the clips are posed here, as `_driver.lua` poses its own:
 * each pose is how far each joint swings from the rest pose, degrees `forward` (its tip toward +z) and `left` (toward
 * +x), its parent's swing carried down to it. Its rest pose is made the library's: arms hanging, legs straight down.
 *
 *   node scripts/driver-import.ts "<Low Poly Animated People folder>" [rig] [name]
 *
 * (rig man_mechanic_Rig, name driver_mechanic by default.) Writes AssetsSource/models/karts/<name>.glb.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import sharp from 'sharp';
import * as THREE from 'three';
import { FBXLoader } from 'three/examples/jsm/loaders/FBXLoader.js';
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import { mergeVertices } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

const pack = process.argv[2];
if (!pack) throw new Error('usage: node scripts/driver-import.ts "<Low Poly Animated People folder>" [rig] [name]');
const RIG = process.argv[3] ?? 'man_mechanic_Rig';
const NAME = process.argv[4] ?? 'driver_mechanic';
const out = new URL(`../AssetsSource/models/karts/${NAME}.glb`, import.meta.url);

THREE.TextureLoader.prototype.load = function () { return new THREE.Texture(); };
(globalThis as Record<string, unknown>).self ??= globalThis;
(globalThis as Record<string, unknown>).FileReader ??= class {
  result: ArrayBuffer | string | null = null;
  onloadend: (() => void) | null = null;
  readAsArrayBuffer(b: Blob): void { void b.arrayBuffer().then((r) => { this.result = r; this.onloadend?.(); }); }
  readAsDataURL(b: Blob): void { void b.arrayBuffer().then((r) => { this.result = `data:${b.type};base64,${Buffer.from(r).toString('base64')}`; this.onloadend?.(); }); }
};

/** The library's hips, over the feet (`_driver.lua`'s HIPS, `assemble.ts`' DRIVER_HIPS): the seat sits them here. */
const HIPS = 0.62;
/** The pack's bones, by the library's (Mixamo) names: what the clips and the ragdoll move. */
const BONES: Record<string, string> = {
  Root_M: 'Hips', Spine1_M: 'Spine', Neck_M: 'Neck', Head_M: 'Head',
  Shoulder_L: 'LeftArm', Elbow_L: 'LeftForeArm', Hip_L: 'LeftUpLeg', Knee_L: 'LeftLeg',
  Shoulder_R: 'RightArm', Elbow_R: 'RightForeArm', Hip_R: 'RightUpLeg', Knee_R: 'RightLeg',
};
/** The library's rest pose: each limb bone's way to its child (x for the left side; the right mirrored). */
const REST: readonly (readonly [string, string, THREE.Vector3])[] = [
  ['LeftArm', 'LeftForeArm', new THREE.Vector3(0.03, -0.23, 0)],
  ['LeftForeArm', 'Wrist_L', new THREE.Vector3(0.02, -0.22, 0.02)],
  ['LeftUpLeg', 'LeftLeg', new THREE.Vector3(0, -1, 0)],
  ['LeftLeg', 'Ankle_L', new THREE.Vector3(0, -1, 0)],
];

const load = (path: string): THREE.Group => {
  const b = readFileSync(path);
  return new FBXLoader().parse(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength), '');
};
const person = load(join(pack, '- Models', 'Rigs', `${RIG}.fbx`));

// Only the skinned figure: the rig's control curve and helper shapes left out.
const extras: THREE.Object3D[] = [];
person.traverse((o) => {
  if (((o as THREE.Mesh).isMesh && !(o as THREE.SkinnedMesh).isSkinnedMesh) || (o as THREE.Line).isLine) extras.push(o);
});
// (A curve may hold the skeleton: its children kept where they are, moved up to its parent.)
for (const x of extras) {
  for (const c of [...x.children]) x.parent!.attach(c);
  x.removeFromParent();
}
let mesh: THREE.SkinnedMesh | null = null;
person.traverse((o) => { if ((o as THREE.SkinnedMesh).isSkinnedMesh) mesh = o as THREE.SkinnedMesh; });
if (!mesh) throw new Error(`${RIG}: no skinned mesh`);
const skin: THREE.SkinnedMesh = mesh;

// The atlas baked into vertex colours; one white material; corners shared.
const atlas = await sharp(join(pack, '- Textures', 'color-atlas-new2.png')).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
{
  const geo = skin.geometry;
  const uv = geo.getAttribute('uv');
  const n = geo.getAttribute('position').count;
  const colours = new Float32Array(n * 3);
  const c = new THREE.Color();
  const { width, height } = atlas.info;
  for (let i = 0; i < n; i++) {
    const x = Math.max(0, Math.min(width - 1, Math.floor((uv.getX(i) - Math.floor(uv.getX(i))) * width)));
    const y = Math.max(0, Math.min(height - 1, Math.floor((1 - (uv.getY(i) - Math.floor(uv.getY(i)))) * height)));
    const p = (y * width + x) * 4;
    c.setRGB(atlas.data[p]! / 255, atlas.data[p + 1]! / 255, atlas.data[p + 2]! / 255, THREE.SRGBColorSpace);
    colours[i * 3] = c.r; colours[i * 3 + 1] = c.g; colours[i * 3 + 2] = c.b;
  }
  geo.setAttribute('color', new THREE.BufferAttribute(colours, 3));
  geo.deleteAttribute('uv');
  skin.geometry = mergeVertices(geo, 1e-4);
  skin.material = new THREE.MeshStandardMaterial({ name: 'Driver', color: 0xffffff, vertexColors: true, roughness: 0.8, metalness: 0 });
  skin.name = 'driver';
}

// The library's names.
const bone = (name: string): THREE.Bone => {
  const b = skin.skeleton.bones.find((x) => x.name === name);
  if (!b) throw new Error(`no bone ${name}`);
  return b;
};
for (const b of skin.skeleton.bones) b.name = BONES[b.name] ?? b.name;

// The library's rest pose: each limb turned (in the world) to hang its way, parents first.
const q = new THREE.Quaternion();
const parentQ = new THREE.Quaternion();
const a = new THREE.Vector3();
const b = new THREE.Vector3();
for (const side of [1, -1]) {
  for (const [from, to, way] of REST) {
    const name = (s: string): string => (side > 0 ? s : s.replace('Left', 'Right').replace(/_L$/, '_R'));
    const j = bone(name(from));
    person.updateMatrixWorld(true);
    j.getWorldPosition(a);
    bone(name(to)).getWorldPosition(b);
    const now = b.sub(a).normalize();
    const want = way.clone().setX(way.x * side).normalize();
    const turn = new THREE.Quaternion().setFromUnitVectors(now, want);
    j.getWorldQuaternion(q);
    j.parent!.getWorldQuaternion(parentQ);
    j.quaternion.copy(parentQ.invert().multiply(turn.multiply(q)));
  }
}
person.updateMatrixWorld(true);

/** The figure baked into its pose now and bound there: that pose its rest. */
function rebind(): void {
  const geo = skin.geometry;
  const pos = geo.getAttribute('position');
  const nor = geo.getAttribute('normal');
  const si = geo.getAttribute('skinIndex');
  const sw = geo.getAttribute('skinWeight');
  const m = new THREE.Matrix4();
  const sum = new THREE.Matrix4();
  const v = new THREE.Vector3();
  const nm = new THREE.Matrix3();
  for (let i = 0; i < pos.count; i++) {
    sum.set(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    for (let k = 0; k < 4; k++) {
      const w = sw.getComponent(i, k);
      if (w === 0) continue;
      const bi = si.getComponent(i, k);
      m.multiplyMatrices(skin.skeleton.bones[bi]!.matrixWorld, skin.skeleton.boneInverses[bi]!);
      for (let e = 0; e < 16; e++) sum.elements[e]! += m.elements[e]! * w;
    }
    m.multiplyMatrices(skin.bindMatrixInverse, sum).multiply(skin.bindMatrix);
    v.fromBufferAttribute(pos, i).applyMatrix4(m);
    pos.setXYZ(i, v.x, v.y, v.z);
    if (nor) {
      nm.getNormalMatrix(m);
      v.fromBufferAttribute(nor, i).applyMatrix3(nm).normalize();
      nor.setXYZ(i, v.x, v.y, v.z);
    }
  }
  pos.needsUpdate = true;
  geo.computeBoundingBox();
  geo.computeBoundingSphere();
  skin.bind(skin.skeleton);
}
rebind();

// Sized so its hips are HIPS over its feet, the feet at the origin.
{
  const box = new THREE.Box3().setFromObject(skin, true);
  const hips = bone('Hips').getWorldPosition(new THREE.Vector3());
  const s = HIPS / (hips.y - box.min.y);
  person.scale.setScalar(s);
  person.position.set(0, -box.min.y * s, 0);
  person.updateMatrixWorld(true);
  skin.bind(skin.skeleton);
}

// ---- The clips: posed as _driver.lua poses its own. ----
type Swing = { forward?: number; left?: number };
type Pose = Record<string, Swing>;
const POSED = ['Hips', 'Spine', 'Neck', 'Head', 'LeftArm', 'LeftForeArm', 'RightArm', 'RightForeArm', 'LeftUpLeg', 'LeftLeg', 'RightUpLeg', 'RightLeg'];
const restLocal = new Map<string, THREE.Quaternion>();
const restWorld = new Map<string, THREE.Quaternion>();
const way = new Map<string, THREE.Vector3>();
const rootQ = person.getWorldQuaternion(new THREE.Quaternion()).invert();
const CHILD: Record<string, string> = {
  Hips: 'Spine', Spine: 'Neck', Neck: 'Head', LeftArm: 'LeftForeArm', LeftForeArm: 'Wrist_L', RightArm: 'RightForeArm',
  RightForeArm: 'Wrist_R', LeftUpLeg: 'LeftLeg', LeftLeg: 'Ankle_L', RightUpLeg: 'RightLeg', RightLeg: 'Ankle_R',
};
for (const n of POSED) {
  const j = bone(n);
  restLocal.set(n, j.quaternion.clone());
  restWorld.set(n, rootQ.clone().multiply(j.getWorldQuaternion(new THREE.Quaternion())));
  if (n === 'Head') way.set(n, new THREE.Vector3(0, 1, 0));
  else {
    j.getWorldPosition(a);
    bone(CHILD[n]!).getWorldPosition(b);
    way.set(n, b.clone().sub(a).normalize());
  }
}
const X = new THREE.Vector3(1, 0, 0);
const Z = new THREE.Vector3(0, 0, 1);
/** A joint's turn for a swing: its rest turn, then the swing about the model's axes (as at rest), in its own frame. */
function turnOf(n: string, s: Swing | undefined): THREE.Quaternion {
  const rest = restLocal.get(n)!;
  if (!s || (!s.forward && !s.left)) return rest.clone();
  const d = way.get(n)!;
  const fAxis = d.clone().cross(Z).normalize();
  const lAxis = d.clone().cross(X).normalize();
  const swing = new THREE.Quaternion();
  if (s.left && lAxis.lengthSq() > 0) swing.setFromAxisAngle(lAxis, THREE.MathUtils.degToRad(s.left));
  if (s.forward && fAxis.lengthSq() > 0) swing.multiply(new THREE.Quaternion().setFromAxisAngle(fAxis, THREE.MathUtils.degToRad(s.forward)));
  const w = restWorld.get(n)!;
  const inFrame = w.clone().invert().multiply(swing).multiply(w);
  return rest.clone().multiply(inFrame);
}
function clip(name: string, keys: readonly { time: number; pose: Pose }[]): THREE.AnimationClip {
  const tracks: THREE.KeyframeTrack[] = [];
  for (const n of POSED) {
    const times: number[] = [];
    const values: number[] = [];
    for (const k of keys) {
      times.push(k.time);
      values.push(...turnOf(n, k.pose[n]).toArray());
    }
    tracks.push(new THREE.QuaternionKeyframeTrack(`${n}.quaternion`, times, values));
  }
  return new THREE.AnimationClip(name, -1, tracks);
}

// Seated: _driver.lua's, its P.bob and P.lean.
const BOB = 2.5;
const LEAN = 22;
const seated = (extra: Pose = {}): Pose => ({
  LeftUpLeg: { forward: 88 }, RightUpLeg: { forward: 88 },
  LeftLeg: { forward: -10 }, RightLeg: { forward: -10 },
  LeftArm: { forward: 55, left: 8 }, RightArm: { forward: 55, left: -8 },
  LeftForeArm: { forward: 25 }, RightForeArm: { forward: 25 },
  ...extra,
});
const held = (p: Pose): { time: number; pose: Pose }[] => [{ time: 0, pose: p }, { time: 1, pose: p }];
const clips: THREE.AnimationClip[] = [
  clip('sit', [{ time: 0, pose: seated() }, { time: 0.6, pose: seated({ Spine: { forward: BOB }, Head: { forward: -BOB } }) }, { time: 1.2, pose: seated() }]),
  clip('lean_left', held(seated({ Spine: { left: LEAN }, Head: { left: -LEAN * 0.4 }, LeftArm: { forward: 40, left: 4 }, RightArm: { forward: 70, left: -8 } }))),
  clip('lean_right', held(seated({ Spine: { left: -LEAN }, Head: { left: LEAN * 0.4 }, LeftArm: { forward: 70, left: 8 }, RightArm: { forward: 40, left: -4 } }))),
  clip('tuck', held(seated({ Spine: { forward: 38 }, Head: { forward: -25 }, LeftArm: { forward: 35, left: 8 }, RightArm: { forward: 35, left: -8 }, LeftForeArm: { forward: 60 }, RightForeArm: { forward: 60 } }))),
  clip('brace', [{ time: 0, pose: seated() }, { time: 0.25, pose: seated({ Spine: { forward: -12 }, LeftArm: { forward: 150, left: 25 }, RightArm: { forward: 150, left: -25 }, LeftForeArm: { forward: 10 }, RightForeArm: { forward: 10 }, Head: { forward: 10 } }) }]),
  clip('cheer', [
    { time: 0, pose: seated({ LeftArm: { forward: 10, left: 160 }, RightArm: { forward: 10, left: -160 }, LeftForeArm: { forward: 20 }, RightForeArm: { forward: 20 } }) },
    { time: 0.35, pose: seated({ Spine: { forward: -8 }, LeftArm: { forward: 10, left: 140 }, RightArm: { forward: 10, left: -140 }, LeftForeArm: { forward: 50 }, RightForeArm: { forward: 50 }, Head: { forward: -15 } }) },
    { time: 0.7, pose: seated({ LeftArm: { forward: 10, left: 160 }, RightArm: { forward: 10, left: -160 }, LeftForeArm: { forward: 20 }, RightForeArm: { forward: 20 } }) },
  ]),
];

// On foot (the teammate): _driver.lua's, the planted feet solved for this figure's own legs.
const at = (n: string): THREE.Vector3 => bone(n).getWorldPosition(new THREE.Vector3());
const THIGH = at('LeftUpLeg').distanceTo(at('LeftLeg'));
const SHIN = at('LeftLeg').distanceTo(at('Ankle_L'));
const ANKLE = at('Ankle_L').y;
const HIP_DROP = at('Hips').y - at('LeftUpLeg').y;
const TOE = at('ToesEnd_L').z - at('Ankle_L').z;
const HEEL = ANKLE * 0.9;
const rad = THREE.MathUtils.degToRad;
const deg = THREE.MathUtils.radToDeg;
const hipAt = (lean: number, ground: number): [number, number] => [HIPS - HIP_DROP * Math.cos(rad(lean)) - ground, -HIP_DROP * Math.sin(rad(lean))];
const soleDrop = (shin: number): number => {
  const s = rad(shin);
  return Math.max(ANKLE * Math.cos(s) + HEEL * 0.6 * Math.sin(s), ANKLE * Math.cos(s) - TOE * Math.sin(s));
};
const acos = (x: number): number => Math.acos(Math.max(-1, Math.min(1, x)));
function solve(hy: number, hz: number, ay: number, az: number): [number, number] {
  const dy = hy - ay, dz = az - hz;
  const d = Math.min(Math.hypot(dy, dz), (THIGH + SHIN) * 0.999);
  const ang = deg(Math.atan2(dz, dy));
  const alpha = deg(acos((THIGH * THIGH + d * d - SHIN * SHIN) / (2 * THIGH * d)));
  const beta = deg(acos((SHIN * SHIN + d * d - THIGH * THIGH) / (2 * SHIN * d)));
  return [ang + alpha, ang - beta];
}
function foot(lean: number, ground: number, z: number, lift: number): [number, number] {
  const [hy, hz] = hipAt(lean, ground);
  let [th, sh] = solve(hy, hz, ANKLE + lift, z);
  for (let i = 0; i < 3; i++) [th, sh] = solve(hy, hz, soleDrop(sh) + lift, z);
  return [th, sh];
}
function onFoot(lean: number, spine: number, head: number, l: [number, number], r: [number, number], la: [number, number], ra: [number, number], spread = 6): Pose {
  const back = lean + spine;
  return {
    Hips: { forward: lean }, Spine: { forward: spine }, Head: { forward: head },
    LeftUpLeg: { forward: l[0] + lean }, LeftLeg: { forward: l[1] - l[0] },
    RightUpLeg: { forward: r[0] + lean }, RightLeg: { forward: r[1] - r[0] },
    LeftArm: { forward: la[0] + back, left: spread }, LeftForeArm: { forward: la[1] },
    RightArm: { forward: ra[0] + back, left: -spread }, RightForeArm: { forward: ra[1] },
  };
}
// (The grounds: pusher.ts' CROUCH, RUN_DIP, STUMBLE_DIP.)
const READY_GROUND = 0.12;
const ready = (k: number): Pose => {
  const lean = 34 + k * 6;
  return onFoot(lean, 12, -42 - k * 4, foot(lean, READY_GROUND, 0.16, 0), foot(lean, READY_GROUND, -0.24, 0), [70 - k * 4, 18 + k * 8], [70 - k * 4, 18 + k * 8]);
};
clips.push(clip('ready', [{ time: 0, pose: ready(0) }, { time: 0.25, pose: ready(1) }, { time: 0.5, pose: ready(0) }]));

const RUN_GROUND = 0.08, RUN_LEAN = 40, RUN_STANCE = 0.35, RUN_REACH = 0.24, RUN_SWEEP = 0.52;
function runFoot(u: number): [number, number] {
  u = ((u % 1) + 1) % 1;
  if (u < RUN_STANCE) return foot(RUN_LEAN, RUN_GROUND, RUN_REACH - (RUN_SWEEP * u) / RUN_STANCE, 0);
  const w = (u - RUN_STANCE) / (1 - RUN_STANCE);
  const ease = w * w * (3 - 2 * w);
  const z = RUN_REACH - RUN_SWEEP + RUN_SWEEP * ease - 0.14 * Math.sin(Math.PI * w);
  return foot(RUN_LEAN, RUN_GROUND, z, 0.3 * Math.sin(Math.PI * w) ** 0.8);
}
const pushKeys: { time: number; pose: Pose }[] = [];
for (let i = 0; i <= 8; i++) {
  const t = i / 8;
  const pump = Math.sin(4 * Math.PI * t);
  pushKeys.push({ time: t, pose: onFoot(RUN_LEAN + pump * 2, 14, -46, runFoot(t), runFoot(t + 0.5), [74 + pump * 4, 14 - pump * 8], [74 + pump * 4, 14 - pump * 8]) });
}
clips.push(clip('push', pushKeys));

const STUMBLE_GROUND = 0.06;
function stumbleFoot(u: number): [number, number] {
  u = u % 1;
  if (u < 0.4) return foot(10, STUMBLE_GROUND, 0.2 - (0.4 * u) / 0.4, 0);
  const w = (u - 0.4) / 0.6;
  return foot(10, STUMBLE_GROUND, -0.2 + 0.4 * w, 0.18 * Math.sin(Math.PI * w));
}
const MILL: [number, number][] = [[-20, 150], [150, 30], [80, 10], [150, -60]];
const staggerKeys: { time: number; pose: Pose }[] = [];
for (let i = 1; i <= 5; i++) {
  const t = (i - 1) * 0.15;
  const u = (i - 1) / 4;
  const l = MILL[(i - 1) % 4]!, r = MILL[(i + 1) % 4]!;
  const pose = onFoot(10, -6, -10, stumbleFoot(u), stumbleFoot(u + 0.5), [l[0], 35], [r[0], 50]);
  pose.LeftArm!.left = 40 + l[1] * 0.15;
  pose.RightArm!.left = -40 - r[1] * 0.15;
  staggerKeys.push({ time: t, pose });
}
clips.push(clip('stagger', staggerKeys));

const flat = (kick: number): Pose => onFoot(86, 0, -35, [-86, -86 - kick], [-84, -114 + kick], [80, 10], [80, 10], 25);
clips.push(clip('flat', [{ time: 0, pose: flat(0) }, { time: 0.7, pose: flat(30) }, { time: 1.4, pose: flat(0) }]));

person.name = NAME;
skin.castShadow = true;
const glb = await new GLTFExporter().parseAsync(person, { binary: true, animations: clips, onlyVisible: false });
writeFileSync(out, Buffer.from(glb as ArrayBuffer));
console.info(`${NAME}.glb: hips ${HIPS} m, thigh ${THIGH.toFixed(3)} shin ${SHIN.toFixed(3)} ankle ${ANKLE.toFixed(3)}, ${clips.length} clips, ${skin.geometry.getAttribute('position').count} vertices`);
