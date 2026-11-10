-- Bog Standard Racing: a toilet for a kart body, one part "toilet". The driver sits in a big porcelain bowl with a
-- teal seat ring round its top, a teal moulded seat back behind them, the cistern standing tall at the back with its
-- teal lid and band and a flush lever; under it all a square-tube aluminium frame, and a blue toilet brush for a
-- front bumper. In the kart's body space: the origin the middle of the chassis' top, +z forward, metres. The chassis
-- box is hidden under this body, so the frame here is the kart's own; the wheels (x +-0.5, z +-0.7, y -0.42) and the
-- steering wheel come from other slots.
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
-- A square tube from a to b, s across.
local function bar(a0, b0, s)
  local a, b = lerp(a0, b0, 0.002), lerp(a0, b0, 0.998)
  local m = box{size=v3(s, length(b - a), s)}
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
  bristles    = { default = 150, min = 40, max = 180, integer = true, doc = "Bristles on the brush head" },
  brush_reach = { default = 1.06, min = 0.95, max = 1.2, doc = "How far forward the brush head sits, metres" },
}

local porcelain = C(0.93, 0.93, 0.91)
local teal      = C(0.04, 0.62, 0.53)
local teal_dk   = shade(teal, 0.8)
local blue      = C(0.04, 0.22, 0.85)
local blue_lt   = C(0.12, 0.38, 0.95)
local alu       = C(0.66, 0.68, 0.72)

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

