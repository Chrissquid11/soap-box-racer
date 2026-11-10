-- Moving Day: a tiny lime-green city car for a kart body, one part "minicar". A rounded little box of a car with
-- round chrome headlamps, a small slatted grille, orange indicators, chrome bumpers, wing mirrors and tall tail lamps;
-- the windows are open frames so the driver shows. On its roof, roped down over the top and down the doors to the
-- handles, a teetering stack of three odd suitcases with a standard lamp lying across them.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x +-0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x +-0.5, z +-0.7,
-- y -0.42, and the steering wheel at (0, 0.1, 0.15).
local p = params{
  waist    = { default = 0.32, min = 0.26, max = 0.36, doc = "Height of the window line (the body's top), metres" },
  arch     = { default = 0.5, min = 0.47, max = 0.56, doc = "Radius of the wheel arches, metres" },
  lean     = { default = 6, min = 0, max = 9, doc = "How far the suitcase stack leans, degrees" },
  lamp_yaw = { default = 16, min = 0, max = 30, doc = "Angle of the standard lamp across the stack, degrees" },
}

local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.5, metallic=0}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
local function paint_if(m, c, fn)
  local sel = faces_where(m, fn)
  if set_count(sel) == 0 then return m end
  return paint_faces(m, {faces=sel, color=c})
end
-- A part of pieces, each { mesh, colour, angle } or { mesh } already painted: merged into one mesh with its colours on
-- its vertices, each piece's normals smoothed first.
local function part(name, pieces)
  local out = {}
  for i, q in ipairs(pieces) do
    local m = q[2] and paint(q[1], q[2]) or q[1]
    out[i] = {mesh=smooth_normals(m, {angle=q[3] or 40}), material=PAINT}
  end
  local merged = merge({parts=out, mode="compatible"})
  emit(merged[1].mesh, {name=name, material=merged[1].material})
  -- Its wreck, as the same pieces broken: what stays on the kart when the bodywork is knocked off (_wreck.lua).
  -- Its signature piece (a piece marked true, 4th) comes off alone as `<name>_sig` (_sig.lua), the rest to the wreck.
  local rest = include("_sig.lua").split(name, out, function(i) return pieces[i][4] end)
  include("_wreck.lua").emit(name, rest)
end
local function C(r, g, b) return v3(r, g, b) end
local function shade(c, k) return v3(math.min(1, c.x * k), math.min(1, c.y * k), math.min(1, c.z * k)) end
local function at(m, x, y, z) return translate(m, v3(x, y, z)) end
-- A box with its edges bevelled.
local function rb(sx, sy, sz, x, y, z, w, seg)
  local m = box{size=v3(sx, sy, sz)}
  return at(bevel(m, {edges=convex_edges(m), width=w or math.min(sx, sy, sz) * 0.2, segments=seg or 1}), x, y, z)
end
-- A box with its corners rounded about y, its base at y; `soft` rounds its top and bottom rims too.
local function rbox(w, h, d, r, x, y, z, soft, seg)
  local m = extrude(rounded_rect{w=w, h=d, radius=r, segments=seg or 4}, {distance=h})
  if soft then
    local edge = 2 * r * math.sin(math.pi / 16)
    for _, side in ipairs({w - 2 * r, d - 2 * r}) do if side > 0.001 then edge = math.min(edge, side) end end
    m = bevel(m, {edges=convex_edges(m, {min_angle=60}), width=math.min(soft, edge * 0.45, h * 0.22), segments=2})
  end
  return at(m, x, y, z)
end
local function ball(rx, ry, rz, x, y, z, seg)
  local s = seg or 12
  return at(scale(sphere{radius=1, segments=s, rings=math.floor(s / 2)}, {factor=v3(rx, ry, rz), pivot=origin()}), x, y, z)
end
local function cyl(r, h, x, y, z, axis, seg) return at(cylinder{radius=r, height=h, segments=seg or 14, axis=axis or "y"}, x, y, z) end
local function along(m, a, b)
  local dir = normalize(b - a)
  local c = dot(v3(0, 1, 0), dir)
  if c < -0.9999 then m = rotate(m, {angle=180, axis=axis_x(), pivot=origin()})
  elseif c < 0.9999 then m = rotate(m, {angle=deg(math.acos(c)), axis=normalize(cross(v3(0, 1, 0), dir)), pivot=origin()}) end
  return translate(m, (a + b) * 0.5)
