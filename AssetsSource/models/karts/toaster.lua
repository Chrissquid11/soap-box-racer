-- The Bread Bull: a chrome toaster with a bull's horns, the driver popping up out of its middle slot between two
-- slices of toast, all of it riding on a wooden breadboard: chrome toaster-rack rails beneath, the axles hung off
-- them, a butter knife for a front bumper, the crumb tray pulled out the back and a bread-bag twist-tie round the
-- rear axle. One part, "toaster", drawn by the game with Render.model "karts/toaster#toaster" on the kart's
-- bodywork entity (the chassis box hidden: it brings its own undercarriage).
--
-- In the kart's body space, metres: origin the middle of the chassis box's top, +z forward, y up. The wheels (another
-- slot) sit at x ±0.5, z ±0.7, y -0.42; the driver at hips (0, -0.21, -0.25), so nothing but the seat and the
-- steering column comes into x ±0.28, z -0.5..0.45, y -0.2..0.9. Colours are painted on the vertices, one white
-- material.
local P = params{
  horns = { default = 1.0, min = 0.6, max = 1.4, doc = "Horn length, share of the usual" },
  pop   = { default = 0.1, min = 0.0, max = 0.2, doc = "How far the toast pops up above its slots, metres" },
  tray  = { default = 0.2, min = 0.05, max = 0.3, doc = "How far the crumb tray is pulled out the back, metres" },
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
local red    = C(0.88, 0.1, 0.07)
local yellow = C(0.99, 0.8, 0.15)
local green  = C(0.3, 0.8, 0.28)
local orange = C(1.0, 0.45, 0.05)
local pink   = C(1.0, 0.55, 0.7)
local brass  = C(0.9, 0.7, 0.25)

-- A cone from a (radius r0) to b (radius r1), a hair short of each, as rod.
local function cone_rod(a0, b0, r0, r1, seg)
  local a, b = lerp(a0, b0, 0.004), lerp(a0, b0, 0.996)
  local d = b - a
  local m = cone{radius=r0, radius_top=r1, height=length(d), segments=seg or 10}
  local dir = normalize(d)
  local c = dot(v3(0, 1, 0), dir)
  if c < -0.9999 then m = rotate(m, {angle=180, axis=axis_x(), pivot=origin()})
  elseif c < 0.9999 then m = rotate(m, {angle=deg(math.acos(c)), axis=normalize(cross(v3(0, 1, 0), dir)), pivot=origin()}) end
  return translate(m, (a + b) * 0.5)
end

local p = {}
local toast = C(0.95, 0.74, 0.4)
local brown = C(0.78, 0.5, 0.2)
local crust = C(0.55, 0.3, 0.12)
local board = C(0.74, 0.52, 0.3)
local grain = C(0.6, 0.39, 0.2)

-- A rounded rectangle's outline in the xz plane as a profile's points, { x, -z } (an extrusion along +y lays a
-- profile's y on -z): counter-clockwise for an outline, `cw` for a hole.
local function rr_pts(x0, x1, z0, z1, r, cw)
  local pts = {}
  local corners = {{x1 - r, z1 - r, 0}, {x0 + r, z1 - r, 90}, {x0 + r, z0 + r, 180}, {x1 - r, z0 + r, 270}}
  for _, c in ipairs(corners) do
    for i = 0, 4 do
      local a = math.rad(c[3] + i * 22.5)
      pts[#pts + 1] = v2(c[1] + math.cos(a) * r, -(c[2] + math.sin(a) * r))
    end
  end
  -- that went counter-clockwise in xz, which is clockwise in (x, -z): reversed for an outline
  if not cw then
    local rev = {}
    for i = #pts, 1, -1 do rev[#rev + 1] = pts[i] end
    pts = rev
  end
  return pts
end
-- A rounded ring in the xz plane -- outer x0..x1, z0..z1, its hole hx0..hx1, hz0..hz1 -- from y up h.
local function ring(x0, x1, z0, z1, r, hx0, hx1, hz0, hz1, hr, y, h)
  local m = extrude(poly{points=rr_pts(x0, x1, z0, z1, r), holes={rr_pts(hx0, hx1, hz0, hz1, hr, true)}}, {distance=h})
  -- extrude centres the outline's bounds: put it back where it was drawn
  return at(m, (x0 + x1) / 2, y, (z0 + z1) / 2)
end

-- The toaster ----------------------------------------------------------------------------------------------------
-- Its shell: x ±0.47, z -0.78..0.6, from y -0.2 to 0.3, open in the middle round the cockpit (the driver's slot).
local TX, TZ0, TZ1, TY0, TY1 = 0.47, -0.78, 0.6, -0.2, 0.3
local HX, HZ0, HZ1 = 0.29, -0.55, 0.47
p[#p + 1] = {ring(-TX, TX, TZ0, TZ1, 0.16, -HX, HX, HZ0, HZ1, 0.08, TY0, TY1 - TY0), silver}
-- Its chrome waist band, and the chrome rim round the slot's mouth.
p[#p + 1] = {ring(-TX - 0.006, TX + 0.006, TZ0 - 0.006, TZ1 + 0.006, 0.166, -TX + 0.02, TX - 0.02, TZ0 + 0.02, TZ1 - 0.02, 0.14, 0.06, 0.03), chrome}
p[#p + 1] = {ring(-HX - 0.03, HX + 0.03, HZ0 - 0.03, HZ1 + 0.03, 0.1, -HX + 0.004, HX - 0.004, HZ0 + 0.004, HZ1 - 0.004, 0.076, TY1 - 0.004, 0.014), chrome}
-- Its black base, a plinth down onto the breadboard, open under the cockpit to the board.
p[#p + 1] = {ring(-0.4, 0.4, TZ0 + 0.04, TZ1 - 0.04, 0.12, -HX, HX, HZ0, HZ1, 0.08, -0.265, 0.07), dark}

-- A slice of bread's outline, { up, along } -- a loaf's top, wider than its sides -- counter-clockwise.
local function slice_outline(inset)
  local o = {}
  o[#o + 1] = v2(0, -0.2)
  for i = 0, 10 do
    local t = i / 10 * math.pi
    o[#o + 1] = v2(0.32 + math.sin(t) * 0.12, -math.cos(t) * 0.23)
  end
  o[#o + 1] = v2(0, 0.2)
  local pr = poly{points=o}
  if inset then pr = offset(pr, {distance=-inset}) end
  return pr
end
-- A slice standing in the yz plane at x, its foot at y: up its height, along z.
local function slice(x, y, z, inset, thick)
  local m = extrude(slice_outline(inset), {distance=thick})
  m = rotate(m, {angle=90, axis=axis_z(), pivot=origin()})
  return at(m, x + thick / 2, y + 0.22, z)
end
-- A whole slice: its crust, the toast standing proud a hair either face, browned darker at its middle.
local function toast_slice(x, y, z)
  return {
    {slice(x, y, z, nil, 0.06), crust},
    {slice(x, y, z, 0.025, 0.066), toast},
    {slice(x, y, z, 0.09, 0.07), brown},
  }
end

local SX = 0.38                       -- the toast slots, in the side walls either side of the driver
local foot = TY1 - 0.44 + 0.2 + P.pop -- a slice is 0.44 tall: 0.2 + pop of it above the slots
for _, side in ipairs({-1, 1}) do
  -- The slot in the top of the wall, and its slice.
  p[#p + 1] = {rbox(0.1, 0.012, 0.52, 0.03, side * SX, TY1 - 0.004, -0.22), chrome}
  p[#p + 1] = {bx(0.08, 0.01, 0.48, side * SX, TY1 + 0.004, -0.22), black}
  for _, s in ipairs(toast_slice(side * SX, foot, -0.22)) do s.sig = true; p[#p + 1] = s end
  -- The lever down its side, red-knobbed, the browning dial by it.
  p[#p + 1] = {rb(0.02, 0.3, 0.05, side * 0.475, 0.08, 0.3, 0.006), black}
  p[#p + 1] = {rbox(0.1, 0.05, 0.12, 0.03, side * 0.51, 0.14, 0.3, 0.012), red}
  p[#p + 1] = {cyl(0.055, 0.03, side * 0.485, -0.02, 0.05, "x", 18), black}
  p[#p + 1] = {rb(0.01, 0.06, 0.012, side * 0.502, 0.0, 0.05, 0.003), white}
  for i = 0, 4 do
    local a = math.rad(-60 + i * 30)
    p[#p + 1] = {bx(0.006, 0.012, 0.008, side * 0.472, -0.02 + math.cos(a) * 0.075, 0.05 + math.sin(a) * 0.075), white}
  end
end
-- A pat of butter melting on one slice.
local top = foot + 0.44
p[#p + 1] = {rb(0.08, 0.03, 0.08, SX, top + 0.017, -0.24, 0.008), C(1.0, 0.92, 0.45)}
p[#p + 1] = {ball(0.05, 0.008, 0.06, SX, top + 0.002, -0.24, 12), C(1.0, 0.85, 0.3)}

-- The bull: cream horns from its front top corners, tipped dark; angry brows, eyes, nostrils and a brass nose ring.
for _, side in ipairs({-1, 1}) do
  local horn = curve(10, function(t)
    local a = t * math.pi * 0.55
    return v3(side * (0.36 + math.sin(a) * 0.3 * P.horns), 0.22 + (1 - math.cos(a)) * 0.26 * P.horns, 0.5)
  end)
  -- (sweep's `scale` thins the whole tube in 0.8.0, not its end: the horn is tapered cones, a ball at each joint)
  for i = 1, #horn - 1 do
    local r0, r1 = 0.075 - (i - 1) * 0.0063, 0.075 - i * 0.0063
    p[#p + 1] = {cone_rod(horn[i], horn[i + 1], r0, r1, 12), C(0.98, 0.92, 0.78)}
    if i > 1 then p[#p + 1] = {ball(r0, r0, r0, horn[i].x, horn[i].y, horn[i].z, 10), C(0.98, 0.92, 0.78)} end
  end
  local tip = horn[#horn]
  p[#p + 1] = {ball(0.02, 0.02, 0.02, tip.x, tip.y, tip.z, 8), dark}
  p[#p + 1] = {ball(0.08, 0.05, 0.03, side * 0.36, 0.22, 0.5, 12), silver}
  p[#p + 1] = {turn(rb(0.16, 0.03, 0.02, 0, 0, 0, 0.006), side * -14, axis_z(), side * 0.17, 0.2, TZ1 + 0.005), black}
  p[#p + 1] = {ball(0.04, 0.05, 0.03, side * 0.17, 0.12, TZ1 - 0.004, 12), white}
  p[#p + 1] = {ball(0.022, 0.026, 0.02, side * 0.16, 0.11, TZ1 + 0.016, 10), black}
  p[#p + 1] = {ball(0.03, 0.022, 0.012, side * 0.07, -0.04, TZ1 + 0.002, 10), black}
end
p[#p + 1] = {at(torus{major_radius=0.06, minor_radius=0.012, major_segments=18, minor_segments=6, axis="z"}, 0, -0.1, TZ1 + 0.014), brass}

-- The cockpit: a slice of toast to sit on, another to lean on, and the steering column up out of the nose.
local seat = rotate(extrude(slice_outline(nil), {distance=0.048}), {angle=90, axis=axis_y(), pivot=origin()})
p[#p + 1] = {at(seat, 0, -0.268, -0.26), crust}
local seat_top = rotate(extrude(slice_outline(0.025), {distance=0.05}), {angle=90, axis=axis_y(), pivot=origin()})
p[#p + 1] = {at(seat_top, 0, -0.269, -0.26), toast}
for _, s in ipairs({{nil, 0.03, crust}, {0.025, 0.036, toast}}) do
  local back = rotate(slice(0, 0, 0, s[1], s[2]), {angle=90, axis=axis_y(), pivot=origin()})
  p[#p + 1] = {at(back, 0, -0.26, -0.52), s[3]}
end
p[#p + 1] = {rod(v3(0, -0.06, HZ1 + 0.02), v3(0, 0.1, 0.15), 0.022, 10), dark}
p[#p + 1] = {cyl(0.04, 0.03, 0, -0.06, HZ1 + 0.005, "z", 14), chrome}

-- The undercarriage ----------------------------------------------------------------------------------------------
-- The breadboard: a thick slab of wood, its juice groove round the top, its end grain down the sides, a handle out
-- the front with its hanging hole -- and a bread-bag clip snapped on that.
local BY = -0.3   -- the board's middle: its top -0.27, just under the plinth
p[#p + 1] = {rbox(0.8, 0.06, 1.86, 0.1, 0, BY - 0.03, -0.06, 0.012), board}
p[#p + 1] = {ring(-0.37, 0.37, -0.96, 0.84, 0.08, -0.355, 0.355, -0.945, 0.825, 0.066, BY + 0.027, 0.006), grain}
for i = 0, 2 do
  local y = BY - 0.018 + i * 0.018
  p[#p + 1] = {bx(0.006, 0.006, 1.5 - (i % 2) * 0.4, -0.4, y, -0.06 + (i - 1) * 0.1), grain}
  p[#p + 1] = {bx(0.006, 0.006, 1.5 - (i % 2) * 0.4, 0.4, y, -0.06 - (i - 1) * 0.1), grain}
end
p[#p + 1] = {rbox(0.3, 0.06, 0.26, 0.1, 0, BY - 0.03, 0.94, 0.012), board}
p[#p + 1] = {cyl(0.04, 0.064, 0, BY, 0.98, "y", 16), C(0.25, 0.15, 0.08)}
p[#p + 1] = {rbox(0.07, 0.012, 0.09, 0.015, 0.1, BY + 0.03, 0.96, 0.004), C(0.2, 0.45, 0.95)}
p[#p + 1] = {cyl(0.012, 0.016, 0.1, BY + 0.036, 0.97, "y", 8), board}

-- The chrome rails beneath it, a toaster rack's bent wire: two long runners, turned down at the front to hold the
-- knife, crossbars between them.
local RX, RY = 0.3, BY - 0.052
for _, side in ipairs({-1, 1}) do
  local x = side * RX
  p[#p + 1] = {tube({v3(x, RY + 0.02, -0.98), v3(x, RY, -0.9), v3(x, RY, 0.84), v3(x, RY - 0.03, 0.95), v3(x, -0.41, 1.0)}, 0.022, 10), chrome}
  -- Its hangers down to the axles, and the bosses the axles run through.
  for _, z in ipairs({-0.7, 0.7}) do
    p[#p + 1] = {rb(0.05, 0.1, 0.09, x, -0.395, z, 0.012), silver}
    p[#p + 1] = {cyl(0.05, 0.03, side * 0.41, -0.42, z, "x", 16), chrome}
  end
end
for _, z in ipairs({-0.45, 0.0, 0.45}) do p[#p + 1] = {rod(v3(-RX, RY, z), v3(RX, RY, z), 0.016, 8), chrome} end
-- The axles: bars across, out into the wheels' hubs.
for _, z in ipairs({-0.7, 0.7}) do p[#p + 1] = {cyl(0.028, 0.94, 0, -0.42, z, "x", 12), grey} end

-- The butter knife across the nose: a long silver blade, its rounded tip one way, its cream handle the other with
-- brass rivets, butter smeared along it.
local KZ, KY = 1.0, -0.41
p[#p + 1] = {rb(0.62, 0.065, 0.014, -0.08, KY, KZ, 0.005), silver}
p[#p + 1] = {ball(0.07, 0.0325, 0.007, -0.39, KY, KZ, 14), silver}
p[#p + 1] = {rb(0.6, 0.012, 0.016, -0.08, KY + 0.032, KZ, 0.004), chrome}
p[#p + 1] = {rbox(0.26, 0.05, 0.04, 0.018, 0.35, KY - 0.025, KZ, 0.01), C(0.95, 0.9, 0.76)}
p[#p + 1] = {rb(0.06, 0.04, 0.03, 0.22, KY, KZ, 0.008), silver}
for _, x in ipairs({0.3, 0.4}) do p[#p + 1] = {cyl(0.008, 0.046, x, KY, KZ, "z", 8), brass} end
p[#p + 1] = {ball(0.12, 0.022, 0.012, -0.12, KY - 0.005, KZ + 0.008, 14), C(1.0, 0.88, 0.4)}

-- The crumb tray pulled out the back from under the shell: a chrome drawer with a lip, crumbs in it, its handle.
local TZ = TZ0 - P.tray
p[#p + 1] = {rbox(0.586, 0.012, 0.586, 0.015, 0, BY + 0.032, TZ + 0.3), chrome}
p[#p + 1] = {ring(-0.3, 0.3, TZ, TZ + 0.6, 0.02, -0.29, 0.29, TZ + 0.01, TZ + 0.59, 0.012, BY + 0.031, 0.03), chrome}
for i = 0, 13 do
  local x = -0.24 + ((i * 37) % 13) / 13 * 0.48
  local z = TZ + 0.04 + ((i * 23) % 7) / 7 * math.max(0.02, P.tray - 0.08)
  local r = 0.01 + (i % 3) * 0.005
  p[#p + 1] = {ball(r, r * 0.6, r, x, BY + 0.045, z, 6), (i % 2 == 0) and crust or brown}
end
p[#p + 1] = {rb(0.3, 0.04, 0.035, 0, BY + 0.05, TZ - 0.02, 0.01), black}

-- A bread-bag twist-tie, wound round the rear axle, its twisted ends sticking up.
local tie = C(0.95, 0.15, 0.2)
for _, x in ipairs({0.16, 0.175}) do
  p[#p + 1] = {at(torus{major_radius=0.031, minor_radius=0.005, major_segments=14, minor_segments=5, axis="x"}, x, -0.42, -0.7), tie}
end
p[#p + 1] = {tube(curve(6, function(t) return v3(0.168 + math.sin(t * 9) * 0.006, -0.39 + t * 0.06, -0.7 + t * 0.03) end), 0.006, 6), tie}
p[#p + 1] = {tube(curve(6, function(t) return v3(0.168 - math.sin(t * 9) * 0.006, -0.39 + t * 0.055, -0.7 - t * 0.035) end), 0.006, 6), tie}

part("toaster", p)
