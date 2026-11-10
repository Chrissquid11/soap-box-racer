/**
 * mendKart and mendCamera, 5 Hz: the kart and its camera made whole again if they turn up without the game's own
 * components. The editor keeps an unsaved world through a page reload; when new game code arrives and the live swap
 * fails part way, the world it keeps has its entities and the engine's components but not the game's -- a kart with
 * no `Kart` or `Build`, wheels with no `Wheel`, a camera with no `ChaseCam` -- and nothing would run. So: a kart's body
 * (the one with `Forces`) missing any of them, or with no wheel that is a `Wheel`, is put back as a fresh kart from
 * its prefab (whole by construction: the race then sets it on the line and `assemble` builds it), and a main camera
 * given a `ChaseCam` -- or its chase pointed again -- at the kart there is. In a scene as saved, neither ever acts.
 */
import { BoxCollider, Camera, Forces, Hierarchy, NONE, optional, type World } from '@vibe/engine';
import { Build, ChaseCam, Kart, Wheel } from '../components.ts';
import { HomemadeKart } from '../prefabs.ts';

export function mendKart(world: World): void {
  world.system({
    name: 'mendKart',
    rate: 5,
    with: [Forces, BoxCollider],
    read: [Hierarchy],
    update({ members, count, cmd, has }, [tree]) {
      for (let n = 0; n < count; n++) {
        const e = members[n];
        let wheels = 0;
        for (let c = tree.firstChild[e]; c !== 0; c = tree.nextSibling[c]) if (has(c, Wheel)) wheels++;
        if (has(e, Kart) && has(e, Build) && wheels > 0) continue;
        // Not a kart any more, or a kart in pieces: a whole one in its place.
        cmd.destroy(e);
        cmd.instantiate(HomemadeKart);
      }
    },
  });
}

export function mendCamera(world: World): void {
  const karts = world.query({ with: [Kart] });
  world.system({
    name: 'mendCamera',
    rate: 5,
    with: [Camera],
    read: [Camera],
    // Optional: a camera without one is what it is here to mend (a system's written components are otherwise its members' own).
    write: [optional(ChaseCam)],
    update({ members, count, cmd, has, ref, deref }, [camera], [chase]) {
      if (karts.count === 0) return;
      const kart = karts.members[0]!;
      for (let n = 0; n < count; n++) {
        const e = members[n];
        if (!camera.main[e]) continue;
        if (!has(e, ChaseCam)) cmd.add(e, ChaseCam).target[e] = ref(kart);
        else if (deref(chase.target[e]) === NONE) chase.target[e] = ref(kart);
      }
    },
  });
}