end
local function rod(a0, b0, r, seg)
  local a, b = lerp(a0, b0, 0.004), lerp(a0, b0, 0.996)
  return along(cylinder{radius=r, height=length(b - a), segments=seg or 8}, a, b)
end
local function bar(a0, b0, s)
  local a, b = lerp(a0, b0, 0.002), lerp(a0, b0, 0.998)
  local m = box{size=v3(s, length(b - a), s)}
  local long = edges_where(m, function(e) return math.abs(e.direction.y) > 0.9 end)
  local edges = set_subtract(long, set_subtract(long, convex_edges(m, {min_angle=60})))
  return along(bevel(m, {edges=edges, width=s * 0.25, segments=1}), a, b)
end
local function tube(pts, r, seg) return sweep(circle{radius=r, segments=seg or 8}, path{points=pts}, {caps=true}) end
local function lathe(pts, seg)
  local ps = {}
  for i, q in ipairs(pts) do ps[i] = v2(q[1], q[2]) end
  return revolve(poly{points=ps}, {segments=seg or 24})
end

local lime     = C(0.36, 0.72, 0.02)
local lime_dk  = shade(lime, 0.62)
local black    = C(0.04, 0.04, 0.05)
local dark     = C(0.13, 0.13, 0.15)
local inside   = C(0.2, 0.2, 0.22)
local grey     = C(0.5, 0.52, 0.55)
local chrome   = C(0.9, 0.91, 0.94)
local lens     = C(0.97, 0.96, 0.85)
local orange   = C(1.0, 0.36, 0.02)
local red      = C(0.8, 0.04, 0.04)
local amber    = C(1.0, 0.5, 0.03)
local yellow   = C(1.0, 0.8, 0.05)
local vinyl    = C(0.16, 0.09, 0.06)
local rope_c   = C(0.78, 0.56, 0.3)
local leather  = C(0.34, 0.15, 0.05)
local strap_c  = C(0.18, 0.08, 0.03)
local brass    = C(0.85, 0.62, 0.2)
local tart_red = C(0.6, 0.04, 0.05)
local tart_grn = C(0.03, 0.25, 0.1)
local tart_nvy = C(0.04, 0.06, 0.25)
local mint     = C(0.42, 0.82, 0.6)
local cream    = C(0.95, 0.9, 0.75)
local shade_c  = C(0.95, 0.62, 0.55)
local tassel   = C(0.55, 0.06, 0.12)

