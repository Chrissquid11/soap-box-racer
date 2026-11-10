-- What a kart breaks into, beside the broken planks and splinters (parts.lua): shards of its bodywork and its frame,
-- each its own part, white, so the game tints each piece the colour of what it broke off (Render.tint):
--
--   shard_a   a thin curved panel, an irregular five-sided piece of shell
--   shard_b   a chunky fragment, thick and jagged
--   shard_c   a sharp triangular sliver
--   shard_d   a long strip, a bit of trim or rail
--   bolt      a hex bolt with its nut: the hardware that held it all together (grey, not tinted to white)
--   spark     a glowing streak: metal scraping on the road (emissive)
--
-- Each about its own middle, about 0.2 m across: the game scales them for variety. Low polys, flat shaded: debris.
local p = params{
  jag = {default=0.35, min=0, max=0.6, doc="How jagged the shards' outlines are"},
  thick = {default=0.035, min=0.015, max=0.08, doc="A panel shard's thickness, metres"},
}

local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.5, metallic=0.05}
local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
local WHITE = v3(1, 1, 1)
local r = rng(7)

-- An irregular outline of n points round about `rad`, each pushed in or out by up to `jag` of it.
local function outline(n, rad, jag, stretch)
  local pts = {}
  for i = 0, n - 1 do
    local a = (i + r:float(-0.25, 0.25)) / n * 2 * math.pi
    local k = rad * (1 + r:float(-jag, jag))
    pts[#pts + 1] = v2(math.cos(a) * k * (stretch or 1), math.sin(a) * k)
  end
  return poly{points=pts}
end

-- A slab of an outline, `t` thick, its faces' edges softened a little, about its own middle.
local function slab(prof, t)
  local m = extrude(prof, {distance=t, anchor="center"})
  m = bevel(m, {edges=convex_edges(m, {min_angle=50}), width=t * 0.25, segments=1})
  return smooth_normals(m, {angle=20})
end

local function out(name, m, c)
  emit(paint(m, c or WHITE), {name=name, material=PAINT})
end

-- A panel, bent a little so it reads as a piece of curved shell.
local a = slab(outline(5, 0.1, p.jag), p.thick)
a = rotate_verts(a, {verts=verts_where(a, function(v) return v.position.x > 0.03 end), angle=18, axis=axis_y(), pivot=v3(0.03, 0, 0)})
out("shard_a", smooth_normals(a, {angle=20}))

-- A chunk: thick, six-sided, tipped.
local b = slab(outline(6, 0.075, p.jag * 1.2), 0.07)
out("shard_b", rotate(b, {angle=25, axis=axis_x(), pivot=origin()}))

-- A sliver: three points, one long.
local c = slab(outline(3, 0.1, p.jag * 0.6, 1.6), p.thick * 0.8)
out("shard_c", c)

-- A strip: long and thin, its ends broken off at angles.
local d = extrude(poly{points={v2(-0.16, -0.02), v2(0.15, -0.025), v2(0.17, 0.02), v2(-0.13, 0.025)}}, {distance=p.thick * 1.2, anchor="center"})
out("shard_d", smooth_normals(d, {angle=20}))

-- A hex bolt and its nut, steel grey.
local head = cylinder{radius=0.03, height=0.018, segments=6, axis="y"}
local shank = translate(cylinder{radius=0.012, height=0.09, segments=10, axis="y"}, v3(0, -0.05, 0))
local nut = translate(cylinder{radius=0.026, height=0.016, segments=6, axis="y"}, v3(0, -0.07, 0))
local steel = v3(0.55, 0.57, 0.6)
local parts = {}
for i, m in ipairs({head, shank, nut}) do parts[i] = {mesh=paint(smooth_normals(m, {angle=30}), steel), material=PAINT} end
emit(merge({parts=parts})[1].mesh, {name="bolt", material=PAINT})

-- Effects (src/game/systems/fx.ts), white, tinted by the game: a puff of dust (a lumpy ball, 1 m across, scaled
-- down) and a skid mark (a flat strip 1 m long and 1 m wide, a hair thick, laid on the road and scaled).
local puff = sphere{radius=0.5, segments=10, rings=6}
out("puff", smooth_normals(puff, {angle=60}))
out("mark", box{size=v3(1, 0.01, 1)})

-- A spark (src/game/sparks.ts): a unit box the game stretches along its flight -- thin and long, a streak -- glowing
-- yellow-white hot of itself (emissive), whatever light it is in.
local SPARK = material{name="Spark", base_color=v3(1, 0.9, 0.6), emissive=v3(7, 4.2, 1.3), roughness=1, metallic=0}
emit(box{size=v3(1, 1, 1)}, {name="spark", material=SPARK})
