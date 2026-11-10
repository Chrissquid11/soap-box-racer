-- Gravity Well: a low, fully enclosed gravity-racer streamliner for a kart body, one part "streamliner". A long faceted
-- shell, navy over black, a needle nose rising to a chopped tail, an orange swoosh down each upper flank, orange
-- italic bars for the name on each black side between grey panels, a silver collar round the cockpit hole and an
-- orange roll hoop behind it. The shell keeps within x +-0.42 so the wheel slot's wheels (x +-0.5, z +-0.7,
-- y -0.42) show outside it. In the kart's body space: the origin the middle of the (hidden) chassis box's top,
-- +z forward, metres.
local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.4, metallic=0}

local p = params{
  half_width = { default = 0.42, min = 0.34, max = 0.44, doc = "Half the shell's width at its widest, metres" },
  roof       = { default = 0.08, min = -0.02, max = 0.2, doc = "Height of the shell's top behind the cockpit, metres" },
  nose_reach = { default = 1.52, min = 1.3, max = 1.55, doc = "How far forward the nose tip reaches, metres" },
  hoop_top   = { default = 0.62, min = 0.4, max = 0.8, doc = "Height of the roll hoop's top, metres" },
}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
local function paint_if(m, c, fn)
  local sel = faces_where(m, fn)
  if set_count(sel) == 0 then return m end
  return paint_faces(m, {faces=sel, color=c})
end
local function part(name, pieces)
  local out = {}
  for i, q in ipairs(pieces) do
    local m = q[2] and paint(q[1], q[2]) or q[1]
    out[i] = {mesh=smooth_normals(m, {angle=q[3] or 30}), material=PAINT}
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
local function rb(sx, sy, sz, x, y, z, w)
  local m = box{size=v3(sx, sy, sz)}
  return at(bevel(m, {edges=convex_edges(m), width=w or math.min(sx, sy, sz) * 0.2, segments=1}), x, y, z)
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

local navy    = C(0.035, 0.07, 0.26)
local black   = C(0.02, 0.02, 0.025)
local orange  = C(1.0, 0.22, 0.01)
local grey    = C(0.2, 0.21, 0.23)
local silver  = C(0.72, 0.74, 0.78)
local white   = C(0.9, 0.9, 0.92)
local dark    = C(0.08, 0.08, 0.09)

