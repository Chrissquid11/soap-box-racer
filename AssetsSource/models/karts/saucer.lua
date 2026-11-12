-- Abduction Reduction, the whole kart: a B-movie flying saucer round the driver, home-made -- a silver disc with a
-- red ring, an inner-tube rim studded with lamps, a raised cabin ring with portholes and half a bubble dome for a
-- windscreen, planks, a rusty plate and tape over its holes, a telly aerial (its signature piece); two aliens up
-- through hatches in its front deck, a cow beamed up behind -- on its own undercarriage, a saucer's landing gear:
-- a plated belly with the tractor-beam emitter glowing beneath it, four hydraulic landing legs on round foot pads,
-- and the axle struts the wheels hang on.
--
-- About the middle of the kart's chassis top, facing +z, in the kart's own metres: the driver's hips at
-- (0, -0.21, -0.25). Its colours are its own, painted on the vertices, one white material.
local P = params{
  radius = { default = 0.82, min = 0.72, max = 0.95, doc = "The saucer's radius across, metres (it is 1.3 times that long)" },
  beam   = { default = 0.5, min = 0.3, max = 0.75, doc = "The tractor beam's height, metres" },
  lights = { default = 14, min = 8, max = 24, integer = true, doc = "Lights round the rim" },
}

local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.55, metallic=0}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
-- Faces of m for which fn(f) holds, painted c (none such: m as it was).
local function paint_if(m, c, fn)
  local sel = faces_where(m, fn)
  if set_count(sel) == 0 then return m end
  return paint_faces(m, {faces=sel, color=c})
end
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
  local sig = include("_sig.lua")
  local rest, sigbox = sig.split(name, out, function(i) return pieces[i].sig end)
  sig.box(name, sigbox)
  -- Its wreck, as the same pieces broken: what stays on the kart when the bodywork is knocked off (_wreck.lua).
  include("_wreck.lua").emit(name, rest)
end
local function many(list) return #list == 1 and list[1] or join(table.unpack(list)) end
local function C(r, g, b) return v3(r, g, b) end
local function shade(c, k) return v3(math.min(1, c.x * k), math.min(1, c.y * k), math.min(1, c.z * k)) end

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

-- The palette: brushed silver over a deep blue-grey belly, a red go-faster ring and seat, amber and cyan lamps, the
-- tractor glow, and the bodges -- plywood, a rusty plate, tape.
local black  = C(0.04, 0.04, 0.05)
local dark   = C(0.13, 0.14, 0.17)
local grey   = C(0.5, 0.52, 0.56)
local silver = C(0.74, 0.77, 0.82)
local bright = C(0.86, 0.88, 0.92)
local chrome = C(0.94, 0.95, 0.98)
local white  = C(0.96, 0.96, 0.94)
local wood   = C(0.76, 0.54, 0.28)
local rust   = C(0.74, 0.38, 0.18)
local tape   = C(0.62, 0.65, 0.66)
local yellow = C(1.0, 0.76, 0.14)
local red    = C(0.9, 0.2, 0.16)
local cabin  = C(0.3, 0.37, 0.52)
local glass  = C(0.56, 0.88, 0.95)

local tractor = C(0.25, 1.0, 0.85)
local hull    = C(0.3, 0.34, 0.44)

