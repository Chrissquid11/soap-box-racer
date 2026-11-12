-- Bog Standard Racing: a toilet for a kart body, one part "toilet". The driver sits in a big egg-shaped porcelain bowl
-- (its pedestal set back under it, the nose overhanging) with a teal seat ring round its top; the seat's lid stands
-- open behind them as the seat back, hinged in chrome. The cistern stands tall at the back -- flared, with a crowned
-- teal lid, a teal band, a chrome flush lever, a pink toilet roll on its side trailing paper and a roundel on its
-- back for the chase camera: it is the signature piece (`toilet_sig`). Under it all a square-tube aluminium frame; a
-- red plunger stuck on the bowl's nose and a blue toilet brush for a front bumper. In the kart's body space: the
-- origin the middle of the chassis' top, +z forward, metres. The chassis box is hidden under this body, so the frame
-- here is the kart's own; the wheels (x +-0.5, z +-0.7, y -0.42) and the steering wheel come from other slots.
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
-- A mesh made along a to b: m modelled along +y, its length `length(b - a)`, turned onto the line and centred on it.
local function along(m, a, b)
  local dir = normalize(b - a)
  local c = dot(v3(0, 1, 0), dir)
  if c < -0.9999 then m = rotate(m, {angle=180, axis=axis_x(), pivot=origin()})
  elseif c < 0.9999 then m = rotate(m, {angle=deg(math.acos(c)), axis=normalize(cross(v3(0, 1, 0), dir)), pivot=origin()}) end
  return translate(m, (a + b) * 0.5)
end
-- A round rod from a to b, a hair short of each (two rods meeting end to end must not share a vertex).
local function rod(a0, b0, r, seg)
  local a, b = lerp(a0, b0, 0.004), lerp(a0, b0, 0.996)
  return along(cylinder{radius=r, height=length(b - a), segments=seg or 8}, a, b)
end
-- A square tube from a to b, s across; `plain` leaves its long edges sharp (the thin ones: a bevel there is not seen).
local function bar(a0, b0, s, plain)
  local a, b = lerp(a0, b0, 0.002), lerp(a0, b0, 0.998)
  local m = box{size=v3(s, length(b - a), s)}
  if plain then return along(m, a, b) end
  local long = edges_where(m, function(e) return math.abs(e.direction.y) > 0.9 end)
  local edges = set_subtract(long, set_subtract(long, convex_edges(m, {min_angle=60})))
  return along(bevel(m, {edges=edges, width=s * 0.18, segments=1}), a, b)
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

-- The toilet's own -----------------------------------------------------------------------------------------------
local p = params{
  rim_height  = { default = 0.11, min = 0.07, max = 0.15, doc = "Thickness of the teal seat ring round the bowl, metres" },
  tank_top    = { default = 0.75, min = 0.55, max = 0.9, doc = "Height of the cistern's lid top, metres" },
  bristles    = { default = 66, min = 40, max = 140, integer = true, doc = "Bristles on the brush head" },
  brush_reach = { default = 1.06, min = 0.95, max = 1.2, doc = "How far forward the brush head sits, metres" },
  nose_taper  = { default = 0.15, min = 0, max = 0.25, doc = "How much the bowl narrows to its nose (0: an oval tub)" },
  plunger     = { default = true, doc = "A plunger stuck on the bowl's nose" },
  paper_tail  = { default = 0.12, min = 0.05, max = 0.14, doc = "How far the toilet roll's paper trails behind the cistern, metres" },
}

local porcelain = C(0.95, 0.95, 0.92)
local shadow    = C(0.80, 0.83, 0.84)    -- porcelain in the shade: the foot, the cistern's underside
local teal      = C(0.04, 0.62, 0.53)
local teal_dk   = shade(teal, 0.72)
local teal_lt   = C(0.25, 0.78, 0.68)
local blue      = C(0.04, 0.22, 0.85)
local blue_lt   = C(0.12, 0.38, 0.95)
local alu       = C(0.66, 0.68, 0.72)
local rubber    = C(0.84, 0.16, 0.12)
local rubber_dk = shade(rubber, 0.72)
local wood      = C(0.80, 0.58, 0.33)
local pink      = C(1.0, 0.72, 0.78)
local card      = C(0.62, 0.45, 0.28)

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

