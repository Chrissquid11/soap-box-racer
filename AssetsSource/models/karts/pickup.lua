-- Old Faithful: a chunky toy 1950s pickup truck for a kart body, one part "pickup". Orange all over: a rounded bonnet
-- over the front wheels, flared wheel arches, a cab with open windows and a roof on pillars, a load bed behind it with
-- a tailgate; a grey grille of slots, round grey headlamps, yellow indicators, red round tail lamps and grey bumpers.
-- The driver sits in the cab on a black bucket seat, legs forward under the dashboard.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x ±0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x ±0.5, z ±0.7, y -0.42.
local p = params{
  roof_top = { default = 1.12, min = 1.0, max = 1.3, doc = "Height of the cab roof's top, metres" },
  bulge    = { default = 0.07, min = 0.0, max = 0.14, doc = "How far the bonnet's rounded hump stands above the body line, metres" },
  arch     = { default = 0.37, min = 0.3, max = 0.42, doc = "Wheel arch radius, metres" },
  slots    = { default = 3, min = 2, max = 4, integer = true, doc = "Rows of slots in the grille" },
}

-- One paint per colour, all alike but for it: merge (compatible) folds them into one white material with each
-- piece's colour on its vertices -- the same result as paint_faces on a white material, without a call per piece.
local paints = {}
local function paint_of(c)
  local key = string.format("%.3f_%.3f_%.3f", c.x, c.y, c.z)
  if not paints[key] then paints[key] = material{name="Paint_" .. key, base_color=c, roughness=0.55, metallic=0} end
  return paints[key]