-- Abduction Reduction ------------------------------------------------------------------------------------------
do
  local p = {}
  local R = P.radius
  -- The saucer is an oval, stretched along z so its cockpit hole fits the driver (x ±0.37, z -0.51..0.45).
  local ZS, CZ = 1.3, -0.03
  local function oval(m) return at(scale(m, {factor=v3(1, 1, ZS), pivot=origin()}), 0, 0, CZ) end
  -- A point on the oval at angle a (0 the kart's left, a quarter turn its nose), radius r, height y.
  local function on(a, r, y) return v3(math.cos(a) * r, y, CZ + math.sin(a) * r * ZS) end
  -- The oval radius of a face's middle, and its angle.
  local function orad(c) local dz = (c.z - CZ) / ZS; return math.sqrt(c.x * c.x + dz * dz), math.atan(dz, c.x) end
  local function wedge(a, n) return math.floor((a + math.pi) / (2 * math.pi) * n) % 2 end

  -- The hull, one lathe: a dish beneath, a fat rim, a deck sloping up to the raised cabin ring round the cockpit.
  local k = R / 0.82
  local RC, RD = 0.52 * k, R - 0.03
  local function deckY(r) return 0.09 + (RD - r) / (RD - RC) * 0.085 end
  local slope = deg(math.atan(0.085 / (RD - RC)))
  local S1, S2 = 0.6 * k, 0.67 * k
  local lens = revolve(poly{points={v2(0.37, -0.2), v2(0.5 * k, -0.13), v2(0.6 * k, -0.085), v2(0.78 * k, -0.01),
    v2(R - 0.01, 0.0), v2(R, 0.015), v2(R, 0.075), v2(RD, 0.09), v2(S2, deckY(S2)), v2(S1, deckY(S1)),
    v2(RC, 0.175), v2(0.41, 0.27), v2(0.395, 0.285), v2(0.375, 0.285), v2(0.37, 0.27)}}, {segments=40})
  lens = paint(oval(lens), silver)
  -- The deck's plates, two silvers turn about; the red ring; the cabin ring; its chrome lip.
  lens = paint_if(lens, bright, function(f)
    local r, a = orad(f.center)
    return f.normal.y > 0.3 and r > RC and wedge(a, 8) == 0
  end)
  lens = paint_if(lens, red, function(f)
    local r = orad(f.center)
    return f.normal.y > 0.3 and r > S1 and r < S2
  end)
  lens = paint_if(lens, cabin, function(f)
    local r = orad(f.center)
    return f.normal.y > 0.2 and r < RC and r > 0.4 and f.center.y < 0.275
  end)
  lens = paint_if(lens, chrome, function(f) return f.center.y > 0.275 end)
  lens = paint_if(lens, dark, function(f)
    local r = orad(f.center)
    return r < 0.372 and math.abs(f.normal.y) < 0.3
  end)
  -- Beneath: hull plates in two blue-greys, a ring of tractor glow.
  lens = paint_if(lens, hull, function(f)
    local _, a = orad(f.center)
    return f.normal.y < -0.2 and wedge(a, 12) == 0
  end)
  lens = paint_if(lens, shade(hull, 1.3), function(f)
    local _, a = orad(f.center)
    return f.normal.y < -0.2 and wedge(a, 12) == 1
  end)
  lens = paint_if(lens, tractor, function(f)
    local r = orad(f.center)
    return f.normal.y < -0.2 and r > 0.5 * k and r < 0.6 * k
  end)
  p[#p + 1] = {lens}
  -- Its rim: a fat rubber hoop (an inner tube, by the look of it) studded with lamps, amber and cyan turn about.
  p[#p + 1] = {oval(at(torus{major_radius=R + 0.005, minor_radius=0.03, major_segments=36, minor_segments=5, axis="y"}, 0, 0.045, 0)), dark}
  for i = 0, P.lights - 1 do
    local q = on(i / P.lights * 2 * math.pi, R + 0.03, 0.045)
    p[#p + 1] = {ball(0.046, 0.046, 0.046, q.x, q.y, q.z, 8), i % 2 == 0 and yellow or C(0.3, 0.9, 1.0)}
  end
  -- Portholes round the cabin ring, lit amber; rivets round the deck's edge.
  for i = 0, 7 do
    local q = on((i + 0.5) / 8 * 2 * math.pi, (RC + 0.41) / 2 + 0.004, 0.2225)
    p[#p + 1] = {ball(0.036, 0.036, 0.036, q.x, q.y, q.z, 8), yellow}
  end
  for i = 0, 11 do
    local q = on((i + 0.5) / 12 * 2 * math.pi, 0.93 * RD, deckY(0.93 * RD) + 0.002)
    p[#p + 1] = {ball(0.016, 0.012, 0.016, q.x, q.y, q.z, 6), chrome}
  end
  -- Something lying on the deck at angle a, radius r: tilted to its slope, `lift` above it.
  local function ondeck(m, a, r, lift)
    m = rotate(m, {angle=-slope, axis=axis_z(), pivot=origin()})
    m = at(m, r, deckY(r) + (lift or 0), 0)
    return oval(rotate(m, {angle=-deg(a), axis=axis_y(), pivot=origin()}))
  end
  -- The bodges: two planks nailed over a hole, a rusty plate riveted on, a cross of tape.
  do
    local a, r = math.rad(215), 0.68 * k
    p[#p + 1] = {ondeck(bx(0.15, 0.014, 0.085, 0, 0, 0), a - 0.07, r, 0.005), wood}
    p[#p + 1] = {ondeck(bx(0.12, 0.014, 0.085, 0, 0, 0), a + 0.07, r - 0.01, 0.005), shade(wood, 0.85)}
    for _, n in ipairs({{-0.07, 0.055}, {-0.07, -0.055}, {0.07, 0.04}, {0.07, -0.04}}) do
      p[#p + 1] = {ondeck(bx(0.016, 0.008, 0.016, 0, 0, 0), a + n[1], r + n[2], 0.014), dark}
    end
    a = math.rad(-22)
    p[#p + 1] = {ondeck(bx(0.14, 0.01, 0.16, 0, 0, 0), a, r, 0.004), rust}
    for _, n in ipairs({{-0.085, 0.05}, {-0.085, -0.05}, {0.085, 0.05}, {0.085, -0.05}}) do
      p[#p + 1] = {ondeck(bx(0.016, 0.008, 0.016, 0, 0, 0), a + n[1], r + n[2], 0.01), chrome}
    end
    a = math.rad(170)
    p[#p + 1] = {ondeck(turn(box{size=v3(0.19, 0.006, 0.034)}, 38, axis_y(), 0, 0, 0), a, 0.7 * k, 0.003), tape}
    p[#p + 1] = {ondeck(turn(box{size=v3(0.19, 0.006, 0.034)}, -38, axis_y(), 0, 0, 0), a, 0.7 * k, 0.007), shade(tape, 1.12)}
  end
  -- Half a bubble dome left on the cabin's front as a windscreen (the rest went to the cow).
  do
    local m = revolve(poly{points={v2(0.392, 0.28), v2(0.365, 0.36), v2(0.295, 0.425), v2(0.2, 0.455),
      v2(0.192, 0.438), v2(0.283, 0.41), v2(0.348, 0.35), v2(0.374, 0.28)}}, {angle=110, segments=10})
    local c = bbox(m).center
    m = oval(rotate(m, {angle=-deg(math.pi / 2 - math.atan(c.z, c.x)), axis=axis_y(), pivot=origin()}))
    m = paint(m, glass)
    m = paint_if(m, C(0.86, 1.0, 1.0), function(f)
      local _, a = orad(f.center)
      return a > math.rad(100) and a < math.rad(123) and f.normal.y > 0.1
    end)
    p[#p + 1] = {m}
  end

  -- The undercarriage. The belly: a plated dish under the cockpit, its top the floor, its foot the tractor-beam
  -- emitter, glowing cyan.
  local belly = lathe({{0.004, -0.39}, {0.3, -0.39}, {0.38, -0.34}, {0.43, -0.26}, {0.44, -0.17}, {0.36, -0.17},
    {0.36, -0.23}, {0.004, -0.23}}, 30)
  belly = paint(oval(belly), hull)
  belly = paint_if(belly, shade(hull, 0.75), function(f)
    local _, a = orad(f.center)
    return f.normal.y < 0.9 and wedge(a, 10) == 0
  end)
  p[#p + 1] = {belly}
  p[#p + 1] = {cyl(0.27, 0.03, 0, -0.4, CZ, "y", 20), dark}
  p[#p + 1] = {cyl(0.22, 0.02, 0, -0.42, CZ, "y", 20), tractor}
  p[#p + 1] = {ball(0.12, 0.04, 0.12, 0, -0.43, CZ, 10), C(0.9, 1.0, 1.0)}
  -- The axle struts: a crossbar into each wheel's hub, two hydraulic struts up from it into the saucer, a rail
  -- either side between them under the belly.
  for _, z in ipairs({-0.7, 0.7}) do
    p[#p + 1] = {cyl(0.026, 0.94, 0, -0.42, z, "x", 8), grey}
    for _, s in ipairs({-1, 1}) do
      p[#p + 1] = {cyl(0.04, 0.05, s * 0.4, -0.42, z, "x", 10), dark}
      p[#p + 1] = {cyl(0.034, 0.18, s * 0.3, -0.33, z, "y", 8), dark}
      p[#p + 1] = {cyl(0.018, 0.2, s * 0.3, -0.15, z, "y", 6), chrome}
    end
  end
  for _, s in ipairs({-1, 1}) do
    p[#p + 1] = {bx(0.05, 0.05, 1.42, s * 0.3, -0.37, 0), dark}
  end
  -- The landing legs: four, a cross of them, each a dark hydraulic housing, a chrome piston, an amber knee collar
  -- and a round foot pad.
  local legs = {
    {v3(0, -0.03, 0.82 * k), v3(0, -0.5, 0.98 * k)},
    {v3(0, -0.03, -0.85 * k), v3(0, -0.5, -1.02 * k)},
    {v3(0.66 * k, -0.03, -0.03), v3(0.76 * k, -0.5, -0.03)},
    {v3(-0.66 * k, -0.03, -0.03), v3(-0.76 * k, -0.5, -0.03)},
  }
  for _, l in ipairs(legs) do
    local top, foot = l[1], l[2]
    local knee = lerp(top, foot, 0.55)
    p[#p + 1] = {rod(top, lerp(top, foot, 0.47), 0.036, 8), dark}
    p[#p + 1] = {rod(lerp(top, foot, 0.47), lerp(top, foot, 0.6), 0.046, 8), yellow}
    p[#p + 1] = {rod(lerp(top, foot, 0.6), foot + v3(0, 0.03, 0), 0.02, 6), chrome}
    p[#p + 1] = {cyl(0.08, 0.024, foot.x, foot.y, foot.z, "y", 12), grey}
    p[#p + 1] = {at(cone{radius=0.05, radius_top=0.022, height=0.035, segments=8}, foot.x, foot.y + 0.028, foot.z), dark}
    -- A brace from the knee back in to the belly.
    local d = v3(top.x, 0, top.z - CZ)
    local inner = v3(d.x * 0.5, -0.3, CZ + d.z * 0.5 * (math.abs(d.x) > 0.01 and 1 or 0.7))
    p[#p + 1] = {rod(knee, inner, 0.015, 6), grey}
  end

  -- The cockpit: a seat cushion under the hips, a padded back against the rear wall, the steering column.
  p[#p + 1] = {rb(0.46, 0.03, 0.4, 0, -0.235, -0.25, 0.01), red}
  p[#p + 1] = {rb(0.44, 0.56, 0.05, 0, 0.06, -0.53, 0.018), red}
  p[#p + 1] = {rod(v3(0, 0.1, 0.15), v3(0, -0.23, 0.38), 0.018, 8), dark}
  p[#p + 1] = {cyl(0.05, 0.015, 0, -0.225, 0.38, "y", 10), grey}

  -- An aerial at the back of the deck, bodged from a telly's: a mast, three rungs, a red lamp atop it.
  local ab = on(-math.pi * 0.62, 0.7 * k, 0.1)
  local lean = v3(0.04, 0.44, -0.07)
  p[#p + 1] = {rod(ab, ab + lean, 0.011, 6), chrome, sig=true}
  for i, w in ipairs({0.075, 0.058, 0.042}) do
    local c = ab + lean * (0.42 + i * 0.13)
    p[#p + 1] = {rod(c - v3(w, 0, 0), c + v3(w, 0, 0), 0.007, 5), chrome, sig=true}
  end
  local at_ = ab + lean * 1.04
  p[#p + 1] = {ball(0.034, 0.034, 0.034, at_.x, at_.y, at_.z, 10), red, sig=true}

  -- Two aliens up through hatches in the front deck: Blip (one big eye, one antenna) watching the road, and Zorp
  -- (three eyes on stalks, a wide grin) turned round to keep an eye on the cow. Each built about its hatch's
  -- middle facing +z, then grown, turned and put in place.
  local function alien(list, x, z, yaw)
    local y = deckY(math.sqrt(x * x + ((z - CZ) / ZS) ^ 2)) - 0.005
    for _, q in ipairs(list) do
      local m = scale(q[1], {factor=v3(1.18, 1.18, 1.18), pivot=origin()})
      if yaw ~= 0 then m = rotate(m, {angle=yaw, axis=axis_y(), pivot=origin()}) end
      p[#p + 1] = {at(m, x, y, z), q[2]}
    end
  end
  -- Blip, lime green.
  do
    local col, c = C(0.5, 0.88, 0.26), {}
    c[#c + 1] = {cyl(0.1, 0.045, 0, 0.005, 0, "y", 12), dark}
    c[#c + 1] = {ball(0.07, 0.06, 0.06, 0, 0.04, 0, 10), col}
    c[#c + 1] = {ball(0.1, 0.11, 0.095, 0, 0.15, 0, 14), col}
    c[#c + 1] = {ball(0.054, 0.054, 0.03, 0, 0.17, 0.08, 10), white}
    c[#c + 1] = {ball(0.026, 0.026, 0.012, 0.006, 0.172, 0.105, 8), black}
    c[#c + 1] = {ball(0.008, 0.008, 0.004, 0.016, 0.183, 0.115, 6), white}
    c[#c + 1] = {ball(0.02, 0.012, 0.008, 0, 0.09, 0.09, 6), C(0.18, 0.32, 0.08)}
    c[#c + 1] = {tube(curve(4, function(t) return v3(t * 0.03, 0.25 + t * 0.12, -t * t * 0.05) end), 0.009, 5), col}
    c[#c + 1] = {ball(0.027, 0.027, 0.027, 0.03, 0.38, -0.05, 8), C(1.0, 0.35, 0.7)}
    for _, h in ipairs({-1, 1}) do c[#c + 1] = {ball(0.03, 0.02, 0.032, h * 0.085, 0.035, 0.095, 8), col} end
    alien(c, -0.4, 0.6, 0)
  end
  -- Zorp, lilac, a broad head.
  do
    local col, c = C(0.62, 0.5, 0.95), {}
    c[#c + 1] = {cyl(0.1, 0.045, 0, 0.005, 0, "y", 12), dark}
    c[#c + 1] = {ball(0.07, 0.06, 0.06, 0, 0.04, 0, 10), col}
    c[#c + 1] = {ball(0.12, 0.085, 0.09, 0, 0.13, 0, 14), col}
    for e = -1, 1 do
      local ex = e * 0.058
      local ey = 0.215 + (e == 0 and 0.03 or 0)
      c[#c + 1] = {rod(v3(ex * 0.6, 0.18, 0.03), v3(ex, ey, 0.04), 0.009, 5), col}
      c[#c + 1] = {ball(0.028, 0.028, 0.028, ex, ey, 0.04, 8), white}
      c[#c + 1] = {ball(0.013, 0.013, 0.008, ex, ey, 0.066, 6), black}
    end
    c[#c + 1] = {ball(0.065, 0.018, 0.02, 0, 0.1, 0.08, 10), C(0.25, 0.1, 0.3)}
    c[#c + 1] = {ball(0.04, 0.008, 0.012, 0, 0.093, 0.094, 8), C(1.0, 0.6, 0.7)}
    for _, s in ipairs({-1, 1}) do
      c[#c + 1] = {rod(v3(s * 0.06, 0.19, -0.02), v3(s * 0.11, 0.31, -0.04), 0.008, 5), col}
      c[#c + 1] = {ball(0.022, 0.022, 0.022, s * 0.11, 0.32, -0.04, 8), yellow}
      c[#c + 1] = {ball(0.03, 0.02, 0.032, s * 0.085, 0.035, 0.095, 8), col}
    end
    alien(c, 0.4, 0.6, 155)
  end

  -- The tractor beam rising from the rear deck behind the driver, ringed with light, and a cow going up it.
  local bz, by, bh = -0.84, 0.115, P.beam
  do
    local function rr(y) return 0.225 - 0.055 * y / bh end
    local pts = {{0.004, 0}, {0.25, 0}, {0.25, 0.03}, {rr(0.03), 0.03}}
    for i = 0, 2 do
      local y = (i + 0.5) / 3 * bh
      pts[#pts + 1] = {rr(y - 0.016), y - 0.016}
      pts[#pts + 1] = {rr(y) + 0.022, y}
      pts[#pts + 1] = {rr(y + 0.016), y + 0.016}
    end
    pts[#pts + 1] = {rr(bh), bh}
    pts[#pts + 1] = {0.004, bh}
    local beam = paint(at(lathe(pts, 16), 0, by, bz), C(0.7, 1.0, 0.74))
    beam = paint_if(beam, C(0.3, 0.95, 0.55), function(f)
      local y = f.center.y - by
      local dx, dz = f.center.x, f.center.z - bz
      return y > 0.04 and y < bh - 0.01 and math.sqrt(dx * dx + dz * dz) > rr(y) + 0.004
    end)
    beam = paint_if(beam, dark, function(f) return f.center.y < by + 0.032 end)
    p[#p + 1] = {beam}
  end
  -- The cow, built about its belly's middle, then turned side on (so she reads from behind), tipped and lifted to
  -- the beam's top: white with brown patches, a bell at her neck.
  local cow = C(0.97, 0.96, 0.93)
  local patch = C(0.42, 0.26, 0.16)
  local pink = C(0.98, 0.62, 0.66)
  local c = {}
  c[#c + 1] = {rb(0.25, 0.18, 0.36, 0, 0.08, 0, 0.045), cow}
  c[#c + 1] = {ball(0.07, 0.04, 0.08, 0.118, 0.1, -0.05, 8), patch}
  c[#c + 1] = {ball(0.07, 0.045, 0.07, -0.118, 0.07, 0.06, 8), patch}
  c[#c + 1] = {ball(0.07, 0.02, 0.08, 0.02, 0.165, -0.08, 8), patch}
  c[#c + 1] = {rb(0.15, 0.14, 0.15, 0, 0.12, 0.23, 0.03), cow}
  c[#c + 1] = {rb(0.13, 0.07, 0.05, 0, 0.085, 0.315, 0.015), pink}
  c[#c + 1] = {rb(0.045, 0.045, 0.03, 0, 0.02, 0.2, 0.008), yellow}
  for _, side in ipairs({-1, 1}) do
    c[#c + 1] = {bx(0.016, 0.016, 0.01, side * 0.03, 0.09, 0.34), black}
    c[#c + 1] = {ball(0.018, 0.022, 0.01, side * 0.042, 0.15, 0.305, 6), black}
    c[#c + 1] = {turn(cone{radius=0.016, height=0.06, segments=6}, side * -30, axis_z(), side * 0.06, 0.21, 0.21), C(0.9, 0.85, 0.7)}
    c[#c + 1] = {ball(0.035, 0.014, 0.022, side * 0.095, 0.16, 0.2, 6), cow}
  end
  for i = 0, 3 do
    local x, z = (i % 2 == 0) and 0.08 or -0.08, (i < 2) and 0.11 or -0.11
    c[#c + 1] = {bx(0.05, 0.13, 0.05, x, -0.06, z), cow}
    c[#c + 1] = {bx(0.058, 0.035, 0.058, x, -0.135, z), dark}
  end
  c[#c + 1] = {ball(0.055, 0.035, 0.045, 0, -0.01, -0.02, 8), pink}
  c[#c + 1] = {rod(v3(0, 0.14, -0.18), v3(0.04, 0.0, -0.25), 0.009, 5), cow}
  c[#c + 1] = {ball(0.018, 0.026, 0.018, 0.042, -0.01, -0.255, 6), patch}
  local lift = v3(0, by + bh + 0.01, bz)
  for _, q in ipairs(c) do
    local m = turn(turn(q[1], 90, axis_y(), 0, 0, 0), 10, axis_z(), 0, 0, 0)
    p[#p + 1] = {translate(m, lift), q[2]}
  end
  part("saucer", p)
end
