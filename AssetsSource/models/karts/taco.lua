-- Taco Tuesday: a giant taco shell for a kart body, one part "taco". Two tall half-disc shell sides stand either side
-- of the driver, leaning out a little and joined by a floor at the bottom; green lettuce shreds spill over their top
-- edges with red tomato chunks and orange cheese strips; a black seat inside, a checker-plate footplate up front and a
-- black square-tube frame under it all. Low-poly and faceted, coloured on the vertices.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x ±0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x ±0.5, z ±0.7, y -0.42.
local p = params{
  shell_top = {default=0.8, min=0.65, max=0.95, doc="Height of the shell sides' tops, metres"},
  length    = {default=1.0, min=0.9, max=1.1, doc="Half the shell's length along the kart, metres"},
  lean      = {default=8, min=0, max=14, doc="How far the shell sides lean out, degrees"},
  lettuce   = {default=95, min=40, max=130, integer=true, doc="Lettuce shreds along each shell's edge"},
}

local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.7, metallic=0}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
local function part(name, pieces)
  local out = {}
  for i, pc in ipairs(pieces) do
    local m = pc[2] and paint(pc[1], pc[2]) or pc[1]
    out[i] = {mesh=smooth_normals(m, {angle=pc.angle or 30}), material=PAINT}
  end
  local merged = merge({parts=out, mode="compatible"})
  emit(merged[1].mesh, {name=name, material=merged[1].material})
  -- Its signature piece (the pieces marked, 3rd): `<name>_sig`, and left out of the wreck (_sig.lua).
  local rest = include("_sig.lua").split(name, out, function(i) return pieces[i][3] end)
  -- Its wreck, as the same pieces broken: what stays on the kart when the bodywork is knocked off (_wreck.lua).
  include("_wreck.lua").emit(name, rest)
