/**
 * Brings polyperfect's Low Poly Animated People into the crowd: each chosen rigged person (an FBX) with the pack's
 * animations (more FBXs, the same skeleton) made into one GLB the game can play -- the clips renamed to the crowd's
 * own (`crowd.ts`: fan_idle, fan_wave, fan_cheer ...), the pack's colour atlas baked into vertex colours (one white
 * material, no texture: as the game's own models are), and sized to stand as tall as the old spectators.
 *
 *   node scripts/people-import.ts "<pack folder>"
 *
 * Writes AssetsSource/models/people/<name>.glb (the pipeline exports each to src/assets/models/people/).
 */
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import sharp from 'sharp';
import * as THREE from 'three';
import { FBXLoader } from 'three/examples/jsm/loaders/FBXLoader.js';
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import { mergeVertices } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

const pack = process.argv[2];
if (!pack) throw new Error('usage: node scripts/people-import.ts "<Low Poly Animated People folder>"');
const outDir = new URL('../AssetsSource/models/people/', import.meta.url);
mkdirSync(outDir, { recursive: true });

// Node has no DOM: textures are not loaded (the atlas is baked in below), and the exporter's FileReader is a stand-in.
THREE.TextureLoader.prototype.load = function () { return new THREE.Texture(); };
(globalThis as Record<string, unknown>).self ??= globalThis;
(globalThis as Record<string, unknown>).FileReader ??= class {
  result: ArrayBuffer | string | null = null;
  onloadend: (() => void) | null = null;
  readAsArrayBuffer(b: Blob): void { void b.arrayBuffer().then((r) => { this.result = r; this.onloadend?.(); }); }
  readAsDataURL(b: Blob): void { void b.arrayBuffer().then((r) => { this.result = `data:${b.type};base64,${Buffer.from(r).toString('base64')}`; this.onloadend?.(); }); }
};

/** The old spectators' height at their model's size (karts/spectator_a: the crowd scales them from there). */
const HEIGHT = 1.234;

/** Who goes in: the pack's rig, and the name it gets. */
const PEOPLE: readonly (readonly [string, string])[] = [
  ['man_casual_Rig', 'man_casual'], ['woman_casual_Rig', 'woman_casual'],
  ['man_casual_shorts_Rig', 'man_shorts'], ['woman_casual_shorts_Rig', 'woman_shorts'],
  ['man_business_Rig', 'man_business'], ['woman_farm_Rig', 'woman_farm'],
  ['man_coat_winter_Rig', 'man_winter'], ['woman_large_Rig', 'woman_large'],
  ['boy_casual_cap_Rig', 'boy_cap'], ['girl_casual_shorts', 'girl_shorts'], ['girl_coat_winter_Rig', 'girl_winter'],
  ['man_police_Rig', 'man_police'], ['woman_construction_worker_Rig', 'woman_hivis'], ['man_mechanic_Rig', 'man_mechanic'],
  ['man_clown_Rig', 'man_clown'], ['woman_viking_Rig', 'woman_viking'], ['man_pirate_Rig', 'man_pirate'], ['man_wizard_Rig', 'man_wizard'],
];

/** The crowd's clips, each from the pack's animation of this name (the first found). */
// (Only these six: the crowd plays the rest -- hold, sip, point, flag, clap, cheer -- as one of them: crowd.ts' PEOPLE_CLIP.)
const CLIPS: Record<string, readonly string[]> = {
  fan_idle: ['Idle_Generic'],
  fan_chat: ['Idle_HardDay', 'Idle_Generic'],
  fan_film: ['Idle_Texting'],
  fan_wave: ['Idle_Waving'],
  fan_jump: ['Standing_Jump'],
  fan_flinch: ['Idle_Crouching', 'Idle_Generic'],
};

const loader = new FBXLoader();
const load = (path: string): THREE.Group => {
  const b = readFileSync(path);
  return loader.parse(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength), '');
};

// The pack's animations, by name.
const anims = new Map<string, THREE.AnimationClip>();
const animFiles = ['Idles/Idle_Generic', 'Idles/Idle_HardDay', 'Idles/Idle_Texting', 'Idles/Idle_Waving', 'Idles/Idle_Crouching', 'Locomotion/Standing_Jump'];
for (const f of animFiles) {
  try {
    const g = load(join(pack, '- Animations', 'In Place', `${f}.fbx`));
    const clip = g.animations[0];
    if (clip) anims.set(f.split('/').pop()!, clip);
  } catch (err) {
    console.warn(`animation ${f}: ${(err as Error).message}`);
  }
}
console.info(`animations: ${[...anims.keys()].join(', ')}`);

// The colour atlas, as raw pixels, for baking.
const atlasFile = join(pack, '- Textures', 'color-atlas-new2.png');
const atlas = await sharp(atlasFile).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
const colourAt = (u: number, v: number, out: THREE.Color): void => {
  const { width, height } = atlas.info;
  const x = Math.max(0, Math.min(width - 1, Math.floor((u - Math.floor(u)) * width)));
  const y = Math.max(0, Math.min(height - 1, Math.floor((1 - (v - Math.floor(v))) * height)));
  const i = (y * width + x) * 4;
  out.setRGB(atlas.data[i]! / 255, atlas.data[i + 1]! / 255, atlas.data[i + 2]! / 255, THREE.SRGBColorSpace);
};

