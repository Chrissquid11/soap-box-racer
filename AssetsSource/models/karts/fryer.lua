-- Air Fryer Force One: a giant glossy-black air fryer up front, the driver sat low in its pulled-out basket among the
-- chips, the whole appliance riding on its own kitchen undercarriage -- a glossy black plinth with chrome tube rails
-- and an orange underglow, rubber appliance feet, the fryer's heating element glowing beneath it, chrome axles
-- through black brackets capped with oven-dial hubs, and a coiled power cord trailing out the back to its plug.
-- One part, "fryer", drawn with Render.model "karts/fryer#fryer".
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- driver's hips at (0, -0.21, -0.25), so the cockpit keeps clear of x ±0.28, z -0.5..0.45 above y -0.2; the wheels
-- (another slot) sit at x ±0.5, z ±0.7, y -0.42, radius 0.18. Colours are painted on the vertices, one white material.
local prm = params{
  chips  = {default=24, min=12, max=36, integer=true, doc="Chips piled along the basket's sides"},
  coils  = {default=9, min=4, max=14, integer=true, doc="Turns of the coiled power cord"},
  cord   = {default=0.42, min=0.25, max=0.6, doc="How far the power cord trails behind, metres"},
}

local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.45, metallic=0.05}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
-- A part of pieces, each { mesh, colour } or { mesh } already painted: merged into one mesh with its colours on its
-- vertices (merge, not join, which drops them), every piece's normals smoothed alike first.
local function part(name, pieces)
  local out = {}
  for i, p in ipairs(pieces) do
    local m = p[2] and paint(p[1], p[2]) or p[1]
    out[i] = {mesh=smooth_normals(m, {angle=40}), material=PAINT}
  end
  local merged = merge({parts=out, mode="compatible"})
  emit(merged[1].mesh, {name=name, material=merged[1].material})
  -- Its signature piece (sig=true): its own part, `<name>_sig` (_sig.lua), and left out of the wreck.
  local rest = include("_sig.lua").split(name, out, function(i) return pieces[i].sig end)
  -- Its wreck, as the same pieces broken: what stays on the kart when the bodywork is knocked off (_wreck.lua).
  include("_wreck.lua").emit(name, rest)
end
local function C(r, g, b) return v3(r, g, b) end

local function at(m, x, y, z) return translate(m, v3(x, y, z)) end
local function bx(sx, sy, sz, x, y, z) return at(box{size=v3(sx, sy, sz)}, x, y, z) end
-- A box with its edges bevelled.
local function rb(sx, sy, sz, x, y, z, w, seg)
  local m = box{size=v3(sx, sy, sz)}
  return at(bevel(m, {edges=convex_edges(m), width=w or math.min(sx, sy, sz) * 0.2, segments=seg or 1}), x, y, z)
end
-- A box with its corners rounded about y, its base at y; `soft` rounds its top and bottom rims too.
local function rbox(w, h, d, r, x, y, z, soft)
  local m = extrude(rounded_rect{w=w, h=d, radius=r, segments=4}, {distance=h})
  if soft then
    local edge = 2 * r * math.sin(math.pi / 16)
    for _, side in ipairs({w - 2 * r, d - 2 * r}) do if side > 0.001 then edge = math.min(edge, side) end end
    m = bevel(m, {edges=convex_edges(m, {min_angle=60}), width=math.min(soft, edge * 0.4, h * 0.22), segments=2})
  end
  return at(m, x, y, z)
end
-- An ellipsoid: a sphere scaled to its three radii.
local function ball(rx, ry, rz, x, y, z, seg)
  local s = seg or 12
  return at(scale(sphere{radius=1, segments=s, rings=math.floor(s / 2)}, {factor=v3(rx, ry, rz), pivot=origin()}), x, y, z)
