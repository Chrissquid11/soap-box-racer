-- Pole Dancer: a blue open-wheel formula racer for a kart body, one part "f1". A long wedge nose with a white
-- pinstripe down each top edge, a black front wing with yellow endplates, black sidepods with yellow intakes either
-- side of the cockpit, a black seat, a blue airbox behind the driver and a tall two-slat rear wing with yellow
-- endplates. In the kart's body space: the origin the middle of the (hidden) chassis box's top, +z forward, metres;
-- the wheels (x +-0.5, z +-0.7, y -0.42) and the steering wheel come from other slots.
local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.45, metallic=0}

local p = params{
  nose_reach = { default = 1.42, min = 1.25, max = 1.55, doc = "How far forward the nose tip reaches, metres" },
  wing_height = { default = 0.86, min = 0.6, max = 1.1, doc = "Height of the rear wing's top slat, metres" },
  wing_span = { default = 0.56, min = 0.4, max = 0.75, doc = "Half the rear wing's span, metres" },
  pod_width = { default = 0.47, min = 0.4, max = 0.52, doc = "How far out the sidepods reach either side, metres" },
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
-- A hull lofted through sections along z, each { z, half-width at the bottom, half-width at the top, bottom y, top y,
-- chamfer }: a six-sided ring, its top corners cut off by the chamfer. Capped at both ends.
local function hull(secs)
  local vs, fs = {}, {}
  for _, s in ipairs(secs) do
    local z, wb, wt, yb, yt, c = s[1], s[2], s[3], s[4], s[5], s[6]
    local ring = {
      v3(wb, yb, z), v3(wt, yt - c, z), v3(wt - c, yt, z),
      v3(-(wt - c), yt, z), v3(-wt, yt - c, z), v3(-wb, yb, z),
    }
    for _, v in ipairs(ring) do vs[#vs + 1] = v end
  end
  local N, R = 6, #secs
  local function id(i, j) return i * N + (j % N) + 1 end
  for i = 0, R - 2 do
    for j = 0, N - 1 do fs[#fs + 1] = {id(i, j), id(i, j + 1), id(i + 1, j + 1), id(i + 1, j)} end
  end
  local a, b = {}, {}
  for j = 0, N - 1 do a[#a + 1] = id(0, N - 1 - j); b[#b + 1] = id(R - 1, j) end
  fs[#fs + 1] = a
  fs[#fs + 1] = b
  return solid(vs, fs)
end
-- The chamfer faces (half up, half out) of a hull, painted c: the pinstripe.
local function stripe(m, c)
  return paint_if(m, c, function(f) return math.abs(f.normal.x) > 0.35 and f.normal.y > 0.35 end)
end

local blue    = C(0.03, 0.3, 0.85)
local blue_dk = C(0.02, 0.2, 0.62)
local yellow  = C(0.98, 0.72, 0.02)
local black   = C(0.03, 0.03, 0.035)
local dark    = C(0.1, 0.1, 0.11)
local white   = C(0.95, 0.95, 0.95)
local grey    = C(0.55, 0.57, 0.6)
local silver  = C(0.78, 0.8, 0.84)

local pieces = {}
local function add(m, c, a, sig) pieces[#pieces + 1] = {m, c, a, sig} end

-- The tub's floor, under the seat and the driver's legs.
add(rb(0.7, 0.16, 1.5, 0, -0.42, -0.25, 0.03), blue_dk)

-- The cockpit's sides: a wall either side, up to the shoulders, its top edge striped.
for _, sx in ipairs({-1, 1}) do
  local w = hull({
    {-0.58, 0.05, 0.05, -0.36, 0.1, 0.025},
    {0.5, 0.05, 0.05, -0.36, 0.06, 0.025},
  })
  w = stripe(paint(w, blue), white)
  pieces[#pieces + 1] = {at(w, sx * 0.33, 0, 0), nil, 30}
end

-- The nose: a wedge from the cockpit's front down to its tip, the white pinstripe down each chamfered top edge.
do
  local tip = p.nose_reach
  local n = hull({
    {0.44, 0.38, 0.38, -0.5, 0.1, 0.07},
    {0.75, 0.32, 0.3, -0.5, -0.04, 0.06},
    {1.1, 0.22, 0.19, -0.49, -0.22, 0.045},
    {tip - 0.03, 0.15, 0.13, -0.47, -0.33, 0.03},
    {tip, 0.12, 0.1, -0.46, -0.36, 0.02},
  })
  n = stripe(paint(n, blue), white)
  pieces[#pieces + 1] = {n, nil, 25}
  -- the dark nose intake at its tip
  add(cyl(0.035, 0.02, 0, -0.42, tip + 0.005, "z", 10), black)
end

-- The engine cover behind the seat, and the airbox rising out of it behind the driver's head.
do
  local e = hull({
    {-0.52, 0.38, 0.38, -0.5, 0.1, 0.07},
    {-0.85, 0.36, 0.33, -0.5, 0.06, 0.06},
    {-1.12, 0.3, 0.26, -0.5, 0.0, 0.05},
  })
  pieces[#pieces + 1] = {stripe(paint(e, blue), white), nil, 25}
  local a = hull({
    {-0.62, 0.14, 0.1, 0.0, 0.42, 0.04},
    {-0.8, 0.15, 0.11, 0.0, 0.5, 0.04},
    {-1.08, 0.14, 0.1, -0.05, 0.3, 0.04},
  })
  add(a, blue, 25)
  -- the airbox's dark mouth over the driver's head
  add(rb(0.12, 0.1, 0.03, 0, 0.38, -0.615, 0.01), black)
end

-- The seat: a black cushion under the hips and a black back, leaning, its sides wrapping round.
add(rb(0.5, 0.06, 0.42, 0, -0.25, -0.3, 0.02), black)
do
  local b = rb(0.5, 0.6, 0.07, 0, 0.3, 0, 0.025)
  b = rotate(b, {angle=-10, axis=axis_x(), pivot=origin()})
  add(at(b, 0, -0.25, -0.58), black)
  for _, sx in ipairs({-1, 1}) do
    local s = rb(0.05, 0.5, 0.16, 0, 0.25, 0.08, 0.015)
    s = rotate(s, {angle=-10, axis=axis_x(), pivot=origin()})
    add(at(s, sx * 0.235, -0.25, -0.58), dark)
  end
end

-- The sidepods: black boxes either side between the wheels, a yellow intake framing a dark mouth on each front.
do
  local W = p.pod_width
  for _, sx in ipairs({-1, 1}) do
    local inner = 0.36
    local cx = sx * (inner + W) * 0.5
    local w = W - inner
    add(rb(w, 0.3, 0.5, cx, -0.3, -0.04, 0.02), black)
    add(rb(w + 0.02, 0.26, 0.08, cx, -0.29, 0.24, 0.025), yellow)
    add(rb(w * 0.55, 0.15, 0.03, cx, -0.29, 0.277, 0.008), dark)
  end
end

-- The front wing: a black plane across under the nose, a yellow endplate each end. The signature piece.
do
  local tip = p.nose_reach
  local z0 = tip - 0.1
  add(rb(1.4, 0.035, 0.3, 0, -0.44, z0, 0.01), black, nil, true)
  for _, sx in ipairs({-1, 1}) do
    local vs = {
      v3(-0.015, -0.47, z0 - 0.16), v3(0.015, -0.47, z0 - 0.16),
      v3(-0.015, -0.47, z0 + 0.17), v3(0.015, -0.47, z0 + 0.17),
      v3(-0.015, -0.3, z0 - 0.16), v3(0.015, -0.3, z0 - 0.16),
      v3(-0.015, -0.4, z0 + 0.17), v3(0.015, -0.4, z0 + 0.17),
    }
    local fs = {{1, 2, 4, 3}, {5, 7, 8, 6}, {1, 5, 6, 2}, {3, 4, 8, 7}, {1, 3, 7, 5}, {2, 6, 8, 4}}
    add(at(solid(vs, fs), sx * 0.715, 0, 0), yellow, nil, true)
  end
end

-- The rear wing: two black slats between yellow endplates, on two pylons from the engine cover.
do
  local H, S = p.wing_height, p.wing_span
  local WZ = -1.22
  add(rb(S * 2, 0.04, 0.26, 0, H, WZ, 0.012), black)
  add(rb(S * 2, 0.035, 0.18, 0, H - 0.16, WZ + 0.02, 0.01), black)
  for _, sx in ipairs({-1, 1}) do
    local vs = {
      v3(-0.015, H - 0.32, WZ - 0.18), v3(0.015, H - 0.32, WZ - 0.18),
      v3(-0.015, H - 0.22, WZ + 0.17), v3(0.015, H - 0.22, WZ + 0.17),
      v3(-0.015, H + 0.12, WZ - 0.18), v3(0.015, H + 0.12, WZ - 0.18),
      v3(-0.015, H + 0.08, WZ + 0.17), v3(0.015, H + 0.08, WZ + 0.17),
    }
    local fs = {{1, 2, 4, 3}, {5, 7, 8, 6}, {1, 5, 6, 2}, {3, 4, 8, 7}, {1, 3, 7, 5}, {2, 6, 8, 4}}
    add(at(solid(vs, fs), sx * (S + 0.015), 0, 0), yellow)
    -- the pylons from the cover up under the lower slat
    add(rb(0.04, H - 0.16, 0.1, sx * 0.17, (H - 0.16) * 0.5, WZ + 0.04, 0.01), blue)
  end
end

-- The frame's bones: axle crossbars at the axles, stubs out to the hubs.
for _, z in ipairs({-0.7, 0.7}) do
  add(rod(v3(-0.47, -0.42, z), v3(0.47, -0.42, z), 0.024, 10), grey)
  for _, sx in ipairs({-1, 1}) do
    add(rod(v3(sx * 0.46, -0.42, z), v3(sx * 0.535, -0.42, z), 0.02, 10), silver)
    add(cyl(0.034, 0.03, sx * 0.47, -0.42, z, "x", 8), dark)
  end
end

-- The steering column: from under the wheel forward and down into the nose.
add(rod(v3(0, 0.1, 0.15), v3(0, -0.1, 0.5), 0.022, 10), dark)
add(cyl(0.035, 0.05, 0, 0.08, 0.17, "y", 10), black)

part("f1", pieces)
