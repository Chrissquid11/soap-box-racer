-- Rock Bottom: a stone-age log car for a kart body, one part "stoneage". A frame of knobbly logs with knuckled ends
-- runs along each side, lashed with crossed rope; a great stone roller across the front, a rough stone dashboard, a
-- red-brown hide seat with rope stitching round its edges, and four crooked poles holding a ragged canvas canopy high
-- overhead. A scrap of hide hangs under one side; under it all a plank deck on pole rails and axle crossbars.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x +-0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x +-0.5, z +-0.7, y -0.42.
local p = params{
  canopy_height = { default = 1.18, min = 1.05, max = 1.3, doc = "Height of the canopy's edge, metres" },
  roller_radius = { default = 0.27, min = 0.2, max = 0.32, doc = "Radius of the stone roller out front, metres" },
  log_radius    = { default = 0.1, min = 0.07, max = 0.13, doc = "Radius of the side logs, metres" },
  knobble       = { default = 0.018, min = 0, max = 0.03, doc = "How knobbly the logs are, metres" },
}

local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.8, metallic=0}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
-- A part of pieces, each { mesh, colour, angle }: merged into one mesh with its colours on its vertices.
local function part(name, pieces)
  local out = {}
  for i, q in ipairs(pieces) do
    local m = q[2] and paint(q[1], q[2]) or q[1]
    out[i] = {mesh=smooth_normals(m, {angle=q[3] or 35}), material=PAINT}
  end
  local merged = merge({parts=out, mode="compatible"})
  emit(merged[1].mesh, {name=name, material=merged[1].material})
  -- Its wreck, as the same pieces broken: what stays on the kart when the bodywork is knocked off (_wreck.lua).
  -- Its signature piece (a piece marked true, 4th) comes off alone as `<name>_sig` (_sig.lua), the rest to the wreck.
  local rest = include("_sig.lua").split(name, out, function(i) return pieces[i][4] end)
  include("_wreck.lua").emit(name, rest)
end
local function C(r, g, b) return v3(r, g, b) end
local function at(m, x, y, z) return translate(m, v3(x, y, z)) end
local function ball(rx, ry, rz, x, y, z, seg)
  local s = seg or 8
  return at(scale(sphere{radius=1, segments=s, rings=math.floor(s / 2)}, {factor=v3(rx, ry, rz), pivot=origin()}), x, y, z)
end
local function cyl(r, h, x, y, z, axis, seg) return at(cylinder{radius=r, height=h, segments=seg or 10, axis=axis or "y"}, x, y, z) end
local function along(m, a, b)
  local dir = normalize(b - a)
  local c = dot(v3(0, 1, 0), dir)
  if c < -0.9999 then m = rotate(m, {angle=180, axis=axis_x(), pivot=origin()})
  elseif c < 0.9999 then m = rotate(m, {angle=deg(math.acos(c)), axis=normalize(cross(v3(0, 1, 0), dir)), pivot=origin()}) end
  return translate(m, (a + b) * 0.5)
end
local function rod(a0, b0, r, seg)
  local a, b = lerp(a0, b0, 0.004), lerp(a0, b0, 0.996)
  return along(cylinder{radius=r, height=length(b - a), segments=seg or 6}, a, b)
end
-- A ring of rope round an axis through c: a torus turned from about y onto `axis`.
local function lash(c, axis, r, thick)
  local t = torus{major_radius=r, minor_radius=thick or 0.014, major_segments=12, minor_segments=5, axis="y"}
  return along(t, c - axis * 0.001, c + axis * 0.001)
end
-- A box with rounded corners about y, bevelled top and bottom, its base at y.
local function rbox(w, h, d, r, x, y, z, soft)
  local m = extrude(rounded_rect{w=w, h=d, radius=r, segments=3}, {distance=h})
  soft = math.min(soft, 2 * r * math.sin(math.pi / 12) * 0.45, h * 0.22)
  m = bevel(m, {edges=convex_edges(m, {min_angle=60}), width=soft, segments=1})
  return at(m, x, y, z)
