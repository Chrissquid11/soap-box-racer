-- Abduction Reduction, the whole kart: a flying saucer round the driver, two aliens peering over its front rim, a
-- cow beamed up behind -- on its own undercarriage, a saucer's landing gear: a riveted belly with the tractor-beam
-- emitter glowing beneath it, four hydraulic landing legs on round foot pads, and the axle struts the wheels hang on.
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
  local rest = include("_sig.lua").split(name, out, function(i) return pieces[i].sig end)
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

local black  = C(0.04, 0.04, 0.05)
local dark   = C(0.14, 0.14, 0.16)
local grey   = C(0.5, 0.52, 0.55)
local silver = C(0.78, 0.8, 0.84)
local chrome = C(0.92, 0.93, 0.96)
local white  = C(0.96, 0.96, 0.94)
local wood   = C(0.72, 0.48, 0.24)

local tractor = C(0.25, 1.0, 0.85)
local glow    = C(0.6, 1.0, 0.95)
local hull    = C(0.42, 0.45, 0.52)

-- Abduction Reduction ------------------------------------------------------------------------------------------
do
  local p = {}
  local R = P.radius
  -- The saucer is an oval, stretched along z so its cockpit hole fits the driver (x ±0.37, z -0.51..0.45).
  local ZS, CZ = 1.3, -0.03
  local function oval(m) return at(scale(m, {factor=v3(1, 1, ZS), pivot=origin()}), 0, 0, CZ) end
  -- A point on the oval at angle a, radius r, height y.
  local function on(a, r, y) return v3(math.cos(a) * r, y, CZ + math.sin(a) * r * ZS) end
  -- The oval radius of a face's middle.
  local function orad(c) local dz = (c.z - CZ) / ZS; return math.sqrt(c.x * c.x + dz * dz), math.atan(dz, c.x) end

  -- The saucer: a lens round the driver's waist, convex beneath down to the cockpit floor, silver above with a
  -- darker panel band, riveted hull plates below in two greys.
  local k = R / 0.82
  local lens = revolve(poly{points={v2(0.37, -0.2), v2(0.5 * k, -0.13), v2(0.65 * k, -0.06), v2(0.78 * k, -0.01),
    v2(R, 0.02), v2(R + 0.01, 0.05), v2(R - 0.02, 0.08), v2(0.68 * k, 0.12), v2(0.55 * k, 0.16), v2(0.45, 0.19),
    v2(0.37, 0.2)}}, {segments=48})
  lens = paint(oval(lens), silver)
  lens = paint_if(lens, C(0.55, 0.58, 0.66), function(f)
    local r = orad(f.center)
    return f.normal.y > 0.3 and r > 0.55 * k and r < 0.68 * k
  end)
  lens = paint_if(lens, hull, function(f)
    local r, a = orad(f.center)
    return f.normal.y < -0.2 and math.floor((a + math.pi) / (2 * math.pi) * 12) % 2 == 0
  end)
  lens = paint_if(lens, shade(hull, 1.25), function(f)
    local r, a = orad(f.center)
    return f.normal.y < -0.2 and math.floor((a + math.pi) / (2 * math.pi) * 12) % 2 == 1
  end)
  p[#p + 1] = {lens}
  -- Its rim, a dark band studded with lights in four colours; a cockpit coaming round the hole.
  p[#p + 1] = {oval(at(torus{major_radius=R + 0.005, minor_radius=0.026, major_segments=48, minor_segments=6, axis="y"}, 0, 0.045, 0)), dark}
  p[#p + 1] = {oval(at(torus{major_radius=0.375, minor_radius=0.022, major_segments=40, minor_segments=6, axis="y"}, 0, 0.2, 0)), chrome}
  local lights = {yellow, C(1.0, 0.3, 0.8), C(0.3, 0.9, 1.0), C(0.6, 1.0, 0.3)}
  for i = 0, P.lights - 1 do
    local a = i / P.lights * 2 * math.pi
    local q = on(a, R + 0.02, 0.045)
    p[#p + 1] = {ball(0.036, 0.036, 0.036, q.x, q.y, q.z, 8), lights[i % 4 + 1]}
  end
  -- A ring of glow round its underside.
  p[#p + 1] = {oval(at(torus{major_radius=0.55 * k, minor_radius=0.018, major_segments=40, minor_segments=6, axis="y"}, 0, -0.118, 0)), tractor}

  -- The undercarriage. The belly: a riveted dish under the cockpit, its top the floor, its foot the tractor-beam
  -- emitter, glowing cyan in rings.
  local belly = lathe({{0.004, -0.39}, {0.3, -0.39}, {0.38, -0.34}, {0.43, -0.26}, {0.44, -0.17}, {0.36, -0.17},
    {0.36, -0.23}, {0.004, -0.23}}, 40)
  belly = paint(oval(belly), hull)
  belly = paint_if(belly, shade(hull, 0.8), function(f)
    local _, a = orad(f.center)
    return f.normal.y < 0.9 and math.floor((a + math.pi) / (2 * math.pi) * 10) % 2 == 0
  end)
  p[#p + 1] = {belly}
  for i = 0, 19 do
    local q = on(i / 20 * 2 * math.pi, 0.425, -0.27)
    p[#p + 1] = {ball(0.011, 0.011, 0.011, q.x, q.y, q.z, 6), silver}
    local s = on((i + 0.5) / 20 * 2 * math.pi, 0.35, -0.365)
    p[#p + 1] = {ball(0.01, 0.01, 0.01, s.x, s.y, s.z, 6), silver}
  end
  p[#p + 1] = {cyl(0.27, 0.03, 0, -0.4, CZ, "y", 32), dark}
  p[#p + 1] = {cyl(0.23, 0.02, 0, -0.42, CZ, "y", 32), tractor}
  p[#p + 1] = {cyl(0.15, 0.02, 0, -0.428, CZ, "y", 28), glow}
  p[#p + 1] = {ball(0.08, 0.035, 0.08, 0, -0.433, CZ, 16), C(0.9, 1.0, 1.0)}
  for i = 0, 1 do
    p[#p + 1] = {at(torus{major_radius=0.19 - i * 0.07, minor_radius=0.008, major_segments=32, minor_segments=5, axis="y"}, 0, -0.432, CZ), C(0.1, 0.55, 0.5)}
  end
  -- The axle struts: a crossbar into each wheel's hub, two hydraulic struts up from it into the saucer, a rail
  -- either side between them under the belly, antenna bulbs at the struts' tops.
  for _, z in ipairs({-0.7, 0.7}) do
    p[#p + 1] = {cyl(0.026, 0.94, 0, -0.42, z, "x", 12), grey}
    for _, s in ipairs({-1, 1}) do
      p[#p + 1] = {cyl(0.04, 0.05, s * 0.4, -0.42, z, "x", 14), dark}
      p[#p + 1] = {cyl(0.032, 0.18, s * 0.3, -0.33, z, "y", 12), dark}
      p[#p + 1] = {cyl(0.018, 0.2, s * 0.3, -0.15, z, "y", 10), chrome}
      p[#p + 1] = {ball(0.04, 0.03, 0.04, s * 0.3, -0.42, z, 10), dark}
      p[#p + 1] = {ball(0.022, 0.022, 0.022, s * 0.3, -0.04, z, 8), C(0.3, 0.9, 1.0)}
    end
  end
  for _, s in ipairs({-1, 1}) do
    p[#p + 1] = {rb(0.05, 0.05, 1.42, s * 0.3, -0.37, 0, 0.012), dark}
  end
  -- The landing legs: four, a cross of them, each a dark hydraulic housing, a chrome piston, a knee collar and a
  -- round foot pad.
  local legs = {
    {v3(0, -0.03, 0.82 * k), v3(0, -0.5, 0.98 * k)},
    {v3(0, -0.03, -0.85 * k), v3(0, -0.5, -1.02 * k)},
    {v3(0.66 * k, -0.03, -0.03), v3(0.76 * k, -0.5, -0.03)},
    {v3(-0.66 * k, -0.03, -0.03), v3(-0.76 * k, -0.5, -0.03)},
  }
  for _, l in ipairs(legs) do
    local top, foot = l[1], l[2]
    local knee = lerp(top, foot, 0.55)
    p[#p + 1] = {rod(top, knee, 0.032, 12), dark}
    p[#p + 1] = {rod(lerp(top, foot, 0.5), foot + v3(0, 0.03, 0), 0.018, 10), chrome}
    p[#p + 1] = {at(torus{major_radius=0.034, minor_radius=0.01, major_segments=14, minor_segments=5, axis="y"}, knee.x, knee.y, knee.z), yellow}
    p[#p + 1] = {cyl(0.075, 0.022, foot.x, foot.y, foot.z, "y", 18), grey}
    p[#p + 1] = {at(cone{radius=0.05, radius_top=0.02, height=0.035, segments=14}, foot.x, foot.y + 0.028, foot.z), dark}
    -- A brace from the knee back in to the belly.
    local d = v3(top.x, 0, top.z - CZ)
    local inner = v3(d.x * 0.5, -0.3, CZ + d.z * 0.5 * (math.abs(d.x) > 0.01 and 1 or 0.7))
    p[#p + 1] = {rod(knee, inner, 0.014, 8), grey}
  end

  -- The cockpit: a seat cushion under the hips, a padded back against the rear wall, the steering column.
  p[#p + 1] = {rbox(0.46, 0.03, 0.4, 0.08, 0, -0.25, -0.25, 0.01), C(0.35, 0.2, 0.55)}
  p[#p + 1] = {rbox(0.46, 0.5, 0.05, 0.02, 0, -0.22, -0.53, 0.01), C(0.35, 0.2, 0.55)}
  p[#p + 1] = {rod(v3(0, 0.1, 0.15), v3(0, -0.23, 0.38), 0.018, 10), dark}
  p[#p + 1] = {cyl(0.05, 0.015, 0, -0.225, 0.38, "y", 14), grey}

  -- An antenna at the back of the rim, a red light atop it.
  local ab = on(-math.pi * 0.62, 0.7 * k, 0.1)
  p[#p + 1] = {rod(ab, ab + v3(0.04, 0.44, -0.07), 0.01, 6), chrome, sig=true}
  local at_ = ab + v3(0.042, 0.46, -0.072)
  p[#p + 1] = {ball(0.03, 0.03, 0.03, at_.x, at_.y, at_.z, 10), red, sig=true}

  -- Two aliens peering over the front of the rim from their hatches: Blip (one big eye, one antenna) and Zorp
  -- (three eyes on stalks, a wide grin), their hands on the rim.
  local deck = 0.16
  for _, side in ipairs({-1, 1}) do
    local x, z = side * 0.3, 0.6
    p[#p + 1] = {at(torus{major_radius=0.1, minor_radius=0.018, major_segments=20, minor_segments=6, axis="y"}, x, deck, z), dark}
    for _, h in ipairs({-1, 1}) do p[#p + 1] = {ball(0.028, 0.018, 0.03, x + h * 0.085, deck + 0.04, z + 0.1, 10), side < 0 and C(0.55, 0.9, 0.3) or C(0.6, 0.5, 0.95)} end
  end
  -- Blip, lime green.
  do
    local x, z, col = -0.3, 0.6, C(0.55, 0.9, 0.3)
    p[#p + 1] = {ball(0.07, 0.06, 0.06, x, deck + 0.03, z, 12), col}
    p[#p + 1] = {ball(0.1, 0.11, 0.095, x, deck + 0.14, z, 16), col}
    p[#p + 1] = {ball(0.05, 0.05, 0.03, x, deck + 0.16, z + 0.08, 14), white}
    p[#p + 1] = {ball(0.024, 0.024, 0.012, x + 0.006, deck + 0.162, z + 0.105, 10), black}
    p[#p + 1] = {ball(0.007, 0.007, 0.004, x + 0.014, deck + 0.172, z + 0.115, 6), white}
    p[#p + 1] = {ball(0.018, 0.012, 0.008, x, deck + 0.085, z + 0.09, 8), C(0.2, 0.35, 0.1)}
    p[#p + 1] = {tube(curve(6, function(t) return v3(x + t * 0.03, deck + 0.24 + t * 0.12, z - t * t * 0.05) end), 0.009, 6), col}
    p[#p + 1] = {ball(0.025, 0.025, 0.025, x + 0.03, deck + 0.37, z - 0.05, 10), C(1.0, 0.4, 0.75)}
  end
  -- Zorp, lilac, a broad head.
  do
    local x, z, col = 0.3, 0.6, C(0.6, 0.5, 0.95)
    p[#p + 1] = {ball(0.07, 0.06, 0.06, x, deck + 0.03, z, 12), col}
    p[#p + 1] = {ball(0.12, 0.085, 0.09, x, deck + 0.12, z, 16), col}
    for e = -1, 1 do
      local ex = x + e * 0.055
      local ey = deck + 0.2 + (e == 0 and 0.03 or 0)
      p[#p + 1] = {rod(v3(ex * 0.6 + x * 0.4, deck + 0.17, z + 0.03), v3(ex, ey, z + 0.04), 0.008, 6), col}
      p[#p + 1] = {ball(0.026, 0.026, 0.026, ex, ey, z + 0.04, 10), white}
      p[#p + 1] = {ball(0.012, 0.012, 0.008, ex, ey, z + 0.064, 8), black}
    end
    p[#p + 1] = {ball(0.06, 0.016, 0.02, x, deck + 0.09, z + 0.08, 12), C(0.25, 0.1, 0.3)}
    p[#p + 1] = {ball(0.04, 0.007, 0.012, x, deck + 0.084, z + 0.094, 10), C(1.0, 0.6, 0.7)}
    for _, s in ipairs({-1, 1}) do
      p[#p + 1] = {rod(v3(x + s * 0.06, deck + 0.18, z - 0.02), v3(x + s * 0.11, deck + 0.3, z - 0.04), 0.007, 6), col}
      p[#p + 1] = {ball(0.02, 0.02, 0.02, x + s * 0.11, deck + 0.31, z - 0.04, 8), yellow}
    end
  end

  -- The tractor beam rising from the rear deck behind the driver, banded rings of light, and a cow going up it.
  local bz, by, bh = -0.86, 0.11, P.beam
  p[#p + 1] = {cyl(0.27, 0.03, 0, by, bz, "y", 24), dark}
  p[#p + 1] = {at(cone{radius=0.24, radius_top=0.18, height=bh, segments=24}, 0, by + bh / 2, bz), C(0.75, 1.0, 0.7)}
  for i = 0, 2 do
    local t = (i + 0.5) / 3
    p[#p + 1] = {at(torus{major_radius=0.24 - t * 0.06, minor_radius=0.012, major_segments=24, minor_segments=6, axis="y"}, 0, by + t * bh, bz), C(0.4, 1.0, 0.6)}
  end
  -- The cow, built about its belly's middle, then lifted to the beam's top: white with brown patches.
  local cow = C(0.97, 0.96, 0.93)
  local patch = C(0.42, 0.26, 0.16)
  local c = {}
  c[#c + 1] = {rbox(0.24, 0.16, 0.34, 0.06, 0, 0, 0, 0.03), cow}
  c[#c + 1] = {ball(0.06, 0.035, 0.07, 0.122, 0.09, -0.04, 10), patch}
  c[#c + 1] = {ball(0.06, 0.04, 0.06, -0.122, 0.06, 0.06, 10), patch}
  c[#c + 1] = {ball(0.05, 0.02, 0.06, 0.02, 0.162, -0.1, 10), patch}
  c[#c + 1] = {rbox(0.12, 0.12, 0.14, 0.035, 0, 0.04, 0.22, 0.02), cow}
  c[#c + 1] = {rb(0.1, 0.06, 0.04, 0, 0.07, 0.295, 0.012), C(0.98, 0.65, 0.68)}
  for _, side in ipairs({-1, 1}) do
    c[#c + 1] = {ball(0.008, 0.008, 0.006, side * 0.025, 0.08, 0.316, 6), black}
    c[#c + 1] = {ball(0.016, 0.016, 0.012, side * 0.04, 0.12, 0.27, 6), black}
    c[#c + 1] = {ball(0.006, 0.006, 0.004, side * 0.044, 0.125, 0.281, 6), white}
    c[#c + 1] = {turn(cone{radius=0.012, height=0.05, segments=8}, side * -30, axis_z(), side * 0.05, 0.185, 0.2), C(0.9, 0.85, 0.7)}
    c[#c + 1] = {ball(0.03, 0.012, 0.02, side * 0.075, 0.14, 0.19, 8), cow}
  end
  for i = 0, 3 do
    local x, z = (i % 2 == 0) and 0.08 or -0.08, (i < 2) and 0.1 or -0.1
    c[#c + 1] = {rb(0.04, 0.12, 0.04, x, -0.06, z, 0.01), cow}
    c[#c + 1] = {rb(0.044, 0.03, 0.044, x, -0.11, z, 0.008), dark}
  end
  c[#c + 1] = {ball(0.05, 0.03, 0.04, 0, -0.01, 0, 10), C(0.98, 0.65, 0.68)}
  c[#c + 1] = {rod(v3(0, 0.12, -0.17), v3(0.04, 0.0, -0.24), 0.008, 6), cow}
  c[#c + 1] = {ball(0.014, 0.022, 0.014, 0.042, -0.01, -0.245, 6), patch}
  local lift = v3(0, by + bh + 0.06, bz + 0.0)
  for _, q in ipairs(c) do
    local m = turn(q[1], 12, axis_x(), 0, 0, 0)
    p[#p + 1] = {translate(m, lift), q[2]}
  end
  part("saucer", p)
end