/** The bones a crowd figure is animated by: its body and limbs, not its fingers nor its face. */
const BODY_BONES = /^(Root_M|Hip_[LR]|Knee_[LR]|Ankle_[LR]|Spine1_M|Chest_M|Scapula_[LR]|Shoulder_[LR]|Elbow_[LR]|Wrist_[LR]|Neck_M|Head_M)$/;

/** A track with every other key (its last always kept): half the data, the motion the same at a glance. */
function thin(t: THREE.KeyframeTrack): THREE.KeyframeTrack {
  const n = t.times.length;
  if (n < 4) return t;
  const size = t.getValueSize();
  const keep: number[] = [];
  for (let i = 0; i < n; i += 2) keep.push(i);
  if (keep[keep.length - 1] !== n - 1) keep.push(n - 1);
  const times = new Float32Array(keep.length);
  const values = new Float32Array(keep.length * size);
  keep.forEach((k, j) => {
    times[j] = t.times[k]!;
    for (let v = 0; v < size; v++) values[j * size + v] = t.values[k * size + v]!;
  });
  const Track = t.constructor as new (name: string, times: Float32Array, values: Float32Array) => THREE.KeyframeTrack;
  return new Track(t.name, times, values);
}

const exporter = new GLTFExporter();
const white = new THREE.MeshStandardMaterial({ color: 0xffffff, vertexColors: true, roughness: 0.8, metalness: 0 });
const c = new THREE.Color();
for (const [rig, name] of PEOPLE) {
  let person: THREE.Group;
  try {
    person = load(join(pack, '- Models', 'Rigs', `${rig}.fbx`));
  } catch (err) {
    console.warn(`${rig}: ${(err as Error).message}`);
    continue;
  }
  // (Only the skinned figure: the rig's helper shapes -- a bone display -- and its control curve left out; the curve
  // holds the skeleton, which is moved up to its parent.)
  const helpers: THREE.Object3D[] = [];
  person.traverse((o) => {
    if (((o as THREE.Mesh).isMesh && !(o as THREE.SkinnedMesh).isSkinnedMesh) || (o as THREE.Line).isLine) helpers.push(o);
  });
  for (const h of helpers) {
    for (const c of [...h.children]) h.parent!.attach(c);
    h.removeFromParent();
  }
  // Baked: each vertex its atlas colour; one white material for the whole figure.
  person.traverse((o) => {
    const mesh = o as THREE.SkinnedMesh;
    if (!mesh.isMesh) return;
    const geo = mesh.geometry as THREE.BufferGeometry;
    const uv = geo.getAttribute('uv');
    const n = geo.getAttribute('position').count;
    const colours = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) {
      if (uv) colourAt(uv.getX(i), uv.getY(i), c);
      else c.setRGB(0.8, 0.8, 0.8);
      colours[i * 3] = c.r; colours[i * 3 + 1] = c.g; colours[i * 3 + 2] = c.b;
    }
    geo.setAttribute('color', new THREE.BufferAttribute(colours, 3));
    geo.deleteAttribute('uv');
    // Its corners shared again (the loader hands every triangle its own): a third of the vertices.
    mesh.geometry = mergeVertices(geo, 1e-4);
    mesh.material = white;
    mesh.castShadow = false;
  });
  // Stood on its feet at the origin, as tall as the old spectators.
  person.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(person);
  const tall = box.max.y - box.min.y;
  if (tall > 0) person.scale.multiplyScalar(HEIGHT / tall);
  person.updateMatrixWorld(true);
  const box2 = new THREE.Box3().setFromObject(person);
  person.position.y -= box2.min.y;
  // The crowd's clips, renamed.
  const clips: THREE.AnimationClip[] = [];
  for (const [clipName, from] of Object.entries(CLIPS)) {
    const src = from.map((f) => anims.get(f)).find(Boolean);
    if (!src) continue;
    const clip = src.clone();
    clip.name = clipName;
    // Lighter: no scale keys, positions only for the root (the rest of the bones only turn), and every key that
    // says nothing new dropped.
    // And only the bones that show at a crowd's distance -- no fingers, no face -- every other key kept.
    clip.tracks = clip.tracks
      .filter((t) => !t.name.endsWith('.scale') && (!t.name.endsWith('.position') || t.name.startsWith('Root_M.')))
      .filter((t) => BODY_BONES.test(t.name.split('.')[0]!))
      .map((t) => thin(t));
    clip.optimize();
    clips.push(clip);
  }
  person.name = name;
  const glb = await exporter.parseAsync(person, { binary: true, animations: clips, onlyVisible: false });
  writeFileSync(new URL(`${name}.glb`, outDir), Buffer.from(glb as ArrayBuffer));
  console.info(`${name}.glb  ${(tall).toFixed(2)} tall in the pack, ${clips.length} clips`);
}
