-- The placeholder prop the base project spins in its scene: a one-metre crate,
-- resting on the ground at Y = 0 and centred on its footprint. Metres, Y up.
--
-- Here to prove the pipeline end to end -- this script, `npm run export` (its options,
-- none, and what was built in `crate.export.json`), `src/assets/models/props/crate.glb`,
-- `Assets.instance('props/crate')` -- and to be deleted (with its record and its export)
-- once a game has art.
--
-- Colour is on the vertices over one white material (glTF multiplies COLOR_0 by
-- the base colour), the way every model in the pipeline is painted.
local P = params{
  size = {default=1.0, min=0.1, max=4.0, doc="Edge length, metres"}
}
local mat = material{name="Crate", base_color=v3(1,1,1), roughness=0.7, metallic=0}

local h = 0.5*P.size
local vs = {
  v3(-h,0,-h), v3(h,0,-h), v3(h,0,h), v3(-h,0,h),
  v3(-h,2*h,-h), v3(h,2*h,-h), v3(h,2*h,h), v3(-h,2*h,h),
}
-- Wound counter-clockwise seen from outside: bottom, top, then the four sides.
local fs = {
  {1,2,3,4}, {5,8,7,6}, {1,5,6,2}, {2,6,7,3}, {3,7,8,4}, {4,8,5,1},
}
local m = polyhedron{vertices=vs, faces=fs}

local all = faces_where(m, function(_) return true end)
local n = 0
local top = faces_where(m, function(_) n = n + 1; return n == 2 end)
m = paint_faces(m, {faces=all, color=v3(0.85,0.55,0.25)})
m = paint_faces(m, {faces=top, color=v3(0.98,0.78,0.42)})

emit(m, {name="crate", material=mat})
info(string.format("%d triangles", triangle_count(m)))