-- A ring-swept oval solid: each ring { a, b, y } a superellipse (exponent n) a across x and b along z at height y,
-- the rings joined in order; `closed` joins the last to the first (a tube round the oval), else the first and last
-- rings are capped flat. `taper` narrows the front (+z) end, as a toilet bowl's is.
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
      vs[#vs + 1] = v3(r[1] * cx * k, r[3], cz + r[2] * sz)
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

local BZ = -0.02         -- the bowl's middle, along z
local TAPER = 0.05
local pieces = {}
local function add(m, c) pieces[#pieces + 1] = {m, c} end

-- The bowl: a porcelain tub from its foot on the frame up to the rim, hollow down to the floor under the seat cushion.
local top = 0.05
add(oval({
  {0.20, 0.34, -0.48},   -- the foot, on the frame's plate
  {0.215, 0.36, -0.465},
  {0.215, 0.36, -0.44},
  {0.19, 0.32, -0.42},
  {0.18, 0.30, -0.37},   -- the pedestal
  {0.19, 0.32, -0.345},
  {0.23, 0.40, -0.325},
  {0.285, 0.50, -0.30},
  {0.335, 0.565, -0.27},
  {0.37, 0.62, -0.23},
  {0.395, 0.66, -0.17},
  {0.415, 0.69, -0.10},
  {0.43, 0.71, -0.03},
  {0.435, 0.72, top},    -- under the rim
  {0.36, 0.595, top},     -- inside
  {0.36, 0.595, -0.19},
  {0.34, 0.56, -0.23},
  {0.30, 0.50, -0.25},   -- the floor
}, {z=BZ, taper=TAPER, seg=72, n=3.4}), porcelain)

-- The seat ring round the bowl's top: thick, rounded, teal.
local rh = p.rim_height
local r0 = top - 0.01
add(oval({
  {0.355, 0.59, r0},
  {0.455, 0.745, r0},
  {0.47, 0.76, r0 + rh * 0.25},
  {0.47, 0.76, r0 + rh * 0.75},
  {0.455, 0.745, r0 + rh},
  {0.375, 0.615, r0 + rh + 0.004},
  {0.355, 0.59, r0 + rh * 0.8},
}, {z=BZ, taper=TAPER, seg=72, n=3.4, closed=true}), teal)

-- The seat: a cushion under the hips (top at y -0.22) and a moulded back behind them, its sides curling forward.
add(rbox(0.44, 0.035, 0.40, 0.08, 0, -0.255, -0.24, 0.012), teal)
do
  -- a slab with rounded corners seen from the front, its sides curled forward round the driver
  local W, T, H = 0.48, 0.08, 0.66
  local function slab(w, h, t, r, seg, bw)
    local m = extrude(rounded_rect{w=w, h=h, radius=r, segments=seg or 5}, {distance=t, anchor="center"})
    m = rotate(m, {angle=90, axis=axis_x(), pivot=origin()})
    return bevel(m, {edges=convex_edges(m, {min_angle=60}), width=bw or 0.019, segments=2})
  end
  local m = translate(slab(W, H, T, 0.13), v3(0, H * 0.5, 0))
  m = rotate(m, {angle=-9, axis=axis_x(), pivot=origin()})
  add(at(m, 0, -0.23, -0.56), teal)
  -- the moulded bolsters either side, angled forward round the driver's back
  for _, sx in ipairs({-1, 1}) do
    local b = translate(slab(0.1, H * 0.58, 0.12, 0.035, 2, 0.01), v3(0, H * 0.29, 0))
    b = rotate(b, {angle=sx * 28, axis=axis_y(), pivot=origin()})
    b = rotate(b, {angle=-9, axis=axis_x(), pivot=origin()})
    add(at(b, sx * 0.215, -0.12, -0.575), teal)
  end
end

-- The cistern at the back: white, standing tall, a teal band round its lower part and a teal lid overhanging it.
local tt = p.tank_top
local CZ, CD, CW = -0.87, 0.32, 0.62
local cb = -0.1
local sig0 = #pieces + 1
add(rbox(CW, tt - 0.075 - cb, CD, 0.045, 0, cb, CZ, 0.02), porcelain)
add(rbox(CW + 0.03, 0.09, CD + 0.03, 0.06, 0, 0.045, CZ, 0.015), teal)
add(rbox(CW + 0.07, 0.085, CD + 0.07, 0.05, 0, tt - 0.085, CZ, 0.025), teal)
-- the flush lever on its right side, pointing forward
do
  local lx = CW * 0.5
  local ly = tt - 0.2
  add(rb(0.02, 0.07, 0.1, lx + 0.008, ly, CZ + 0.07, 0.008), shade(grey, 0.85))
  add(cyl(0.03, 0.04, lx + 0.03, ly, CZ + 0.07, "x", 16), grey)
  add(rb(0.03, 0.04, 0.2, lx + 0.05, ly, CZ + 0.17, 0.012), grey)
  add(rb(0.036, 0.055, 0.05, lx + 0.05, ly - 0.004, CZ + 0.27, 0.015), grey)
  for i = sig0, #pieces do pieces[i].sig = true end
end

-- The frame: square aluminium tube. Side rails, crossbars at the axles, axle stubs, braces up to the bowl.
local S = 0.05
local RX, RY = 0.34, -0.47
local function frame(a, b, s) add(bar(a, b, s or S), alu) end
for _, sx in ipairs({-1, 1}) do
  frame(v3(sx * RX, RY, -0.97), v3(sx * RX, RY, 0.9))
  -- braces from the rails up to the bowl's flanks, front and back
  frame(v3(sx * RX, RY + 0.02, 0.62), v3(sx * 0.33, -0.25, 0.29), 0.04)
  frame(v3(sx * RX, RY + 0.02, -0.62), v3(sx * 0.33, -0.25, -0.33), 0.04)
  -- the posts under the cistern
  frame(v3(sx * 0.24, RY + 0.025, -0.86), v3(sx * 0.24, cb + 0.02, -0.86), 0.04)
  -- the front bumper's uprights
  frame(v3(sx * 0.3, RY + 0.025, 0.88), v3(sx * 0.3, -0.31, 0.88), 0.04)
  -- axle stubs to the hubs
  for _, z in ipairs({-0.7, 0.7}) do
    add(rod(v3(sx * 0.47, -0.42, z), v3(sx * 0.535, -0.42, z), 0.022, 12), grey)
    add(cyl(0.032, 0.02, sx * 0.47, -0.42, z, "x", 6), dark)
  end
end
for _, z in ipairs({-0.7, 0.7}) do frame(v3(-0.47, -0.42, z), v3(0.47, -0.42, z)) end
frame(v3(-RX, RY, -0.95), v3(RX, RY, -0.95))
frame(v3(-RX, RY, 0.875), v3(RX, RY, 0.875))
frame(v3(-0.32, -0.33, 0.88), v3(0.32, -0.33, 0.88), 0.04)
frame(v3(-0.26, cb + 0.0, -0.86), v3(0.26, cb + 0.0, -0.86), 0.04)
-- the plate the bowl's foot stands on
add(rb(RX * 2 + 0.04, 0.018, 0.5, 0, -0.489, -0.03, 0.005), shade(alu, 0.92))

-- Corner gussets: triangular plates in the corners of rails and crossbars.
local function gusset(x0, z0, dx, dz, y)
  local vs = {
    v3(x0, y - 0.006, z0), v3(x0 + dx, y - 0.006, z0), v3(x0, y - 0.006, z0 + dz),
    v3(x0, y + 0.006, z0), v3(x0 + dx, y + 0.006, z0), v3(x0, y + 0.006, z0 + dz),
  }
  return solid(vs, {{1, 3, 2}, {4, 5, 6}, {1, 2, 5, 4}, {2, 3, 6, 5}, {3, 1, 4, 6}})
end
for _, sx in ipairs({-1, 1}) do
  for _, z in ipairs({-0.7, 0.7}) do
    for _, sz in ipairs({-1, 1}) do
      add(gusset(sx * (RX - S * 0.5), z + sz * S * 0.5, -sx * 0.09, sz * 0.09, -0.44), alu)
    end
  end
  for _, z in ipairs({-0.95, 0.875}) do
    local sz = z < 0 and 1 or -1
    add(gusset(sx * (RX - S * 0.5), z + sz * S * 0.5, -sx * 0.08, sz * 0.08, RY + 0.012), alu)
  end
end

-- The steering column: from just under the wheel, forward and down through the bowl's front to the frame.
do
  local a, b = v3(0, 0.1, 0.15), v3(0, -0.445, 0.86)
  add(rod(a, b, 0.022, 12), grey)
  add(cyl(0.035, 0.05, 0, 0.1 - 0.02, 0.15 + 0.025, "y", 12), dark)
  add(rb(0.08, 0.03, 0.07, 0, -0.43, 0.86, 0.008), alu)
end

-- The toilet brush, a front bumper: its handle along the front of the frame, the head out front and to one side.
do
  local reach = p.brush_reach
  local L = v3(0.28, -0.40, 0.93)            -- the handle's end, its loop beyond
  local H = v3(-0.36, -0.30, reach - 0.04)   -- where the handle meets the head
  local d = normalize(H - L)
  add(rod(L, H, 0.025, 12), blue_lt)
  -- a collar at each end
  add(rod(L - d * 0.0, L + d * 0.05, 0.031, 12), blue)
  add(rod(H - d * 0.06, H, 0.03, 12), blue)
  -- the loop on its end
  do
    local ring = torus{major_radius=0.045, minor_radius=0.012, major_segments=20, minor_segments=8, axis="z"}
    ring = scale(ring, {factor=v3(1.5, 1, 1), pivot=origin()})
    local hd = normalize(v3(-d.x, 0, -d.z))
    ring = rotate(ring, {angle=deg(math.asin(d.y / length(d))), axis=axis_z(), pivot=origin()})
    ring = rotate(ring, {angle=deg(math.atan(-hd.z, hd.x)), axis=axis_y(), pivot=origin()})
    add(translate(ring, L - d * 0.06), blue_lt)
  end
  -- clamps holding it to the bumper
  for _, t in ipairs({0.2, 0.62}) do
    local q = lerp(L, H, t)
    add(bar(v3(q.x, -0.33, 0.88), q, 0.03), alu)
  end
  -- the head: a ball of radiating bristles round a core, none pointing back at the handle
  local hc = H + d * 0.12
  add(ball(0.045, 0.045, 0.045, hc.x, hc.y, hc.z, 12), blue)
  add(rod(H, hc, 0.012, 8), blue)
  local N = p.bristles
  local ga = math.pi * (3 - math.sqrt(5))
  local back = v3(-d.x, -d.y, -d.z)
  for i = 0, N - 1 do
    local y = 1 - 2 * (i + 0.5) / N
    local r = math.sqrt(1 - y * y)
    local ph = i * ga
    local dir = v3(math.cos(ph) * r, y, math.sin(ph) * r)
    if dot(dir, back) < 0.72 then
      add(rod(hc + dir * 0.03, hc + dir * (0.13 + 0.008 * ((i * 7) % 3)), 0.008, 4), (i % 3 == 0) and blue_lt or blue)
    end
  end
end

part("toilet", pieces)