local pieces = {}
-- `SIG` true while adding the signature's pieces (the roof load: cases, lamp, ropes): marked 4th, for part().
local SIG = false
local function add(m, c, a) pieces[#pieces + 1] = {m, c, a, SIG} end

local W = p.waist
local AR = p.arch
local BOT = -0.36                 -- the body's underside
local ZF, ZB = 1.3, -1.28         -- its front and back faces
local HX = 0.65                   -- its half-width
local RY = 0.94                   -- the roof's underside
local CUT = { x = 0.55, y = -0.28, z0 = -0.7, z1 = 0.5 }   -- the cockpit

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
-- A stack of superellipse rings { a (half across x), b (half along z), y }, capped top and bottom; `lift(y, z)` moves
-- a ring point up or down (a bonnet sloping off the front).
local function pillow(rings, n, cz, seg, lift)
  local vs, fs = {}, {}
  for _, r in ipairs(rings) do
    for j = 0, seg - 1 do
      local t = 2 * math.pi * (j + 0.5) / seg
      local c, s = math.cos(t), math.sin(t)
      local x = r[1] * (c < 0 and -1 or 1) * math.abs(c) ^ (2 / n)
      local z = cz + r[2] * (s < 0 and -1 or 1) * math.abs(s) ^ (2 / n)
      vs[#vs + 1] = v3(x, r[3] + (lift and lift(r[3], z) or 0), z)
    end
  end
  local R = #rings
  local function id(i, j) return i * seg + (j % seg) + 1 end
  for i = 0, R - 2 do
    for j = 0, seg - 1 do fs[#fs + 1] = {id(i, j), id(i, j + 1), id(i + 1, j + 1), id(i + 1, j)} end
  end
  local a, b = {}, {}
  for j = 0, seg - 1 do a[#a + 1] = id(0, seg - 1 - j); b[#b + 1] = id(R - 1, j) end
  fs[#fs + 1] = a
  fs[#fs + 1] = b
  return solid(vs, fs)
end
local function smooth(e0, e1, x)
  local t = math.max(0, math.min(1, (x - e0) / (e1 - e0)))
  return t * t * (3 - 2 * t)
end
local BN = 5                               -- the body's squareness in plan
local BZ0 = (ZF + ZB) * 0.5                -- its middle along z
local BB = (ZF - ZB) * 0.5                 -- its half-length
-- Where the body's front (sz 1) or back (sz -1) face is at x, at its widest.
local function face_z(x, sz)
  local u = math.min(0.999, math.abs(x) / HX)
  return BZ0 + sz * BB * (1 - u ^ BN) ^ (1 / BN)
end

-- The body: a rounded tub to the window line, its bonnet sloping off the front, the cockpit and the wheel arches cut
-- out.
do
  local function lift(y, z)
    if y < W - 0.1 then return 0 end
    local k = (y - (W - 0.1)) / 0.1
    return -k * (0.07 * smooth(0.62, 1.3, z) + 0.025 * smooth(-0.9, -1.3, z))
  end
  local body = pillow({
    {HX - 0.05, BB - 0.05, BOT},
    {HX - 0.01, BB - 0.01, BOT + 0.03},
    {HX, BB, BOT + 0.1},
    {HX, BB, W - 0.1},
    {HX - 0.012, BB - 0.012, W - 0.035},
    {HX - 0.04, BB - 0.04, W - 0.008},
    {HX - 0.07, BB - 0.07, W},
    {HX - 0.2, BB - 0.2, W + 0.003},
    {HX - 0.4, BB - 0.4, W + 0.005},
  }, BN, BZ0, 60, lift)
  local cut = at(box{size=v3(CUT.x * 2, 2, CUT.z1 - CUT.z0)}, 0, CUT.y + 1, (CUT.z0 + CUT.z1) * 0.5)
  local arches = {}
  for _, z in ipairs({-0.7, 0.7}) do
    for _, sx in ipairs({-1, 1}) do arches[#arches + 1] = cyl(AR, 0.6, sx * 0.66, -0.42, z, "x", 32) end
  end
  body = subtract(body, cut, table.unpack(arches))
  body = paint(body, lime)
  body = paint_if(body, inside, function(f)
    local c = f.center
    return math.abs(c.x) < CUT.x + 0.001 and c.z > CUT.z0 - 0.001 and c.z < CUT.z1 + 0.001 and c.y > CUT.y - 0.001
       and c.y < W - 0.005
  end)
  body = paint_if(body, dark, function(f) return f.center.y < BOT + 0.002 end)
  -- inside the arches, dark
  body = paint_if(body, dark, function(f)
    local c = f.center
    local d = math.sqrt((c.y + 0.42) ^ 2 + (math.abs(c.z) - 0.7) ^ 2)
    return math.abs(d - AR) < 0.01 and math.abs(c.x) > 0.3
  end)
  pieces[#pieces + 1] = {body, nil, 35}
end

-- Wheel-well liners: dark humps over the tyres' inner side.
for _, z in ipairs({-0.7, 0.7}) do
  for _, sx in ipairs({-1, 1}) do
    local disc = cyl(AR + 0.015, 0.02, sx * 0.355, -0.42, z, "x", 32)
    add(subtract(disc, at(box{size=v3(0.1, 1, 1.4)}, sx * 0.355, BOT - 0.5 + 0.03, z)), dark)
  end
end

-- Arch lips: dark rolled edges round each arch.
for _, z in ipairs({-0.7, 0.7}) do
  for _, sx in ipairs({-1, 1}) do
    local R = AR + 0.012
    local t0 = math.asin((BOT + 0.03 + 0.42) / R)
    local pts = {}
    for i = 0, 14 do
      local t = t0 + (math.pi - 2 * t0) * i / 14
      pts[#pts + 1] = v3(sx * (HX - 0.005), -0.42 + R * math.sin(t), z + R * math.cos(t))
    end
    add(tube(pts, 0.026, 8), dark)
  end
end

-- The greenhouse: pillars leaning in to the roof, every window an open frame.
do
  local P = { {0.66, 0.44, 0.08}, {-0.32, -0.32, 0.075}, {-1.0, -0.86, 0.14} }   -- { z at the waist, z at the roof, size }
  for _, sx in ipairs({-1, 1}) do
    for _, q in ipairs(P) do
      add(bar(v3(sx * 0.585, W - 0.04, q[1]), v3(sx * 0.53, RY + 0.02, q[2]), q[3]), lime, 35)
    end
    -- a chrome sill along the window line
    add(rod(v3(sx * 0.6, W + 0.004, 0.62), v3(sx * 0.6, W + 0.004, -0.96), 0.012, 6), chrome)
  end
  -- the roof: a rounded lid, a drip rail round its edge
  add(pillow({{0.55, 0.68, RY}, {0.6, 0.73, RY + 0.015}, {0.6, 0.73, RY + 0.045}, {0.57, 0.7, RY + 0.07},
    {0.53, 0.66, RY + 0.077}}, 4, -0.21, 40), lime, 35)
  add(pillow({{0.615, 0.745, RY + 0.012}, {0.615, 0.745, RY + 0.03}}, 4, -0.21, 40), lime_dk, 35)
  -- the dashboard, a speedometer, the steering column
  add(rb(1.08, 0.1, 0.12, 0, 0.2, 0.555, 0.02), dark)
  add(cyl(0.055, 0.02, 0.22, 0.2, 0.49, "z", 16), chrome)
  add(cyl(0.045, 0.01, 0.22, 0.2, 0.481, "z", 16), C(0.9, 0.9, 0.85))
  add(rod(v3(0, 0.1, 0.15), v3(0, 0.12, 0.5), 0.022, 10), black)
  add(cyl(0.035, 0.05, 0, 0.1, 0.18, "z", 10), black)
end

-- The seat: a cushion under the hips, a tilted back behind them.
do
  add(rbox(0.48, 0.06, 0.44, 0.07, 0, -0.29, -0.32, 0.02), vinyl)
  local back = extrude(rounded_rect{w=0.5, h=0.68, radius=0.12, segments=4}, {distance=0.1, anchor="center"})
  back = rotate(back, {angle=90, axis=axis_x(), pivot=origin()})
  back = bevel(back, {edges=convex_edges(back, {min_angle=60}), width=0.02, segments=2})
  back = rotate(translate(back, v3(0, 0.34, 0)), {angle=-9, axis=axis_x(), pivot=origin()})
  add(at(back, 0, -0.24, -0.625), vinyl)
end

-- The front: round chrome headlamps, a small slatted grille, orange indicators.
for _, sx in ipairs({-1, 1}) do
  local zl = face_z(0.37, 1)
  add(cyl(0.1, 0.06, sx * 0.37, 0.08, zl, "z", 20), chrome)
  add(ball(0.082, 0.082, 0.035, sx * 0.37, 0.08, zl + 0.03, 16), lens)
  add(ball(0.035, 0.03, 0.03, sx * 0.47, -0.1, face_z(0.47, 1), 10), orange)
end
add(rb(0.38, 0.2, 0.03, 0, 0.0, ZF, 0.008), chrome)
add(rb(0.33, 0.155, 0.03, 0, 0.0, ZF + 0.01, 0.005), black)
for i = 0, 3 do add(rb(0.32, 0.014, 0.02, 0, -0.054 + i * 0.036, ZF + 0.022, 0.004), chrome) end
add(rb(0.014, 0.15, 0.02, 0, 0.0, ZF + 0.026, 0.004), chrome)

-- The back: tall red over amber tail lamps, a blank yellow plate, a boot handle and the boot lid's seam.
for _, sx in ipairs({-1, 1}) do
  local zt = face_z(0.47, -1)
  add(rb(0.1, 0.27, 0.03, sx * 0.46, 0.02, zt + 0.004, 0.006), chrome)
  add(rb(0.075, 0.14, 0.03, sx * 0.46, 0.07, zt - 0.006, 0.01), red)
  add(rb(0.075, 0.09, 0.03, sx * 0.46, -0.055, zt - 0.006, 0.01), amber)
end
add(rb(0.34, 0.1, 0.014, 0, -0.17, ZB - 0.003, 0.004), black)
add(rb(0.32, 0.08, 0.016, 0, -0.17, ZB - 0.006, 0.004), yellow)
add(rb(0.14, 0.022, 0.03, 0, 0.0, ZB - 0.005, 0.008), chrome)
add(rb(0.64, 0.008, 0.008, 0, 0.17, ZB - 0.002, 0.002), lime_dk)
add(rb(0.008, 0.36, 0.008, -0.32, -0.01, ZB - 0.002, 0.002), lime_dk)
add(rb(0.008, 0.36, 0.008, 0.32, -0.01, ZB - 0.002, 0.002), lime_dk)

-- Chrome bumpers, wrapping round the corners, with overriders.
for _, sz in ipairs({-1, 1}) do
  local zf = sz > 0 and ZF + 0.045 or ZB - 0.045
  local zs = sz > 0 and 1.2 or -1.2
  local y = -0.24
  add(tube({
    v3(-0.655, y, zs), v3(-0.665, y, zs + sz * 0.06), v3(-0.6, y, zf - sz * 0.01), v3(0, y, zf),
    v3(0.6, y, zf - sz * 0.01), v3(0.665, y, zs + sz * 0.06), v3(0.655, y, zs),
  }, 0.035, 10), chrome)
  for _, sx in ipairs({-1, 1}) do
    add(rb(0.05, 0.13, 0.05, sx * 0.3, y + 0.01, zf + sz * 0.015, 0.015), chrome)
  end
end

-- The sides: door seams, chrome handles, wing mirrors.
local HANDLE_Z, HANDLE_Y = -0.24, 0.18
for _, sx in ipairs({-1, 1}) do
  local xs = sx * (HX + 0.002)
  for _, z in ipairs({0.49, -0.33}) do
    local top = -0.42 + math.sqrt(math.max(0, AR * AR - (math.abs(z) - 0.7) ^ 2)) + 0.035
    add(rb(0.008, W - 0.04 - top, 0.008, xs, (W - 0.04 + top) * 0.5, z, 0.002), lime_dk)
  end
  add(rb(0.03, 0.03, 0.11, sx * (HX + 0.012), HANDLE_Y, HANDLE_Z, 0.01), chrome)
  add(rod(v3(sx * 0.6, W - 0.01, 0.56), v3(sx * 0.74, W + 0.09, 0.55), 0.014, 8), black)
  add(rb(0.05, 0.08, 0.11, sx * 0.76, W + 0.11, 0.54, 0.018), dark)
  add(rb(0.012, 0.065, 0.09, sx * 0.735, W + 0.11, 0.54, 0.004), C(0.7, 0.8, 0.88))
end

-- Underneath: the floor pan's subframes, the axle crossbars, stubs and hubs, an exhaust.
for _, z in ipairs({-0.7, 0.7}) do
  add(bar(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.05), dark)
  for _, sx in ipairs({-1, 1}) do
    add(rb(0.06, 0.07, 0.07, sx * 0.22, -0.385, z, 0.01), dark)
    add(rod(v3(sx * 0.47, -0.42, z), v3(sx * 0.535, -0.42, z), 0.022, 12), grey)
    add(cyl(0.034, 0.02, sx * 0.48, -0.42, z, "x", 8), chrome)
  end
end
add(rod(v3(0.28, -0.4, -0.3), v3(0.28, -0.4, -1.3), 0.025, 10), dark)
add(rod(v3(0.28, -0.4, -1.28), v3(0.28, -0.4, -1.38), 0.032, 12), chrome)

-- The roof load ------------------------------------------------------------------------------------------------
-- Each suitcase modelled about its base's middle, then tilted about z, turned about y and set down.
local cases = {}
local function xf(c, q)
  local a, b = rad(c.tilt), rad(c.yaw)
  local x, y = q.x * math.cos(a) - q.y * math.sin(a), q.x * math.sin(a) + q.y * math.cos(a)
  local z = q.z
  return v3(c.pos.x + x * math.cos(b) + z * math.sin(b), c.pos.y + y, c.pos.z - x * math.sin(b) + z * math.cos(b))
end
local function place(c, m)
  m = rotate(m, {angle=c.tilt, axis=axis_z(), pivot=origin()})
  m = rotate(m, {angle=c.yaw, axis=axis_y(), pivot=origin()})
  return translate(m, c.pos)
end
-- A suitcase's shell, its straps and handle, as { mesh, colour } in its own space.
local function suitcase(w, h, d, col, extra)
  local out = {}
  local function put(m, c) out[#out + 1] = {m, c} end
  put(rb(w, h, d, 0, h * 0.5, 0, math.min(h, d) * 0.22, 2), col)
  -- a seam round its middle
  put(rb(w + 0.006, 0.012, d + 0.006, 0, h * 0.5, 0, 0.004), shade(col, 0.6))
  -- the handle on its front, brass clasps either side
  put(tube({v3(-0.08, h * 0.55, d * 0.5 - 0.005), v3(-0.07, h * 0.55, d * 0.5 + 0.035),
    v3(0.07, h * 0.55, d * 0.5 + 0.035), v3(0.08, h * 0.55, d * 0.5 - 0.005)}, 0.012, 6), strap_c)
  for _, sx in ipairs({-1, 1}) do
    put(rb(0.035, 0.03, 0.012, sx * 0.13, h * 0.62, d * 0.5 + 0.003, 0.004), brass)
    put(rb(0.026, 0.026, 0.026, sx * 0.1, h * 0.55, d * 0.5 + 0.004, 0.006), strap_c)
  end
  if extra then extra(put, w, h, d) end
  return out
end
local function straps(xs, col)
  return function(put, w, h, d)
    for _, x in ipairs(xs) do put(rb(0.045, h + 0.016, d + 0.016, x * w, h * 0.5, 0, 0.006), col) end
  end
end
local function tartan(put, w, h, d)
  for _, x in ipairs({-0.36, -0.12, 0.12, 0.36}) do put(rb(0.07, h + 0.006, d + 0.006, x * w, h * 0.5, 0, 0.002), tart_grn) end
  for _, x in ipairs({-0.24, 0.0, 0.24}) do put(rb(0.012, h + 0.008, d + 0.008, x * w, h * 0.5, 0, 0.002), yellow) end
  for _, z in ipairs({-0.25, 0.25}) do put(rb(w + 0.012, h + 0.012, 0.05, 0, h * 0.5, z * d, 0.003), tart_nvy) end
end

local ROOF = RY + 0.077
local lean = p.lean
local defs = {
  { w = 1.0, h = 0.12, d = 0.62, col = leather, x = 0.02, z = -0.2, yaw = 4, tilt = 0, extra = straps({-0.3, 0.3}, strap_c) },
  { w = 0.86, h = 0.11, d = 0.54, col = tart_red, x = -0.05, z = -0.16, yaw = -7, tilt = lean * 0.5, extra = tartan },
  { w = 0.66, h = 0.095, d = 0.44, col = mint, x = 0.06, z = -0.25, yaw = 10, tilt = -lean, extra = straps({0.0}, cream) },
}
local top = ROOF
SIG = true
for i, c in ipairs(defs) do
  -- set down so its lowest corner just touches the one under it
  local y = top + c.w * 0.5 * math.sin(rad(math.abs(c.tilt))) + 0.002
  c.pos = v3(c.x, y, c.z)
  cases[i] = c
  for _, q in ipairs(suitcase(c.w, c.h, c.d, c.col, c.extra)) do add(place(c, q[1]), q[2]) end
  top = y + c.h + c.w * 0.5 * math.sin(rad(math.abs(c.tilt)))
end

-- The standard lamp, lying across the top: a brass pole resting on the top case, its foot at the back, its tasselled
-- shade drooping out over the windscreen.
local top_case = cases[3]
local yaw = rad(p.lamp_yaw)
local PR = 0.018
local mid = xf(top_case, v3(0, top_case.h, 0))
local dir = normalize(v3(math.sin(yaw), -0.07, math.cos(yaw)))
local pole_mid = mid + v3(0, PR + 0.004, 0) - v3(0, 0, 0)
local A = pole_mid - dir * 0.6       -- the foot's end
local B = pole_mid + dir * 0.66      -- the shade's end
local function pole_y(x, z)
  -- the pole's height above a point (x, z) and its distance off it across
  local rel = v3(x, 0, z) - v3(pole_mid.x, 0, pole_mid.z)
  local hd = normalize(v3(dir.x, 0, dir.z))
  local t = dot(rel, hd)
  local off = length(rel - hd * t)
  local y = pole_mid.y + dir.y * t / length(v3(dir.x, 0, dir.z))
  return y, off
end
do
  add(rod(A, B, PR, 10), brass)
  -- the foot: a round base and a dome, square to the pole
  local foot = cyl(0.1, 0.03, 0, 0, 0, "y", 16)
  local dome = lathe({{0.001, 0}, {0.08, 0}, {0.055, 0.04}, {0.02, 0.06}, {0.001, 0.065}}, 16)
  add(along(foot, A - dir * 0.03, A), brass)
  add(along(at(dome, 0, -0.0325, 0), A, A + dir * 0.065), brass)
  -- a knob part way up
  add(along(ball(0.03, 0.04, 0.03, 0, 0, 0, 10), B - dir * 0.36, B - dir * 0.28), brass)
  -- the shade: a thin open frustum, narrow end toward the pole, a trim and a fringe of tassels round its wide rim
  local L, r0, r1, t = 0.23, 0.065, 0.14, 0.008
  local sh = lathe({{r0, 0}, {r1, L}, {r1 - t, L}, {r0 - t, 0}}, 18)
  local s0 = B - dir * 0.1
  add(along(at(sh, 0, -L * 0.5, 0), s0, s0 + dir * L), shade_c)
  local ring = torus{major_radius=r1, minor_radius=0.01, major_segments=18, minor_segments=6, axis="y"}
  add(along(ring, s0 + dir * (L - 0.001), s0 + dir * (L + 0.001)), tassel)
  -- the bulb's fitting
  add(along(cylinder{radius=0.025, height=0.06, segments=10}, s0 - dir * 0.02, s0 + dir * 0.06), brass)
  -- the fringe: tassels hanging straight down from the rim
  local rim = s0 + dir * L
  local u = normalize(cross(dir, v3(0, 1, 0)))
  local v = normalize(cross(u, dir))
  for i = 0, 11 do
    local a = 2 * math.pi * (i + 0.5) / 12
    local q = rim + (u * math.cos(a) + v * math.sin(a)) * (r1 + 0.004)
    add(rod(q, q - v3(0, 0.06, 0), 0.006, 4), tassel)
    add(ball(0.014, 0.018, 0.014, q.x, q.y - 0.07, q.z, 6), tassel)
  end
end

-- The ropes: two over the top case and the lamp's pole, down over the cases' ends and the roof's edge to each side's
-- door handle, where they meet in a V.
do
  local RR = 0.011
  for _, zr in ipairs({-0.42, -0.08}) do
    local c = top_case
    -- across the top case, in its own space, lifted over the pole where it crosses
    local pts = {}
    local local_z = zr - c.pos.z
    local N = 16
    for i = 0, N do
      local lx = -c.w * 0.5 - 0.01 + (c.w + 0.02) * i / N
      local q = xf(c, v3(lx, c.h + RR + 0.003, local_z))
      local py, off = pole_y(q.x, q.z)
      if off < PR + RR + 0.03 then q = v3(q.x, math.max(q.y, py + PR + RR + 0.004 - off * 0.3), q.z) end
      pts[#pts + 1] = q
    end
    -- each end, down the cases to the roof's edge and the door handle
    local function down(sx)
      local out = {}
      local x = sx > 0 and pts[#pts] or pts[1]
      local reach = math.abs(x.x)
      for k = 3, 1, -1 do
        local ck = cases[k]
        local e = xf(ck, v3(sx * (ck.w * 0.5 + RR + 0.008), ck.h * (k == 3 and 0.5 or 1) + RR, zr - ck.pos.z))
        e = v3(e.x, e.y, zr)
        if k < 3 and math.abs(e.x) > reach then
          out[#out + 1] = e
          reach = math.abs(e.x)
        elseif k == 3 then
          out[#out + 1] = v3(x.x + sx * 0.002, e.y, zr)
          reach = math.abs(x.x)
        end
      end
      out[#out + 1] = v3(sx * 0.592, ROOF - 0.01, zr)
      out[#out + 1] = v3(sx * 0.6, ROOF - 0.08, zr)
      out[#out + 1] = v3(sx * (HX + 0.016), HANDLE_Y + 0.025, HANDLE_Z + (zr - (-0.25)) * 0.12)
      return out
    end
    local L, R = down(-1), down(1)
    local all_pts = {}
    for i = #L, 1, -1 do all_pts[#all_pts + 1] = L[i] end
    for _, q in ipairs(pts) do all_pts[#all_pts + 1] = q end
    for _, q in ipairs(R) do all_pts[#all_pts + 1] = q end
    add(tube(all_pts, RR, 6), rope_c)
  end
  -- the knots at the handles
  for _, sx in ipairs({-1, 1}) do add(ball(0.025, 0.025, 0.03, sx * (HX + 0.02), HANDLE_Y + 0.02, HANDLE_Z, 8), rope_c) end
end
SIG = false

part("minicar", pieces)