local pieces = {}
local function add(m, c, a, sig) pieces[#pieces + 1] = {m, c, a, sig} end

local W, ROOF, TIP = p.half_width, p.roof, p.nose_reach

-- The shell: twelve-sided faceted rings lofted along z through key sections { z, half-width, bottom, side top, top },
-- sampled finely so the paint can draw stripes across the facets.
local KEYS = {
  {-1.5, W * 0.66, -0.44, -0.18, ROOF - 0.1},
  {-1.42, W * 0.84, -0.46, -0.16, ROOF - 0.04},
  {-1.25, W * 0.96, -0.48, -0.15, ROOF},
  {-1.0, W, -0.48, -0.15, ROOF + 0.01},
  {-0.6, W, -0.48, -0.16, ROOF},
  {0.55, W, -0.48, -0.19, math.min(ROOF, 0.06)},
  {0.9, W, -0.48, -0.24, -0.06},
  {1.15, W * 0.8, -0.48, -0.3, -0.16},
  {TIP - 0.18, W * 0.5, -0.46, -0.35, -0.27},
  {TIP, W * 0.18, -0.44, -0.365, -0.33},
}
local function key_at(z)
  for i = 1, #KEYS - 1 do
    local a, b = KEYS[i], KEYS[i + 1]
    if z <= b[1] + 1e-9 then
      local t = (z - a[1]) / (b[1] - a[1])
      local r = {z}
      for k = 2, 5 do r[k] = a[k] + (b[k] - a[k]) * t end
      return r
    end
  end
  return KEYS[#KEYS]
end
local shell
do
  local zs = {}
  for _, k in ipairs(KEYS) do zs[#zs + 1] = k[1] end
  -- in-between rings every ~0.2 m along the long middle
  for z = -0.8, 0.5, 0.2 do zs[#zs + 1] = z end
  zs[#zs + 1] = 0.72
  zs[#zs + 1] = 1.03
  table.sort(zs)
  local uniq = {}
  for _, z in ipairs(zs) do
    if #uniq == 0 or z - uniq[#uniq] > 0.01 then uniq[#uniq + 1] = z end
  end
  zs = uniq
  local vs, fs = {}, {}
  local N = 12
  for _, z in ipairs(zs) do
    local s = key_at(z)
    local w, yb, ys, yt = s[2], s[3], s[4], s[5]
    local half = {
      {0.7 * w, yb}, {w, yb + 0.06}, {w, ys}, {0.75 * w, ys + 0.65 * (yt - ys)}, {0.3 * w, yt}, {math.min(0.035, 0.15 * w), yt + 0.004},
    }
    for i = 1, 6 do vs[#vs + 1] = v3(half[i][1], half[i][2], z) end
    for i = 6, 1, -1 do vs[#vs + 1] = v3(-half[i][1], half[i][2], z) end
  end
  local R = #zs
  local function id(i, j) return i * N + (j % N) + 1 end
  for i = 0, R - 2 do
    for j = 0, N - 1 do fs[#fs + 1] = {id(i, j), id(i, j + 1), id(i + 1, j + 1), id(i + 1, j)} end
  end
  local a, b = {}, {}
  for j = 0, N - 1 do a[#a + 1] = id(0, N - 1 - j); b[#b + 1] = id(R - 1, j) end
  fs[#fs + 1] = a
  fs[#fs + 1] = b
  shell = solid(vs, fs)
end

-- The cockpit: a hole down through the shell's top to a floor under the seat, keeping the driver's space clear.
local CW, CL, CZ = 0.58, 0.99, -0.025
do
  local cut = extrude(rounded_rect{w=CW, h=CL, radius=0.2, segments=4}, {distance=1.0})
  shell = subtract(shell, at(cut, 0, -0.3, CZ))
end

-- The left (+x) skirt panel: the shell's outer skin along the straight middle of that side, cut off as its own piece
-- (the signature piece: the fairing that comes away).
-- The panel is cut a millimetre inside the hole it leaves, so the two share no edge (the merged part stays manifold).
local SKIRT = at(box{size=v3(0.12, 1.2, 1.8)}, W + 0.04, -0.2, -0.05)   -- x from W - 0.02, z -0.95..0.85
local skirt = intersect(shell, at(box{size=v3(0.119, 1.2, 1.798)}, W + 0.0405, -0.2, -0.05))
shell = subtract(shell, SKIRT)

-- Its paint: navy, the sides and belly black, an orange swoosh down each upper flank, a white pinstripe down the
-- spine.
local function shell_paint(m)
  m = paint(m, navy)
  m = paint_if(m, black, function(f)
    return f.normal.y < -0.3 or math.abs(f.normal.x) > 0.9 or (f.center.y < -0.12 and f.normal.y < 0.5)
  end)
  m = paint_if(m, orange, function(f)
    local z = f.center.z
    return f.normal.y > 0.25 and math.abs(f.normal.x) > 0.6 and z > -1.15 and z < 1.3
  end)
  return paint_if(m, white, function(f)
    return math.abs(f.center.x) < 0.034 and f.normal.y > 0.8 and f.center.y > -0.25 and f.center.z > -1.45
  end)
end
pieces[#pieces + 1] = {shell_paint(shell), nil, 20}
pieces[#pieces + 1] = {shell_paint(skirt), nil, 20, true}

-- The silver collar round the cockpit hole.
do
  local ring = profile_subtract(rounded_rect{w=CW + 0.07, h=CL + 0.07, radius=0.235, segments=4},
    rounded_rect{w=CW - 0.004, h=CL - 0.004, radius=0.198, segments=4})
  add(at(extrude(ring, {distance=0.14}), 0, ROOF > 0.06 and -0.04 or -0.06, CZ), silver, 35)
end

-- The seat: a black cushion on the cockpit floor under the hips, a black back with a headrest pad.
add(rb(0.5, 0.08, 0.42, 0, -0.26, -0.3, 0.02), black)
do
  local b = rb(0.48, 0.5, 0.07, 0, 0.25, 0, 0.025)
  b = rotate(b, {angle=-10, axis=axis_x(), pivot=origin()})
  add(at(b, 0, -0.27, -0.56), black)
  local h = rb(0.26, 0.16, 0.08, 0, 0, 0, 0.03)
  h = rotate(h, {angle=-10, axis=axis_x(), pivot=origin()})
  add(at(h, 0, 0.33, -0.66), dark)
end

-- The roll hoop behind the cockpit: an orange square tube bent over the driver's shoulders.
do
  local H = p.hoop_top
  local z = -0.68
  local pts = {
    v3(-0.2, ROOF - 0.04, z), v3(-0.2, H - 0.12, z), v3(-0.13, H, z),
    v3(0.13, H, z), v3(0.2, H - 0.12, z), v3(0.2, ROOF - 0.04, z),
  }
  add(sweep(rect{w=0.05, h=0.05}, path{points=pts}, {caps=true}), orange, 20)
  -- its feet on the shell
  for _, sx in ipairs({-1, 1}) do add(rb(0.09, 0.03, 0.09, sx * 0.2, ROOF - 0.005, z, 0.01), silver) end
end

-- The name down each black side: italic orange bars, with a grey panel fore and aft.
for _, sx in ipairs({-1, 1}) do
  local xo = sx * (W + 0.003)
  for i = 0, 8 do
    local z = -0.5 + i * 0.115
    local bar = rb(0.012, 0.15, 0.06 + (i % 3 == 1 and 0.02 or 0), 0, 0, 0, 0.004)
    bar = rotate(bar, {angle=sx * -18, axis=axis_x(), pivot=origin()})
    bar = rotate(bar, {angle=0, axis=axis_y(), pivot=origin()})
    add(at(bar, xo, -0.3, z), orange, nil, sx > 0)
  end
  for _, zc in ipairs({-0.82, 0.7}) do
    local m = extrude(rounded_rect{w=0.34, h=0.15, radius=0.07, segments=3}, {distance=0.012, anchor="center"})
    m = rotate(m, {angle=90, axis=axis_z(), pivot=origin()})
    m = rotate(m, {angle=90, axis=axis_x(), pivot=origin()})
    add(at(m, xo, -0.3, zc), grey, nil, sx > 0)
  end
  -- bolts at the tail's corners
  for _, y in ipairs({-0.42, -0.22}) do add(cyl(0.012, 0.01, sx * 0.24, y, -1.502, "z", 8), silver) end
end

-- The number on the nose: an orange roundel, a white ring round it.
do
  local s = key_at(1.02)
  local y = s[5]
  local m = cylinder{radius=0.085, height=0.012, segments=16}
  local ring = cylinder{radius=0.1, height=0.008, segments=16}
  local slope = deg(math.atan(KEYS[7][5] - KEYS[8][5], KEYS[8][1] - KEYS[7][1]))
  for _, q in ipairs({{ring, white, 0.012}, {m, orange, 0.017}}) do
    local d = rotate(q[1], {angle=slope, axis=axis_x(), pivot=origin()})
    add(at(d, 0, y + q[3], 1.02), q[2])
  end
end

-- The tow eye on the nose's tip.
add(cyl(0.02, 0.06, 0, -0.395, TIP + 0.02, "z", 8), silver)

-- The frame's bones: axle crossbars through the shell, stubs out to the hubs.
for _, z in ipairs({-0.7, 0.7}) do
  add(rod(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.024, 10), grey)
  for _, sx in ipairs({-1, 1}) do
    add(rod(v3(sx * 0.46, -0.42, z), v3(sx * 0.535, -0.42, z), 0.02, 10), silver)
    add(cyl(0.034, 0.03, sx * 0.47, -0.42, z, "x", 8), dark)
  end
end

-- The steering column: from under the wheel forward and down into the shell.
add(rod(v3(0, 0.1, 0.15), v3(0, -0.12, 0.52), 0.022, 10), dark)
add(cyl(0.035, 0.05, 0, 0.08, 0.17, "y", 10), black)

part("streamliner", pieces)