end
local function cyl(r, h, x, y, z, axis, seg) return at(cylinder{radius=r, height=h, segments=seg or 14, axis=axis or "y"}, x, y, z) end
-- A round rod from a to b, a hair short of each (two rods meeting end to end must not share a vertex).
local function rod(a0, b0, r, seg)
  local a = lerp(a0, b0, 0.004)
  local b = lerp(a0, b0, 0.996)
  local d = b - a
  local up = v3(0, 1, 0)
  local m = cylinder{radius=r, height=length(d), segments=seg or 8}
  local dir = normalize(d)
  local c = dot(up, dir)
  if c < -0.9999 then m = rotate(m, {angle=180, axis=axis_x(), pivot=origin()})
  elseif c < 0.9999 then m = rotate(m, {angle=deg(math.acos(c)), axis=normalize(cross(up, dir)), pivot=origin()}) end
  return translate(m, (a + b) * 0.5)
end
-- A tube along points, round, capped; `taper` the end's share of the start's radius.
local function tube(pts, r, seg, taper)
  return sweep(circle{radius=r, segments=seg or 8}, path{points=pts}, {caps=true, scale=taper or 1})
end
-- A mesh turned about an axis through its own middle, then moved.
local function turn(m, angle, axis, x, y, z) return at(rotate(m, {angle=angle, axis=axis, pivot=origin()}), x, y, z) end
-- A solid of revolution about +y from { radius, height } pairs, counter-clockwise.
local function lathe(pts, seg)
  local ps = {}
  for i, p in ipairs(pts) do ps[i] = v2(p[1], p[2]) end
  return revolve(poly{points=ps}, {segments=seg or 24})
