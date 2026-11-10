-- Orange Crate Special: a classic wooden soapbox for a kart body, one part "crate". A pine plank chassis running
-- forward under the driver's legs, a slatted wooden crate at the back for a seat box (screw heads on its corner
-- posts), a plank seat and a slanted backboard inside it, a front axle beam pivoting on a big bolt through the plank,
-- and rope reins from the crate's front posts to the axle beam's ends. In the kart's body space: the origin the middle
-- of the (hidden) chassis box's top, +z forward, metres; the (spoked) wheels at x +-0.5, z +-0.7, y -0.42 and the
-- steering wheel come from other slots.
local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.75, metallic=0}

local p = params{
  crate_top   = { default = 0.32, min = 0.1, max = 0.5, doc = "Height of the crate's walls' top, metres" },
  crate_front = { default = -0.12, min = -0.3, max = 0.0, doc = "Where the crate's open front stands along z, metres" },
  slats       = { default = 3, min = 2, max = 4, integer = true, doc = "Slats up each crate wall" },
  plank_width = { default = 0.32, min = 0.22, max = 0.44, doc = "Width of the chassis plank, metres" },
}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
local function part(name, pieces)
  local out = {}
  for i, q in ipairs(pieces) do
    local m = q[2] and paint(q[1], q[2]) or q[1]
    out[i] = {mesh=smooth_normals(m, {angle=q[3] or 30}), material=PAINT}
  end
  local merged = merge({parts=out, mode="compatible"})
  emit(merged[1].mesh, {name=name, material=merged[1].material})
  -- Its wreck: the bare plank (the pieces marked true, 4th, kept) -- the driver left sat on Dad's shelf.
  local kept = {}
  for i, q in ipairs(pieces) do if q[4] then kept[#kept + 1] = out[i] end end
  local w = merge({parts=kept, mode="compatible"})
  emit(w[1].mesh, {name=name .. "_wreck", material=w[1].material})
end
local function C(r, g, b) return v3(r, g, b) end
local function at(m, x, y, z) return translate(m, v3(x, y, z)) end
local function rb(sx, sy, sz, x, y, z, w)
  local m = box{size=v3(sx, sy, sz)}
  return at(bevel(m, {edges=convex_edges(m), width=w or math.min(sx, sy, sz) * 0.15, segments=1}), x, y, z)
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
local function ball(r, x, y, z, seg)
  local s = seg or 8
  return at(sphere{radius=r, segments=s, rings=math.floor(s / 2)}, x, y, z)
end

-- Pine in a few shades, so boards side by side read apart.
local PINE = { C(0.92, 0.66, 0.32), C(0.86, 0.6, 0.28), C(0.95, 0.71, 0.38), C(0.89, 0.63, 0.3) }
local function pine(i) return PINE[(i - 1) % #PINE + 1] end
local pine_dk = C(0.7, 0.45, 0.18)
local rope    = C(0.55, 0.36, 0.13)
local rope_dk = C(0.42, 0.26, 0.08)
local steel   = C(0.62, 0.64, 0.68)
local silver  = C(0.8, 0.82, 0.86)
local dark    = C(0.1, 0.1, 0.11)

local pieces = {}
local function add(m, c, a) pieces[#pieces + 1] = {m, c, a} end

-- The axle beams: a square timber across under each axle. The front one pivots on a bolt through the plank.
local BEAM = 0.09
for i, z in ipairs({-0.7, 0.7}) do
  add(rb(0.94, BEAM, 0.11, 0, -0.42, z, 0.01), pine(i + 1))
  for _, sx in ipairs({-1, 1}) do
    add(rod(v3(sx * 0.46, -0.42, z), v3(sx * 0.535, -0.42, z), 0.02, 10), steel)
    add(cyl(0.035, 0.012, sx * 0.476, -0.42, z, "x", 8), silver)
  end
end

-- The chassis plank, from the crate's back to past the front axle, on top of the beams.
local PY = -0.42 + BEAM * 0.5 + 0.025    -- the plank's middle
local PW = p.plank_width
add(rb(PW, 0.05, 1.98, 0, PY, -0.04, 0.008), pine(1))
-- the front axle's pivot: a big bolt head and washer on the plank, the nut under the beam
add(cyl(0.05, 0.008, 0, PY + 0.029, 0.7, "y", 16), silver)
add(cyl(0.03, 0.022, 0, PY + 0.04, 0.7, "y", 6), steel)
add(cyl(0.03, 0.02, 0, -0.42 - BEAM * 0.5 - 0.009, 0.7, "y", 6), steel)

-- What its wreck keeps: everything so far (the beams, the plank, its pivot).
for i = 1, #pieces do pieces[i][4] = true end

-- The crate: a deck of boards on the plank, corner posts, slatted side and back walls, open at the front.
local CB, CF = -1.02, p.crate_front     -- its back and front along z
local CX = 0.4                          -- its walls' outside, either side
local DY = PY + 0.025                   -- the deck's underside
local TOP = p.crate_top
do
  -- deck boards running across
  local n = 6
  local len = CF - CB
  for i = 0, n - 1 do
    local z = CB + (i + 0.5) * len / n
    add(rb(CX * 2, 0.03, len / n - 0.012, 0, DY + 0.015, z, 0.006), pine(i + 2))
  end
  -- a bearer either side under the deck
  for _, sx in ipairs({-1, 1}) do add(rb(0.06, 0.05, len, sx * (CX - 0.05), DY - 0.025, (CB + CF) * 0.5, 0.008), pine_dk) end

  local y0 = DY + 0.03
  local PS = 0.06
  -- corner posts
  local posts = {}
  for _, sx in ipairs({-1, 1}) do
    for _, z in ipairs({CB + PS * 0.5, CF - PS * 0.5}) do
      posts[#posts + 1] = {sx * (CX - PS * 0.5), z}
      add(rb(PS, TOP - y0 + 0.03, PS, sx * (CX - PS * 0.5), (TOP + y0 + 0.03) * 0.5, z, 0.008), pine(3))
    end
  end
  -- the slats, outside the posts: up each side and across the back
  local S = p.slats
  local gap = 0.045
  local sh = ((TOP - y0) - gap * (S - 1)) / S
  local T = 0.022
  for k = 0, S - 1 do
    local yc = y0 + sh * 0.5 + k * (sh + gap)
    for _, sx in ipairs({-1, 1}) do
      add(rb(T, sh, len, sx * (CX + T * 0.5), yc, (CB + CF) * 0.5, 0.005), pine(k + (sx > 0 and 1 or 3)))
      -- screw heads on each post through the slat
      for _, z in ipairs({CB + PS * 0.5, CF - PS * 0.5}) do
        add(cyl(0.012, 0.006, sx * (CX + T + 0.002), yc, z, "x", 8), silver)
      end
    end
    add(rb(CX * 2 + T * 2 + 0.012, sh - 0.004, T, 0, yc, CB - T * 0.5 + 0.004, 0.005), pine(k + 2))
    for _, sx in ipairs({-1, 1}) do
      add(cyl(0.012, 0.006, sx * (CX - PS * 0.5), yc, CB - T - 0.002, "z", 8), silver)
    end
  end
  -- a low kick board across the crate's open front, under the driver's legs
  add(rb(CX * 2, 0.07, T, 0, y0 + 0.035, CF + T * 0.5, 0.005), pine(4))
end

-- The seat: a plank seat board across the crate (its top at y -0.22) on two blocks, and a slanted backboard behind.
add(rb(0.62, 0.035, 0.4, 0, -0.2375, -0.32, 0.008), pine(2))
for _, sx in ipairs({-1, 1}) do add(rb(0.06, -0.255 - (DY + 0.03), 0.34, sx * 0.25, (-0.255 + DY + 0.03) * 0.5, -0.32, 0.006), pine_dk) end
-- (the seat board and its blocks stay in the wreck: the driver still sits on a plank)
for i = #pieces - 2, #pieces do pieces[i][4] = true end
do
  for k = 0, 2 do
    local b = rb(0.56, 0.13, 0.03, 0, 0.0, 0, 0.006)
    b = rotate(b, {angle=-12, axis=axis_x(), pivot=origin()})
    add(at(b, 0, -0.14 + k * 0.155, -0.585 - k * 0.032), pine(k + 1))
  end
  -- the two battens holding the backboard's boards, against the crate's back
  for _, sx in ipairs({-1, 1}) do
    local a, b = v3(sx * 0.2, -0.22, -0.6), v3(sx * 0.2, 0.22, -0.69)
    add(along(box{size=v3(0.05, length(b - a), 0.03)}, a, b), pine_dk)
    add(rb(0.05, 0.03, 0.36, sx * 0.2, 0.22, -0.86, 0.006), pine_dk)
  end
end

-- The rope reins: from a knot on each front post's top, sagging a touch, to an eye on each end of the front beam.
do
  for _, sx in ipairs({-1, 1}) do
    local a = v3(sx * (CX - 0.03), TOP - 0.02, CF + 0.005)
    local b = v3(sx * 0.4, -0.38, 0.7)
    local pts = {}
    for i = 0, 8 do
      local t = i / 8
      local q = lerp(a, b, t)
      pts[#pts + 1] = q - v3(0, 0.05 * math.sin(math.pi * t), 0)
    end
    add(sweep(circle{radius=0.011, segments=6}, path{points=pts}, {caps=true}), rope, 50)
    add(ball(0.024, a.x, a.y, a.z, 8), rope_dk)
    add(ball(0.022, b.x, b.y + 0.005, b.z, 8), rope_dk)
    add(cyl(0.02, 0.012, b.x, -0.42 + BEAM * 0.5 + 0.005, 0.7, "y", 8), steel)
  end
end

-- The steering column: from under the wheel, down and forward to a block on the plank.
add(rod(v3(0, 0.1, 0.15), v3(0, PY + 0.03, 0.46), 0.02, 10), dark)
add(cyl(0.035, 0.05, 0, 0.08, 0.17, "y", 10), dark)
add(rb(0.12, 0.06, 0.12, 0, PY + 0.055, 0.46, 0.01), pine(3))
for i = #pieces - 2, #pieces do pieces[i][4] = true end

part("crate", pieces)
