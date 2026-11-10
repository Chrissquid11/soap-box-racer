-- Pram Pushing: a giant Victorian wicker pram for a kart body, one part "pram". A cream woven-basket tub with pink
-- bands and a pink padded rim, a big pleated cream hood folded up at the back with pink edging and struts to the tub,
-- a white push-handle bar out front, a pink padded seat, a white race-number roundel on each side, a little blue teddy
-- hanging off the front, and white curved springs and rails underneath. The spoked wheels are another slot.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x +-0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x +-0.5, z +-0.7, y -0.42.
local p = params{
  hood_tilt   = { default = 100, min = 60, max = 100, doc = "How far the hood is raised, degrees from lying back" },
  hood_size   = { default = 0.82, min = 0.65, max = 0.85, doc = "The hood's reach from its hinge, metres" },
  handle_top  = { default = 0.62, min = 0.45, max = 0.8, doc = "Height of the push-handle bar, metres" },
  pleats      = { default = 8, min = 4, max = 10, integer = true, doc = "Folds in the hood" },
}

local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.6, metallic=0}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
local function paint_if(m, c, fn)
  local sel = faces_where(m, fn)
  if set_count(sel) == 0 then return m end
  return paint_faces(m, {faces=sel, color=c})
end
-- A part of pieces, each { mesh, colour, angle }: merged into one mesh with its colours on its vertices.
-- A piece marked see-through (5th) is left out of it: emitted alone as `<name>_glass`, which the game draws in a
-- see-through material of its own (the hood: the driver shows through it from behind).
local function part(name, all)
  local pieces, glass = {}, {}
  for _, q in ipairs(all) do
    if q[5] then glass[#glass + 1] = q else pieces[#pieces + 1] = q end
  end
  local out = {}
  for i, q in ipairs(pieces) do
    local m = q[2] and paint(q[1], q[2]) or q[1]
    out[i] = {mesh=smooth_normals(m, {angle=q[3] or 35}), material=PAINT}
  end
  local merged = merge({parts=out, mode="compatible"})
  emit(merged[1].mesh, {name=name, material=merged[1].material})
  for _, q in ipairs(glass) do
    emit(smooth_normals(q[1], {angle=q[3] or 35}), {name=name .. "_glass", material=PAINT})
  end
  -- Its wreck, as the same pieces broken: what stays on the kart when the bodywork is knocked off (_wreck.lua).
  -- Its signature piece (a piece marked true, 4th) comes off alone as `<name>_sig` (_sig.lua), the rest to the wreck.
  local rest = include("_sig.lua").split(name, out, function(i) return pieces[i][4] end)
  include("_wreck.lua").emit(name, rest)
end
local function C(r, g, b) return v3(r, g, b) end
local function at(m, x, y, z) return translate(m, v3(x, y, z)) end
local function ball(rx, ry, rz, x, y, z, seg)
  local s = seg or 10
  return at(scale(sphere{radius=1, segments=s, rings=math.floor(s / 2)}, {factor=v3(rx, ry, rz), pivot=origin()}), x, y, z)
end
local function cyl(r, h, x, y, z, axis, seg) return at(cylinder{radius=r, height=h, segments=seg or 12, axis=axis or "y"}, x, y, z) end
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
local function tube(pts, r, seg) return sweep(circle{radius=r, segments=seg or 8}, path{points=pts}, {caps=true}) end
local function rbox(w, h, d, r, x, y, z, soft)
  local m = extrude(rounded_rect{w=w, h=d, radius=r, segments=3}, {distance=h})
  soft = math.min(soft, 2 * r * math.sin(math.pi / 12) * 0.45, h * 0.18)
  local straight = math.min(w, d) - 2 * r
  if straight > 0.001 then soft = math.min(soft, straight * 0.45) end
  m = bevel(m, {edges=convex_edges(m, {min_angle=60}), width=soft, segments=2})
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
-- A ring-swept oval solid: each ring { a, b, y } a superellipse a across x and b along z at height y; `closed` joins
-- the last ring to the first (a tube round the oval), else the ends are capped flat.
local function oval(rings, opt)
  local n, seg = opt.n or 2.6, opt.seg or 48
  local vs, fs = {}, {}
  for _, r in ipairs(rings) do
    for j = 0, seg - 1 do
      local t = 2 * math.pi * (j + 0.5) / seg
      local c, s = math.cos(t), math.sin(t)
      local cx = (c < 0 and -1 or 1) * math.abs(c) ^ (2 / n)
      local sz = (s < 0 and -1 or 1) * math.abs(s) ^ (2 / n)
      vs[#vs + 1] = v3(r[1] * cx, r[3], r[2] * sz)
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
-- A thick grid: ni by nj cells, pos(i, j, inner) the outer (false) or inner (true) surface's point, closed round its edges.
local function shell(ni, nj, pos)
  local vs, fs = {}, {}
  local W, N = nj + 1, (ni + 1) * (nj + 1)
  local function id(i, j, b) return (b and N or 0) + i * W + j + 1 end
  for _, b in ipairs({false, true}) do
    for i = 0, ni do
      for j = 0, nj do vs[#vs + 1] = pos(i, j, b) end
    end
  end
  for i = 0, ni - 1 do
    for j = 0, nj - 1 do
      fs[#fs + 1] = {id(i, j), id(i, j + 1), id(i + 1, j + 1), id(i + 1, j)}
      fs[#fs + 1] = {id(i + 1, j, true), id(i + 1, j + 1, true), id(i, j + 1, true), id(i, j, true)}
    end
  end
  local function side(a, b) fs[#fs + 1] = {a + N, b + N, b, a} end
  for j = 0, nj - 1 do
    side(id(0, j), id(0, j + 1))
    side(id(ni, j + 1), id(ni, j))
  end
  for i = 0, ni - 1 do
    side(id(i + 1, 0), id(i, 0))
    side(id(i, nj), id(i + 1, nj))
  end
  return solid(vs, fs)
end

local cream    = C(0.95, 0.91, 0.82)
local cream_dk = C(0.84, 0.79, 0.68)
local pink     = C(0.93, 0.45, 0.6)
local pink_dk  = C(0.82, 0.35, 0.5)
local white    = C(0.96, 0.96, 0.95)
local grey     = C(0.5, 0.52, 0.55)
local dark     = C(0.16, 0.16, 0.18)
local blue     = C(0.45, 0.68, 0.95)
local blue_lt  = C(0.68, 0.84, 1.0)
local black    = C(0.05, 0.05, 0.06)

local pieces = {}
-- `SIG` true while adding the signature's pieces (the teddy): marked 4th, for part().
local SIG = false
local function add(m, c, a) pieces[#pieces + 1] = {m, c, a, SIG} end

-- The tub: an open basket, cream wicker woven in a checker of light and darker strands, hollow down to its floor.
local TOP = 0.2
do
  local m = oval({
    {0.30, 0.62, -0.33},
    {0.38, 0.74, -0.31},
    {0.47, 0.84, -0.24},
    {0.53, 0.90, -0.12},
    {0.56, 0.93, 0.0},
    {0.57, 0.95, 0.1},
    {0.57, 0.95, TOP},
    {0.50, 0.88, TOP},
    {0.50, 0.88, -0.1},
    {0.42, 0.78, -0.2},
    {0.32, 0.66, -0.26},
  }, {seg=44, n=2.6})
  for k = 0, 10 do
    local walls = faces_where(m, function(f) return math.abs(f.normal.y) < 0.9 end)
    m = knife(m, {normal=axis_y(), point=v3(0, -0.2925 + k * 0.045, 0), faces=walls})
  end
  m = paint(m, cream)
  -- the weave: alternate strands darker, in rows up the wall and columns round it
  m = paint_if(m, cream_dk, function(f)
    if f.normal.y > 0.7 or f.normal.y < -0.7 then return false end
    local row = math.floor((f.center.y + 0.2925) / 0.045)
    local col = math.floor((math.atan(f.center.z / 0.93, f.center.x / 0.56) + math.pi) / (2 * math.pi) * 44)
    return (row + col) % 2 == 0
  end)
  add(m, nil, 20)
end
-- the pink bands round it: a broad one at the middle and a thin one under it
add(oval({
  {0.54, 0.91, -0.075}, {0.57, 0.94, -0.07}, {0.575, 0.945, -0.015}, {0.555, 0.925, -0.01},
}, {seg=44, n=2.6, closed=true}), pink, 50)
add(oval({
  {0.49, 0.86, -0.19}, {0.515, 0.885, -0.19}, {0.53, 0.9, -0.155}, {0.51, 0.88, -0.15},
}, {seg=44, n=2.6, closed=true}), pink, 50)
-- the padded rim round its top
add(oval({
  {0.48, 0.86, TOP - 0.03},
  {0.6, 0.98, TOP - 0.03},
  {0.625, 1.0, TOP + 0.03},
  {0.6, 0.98, TOP + 0.09},
  {0.5, 0.88, TOP + 0.1},
  {0.47, 0.85, TOP + 0.04},
}, {seg=44, n=2.6, closed=true}), pink, 60)

-- The seat: a pink cushion under the hips, a tall padded back of two pink rolls against the tub's back.
add(rbox(0.5, 0.05, 0.46, 0.1, 0, -0.27, -0.3, 0.02), pink, 50)
for i = 0, 2 do
  local m = rbox(0.5, 0.22, 0.12, 0.05, 0, 0, 0, 0.04)
  m = rotate(m, {angle=-10, axis=axis_x(), pivot=origin()})
  add(at(m, 0, -0.24 + i * 0.22, -0.62 - i * 0.04), (i % 2 == 0) and pink or pink_dk, 50)
end

-- The hood: pleated cream fabric on ribs that fold about a hinge across the tub's back, raised up behind the driver.
local HY, HZ = TOP + 0.08, -0.72
local HA = 0.6
local function hood_point(alpha, t, r, a)
  local d = r * math.sin(t) + 0.04
  local u = v3(0, math.sin(rad(alpha)), -math.cos(rad(alpha)))
  return v3(-a * math.cos(t), HY, HZ) + u * d
end
do
  local NI = p.pleats * 2
  local NJ = 16
  local A0, A1 = 12, p.hood_tilt
  local R = p.hood_size
  local m = shell(NI, NJ, function(i, j, inner)
    local alpha = A0 + (A1 - A0) * i / NI
    local t = math.pi * j / NJ
    local bulge = (i % 2 == 1) and 0.022 or 0
    if i == NI then bulge = 0 end
    local r = R + bulge - (inner and 0.03 or 0)
    local a = HA + bulge * 0.5 - (inner and 0.03 or 0)
    return hood_point(alpha, t, r, a)
  end)
  m = paint(m, cream)
  -- (see-through in the game: its own part, `pram_glass`)
  pieces[#pieces + 1] = {m, nil, 25, false, true}
  -- pink edging round its front opening
  local pts = {}
  for j = 0, 20 do pts[#pts + 1] = hood_point(A1, math.pi * j / 20, R + 0.005, HA + 0.005) end
  add(tube(pts, 0.035, 8), pink, 50)
  -- a pink edging along its back too, and the hinge bosses
  local bk = {}
  for j = 0, 20 do bk[#bk + 1] = hood_point(A0, math.pi * j / 20, R + 0.005, HA + 0.005) end
  add(tube(bk, 0.025, 8), pink_dk, 50)
  for _, sx in ipairs({-1, 1}) do
    add(cyl(0.06, 0.05, sx * (HA + 0.03), HY + 0.02, HZ, "x", 12), pink, 40)
    -- the struts: from the tub's side up to the hood's front edge
    local tt = math.acos(0.78)
    local top = hood_point(A1, sx < 0 and tt or math.pi - tt, R, HA)
    add(rod(v3(sx * 0.6, TOP + 0.02, 0.15), top + v3(sx * 0.035, 0, 0), 0.016, 8), white, 40)
    add(ball(0.03, 0.03, 0.03, sx * 0.6, TOP + 0.02, 0.15, 8), white, 40)
  end
end

-- The push handle: a white bar out front on two uprights rising from the rim, its corners rounded.
do
  local H = p.handle_top
  for _, sx in ipairs({-1, 1}) do
    local pts = {
      v3(sx * 0.42, TOP + 0.02, 0.8),
      v3(sx * 0.42, H - 0.1, 0.84),
      v3(sx * 0.41, H - 0.03, 0.86),
      v3(sx * 0.37, H, 0.87),
      v3(sx * 0.3, H, 0.87),
    }
    add(tube(pts, 0.025, 10), white, 50)
    add(cyl(0.04, 0.05, sx * 0.42, TOP + 0.04, 0.8, "y", 10), white, 40)
  end
  add(rod(v3(-0.31, H, 0.87), v3(0.31, H, 0.87), 0.028, 10), white, 50)
end

-- The roundels on each side: a white disc, pink-ringed, a dark number plate on it.
for _, sx in ipairs({-1, 1}) do
  local x = sx * 0.565
  add(cyl(0.13, 0.03, x, 0.02, 0.05, "x", 20), pink, 40)
  add(cyl(0.11, 0.03, x + sx * 0.01, 0.02, 0.05, "x", 20), white, 40)
end

-- The steering column: a short dark column from under the wheel down to the tub's floor.
add(rod(v3(0, 0.1, 0.15), v3(0, -0.26, 0.6), 0.022, 10), dark, 40)
add(cyl(0.035, 0.05, 0, 0.08, 0.17, "y", 10), dark, 40)

-- Underneath: white rails along the tub's bottom, curved C-springs to the axles, grey axle crossbars and stubs.
do
  for _, sx in ipairs({-1, 1}) do
    add(rod(v3(sx * 0.26, -0.36, -0.82), v3(sx * 0.26, -0.36, 0.82), 0.022, 8), white, 40)
    for _, z in ipairs({-0.7, 0.7}) do
      local dz = z < 0 and -1 or 1
      -- a C-spring: from the axle, curling out and up and back in to the tub's bottom
      local pts = {}
      for k = 0, 10 do
        local a = math.pi * 1.25 * k / 10 - math.pi * 0.5
        pts[#pts + 1] = v3(sx * 0.3, -0.37 + 0.08 * math.sin(a), z + dz * (0.04 + 0.08 * math.cos(a)))
      end
      add(tube(pts, 0.018, 8), white, 50)
      add(rod(v3(sx * 0.46, -0.42, z), v3(sx * 0.535, -0.42, z), 0.022, 10), grey, 40)
      add(cyl(0.034, 0.03, sx * 0.47, -0.42, z, "x", 8), white, 40)
      add(rod(v3(sx * 0.26, -0.36, z), v3(sx * 0.3, -0.43, z), 0.02, 8), white, 40)
    end
  end
  for _, z in ipairs({-0.7, 0.7}) do add(rod(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.026, 10), dark, 40) end
  -- the front bar the teddy hangs from
  add(rod(v3(-0.26, -0.36, 0.82), v3(0.26, -0.36, 0.82), 0.022, 8), white, 40)
  add(rod(v3(-0.26, -0.36, -0.82), v3(0.26, -0.36, -0.82), 0.022, 8), white, 40)
end

-- The teddy: a little blue bear sitting on the front bar, a pink bow at its neck.
do
  local X, Y, Z = 0.16, -0.3, 0.97
  SIG = true
  add(ball(0.07, 0.08, 0.06, X, Y, Z, 10), blue, 50)
  add(ball(0.065, 0.06, 0.06, X, Y + 0.12, Z + 0.01, 10), blue, 50)
  add(ball(0.03, 0.022, 0.02, X, Y + 0.105, Z + 0.065, 8), blue_lt, 50)
  add(ball(0.01, 0.009, 0.008, X, Y + 0.115, Z + 0.083, 6), black, 50)
  for _, s in ipairs({-1, 1}) do
    add(ball(0.025, 0.025, 0.015, X + s * 0.05, Y + 0.175, Z, 8), blue, 50)
    add(ball(0.009, 0.009, 0.006, X + s * 0.025, Y + 0.135, Z + 0.055, 6), black, 50)
    add(ball(0.028, 0.045, 0.028, X + s * 0.075, Y + 0.0, Z + 0.025, 8), blue, 50)
    add(ball(0.03, 0.028, 0.05, X + s * 0.04, Y - 0.06, Z + 0.05, 8), blue, 50)
    add(ball(0.025, 0.018, 0.012, X + s * 0.022, Y + 0.06, Z + 0.06, 6), pink, 50)
  end
  SIG = false
end

part("pram", pieces)