end
-- A curve: n + 1 points of fn(t), t from 0 to 1.
local function curve(n, fn)
  local pts = {}
  for i = 0, n do pts[#pts + 1] = fn(i / n) end
  return pts
end

local black  = C(0.04, 0.04, 0.05)
local dark   = C(0.14, 0.14, 0.16)
local chrome = C(0.92, 0.93, 0.96)
local white  = C(0.96, 0.96, 0.94)
local red    = C(0.88, 0.1, 0.07)
local green  = C(0.3, 0.8, 0.28)
local orange = C(1.0, 0.45, 0.05)
local brass  = C(0.85, 0.66, 0.25)
local gloss  = C(0.07, 0.07, 0.08)
local rubber = C(0.025, 0.025, 0.03)

local p = {}

-- The fryer itself, up front ----------------------------------------------------------------------------------------
-- A tall glossy black rounded box standing on the plinth, its control panel on top, its basket's dark mouth facing
-- the driver (whose feet go into it).
p[#p + 1] = {rbox(0.84, 0.8, 0.48, 0.12, 0, -0.3, 0.69, 0.02), gloss}
p[#p + 1] = {rbox(0.72, 0.03, 0.34, 0.08, 0, 0.498, 0.69), dark}
-- The display, its temperature in orange; the big chrome dial with a red pointer; the buttons.
p[#p + 1] = {rb(0.26, 0.016, 0.11, 0, 0.532, 0.62, 0.004), C(0.04, 0.08, 0.12)}
for i = 0, 2 do p[#p + 1] = {bx(0.045, 0.006, 0.065, -0.07 + i * 0.07, 0.542, 0.62), orange} end
p[#p + 1] = {at(lathe({{0.004, 0}, {0.065, 0}, {0.06, 0.03}, {0.045, 0.045}, {0.004, 0.045}}, 24), 0.24, 0.526, 0.73), chrome}
p[#p + 1] = {rb(0.012, 0.012, 0.05, 0.24, 0.575, 0.75, 0.003), red}
p[#p + 1] = {cyl(0.028, 0.03, -0.24, 0.53, 0.62, "y", 14), red}
p[#p + 1] = {cyl(0.028, 0.03, -0.24, 0.53, 0.74, "y", 14), green}
p[#p + 1] = {cyl(0.016, 0.03, -0.16, 0.53, 0.74, "y", 10), C(0.2, 0.6, 1.0)}
-- The mouth, and the chrome trim round it.
p[#p + 1] = {bx(0.66, 0.42, 0.02, 0, -0.04, 0.444), C(0.02, 0.02, 0.025)}
p[#p + 1] = {rb(0.7, 0.025, 0.03, 0, 0.185, 0.445, 0.008), chrome}
p[#p + 1] = {rb(0.7, 0.025, 0.03, 0, -0.265, 0.445, 0.008), chrome}
-- Vents up the front, and its badge.
for i = 0, 5 do p[#p + 1] = {rb(0.5, 0.025, 0.014, 0, -0.15 + i * 0.07, 0.935, 0.005), dark} end
p[#p + 1] = {ball(0.12, 0.04, 0.012, 0, 0.36, 0.932, 18), chrome}
p[#p + 1] = {ball(0.1, 0.028, 0.012, 0, 0.36, 0.936, 18), red}
-- The steering column: out of the fryer's mouth up to the wheel, a chrome collar where it goes in.
p[#p + 1] = {rod(v3(0, 0.02, 0.45), v3(0, 0.115, 0.16), 0.018, 10), dark}
p[#p + 1] = {turn(cylinder{radius=0.032, height=0.03, segments=14}, 90, axis_x(), 0, 0.02, 0.44), chrome}

-- The basket, pulled out round the driver -----------------------------------------------------------------------------
-- Sat low on the plinth: grey walls behind a mesh of darker bars, a lip, a mesh floor, a long handle behind.
local basket = C(0.6, 0.62, 0.66)
local sig0 = #p + 1
p[#p + 1] = {rb(0.04, 0.3, 1.02, 0.34, -0.15, -0.1, 0.01), basket}
p[#p + 1] = {rb(0.04, 0.3, 1.02, -0.34, -0.15, -0.1, 0.01), basket}
p[#p + 1] = {rb(0.72, 0.3, 0.04, 0, -0.15, -0.62, 0.01), basket}
p[#p + 1] = {rb(0.06, 0.03, 1.06, 0.34, 0.015, -0.1, 0.01), dark}
p[#p + 1] = {rb(0.06, 0.03, 1.06, -0.34, 0.015, -0.1, 0.01), dark}
p[#p + 1] = {rb(0.76, 0.03, 0.06, 0, 0.015, -0.62, 0.01), dark}
p[#p + 1] = {bx(0.64, 0.02, 1.0, 0, -0.292, -0.1), dark}
for i = 0, 3 do
  local y = -0.27 + i * 0.075
  p[#p + 1] = {bx(0.012, 0.016, 1.0, 0.362, y, -0.1), dark}
  p[#p + 1] = {bx(0.012, 0.016, 1.0, -0.362, y, -0.1), dark}
  p[#p + 1] = {bx(0.7, 0.016, 0.012, 0, y, -0.642), dark}
end
for i = 0, 9 do
  local z = -0.58 + i * 0.105
  p[#p + 1] = {bx(0.01, 0.27, 0.014, 0.366, -0.15, z), dark}
  p[#p + 1] = {bx(0.01, 0.27, 0.014, -0.366, -0.15, z), dark}
end
for i = 0, 5 do p[#p + 1] = {bx(0.014, 0.27, 0.01, -0.29 + i * 0.116, -0.15, -0.646), dark} end
p[#p + 1] = {rod(v3(0, -0.07, -0.64), v3(0, 0.05, -0.92), 0.03, 10), black}
p[#p + 1] = {rbox(0.34, 0.08, 0.1, 0.035, 0, 0.01, -0.97, 0.012), red}
p[#p + 1] = {cyl(0.02, 0.012, 0, 0.095, -0.97, "y", 10), chrome}
for i = sig0, #p do p[i].sig = true end
-- The seat: a red silicone cushion under the hips and a padded back against the basket's back wall.
local silicone = C(0.82, 0.12, 0.1)
p[#p + 1] = {rbox(0.42, 0.07, 0.42, 0.06, 0, -0.29, -0.27, 0.02), silicone}
p[#p + 1] = {rbox(0.44, 0.4, 0.08, 0.03, 0, -0.26, -0.56, 0.015), silicone}
-- Golden oil running down the basket's sides.
for i = 0, 5 do
  local side = (i % 2 == 0) and 1 or -1
  local z = -0.5 + i * 0.16
  local y = -0.23 + (i % 3) * 0.03
  p[#p + 1] = {ball(0.008, 0.05, 0.016, side * 0.37, y, z, 10), C(0.95, 0.62, 0.08)}
  p[#p + 1] = {ball(0.012, 0.016, 0.016, side * 0.371, y - 0.05, z, 8), C(0.95, 0.62, 0.08)}
end
-- The chips, piled along the basket's sides either side of the driver: no two the same gold, a blob of ketchup.
local rows = math.ceil(prm.chips / 2)
local step = 0.94 / math.max(1, rows - 1)
for i = 0, prm.chips - 1 do
  local side = (i % 2 == 0) and 1 or -1
  local z = -0.56 + math.floor(i / 2) * step
  local y = -0.06 + ((i * 37) % 5) * 0.022
  local tone = 0.5 + 0.5 * noise3(i * 0.71, 0.3, 1.1)
  local col = lerp(C(1.0, 0.85, 0.35), C(0.88, 0.55, 0.12), tone)
  local chip = rb(0.036, 0.036, 0.18 + (i % 3) * 0.02, 0, 0, 0, 0.007)
  chip = rotate(chip, {angle=25 + (i * 53) % 70, axis=normalize(v3(1, (i % 3) - 1, 0.4)), pivot=origin()})
  p[#p + 1] = {at(chip, side * (0.29 + (i % 3) * 0.012), y, z), col}
end
p[#p + 1] = {ball(0.05, 0.03, 0.06, 0.3, 0.05, -0.1, 14), C(0.8, 0.05, 0.04)}
p[#p + 1] = {ball(0.03, 0.025, 0.035, 0.3, 0.08, -0.1, 10), C(0.85, 0.08, 0.05)}

-- The undercarriage: the appliance's own base ---------------------------------------------------------------------
-- A glossy black plinth the whole length of the kart, an orange underglow strip along each flank.
p[#p + 1] = {rbox(0.8, 0.085, 1.82, 0.09, 0, -0.385, 0.01, 0.02), gloss}
p[#p + 1] = {rbox(0.74, 0.012, 1.76, 0.07, 0, -0.307, 0.01), dark}
for _, s in ipairs({1, -1}) do
  p[#p + 1] = {bx(0.008, 0.014, 1.5, s * 0.4, -0.345, 0.01), orange}
end
-- Chrome tube rails along each side, bent down into the plinth at each end and held up on posts.
for _, s in ipairs({1, -1}) do
  local x = s * 0.41
  local pts = {v3(x, -0.31, -0.87)}
  for k = 1, 5 do
    local a = (k / 5) * math.pi * 0.5
    pts[#pts + 1] = v3(x, -0.31 + 0.06 * math.sin(a), -0.87 + 0.04 * (1 - math.cos(a)) + 0.0)
  end
  pts[#pts + 1] = v3(x, -0.25, 0.36)
  for k = 1, 5 do
    local a = (k / 5) * math.pi * 0.5
    pts[#pts + 1] = v3(x, -0.25 - 0.06 * (1 - math.cos(a)), 0.36 + 0.04 * math.sin(a))
  end
  p[#p + 1] = {tube(pts, 0.012, 10), chrome}
  for _, z in ipairs({-0.4, 0.0}) do p[#p + 1] = {rod(v3(x, -0.32, z), v3(x, -0.252, z), 0.008, 8), chrome} end
end
-- Rubber appliance feet under it, between the wheels.
for _, s in ipairs({1, -1}) do
  for _, z in ipairs({-0.42, 0.0, 0.42}) do
    p[#p + 1] = {at(lathe({{0.004, 0}, {0.034, 0}, {0.044, 0.018}, {0.05, 0.05}, {0.004, 0.05}}, 16), s * 0.33, -0.433, z), rubber}
  end
end
-- The fryer's heating element, slung beneath, glowing: a zig-zag coil between two ceramic terminal blocks.
do
  local pts = {}
  local n = 9
  for k = 0, n do
    local z = -0.48 + k * (0.96 / n)
    local x = ((k % 2 == 0) and 1 or -1) * 0.2
    pts[#pts + 1] = v3(x * 0.85, -0.43, z)
    pts[#pts + 1] = v3(x, -0.43, z + 0.02)
  end
  p[#p + 1] = {tube(pts, 0.011, 8), C(1.0, 0.35, 0.04)}
  for _, z in ipairs({-0.52, 0.52}) do
    p[#p + 1] = {rb(0.46, 0.05, 0.05, 0, -0.43, z, 0.01), C(0.9, 0.88, 0.82)}
    p[#p + 1] = {rod(v3(0, -0.405, z), v3(0, -0.345, z), 0.012, 8), dark}
  end
end
-- The axles: chrome bars through black hanging brackets, reaching out into the wheel hubs, each end capped inside
-- the wheel with an oven dial -- black, knurled, a chrome ring and a white pointer.
for _, z in ipairs({0.7, -0.7}) do
  p[#p + 1] = {turn(cylinder{radius=0.024, height=0.94, segments=12}, 90, axis_z(), 0, -0.42, z), chrome}
  for _, s in ipairs({1, -1}) do
    p[#p + 1] = {rb(0.07, 0.12, 0.11, s * 0.29, -0.4, z, 0.015), black}
    p[#p + 1] = {turn(cylinder{radius=0.034, height=0.08, segments=14}, 90, axis_z(), s * 0.29, -0.42, z), chrome}
    local dial = turn(cylinder{radius=0.06, height=0.035, segments=20}, 90, axis_z(), s * 0.395, -0.42, z)
    p[#p + 1] = {dial, black}
    p[#p + 1] = {turn(torus{major_radius=0.06, minor_radius=0.006, major_segments=20, minor_segments=6, axis="x"}, 0, axis_x(), s * 0.413, -0.42, z), chrome}
    p[#p + 1] = {bx(0.006, 0.07, 0.012, s * 0.4155, -0.42, z), white}
  end
end
-- The power cord: out of a grommet in the plinth's back, coiled, trailing behind to a three-pin plug.
do
  local s = v3(0, -0.36, -0.93)
  local e = v3(0.07, -0.5, -0.93 - prm.cord)
  p[#p + 1] = {turn(cylinder{radius=0.03, height=0.03, segments=14}, 90, axis_x(), 0, -0.36, -0.915), dark}
  local d = normalize(e - s)
  local u = normalize(cross(d, v3(0, 1, 0)))
  local w = cross(u, d)
  local n = prm.coils * 14
  local pts = curve(n, function(t)
    local a = t * prm.coils * 2 * math.pi
    local rr = 0.03
    return lerp(s, e, t) + u * (rr * math.cos(a)) + w * (rr * math.sin(a))
  end)
  p[#p + 1] = {tube(pts, 0.009, 6), black}
  -- The plug, turned along the cord, its pins out the back.
  local plug = {}
  local function plugpiece(m, c) plug[#plug + 1] = {m, c} end
  plugpiece(rb(0.07, 0.05, 0.09, 0, 0, -0.045, 0.012), white)
  plugpiece(cyl(0.014, 0.03, 0, 0, 0.01, "z", 10), white)
  plugpiece(bx(0.008, 0.016, 0.04, 0.02, -0.008, -0.105), brass)
  plugpiece(bx(0.008, 0.016, 0.04, -0.02, -0.008, -0.105), brass)
  plugpiece(bx(0.016, 0.008, 0.045, 0, 0.015, -0.11), brass)
  local yaw = deg(math.atan(d.x, -d.z))
  local pitch = deg(math.asin(d.y))
  for _, q in ipairs(plug) do
    local m = rotate(q[1], {angle=pitch, axis=axis_x(), pivot=origin()})
    m = rotate(m, {angle=-yaw, axis=axis_y(), pivot=origin()})
    p[#p + 1] = {translate(m, e), q[2]}
  end
end

part("fryer", p)