-- A ring-swept oval solid: each ring { a, b, y, dz } a superellipse (exponent n) a across x and b along z at height
-- y, its middle dz along z from the solid's (0 when left out), the rings joined in order; `closed` joins the last to
-- the first (a tube round the oval), else the first and last rings are capped flat. `taper` narrows the front (+z)
-- end, as a toilet bowl's is.
local function oval(rings, opt)
  local n, seg, cz, tp = opt.n or 3, opt.seg or 64, opt.z or 0, opt.taper or 0
  local vs, fs = {}, {}
  for _, r in ipairs(rings) do
    for j = 0, seg - 1 do
      local t = 2 * math.pi * j / seg
      local c, s = math.cos(t), math.sin(t)
      local cx = (c < 0 and -1 or 1) * math.abs(c) ^ (2 / n)
      local sz = (s < 0 and -1 or 1) * math.abs(s) ^ (2 / n)
      local k = 1 - tp * math.max(0, sz) ^ 2
      vs[#vs + 1] = v3(r[1] * cx * k, r[3], cz + (r[4] or 0) + r[2] * sz)
    end
  end
  local R = #rings
  local function id(i, j) return (i % R) * seg + (j % seg) + 1 end
  for i = 0, (opt.closed and R or R - 1) - 1 do
    for j = 0, seg - 1 do fs[#fs + 1] = {id(i, j), id(i, j + 1), id(i + 1, j + 1), id(i + 1, j)} end
  end
  if not opt.closed then
    local a, b = {}, {}
    for j = 0, seg - 1 do a[#a + 1] = id(0, seg - 1 - j); b[#b + 1] = id(R - 1, j) end
    fs[#fs + 1] = a
    fs[#fs + 1] = b
  end
  return solid(vs, fs)
end
-- A round turned solid along a to b from { radius, t } rings, t 0 at a and 1 at b.
local function turned(rings, a, b, seg)
  local len = length(b - a)
  local rs = {}
  for i, r in ipairs(rings) do rs[i] = {r[1], r[1], (r[2] - 0.5) * len} end
  return along(oval(rs, {n=2, seg=seg or 12}), a, b)
end

local BZ = -0.02         -- the bowl's middle, along z
local TAPER = p.nose_taper
local pieces = {}
local function add(m, c) pieces[#pieces + 1] = {m, c} end

-- The bowl: a porcelain egg from the rim down to the floor under the seat cushion, on a pedestal set back under it
-- (the nose overhangs, as a toilet's does) with a flared foot on the frame's plate.
local top = 0.05
local PZ = -0.07         -- the pedestal's middle, from the bowl's
do
  local m = oval({
    {0.215, 0.30, -0.48, PZ},    -- the foot, on the frame's plate
    {0.235, 0.325, -0.468, PZ},
    {0.235, 0.325, -0.445, PZ},
    {0.20, 0.275, -0.425, PZ},
    {0.18, 0.25, -0.385, PZ},    -- the pedestal's waist
    {0.19, 0.275, -0.35, PZ * 0.8},
    {0.24, 0.37, -0.325, PZ * 0.5},
    {0.30, 0.47, -0.30, -0.035},   -- the belly, swept up to the nose
    {0.345, 0.55, -0.268, -0.025},
    {0.385, 0.62, -0.22, -0.015},
    {0.412, 0.668, -0.15, -0.007},
    {0.432, 0.705, -0.06, 0},
    {0.44, 0.72, top, 0},        -- under the rim
    {0.36, 0.595, top, 0},       -- inside
    {0.36, 0.595, -0.19, 0},
    {0.34, 0.56, -0.23, 0},
    {0.30, 0.50, -0.25, 0},      -- the floor
  }, {z=BZ, taper=TAPER, seg=44, n=3})
  -- the foot's flare and the pedestal's waist a shade darker, so the pedestal reads under the white bowl
  add(paint_if(paint(m, porcelain), shadow, function(f) return f.center.y < -0.36 end))
end

-- The seat ring round the bowl's top: thick, rounded, teal.
local rh = p.rim_height
local r0 = top - 0.01
add(oval({
  {0.355, 0.59, r0},
  {0.458, 0.745, r0},
  {0.475, 0.76, r0 + rh * 0.25},
  {0.475, 0.76, r0 + rh * 0.75},
  {0.458, 0.745, r0 + rh},
  {0.375, 0.615, r0 + rh + 0.004},
  {0.355, 0.59, r0 + rh * 0.8},
}, {z=BZ, taper=TAPER, seg=44, n=3, closed=true}), teal)

-- The seat: a cushion under the hips (top at y -0.22), a padded back inside the bowl with its sides curling forward,
-- and above it the toilet's lid, standing open on its chrome hinges against the cistern.
add(rbox(0.44, 0.035, 0.40, 0.08, 0, -0.255, -0.24, 0.012), teal_dk)
do
  local W, T, H = 0.46, 0.07, 0.42
  local function slab(w, h, t, r, seg, bw)
    local m = extrude(rounded_rect{w=w, h=h, radius=r, segments=seg or 4}, {distance=t, anchor="center"})
    m = rotate(m, {angle=90, axis=axis_x(), pivot=origin()})
    return bevel(m, {edges=convex_edges(m, {min_angle=60}), width=bw or 0.016, segments=1})
  end
  local m = translate(slab(W, H, T, 0.1), v3(0, H * 0.5, 0))
  m = rotate(m, {angle=-9, axis=axis_x(), pivot=origin()})
  add(at(m, 0, -0.23, -0.555), teal_dk)
  for _, sx in ipairs({1, -1}) do    -- the left one last: the wreck's torn stump
    local b = translate(slab(0.1, 0.3, 0.11, 0.035, 2, 0.01), v3(0, 0.15, 0))
    b = rotate(b, {angle=sx * 28, axis=axis_y(), pivot=origin()})
    b = rotate(b, {angle=-9, axis=axis_x(), pivot=origin()})
    add(at(b, sx * 0.21, -0.14, -0.565), teal_dk)
  end
  -- the lid: the seat ring's own egg, stood on its back end, a lighter panel pressed into its face
  local LB, LY, LZ = 0.285, r0 + rh + 0.005, -0.632
  local function egg(rings)
    local e = oval(rings, {taper=0.2, seg=32, n=2.6})
    e = rotate(e, {angle=-92, axis=axis_x(), pivot=origin()})
    return at(e, 0, LY + LB, LZ)
  end
  add(egg({
    {0.385, LB - 0.012, -0.024}, {0.40, LB, -0.012}, {0.40, LB, 0.012}, {0.385, LB - 0.012, 0.024},
  }), teal)
  add(egg({{0.31, LB - 0.075, -0.034}, {0.30, LB - 0.085, -0.04}}), teal_lt)
  for _, sx in ipairs({-1, 1}) do
    add(cyl(0.03, 0.1, sx * 0.2, LY + 0.012, LZ + 0.012, "x", 10), chrome)
  end
end

-- The cistern at the back: white, standing tall and flaring a little to its top, a teal band round its lower part
-- and a crowned teal lid overhanging it. All of it, and what hangs on it, is the signature piece.
local tt = p.tank_top
local CZ = -0.87
local cb = -0.1
local sig0 = #pieces + 1
do
  local CB = {z=CZ, seg=32, n=6}
  local y1 = tt - 0.08
  add(paint_if(paint(oval({
    {0.265, 0.12, cb}, {0.29, 0.145, cb + 0.025}, {0.315, 0.165, y1},
  }, CB), porcelain), shadow, function(f) return f.center.y < cb + 0.02 end))
  add(oval({
    {0.296, 0.151, 0.03}, {0.306, 0.161, 0.04}, {0.308, 0.163, 0.105}, {0.30, 0.155, 0.115},
  }, CB), teal)
  local l0 = tt - 0.085
  add(oval({
    {0.325, 0.175, l0}, {0.345, 0.195, l0 + 0.018}, {0.345, 0.195, l0 + 0.052}, {0.325, 0.178, l0 + 0.074},
    {0.24, 0.11, l0 + 0.085},
  }, CB), teal)
  -- the flush lever on its side: a chrome boss, an arm forward and down, a ball on its end
  local lx, ly = 0.31, tt - 0.2
  local piv, tip = v3(lx + 0.03, ly, CZ + 0.08), v3(lx + 0.05, ly - 0.035, CZ + 0.26)
  add(cyl(0.036, 0.06, lx + 0.012, ly, CZ + 0.08, "x", 12), chrome)
  add(rod(piv, tip, 0.016, 8), chrome)
  add(ball(0.034, 0.034, 0.034, tip.x, tip.y, tip.z, 10), chrome)
  -- a roundel on its back, for whoever is behind
  add(cyl(0.125, 0.02, 0, 0.37, CZ - 0.158, "z", 20), teal)
  add(cyl(0.08, 0.028, 0, 0.37, CZ - 0.158, "z", 16), porcelain)
  -- a toilet roll on a holder on its other side, the paper trailing behind
  local ry, rx = 0.36, -0.395
  add(rod(v3(-0.29, ry, CZ), v3(rx - 0.075, ry, CZ), 0.014, 8), chrome)
  add(cyl(0.082, 0.12, rx, ry, CZ, "x", 16), pink)
  add(cyl(0.034, 0.126, rx, ry, CZ, "x", 10), card)
  local function strip(a, b) return along(box{size=v3(0.11, length(b - a), 0.008)}, a, b) end
  local back = CZ - 0.082 + 0.004
  local reach = p.paper_tail
  local q0, q1 = v3(rx, ry, back), v3(rx, ry - 0.17, back - reach * 0.1)
  local q2, q3 = v3(rx, ry - 0.27, back - reach * 0.45), v3(rx, ry - 0.31, back - reach * 0.93)
  add(strip(q0, q1), pink)
  add(strip(q1, q2), pink)
  add(strip(q2, q3), pink)
  for i = sig0, #pieces do pieces[i].sig = true end
end
-- the flush pipe from under the cistern into the bowl's back
add(tube({v3(0, cb + 0.01, CZ + 0.01), v3(0, -0.2, CZ + 0.01), v3(0, -0.245, CZ + 0.09), v3(0, -0.25, -0.68)}, 0.042, 10), chrome)

-- The frame: square aluminium tube. Side rails, crossbars at the axles, axle stubs, braces up to the bowl.
local S = 0.05
local RX, RY = 0.34, -0.47
local function frame(a, b, s) add(bar(a, b, s or S, s ~= nil), alu) end
for _, sx in ipairs({-1, 1}) do
  frame(v3(sx * RX, RY, -0.97), v3(sx * RX, RY, 0.9))
  -- braces from the rails up to the bowl's flanks, front and back
  frame(v3(sx * RX, RY + 0.02, 0.62), v3(sx * 0.31, -0.25, 0.29), 0.04)
  frame(v3(sx * RX, RY + 0.02, -0.62), v3(sx * 0.33, -0.25, -0.33), 0.04)
  -- the posts under the cistern
  frame(v3(sx * 0.2, RY + 0.025, -0.86), v3(sx * 0.2, cb + 0.02, -0.86), 0.04)
  -- the front bumper's uprights
  frame(v3(sx * 0.3, RY + 0.025, 0.88), v3(sx * 0.3, -0.31, 0.88), 0.04)
  -- axle stubs to the hubs
  for _, z in ipairs({-0.7, 0.7}) do
    add(rod(v3(sx * 0.47, -0.42, z), v3(sx * 0.535, -0.42, z), 0.022, 10), grey)
    add(cyl(0.032, 0.02, sx * 0.47, -0.42, z, "x", 6), dark)
  end
end
for _, z in ipairs({-0.7, 0.7}) do frame(v3(-0.47, -0.42, z), v3(0.47, -0.42, z)) end
frame(v3(-RX, RY, -0.95), v3(RX, RY, -0.95))
frame(v3(-RX, RY, 0.875), v3(RX, RY, 0.875))
frame(v3(-0.32, -0.33, 0.88), v3(0.32, -0.33, 0.88), 0.04)
frame(v3(-0.24, cb + 0.0, -0.86), v3(0.24, cb + 0.0, -0.86), 0.04)
-- the plate the bowl's foot stands on
add(rb(RX * 2 + 0.04, 0.018, 0.74, 0, -0.489, BZ + PZ, 0.005), shade(alu, 0.92))

-- Corner gussets: triangular plates in the corners of rails and end crossbars, all one piece.
local function gusset(x0, z0, dx, dz, y)
  local vs = {
    v3(x0, y - 0.006, z0), v3(x0 + dx, y - 0.006, z0), v3(x0, y - 0.006, z0 + dz),
    v3(x0, y + 0.006, z0), v3(x0 + dx, y + 0.006, z0), v3(x0, y + 0.006, z0 + dz),
  }
  return solid(vs, {{1, 3, 2}, {4, 5, 6}, {1, 2, 5, 4}, {2, 3, 6, 5}, {3, 1, 4, 6}})
end
do
  local gs = {}
  for _, sx in ipairs({-1, 1}) do
    for _, z in ipairs({-0.95, 0.875}) do
      local sz = z < 0 and 1 or -1
      gs[#gs + 1] = gusset(sx * (RX - S * 0.5), z + sz * S * 0.5, -sx * 0.08, sz * 0.08, RY + 0.012)
    end
  end
  add(many(gs), alu)
end

-- The steering column: from just under the wheel, forward and down through the bowl's front to the frame.
do
  local a, b = v3(0, 0.1, 0.15), v3(0, -0.445, 0.86)
  add(rod(a, b, 0.022, 10), grey)
  add(cyl(0.035, 0.05, 0, 0.1 - 0.02, 0.15 + 0.025, "y", 12), dark)
  add(rb(0.08, 0.03, 0.07, 0, -0.43, 0.86, 0.008), alu)
end

-- The plunger: its red cup stuck on the bowl's nose, the handle out ahead and up like a lance.
if p.plunger then
  local d = normalize(v3(0, 0.4, 1))
  local a = v3(0, -0.075, BZ + 0.685)
  add(turned({{0.092, 0}, {0.1, 0.12}, {0.085, 0.5}, {0.045, 0.85}, {0.03, 1}}, a, a + d * 0.1, 14), rubber)
  add(turned({{0.034, 0}, {0.034, 1}}, a + d * 0.095, a + d * 0.13, 10), rubber_dk)
  add(rod(a + d * 0.125, a + d * 0.43, 0.019, 8), wood)
  add(ball(0.027, 0.027, 0.027, a.x + d.x * 0.43, a.y + d.y * 0.43, a.z + d.z * 0.43, 8), wood)
end

-- The toilet brush, a front bumper: its handle along the front of the frame, the head out front and to one side.
do
  local reach = p.brush_reach
  local L = v3(0.28, -0.40, 0.93)            -- the handle's end, its loop beyond
  local H = v3(-0.36, -0.30, reach - 0.04)   -- where the handle meets the head
  local d = normalize(H - L)
  add(rod(L, H, 0.025, 10), blue_lt)
  -- a collar at each end
  add(rod(L - d * 0.0, L + d * 0.05, 0.031, 10), blue)
  add(rod(H - d * 0.06, H, 0.03, 10), blue)
  -- the loop on its end
  do
    local ring = torus{major_radius=0.045, minor_radius=0.012, major_segments=14, minor_segments=6, axis="z"}
    ring = scale(ring, {factor=v3(1.5, 1, 1), pivot=origin()})
    local hd = normalize(v3(-d.x, 0, -d.z))
    ring = rotate(ring, {angle=deg(math.asin(d.y / length(d))), axis=axis_z(), pivot=origin()})
    ring = rotate(ring, {angle=deg(math.atan(-hd.z, hd.x)), axis=axis_y(), pivot=origin()})
    add(translate(ring, L - d * 0.06), blue_lt)
  end
  -- clamps holding it to the bumper
  for _, t in ipairs({0.2, 0.62}) do
    local q = lerp(L, H, t)
    add(bar(v3(q.x, -0.33, 0.88), q, 0.03, true), alu)
  end
  -- the head: a ball of radiating bristles round a core, none pointing back at the handle; chunky three-sided
  -- bristles in two blues, each blue one mesh
  local hc = H + d * 0.12
  add(ball(0.05, 0.05, 0.05, hc.x, hc.y, hc.z, 10), blue)
  add(rod(H, hc, 0.012, 6), blue)
  local N = p.bristles
  local ga = math.pi * (3 - math.sqrt(5))
  local back = v3(-d.x, -d.y, -d.z)
  local tufts = {{vs={}, fs={}}, {vs={}, fs={}}}
  -- a bristle: a three-sided spike from a to b, into one polyhedron a blue
  local function spike(t, a, b, dir, r0, r1)
    local u = normalize(cross(dir, math.abs(dir.y) < 0.9 and v3(0, 1, 0) or v3(1, 0, 0)))
    local w = cross(dir, u)
    local n = #t.vs
    for k = 0, 2 do
      local c, s = math.cos(k * 2 * math.pi / 3), math.sin(k * 2 * math.pi / 3)
      t.vs[n + k + 1] = a + u * (c * r0) + w * (s * r0)
      t.vs[n + k + 4] = b + u * (c * r1) + w * (s * r1)
    end
    t.fs[#t.fs + 1] = {n + 3, n + 2, n + 1}
    t.fs[#t.fs + 1] = {n + 4, n + 5, n + 6}
    for k = 0, 2 do
      local k2 = (k + 1) % 3
      t.fs[#t.fs + 1] = {n + k + 1, n + k2 + 1, n + k2 + 4, n + k + 4}
    end
  end
  for i = 0, N - 1 do
    local y = 1 - 2 * (i + 0.5) / N
    local r = math.sqrt(1 - y * y)
    local ph = i * ga
    local dir = v3(math.cos(ph) * r, y, math.sin(ph) * r)
    if dot(dir, back) < 0.72 then
      local t = tufts[(i % 3 == 0) and 2 or 1]
      spike(t, hc + dir * 0.035, hc + dir * (0.13 + 0.008 * ((i * 7) % 3)), dir, 0.015, 0.007)
    end
  end
  for i, c in ipairs({blue, blue_lt}) do
    if #tufts[i].fs > 0 then add(solid(tufts[i].vs, tufts[i].fs), c) end
  end
end

part("toilet", pieces)