end
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
-- A thin sheet over a grid: nx by nz cells across x0..x1, z0..z1, its top at y = fn(x, z), t thick.
local function sheet(nx, nz, x0, x1, z0, z1, t, fn)
  local vs, fs = {}, {}
  local W = nx + 1
  local function id(i, j, b) return (b and W * (nz + 1) or 0) + j * W + i + 1 end
  for _, b in ipairs({false, true}) do
    for j = 0, nz do
      for i = 0, nx do
        local x, z = x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz
        vs[#vs + 1] = v3(x, fn(x, z) - (b and t or 0), z)
      end
    end
  end
  for j = 0, nz - 1 do
    for i = 0, nx - 1 do
      fs[#fs + 1] = {id(i, j), id(i + 1, j), id(i + 1, j + 1), id(i, j + 1)}
      fs[#fs + 1] = {id(i, j + 1, true), id(i + 1, j + 1, true), id(i + 1, j, true), id(i, j, true)}
    end
  end
  local function side(a, b) fs[#fs + 1] = {a + W * (nz + 1), b + W * (nz + 1), b, a} end
  for i = 0, nx - 1 do
    side(id(i, 0), id(i + 1, 0))
    side(id(i + 1, nz), id(i, nz))
  end
  for j = 0, nz - 1 do
    side(id(nx, j), id(nx, j + 1))
    side(id(0, j + 1), id(0, j))
  end
  return solid(vs, fs)
end
-- A thin flat plate in the zy plane (facing x) from an outline of {z, y} points (star-shaped about its first edge's
-- middle), t thick.
local function plate(pts, t)
  local vs, fs = {}, {}
  local n = #pts
  for _, sx in ipairs({-0.5, 0.5}) do
    for _, q in ipairs(pts) do vs[#vs + 1] = v3(sx * t, q[2], q[1]) end
  end
  local a, b = {}, {}
  for i = 1, n do a[i] = i; b[i] = 2 * n + 1 - i end
  fs[1], fs[2] = a, b
  for i = 1, n do
    local j = i % n + 1
    fs[#fs + 1] = {j, i, n + i, n + j}
  end
  return solid(vs, fs)
end

local wood    = C(0.46, 0.27, 0.13)
local wood_dk = C(0.32, 0.18, 0.08)
local wood_lt = C(0.56, 0.35, 0.18)
local rope    = C(0.86, 0.72, 0.46)
local stone   = C(0.42, 0.44, 0.47)
local stone_lt= C(0.7, 0.7, 0.68)
local hide    = C(0.55, 0.2, 0.12)
local hide_dk = C(0.42, 0.14, 0.08)
local scrap   = C(0.82, 0.48, 0.42)
local canvas  = C(0.94, 0.85, 0.66)
local dark    = C(0.12, 0.1, 0.08)
local grey    = C(0.5, 0.5, 0.52)

local pieces = {}
local function add(m, c, a, sig) pieces[#pieces + 1] = {m, c, a, sig} end

-- A knobbly log from a to b: a swept tube with rings along it, its surface pushed about a little.
local function log(a, b, r, seed, col)
  local n = math.max(3, math.floor(length(b - a) / 0.12))
  local pts = {}
  for i = 0, n do
    local t = i / n
    local q = lerp(a, b, t)
    -- a gentle crook along it
    local wob = math.sin(t * math.pi * 2 + seed) * r * 0.12
    pts[#pts + 1] = q + v3(0, wob, 0)
  end
  local m = sweep(circle{radius=r, segments=8}, path{points=pts}, {caps=true})
  if p.knobble > 0 then m = displace(m, {amount=p.knobble, frequency=5, seed=seed}) end
  add(m, col or wood, 30)
end

-- The side frames: a big log along each side with knuckled ends (a lump above and below), a smaller one under it,
-- tied with crossed rope near each end.
local LR = p.log_radius
local SX, SY = 0.68, -0.1
for k, sx in ipairs({-1, 1}) do
  local x = sx * SX
  log(v3(x, SY, -1.12), v3(x, SY, 1.0), LR, k * 3, wood)
  log(v3(x - sx * 0.02, SY - LR * 1.55, -1.02), v3(x - sx * 0.02, SY - LR * 1.55, 0.9), LR * 0.62, k * 5 + 1, wood_dk)
  for _, z in ipairs({-1.12, 1.0}) do
    local dz = z < 0 and -1 or 1
    add(ball(LR * 0.85, LR * 0.8, LR * 0.9, x, SY + LR * 0.7, z + dz * 0.04, 8), wood_lt, 30)
    add(ball(LR * 0.85, LR * 0.8, LR * 0.9, x, SY - LR * 0.7, z + dz * 0.04, 8), wood_lt, 30)
  end
  -- crossed rope on the outside near each end
  for _, z in ipairs({-0.88, 0.78}) do
    local xo = x + sx * LR * 0.95
    add(rod(v3(xo, SY - LR * 0.9, z - 0.1), v3(xo, SY + LR * 0.9, z + 0.1), 0.016, 5), rope, 40)
    add(rod(v3(xo, SY + LR * 0.9, z - 0.1), v3(xo, SY - LR * 0.9, z + 0.1), 0.016, 5), rope, 40)
  end
  -- a ring of rope round the log by each pole
  for _, z in ipairs({-0.82, 0.6}) do
    add(lash(v3(x, SY, z - 0.07), axis_z(), LR + 0.01, 0.014), rope, 40)
    add(lash(v3(x, SY, z + 0.07), axis_z(), LR + 0.01, 0.014), rope, 40)
  end
end
-- the cross log at the back, knuckled ends past the side logs
log(v3(-0.82, SY - 0.02, -1.08), v3(0.82, SY - 0.02, -1.08), LR * 0.9, 11, wood)
for _, sx in ipairs({-1, 1}) do
  add(ball(0.08, 0.08, 0.075, sx * 0.84, SY + 0.04, -1.08, 8), wood_lt, 30)
  add(ball(0.08, 0.08, 0.075, sx * 0.84, SY - 0.08, -1.08, 8), wood_lt, 30)
  add(lash(v3(sx * 0.42, SY - 0.02, -1.08), axis_x(), LR * 0.9 + 0.01, 0.015), rope, 40)
  add(lash(v3(sx * 0.36, SY - 0.02, -1.08), axis_x(), LR * 0.9 + 0.01, 0.015), rope, 40)
end

-- The deck: planks across between the side logs, on two pole rails, with axle crossbars and stubs under it.
for i = 0, 10 do
  local z = -1.0 + i * 0.185
  add(rbox(1.26, 0.05, 0.17, 0.02, 0, -0.36, z, 0.01), (i % 2 == 0) and wood or wood_dk, 30)
end
for _, sx in ipairs({-1, 1}) do
  add(rod(v3(sx * 0.36, -0.4, -1.05), v3(sx * 0.36, -0.4, 1.0), 0.035, 7), wood_dk, 40)
  for _, z in ipairs({-0.7, 0.7}) do
    add(rod(v3(sx * 0.46, -0.42, z), v3(sx * 0.535, -0.42, z), 0.022, 10), grey, 40)
    add(cyl(0.034, 0.03, sx * 0.47, -0.42, z, "x", 8), dark, 40)
  end
  -- hangers from the deck out to the side logs
  for _, z in ipairs({-0.45, 0.35}) do
    add(rod(v3(sx * 0.6, -0.33, z), v3(sx * (SX - 0.02), SY - LR * 1.3, z), 0.03, 6), wood_dk, 40)
  end
end
for _, z in ipairs({-0.7, 0.7}) do add(rod(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.03, 8), wood_dk, 40) end

-- The stone roller across the front, on a log yoke from the side frames.
do
  local R = p.roller_radius
  local RZ, RY = 1.59 - R, -0.48 + R
  local m = cylinder{radius=R, height=1.2, segments=11, axis="x"}
  m = bevel(m, {edges=convex_edges(m, {min_angle=60}), width=0.035, segments=1})
  m = knife(m, {normal=axis_x(), point=v3(0.2, 0, 0)})
  m = knife(m, {normal=axis_x(), point=v3(-0.2, 0, 0)})
  m = displace(m, {amount=0.018, frequency=3, seed=4})
  add(at(m, 0, RY, RZ), stone, 25, true)
  -- the axle pins at its ends and the yoke arms back to the side logs
  for _, sx in ipairs({-1, 1}) do
    add(cyl(0.05, 0.06, sx * 0.63, RY, RZ, "x", 8), wood_dk, 40, true)
    add(rod(v3(sx * 0.67, RY, RZ), v3(sx * SX, SY, 0.92), 0.05, 7), wood, 40)
    add(lash(v3(sx * 0.67, RY, RZ), axis_x(), 0.055, 0.014), rope, 40)
  end
end

-- The stone dashboard ahead of the driver's legs, a stone knob on top, the steering column into it.
do
  local d = rbox(0.86, 0.36, 0.34, 0.07, 0, 0, 0, 0.04)
  d = knife(d, {normal=axis_y(), point=v3(0, 0.18, 0)})
  d = displace(d, {amount=0.012, frequency=4, seed=9})
  add(at(d, 0, -0.33, 0.66), stone_lt, 25)
  add(at(rotate(rbox(0.6, 0.12, 0.2, 0.05, 0, 0, 0, 0.03), {angle=-12, axis=axis_x(), pivot=origin()}), 0, 0.0, 0.62), stone_lt, 25)
  add(ball(0.08, 0.035, 0.07, 0.22, 0.12, 0.68, 7), wood, 30)
  add(rod(v3(0, 0.1, 0.15), v3(0, -0.05, 0.56), 0.022, 8), dark, 40)
  add(cyl(0.034, 0.05, 0, 0.08, 0.17, "y", 8), dark, 40)
end

-- The seat: a hide cushion under the hips and a rounded hide back, rope stitches round both.
do
  add(rbox(0.5, 0.06, 0.44, 0.1, 0, -0.29, -0.3, 0.02), hide, 40)
  local W, H, T = 0.5, 0.6, 0.08
  local back = extrude(rounded_rect{w=W, h=H, radius=0.2, segments=4}, {distance=T, anchor="center"})
  back = bevel(back, {edges=convex_edges(back, {min_angle=60}), width=0.02, segments=1})
  back = rotate(back, {angle=90, axis=axis_x(), pivot=origin()})
  back = rotate(translate(back, v3(0, H * 0.5, 0)), {angle=-10, axis=axis_x(), pivot=origin()})
  add(at(back, 0, -0.25, -0.6), hide, 40)
  -- the stitches round the back's rim: little rope dashes across its edge
  local tilt = rad(10)
  for i = 0, 17 do
    local a = 2 * math.pi * i / 18
    local ex, ey = math.cos(a) * W * 0.47, math.sin(a) * H * 0.47
    ex = math.max(-W * 0.47, math.min(W * 0.47, ex * 1.15))
    ey = math.max(-H * 0.47, math.min(H * 0.47, ey * 1.15))
    if math.abs(ex) > W * 0.4 and math.abs(ey) > H * 0.4 then ex, ey = ex * 0.82, ey * 0.9 end
    local yy = ey + H * 0.5
    local zz = -0.6 - yy * math.sin(tilt)
    local y = -0.25 + yy * math.cos(tilt)
    add(rod(v3(ex, y, zz - 0.055), v3(ex, y, zz + 0.055), 0.011, 4), rope, 40)
  end
  for i = 0, 7 do
    local x = -0.21 + i * 0.06
    add(rod(v3(x, -0.235, -0.09), v3(x, -0.3, -0.06), 0.01, 4), rope, 40)
  end
end

-- The poles: four crooked branches from the side logs up to the canopy, roped where they meet the logs.
local CH = p.canopy_height
local POLES = { {-1, -0.82}, {1, -0.82}, {-1, 0.6}, {1, 0.6} }
for k, pl in ipairs(POLES) do
  local sx, z = pl[1], pl[2]
  local x0 = sx * (SX - 0.03)
  local pts = {
    v3(x0, SY - 0.08, z),
    v3(x0 + sx * 0.03, SY + 0.35, z + 0.03),
    v3(x0 - sx * 0.02, SY + 0.75, z - 0.02),
    v3(x0 + sx * 0.01, CH + 0.04, z + 0.02),
  }
  local m = sweep(circle{radius=0.045, segments=7}, path{points=pts}, {caps=true, scale=0.8})
  add(m, (k % 2 == 0) and wood or wood_lt, 35)
  -- a stub of a branch off one side
  add(rod(pts[2] + v3(0, 0.05, 0), pts[2] + v3(sx * 0.05, 0.2, (z < 0) and 0.04 or -0.04), 0.022, 5), wood, 35)
  -- rope round the pole's foot and head
  add(lash(pts[1] + v3(0, LR + 0.06, 0), axis_y(), 0.05, 0.014), rope, 40)
  add(lash(pts[1] + v3(0, LR + 0.1, 0), axis_y(), 0.05, 0.014), rope, 40)
  add(lash(v3(x0 + sx * 0.01, CH - 0.06, z + 0.02), axis_y(), 0.048, 0.014), rope, 40)
end
-- the canopy's frame poles along each side and across, tied at the corners
for _, sx in ipairs({-1, 1}) do
  add(rod(v3(sx * (SX - 0.02), CH + 0.04, -1.02), v3(sx * (SX - 0.02), CH + 0.04, 0.82), 0.035, 6), wood, 35)
end
for _, z in ipairs({-0.82, 0.6}) do
  add(rod(v3(-0.8, CH + 0.06, z), v3(0.8, CH + 0.06, z), 0.032, 6), wood_dk, 35)
end

-- The canvas: a sheet over the frame, peaked in the middle and sagging between, its edges ragged.
do
  local function top(x, z)
    local peak = 0.13 * (1 - math.abs(x) / 0.85) * (1 - ((z + 0.15) / 1.0) ^ 2)
    local rag = 0.025 * math.sin(x * 23 + z * 7) * math.sin(z * 11)
    local droop = 0
    if z < -0.95 or z > 0.75 then droop = -0.05 end
    return CH + 0.11 + math.max(0, peak) + rag + droop
  end
  add(sheet(8, 10, -0.86, 0.86, -1.12, 0.85, 0.025, top), canvas, 25)
  -- tattered flaps hanging down at the front corners and one back side
  local function flap(x, z, w, h, sx, rotz)
    local f = plate({ {-w, 0}, {w, 0}, {w * 0.8, -h * 0.7}, {w * 0.3, -h}, {-w * 0.1, -h * 0.75}, {-w * 0.6, -h * 0.95}, {-w, -h * 0.5} }, 0.018)
    f = rotate(f, {angle=sx * (rotz or 8), axis=axis_z(), pivot=origin()})
    return at(f, x, CH + 0.1, z)
  end
  add(flap(-0.87, 0.62, 0.2, 0.32, -1, 10), canvas, 25)
  add(flap(0.87, -0.95, 0.15, 0.24, 1, 8), canvas, 25)
end

-- A scrap of hide hanging under the left side log.
do
  local f = plate({ {-0.14, 0}, {0.14, 0}, {0.12, -0.14}, {0.05, -0.1}, {0.0, -0.17}, {-0.06, -0.1}, {-0.13, -0.15} }, 0.015)
  add(at(f, -SX + 0.03, SY - LR * 1.9, 0.05), scrap, 25)
end

part("stoneage", pieces)
