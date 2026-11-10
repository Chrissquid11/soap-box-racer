-- Tin Can Tesseract: a homemade "futuristic electric truck" for a kart body, one part "steeltruck". A flat-panelled
-- brushed-steel wedge riveted together from sheet: an angular tub with a faceted crease down each side, a flat bonnet
-- under a sloping tinted windscreen, triangular side sails with dark tinted windows rising to a crossbar behind the
-- driver, an open cockpit and a load bed behind it, dark angular wheel-arch trims, a light strip across the nose and a
-- red one across the tailgate. The panels sit slightly askew and every seam is riveted.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x ±0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x ±0.5, z ±0.7, y -0.42.
local p = params{
  apex    = { default = 0.92, min = 0.8, max = 1.1, doc = "Height of the side sails' peak and the crossbar behind the driver, metres" },
  wobble  = { default = 1.2, min = 0, max = 3, doc = "How askew the hand-cut side panels sit, degrees" },
  rivets  = { default = 0.11, min = 0.07, max = 0.2, doc = "Spacing of the rivets along the seams, metres" },
  arch    = { default = 1.0, min = 0.85, max = 1.15, doc = "Size of the angular wheel arches, a share of their usual" },
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
  -- Its signature piece (the pieces marked, 4th): `<name>_sig`, and left out of the wreck (_sig.lua).
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

local steel    = C(0.64, 0.65, 0.67)
local steel_a  = C(0.58, 0.59, 0.61)
local steel_b  = C(0.7, 0.71, 0.72)
local steel_dk = C(0.42, 0.43, 0.45)
local trim     = C(0.13, 0.13, 0.14)
local glass    = C(0.16, 0.09, 0.08)
local rivet_c  = C(0.5, 0.51, 0.53)
local dark     = C(0.05, 0.05, 0.06)
local seat_c   = C(0.07, 0.07, 0.08)
local lamp     = C(0.95, 0.95, 0.9)
local red      = C(0.78, 0.03, 0.03)

local pieces = {}
-- While `sig` is true, what is added is the signature piece: the +x side's sail, flung off when the bodywork goes.
local sig = false
local function add(m, c, a) pieces[#pieces + 1] = {m, c, a or 20, sig} end

-- A prism of an outline { {z, y}, ... } (convex) in the side plane, from x0 to x1.
local function prism_x(pts, x0, x1)
  local vs, fs, n = {}, {}, #pts
  for _, q in ipairs(pts) do vs[#vs + 1] = v3(x0, q[2], q[1]) end
  for _, q in ipairs(pts) do vs[#vs + 1] = v3(x1, q[2], q[1]) end
  local a, b = {}, {}
  for i = 1, n do a[i] = n + 1 - i; b[i] = n + i end
  fs[1], fs[2] = a, b
  for i = 1, n do
    local j = i % n + 1
    fs[#fs + 1] = {i, j, n + j, n + i}
  end
  return solid(vs, fs)
end

local ZB, ZF = -1.32, 1.18           -- the tub's back and the front of its full section
local NOSE = 1.3
local BOT = -0.38
local HW, HWB, HWT = 0.58, 0.5, 0.54  -- half widths: the sides, the bottom, the top
local APEX = p.apex
local AZ = -0.6                      -- the sails' peak, along z: behind the driver's head
local function belt(z) return 0.17 + (ZF - z) / (ZF - ZB) * 0.2 end

-- The tub: an angular solid, a chamfer along its top and bottom edges, the nose sloped and narrowed.
do
  local ST = {
    {NOSE, -0.26, 0.02, 0.86},
    {ZF, BOT, belt(ZF), 1},
    {ZB, BOT, belt(ZB), 1},
  }
  local vs, fs = {}, {}
  for _, s in ipairs(ST) do
    local z, yb, yt, k = s[1], s[2], s[3], s[4]
    local c = 0.07 * k
    local ring = {
      {-HWB * k, yb}, {HWB * k, yb}, {HW * k, yb + c * 1.6}, {HW * k, yt - c}, {HWT * k, yt}, {-HWT * k, yt},
      {-HW * k, yt - c}, {-HW * k, yb + c * 1.6},
    }
    for _, q in ipairs(ring) do vs[#vs + 1] = v3(q[1], q[2], z) end
  end
  for i = 0, #ST - 2 do
    for j = 0, 7 do
      local j2 = (j + 1) % 8
      fs[#fs + 1] = {i * 8 + j + 1, i * 8 + j2 + 1, (i + 1) * 8 + j2 + 1, (i + 1) * 8 + j + 1}
    end
  end
  local a, b = {}, {}
  for j = 1, 8 do a[j] = 9 - j; b[j] = (#ST - 1) * 8 + j end
  fs[#fs + 1] = a
  fs[#fs + 1] = b
  local body = solid(vs, fs)
  -- the cockpit and the bed hollowed out of it; angular arches out of its sides
  local cuts = {bx(2 * (HW - 0.07), 2, 0.45 - (ZB + 0.06), 0, BOT + 0.1 + 1, (0.45 + ZB + 0.06) / 2)}
  local A = p.arch
  for _, sx in ipairs({-1, 1}) do
    for _, z in ipairs({-0.7, 0.7}) do
      local x0, x1 = sx * 0.38, sx * 0.8
      cuts[#cuts + 1] = prism_x({{z - 0.48 * A, -0.6}, {z + 0.48 * A, -0.6}, {z + 0.3 * A, -0.42 + 0.4 * A}, {z - 0.3 * A, -0.42 + 0.4 * A}},
        math.min(x0, x1), math.max(x0, x1))
    end
  end
  add(subtract(body, table.unpack(cuts)), steel)
  -- the arches: dark angular trims standing proud round them, dark liners inside
  for _, sx in ipairs({-1, 1}) do
    for _, z in ipairs({-0.7, 0.7}) do
      local o = prism_x({{z - 0.58 * A, -0.6}, {z + 0.58 * A, -0.6}, {z + 0.36 * A, -0.42 + 0.47 * A}, {z - 0.36 * A, -0.42 + 0.47 * A}}, 0, 0.055)
      local i = prism_x({{z - 0.48 * A, -0.7}, {z + 0.48 * A, -0.7}, {z + 0.3 * A, -0.42 + 0.4 * A}, {z - 0.3 * A, -0.42 + 0.4 * A}}, -0.1, 0.2)
      local t = subtract(o, i, bx(0.4, 0.4, 2, 0.02, BOT - 0.2 - 0.015, z))
      if sx < 0 then t = mirror(t, {normal=axis_x(), pivot=origin()}) end
      add(at(t, sx * (HW - 0.02), 0, 0), trim)
      local l = prism_x({{z - 0.48 * A + 0.01, BOT + 0.005}, {z + 0.48 * A - 0.01, BOT + 0.005}, {z + 0.3 * A - 0.01, -0.43 + 0.4 * A}, {z - 0.3 * A + 0.01, -0.43 + 0.4 * A}},
        sx * 0.383, sx * 0.395)
      add(l, trim)
    end
  end
end

-- The side panels: hand-cut sheets riveted on, each a touch askew, each its own shade of steel.
local function sheet(z0, z1, y0, y1, sx, tilt, c)
  local m = box{size=v3(0.008, y1 - y0, z1 - z0)}
  m = rotate(m, {angle=tilt, axis=axis_y(), pivot=origin()})
  m = rotate(m, {angle=tilt * 0.6, axis=axis_x(), pivot=origin()})
  add(at(m, sx * (HW + 0.004), (y0 + y1) / 2, (z0 + z1) / 2), c)
end
local w = p.wobble
for _, sx in ipairs({-1, 1}) do
  sheet(-0.3, 0.26, -0.24, belt(0.26) - 0.07, sx, w * sx, steel_a)          -- the door
  sheet(0.34, 1.08, 0.0, belt(1.08) - 0.025, sx, -w * 0.7 * sx, steel_b)     -- the front wing
  sheet(-1.22, -0.36, 0.0, belt(-0.36) - 0.05, sx, w * 0.5 * sx, steel_b)   -- the rear quarter
end

-- Rivets along the seams: little domes in rows.
local SP = p.rivets
local function rivet(x, y, z) add(sph(0.011, x, y, z, 6), rivet_c, 60) end
local function row(a, b, sx)
  local n = math.max(1, math.floor(length(b - a) / SP + 0.5))
  for i = 0, n do
    local q = lerp(a, b, i / n)
    rivet(q.x, q.y, q.z)
  end
end
for _, sx in ipairs({-1, 1}) do
  local x = sx * (HW + 0.009)
  row(v3(x, belt(1.1) - 0.035, 1.1), v3(x, belt(-1.25) - 0.035, -1.25), sx)
  for _, z in ipairs({-0.33, 0.3}) do row(v3(x, -0.25, z), v3(x, belt(z) - 0.06, z), sx) end
  row(v3(x, -0.27, -0.24), v3(x, -0.27, 0.2), sx)
end
row(v3(-0.4, belt(ZB) - 0.04, ZB - 0.009), v3(0.4, belt(ZB) - 0.04, ZB - 0.009))
row(v3(-0.4, -0.3, ZB - 0.009), v3(0.4, -0.3, ZB - 0.009))
row(v3(-0.36, -0.02, NOSE + 0.004), v3(0.36, -0.02, NOSE + 0.004))

-- The sails: triangular sheets up each side from the belt to the peak, leaning in, tinted windows let into them.
do
  local F, R = 0.97, ZB + 0.04
  local function lean(y) return HW - 0.025 - 0.07 * (y - belt(0)) / (APEX - belt(0)) end
  local function tri(pts, x_off, t)
    -- pts: three {z, y}; a sheet t thick, its outside at lean(y) + x_off
    local vs = {}
    for _, q in ipairs(pts) do vs[#vs + 1] = v3(lean(q[2]) + x_off, q[2], q[1]) end
    for _, q in ipairs(pts) do vs[#vs + 1] = v3(lean(q[2]) + x_off - t, q[2], q[1]) end
    return solid(vs, {{1, 2, 3}, {6, 5, 4}, {1, 4, 5, 2}, {2, 5, 6, 3}, {3, 6, 4, 1}})
  end
  local f, a, r = {F, belt(F) - 0.03}, {AZ, APEX}, {R, belt(R) - 0.03}
  local foot = {AZ, belt(AZ) - 0.03}
  local function shrink(t, k)
    local cz, cy = (t[1][1] + t[2][1] + t[3][1]) / 3, (t[1][2] + t[2][2] + t[3][2]) / 3
    local o = {}
    for i, q in ipairs(t) do o[i] = {cz + (q[1] - cz) * k, cy + (q[2] - cy) * k} end
    return o
  end
  for _, sx in ipairs({-1, 1}) do
    local function put(m) if sx < 0 then m = mirror(m, {normal=axis_x(), pivot=origin()}) end; return m end
    sig = sx > 0
    add(put(tri({f, a, r}, 0, 0.03)), steel)
    add(put(tri(shrink({f, a, foot}, 0.74), 0.006, 0.01)), glass)
    add(put(tri(shrink({foot, a, r}, 0.7), 0.006, 0.01)), glass)
    -- rivets along the sail's top edges
    for _, e in ipairs({{f, a}, {a, r}}) do
      local n = math.max(1, math.floor(math.sqrt((e[1][1] - e[2][1]) ^ 2 + (e[1][2] - e[2][2]) ^ 2) / SP + 0.5))
      for i = 1, n - 1 do
        local z = e[1][1] + (e[2][1] - e[1][1]) * i / n
        local y = e[1][2] + (e[2][2] - e[1][2]) * i / n - 0.03
        rivet(sx * (lean(y) + 0.004), y, z)
      end
    end
    sig = false
  end
  -- the crossbar between the peaks, behind the driver's head
  local xl = lean(APEX) - 0.02
  add(rb(2 * xl, 0.07, 0.09, 0, APEX - 0.045, AZ, 0.012), steel_dk)
  -- the windscreen: a tinted sheet sloping up from the bonnet, in line with the sails' front edges, in a steel frame
  local z0, z1 = F - 0.02, 0.5
  local y0 = belt(z0) + 0.005
  local y1 = belt(F) - 0.03 + (APEX - belt(F) + 0.03) * (F - z1) / (F - AZ) - 0.02
  local xw = 0.46
  local function slab(xa, za, ya, zb, yb, t, c)
    local vs = {
      v3(-xa, ya, za), v3(xa, ya, za), v3(xa, yb, zb), v3(-xa, yb, zb),
      v3(-xa, ya - t, za), v3(xa, ya - t, za), v3(xa, yb - t, zb), v3(-xa, yb - t, zb),
    }
    add(solid(vs, {{1, 2, 3, 4}, {8, 7, 6, 5}, {1, 5, 6, 2}, {2, 6, 7, 3}, {3, 7, 8, 4}, {4, 8, 5, 1}}), c)
  end
  slab(xw + 0.04, z0 + 0.02, y0 - 0.005, z1 - 0.03, y1 + 0.01, 0.03, steel_dk)
  slab(xw, z0, y0 + 0.004, z1, y1 + 0.004, 0.012, glass)
  -- the bonnet's lid: a sheet over the front, a light strip across the nose
  slab(0.42, NOSE - 0.012, 0.025, ZF, belt(ZF) + 0.006, 0.014, steel_a)
  slab(0.48, ZF, belt(ZF) + 0.006, z0 + 0.01, belt(z0 + 0.01) + 0.006, 0.014, steel_a)
  add(rb(0.84, 0.025, 0.02, 0, -0.08, NOSE + 0.005, 0.006), lamp)
end

-- The back: the tailgate's sheet, a red light strip across its top, the bed's floor and the wall behind the seat.
do
  add(rb(0.92, 0.42, 0.01, 0, -0.06, ZB - 0.004, 0.003), steel_a)
  add(rb(0.98, 0.03, 0.02, 0, belt(ZB) - 0.04, ZB - 0.008, 0.006), red)
  add(rb(2 * (HW - 0.08), 0.015, -0.72 - (ZB + 0.06), 0, BOT + 0.105, (ZB + 0.06 - 0.72) / 2, 0.004), steel_dk)
  add(rb(2 * (HW - 0.08), belt(-0.72) + 0.06 - (BOT + 0.1), 0.03, 0, (belt(-0.72) + 0.06 + BOT + 0.1) / 2, -0.735, 0.006), steel)
  add(rb(0.12, 0.08, 0.04, 0, -0.32, ZB - 0.02, 0.01), trim)
end

-- Inside: a black bucket seat with a headrest, a dark dashboard, the steering column.
add(rbox(0.48, 0.08, 0.44, 0.08, 0, BOT + 0.08, -0.3, 0.02), seat_c)
do
  local m = rb(0.46, 0.78, 0.1, 0, 0, 0, 0.03, 2)
  m = turn(translate(m, v3(0, 0.39, 0)), -8, axis_x())
  add(at(m, 0, -0.24, -0.62), seat_c)
  for _, sx in ipairs({-1, 1}) do
    local b = turn(translate(rb(0.08, 0.42, 0.14, 0, 0, 0, 0.02), v3(0, 0.21, 0)), -8, axis_x())
    add(at(turn(b, sx * 20, axis_y()), sx * 0.22, -0.2, -0.6), seat_c)
  end
end
add(rb(2 * (HW - 0.08), 0.14, 0.1, 0, 0.12, 0.5, 0.02), trim)
add(rod(v3(0, 0.1, 0.15), v3(0, 0.02, 0.47), 0.022, 10), dark)
add(cyl(0.035, 0.05, 0, 0.08, 0.17, "z", 10), dark)

-- Underneath: axle crossbars, stubs to the hubs, two rails.
for _, z in ipairs({-0.7, 0.7}) do
  add(rod(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.03, 10), dark)
  for _, sx in ipairs({-1, 1}) do
    add(rod(v3(sx * 0.46, -0.42, z), v3(sx * 0.535, -0.42, z), 0.02, 10), steel_dk)
    add(cyl(0.036, 0.03, sx * 0.47, -0.42, z, "x", 8), steel)
  end
end
for _, sx in ipairs({-1, 1}) do add(rb(0.06, 0.05, 2.2, sx * 0.3, -0.405, -0.05, 0.012), dark) end

part("steeltruck", pieces)
