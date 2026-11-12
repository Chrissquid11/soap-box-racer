-- The course's hazards, each its own part, each standing on the ground at its origin and facing +z:
--
--   ramp        a plywood roller along +z: 4 m wide, 18 m long, one smooth wave 0.45 m high at its middle
--   jump        the big final jump: 10 m wide, 5 m long, 1.1 m high at its lip
--   bin         a wheelie bin: 0.6 x 1.0 x 0.72
--   cone        a traffic cone: 0.7 m
--   bale        a round hay bale on its side: 1.2 m across, 1.0 m long, axis x
--   hay_bale    a square hay bale lining the edges: 0.5 x 0.42 x 1.0, long along z
--   tyre_stack  three old tyres stacked for a chicane: 0.68 across, 0.6 high
--   tyre, tyre_top  one of them alone, lying flat about its middle (0.2 high): the game stacks three, loose
--   bonus       a plain yellow star to collect, 0.9 m across, about its middle
--   rattler     the bone rattler: washboard ridges across the road, 1 m wide, 8 m long, 7 cm high
--
-- The ramps' sizes match src/game/course.ts. Colours on the vertices, one white material.
local PAINT = material{name="Paint", base_color=v3(1,1,1), roughness=0.8, metallic=0}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
-- Painted pieces into one mesh, each keeping its colours (join would drop them): merged onto the one white material.
local function combine(pieces)
  local parts = {}
  for _, p in ipairs(pieces) do parts[#parts + 1] = {mesh=p, material=PAINT} end
  for i, p in ipairs(parts) do p.mesh = smooth_normals(p.mesh, {angle=35}) end
  return merge({parts=parts})[1].mesh
end
local function bx(sx, sy, sz, x, y, z) return translate(box{size=v3(sx, sy, sz)}, v3(x, y, z)) end
-- Paint the faces `fn(centre, normal)` holds for; nothing when it holds for none.
local function paint_where(m, c, fn)
  local sel = faces_where(m, function(f) return fn(f.center, f.normal) == true end)
  if set_count(sel) == 0 then return m end
  return paint_faces(m, {faces=sel, color=c})
end
-- A rounded box: its edges bevelled.
local function rbox(sx, sy, sz, r, x, y, z)
  local m = box{size=v3(sx, sy, sz)}
  m = bevel(m, {edges=sharp_edges(m, {angle=30}), width=r, segments=2})
  return translate(smooth_normals(m, {angle=40}), v3(x, y, z))
end
local function shade(c, k) return v3(c.x * k, c.y * k, c.z * k) end

-- A kicker's rise along it, as a share of its height, for s from 0 (its foot) to 1 (its lip): flat at the foot, curving
-- up over the first CURVE of its length (a parabola, so no kink where it meets the road), then straight on up to the
-- lip at the slope the curve ends on. As src/game/courses.ts' rampRise.
local CURVE = 0.55
local K = 1 / (CURVE * (2 - CURVE))
local function rise(s)
  if s <= CURVE then return K * s * s end
  return K * CURVE * CURVE + 2 * K * CURVE * (s - CURVE)
end

-- Four plywood sheets' tones, the seams between them, the frame's timber.
local plies = {v3(0.8, 0.6, 0.34), v3(0.72, 0.52, 0.28), v3(0.84, 0.66, 0.4), v3(0.76, 0.56, 0.31)}
local seam = v3(0.4, 0.27, 0.13)
local beam = v3(0.32, 0.19, 0.08)
local stripe_a, stripe_b = v3(1.0, 0.72, 0.02), v3(0.04, 0.04, 0.04)
local hazard_red, hazard_white = v3(0.85, 0.06, 0.03), v3(0.95, 0.95, 0.92)
local side_paint = {ramp=v3(0.03, 0.25, 0.75), jump=v3(0.8, 0.08, 0.04)}

-- A kicker's height along it, a share of h for s from 0 (its near foot) to 1 (its far end): a hump is one smooth wave
-- up and down (a roller: no corner anywhere); a jump rises as above to a lip. As courses.ts' kickerRise.
local function profile(hump, s)
  if hump then return (1 - math.cos(2 * math.pi * s)) / 2 end
  return rise(s)
end

-- A kicker: w wide, l long, at most h high (+z), centred on its length: a hump, or a jump with a lip to fly off. One
-- smooth solid -- its top the profile in many strips, a hair above the ground at either foot -- its plywood sheets,
-- seams, warning bands and painted timber sides all paint, never standing proud: the kart rides what it is drawn as.
-- (The sides are cut once along their foot for the painted rail: the top is not touched.)
local function kicker(name, w, l, h, hump)
  local hw = w / 2
  local z0 = -l / 2
  -- Its profile: each section's z and height.
  local prof = {}
  local seams = {}
  -- Fine strips along it (a few centimetres each: the wheels ride a curve, not facets), and its top split across
  -- into columns about 0.5 m wide (light enough to draw, still no long thin triangle for the kart's box to catch on).
  local STRIPS = 160
  local cols = math.max(4, math.ceil(w / 0.5))
  local ss = {}
  for i = 0, STRIPS do ss[#ss + 1] = i / STRIPS end
  for _, s in ipairs({0.25, 0.5, 0.75}) do ss[#ss + 1] = s - 0.0015; ss[#ss + 1] = s + 0.0015; seams[#seams + 1] = s end
  table.sort(ss)
  for _, s in ipairs(ss) do prof[#prof + 1] = {z0 + s * l, h * profile(hump, s)} end
  -- Per section: its two bottom corners, then its top row from -x to +x.
  local per = 2 + cols + 1
  local verts, faces = {}, {}
  for _, p in ipairs(prof) do
    local z = p[1]
    local y = math.max(0.004, p[2])
    verts[#verts + 1] = v3(-hw, 0, z)
    verts[#verts + 1] = v3(hw, 0, z)
    for j = 0, cols do verts[#verts + 1] = v3(-hw + w * j / cols, y, z) end
  end
  local n = #prof
  local function b(i, k) return (i - 1) * per + k end            -- k 1: bottom left, 2: bottom right
  local function t(i, j) return (i - 1) * per + 3 + j end        -- j 0..cols, left to right
  for i = 1, n - 1 do
    faces[#faces + 1] = {b(i, 1), b(i, 2), b(i + 1, 2), b(i + 1, 1)}   -- bottom
    for j = 0, cols - 1 do faces[#faces + 1] = {t(i, j), t(i + 1, j), t(i + 1, j + 1), t(i, j + 1)} end   -- top
    faces[#faces + 1] = {b(i, 2), t(i, cols), t(i + 1, cols), b(i + 1, 2)}   -- right
    faces[#faces + 1] = {b(i, 1), b(i + 1, 1), t(i + 1, 0), t(i, 0)}         -- left
  end
  -- Its foot and its far end (a lip's face, or a hump's foot): each the bottom edge and the whole top row.
  local foot, far = {b(1, 1)}, {b(n, 1), b(n, 2)}
  for j = 0, cols do foot[#foot + 1] = t(1, j) end
  foot[#foot + 1] = b(1, 2)
  for j = cols, 0, -1 do far[#far + 1] = t(n, j) end
  faces[#faces + 1] = foot
  faces[#faces + 1] = far
  local m = polyhedron{vertices=verts, faces=faces}
  -- The sides' rail: a cut along each side a little above the ground, where the side stands taller than it.
  local RAIL = math.min(0.08, h * 0.15)
  m = knife(m, {normal=axis_y(), point=v3(0, RAIL, 0), faces=faces_where(m, function(f) return math.abs(f.normal.x) > 0.9 end)})

  local function along(c) return (c.z - z0) / l end
  local function top(c, nn) return nn.y > 0.2 and math.abs(nn.x) < 0.5 end
  local function side(nn) return math.abs(nn.x) > 0.9 end
  -- The strip a face is on, counted from the foot.
  local function strip(c) return math.floor(along(c) * 40) end
  m = paint(m, plies[1])
  -- The sheets, a quarter each, and a grain: every other strip a shade darker.
  for q = 1, 4 do
    for g = 0, 1 do
      local c = g == 0 and plies[q] or shade(plies[q], 0.92)
      m = paint_where(m, c, function(cc, nn)
        local s = along(cc)
        return top(cc, nn) and s >= (q - 1) / 4 and s < q / 4 and math.floor(s * 80) % 2 == g
      end)
    end
  end
  m = paint_where(m, seam, function(c, nn)
    if not top(c, nn) then return false end
    for _, q in ipairs(seams) do if math.abs(along(c) - q) < 0.0016 then return true end end
    return false
  end)
  if hump then
    -- A hump's crest in hazard yellow between two black lines, and yellow-and-black warning bands at either foot.
    m = paint_where(m, stripe_b, function(c, nn) return top(c, nn) and math.abs(c.z) < l * 0.058 end)
    m = paint_where(m, stripe_a, function(c, nn) return top(c, nn) and math.abs(c.z) < l * 0.04 end)
    m = paint_where(m, stripe_a, function(c, nn) local s = along(c); return top(c, nn) and (s < 0.1 or s > 0.9) and strip(c) % 2 == 0 end)
    m = paint_where(m, stripe_b, function(c, nn) local s = along(c); return top(c, nn) and (s < 0.1 or s > 0.9) and strip(c) % 2 == 1 end)
  else
    -- A jump: a warning band at its foot, and the run-up to the lip in red and white.
    m = paint_where(m, stripe_a, function(c, nn) return top(c, nn) and along(c) < 0.075 and strip(c) % 2 == 0 end)
    m = paint_where(m, stripe_b, function(c, nn) return top(c, nn) and along(c) < 0.075 and strip(c) % 2 == 1 end)
    m = paint_where(m, hazard_red, function(c, nn) return top(c, nn) and along(c) > 0.85 and strip(c) % 2 == 0 end)
    m = paint_where(m, hazard_white, function(c, nn) return top(c, nn) and along(c) > 0.85 and strip(c) % 2 == 1 end)
    -- Its lip's face, under the chequer, red.
    m = paint_where(m, side_paint.jump, function(c, nn) return nn.z > 0.9 end)
  end
  -- The sides: a painted skirt between timber posts at the sheets' seams, on a dark rail along the ground.
  m = paint_where(m, side_paint[name], function(c, nn) return side(nn) end)
  m = paint_where(m, beam, function(c, nn)
    if not side(nn) then return false end
    if c.y < RAIL then return true end
    local s = along(c)
    for _, q in ipairs({0, 0.25, 0.5, 0.75, 1}) do if math.abs(s - q) < 0.016 then return true end end
    return false
  end)
  -- A jump's sides: hazard stripes by the lip.
  if not hump then
    m = paint_where(m, stripe_a, function(c, nn) return side(nn) and c.y >= RAIL and along(c) > 0.8 and along(c) < 0.985 and strip(c) % 2 == 0 end)
    m = paint_where(m, stripe_b, function(c, nn) return side(nn) and c.y >= RAIL and along(c) > 0.8 and along(c) < 0.985 and strip(c) % 2 == 1 end)
  end
  local pieces = {m}
  -- A jump's lip: a chequer of hazard paint standing proud of its face, past the lip, where the kart has left the ground.
  if not hump then
    local zl = z0 + l
    local cells = math.floor(w / 0.5)
    for i = 0, cells - 1 do
      local x = -hw + (i + 0.5) * (w / cells)
      pieces[#pieces + 1] = paint(bx(w / cells - 0.01, 0.12, 0.03, x, h - 0.07, zl + 0.016), (i % 2 == 0) and stripe_a or stripe_b)
    end
  end
  emit(#pieces == 1 and pieces[1] or combine(pieces), {name=name, material=PAINT})
end
-- As courses.ts' RAMP and JUMP.
kicker("ramp", 4, 18, 0.45, true)
kicker("jump", 10, 5, 1.1, false)

-- A body lofted up through rounded-rectangle sections: { y, width, depth, z } each.
local function rounded_loft(secs, radius, segs)
  local sections = {}
  for _, q in ipairs(secs) do
    sections[#sections + 1] = {p=rounded_rect{w=q[2], h=q[3], radius=radius, segments=segs}, at=v3(0, q[1], q[4] or 0)}
  end
  return smooth_normals(loft(sections, {caps=true}), {angle=40})
end

-- The wheelie bin: a green tapered body with a lip and ribs, a darker lid hinged at the back over a handle, two
-- wheels on an axle, a council sticker on the front. Within 0.6 x 1.0 x 0.72, standing on the ground.
do
  local GREEN, DARK, BLACK, GREY = v3(0.06, 0.4, 0.1), v3(0.035, 0.25, 0.065), v3(0.03, 0.03, 0.03), v3(0.45, 0.45, 0.47)
  local body = rounded_loft({
    {0.06, 0.5, 0.56, 0.01}, {0.2, 0.52, 0.59, 0.01}, {0.4, 0.54, 0.62, 0.01}, {0.6, 0.56, 0.65, 0.005},
    {0.8, 0.575, 0.67, 0}, {0.885, 0.58, 0.68, 0}, {0.89, 0.6, 0.7, 0}, {0.93, 0.6, 0.7, 0},
  }, 0.06, 4)
  -- Ribs: darker bands round the body, and the lip under the lid.
  body = paint(body, GREEN)
  body = paint_where(body, DARK, function(c, nn) return c.y > 0.885 or (c.y > 0.19 and c.y < 0.21) end)
  local lid = rbox(0.6, 0.045, 0.72, 0.015, 0, 0.955, 0)
  -- The lid's front grip.
  local grip = rbox(0.3, 0.035, 0.03, 0.01, 0, 0.93, 0.355)
  local tops = paint(join(lid, grip), DARK)
  -- The hinge along the back, and the handle on two brackets behind it.
  local hinge = translate(cylinder{radius=0.018, height=0.5, segments=12, axis="x"}, v3(0, 0.945, -0.352))
  local handle = translate(cylinder{radius=0.016, height=0.46, segments=12, axis="x"}, v3(0, 0.89, -0.395))
  local brackets = {}
  for side = -1, 1, 2 do brackets[#brackets + 1] = rbox(0.03, 0.05, 0.06, 0.008, 0.22 * side, 0.89, -0.365) end
  local fittings = paint(join(hinge, handle, table.unpack(brackets)), DARK)
  -- The wheels: black tyres, grey hubs, an axle between them.
  local wheels = {}
  for side = -1, 1, 2 do
    -- (its rims rounded over, and its hub a recessed grey disc inset in the wall)
    local tyre = cylinder{radius=0.1, height=0.06, segments=24, axis="x"}
    tyre = bevel(tyre, {edges=convex_edges(tyre, {min_angle=45}), width=0.012, segments=2})
    local hub = faces_where(tyre, function(f) return math.abs(f.normal.x) > 0.99 end)
    tyre = inset_faces(tyre, {faces=hub, distance=0.04})
    tyre = translate(tyre, v3(0.27 * side, 0.1, -0.29))
    tyre = paint_where(paint(tyre, BLACK), GREY, function(c, nn) return math.abs(nn.x) > 0.9 and
      ((c.y - 0.1)^2 + (c.z + 0.29)^2) < 0.05^2 end)
    wheels[#wheels + 1] = tyre
  end
  local axle = paint(translate(cylinder{radius=0.015, height=0.5, segments=10, axis="x"}, v3(0, 0.1, -0.29)), GREY)
  -- The sticker: white, a yellow band, and a black bar for its words.
  local sticker = paint(bx(0.24, 0.2, 0.006, 0, 0.62, 0.333), v3(0.93, 0.93, 0.9))
  local band = paint(bx(0.24, 0.05, 0.004, 0, 0.69, 0.338), v3(1.0, 0.7, 0.02))
  local words = paint(join(bx(0.16, 0.02, 0.004, 0, 0.6, 0.338), bx(0.12, 0.02, 0.004, 0, 0.56, 0.338)), v3(0.05, 0.05, 0.05))
  emit(combine({body, tops, fittings, axle, sticker, band, words, wheels[1], wheels[2]}), {name="bin", material=PAINT})
end

-- The cone: a fluorescent orange cone on a square black base, two reflective white bands, a rounded tip. 0.7 m tall,
-- 0.2 m in radius at the base.
do
  local ORANGE, WHITE, BLACK = v3(1.0, 0.22, 0.01), v3(0.97, 0.97, 0.97), v3(0.03, 0.03, 0.03)
  local base = rbox(0.4, 0.04, 0.4, 0.012, 0, 0.02, 0)
  base = paint_where(paint(base, BLACK), v3(0.9, 0.2, 0.02), function(c, nn) return nn.y > 0.9 and (c.x^2 + c.z^2) < 0.17^2 end)
  -- The body, a ring every few centimetres so the bands can be painted on it.
  local sections = {}
  local R0, R1, Y0, Y1 = 0.165, 0.028, 0.04, 0.675
  for i = 0, 24 do
    local t = i / 24
    local y = Y0 + (Y1 - Y0) * t
    sections[#sections + 1] = {p=circle{radius=R0 + (R1 - R0) * t, segments=32}, at=v3(0, y, 0)}
  end
  local body = smooth_normals(loft(sections, {caps=true}), {angle=50})
  body = paint(body, ORANGE)
  body = paint_where(body, WHITE, function(c, nn) return (c.y > 0.43 and c.y < 0.52) or (c.y > 0.26 and c.y < 0.33) end)
  -- Its foot, a lip round the base of the cone.
  local foot = paint(translate(cylinder{radius=0.175, height=0.02, segments=32}, v3(0, 0.05, 0)), ORANGE)
  local tip = paint(translate(sphere{radius=0.028, segments=16, rings=8}, v3(0, 0.672, 0)), ORANGE)
  emit(combine({base, foot, body, tip}), {name="cone", material=PAINT})
end

-- Hay, for the two bales below: five straw tones from sun-bleached to shadowed, and what both are made of -- a closed
-- skin through rings of points (so the straw can bulge, and the twine bite in, a vertex at a time) and loose wisps.
local HAY = {v3(0.95, 0.82, 0.45), v3(0.9, 0.72, 0.32), v3(0.84, 0.62, 0.22), v3(0.72, 0.5, 0.14), v3(0.56, 0.37, 0.1)}
local function hash(a, b)
  local h = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
  return h - math.floor(h)
end
-- A skin's vertices and faces, n points a ring: every ring's points run counter-clockwise seen from the far end of
-- the axis, a wall joins a ring to the next one along it, and a fan closes an end onto a point.
local function hay_shell(n)
  local S = {verts={}, faces={}}
  function S.vert(p) S.verts[#S.verts + 1] = p; return #S.verts end
  function S.ring(pts)
    local ids = {}
    for j = 1, n do ids[j] = S.vert(pts[j]) end
    return ids
  end
  function S.wall(a, b)
    for j = 1, n do local k = j % n + 1; S.faces[#S.faces + 1] = {a[j], a[k], b[k], b[j]} end
  end
  function S.fan(a, tip, near)
    for j = 1, n do local k = j % n + 1; S.faces[#S.faces + 1] = near and {a[k], a[j], tip} or {a[j], a[k], tip} end
  end
  return S
end
-- A loose stalk: a three-sided spike from (px, py, pz) -- set a little inside the straw -- along (dx, dy, dz), `w`
-- thick at its root. With a `droop` it has a knee past its middle and hangs from there, the more the further over.
-- `keep(x, y, z)`, when given, answers a point of it held within the bale's reach.
local function wisp(px, py, pz, dx, dy, dz, len, w, droop, keep)
  local d = normalize(v3(dx, dy, dz))
  local u = normalize(cross(d, math.abs(d.y) < 0.9 and axis_y() or axis_x()))
  local v = cross(d, u)
  keep = keep or function(x, y, z) return x, y, z end
  local vs = {}
  local function ring(cx, cy, cz, r)
    for k = 0, 2 do
      local c, s = r * math.cos(2 * math.pi * k / 3), r * math.sin(2 * math.pi * k / 3)
      vs[#vs + 1] = v3(cx + c * u.x + s * v.x, cy + c * u.y + s * v.y, cz + c * u.z + s * v.z)
    end
  end
  ring(px, py, pz, w)
  if not droop or droop <= 0 then
    vs[4] = v3(keep(px + d.x * len, py + d.y * len, pz + d.z * len))
    return polyhedron{vertices=vs, faces={{1, 3, 2}, {1, 2, 4}, {2, 3, 4}, {3, 1, 4}}}
  end
  local mx, my, mz = keep(px + d.x * len * 0.55, py + d.y * len * 0.55, pz + d.z * len * 0.55)
  ring(mx, my, mz, w * 0.65)
  local e = normalize(v3(d.x, d.y - droop, d.z))
  vs[7] = v3(keep(mx + e.x * len * 0.45, my + e.y * len * 0.45, mz + e.z * len * 0.45))
  return polyhedron{vertices=vs, faces={{1, 3, 2}, {1, 2, 5, 4}, {2, 3, 6, 5}, {3, 1, 4, 6}, {4, 5, 7}, {5, 6, 7}, {6, 4, 7}}}
end
-- A tuft onto `pieces`: `count` stalks from about (px, py, pz) along about (dx, dy, dz) -- one alone, or a clump
-- fanned out of one spot -- each its own length (about `len`), thickness (about `w`) and straw tone, mostly the pale
-- ones, one in four drooping. `seed` tells one tuft from another.
local function hay_tuft(pieces, seed, px, py, pz, dx, dy, dz, count, len, w, keep)
  for c = 1, count do
    local function h(k) return hash(seed * 7 + c, k) end
    local j = c > 1 and 0.05 or 0
    local tone = h(3)
    pieces[#pieces + 1] = paint(wisp(px + (h(4) - 0.5) * j, py + (h(5) - 0.5) * j, pz + (h(6) - 0.5) * j,
      dx + (h(7) - 0.5) * 0.5, dy + (h(8) - 0.5) * 0.5, dz + (h(9) - 0.5) * 0.5,
      len * (0.75 + 0.6 * h(10)), w * (0.8 + 0.5 * h(11)), h(1) < 0.27 and 0.5 + h(2) or 0, keep),
      HAY[tone < 0.34 and 1 or (tone < 0.62 and 2 or (tone < 0.8 and 3 or (tone < 0.93 and 4 or 5)))])
  end
end
-- Straw paint: each face the tone `tone(centre, normal)` picks, 1 (palest) to 5 (darkest).
local function hay_paint(m, tone)
  m = paint(m, HAY[3])
  for k = 1, #HAY do
    if k ~= 3 then m = paint_where(m, HAY[k], function(c, nn) return tone(c, nn) == k end) end
  end
  return m
end

-- The bale: a round of hay on its side, 1.2 m across, 1.0 m long, axis x, centred 0.6 up -- the straw wound round it
-- in uneven streaks and bulging between four turns of blue baler twine pulled tight into it, its rims rolled over,
-- each end the roll's own spiral (two arms, darker and paler, wound out from the core), a few loose stalks sticking
-- out of it. One skin of twenty sides, the twine and the spiral paint on its faces.
do
  local R, HALF, N = 0.6, 0.5, 20
  local REND, PITCH, DOME = 0.55, 0.1, 0.015       -- an end's flat: its radius, a spiral arm's width, how far its rim sits back
  local TWINE, TW, BITE = {-0.33, -0.11, 0.11, 0.33}, 0.014, 0.016
  local S = hay_shell(N)
  local function pt(x, r, j)
    local a = 2 * math.pi * j / N
    return v3(x, R + r * math.cos(a), r * math.sin(a))
  end
  -- Along it: { x, radius, how lumpy }. The middle ring is the full round, so the bale's size is exact.
  local prof = {{-HALF + DOME, REND, 0}, {-0.44, R, 1}}
  for i, x in ipairs(TWINE) do
    prof[#prof + 1] = {x - TW, R - BITE, 0}
    prof[#prof + 1] = {x + TW, R - BITE, 0}
    if i < #TWINE then prof[#prof + 1] = {x + 0.11, R, i == 2 and 0 or 1} end
  end
  prof[#prof + 1] = {0.44, R, 1}
  prof[#prof + 1] = {HALF - DOME, REND, 0}
  local rings = {}
  for i, q in ipairs(prof) do
    local pts = {}
    for j = 0, N - 1 do
      local a = 2 * math.pi * j / N
      local lump = 0.5 + 0.5 * noise3(q[1] * 4, math.cos(a) * 2.5, math.sin(a) * 2.5, {seed=7})
      pts[j + 1] = pt(q[1], q[2] * (1 - 0.04 * q[3] * lump), j)
    end
    rings[i] = S.ring(pts)
    if i > 1 then S.wall(rings[i - 1], rings[i]) end
  end
  -- The ends: two spiral arms out from the core to the rim, each PITCH wide (a curve gains two of them a turn), the
  -- faces between one curve and the next; a touch domed.
  for e = -1, 1, 2 do
    local ids = {rim=rings[e < 0 and 1 or #rings], core=S.vert(v3(e * HALF, R, 0))}
    local function at(m, j)
      if j == N then m, j = m + 2, 0 end
      local r = PITCH * (m + 2 * j / N)
      if r < 1e-6 then return ids.core end
      if r > REND - 1e-6 then return ids.rim[j + 1] end
      local key = m * N + j
      if not ids[key] then ids[key] = S.vert(pt(e * (HALF - DOME * (r / REND) ^ 2), r, j)) end
      return ids[key]
    end
    for m = -2, math.ceil(REND / PITCH) do
      for j = 0, N - 1 do
        local q = {at(m, j), at(m + 1, j), at(m + 1, j + 1), at(m, j + 1)}
        local f = {}
        for k = 1, 4 do
          if q[k] ~= q[k % 4 + 1] then f[#f + 1] = q[k] end
        end
        if #f >= 3 then
          if e < 0 then local g = {}; for k = #f, 1, -1 do g[#g + 1] = f[k] end; f = g end
          S.faces[#S.faces + 1] = f
        end
      end
    end
  end
  local roll = polyhedron{vertices=S.verts, faces=S.faces}
  roll = hay_paint(roll, function(c, nn)
    local y, z = c.y - R, c.z
    local r, a = math.sqrt(y * y + z * z), math.atan(z, y)
    if a < 0 then a = a + 2 * math.pi end
    if math.abs(c.x) > HALF - DOME - 0.005 then
      -- An end: the spiral's arms by turns, each mottled a little; the core dark.
      if r < 0.06 then return 5 end
      local m = math.floor(r / PITCH - a / math.pi)
      local v = hash(m + (c.x > 0 and 31 or 0), math.floor(a * N / (2 * math.pi)))
      if m % 2 == 0 then return v < 0.3 and 5 or 4 end
      return v < 0.35 and 1 or 2
    end
    -- Round it: streaks that run the way the straw was wound, each band along it its own shade.
    local band = math.floor(c.x * 12 + 40)
    local v = noise3(c.x * 5, math.cos(a) * 1.6, math.sin(a) * 1.6, {seed=7, octaves=2}) + (hash(band, 1) - 0.5) * 0.5
    return math.max(1, math.min(5, math.floor(3.3 + v * 3.6)))
  end)
  roll = paint_where(roll, v3(0.04, 0.3, 0.8), function(c, nn)
    if math.abs(nn.x) > 0.5 then return false end
    for _, x in ipairs(TWINE) do if math.abs(c.x - x) < TW then return true end end
    return false
  end)
  -- Loose straw all over it, singly and in clumps, none more than 7 cm out of the round or past an end, none into
  -- the ground: out of the round (not underneath), leaning round it one way or the other; out of the ends' spirals;
  -- and off the rolled rims.
  local pieces = {roll}
  local function keep(x, y, z)
    local r = math.sqrt((y - R) ^ 2 + z ^ 2)
    local s = r > R + 0.07 and (R + 0.07) / r or 1
    return math.max(-HALF - 0.07, math.min(HALF + 0.07, x)), math.max(0.012, R + (y - R) * s), z * s
  end
  -- A tuft at (x, r out along the angle a from straight up), pointing ax along the bale, `out` of it, `round` it.
  local seed = 0
  local function tuft(x, a, r, ax, out, round, count, len)
    local cy, cz = math.cos(a), math.sin(a)
    seed = seed + 1
    hay_tuft(pieces, seed, x, R + r * cy, r * cz, ax, out * cy - round * cz, out * cz + round * cy, count, len, 0.02, keep)
  end
  for i = 1, 30 do
    local a = rad(-135 + 270 * (i - 0.5 + (hash(i, 12) - 0.5) * 0.8) / 30)
    tuft(-0.43 + 0.86 * hash(i, 11), a, R - 0.05, (hash(i, 14) - 0.5) * 1.2, 0.6, i % 2 == 0 and 0.8 or -0.8,
      hash(i, 13) < 0.3 and 3 or 1, 0.17)
  end
  for e = -1, 1, 2 do
    for i = 1, 9 do
      local a = rad(-150 + 300 * (i - 0.5 + (hash(i, 15 + e) - 0.5) * 0.8) / 9)
      tuft(e * 0.47, a, 0.12 + 0.38 * hash(i, 18 + e), e * 0.9, 0.3, i % 2 == 0 and 0.6 or -0.6,
        hash(i, 21 + e) < 0.3 and 2 or 1, 0.14)
    end
    for i = 1, 6 do
      local a = rad(-140 + 280 * (i - 0.5 + (hash(i, 24 + e) - 0.5) * 0.8) / 6)
      tuft(e * 0.45, a, 0.54, e * 0.5, 0.6, i % 2 == 0 and 0.5 or -0.5, 1, 0.15)
    end
  end
  emit(combine(pieces), {name="bale", material=PAINT})
end

-- The hay bale lining the course's edges: a small square bale, 0.5 wide, 0.42 high and 1.0 long along +z, standing
-- on its origin -- its corners knocked off, the straw streaked along its length and bulging between two orange baler
-- twines pulled tight round it, its cut ends darker, rougher and a little domed, tufts of loose straw out of the ends
-- and off the top. One skin of twelve sides (they are set out in hundreds), the twine paint on its faces.
do
  local W, H, L, N = 0.5, 0.42, 1.0, 12
  local hw, C = W / 2, 0.05
  local TWINE, TW = 0.27, 0.015
  -- Its section, counter-clockwise seen from +z: the four sides each in two strips, the corners cut.
  local sect = {{-hw + C, 0}, {0, 0}, {hw - C, 0}, {hw, C}, {hw, H / 2}, {hw, H - C},
    {hw - C, H}, {0, H}, {-hw + C, H}, {-hw, H - C}, {-hw, H / 2}, {-hw, C}}
  local S = hay_shell(N)
  -- Along it, one half: { z, the section's scale, how lumpy, how ragged in z }. The middle ring is the full section.
  local half = {{0, 1, 0, 0}, {0.135, 1, 1, 0}, {TWINE - TW, 0.95, 0, 0}, {TWINE + TW, 0.95, 0, 0}, {0.44, 1, 1, 0},
    {0.475, 0.93, 0, 0}, {0.488, 0.72, 0, 1}, {0.495, 0.36, 0, 1}}
  local prof = {}
  for k = #half, 2, -1 do prof[#prof + 1] = {-half[k][1], half[k][2], half[k][3], half[k][4]} end
  for k = 1, #half do prof[#prof + 1] = half[k] end
  local rings = {}
  for i, q in ipairs(prof) do
    local pts = {}
    for j, p in ipairs(sect) do
      local lump = 0.5 + 0.5 * noise3(p[1] * 6, p[2] * 6, q[1] * 5, {seed=11})
      local s = q[2] * (1 - 0.04 * q[3] * lump)
      local z = q[1] + (q[1] < 0 and 1 or -1) * q[4] * 0.008 * hash(i, j)
      pts[j] = v3(p[1] * s, H / 2 + (p[2] - H / 2) * s, z)
    end
    rings[i] = S.ring(pts)
    if i > 1 then S.wall(rings[i - 1], rings[i]) end
  end
  S.fan(rings[1], S.vert(v3(0, H / 2, -L / 2)), true)
  S.fan(rings[#rings], S.vert(v3(0, H / 2, L / 2)), false)
  local body = polyhedron{vertices=S.verts, faces=S.faces}
  body = hay_paint(body, function(c, nn)
    if math.abs(c.z) > 0.478 then
      -- A cut end: the stalks' ends, a darker mottle.
      local v = hash(math.floor(c.x * 31) + (c.z > 0 and 17 or 0), math.floor(c.y * 31))
      return v < 0.4 and 5 or (v < 0.8 and 4 or 2)
    end
    -- Its sides: streaks the way the stalks lie, each strip round it its own shade.
    local strip = math.floor((math.atan(c.y - H / 2, c.x) + math.pi) * 12 / (2 * math.pi))
    local v = noise3(c.x * 7, c.y * 7, c.z * 1.6, {seed=11, octaves=2}) + (hash(strip, 3) - 0.5) * 0.5
    return math.max(1, math.min(5, math.floor(2.9 + v * 3.6)))
  end)
  body = paint_where(body, v3(0.95, 0.35, 0.02), function(c, nn)
    return math.abs(nn.z) < 0.5 and math.abs(math.abs(c.z) - TWINE) < TW
  end)
  -- Loose straw, singly and in clumps, none more than 7 cm past the bale's size nor into the ground.
  local pieces = {body}
  local function keep(x, y, z)
    return math.max(-hw - 0.07, math.min(hw + 0.07, x)), math.max(0.012, math.min(H + 0.07, y)),
      math.max(-L / 2 - 0.07, math.min(L / 2 + 0.07, z))
  end
  local seed = 100
  local function tuft(px, py, pz, dx, dy, dz, count, len)
    seed = seed + 1
    hay_tuft(pieces, seed, px, py, pz, dx, dy, dz, count, len, 0.017, keep)
  end
  for e = -1, 1, 2 do
    -- Tufts out of each cut end...
    for i = 1, 7 do
      tuft((hash(i, 31 + e) - 0.5) * 0.36, 0.06 + 0.3 * hash(i, 34 + e), e * 0.46,
        (hash(i, 37 + e) - 0.5) * 0.9, (hash(i, 40 + e) - 0.5) * 0.9 + 0.15, e, hash(i, 43 + e) < 0.3 and 2 or 1, 0.12)
    end
    -- ... stalks lying loose off the top's two long edges, and out of the sides (e the side here) ...
    for i = 1, 5 do
      local z = -0.42 + 0.84 * (i - 0.5 + (hash(i, 46 + e) - 0.5) * 0.8) / 5
      tuft(e * 0.2, H - 0.035, z, e * 0.6, 0.45, i % 2 == 0 and 0.9 or -0.9, hash(i, 49 + e) < 0.3 and 2 or 1, 0.13)
    end
    for i = 1, 4 do
      local z = -0.4 + 0.8 * (i - 0.5 + (hash(i, 52 + e) - 0.5) * 0.8) / 4
      tuft(e * (hw - 0.035), 0.1 + 0.24 * hash(i, 55 + e), z, e * 0.55, 0.1, i % 2 == 0 and -1 or 1, 1, 0.13)
    end
  end
  -- ... and a few standing up off the top.
  for i = 1, 3 do
    tuft((hash(i, 60) - 0.5) * 0.2, H - 0.035, -0.3 + 0.3 * (i - 1) + (hash(i, 61) - 0.5) * 0.1,
      (hash(i, 62) - 0.5) * 0.8, 0.6, i % 2 == 0 and 0.8 or -0.8, 1, 0.12)
  end
  emit(combine(pieces), {name="hay_bale", material=PAINT})
end

-- A stack of old tyres for the chicanes: three car tyres lying flat one on another, none quite square on the one
-- under it, the top one painted with a red-and-white band as a circuit's are; 0.68 across, 0.6 high, standing on its
-- origin. (The game collides it as an upright cylinder, 0.34 round.)
do
  local R0, R1, T = 0.17, 0.34, 0.2
  -- A tyre's section: a rounded box from R0 to R1 out, T high -- its outer wall bulging, its inner lip tight.
  local function section()
    local pts = {}
    local n = 20
    local cx, a, b = (R0 + R1) / 2, (R1 - R0) / 2, T / 2
    for i = 0, n - 1 do
      local t = 2 * math.pi * (i + 0.5) / n
      local c, s = math.cos(t), math.sin(t)
      local e = 0.45
      pts[#pts + 1] = v2(cx + a * (c < 0 and -1 or 1) * math.abs(c) ^ e, b * (s < 0 and -1 or 1) * math.abs(s) ^ e)
    end
    return poly{points=pts}
  end
  local rubber, worn = v3(0.05, 0.05, 0.055), v3(0.1, 0.1, 0.11)
  local function tyre(seed)
    local m = revolve(section(), {segments=36})
    m = paint(m, rubber)
    -- Its tread round the outside, in blocks.
    m = paint_where(m, worn, function(c, nn)
      local r = math.sqrt(c.x * c.x + c.z * c.z)
      if r < R1 - 0.03 then return false end
      return math.floor((math.atan(c.z, c.x) + math.pi) / (2 * math.pi) * 36 + (c.y > 0 and 0.5 or 0)) % 2 == 0
    end)
    return m
  end
  -- The top one's sidewall painted, red and white blocks round it.
  local function banded(m)
    m = paint_where(m, v3(0.85, 0.06, 0.04), function(c, nn)
      local r = math.sqrt(c.x * c.x + c.z * c.z)
      return r > R0 + 0.03 and r < R1 - 0.02 and math.floor((math.atan(c.z, c.x) + math.pi) / (2 * math.pi) * 8) % 2 == 0
    end)
    return paint_where(m, v3(0.95, 0.95, 0.93), function(c, nn)
      local r = math.sqrt(c.x * c.x + c.z * c.z)
      return r > R0 + 0.03 and r < R1 - 0.02 and math.floor((math.atan(c.z, c.x) + math.pi) / (2 * math.pi) * 8) % 2 == 1
    end)
  end
  -- One tyre alone, lying flat about its middle (the game stacks three, each a body of its own, knocked about
  -- separately): plain, and the banded top one.
  emit(tyre(0), {name="tyre", material=PAINT})
  emit(banded(tyre(2)), {name="tyre_top", material=PAINT})
  local pieces = {}
  local offs = {{0, 0, 0}, {0.025, -0.015, 7}, {-0.02, 0.02, -5}}
  for k = 0, 2 do
    local o = offs[k + 1]
    local m = tyre(k)
    if k == 2 then m = banded(m) end
    m = rotate(m, {angle=o[3], axis=axis_y(), pivot=origin()})
    m = rotate(m, {angle=(k == 1) and 2.5 or 0, axis=axis_x(), pivot=origin()})
    pieces[#pieces + 1] = translate(m, v3(o[1], T / 2 + k * (T - 0.004), o[2]))
  end
  emit(combine(pieces), {name="tyre_stack", material=PAINT})
end

-- The bonus: a plain, chunky yellow star, its bevelled rim a deeper gold, about 0.9 m across, standing upright about
-- its middle and facing +z, glowing a little of itself so it reads from far off (src/game/systems/bonus.ts spins it and
-- bobs it). Colours on the vertices.
do
  local YELLOW, GOLD = v3(1.0, 0.82, 0.06), v3(1.0, 0.58, 0.02)
  local GLOW = material{name="Bonus", base_color=v3(1, 1, 1), emissive=v3(0.4, 0.32, 0.02), roughness=0.35, metallic=0.1}
  local pts = {}
  for i = 0, 9 do
    local a = math.rad(90 + i * 36)
    local r = (i % 2 == 0) and 0.45 or 0.2
    pts[#pts + 1] = v2(math.cos(a) * r, math.sin(a) * r)
  end
  local star = extrude(poly{points=pts}, {distance=0.16})
  star = rotate(star, {angle=90, axis=axis_x(), pivot=origin()})
  star = translate(star, v3(0, 0, -0.08))  -- centred on z = 0
  star = bevel(star, {edges=convex_edges(star), width=0.035, segments=2})
  star = paint(star, YELLOW)
  star = paint_where(star, GOLD, function(c, n) return math.abs(n.z) < 0.5 end)
  emit(smooth_normals(star, {angle=40}), {name="bonus", material=GLOW})
end

-- The bone rattler: corrugations across the road, a washboard of low timber ridges bolted to a thin mat -- 1 m wide
-- (the game stretches it across the road), 8 m long along +z, each ridge 7 cm high and rounded on top, 0.4 m apart,
-- painted yellow and black by turns so it reads from far up the hill. It shakes a kart hard at speed (it collides as
-- drawn): loose wheels and bodywork come off on it.
do
  local L, PITCH, H = 8, 0.4, 0.07
  local pieces = {paint(bx(1, 0.02, L, 0, 0.01, 0), shade(beam, 0.8))}
  local n = math.floor(L / PITCH)
  for i = 0, n - 1 do
    local z = -L / 2 + PITCH * (i + 0.5)
    local ridge = rbox(1, H, 0.16, 0.025, 0, H / 2, z)
    pieces[#pieces + 1] = paint(ridge, (i % 2 == 0) and stripe_a or stripe_b)
  end
  emit(combine(pieces), {name="rattler", material=PAINT})
end

-- The stair set: a plank ramp up from the road to a deck 0.75 m high, then five steps straight back down to it -- 1 m
-- wide (the game stretches it across the road), 11 m long along +z, its foot at z = -5.5. Every step a hard drop on the
-- wheels: it collides as drawn (src/game/course.ts' STAIRS).
do
  local pieces = {}
  local L, UP, DECK, STEPS, TREAD = 11, 0.75, 1.5, 5, 0.7
  local z0 = -L / 2
  local up_len = L - DECK - STEPS * TREAD
  -- The ramp up: a wedge of planks.
  local ramp = polyhedron{
    vertices={v3(-0.5, 0, z0), v3(0.5, 0, z0), v3(0.5, 0, z0 + up_len), v3(-0.5, 0, z0 + up_len), v3(-0.5, UP, z0 + up_len), v3(0.5, UP, z0 + up_len)},
    faces={{1, 4, 3, 2}, {1, 2, 6, 5}, {4, 5, 6, 3}, {1, 5, 4}, {2, 3, 6}},
  }
  pieces[#pieces + 1] = paint(ramp, plies[1])
  pieces[#pieces + 1] = paint(bx(1, UP, DECK, 0, UP / 2, z0 + up_len + DECK / 2), plies[2])
  for k = 1, STEPS do
    local h = UP - k * (UP / (STEPS + 1))
    local z = z0 + up_len + DECK + (k - 0.5) * TREAD
    pieces[#pieces + 1] = paint(bx(1, h, TREAD, 0, h / 2, z), plies[(k % 4) + 1])
    -- A yellow nose on each step, so they read from up the hill.
    pieces[#pieces + 1] = paint(bx(1.002, 0.03, 0.06, 0, h - 0.014, z - TREAD / 2 + 0.03), stripe_a)
  end
  pieces[#pieces + 1] = paint(bx(1.002, 0.03, 0.06, 0, UP - 0.014, z0 + up_len + 0.03), stripe_a)
  emit(combine(pieces), {name="stairs", material=PAINT, open=true})
end

-- The gravel trap: a bed of loose stones laid over the road, 8 m wide, 14 m long along +z, a few centimetres deep --
-- speckled greys and browns, a scatter of bigger pebbles on top. Only the look: its drag is the game's
-- (src/game/courses.ts' surfaces). Not collided.
do
  local W, L = 8, 14
  local stones = {v3(0.42, 0.4, 0.37), v3(0.5, 0.46, 0.4), v3(0.35, 0.32, 0.28), v3(0.55, 0.52, 0.48), v3(0.45, 0.38, 0.3)}
  -- The bed in metre cells, each its own stones' tone.
  local cells = {}
  for i = 0, W - 1 do
    for j = 0, L - 1 do
      local h = math.sin(i * 12.9898 + j * 78.233) * 43758.5453
      h = h - math.floor(h)
      cells[#cells + 1] = paint(bx(1, 0.04, 1, -W / 2 + i + 0.5, 0.02, -L / 2 + j + 0.5), stones[math.floor(h * #stones) + 1])
    end
  end
  local bed = combine(cells)
  local pieces = {bed}
  for i = 1, 70 do
    local a = math.sin(i * 3.1) * 0.5 + 0.5
    local b = math.sin(i * 7.7 + 1) * 0.5 + 0.5
    local r = 0.05 + (math.sin(i * 1.3) * 0.5 + 0.5) * 0.06
    local pebble = scale(sphere{radius=1, segments=6, rings=4}, {factor=v3(r, r * 0.6, r * 1.2), pivot=origin()})
    pieces[#pieces + 1] = paint(translate(pebble, v3((a - 0.5) * (W - 0.4), 0.03, (b - 0.5) * (L - 0.4))), stones[(i % #stones) + 1])
  end
  emit(combine(pieces), {name="gravel", material=PAINT, open=true})
end

-- The foam section and car wash: 8 m wide, 18 m long along +z -- a gantry over the road at its start (two posts and a
-- beam 4.5 m up, striped, with foam cannons) and long soapy drapes hanging from it, then the road buried in heaped
-- white suds up past a driver's head, thinning out toward the end. Only the look: the kart drives through it (its
-- slick soapy road is the game's, src/game/courses.ts' surfaces). Not collided.
do
  local W, L = 8, 18
  local FOAM = {v3(0.97, 0.97, 0.98), v3(0.9, 0.93, 0.98), v3(0.95, 0.9, 0.97)}
  local pieces = {}
  -- The gantry.
  -- Rounded steel posts banded in hazard yellow and black at the foot, on concrete pads; a blue beam with a white
  -- trim line along it; foam cannons with chrome nozzles.
  for side = -1, 1, 2 do
    local x = side * (W / 2 + 0.4)
    local post = rbox(0.3, 4.8, 0.3, 0.03, x, 2.4, -L / 2)
    for _, y in ipairs({0.3, 0.6, 0.9, 1.2}) do post = knife(post, {normal=axis_y(), point=v3(0, y, 0)}) end
    post = paint(post, hazard_red)
    post = paint_where(post, stripe_a, function(c, nn) return c.y < 1.2 and math.floor(c.y / 0.3) % 2 == 0 end)
    post = paint_where(post, stripe_b, function(c, nn) return c.y < 1.2 and math.floor(c.y / 0.3) % 2 == 1 end)
    pieces[#pieces + 1] = post
    pieces[#pieces + 1] = paint(rbox(0.5, 0.12, 0.5, 0.03, x, 0.06, -L / 2), v3(0.55, 0.55, 0.53))
  end
  pieces[#pieces + 1] = paint(rbox(W + 1.1, 0.5, 0.4, 0.04, 0, 4.7, -L / 2), side_paint.ramp)
  pieces[#pieces + 1] = paint(bx(W + 0.9, 0.06, 0.42, 0, 4.65, -L / 2), hazard_white)
  for k = -3, 3 do
    pieces[#pieces + 1] = paint(translate(cylinder{radius=0.12, height=0.5, segments=12, axis="z"}, v3(k * 1.1, 4.35, -L / 2 + 0.3)), v3(0.2, 0.2, 0.22))
    pieces[#pieces + 1] = paint(translate(cylinder{radius=0.07, height=0.08, segments=12, axis="z"}, v3(k * 1.1, 4.35, -L / 2 + 0.59)), v3(0.85, 0.86, 0.9))
  end
  -- The drapes: thin strips hanging from the beam, blue and white by turns.
  for k = 0, 15 do
    local x = -W / 2 + 0.25 + k * (W - 0.5) / 15
    pieces[#pieces + 1] = paint(bx(0.4, 3.2, 0.02, x, 2.85, -L / 2 + 0.15), (k % 2 == 0) and v3(0.1, 0.35, 0.85) or v3(0.92, 0.92, 0.95))
  end
  emit(combine(pieces), {name="foam", material=PAINT, open=true})
  -- The suds: heaps of round bubbles -- each heap a few soft balls of different sizes -- densest and highest after the
  -- gantry, thinning toward the end. Smooth all over (never faceted), in a soft, faintly blue-white satin of their own.
  local SUDS = material{name="Suds", base_color=v3(0.94, 0.96, 1.0), emissive=v3(0.18, 0.19, 0.22), roughness=0.35, metallic=0}
  local suds = {}
  for i = 1, 60 do
    local a = math.sin(i * 12.9898) * 0.5 + 0.5
    local b = math.sin(i * 4.1414 + 2.0) * 0.5 + 0.5
    local z = -L / 2 + 0.6 + b * (L - 1.2)
    local tall = 1 - 0.6 * (z + L / 2) / L
    local x = (a - 0.5) * (W - 0.8)
    local r = (0.45 + (math.sin(i * 2.3) * 0.5 + 0.5) * 0.5) * tall
    for k = 0, 2 do
      local ang = i * 1.7 + k * 2.1
      local rr = r * (k == 0 and 1 or 0.62)
      local off = k == 0 and v3(0, 0, 0) or v3(math.cos(ang) * r * 0.75, rr * 0.2, math.sin(ang) * r * 0.75)
      local ball = sphere{radius=rr, segments=14, rings=9}
      suds[#suds + 1] = {mesh=smooth_normals(translate(ball, v3(x, rr * 0.55, z) + off), {angle=89}), material=SUDS}
    end
  end
  emit(merge({parts=suds})[1].mesh, {name="foam_suds", material=SUDS, open=true})

end

-- The disco tunnel: a closed tunnel over the road, 24 m long along +z, 11 m wide inside (it stands outside the walls),
-- 5 m high -- black inside, a mirror ball in the middle -- and two sets of coloured lights down its walls and ceiling
-- (tunnel_lights_a, tunnel_lights_b), glowing: the game flashes them by turns (src/game/systems/disco.ts). Not collided.
do
  local L, HW_, H, T = 24, 5.5, 5, 0.3
  local DARK = v3(0.03, 0.03, 0.05)
  local shell = {}
  for side = -1, 1, 2 do
    shell[#shell + 1] = paint(bx(T, H, L, side * (HW_ + T / 2), H / 2 - 0.6, 0), DARK)
  end
  shell[#shell + 1] = paint(bx(2 * HW_ + 2 * T, T, L, 0, H - 0.6 + T / 2, 0), DARK)
  -- The mouths: a striped frame round each end, so it reads from up the hill.
  for e = -1, 1, 2 do
    local z = e * (L / 2)
    for k = 0, 9 do
      local c = (k % 2 == 0) and v3(0.9, 0.1, 0.6) or v3(0.1, 0.8, 0.9)
      shell[#shell + 1] = paint(bx(0.6, 0.6, 0.35, -HW_ - T + 0.3 + k * (2 * HW_ + 2 * T - 0.6) / 9, H - 0.3, z), c)
    end
    for side = -1, 1, 2 do shell[#shell + 1] = paint(bx(0.6, H, 0.35, side * (HW_ + T - 0.3), H / 2 - 0.6, z), v3(0.95, 0.85, 0.1)) end
  end
  shell[#shell + 1] = paint(translate(sphere{radius=0.45, segments=14, rings=8}, v3(0, H - 1.4, 0)), v3(0.8, 0.82, 0.85))
  shell[#shell + 1] = paint(bx(0.04, 0.8, 0.04, 0, H - 0.75, 0), v3(0.2, 0.2, 0.2))
  emit(combine(shell), {name="tunnel", material=PAINT, open=true})
  -- The lights: square lamps down both walls and across the ceiling, the two sets interleaved.
  for set = 0, 1 do
    local colours = set == 0 and {v3(1, 0.1, 0.5), v3(0.2, 0.4, 1)} or {v3(0.1, 1, 0.4), v3(1, 0.8, 0.1)}
    local lamps = {}
    local n = 0
    for k = 0, 11 do
      if k % 2 == set then
        local z = -L / 2 + 1 + k * (L - 2) / 11
        n = n + 1
        local c = colours[(n % 2) + 1]
        for side = -1, 1, 2 do lamps[#lamps + 1] = paint(bx(0.06, 0.5, 0.5, side * (HW_ - 0.03), 2.6, z), c) end
        for q = -2, 2 do lamps[#lamps + 1] = paint(bx(0.5, 0.06, 0.5, q * 2, H - 0.6 - 0.03, z), c) end
      end
    end
    local GLOW = material{name="Disco " .. set, base_color=v3(1, 1, 1), emissive=v3(1, 1, 1), roughness=0.4, metallic=0}
    local parts = {}
    for _, p in ipairs(lamps) do parts[#parts + 1] = {mesh=p, material=GLOW} end
    emit(merge({parts=parts})[1].mesh, {name="tunnel_lights_" .. (set == 0 and "a" or "b"), material=GLOW, open=true})
  end
end

-- A folding deck chair for a pensioner in the crowd (src/game/systems/course.ts sets it under one; crowd.ts sits
-- them in it): a striped canvas seat about 0.34 m up, its back leaning behind, on a tubular frame. Facing +z, the
-- seat's middle over the origin.
do
  local TUBE, CANVAS_A, CANVAS_B = v3(0.6, 0.6, 0.62), v3(0.1, 0.45, 0.2), v3(0.92, 0.92, 0.88)
  local pieces = {}
  -- The seat: canvas slats across, green and white by turns.
  for i = 0, 5 do
    pieces[#pieces + 1] = paint(bx(0.44, 0.02, 0.066, 0, 0.33, -0.14 + i * 0.07), i % 2 == 0 and CANVAS_A or CANVAS_B)
  end
  -- The back: a canvas sheet leaning back from the seat's rear edge.
  for i = 0, 5 do
    local back = bx(0.44, 0.075, 0.018, 0, 0.38 + i * 0.075, 0)
    back = rotate(back, {angle=-12, axis=axis_x(), pivot=v3(0, 0.34, 0)})
    pieces[#pieces + 1] = paint(translate(back, v3(0, 0, -0.2)), i % 2 == 0 and CANVAS_A or CANVAS_B)
  end
  -- The frame: round aluminium tube -- legs on rubber feet, rails along the seat's sides and up the back, a crossbar
  -- under the seat (no armrests: the pensioner's arms hang over its sides).
  local function tubey(h, x, y, z) return translate(cylinder{radius=0.012, height=h, segments=8}, v3(x, y, z)) end
  local function tubez(l, x, y, z) return translate(cylinder{radius=0.012, height=l, segments=8, axis="z"}, v3(x, y, z)) end
  local FEET = v3(0.04, 0.04, 0.045)
  for side = -1, 1, 2 do
    local x = side * 0.23
    pieces[#pieces + 1] = paint(tubey(0.32, x, 0.17, 0.2), TUBE)
    pieces[#pieces + 1] = paint(tubey(0.32, x, 0.17, -0.18), TUBE)
    pieces[#pieces + 1] = paint(tubez(0.43, x, 0.33, 0.01), TUBE)
    pieces[#pieces + 1] = paint(translate(rotate(tubey(0.5, x, 0.6, 0), {angle=-12, axis=axis_x(), pivot=v3(0, 0.34, 0)}), v3(0, 0, -0.2)), TUBE)
    for _, z in ipairs({0.2, -0.18}) do
      pieces[#pieces + 1] = paint(translate(cylinder{radius=0.016, height=0.014, segments=8}, v3(x, 0.007, z)), FEET)
    end
  end
  pieces[#pieces + 1] = paint(translate(cylinder{radius=0.011, height=0.44, segments=8, axis="x"}, v3(0, 0.1, 0.2)), TUBE)
  emit(combine(pieces), {name="folding_chair", material=PAINT, open=true})
end
