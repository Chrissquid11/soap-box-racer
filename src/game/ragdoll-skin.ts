/**
 * The thrown driver's skin: one skinned `karts/driver` model whose bones follow the ragdoll's ten bodies,
 * so a crash throws a whole floppy person, not loose pieces. A render system of the page's (one of
 * the game entry's `installs`): each frame, for every `RagdollSkin`, each of its ragdoll's bodies
 * (`RagdollBone`) turns its bone -- the hips (and the spine riding on them) with the torso, the head,
 * each upper arm and thigh, then each forearm and shin on its hinge -- and the hips go where the torso
 * is. The neck keeps its rest bend on the spine.
 *
 * The bodies are laid out in the model's rest pose (`karts/ragdoll.prefab` matches
 * `AssetsSource/models/karts/driver.lua`): a bone's rest turn relative to the model, taken once from the
 * model as it arrives, times its body's turn now, is the bone's turn now.
 */
import * as THREE from 'three';
import { Hierarchy, optional, View, WorldTransform, type World } from '@vibe/engine';
import { Bone, RagdollBone, RagdollSkin } from './components.ts';

/** The skeleton's bone for each ragdoll body, by `Bone`'s order. */
const BONE_NAMES = ['Hips', 'Head', 'LeftArm', 'RightArm', 'LeftUpLeg', 'RightUpLeg', 'LeftForeArm', 'RightForeArm', 'LeftLeg', 'RightLeg'] as const;
/** The hips' place in the torso body, metres: the hips joint (0.62 up) under the torso's middle (0.80 up). */
const HIPS_IN_TORSO = new THREE.Vector3(0, 0.62 - 0.8, 0);

interface Rig {
  readonly bones: (THREE.Object3D | null)[];
  /** Each bone's rest turn relative to the model. */
  readonly rest: THREE.Quaternion[];
}

const rigs = new WeakMap<THREE.Object3D, Rig>();
const bodies = new Int32Array(BONE_NAMES.length);
const bodyQ = new THREE.Quaternion();
const want = new THREE.Quaternion();
const parentQ = new THREE.Quaternion();
const objQ = new THREE.Quaternion();
const hips = new THREE.Vector3();

/** The rig of a newly seen skin: its bones by name, and their rest turns, read before anything moves them. */
function rigOf(obj: THREE.Object3D): Rig {
  let rig = rigs.get(obj);
  if (rig) return rig;
  obj.updateMatrixWorld(true);
  obj.getWorldQuaternion(objQ).invert();
  const bones: (THREE.Object3D | null)[] = [];
  const rest: THREE.Quaternion[] = [];
  for (const name of BONE_NAMES) {
    const bone = obj.getObjectByName(name) ?? null;
    bones.push(bone);
    rest.push(bone ? objQ.clone().multiply(bone.getWorldQuaternion(new THREE.Quaternion())) : new THREE.Quaternion());
  }
  // A pose is the bones', so the rest pose's bounds would cull it wrongly.
  obj.traverse((o) => {
    o.frustumCulled = false;
  });
  rig = { bones, rest };
  rigs.set(obj, rig);
  return rig;
}

/** The game entry's install: the ragdoll skins posed each frame. */
export function ragdollSkin(world: World): () => void {
  world.system({
    name: 'ragdoll-skin',
    phase: 'render',
    with: [RagdollSkin],
    read: [View, Hierarchy, optional(WorldTransform), optional(RagdollBone)],
    update({ members, count, has }, [view, tree, where, which]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        const obj = view.get(e);
        if (!obj) continue;
        const rig = rigOf(obj);
        // This skin's bodies: its ragdoll's other children, each the bone it moves.
        bodies.fill(0);
        const root = tree.parent[e];
        for (let c = tree.firstChild[root]; c !== 0; c = tree.nextSibling[c]) {
          if (c !== e && has(c, RagdollBone)) bodies[which.bone[c]] = c;
        }
        // Parents first: the hips (placed and turned), then the head, the arms and the legs.
        for (let b = 0; b < BONE_NAMES.length; b++) {
          const body = bodies[b];
          const bone = rig.bones[b];
          if (body === 0 || !bone || !bone.parent) continue;
          bodyQ.set(where.qx[body], where.qy[body], where.qz[body], where.qw[body]);
          want.copy(bodyQ).multiply(rig.rest[b]);
          if (b === Bone.hips) {
            hips.copy(HIPS_IN_TORSO).applyQuaternion(bodyQ);
            hips.x += where.px[body];
            hips.y += where.py[body];
            hips.z += where.pz[body];
            bone.parent.updateWorldMatrix(true, false);
            bone.position.copy(bone.parent.worldToLocal(hips));
          }
          bone.parent.getWorldQuaternion(parentQ);
          bone.quaternion.copy(parentQ.invert().multiply(want));
          bone.updateMatrixWorld(true);
        }
      }
    },
  });
  return () => {};
}
