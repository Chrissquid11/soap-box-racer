-- Pram Pushing: a giant Victorian wicker pram for a kart body, one part "pram". A cream woven-basket tub, pink-lined,
-- its padded pink rim sweeping up to the ends like a carriage's, a pink sash round its middle (the tub is two pieces
-- there: the lower basket stays on the wreck); a tall candy-striped pleated hood raised at the back (see-through:
-- `pram_glass`) with a beaded pink edge and folding stays; a swan-necked white push handle out front with a pink grip;
-- a pink padded seat, a race-number roundel on each side, white C-springs and rails underneath -- and the teddy (the
-- signature piece, `pram_sig`): a blue bear sat on the front rim, paws up on the handle. The spoked wheels are another slot.
--
-- In the kart's body space, metres: the origin the middle of the (hidden) chassis box's top, +z forward, y up. The
-- cockpit keeps clear of x +-0.28, z -0.5..0.45 above y -0.2; the wheels (another slot) sit at x +-0.5, z +-0.7, y -0.42.
local p = params{
  hood_tilt   = { default = 100, min = 60, max = 100, doc = "How far the hood is raised, degrees from lying back" },
  hood_size   = { default = 0.82, min = 0.65, max = 0.85, doc = "The hood's reach from its hinge, metres" },
  handle_top  = { default = 0.76, min = 0.5, max = 0.85, doc = "Height of the push-handle bar, metres" },
  pleats      = { default = 8, min = 4, max = 10, integer = true, doc = "Folds in the hood" },
  sheer       = { default = 0.08, min = 0, max = 0.12, doc = "How far the rim sweeps up at the back, metres" },
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
  local sig = include("_sig.lua")
  local rest, box = sig.split(name, out, function(i) return pieces[i][4] end)
  sig.box(name, box)
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
-- the last ring to the first (a tube round the oval), else the ends are capped flat. `warp`, given, moves each point.
local function oval(rings, opt)
  local n, seg = opt.n or 2.6, opt.seg or 48
  local vs, fs = {}, {}
  for _, r in ipairs(rings) do
    for j = 0, seg - 1 do
      local t = 2 * math.pi * (j + 0.5) / seg
      local c, s = math.cos(t), math.sin(t)
      local cx = (c < 0 and -1 or 1) * math.abs(c) ^ (2 / n)
      local sz = (s < 0 and -1 or 1) * math.abs(s) ^ (2 / n)
      local v = v3(r[1] * cx, r[3], r[2] * sz)
      vs[#vs + 1] = opt.warp and opt.warp(v) or v
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

local cream    = C(0.96, 0.91, 0.8)
local cream_dk = C(0.83, 0.74, 0.57)
local pink     = C(0.93, 0.45, 0.6)
local pink_dk  = C(0.8, 0.33, 0.49)
local pink_lt  = C(0.98, 0.74, 0.81)
local white    = C(0.96, 0.96, 0.95)
local grey     = C(0.5, 0.52, 0.55)
local dark     = C(0.16, 0.16, 0.18)
local blue     = C(0.45, 0.68, 0.95)
local blue_lt  = C(0.74, 0.88, 1.0)
local black    = C(0.05, 0.05, 0.06)

local pieces = {}
-- `SIG` true while adding the signature's pieces (the teddy): marked 4th, for part().
local SIG = false
local function add(m, c, a) pieces[#pieces + 1] = {m, c, a, SIG} end

-- The tub's shape: its outer half-width a (x) and half-length b (z) at a height, and the sheer -- above the sash
-- (y MID) everything rises towards the ends, more at the back, the rim's sweep.
local TOP, MID = 0.2, -0.04
local SEG, N = 40, 2.6
local PROF = {
  {-0.33, 0.30, 0.62}, {-0.31, 0.38, 0.74}, {-0.24, 0.47, 0.84}, {-0.12, 0.53, 0.90},
  {0.0, 0.56, 0.93}, {0.1, 0.57, 0.95}, {0.2, 0.575, 0.955},
}
local function prof(y)
  if y <= PROF[1][1] then return PROF[1][2], PROF[1][3] end
  for i = 2, #PROF do
    if y <= PROF[i][1] then
      local t = (y - PROF[i - 1][1]) / (PROF[i][1] - PROF[i - 1][1])
      return PROF[i - 1][2] + (PROF[i][2] - PROF[i - 1][2]) * t, PROF[i - 1][3] + (PROF[i][3] - PROF[i - 1][3]) * t
    end
  end
  return PROF[#PROF][2], PROF[#PROF][3]
end
local function sheer(z)
  local u = z / 0.95
  return (z < 0 and p.sheer or p.sheer * 0.55) * u * u
end
local function lift(v)
  local t = math.max(0, math.min(1, (v.y - MID) / (TOP - MID)))
  return v3(v.x, v.y + sheer(v.z) * t, v.z)
end
local function unlift(y, z)
  if y <= MID then return y end
  local k = sheer(z) / (TOP - MID)
  return math.min((y + k * MID) / (1 + k), TOP)
end
-- the wicker: a checker of light and darker strands on the outer wall, a soft pink lining inside
local ROW = 0.048
local function wicker(m)
  m = paint(m, cream)
  m = paint_if(m, cream_dk, function(f)
    if math.abs(f.normal.y) > 0.75 then return false end
    if f.normal.x * f.center.x + f.normal.z * f.center.z <= 0 then return false end
    local y = unlift(f.center.y, f.center.z)
    local a, b = prof(y)
    local cx, sz = f.center.x / a, f.center.z / b
    local ang = math.atan((sz < 0 and -1 or 1) * math.abs(sz) ^ (N / 2), (cx < 0 and -1 or 1) * math.abs(cx) ^ (N / 2))
    local col = math.floor((ang + math.pi) / (2 * math.pi) * SEG + 0.5)
    local row = math.floor((y - MID + 10 * ROW) / ROW)
    return (row + col) % 2 == 0
  end)
  return paint_if(m, pink_lt, function(f)
    if f.normal.y > 0.75 then return f.center.y < MID - 0.01 end
    return math.abs(f.normal.y) <= 0.75 and f.normal.x * f.center.x + f.normal.z * f.center.z < 0
  end)
end
do
  -- the lower basket: up to the sash, hollow down to its floor
  local rings = {{0.30, 0.62, -0.33}}
  for k = 6, 0, -1 do
    local y = MID - k * ROW
    if y > -0.325 then
      local a, b = prof(y)
      rings[#rings + 1] = {a, b, y}
    end
  end
  rings[#rings + 1] = {0.50, 0.88, MID}
  rings[#rings + 1] = {0.50, 0.88, -0.1}
  rings[#rings + 1] = {0.42, 0.78, -0.2}
  rings[#rings + 1] = {0.32, 0.66, -0.26}
  add(wicker(oval(rings, {seg=SEG, n=N})), nil, 20)
  -- the upper basket: a ring of wall from the sash to the rim, swept up at the ends
  local up = {}
  for k = 0, 5 do
    local y = math.min(MID + k * ROW, TOP)
    local a, b = prof(y)
    -- (its foot a hair in and up from the lower basket's top, so the two never share an edge)
    if k == 0 then up[#up + 1] = {a - 0.006, b - 0.006, y + 0.004} else up[#up + 1] = {a, b, y} end
  end
  up[#up + 1] = {0.50, 0.88, TOP}
  up[#up + 1] = {0.506, 0.886, MID + 0.004}
  add(wicker(oval(up, {seg=SEG, n=N, closed=true, warp=lift})), nil, 20)
end
-- a band round the tub from y0 to y1, standing `out` proud of the wall
local function band(y0, y1, out)
  local a0, b0 = prof(y0)
  local a1, b1 = prof(y1)
  return oval({
    {a0 - 0.02, b0 - 0.02, y0}, {a0 + out, b0 + out, y0 + 0.006}, {a1 + out, b1 + out, y1 - 0.006}, {a1 - 0.02, b1 - 0.02, y1},
  }, {seg=SEG, n=N, closed=true})
end
-- the pink sash round its middle, and a thin pink band lower down
add(band(MID - 0.045, MID + 0.035, 0.022), pink, 50)
add(band(-0.215, -0.18, 0.016), pink, 50)
-- the padded rim round its top, white piping under it
add(oval({
  {0.48, 0.86, TOP - 0.03},
  {0.61, 0.985, TOP - 0.03},
  {0.64, 1.01, TOP + 0.03},
  {0.615, 0.985, TOP + 0.09},
  {0.5, 0.88, TOP + 0.1},
  {0.47, 0.85, TOP + 0.04},
}, {seg=SEG, n=N, closed=true, warp=lift}), pink, 60)
add(oval({
  {0.55, 0.93, TOP - 0.06}, {0.6, 0.98, TOP - 0.06}, {0.605, 0.985, TOP - 0.025}, {0.55, 0.93, TOP - 0.02},
}, {seg=SEG, n=N, closed=true, warp=lift}), white, 50)

-- The seat: a pink cushion under the hips, a tall padded back of pink rolls against the tub's back.
add(rbox(0.5, 0.05, 0.46, 0.1, 0, -0.27, -0.3, 0.02), pink, 50)
for i = 0, 2 do
  local m = rbox(0.5, 0.22, 0.12, 0.05, 0, 0, 0, 0.04)
  m = rotate(m, {angle=-10, axis=axis_x(), pivot=origin()})
  add(at(m, 0, -0.24 + i * 0.22, -0.62 - i * 0.04), (i % 2 == 0) and pink or pink_dk, 50)
end

-- The hood: pleated fabric, candy-striped cream and pink, on ribs that fold about a hinge across the tub's back,
-- raised up behind the driver.
local HZ = -0.72
local HY = TOP + 0.06 + sheer(HZ)
local HA = 0.52
local function hood_point(alpha, t, r, a)
  local d = r * math.sin(t) + 0.04
  local u = v3(0, math.sin(rad(alpha)), -math.cos(rad(alpha)))
  return v3(-a * math.cos(t), HY, HZ) + u * d
end
do
  local NI = p.pleats * 2
  local NJ = 14
  local A0, A1 = 12, p.hood_tilt
  local R = p.hood_size
  local m = shell(NI, NJ, function(i, j, inner)
    local alpha = A0 + (A1 - A0) * i / NI
    local t = math.pi * j / NJ
    local bulge = (i % 2 == 1) and 0.03 or 0
    if i == NI then bulge = 0 end
    local r = R + bulge - (inner and 0.03 or 0)
    local a = HA + bulge * 0.5 - (inner and 0.03 or 0)
    return hood_point(alpha, t, r, a)
  end)
  m = paint(m, cream)
  m = paint_if(m, pink_lt, function(f)
    local alpha = deg(math.atan(f.center.y - HY, -(f.center.z - HZ)))
    return math.floor((alpha - A0) / (A1 - A0) * p.pleats) % 2 == 1
  end)
  -- (see-through in the game: its own part, `pram_glass`)
  pieces[#pieces + 1] = {m, nil, 25, false, true}
  -- pink edging round its front opening, white bobbles beaded along it
  local pts = {}
  for j = 0, 16 do pts[#pts + 1] = hood_point(A1, math.pi * j / 16, R + 0.005, HA + 0.005) end
  add(tube(pts, 0.034, 6), pink, 50)
  for j = 1, 9 do
    local c = hood_point(A1, math.pi * j / 10, R + 0.012, HA + 0.01)
    add(ball(0.045, 0.045, 0.045, c.x, c.y, c.z + 0.012, 6), white, 50)
  end
  -- a darker edging along its back too
  local bk = {}
  for j = 0, 12 do bk[#bk + 1] = hood_point(A0, math.pi * j / 12, R + 0.005, HA + 0.005) end
  add(tube(bk, 0.025, 6), pink_dk, 50)
  for _, sx in ipairs({-1, 1}) do
    -- the hinge bosses, a white button on each
    add(cyl(0.065, 0.05, sx * (HA + 0.03), HY + 0.02, HZ, "x", 12), pink, 40)
    add(cyl(0.035, 0.02, sx * (HA + 0.06), HY + 0.02, HZ, "x", 8), white, 40)
    -- the folding stays: from the tub's side up to the hood's front edge, a knuckle half way
    local tt = math.acos(0.78)
    local top = hood_point(A1, sx < 0 and tt or math.pi - tt, R, HA) + v3(sx * 0.035, 0, 0)
    local foot = v3(sx * 0.6, TOP + 0.02, 0.1)
    local mid = lerp(foot, top, 0.5)
    add(rod(foot, mid, 0.018, 6), white, 40)
    add(rod(mid, top, 0.018, 6), white, 40)
    add(ball(0.034, 0.034, 0.034, mid.x, mid.y, mid.z, 6), pink, 40)
    add(ball(0.036, 0.036, 0.036, foot.x, foot.y, foot.z, 6), white, 40)
  end
end

-- The push handle: two white swan-necked uprights rising from the front of the rim and leaning out ahead, a bar
-- across them with a pink grip.
local BAR_Z = 1.04
do
  local H = p.handle_top
  for _, sx in ipairs({-1, 1}) do
    local x = sx * 0.4
    local pts = {
      v3(x, 0.15, 0.77),
      v3(x, 0.38, 0.79),
      v3(x, H - 0.16, 0.9),
      v3(x, H - 0.05, 1.0),
      v3(x * 0.96, H - 0.01, BAR_Z - 0.01),
      v3(x * 0.85, H, BAR_Z),
    }
    add(tube(pts, 0.026, 8), white, 50)
    add(cyl(0.045, 0.05, x, TOP + 0.12, 0.775, "y", 10), white, 40)
  end
  add(rod(v3(-0.35, H, BAR_Z), v3(0.35, H, BAR_Z), 0.026, 8), white, 50)
  add(rod(v3(-0.27, H, BAR_Z), v3(0.27, H, BAR_Z), 0.04, 10), pink, 50)
end

-- The roundels on each side: a white disc, pink-ringed, over the sash.
for _, sx in ipairs({-1, 1}) do
  add(cyl(0.14, 0.09, sx * 0.535, -0.03, 0.05, "x", 20), pink, 40)
  add(cyl(0.11, 0.09, sx * 0.547, -0.03, 0.05, "x", 20), white, 40)
end

-- The steering column: a short dark column from under the wheel down to the tub's floor.
add(rod(v3(0, 0.1, 0.15), v3(0, -0.26, 0.6), 0.022, 8), dark, 40)
add(cyl(0.035, 0.05, 0, 0.08, 0.17, "y", 8), dark, 40)

-- Underneath: white rails along the tub's bottom, curved C-springs to the axles, grey axle crossbars and stubs.
do
  for _, sx in ipairs({-1, 1}) do
    add(rod(v3(sx * 0.26, -0.36, -0.82), v3(sx * 0.26, -0.36, 0.82), 0.022, 6), white, 40)
    for _, z in ipairs({-0.7, 0.7}) do
      local dz = z < 0 and -1 or 1
      -- a C-spring: from the axle, curling out and up and back in to the tub's bottom
      local pts = {}
      for k = 0, 8 do
        local a = math.pi * 1.25 * k / 8 - math.pi * 0.5
        pts[#pts + 1] = v3(sx * 0.3, -0.37 + 0.08 * math.sin(a), z + dz * (0.04 + 0.08 * math.cos(a)))
      end
      add(tube(pts, 0.02, 6), white, 50)
      add(rod(v3(sx * 0.46, -0.42, z), v3(sx * 0.535, -0.42, z), 0.022, 8), grey, 40)
      add(cyl(0.034, 0.03, sx * 0.47, -0.42, z, "x", 8), white, 40)
      add(rod(v3(sx * 0.26, -0.36, z), v3(sx * 0.3, -0.43, z), 0.02, 6), white, 40)
    end
  end
  for _, z in ipairs({-0.7, 0.7}) do add(rod(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.026, 8), dark, 40) end
  add(rod(v3(-0.26, -0.36, 0.82), v3(0.26, -0.36, 0.82), 0.022, 6), white, 40)
  add(rod(v3(-0.26, -0.36, -0.82), v3(0.26, -0.36, -0.82), 0.022, 6), white, 40)
end

-- The teddy: a blue bear sat on the front rim beside the driver's sightline, legs out over it, both paws up on the
-- handle's grip, a pink bow at its neck.
do
  local X, Z = 0.2, 0.84
  local Y = TOP + 0.1 + sheer(Z) - 0.01
  SIG = true
  add(ball(0.105, 0.12, 0.095, X, Y + 0.11, Z, 12), blue, 50)
  add(ball(0.07, 0.08, 0.03, X, Y + 0.1, Z + 0.075, 8), blue_lt, 50)
  add(ball(0.105, 0.095, 0.095, X, Y + 0.29, Z + 0.01, 12), blue, 50)
  add(ball(0.05, 0.04, 0.035, X, Y + 0.265, Z + 0.095, 8), blue_lt, 50)
  add(ball(0.018, 0.014, 0.012, X, Y + 0.283, Z + 0.128, 6), black, 50)
  add(ball(0.02, 0.02, 0.014, X, Y + 0.2, Z + 0.092, 6), pink_dk, 50)
  for _, s in ipairs({-1, 1}) do
    add(ball(0.044, 0.044, 0.024, X + s * 0.085, Y + 0.37, Z, 8), blue, 50)
    add(ball(0.026, 0.026, 0.012, X + s * 0.085, Y + 0.37, Z + 0.016, 6), blue_lt, 50)
    add(ball(0.014, 0.017, 0.01, X + s * 0.042, Y + 0.318, Z + 0.093, 6), black, 50)
    add(ball(0.042, 0.04, 0.075, X + s * 0.065, Y + 0.035, Z + 0.09, 8), blue, 50)
    add(ball(0.03, 0.03, 0.012, X + s * 0.065, Y + 0.04, Z + 0.165, 6), blue_lt, 50)
    add(ball(0.042, 0.028, 0.018, X + s * 0.045, Y + 0.2, Z + 0.085, 6), pink, 50)
    -- an arm, from the shoulder up to the handle
    local a = v3(X + s * 0.085, Y + 0.17, Z + 0.03)
    local b = v3(X + s * 0.09, p.handle_top - 0.005, BAR_Z - 0.015)
    local arm = scale(sphere{radius=1, segments=8, rings=4}, {factor=v3(0.036, length(b - a) * 0.5 + 0.02, 0.036), pivot=origin()})
    add(along(arm, a, b), blue, 50)
  end
  SIG = false
end

part("pram", pieces)