end
-- A part of pieces, each { mesh, colour, angle }: each piece's normals smoothed, then all merged into one mesh with
-- its colours on its vertices.
local function part(name, pieces)
  local out = {}
  for i, q in ipairs(pieces) do
    out[i] = {mesh=smooth_normals(q[1], {angle=q[3] or 40}), material=paint_of(q[2])}
  end
  local merged = merge({parts=out, mode="compatible"})
  emit(merged[1].mesh, {name=name, material=merged[1].material})
  -- Its signature piece (the pieces marked true, 4th): `<name>_sig`, left out of the wreck (_sig.lua).
  local rest = include("_sig.lua").split(name, out, function(i) return pieces[i][4] end)
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
local function cyl(r, h, x, y, z, axis, seg) return at(cylinder{radius=r, height=h, segments=seg or 14, axis=axis or "y"}, x, y, z) end
local function sph(r, x, y, z, seg) return at(sphere{radius=r, segments=seg or 12, rings=math.floor((seg or 12) / 2)}, x, y, z) end
-- A flat oval, rx by ry in the xy plane, t thick along z, centred on the origin.
local function petal(rx, ry, t, n)
  local pts = {}
  n = n or 10
  for i = 0, n - 1 do
    local a = 2 * math.pi * i / n
    pts[#pts + 1] = v2(rx * math.cos(a), ry * math.sin(a))
  end
  return rotate(extrude(poly{points=pts}, {distance=t, anchor="center"}), {angle=90, axis=axis_x(), pivot=origin()})
end
local function along(m, a, b)
  local dir = normalize(b - a)
  local c = dot(v3(0, 1, 0), dir)
  if c < -0.9999 then m = rotate(m, {angle=180, axis=axis_x(), pivot=origin()})
  elseif c < 0.9999 then m = rotate(m, {angle=deg(math.acos(c)), axis=normalize(cross(v3(0, 1, 0), dir)), pivot=origin()}) end
  return translate(m, (a + b) * 0.5)
end
-- A round rod from a to b, a hair short of each.
local function rod(a0, b0, r, seg)
  local a, b = lerp(a0, b0, 0.004), lerp(a0, b0, 0.996)
  return along(cylinder{radius=r, height=length(b - a), segments=seg or 8}, a, b)
end
local function turn(m, angle, axis) return rotate(m, {angle=angle, axis=axis, pivot=origin()}) end
-- A closed polyhedron, its faces turned outward whichever way they were listed.
local function solid(vs, fs)
  local vol = 0
  for _, f in ipairs(fs) do
    for k = 2, #f - 1 do vol = vol + dot(vs[f[1]], cross(vs[f[k]], vs[f[k + 1]])) end
  end
  if vol < 0 then
    local rf = {}
    for i, f in ipairs(fs) do
      local r = {}
      for k = #f, 1, -1 do r[#r + 1] = f[k] end
      rf[i] = r
    end
    fs = rf
  end
  return polyhedron{vertices=vs, faces=fs}
end
-- A flat plate of a convex outline { {x, y}, ... } in the xy plane, from z0 to z1.
local function plate(pts, z0, z1)
  local vs, fs, n = {}, {}, #pts
  for _, q in ipairs(pts) do vs[#vs + 1] = v3(q[1], q[2], z0) end
  for _, q in ipairs(pts) do vs[#vs + 1] = v3(q[1], q[2], z1) end
  local a, b = {}, {}
  for i = 1, n do a[i] = n + 1 - i; b[i] = n + i end
  fs[1], fs[2] = a, b
  for i = 1, n do
    local j = i % n + 1
    fs[#fs + 1] = {i, j, n + j, n + i}
  end
  return solid(vs, fs)
end

local orange    = C(0.95, 0.3, 0.03)
local orange_dk = C(0.7, 0.2, 0.02)
local orange_lt = C(1.0, 0.4, 0.08)
local grey      = C(0.6, 0.62, 0.65)
local grey_dk   = C(0.38, 0.4, 0.43)
local lens      = C(0.82, 0.84, 0.86)
local dark      = C(0.05, 0.05, 0.06)
local seat_c    = C(0.07, 0.07, 0.08)
local yellow    = C(1.0, 0.8, 0.05)
local red       = C(0.78, 0.02, 0.02)
-- Patched up: grey primer on a replacement panel, rusty tin patches, silver duct tape, a plank, rope.
local primer    = C(0.56, 0.56, 0.52)
local tin       = C(0.5, 0.3, 0.16)
local rivet     = C(0.3, 0.3, 0.32)
local tape      = C(0.76, 0.77, 0.79)
local wood      = C(0.58, 0.4, 0.2)
local rope      = C(0.78, 0.64, 0.38)

local pieces = {}
local function add(m, c, a, sig) pieces[#pieces + 1] = {m, c, a, sig} end

local W = 1.16
local HW = W / 2
local ZB, ZF = -1.32, 1.2          -- the body's back and front faces
local ZC, L = (ZB + ZF) / 2, ZF - ZB
local BOT, BELT = -0.4, 0.28       -- the body's bottom and its belt line
local ROOF = p.roof_top
local FOOT = ROOF - 0.12           -- where the roof sits on the cab
local ZI0, ZI1 = ZB + 0.06, 0.5    -- the hollow of the cab and bed, along z

-- The body: one orange tub, hollow over the cab and the bed, solid under the bonnet, the wheel arches cut out.
do
  local outer = rbox(W, BELT - BOT, L, 0.14, 0, BOT, ZC, 0.05)
  local inner = rbox(W - 0.12, 1.0, ZI1 - ZI0, 0.08, 0, BOT + 0.1, (ZI0 + ZI1) / 2)
  -- the front wheels share one tunnel under the bonnet; the back ones open into the bed
  local cuts = {inner, cyl(p.arch, W + 0.2, 0, -0.42, 0.7, "x", 22)}
  for _, sx in ipairs({-1, 1}) do
    cuts[#cuts + 1] = cyl(p.arch, 0.4, sx * 0.6, -0.42, -0.7, "x", 22)
  end
  add(subtract(outer, table.unpack(cuts)), orange)
  -- flared arches: a half ring standing proud round each
  for _, sx in ipairs({-1, 1}) do
    for _, z in ipairs({-0.7, 0.7}) do
      local f = subtract(cylinder{radius=p.arch + 0.075, height=0.075, segments=22, axis="x"},
        cylinder{radius=p.arch - 0.005, height=0.2, segments=22, axis="x"}, bx(0.2, 1, 1.2, 0, -0.5 - 0.02, 0))
      -- (one of them a scrapyard replacement, never painted)
      add(at(f, sx * (HW - 0.01), -0.42, z), (sx > 0 and z < 0) and primer or orange)
    end
  end
  -- the wall between the cab and the bed, under the belt
  add(rb(W - 0.1, BELT - BOT - 0.12, 0.05, 0, (BOT + BELT) / 2 + 0.04, -0.655, 0.01), orange)
end

-- The bonnet: a rounded hump over the front, a crease down its middle.
add(rbox(W - 0.08, 0.1 + p.bulge, 0.66, 0.24, 0, BELT - 0.08, 0.86, 0.06), orange)
add(rb(0.03, 0.02, 0.6, 0, BELT + 0.02 + p.bulge, 0.86, 0.008), orange_lt)

-- The cab: walls round open windows, a windscreen and a back window, a roof on top with a visor lip.
do
  local zc, d = -0.07, 1.22
  local outer = rbox(W - 0.04, FOOT + 0.02 - (BELT - 0.02), d, 0.1, 0, BELT - 0.02, zc)
  local inner = rbox(W - 0.14, 2, d - 0.1, 0.06, 0, BELT - 0.5, zc)
  local y0, y1 = BELT + 0.1, FOOT - 0.06
  local ym, h = (y0 + y1) / 2, y1 - y0
  add(subtract(outer, inner,
    bx(W + 0.2, h, 0.96, 0, ym, -0.08),            -- the side windows, through both sides
    bx(0.86, h, 0.3, 0, ym, zc + d / 2),           -- the windscreen
    bx(0.8, h * 0.8, 0.3, 0, ym - h * 0.05, zc - d / 2)), orange)
  add(rbox(W, ROOF - FOOT + 0.02, d + 0.1, 0.12, 0, FOOT - 0.02, zc + 0.02, 0.045), orange)
end

-- The front: a grey grille of slots in a frame, round grey headlamps, yellow indicators, a grey bumper.
do
  local gy = -0.11
  add(rb(0.74, 0.27, 0.04, 0, gy, ZF + 0.005, 0.015, 2), grey)
  add(rb(0.64, 0.19, 0.03, 0, gy, ZF + 0.016, 0.012), dark)
  local n = p.slots
  for r = 1, n do
    local y = gy + (r - (n + 1) / 2) * (0.16 / n)
    for _, x in ipairs({-0.2, 0, 0.2}) do add(rb(0.15, 0.022, 0.02, x, y, ZF + 0.03, 0.007), grey) end
  end
  for _, sx in ipairs({-1, 1}) do
    if sx > 0 then
      add(cyl(0.085, 0.06, sx * 0.4, 0.1, ZF - 0.0, "z", 18), grey_dk)
      add(sph(0.11, sx * 0.4, 0.1, ZF + 0.03 - 0.085, 14), lens)
    else
      -- The other lamp long gone: a bicycle lamp taped into the empty hole.
      add(cyl(0.085, 0.03, sx * 0.4, 0.1, ZF - 0.01, "z", 18), dark)
      add(cyl(0.045, 0.1, sx * 0.4, 0.1, ZF + 0.04, "z", 12), yellow)
      add(cyl(0.035, 0.012, sx * 0.4, 0.1, ZF + 0.095, "z", 12), lens)
      add(rb(0.2, 0.03, 0.012, sx * 0.4, 0.1, ZF + 0.045, 0.004), tape)
      add(rb(0.03, 0.2, 0.012, sx * 0.4, 0.1, ZF + 0.047, 0.004), tape)
    end
    add(sph(0.032, sx * 0.4, -0.215, ZF + 0.005, 10), yellow)
  end
  -- The bumper fell off years ago: a scaffold plank roped on in its place.
  add(rb(W + 0.1, 0.1, 0.06, 0, -0.34, ZF + 0.05, 0.012), wood)
  for _, sx in ipairs({-1, 1}) do
    for k = 0, 2 do add(cyl(0.058, 0.014, sx * (0.38 + k * 0.02), -0.34, ZF + 0.05, "x", 10), rope) end
  end
end

-- The back: the tailgate's panel (the signature piece), red round tail lamps in grey rims, a grey bumper.
do
  add(rb(0.8, 0.34, 0.02, 0, -0.02, ZB - 0.005, 0.008), orange_dk, nil, true)
  add(rb(0.76, 0.3, 0.02, 0, -0.02, ZB - 0.012, 0.008), orange, nil, true)
  for _, sx in ipairs({-1, 1}) do
    add(cyl(0.065, 0.04, sx * 0.47, 0.06, ZB - 0.005, "z", 18), grey)
    add(cyl(0.05, 0.04, sx * 0.47, 0.06, ZB - 0.018, "z", 18), red)
  end
  add(rb(W + 0.06, 0.09, 0.1, 0, -0.34, ZB - 0.05, 0.03, 2), grey)
  -- ribs along the bed's floor
  for _, x in ipairs({-0.3, -0.1, 0.1, 0.3}) do add(rb(0.04, 0.02, 0.56, x, BOT + 0.105, -0.98, 0.008), orange_dk) end
end

-- The bodges: tin patches riveted over the rust holes (the bonnet, the bed's side, under the cab), duct tape over a
-- crack in a front arch and a split in the roof's edge, and the driver's door a primer-grey replacement.
do
  local function patch(w, h, x, y, z, side, c)
    -- A square of tin flat on a side (side = +-1: x faces) or on top (side = 0), four rivets at its corners.
    if side == 0 then
      add(rb(w, 0.008, h, x, y, z, 0.003), c or tin)
      for _, dx in ipairs({-1, 1}) do for _, dz in ipairs({-1, 1}) do
        add(sph(0.011, x + dx * (w / 2 - 0.02), y + 0.005, z + dz * (h / 2 - 0.02), 6), rivet)
      end end
    else
      add(rb(0.008, h, w, x, y, z, 0.003), c or tin)
      for _, dy in ipairs({-1, 1}) do for _, dz in ipairs({-1, 1}) do
        add(sph(0.011, x + side * 0.005, y + dy * (h / 2 - 0.02), z + dz * (w / 2 - 0.02), 6), rivet)
      end end
    end
  end
  patch(0.22, 0.18, 0.24, BELT + 0.03 + p.bulge * 0.6, 0.95, 0)
  patch(0.24, 0.16, HW + 0.006, 0.0, -1.0, 1)
  patch(0.16, 0.12, -(HW + 0.006), -0.22, 0.05, -1)
  patch(0.14, 0.1, -(HW + 0.006), 0.12, -1.1, -1, primer)
  -- duct tape: a cross over a crack in the front left arch, a strip along the roof's back edge
  local ax, ay, az = -(HW + 0.03), -0.42 + p.arch + 0.04, 0.7
  add(turn(rb(0.012, 0.035, 0.22, 0, 0, 0, 0.004), 35, axis_x()), tape)
  pieces[#pieces][1] = at(pieces[#pieces][1], ax, ay, az)
  add(turn(rb(0.012, 0.035, 0.22, 0, 0, 0, 0.004), -35, axis_x()), tape)
  pieces[#pieces][1] = at(pieces[#pieces][1], ax, ay, az)
  add(rb(0.7, 0.012, 0.05, 0.05, ROOF + 0.004, -0.07 - 0.62, 0.004), tape)
  -- the driver's (left) door: a grey primer replacement panel over the orange
  add(rb(0.01, BELT - 0.03 + 0.29, 0.6, -(HW + 0.007), (BELT - 0.03 - 0.31) / 2 + 0.005, 0.01, 0.003), primer)
end

-- The doors: an outline on each side under the window, a grey handle.
for _, sx in ipairs({-1, 1}) do
  local x = sx * (HW + 0.002)
  local z0, z1, y0, y1 = -0.3, 0.32, -0.3, BELT - 0.03
  add(bx(0.014, y1 - y0, 0.014, x, (y0 + y1) / 2, z0), orange_dk)
  add(bx(0.014, y1 - y0, 0.014, x, (y0 + y1) / 2, z1), orange_dk)
  add(bx(0.014, 0.014, z1 - z0 + 0.014, x, y0, (z0 + z1) / 2), orange_dk)
  add(rb(0.03, 0.025, 0.12, sx * (HW + 0.012), 0.16, -0.18, 0.008), grey)
end

-- Inside: a black bucket seat, the dashboard, the steering column.
add(rbox(0.48, 0.1, 0.44, 0.08, 0, BOT + 0.09, -0.3, 0.02), seat_c)
do
  local m = rb(0.48, 0.66, 0.1, 0, 0, 0, 0.03, 2)
  m = turn(translate(m, v3(0, 0.33, 0)), -8, axis_x())
  add(at(m, 0, -0.24, -0.6), seat_c)
  for _, sx in ipairs({-1, 1}) do
    local b = turn(translate(rb(0.08, 0.4, 0.14, 0, 0, 0, 0.02), v3(0, 0.2, 0)), -8, axis_x())
    add(at(turn(b, sx * 20, axis_y()), sx * 0.22, -0.2, -0.58), seat_c)
  end
end
add(rb(W - 0.16, 0.16, 0.08, 0, 0.18, 0.5, 0.02), orange_dk)
add(rod(v3(0, 0.1, 0.15), v3(0, -0.02, 0.47), 0.022, 10), dark)
add(cyl(0.035, 0.05, 0, 0.08, 0.17, "z", 10), dark)

-- Underneath: axle crossbars, stubs to the hubs, two rails.
for _, z in ipairs({-0.7, 0.7}) do
  add(rod(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.03, 10), dark)
  for _, sx in ipairs({-1, 1}) do
    add(rod(v3(sx * 0.46, -0.42, z), v3(sx * 0.535, -0.42, z), 0.02, 10), grey)
    add(cyl(0.036, 0.03, sx * 0.47, -0.42, z, "x", 8), grey_dk)
  end
end
for _, sx in ipairs({-1, 1}) do add(rb(0.06, 0.05, 2.2, sx * 0.3, -0.425, ZC, 0.012), dark) end

part("pickup", pieces)