end
local function C(r, g, b) return v3(r, g, b) end
local function at(m, x, y, z) return translate(m, v3(x, y, z)) end
local function rb(sx, sy, sz, x, y, z, w, seg)
  local m = box{size=v3(sx, sy, sz)}
  return at(bevel(m, {edges=convex_edges(m), width=w or math.min(sx, sy, sz) * 0.2, segments=seg or 1}), x, y, z)
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
-- A square tube from a to b, s across.
local function bar(a0, b0, s)
  local a, b = lerp(a0, b0, 0.002), lerp(a0, b0, 0.998)
  local m = box{size=v3(s, length(b - a), s)}
  local long = edges_where(m, function(e) return math.abs(e.direction.y) > 0.9 end)
  local edges = set_subtract(long, set_subtract(long, convex_edges(m, {min_angle=60})))
  return along(bevel(m, {edges=edges, width=s * 0.18, segments=1}), a, b)
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
-- A slab of a convex outline: pts are { u, v } pairs, place(u, v, w) the point at side w (-1 or 1).
local function slab(pts, place)
  local vs, fs = {}, {}
  local n = #pts
  local a, b = {}, {}
  for i, q in ipairs(pts) do
    vs[i] = place(q[1], q[2], -1)
    vs[n + i] = place(q[1], q[2], 1)
  end
  for i = 1, n do
    a[i] = i
    b[i] = 2 * n + 1 - i
    local j = i % n + 1
    fs[#fs + 1] = {j, i, n + i, n + j}
  end
  fs[#fs + 1] = a
  fs[#fs + 1] = b
  return solid(vs, fs)
end
-- A little repeatable random stream (no global random in Gladius).
local seed = 20261108
local function rnd(a, b)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return a + (b - a) * seed / 2147483648
end
local function turned(m, ang, ax) return rotate(m, {angle=ang, axis=normalize(ax), pivot=origin()}) end

local shell   = C(1.0, 0.56, 0.03)
local shellin = C(0.9, 0.42, 0.02)
local green   = C(0.12, 0.6, 0.02)
local green2  = C(0.3, 0.75, 0.03)
local tomato  = C(0.8, 0.03, 0.02)
local cheese  = C(1.0, 0.28, 0.0)
local black   = C(0.025, 0.025, 0.03)
local dark    = C(0.08, 0.08, 0.09)
local steel   = C(0.55, 0.57, 0.6)
local steel2  = C(0.7, 0.72, 0.75)
local grey    = C(0.45, 0.46, 0.5)

local L = p.length
local Y0 = -0.44
local H = p.shell_top - Y0
local X0, T = 0.34, 0.07
local SK = 0.22     -- how far back the shell's peak sits
local TL = math.tan(math.rad(p.lean))
local pieces = {}
-- While `sig` is true, what is added is the signature piece: the filling, flung out when the bodywork goes.
local sig = false
local function add(m, c, angle) pieces[#pieces + 1] = {m, c, sig, angle=angle} end

-- The shell's middle plane at height y, on side sx: its x.
local function shell_x(sx, y) return sx * (X0 + T / 2 + (y - Y0) * TL) end
-- The point on the shell's top edge at t (0 the front, pi the back).
local function edge(sx, t)
  local y = Y0 + H * math.sin(t)
  return v3(shell_x(sx, y), y, L * math.cos(t) - SK * math.sin(t)), v3(0, math.sin(t) / H, math.cos(t) / L)
end

-- The shell sides ---------------------------------------------------------------------------------------------
for _, sx in ipairs({-1, 1}) do
  local pts = {}
  local N = 16
  for i = 0, N do
    local t = math.pi * i / N
    pts[#pts + 1] = {L * math.cos(t) - SK * math.sin(t), Y0 + H * math.sin(t)}
  end
  local side = slab(pts, function(u, v, w) return v3(shell_x(sx, v) + w * T / 2, v, u) end)
  side = bevel(side, {edges=convex_edges(side, {min_angle=50}), width=0.018, segments=1})
  side = paint(side, shell)
  side = paint_faces(side, {faces=faces_where(side, function(f) return f.normal.x * sx < -0.8 end), color=shellin})
  add(side, nil, 20)
end
-- the fold at the bottom: a floor joining the sides, under the seat
add(rb(2 * X0 + 0.04, 0.13, 1.25, 0, Y0 + 0.065, -0.33, 0.02), shellin, 30)

-- The filling along the top edges: lettuce shreds, cheese strips, tomato chunks --------------------------------
sig = true
for _, sx in ipairs({-1, 1}) do
  local n = p.lettuce
  for i = 1, n do
    local t = math.pi * (0.06 + 0.88 * (i - 0.5) / n) + rnd(-0.02, 0.02)
    local e, nrm = edge(sx, t)
    nrm = normalize(nrm)
    local c = e + nrm * rnd(-0.01, 0.05) + v3(rnd(-0.1, 0.1), 0, 0)
    local s = box{size=v3(0.022, rnd(0.12, 0.2), 0.034)}
    s = turned(s, rnd(-70, 70), v3(rnd(-1, 1), rnd(-0.3, 0.3), rnd(-1, 1)))
    add(translate(s, c), (i % 3 == 0) and green2 or green, 25)
  end
  for i = 1, 16 do
    local t = math.pi * (0.12 + 0.76 * (i - 0.5) / 16) + rnd(-0.04, 0.04)
    local e, nrm = edge(sx, t)
    local c = e + normalize(nrm) * rnd(0.01, 0.04) + v3(rnd(-0.05, 0.05), 0, 0)
    local s = box{size=v3(0.025, 0.014, rnd(0.11, 0.16))}
    s = turned(s, rnd(-50, 50), v3(rnd(-0.3, 0.3), rnd(-1, 1), rnd(-0.3, 0.3)))
    add(translate(s, c), cheese, 25)
  end
  for i = 1, 4 do
    local t = math.pi * (0.22 + 0.56 * (i - 0.5) / 4) + rnd(-0.06, 0.06)
    local e, nrm = edge(sx, t)
    local c = e - normalize(nrm) * rnd(0.06, 0.16)
    c = v3(shell_x(sx, c.y) - sx * (T / 2 + 0.02), c.y, c.z)
    local r = rnd(0.05, 0.065)
    local m = sphere{radius=r, segments=6, rings=4}
    m = turned(m, rnd(0, 90), v3(rnd(-1, 1), 1, rnd(-1, 1)))
    add(translate(m, c), tomato, 15)
  end
end
sig = false

-- The seat: a plain black seat, its cushion under the hips and its square back with rounded top behind them.
do
  add(rb(0.48, 0.06, 0.42, 0, -0.25, -0.3, 0.02, 2), black)
  local back = extrude(rounded_rect{w=0.46, h=0.6, radius=0.09, segments=4}, {distance=0.08, anchor="center"})
  back = rotate(back, {angle=90, axis=axis_x(), pivot=origin()})
  back = bevel(back, {edges=convex_edges(back, {min_angle=60}), width=0.015, segments=2})
  back = rotate(back, {angle=-10, axis=axis_x(), pivot=v3(0, -0.3, 0)})
  add(at(back, 0, 0.02, -0.6), black, 35)
  add(rb(0.4, 0.1, 0.06, 0, -0.33, -0.6, 0.015), dark)
end

-- The steering column: from under the wheel's hub down to the front of the footplate.
add(rod(v3(0, 0.115, 0.15), v3(0, -0.31, 0.62), 0.018, 10), dark)
add(rb(0.07, 0.03, 0.07, 0, -0.32, 0.62, 0.008), dark)

-- The footplate: checker plate between the shells' fronts, a grid of raised diamonds on it.
do
  local Z0, Z1, Y = 0.29, 0.93, -0.36
  add(rb(2 * X0, 0.03, Z1 - Z0, 0, Y, (Z0 + Z1) / 2, 0.006), steel)
  for i = 0, 5 do
    for j = 0, 7 do
      local x = -0.25 + i * 0.1 + ((j % 2) * 0.05)
      local z = Z0 + 0.05 + j * 0.077
      if x < 0.29 then
        local d = rotate(box{size=v3(0.05, 0.008, 0.016)}, {angle=(j % 2 == 0) and 45 or -45, axis=axis_y(), pivot=origin()})
        add(at(d, x, Y + 0.018, z), steel2, 20)
      end
    end
  end
end

-- The frame: black square tube ---------------------------------------------------------------------------------
do
  local S = 0.05
  local RX, RY = 0.34, -0.47
  local function frame(a, b, s) add(bar(a, b, s or S), black, 30) end
  for _, sx in ipairs({-1, 1}) do
    frame(v3(sx * RX, RY, -0.98), v3(sx * RX, RY, 0.98))
    for _, z in ipairs({-0.7, 0.7}) do
      add(rod(v3(sx * 0.47, -0.42, z), v3(sx * 0.535, -0.42, z), 0.022, 12), grey)
      add(cyl(0.032, 0.02, sx * 0.47, -0.42, z, "x", 6), dark)
    end
  end
  for _, z in ipairs({-0.7, 0.7}) do frame(v3(-0.47, -0.42, z), v3(0.47, -0.42, z)) end
  frame(v3(-RX, RY, -0.955), v3(RX, RY, -0.955))
  frame(v3(-RX, RY, 0.955), v3(RX, RY, 0.955))
  frame(v3(-RX, RY, 0.3), v3(RX, RY, 0.3), 0.04)
end

part("taco", pieces)
