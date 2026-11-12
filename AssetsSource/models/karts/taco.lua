-- Shell Suit: a giant taco for a kart body. Two tall golden shell panels stand either side of the driver, leaning out a
-- little, their top edges uneven and tapering to the front, open between them; chunky lettuce strips, short cheese
-- pieces and angular tomato chunks sit along their inner and top edges. Under it a narrow black square-tube chassis
-- with exposed crossbars, a silver diamond-plate footplate up front, a black front bumper, a plain seat and the
-- steering column. Low-poly and faceted, coloured on the vertices.
-- Each panel with its own food is its own part (`taco_panel_l` at +x, `taco_panel_r` at -x, and `_loose` centred): the
-- game knocks one off in a sideswipe. Everything else is the main part "taco" (no signature piece; its wreck as ever).
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up, +x the
-- kart's left. The cockpit keeps clear of x ±0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at
-- x ±0.5..0.6, z ±0.7, y -0.42, radius 0.2 -- the panels' bottoms lift over them.
local p = params{
  shell_top = {default=0.8, min=0.65, max=0.95, doc="Height of the shell panels' tops, metres"},
  length    = {default=1.0, min=0.9, max=1.1, doc="Half the shell's length along the kart, metres"},
  lean      = {default=10, min=0, max=14, doc="How far the shell panels lean out, degrees"},
  lettuce   = {default=13, min=6, max=20, integer=true, doc="Lettuce strips along each panel's edge"},
  wobble    = {default=0.03, min=0, max=0.05, doc="Unevenness of the panels' top edges, metres"},
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

local shell   = C(1.0, 0.62, 0.06)
local shellin = C(0.92, 0.5, 0.04)
local toast   = C(0.82, 0.36, 0.02)
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
local Y0 = -0.44    -- the panels' bottoms between the wheels
local YA = -0.15    -- and lifted over the wheels
local X0, T = 0.34, 0.07
local TL = math.tan(math.rad(p.lean))
local ZR, ZF = -(L + 0.05), L
local pieces = {}
local function add(m, c, angle) pieces[#pieces + 1] = {m, c, false, angle=angle} end

-- The bits that come off on their own (the game's BODY bits): each its own part, drawn in place on the body as
-- `taco_<bit>`, and again centred on its own middle as `taco_<bit>_loose` to tumble away when it is knocked off. Their
-- bounds (centre and size, body space) are said for the game's table.
local function bit(name, list)
  local out = {}
  for i, pc in ipairs(list) do
    local m = pc[2] and paint(pc[1], pc[2]) or pc[1]
    out[i] = {mesh=smooth_normals(m, {angle=pc.angle or 30}), material=PAINT}
  end
  local merged = merge({parts=out, mode="compatible"})[1]
  emit(merged.mesh, {name="taco_" .. name, material=merged.material})
  local b = bbox(merged.mesh)
  emit(translate(merged.mesh, v3(0, 0, 0) - b.center), {name="taco_" .. name .. "_loose", material=merged.material})
  warn(string.format("bit %s: at {%.3f, %.3f, %.3f} size {%.3f, %.3f, %.3f}", name, b.center.x, b.center.y, b.center.z, b.size.x, b.size.y, b.size.z))
end

local function smooth01(t)
  t = math.max(0, math.min(1, t))
  return t * t * (3 - 2 * t)
end
-- A panel's outline at z: its bottom (down between the wheels, lifted over them) and, at u (0 the back, 1 the front),
-- its top -- a blunt back, the peak behind the middle, a long taper to the front, and a handmade wobble along it.
local function bottom_y(z) return Y0 + (YA - Y0) * smooth01((math.abs(z) - 0.36) / 0.12) end
local function top_y(sx, u)
  local s = math.sin(math.pi * u ^ 0.75) ^ 0.55
  local ph = sx > 0 and 0.7 or 2.9
  local wob = p.wobble * (math.sin(u * 19 + ph) + 0.65 * math.sin(u * 37 + 2 * ph)) * math.min(1, s * 1.6)
  return YA + 0.07 + (p.shell_top - YA - 0.07) * s + wob
end
local function z_at(u) return ZR + (ZF - ZR) * u end
-- The panel's middle plane at height y and z, on side sx: its x (leaning out, drawing in toward the front).
local function shell_x(sx, y, z)
  local ph = sx > 0 and 0.7 or 2.9
  return sx * (X0 + T / 2 + (y - Y0) * TL - 0.07 * smooth01((z - 0.35) / 0.65) + 0.008 * math.sin(z * 8 + ph))
end

-- The shell panels, each with its own filling ---------------------------------------------------------------------
for _, sx in ipairs({1, -1}) do
  local list = {}
  local function put(m, c, angle) list[#list + 1] = {m, c, angle=angle} end

  -- the panel: a slab through stations along the kart, each { inner bottom, inner top, outer top, outer bottom }
  do
    local N = 30
    local vs, fs = {}, {}
    for i = 0, N do
      local u = 0.5 - 0.5 * math.cos(math.pi * i / N)
      local z = z_at(u)
      local yb, yt = bottom_y(z), top_y(sx, u)
      local xb, xt = shell_x(sx, yb, z), shell_x(sx, yt, z)
      vs[#vs + 1] = v3(xb - sx * T / 2, yb, z)
      vs[#vs + 1] = v3(xt - sx * T / 2, yt, z)
      vs[#vs + 1] = v3(xt + sx * T / 2, yt, z)
      vs[#vs + 1] = v3(xb + sx * T / 2, yb, z)
    end
    local function id(i, j) return i * 4 + (j % 4) + 1 end
    for i = 0, N - 1 do
      for j = 0, 3 do fs[#fs + 1] = {id(i, j), id(i, j + 1), id(i + 1, j + 1), id(i + 1, j)} end
    end
    fs[#fs + 1] = {id(0, 3), id(0, 2), id(0, 1), id(0, 0)}
    fs[#fs + 1] = {id(N, 0), id(N, 1), id(N, 2), id(N, 3)}
    local side = solid(vs, fs)
    side = paint(side, shell)
    side = paint_faces(side, {faces=faces_where(side, function(f) return f.normal.x * sx < -0.8 end), color=shellin})
    put(side, nil, 20)
    -- toasted blisters on its outside: low dark-gold discs, here and there
    for i = 1, 6 do
      local u = 0.16 + 0.66 * (i - 0.5) / 6 + rnd(-0.03, 0.03)
      local z = z_at(u)
      local y = bottom_y(z) + (top_y(sx, u) - bottom_y(z)) * rnd(0.3, 0.75)
      local d = cylinder{radius=rnd(0.035, 0.06), height=0.014, segments=7, axis="x"}
      d = rotate(d, {angle=-sx * p.lean, axis=axis_z(), pivot=origin()})
      put(at(d, shell_x(sx, y, z) + sx * T / 2, y, z), toast, 20)
    end
  end

  -- lettuce: chunky strips standing against the inside of the edge and poking over it
  local n = p.lettuce
  for i = 1, n do
    local u = 0.07 + 0.86 * (i - 0.5) / n + rnd(-0.012, 0.012)
    local z = z_at(u)
    local y = top_y(sx, u) + rnd(-0.01, 0.05)
    local s = box{size=v3(0.04, rnd(0.17, 0.27), rnd(0.085, 0.12))}
    s = rotate(s, {angle=rnd(-30, 30), axis=axis_x(), pivot=origin()})
    s = rotate(s, {angle=-sx * (p.lean + rnd(-6, 14)), axis=axis_z(), pivot=origin()})
    put(at(s, shell_x(sx, y, z) - sx * (T / 2 + 0.012), y, z), (i % 3 == 0) and green2 or green, 25)
  end
  -- cheese: short square pieces lying along the top of the edge
  for i = 1, 8 do
    local u = 0.12 + 0.76 * (i - 0.5) / 8 + rnd(-0.025, 0.025)
    local z = z_at(u)
    local y = top_y(sx, u) + 0.022
    local s = box{size=v3(0.04, 0.04, rnd(0.12, 0.17))}
    s = rotate(s, {angle=rnd(-30, 30), axis=axis_x(), pivot=origin()})
    s = rotate(s, {angle=rnd(-40, 40), axis=axis_y(), pivot=origin()})
    put(at(s, shell_x(sx, y, z) + sx * rnd(-0.01, 0.02), y, z), cheese, 25)
  end
  -- tomato: angular chunks wedged inside the edge
  for i = 1, 5 do
    local u = 0.2 + 0.6 * (i - 0.5) / 5 + rnd(-0.04, 0.04)
    local z = z_at(u)
    local y = top_y(sx, u) + rnd(-0.03, 0.03)
    local m = box{size=v3(rnd(0.08, 0.1), rnd(0.075, 0.095), rnd(0.085, 0.11))}
    m = turned(m, rnd(15, 75), v3(rnd(-1, 1), rnd(0.2, 1), rnd(-1, 1)))
    put(at(m, shell_x(sx, y, z) - sx * (T / 2 + 0.03), y, z), tomato, 15)
  end

  bit(sx > 0 and "panel_l" or "panel_r", list)
end

-- The seat: a plain black seat, its cushion under the hips and its square back with rounded top behind them.
do
  add(rb(0.48, 0.06, 0.42, 0, -0.25, -0.3, 0.02, 2), black)
  local back = extrude(rounded_rect{w=0.46, h=0.6, radius=0.09, segments=4}, {distance=0.08, anchor="center"})
  back = rotate(back, {angle=90, axis=axis_x(), pivot=origin()})
  back = bevel(back, {edges=convex_edges(back, {min_angle=60}), width=0.015, segments=2})
  back = rotate(back, {angle=-10, axis=axis_x(), pivot=v3(0, -0.3, 0)})
  add(at(back, 0, 0.02, -0.6), black, 35)
  add(rb(0.4, 0.1, 0.06, 0, -0.33, -0.6, 0.015), dark)
  -- its posts, down to the crossbars
  for _, sx in ipairs({-1, 1}) do
    for _, z in ipairs({-0.45, -0.15}) do add(rb(0.04, 0.18, 0.04, sx * 0.17, -0.365, z, 0.006), black) end
  end
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

-- The chassis: narrow black square tube, its crossbars bare between the panels; a bumper out front on two stays -----
do
  local S = 0.05
  local RX, RY = 0.33, -0.47
  local function frame(a, b, s) add(bar(a, b, s or S), black, 30) end
  for _, sx in ipairs({-1, 1}) do
    frame(v3(sx * RX, RY, -0.98), v3(sx * RX, RY, 0.98))
    for _, z in ipairs({-0.7, 0.7}) do
      add(rod(v3(sx * 0.47, -0.42, z), v3(sx * 0.535, -0.42, z), 0.022, 12), grey)
      add(cyl(0.032, 0.02, sx * 0.47, -0.42, z, "x", 6), dark)
    end
    frame(v3(sx * 0.22, -0.455, 0.96), v3(sx * 0.22, -0.42, 1.03), 0.04)
  end
  for _, z in ipairs({-0.7, 0.7}) do frame(v3(-0.47, -0.42, z), v3(0.47, -0.42, z)) end
  for _, z in ipairs({-0.955, -0.45, -0.15, 0.955}) do frame(v3(-RX, RY, z), v3(RX, RY, z)) end
  frame(v3(-RX, RY, 0.3), v3(RX, RY, 0.3), 0.04)
  frame(v3(-RX, RY, -0.955), v3(RX, RY, -0.45), 0.035)
  frame(v3(RX, RY, -0.955), v3(-RX, RY, -0.45), 0.035)
  add(rb(0.92, 0.1, 0.07, 0, -0.41, 1.05, 0.022, 2), black, 35)
end

part("taco", pieces)
