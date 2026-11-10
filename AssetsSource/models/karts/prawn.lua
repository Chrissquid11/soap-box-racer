-- The Existential Prawn: a whole kart, one part ("prawn"). A giant prawn on its back, legs in the air, staring into
-- space -- served up: it lies on a bed of crushed ice on an oval silver seafood platter, with lemon wedges and parsley
-- round it, the platter carried on a fork (the front axle) and a kebab skewer (the rear), so no crate shows.
--
-- About the middle of the chassis' top, facing +z, in the kart's own metres. The wheels (another slot) sit at x ±0.5,
-- z ±0.7, y -0.42; the driver's hips at (0, -0.21, -0.25) on the prawn's pale belly, clear of x ±0.28, z -0.5..0.45,
-- y -0.2..0.9; the steering wheel (another slot) at (0, 0.13, 0.12). Colours painted on the vertices, one material.
local P = params{
  tray_length = { default = 1.16, min = 1.0, max = 1.3, doc = "Half the platter's length, metres" },
  ice         = { default = 120, min = 40, max = 220, integer = true, doc = "Lumps of crushed ice on the platter" },
  eyes        = { default = 0.11, min = 0.07, max = 0.15, doc = "Eye radius, metres: how hard it stares" },
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

-- A tiny deterministic random, so the ice lies the same every build.
local seed = 20261105
local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
local function rr(a, b) return a + (b - a) * rnd() end

local p = {}
local pink   = C(1.0, 0.56, 0.45)
local deep   = C(0.9, 0.32, 0.26)
local pale   = C(1.0, 0.82, 0.72)
local lemon  = C(1.0, 0.86, 0.12)
local flesh  = C(1.0, 0.95, 0.62)
local green  = C(0.16, 0.5, 0.12)
local leaf   = C(0.24, 0.62, 0.18)
local L      = P.tray_length
local TOP    = -0.225                       -- the platter's top, the ice on it

-- THE PRAWN ------------------------------------------------------------------------------------------------------
-- On its back along the kart: shell segments down both sides, banded, their colour deepening toward the tail, a
-- paler belly between them, low, where the driver sits.
for i = 0, 6 do
  local z = 0.55 - i * 0.2
  local c = lerp((i % 2 == 0) and pink or deep, C(0.95, 0.42, 0.2), i / 10)
  for _, side in ipairs({-1, 1}) do
    local seg = ball(0.12, 0.17, 0.14, side * 0.39, 0.0, z, 12)
    seg = paint(seg, c)
    seg = paint_if(seg, pale, function(f) return f.normal.x * side < -0.45 and f.normal.y > -0.2 end)
    p[#p + 1] = {seg}
    p[#p + 1] = {turn(ball(0.05, 0.11, 0.025, 0, 0, 0, 8), side * 20, axis_z(), side * 0.5, -0.04, z - 0.08), shade(c, 0.85)}
  end
end
-- The belly: pale plates across between the shell sides, the seat; their tops at -0.22 under the driver.
for i = 0, 5 do
  local z = 0.4 - i * 0.18
  p[#p + 1] = {ball(0.3, 0.02, 0.1, 0, -0.238, z, 12), (i % 2 == 0) and pale or C(0.98, 0.74, 0.62)}
end
-- The tail, curling up behind (the seat back), its fan splayed at the top.
local tail = {{0, 0.06, -0.84, 0.26}, {0, 0.28, -0.99, 0.22}, {0, 0.5, -1.05, 0.18}, {0, 0.7, -1.01, 0.15}}
for i, t in ipairs(tail) do p[#p + 1] = {ball(t[4] * 1.3, t[4], t[4], t[1], t[2], t[3], 12), (i % 2 == 0) and pink or deep} end
for i = -2, 2 do
  local blade = turn(ball(0.06, 0.2, 0.025, 0, 0, 0, 14), i * 22, axis_z(), i * 0.1, 0.91 - math.abs(i) * 0.03, -0.96 + i * 0.005)
  p[#p + 1] = {blade, (i % 2 == 0) and deep or C(0.95, 0.45, 0.3)}
  p[#p + 1] = {turn(ball(0.04, 0.05, 0.02, 0, 0, 0, 10), i * 22, axis_z(), i * 0.1 + math.sin(math.rad(i * 22)) * -0.16, 0.91 - math.abs(i) * 0.03 + math.cos(math.rad(i * 22)) * 0.16, -0.96 + i * 0.005), C(0.35, 0.12, 0.15)}
end
-- The head up front, a spiked rostrum; eyes on stalks, staring straight up into space; long feelers waving ahead.
p[#p + 1] = {ball(0.3, 0.22, 0.34, 0, 0.06, 0.88, 18), pink}
p[#p + 1] = {ball(0.22, 0.1, 0.26, 0, 0.21, 0.86, 16), deep}
p[#p + 1] = {tube(curve(6, function(t) return v3(0, 0.14 + 0.05 * t, 1.16 + 0.2 * t) end), 0.035, 8, 0.1), deep}
for i = 0, 3 do p[#p + 1] = {at(cone{radius=0.012, height=0.04, segments=6}, 0, 0.185 + i * 0.008, 1.18 + i * 0.045), deep} end
local E = P.eyes
for _, side in ipairs({-1, 1}) do
  p[#p + 1] = {rod(v3(side * 0.12, 0.19, 0.93), v3(side * 0.16, 0.42 - E, 0.96), 0.03, 10), deep}
  p[#p + 1] = {ball(E, E, E, side * 0.16, 0.42, 0.96, 14), black}
  p[#p + 1] = {ball(E * 0.27, E * 0.27, E * 0.23, side * 0.16 - side * E * 0.27, 0.42 + E * 0.73, 0.96 + E * 0.45, 10), white}
  p[#p + 1] = {ball(E * 0.13, E * 0.13, E * 0.11, side * 0.16 + side * E * 0.27, 0.42 + E * 0.9, 0.96 + E * 0.2, 8), white}
  -- The feelers: long, thin, curving out and up; two short ones under them.
  p[#p + 1] = {tube(curve(16, function(t)
    return v3(side * (0.1 + 0.45 * t), 0.14 + 0.85 * t - 0.25 * t * t, 1.08 + 0.55 * math.sin(t * 2.2) * 0.8)
  end), 0.014, 6, 0.3), C(0.85, 0.2, 0.15), sig=true}
  p[#p + 1] = {tube(curve(8, function(t) return v3(side * (0.06 + 0.1 * t), 0.09 + 0.1 * t, 1.16 + 0.2 * t) end), 0.01, 6, 0.4), C(0.85, 0.2, 0.15)}
  -- Its legs, in the air: five pairs up its sides, jointed, their tips paler.
  for i = 0, 4 do
    local z = 0.45 - i * 0.2
    local knee = v3(side * 0.47, 0.42, z + 0.05)
    local tip = v3(side * 0.42, 0.6, z + 0.12)
    p[#p + 1] = {rod(v3(side * 0.4, 0.12, z), knee, 0.02, 8), deep}
    p[#p + 1] = {ball(0.026, 0.026, 0.026, knee.x, knee.y, knee.z, 8), C(0.75, 0.25, 0.2)}
    p[#p + 1] = {rod(knee, tip, 0.015, 8), pink}
    p[#p + 1] = {ball(0.016, 0.02, 0.016, tip.x, tip.y + 0.004, tip.z, 8), pale}
  end
end
-- The steering column: a silver stem, up from the belly's front to the wheel.
p[#p + 1] = {rod(v3(0, -0.24, 0.5), v3(0, 0.1, 0.13), 0.016, 10), chrome}
p[#p + 1] = {cyl(0.04, 0.03, 0, -0.235, 0.5, "y", 14), silver}

-- THE PLATTER ----------------------------------------------------------------------------------------------------
-- An oval silver serving tray, flaring from its foot up to a rolled rim, a handle at each end.
local TW, TR = 0.4, 0.34                    -- half its width at the top, its ends' radius
p[#p + 1] = {at(extrude(rounded_rect{w=TW * 2 * 0.86, h=L * 2 * 0.93, radius=TR * 0.85, segments=8},
  {distance=0.1, scale_end=1 / 0.88, segments=2}), 0, TOP - 0.1, 0), silver}
p[#p + 1] = {rbox(TW * 2 - 0.03, 0.006, L * 2 - 0.03, TR - 0.015, 0, TOP - 0.004, 0), chrome}
local rim = {}
local function ring_pt(a)                    -- a point on the rim's rounded-rectangle outline
  local c, s = math.cos(a), math.sin(a)
  local cx = (c >= 0 and 1 or -1) * (TW - TR)
  local cz = (s >= 0 and 1 or -1) * (L - TR)
  return v3(cx + c * TR, TOP, cz + s * TR)
end
for i = 0, 63 do rim[#rim + 1] = ring_pt(i / 64 * math.pi * 2 + 0.0001) end
p[#p + 1] = {sweep(circle{radius=0.02, segments=8}, path{points=rim, closed=true}, {}), chrome}
for _, e in ipairs({-1, 1}) do
  local h = scale(torus{major_radius=0.12, minor_radius=0.016, major_segments=20, minor_segments=8, axis="y"},
    {factor=v3(1, 1, 0.6), pivot=origin()})
  p[#p + 1] = {at(h, 0, TOP - 0.01, e * (L + 0.02)), chrome}
  p[#p + 1] = {rb(0.08, 0.02, 0.05, 0, TOP - 0.01, e * (L + 0.08), 0.008), silver}
end

-- The bed of crushed ice: faceted pale lumps over the platter, low under the cockpit, heaped round the prawn.
local ices = {C(0.86, 0.94, 1.0), C(0.78, 0.9, 0.98), C(0.94, 0.98, 1.0), C(0.7, 0.85, 0.95)}
local n, tries = 0, 0
while n < P.ice and tries < P.ice * 20 do
  tries = tries + 1
  local x, z = rr(-TW + 0.05, TW - 0.05), rr(-L + 0.05, L - 0.05)
  local ex = math.max(0, math.abs(x) - (TW - TR))
  local ez = math.max(0, math.abs(z) - (L - TR))
  local inside = ex * ex + ez * ez < (TR - 0.05) ^ 2
  local cockpit = math.abs(x) < 0.3 and z > -0.55 and z < 0.5
  if inside and not cockpit then
    local r = rr(0.035, 0.065)
    local lump = sphere{radius=1, segments=5 + math.floor(rnd() * 2), rings=3}
    lump = scale(lump, {factor=v3(r * rr(0.8, 1.3), r * rr(0.6, 0.9), r * rr(0.8, 1.3)), pivot=origin()})
    lump = rotate(lump, {angle=rr(0, 360), axis=axis_y(), pivot=origin()})
    lump = rotate(lump, {angle=rr(-25, 25), axis=axis_x(), pivot=origin()})
    p[#p + 1] = {at(lump, x, TOP + r * 0.4 + rr(0, 0.03), z), ices[1 + math.floor(rnd() * 4)]}
    n = n + 1
  end
end

-- Lemon wedges on the ice: a slice of a lemon turned about its pole, rind up, its cut faces pale.
local function wedge(r, yaw, x, y, z)
  local pts = {}
  for i = 0, 8 do
    local t = -math.pi / 2 + math.pi * i / 8
    pts[#pts + 1] = v2(0.004 + r * math.cos(t), r * 1.25 * math.sin(t))
  end
  local A = 100
  local m = revolve(poly{points=pts}, {angle=A, segments=8})
  local sa, ca = math.sin(math.rad(A)), math.cos(math.rad(A))
  m = paint(m, lemon)
  m = paint_if(m, flesh, function(f)
    return math.abs(f.normal.z) > 0.97 or math.abs(f.normal.x * sa + f.normal.z * ca) > 0.97
  end)
  m = rotate(m, {angle=-A / 2, axis=axis_y(), pivot=origin()})
  m = rotate(m, {angle=90, axis=axis_z(), pivot=origin()})
  m = rotate(m, {angle=yaw, axis=axis_y(), pivot=origin()})
  return {at(m, x, y, z)}
end
p[#p + 1] = wedge(0.07, 30, 0.27, TOP + 0.02, L - 0.2)
p[#p + 1] = wedge(0.07, -30, -0.27, TOP + 0.02, L - 0.2)
p[#p + 1] = wedge(0.065, 75, 0.3, TOP + 0.02, -L + 0.3)
p[#p + 1] = wedge(0.065, -100, -0.29, TOP + 0.02, -L + 0.32)

-- Sprigs of parsley: a stem with a few leafy clusters, tucked in at the platter's corners.
local function sprig(x, z, yaw)
  local a = math.rad(yaw)
  local dx, dz = math.sin(a), math.cos(a)
  local y = TOP + 0.04
  p[#p + 1] = {tube({v3(x, y, z), v3(x + dx * 0.06, y + 0.015, z + dz * 0.06), v3(x + dx * 0.12, y + 0.02, z + dz * 0.12)}, 0.006, 6), green}
  for k = 1, 3 do
    local t = 0.04 * k
    local cx, cz = x + dx * t + dz * (k - 2) * 0.04, z + dz * t - dx * (k - 2) * 0.04
    p[#p + 1] = {tube({v3(x + dx * t * 0.8, y + 0.012, z + dz * t * 0.8), v3(cx, y + 0.03, cz)}, 0.004, 5), green}
    for j = 0, 3 do
      local ja = j * math.pi / 2 + k
      p[#p + 1] = {ball(0.022, 0.014, 0.022, cx + math.cos(ja) * 0.018, y + 0.035 + (j % 2) * 0.01, cz + math.sin(ja) * 0.018, 6), (j % 2 == 0) and leaf or green}
    end
  end
end
sprig(0.2, L - 0.12, 60)
sprig(-0.22, -L + 0.14, -120)
sprig(0.31, -0.62, 10)

-- UNDER THE PLATTER ----------------------------------------------------------------------------------------------
-- A footed stand in the middle: a stem and a round foot.
p[#p + 1] = {at(lathe({{0.0, 0}, {0.13, 0}, {0.13, 0.012}, {0.06, 0.03}, {0.04, 0.09}, {0.09, 0.13}, {0.0, 0.13}}, 24), 0, -0.48, 0), silver}
-- The axles, each in a pair of silver brackets hung from the platter's underside, reaching into the wheel hubs.
for _, az in ipairs({-0.7, 0.7}) do
  for _, side in ipairs({-1, 1}) do
    p[#p + 1] = {rb(0.05, 0.1, 0.06, side * 0.27, -0.375, az, 0.012), silver}
    p[#p + 1] = {at(torus{major_radius=0.03, minor_radius=0.01, major_segments=14, minor_segments=6, axis="x"}, side * 0.27, -0.42, az), chrome}
  end
end
-- The front axle: a big silver fork lying across, its handle one side, its tines into the other hub.
p[#p + 1] = {rod(v3(-0.47, -0.42, 0.7), v3(0.2, -0.42, 0.7), 0.017, 10), chrome}
p[#p + 1] = {rb(0.04, 0.022, 0.03, -0.45, -0.42, 0.7, 0.008), chrome}
p[#p + 1] = {ball(0.05, 0.012, 0.035, 0.25, -0.42, 0.7, 10), chrome}
for t = 0, 3 do
  local tz = 0.7 + (t - 1.5) * 0.016
  p[#p + 1] = {rod(v3(0.27, -0.42, tz), v3(0.47, -0.42, tz), 0.0055, 6), chrome}
end
-- The rear axle: a kebab skewer, a loop at its end, a lemon slice and two prawn chunks on it.
p[#p + 1] = {rod(v3(-0.44, -0.42, -0.7), v3(0.46, -0.42, -0.7), 0.009, 8), chrome}
p[#p + 1] = {at(cone{radius=0.009, height=0.025, segments=8, axis="x"}, 0.47, -0.42, -0.7), chrome}
p[#p + 1] = {at(torus{major_radius=0.025, minor_radius=0.006, major_segments=12, minor_segments=6, axis="z"}, -0.465, -0.42, -0.7), chrome}
for _, x in ipairs({-0.15, 0.15}) do
  p[#p + 1] = {at(torus{major_radius=0.035, minor_radius=0.02, major_segments=14, minor_segments=8, axis="x"}, x, -0.42, -0.7), pink}
end
local slice = paint(cylinder{radius=0.055, height=0.018, segments=16, axis="x"}, lemon)
slice = paint_if(slice, flesh, function(f) return math.abs(f.normal.x) > 0.9 end)
p[#p + 1] = {at(slice, 0, -0.42, -0.7)}

part("prawn", p)
