-- Every part a homemade kart is built from, each its own named part modelled about its own origin:
-- the game draws each with Render.model "karts/parts#<name>" on an entity placed where it goes.
--
--   chassis_plank, chassis_crate, chassis_tub,   origin at the middle of the chassis' box (its collider);
--   chassis_trolley, chassis_bin, chassis_canoe  the sizes match CHASSIS in src/game/build.ts
--   wheel_pram, wheel_trolley, wheel_bike,       origin at the hub, axle along x; radii match WHEELS
--   wheel_skate, wheel_tractor, wheel_slick,
--   wheel_cart, wheel_mower, wheel_disc
--   deco_*                                       origin at the middle of its base, facing +z
--   spring                                       1 m tall about its middle, along y (the game stretches it)
--   steer_wheel, steer_bars, steer_rope          about the driver's hands, turning about +y
--   bit, plank                                   debris, about their middles
--
-- Every part wears one white material and its colours on its vertices (glTF multiplies the two): each in its own
-- colours, as such a thing would be -- pine with a red backrest, a green bin, a duck-egg bath, a cedar canoe.
-- Only the debris is kept pale, tinted (Render.tint) the colour of what broke. Facing +z.
local P = params{
  slats  = {default=4, min=2, max=7, integer=true, doc="Slats a side on the fruit crate"},
  spokes = {default=24, min=12, max=36, integer=true, doc="Spokes in a bike wheel"},
}

local PAINT = material{name="Paint", base_color=v3(1, 1, 1), roughness=0.7, metallic=0}

local function C(r, g, b) return v3(r, g, b) end
local function shade(c, k) return v3(math.min(1, c.x * k), math.min(1, c.y * k), math.min(1, c.z * k)) end

-- Pale wood, white enamel and chrome wire.
-- (Linear colours: the pine is a warm honey, not near-white -- it read as grey card on the road.)
local pale    = C(0.84, 0.62, 0.36)   -- light pine
local pale2   = C(0.7, 0.49, 0.26)   -- its darker, older boards
-- The debris alone stays pale, as it is tinted the colour of what broke.
local dpale   = C(0.92, 0.86, 0.75)
local dpale2  = C(0.84, 0.75, 0.6)
local fresh   = C(1.0, 0.95, 0.84)    -- freshly split wood
local enamel  = C(0.96, 0.96, 0.95)
local wire    = C(0.86, 0.87, 0.9)
-- The details, and the parts' own colours.
local wood    = C(0.55, 0.36, 0.18)
local walnut  = C(0.32, 0.18, 0.08)
local rubber  = C(0.035, 0.035, 0.04)
local tread   = C(0.075, 0.075, 0.08)
local steel   = C(0.55, 0.56, 0.6)
local chrome  = C(0.88, 0.89, 0.93)
local iron    = C(0.2, 0.2, 0.22)
local rust    = C(0.45, 0.2, 0.08)
local gumwall = C(0.62, 0.38, 0.15)
local cream   = C(0.96, 0.92, 0.8)
local red     = C(0.85, 0.08, 0.05)
local blue    = C(0.08, 0.32, 0.9)
local yellow  = C(0.98, 0.75, 0.06)
local orange  = C(1.0, 0.42, 0.04)
local mint    = C(0.25, 0.88, 0.62)
local black   = C(0.03, 0.03, 0.035)
local white   = C(0.97, 0.97, 0.96)
local glass   = C(0.35, 0.7, 0.95)

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
-- Faces of m for which fn(f) holds, painted c (none such: m as it was).
local function paint_if(m, c, fn)
  local sel = faces_where(m, fn)
  if set_count(sel) == 0 then return m end
  return paint_faces(m, {faces=sel, color=c})
end
-- A part of several pieces: each { mesh, colour }, or { mesh } already painted -- merged into one mesh, its colours
-- on its vertices (merge, not join: join drops vertex colours). Every piece's normals smoothed first (to 40°, so a
-- box stays crisp and a bevel or a tyre goes round), as merge wants them all alike.
local function part(name, pieces, factor)
  local out = {}
  for i, p in ipairs(pieces) do
    local m = p[2] and paint(p[1], p[2]) or p[1]
    out[i] = {mesh=smooth_normals(m, {angle=40}), material=PAINT}
  end
  local merged = merge({parts=out, mode="compatible"})
  local m = merged[1].mesh
  if factor then m = scale(m, {factor=factor, pivot=origin()}) end
  emit(m, {name=name, material=merged[1].material})
end
local function many(list) return #list == 1 and list[1] or join(table.unpack(list)) end

local function at(m, x, y, z) return translate(m, v3(x, y, z)) end
local function bev(m, w, seg) return bevel(m, {edges=convex_edges(m), width=w, segments=seg or 1}) end
local function bx(sx, sy, sz, x, y, z) return at(box{size=v3(sx, sy, sz)}, x, y, z) end
-- A box with its edges bevelled (w, or a fifth of its thinnest side).
local function rb(sx, sy, sz, x, y, z, w, seg)
  return at(bev(box{size=v3(sx, sy, sz)}, w or math.min(sx, sy, sz) * 0.2, seg), x, y, z)
end
local function cyl(r, h, x, y, z, axis, seg) return at(cylinder{radius=r, height=h, segments=seg or 12, axis=axis or "y"}, x, y, z) end
local function ball(r, x, y, z, seg) local s = seg or 12; return at(sphere{radius=r, segments=s, rings=math.floor(s / 2)}, x, y, z) end
local function ell(rx, ry, rz, x, y, z, seg)
  local s = seg or 14
  return at(scale(sphere{radius=1, segments=s, rings=math.floor(s / 2)}, {factor=v3(rx, ry, rz), pivot=origin()}), x, y, z)
end
-- A mesh turned about an axis through the origin, then moved.
local function turn(m, angle, axis, x, y, z) return at(rotate(m, {angle=angle, axis=axis, pivot=origin()}), x or 0, y or 0, z or 0) end
-- A round rod from a to b, a hair short of each (two rods meeting end to end must not share a vertex).
local function rod(a0, b0, r, seg)
  local a = lerp(a0, b0, 0.004)
  local b = lerp(a0, b0, 0.996)
  local d = b - a
  local up = v3(0, 1, 0)
  local m = cylinder{radius=r, height=length(d), segments=seg or 8}
  local dir = normalize(d)
  local c = dot(up, dir)
  if c < -0.9999 then
    m = rotate(m, {angle=180, axis=axis_x(), pivot=origin()})
  elseif c < 0.9999 then
    m = rotate(m, {angle=deg(math.acos(c)), axis=normalize(cross(up, dir)), pivot=origin()})
  end
  return translate(m, (a + b) * 0.5)
end
-- A tube along points (a path), round, its ends capped.
local function tube(pts, r, seg, closed)
  return sweep(circle{radius=r, segments=seg or 8}, path{points=pts, closed=closed or false}, {caps=not closed})
end

local function sgnpow(v, p) local a = math.abs(v) ^ p; return v < 0 and -a or a end
-- A solid of revolution about the x axis (an axle's): `pts` are { radius, along } pairs, counter-clockwise.
local function lathe(pts, seg)
  local ps = {}
  for i, p in ipairs(pts) do ps[i] = v2(p[1], p[2]) end
  return rotate(revolve(poly{points=ps}, {segments=seg}), {angle=90, axis=axis_z(), pivot=origin()})
end
-- The same about the y axis.
local function lathe_y(pts, seg)
  local ps = {}
  for i, p in ipairs(pts) do ps[i] = v2(p[1], p[2]) end
  return revolve(poly{points=ps}, {segments=seg})
end
-- A ring about the x axis -- a tyre, a rim: radii r0 to r1, w wide, its section a rounded square (`sq` 1 an oval,
-- smaller boxier), n points round the section.
local function hoop(r0, r1, w, seg, sq, n)
  local cx, a, b = (r0 + r1) / 2, (r1 - r0) / 2, w / 2
  local pts = {}
  n = n or 12
  for i = 0, n - 1 do
    local t = 2 * math.pi * (i + 0.5) / n
    pts[#pts + 1] = { cx + a * sgnpow(math.cos(t), sq), b * sgnpow(math.sin(t), sq) }
  end
  return lathe(pts, seg)
end
-- How far a face's centre is from the x axis.
local function radial(f) return math.sqrt(f.center.y * f.center.y + f.center.z * f.center.z) end

-- A board sx × sy × sz about (x, y, z), its edges bevelled, its grain in stripes along its longest side: `c` and
-- a shade darker, the stripes uneven (`seed` moves them, and shades the board a little), so no two are alike.
local function board(sx, sy, sz, x, y, z, c, seed, w)
  seed = seed or 0
  local m = bev(box{size=v3(sx, sy, sz)}, w or math.min(sx, sy, sz) * 0.2)
  local alongz = sz >= sx
  local across = alongz and sx or sz
  local n = math.max(2, math.floor(across / 0.022 + 0.5))
  local cuts = {}
  for i = 1, n - 1 do
    local u = -across / 2 + across * (i + 0.3 * noise3(i * 1.7, seed * 0.37, 0.5)) / n
    cuts[#cuts + 1] = u
    m = knife(m, {normal=alongz and axis_x() or axis_z(), point=alongz and v3(u, 0, 0) or v3(0, 0, u)})
  end
  m = at(m, x, y, z)
  local base = shade(c, 1 + 0.05 * noise3(seed * 0.61, 1.3, 2.2))
  m = paint(m, base)
  return paint_if(m, shade(base, 0.86), function(f)
    local u = alongz and (f.center.x - x) or (f.center.z - z)
    local k = 0
    for _, cu in ipairs(cuts) do if u > cu then k = k + 1 end end
    return k % 2 == 1
  end)
end
-- A nail's head, round, facing along `axis` ("x", "y" or "z"), sunk a little into what it is driven into.
local function nail(x, y, z, axis) return cyl(0.008, 0.006, x, y, z, axis or "y", 6) end
-- A hex bolt's head, facing along `axis`.
local function bolt(x, y, z, axis, r) return cyl(r or 0.012, 0.012, x, y, z, axis or "y", 6) end

-- Bodges: what holds a homemade kart together. Duct tape (a strip, tilted as it was slapped on), string lashings,
-- a nail bent over where it missed, a patch of whatever was to hand.
local TAPE, TAPE2 = C(0.6, 0.61, 0.64), C(0.48, 0.49, 0.52)
local TWINE = C(0.82, 0.68, 0.42)
local CARD = C(0.66, 0.5, 0.3)
local function tape(sx, sy, sz, x, y, z, ang, axis)
  return turn(rb(sx, sy, sz, 0, 0, 0, math.min(sx, sy, sz) * 0.3), ang or 0, axis or axis_y(), x, y, z)
end
-- A loop of string round the x axis at (x, y, z), radius r.
local function lash_x(x, y, z, r)
  local pts = {}
  for i = 0, 7 do local a = 2 * math.pi * i / 8; pts[#pts + 1] = v3(x, y + math.cos(a) * r, z + math.sin(a) * r) end
  return tube(pts, 0.005, 5, true)
end
local function bent_nail(x, y, z, dx, dz)
  return many({rod(v3(x, y, z), v3(x, y + 0.025, z), 0.004, 5), rod(v3(x, y + 0.025, z), v3(x + dx, y + 0.03, z + dz), 0.004, 5)})
end

-- Chassis ------------------------------------------------------------------------------------------

-- The plank: three boards side by side on two cross bars, rails either side and a backrest, 0.6 x 0.12 x 1.7.
do
  local p = {}
  for i = -1, 1 do p[#p + 1] = {board(0.16, 0.036, 1.7, i * 0.17, -0.024, 0, (i == 0) and pale2 or pale, 10 + i, 0.008)} end
  for _, z in ipairs({0.6, -0.6}) do
    p[#p + 1] = {board(0.6, 0.034, 0.08, 0, -0.043, z, pale2, 20 + z * 10, 0.008)}
    for i = -1, 1 do
      p[#p + 1] = {nail(i * 0.17 - 0.04, -0.0055, z), iron}
      p[#p + 1] = {nail(i * 0.17 + 0.04, -0.0055, z), iron}
    end
  end
  for _, x in ipairs({-0.27, 0.27}) do
    p[#p + 1] = {board(0.05, 0.07, 1.5, x, 0.025, 0, pale2, 30 + x * 10, 0.012)}
    for _, z in ipairs({-0.55, 0, 0.55}) do p[#p + 1] = {bolt(x, 0.061, z, "y", 0.01), iron} end
  end
  -- The backrest: a board on two braces, a racing roundel on its back.
  p[#p + 1] = {board(0.42, 0.3, 0.04, 0, 0.17, -0.62, red, 40, 0.012)}
  p[#p + 1] = {rod(v3(-0.15, -0.004, -0.83), v3(-0.15, 0.25, -0.646), 0.014, 6), wood}
  p[#p + 1] = {rod(v3(0.15, -0.004, -0.83), v3(0.15, 0.25, -0.646), 0.014, 6), wood}
  p[#p + 1] = {cyl(0.1, 0.006, 0, 0.17, -0.642, "z", 20), white}
  p[#p + 1] = {cyl(0.075, 0.006, 0, 0.17, -0.6455, "z", 20), black}
  p[#p + 1] = {cyl(0.06, 0.006, 0, 0.17, -0.649, "z", 20), white}
  -- A rubber bumper across the nose.
  p[#p + 1] = {at(capsule{radius=0.025, height=0.44, segments=10, axis="x"}, 0, -0.03, 0.82), rubber}
  -- Bodged: tape round both rails, a scrap of old blue-painted board screwed over a split, an X of tape holding the
  -- backrest together, string round the bumper and a nail that missed.
  p[#p + 1] = {tape(0.06, 0.08, 0.08, -0.27, 0.025, 0.3, 8, axis_x()), TAPE}
  p[#p + 1] = {tape(0.06, 0.08, 0.06, 0.27, 0.025, -0.25, -7, axis_x()), TAPE2}
  p[#p + 1] = {turn(board(0.18, 0.012, 0.32, 0, 0, 0, C(0.45, 0.62, 0.8), 77, 0.004), 5, axis_y(), 0.165, 0.0, 0.25)}
  for _, q in ipairs({{0.11, 0.13}, {0.22, 0.37}, {0.12, 0.38}}) do p[#p + 1] = {bolt(q[1], 0.007, q[2], "y", 0.009), (q[1] > 0.2) and chrome or iron} end
  p[#p + 1] = {tape(0.34, 0.04, 0.005, 0, 0.17, -0.597, 30, axis_z()), TAPE}
  p[#p + 1] = {tape(0.34, 0.04, 0.005, 0, 0.17, -0.5965, -30, axis_z()), TAPE2}
  for _, x in ipairs({-0.14, 0.14}) do p[#p + 1] = {lash_x(x, -0.03, 0.82, 0.03), TWINE} end
  p[#p + 1] = {bent_nail(-0.2, -0.006, 0.6, 0.03, 0.01), iron}
  part("chassis_plank", p)
end

-- The fruit crate: a floor and slatted walls, 0.85 x 0.35 x 1.8, corner posts, a label either side.
do
  local w, h, l = 0.85, 0.35, 1.8
  local p = {}
  local n = P.slats
  local gap = h / n
  for i = 0, n - 1 do
    local y = -h / 2 + gap * (i + 0.5)
    local c = (i % 2 == 0) and pale or pale2
    p[#p + 1] = {board(0.03, gap * 0.72, l, -w / 2 + 0.015, y, 0, c, 100 + i, 0.006)}
    p[#p + 1] = {board(0.03, gap * 0.72, l, w / 2 - 0.015, y, 0, c, 110 + i, 0.006)}
    p[#p + 1] = {board(w - 0.08, gap * 0.72, 0.03, 0, y, l / 2 - 0.015, c, 120 + i, 0.006)}
    p[#p + 1] = {board(w - 0.08, gap * 0.72, 0.03, 0, y, -l / 2 + 0.015, c, 130 + i, 0.006)}
    -- Two nails a slat end, into the posts.
    for _, sx in ipairs({-1, 1}) do
      for _, sz in ipairs({-1, 1}) do
        p[#p + 1] = {nail(sx * (w / 2 + 0.001), y, sz * (l / 2 - 0.03), "x"), iron}
        p[#p + 1] = {nail(sx * (w / 2 - 0.03), y, sz * (l / 2 + 0.001), "z"), iron}
      end
    end
  end
  p[#p + 1] = {board(w - 0.08, 0.03, l - 0.08, 0, -h / 2 + 0.015, 0, pale2, 140, 0.006)}
  for _, x in ipairs({-w / 2 + 0.03, w / 2 - 0.03}) do
    for _, z in ipairs({-l / 2 + 0.03, l / 2 - 0.03}) do
      p[#p + 1] = {rb(0.06, h, 0.06, x, 0, z, 0.008), wood}
      -- A tin corner cap, rusting.
      p[#p + 1] = {rb(0.068, 0.04, 0.068, x, h / 2 - 0.02, z, 0.006), rust}
    end
  end
  -- The grower's label either side: cream paper, a red apple with its leaf.
  for _, s in ipairs({-1, 1}) do
    local x = s * (w / 2 + 0.004)
    p[#p + 1] = {bx(0.006, 0.16, 0.42, x, 0.0, 0.1), cream}
    p[#p + 1] = {ell(0.012, 0.05, 0.05, x + s * 0.004, 0.0, 0.22, 12), red}
    p[#p + 1] = {ell(0.008, 0.012, 0.025, x + s * 0.006, 0.055, 0.235, 8), C(0.2, 0.6, 0.15)}
    p[#p + 1] = {bx(0.008, 0.025, 0.2, x + s * 0.002, 0.03, 0.02), C(0.15, 0.3, 0.6)}
    p[#p + 1] = {bx(0.008, 0.015, 0.16, x + s * 0.002, -0.03, 0.0), C(0.15, 0.3, 0.6)}
  end
  -- Bodged: a slat split and taped, cardboard where one fell out, string round it all, a nail bent over.
  p[#p + 1] = {tape(0.007, 0.12, 0.07, -w / 2 - 0.004, 0.03, 0.45, 18, axis_x()), TAPE}
  p[#p + 1] = {tape(0.007, 0.1, 0.06, w / 2 + 0.004, -0.07, -0.55, -14, axis_x()), TAPE2}
  p[#p + 1] = {bx(0.006, 0.13, 0.28, w / 2 + 0.008, -0.08, 0.5), CARD}
  for _, z in ipairs({0.37, 0.63}) do p[#p + 1] = {tape(0.007, 0.16, 0.045, w / 2 + 0.012, -0.08, z, 6, axis_x()), TAPE} end
  local rope = {}
  for _, c in ipairs({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do rope[#rope + 1] = v3(c[1] * (w / 2 + 0.01), c[2] * (h / 2 + 0.008), -0.28) end
  p[#p + 1] = {tube(rope, 0.007, 6, true), TWINE}
  p[#p + 1] = {bent_nail(-w / 2 + 0.03, h / 2, l / 2 - 0.03, 0.02, -0.02), iron}
  part("chassis_crate", p)
end

-- The bathtub: a cast-iron roll-top tub, 1.0 x 0.5 x 1.9 -- its sides flaring out to a thick rolled rim, its ends
-- sloping back to lie against, a white enamelled bowl inside, four chrome ball-and-claw feet, and the old mixer
-- taps with a shower handset in its cradle at the back end. The shell is one closed surface: rings of a rounded
-- oval (a superellipse) from the middle of its underside, up the outside, over the roll and down into the bowl.
do
  local A, B, N, SQ = 0.47, 0.92, 48, 2.6   -- the rim's half width and half length, points a ring, squareness
  local FLARE = 1.6                         -- the ends slope more than the sides
  local function ring(d, y)
    local ax, az = A + d, B + d * FLARE
    local pts = {}
    for i = 0, N - 1 do
      local t = 2 * math.pi * i / N
      local c, s = math.cos(t), math.sin(t)
      pts[#pts + 1] = v3(ax * sgnpow(c, 2 / SQ), y, az * sgnpow(s, 2 / SQ))
    end
    return pts
  end
  -- (inset from the rim, height): up the outside, over the roll, down the inside.
  local shape = {
    {-0.18, -0.2}, {-0.15, -0.195}, {-0.12, -0.18}, {-0.1, -0.15}, {-0.075, -0.06}, {-0.045, 0.05}, {-0.02, 0.14}, {0, 0.195},
    {0.022, 0.212}, {0.035, 0.232}, {0.03, 0.252}, {0.012, 0.263}, {-0.012, 0.26}, {-0.03, 0.245}, {-0.04, 0.225},
    {-0.055, 0.18}, {-0.08, 0.07}, {-0.11, -0.04}, {-0.14, -0.11}, {-0.17, -0.14}, {-0.2, -0.15},
  }
  local verts, faces = {}, {}
  for _, s in ipairs(shape) do for _, q in ipairs(ring(s[1], s[2])) do verts[#verts + 1] = q end end
  local R = #shape
  local function vi(r, i) return r * N + (i % N) + 1 end
  for r = 0, R - 2 do
    for i = 0, N - 1 do faces[#faces + 1] = {vi(r, i), vi(r + 1, i), vi(r + 1, i + 1), vi(r, i + 1)} end
  end
  verts[#verts + 1] = v3(0, -0.2, 0)
  local under = #verts
  verts[#verts + 1] = v3(0, -0.15, 0)
  local floor = #verts
  for i = 0, N - 1 do
    faces[#faces + 1] = {under, vi(0, i), vi(0, i + 1)}
    faces[#faces + 1] = {floor, vi(R - 1, i + 1), vi(R - 1, i)}
  end
  local tub = polyhedron{vertices=verts, faces=faces}
  -- Painted duck-egg blue outside, white enamel in the bowl.
  tub = paint(tub, C(0.45, 0.74, 0.86))
  -- The bowl inside, white enamel.
  tub = paint_if(tub, C(0.86, 0.9, 0.95), function(f)
    local c = f.center
    if c.y < -0.17 or c.y > 0.235 then return false end
    local d = math.min(-0.025, -0.03 - (0.18 - c.y) * 0.293)
    local ax, az = A + d, B + d * FLARE
    return (math.abs(c.x) / ax) ^ SQ + (math.abs(c.z) / az) ^ SQ < 1
  end)
  local p = {{tub}}

  -- Ball-and-claw feet: a leaf-cast shoulder against the tub, a turned ankle, the ball and its gripping toes.
  for _, sx in ipairs({-1, 1}) do
    for _, sz in ipairs({-1, 1}) do
      local x, z = sx * 0.25, sz * 0.52
      p[#p + 1] = {ell(0.08, 0.05, 0.09, x, -0.165, z, 14), chrome}
      p[#p + 1] = {ell(0.032, 0.06, 0.032, x + sx * 0.02, -0.2, z, 12), chrome}
      p[#p + 1] = {ball(0.04, x + sx * 0.024, -0.215, z, 14), chrome}
      for k = -1, 1 do
        local a = math.rad(k * 55)
        local ox, oz = sx * math.cos(a), math.sin(a)
        p[#p + 1] = {ell(0.016, 0.014, 0.03, x + sx * 0.024 + ox * 0.036, -0.238, z + oz * 0.036, 8), chrome}
      end
    end
  end

  -- The taps at the back end: a chrome mixer on two risers, a swan-neck spout over the bowl, white china handles,
  -- and a shower handset on its hose, laid in a cradle above.
  local tz, ty = -B + 0.06, 0.262
  for _, s in ipairs({-1, 1}) do
    p[#p + 1] = {cyl(0.012, 0.06, s * 0.07, ty + 0.03, tz, "y", 10), chrome}
    p[#p + 1] = {cyl(0.018, 0.012, s * 0.07, ty + 0.006, tz, "y", 12), chrome}
    p[#p + 1] = {cyl(0.016, 0.05, s * 0.1, ty + 0.085, tz, "y", 10), chrome}
    for k = 0, 3 do p[#p + 1] = {turn(rb(0.045, 0.012, 0.012, 0.02, 0, 0, 0.004), 90 * k + 45, axis_y(), s * 0.1, ty + 0.115, tz), chrome} end
    p[#p + 1] = {ell(0.012, 0.016, 0.012, s * 0.1, ty + 0.13, tz, 10), white}
  end
  p[#p + 1] = {cyl(0.014, 0.16, 0, ty + 0.07, tz, "x", 12), chrome}
  p[#p + 1] = {tube({v3(0, ty + 0.07, tz), v3(0, ty + 0.14, tz + 0.01), v3(0, ty + 0.17, tz + 0.06), v3(0, ty + 0.15, tz + 0.12), v3(0, ty + 0.11, tz + 0.14)}, 0.013, 10), chrome}
  -- The cradle, the handset in it, its hose looping down behind.
  p[#p + 1] = {cyl(0.008, 0.12, 0, ty + 0.13, tz - 0.01, "y", 8), chrome}
  p[#p + 1] = {rb(0.14, 0.012, 0.03, 0, ty + 0.19, tz - 0.01, 0.004), chrome}
  p[#p + 1] = {cyl(0.014, 0.12, 0, ty + 0.21, tz - 0.01, "x", 10), chrome}
  p[#p + 1] = {ell(0.012, 0.03, 0.03, 0.07, ty + 0.21, tz - 0.01, 12), chrome}
  p[#p + 1] = {tube({v3(-0.06, ty + 0.21, tz - 0.01), v3(-0.1, ty + 0.17, tz - 0.03), v3(-0.11, ty + 0.1, tz - 0.04), v3(-0.07, ty + 0.07, tz - 0.01)}, 0.007, 8), steel}
  -- The shower: a chrome riser pipe clamped to the back end, up to a gooseneck over the bowl, a big round rose on it.
  do
    local sx, sz = 0.2, -B - 0.035
    local top = ty + 0.95
    p[#p + 1] = {cyl(0.016, top - (ty - 0.06), sx, (top + ty - 0.06) / 2, sz, "y", 12), chrome}
    for _, y in ipairs({ty - 0.03, ty + 0.25}) do
      p[#p + 1] = {rb(0.05, 0.03, 0.06, sx, y, sz + 0.02, 0.006), chrome}
      p[#p + 1] = {bolt(sx, y, sz + 0.05, "z", 0.008), steel}
    end
    p[#p + 1] = {tube({v3(sx, top - 0.02, sz), v3(sx, top + 0.06, sz + 0.02), v3(sx * 0.6, top + 0.1, sz + 0.12),
      v3(sx * 0.25, top + 0.08, sz + 0.24), v3(sx * 0.15, top + 0.03, sz + 0.3)}, 0.016, 12), chrome}
    -- The rose: a wide dish facing down, its pierced face a darker disc of holes.
    local rx, ry, rz = sx * 0.15, top - 0.005, sz + 0.31
    p[#p + 1] = {at(lathe_y({{0.006, 0.035}, {0.025, 0.03}, {0.07, 0.0}, {0.075, -0.015}, {0.006, -0.015}}, 24), rx, ry, rz), chrome}
    p[#p + 1] = {at(cylinder{radius=0.064, height=0.004, segments=24}, rx, ry - 0.017, rz), shade(steel, 0.6)}
    -- and a hose from the mixer up the riser, taped to it
    p[#p + 1] = {tube({v3(0.08, ty + 0.07, tz), v3(0.15, ty + 0.05, tz - 0.05), v3(sx - 0.03, ty + 0.1, sz - 0.01), v3(sx - 0.03, ty + 0.4, sz - 0.01)}, 0.007, 8), steel}
    p[#p + 1] = {cyl(0.026, 0.04, sx - 0.01, ty + 0.33, sz, "y", 10), TAPE}
  end
  -- Bodged on for the wheels: a steel beam across under each end, where the axles are (the box's wheelbase, 1.5),
  -- strapped up into the tub's tapering ends -- what the springs hang from (`wheelLook`: their tops at the box's
  -- side, 0.1 under its middle).
  for _, sz in ipairs({-1, 1}) do
    local z = sz * 0.75
    p[#p + 1] = {rb(1.04, 0.05, 0.07, 0, -0.1, z, 0.01), steel}
    for _, sx in ipairs({-1, 1}) do
      p[#p + 1] = {rb(0.045, 0.2, 0.05, sx * 0.14, 0.0, z, 0.008), steel}
      p[#p + 1] = {bolt(sx * 0.14, -0.072, z, "y", 0.014), steel}
      -- Its ends, where the springs bolt on.
      p[#p + 1] = {rb(0.07, 0.08, 0.09, sx * 0.47, -0.1, z, 0.012), steel}
    end
  end

  -- The plug and its chain.
  p[#p + 1] = {cyl(0.028, 0.008, 0, -0.147, -0.45, "y", 14), black}
  for k = 0, 7 do
    local q = lerp(v3(0, -0.14, -0.45), v3(0.03, 0.2, -B + 0.08), k / 7)
    p[#p + 1] = {ball(0.008, q.x, q.y, q.z, 6), chrome}
  end
  -- Bodged: a crack in the enamel taped over, and a rusty patch.
  p[#p + 1] = {tape(0.008, 0.1, 0.24, 0.424, 0.05, 0.2, 12, axis_x()), TAPE}
  p[#p + 1] = {tape(0.008, 0.08, 0.2, 0.424, 0.05, 0.2, -20, axis_x()), TAPE2}
  p[#p + 1] = {ell(0.006, 0.05, 0.09, -0.421, -0.02, -0.3, 10), rust}
  part("chassis_tub", p)
end

-- The shopping trolley: a basket of round wire on a frame, 0.6 x 0.6 x 0.95; the handle at the back.
do
  local w, h, l = 0.6, 0.6, 0.95
  local r = 0.006
  local p = {}
  local wires = {}
  local x0, x1, y0, y1, z0, z1 = -w / 2 + 0.012, w / 2 - 0.012, -h / 2 + 0.03, h / 2 - 0.02, -l / 2 + 0.012, l / 2 - 0.012
  -- Uprights up the sides and ends.
  local nz, nx = 14, 9
  for i = 0, nz do
    local z = z0 + (z1 - z0) * i / nz
    wires[#wires + 1] = rod(v3(x0, y0, z), v3(x0, y1, z), r, 6)
    wires[#wires + 1] = rod(v3(x1, y0, z), v3(x1, y1, z), r, 6)
  end
  for i = 1, nx - 1 do
    local x = x0 + (x1 - x0) * i / nx
    wires[#wires + 1] = rod(v3(x, y0, z0), v3(x, y1, z0), r, 6)
    wires[#wires + 1] = rod(v3(x, y0, z1), v3(x, y1, z1), r, 6)
  end
  -- Rings round it, a hair outside the uprights; the floor's grid.
  for i = 0, 2 do
    local y = y0 + 0.08 + i * (y1 - y0 - 0.12) / 2
    local o = r * 1.6
    wires[#wires + 1] = rod(v3(x0 - o, y, z0 - 0.01), v3(x0 - o, y, z1 + 0.01), r, 6)
    wires[#wires + 1] = rod(v3(x1 + o, y, z0 - 0.01), v3(x1 + o, y, z1 + 0.01), r, 6)
    wires[#wires + 1] = rod(v3(x0 - 0.01, y, z0 - o), v3(x1 + 0.01, y, z0 - o), r, 6)
    wires[#wires + 1] = rod(v3(x0 - 0.01, y, z1 + o), v3(x1 + 0.01, y, z1 + o), r, 6)
  end
  for i = 0, 6 do
    local x = x0 + (x1 - x0) * i / 6
    wires[#wires + 1] = rod(v3(x, y0 + 0.012, z0), v3(x, y0 + 0.012, z1), r, 6)
  end
  p[#p + 1] = {many(wires), wire}
  -- The top rim, a thick rolled tube; the frame under it.
  local rim = {v3(x0, y1, z0), v3(x1, y1, z0), v3(x1, y1, z1), v3(x0, y1, z1)}
  p[#p + 1] = {tube(rim, 0.014, 8, true), wire}
  p[#p + 1] = {tube({v3(x0, y0, z0), v3(x1, y0, z0), v3(x1, y0, z1), v3(x0, y0, z1)}, 0.012, 8, true), steel}
  p[#p + 1] = {rb(w - 0.04, 0.012, l - 0.04, 0, -h / 2 + 0.007, 0, 0.004), shade(wire, 0.8)}
  -- The handle: red plastic on two posts, the coin lock on it.
  p[#p + 1] = {at(capsule{radius=0.024, height=w - 0.02, segments=12, axis="x"}, 0, h / 2 + 0.1, -l / 2 - 0.06), red}
  for _, s in ipairs({-1, 1}) do
    p[#p + 1] = {rod(v3(s * (w / 2 - 0.02), h / 2 - 0.03, -l / 2 + 0.01), v3(s * (w / 2 - 0.02), h / 2 + 0.1, -l / 2 - 0.06), 0.012, 8), wire}
    p[#p + 1] = {cyl(0.03, 0.05, s * (w / 2 - 0.02), h / 2 + 0.1, -l / 2 - 0.06, "x", 12), red}
  end
  p[#p + 1] = {rb(0.1, 0.06, 0.06, 0.16, h / 2 + 0.1, -l / 2 - 0.03, 0.01), yellow}
  p[#p + 1] = {bx(0.04, 0.012, 0.03, 0.16, h / 2 + 0.135, -l / 2 - 0.03), black}
  -- Red plastic caps on the rim's corners.
  for _, x in ipairs({x0, x1}) do
    for _, z in ipairs({z0, z1}) do p[#p + 1] = {ball(0.022, x, y1, z, 10), red} end
  end
  -- Bodged: tape round the handle, a cardboard sheet tied to its side with string, string round a loose wire.
  for _, x in ipairs({-0.12, 0.02}) do p[#p + 1] = {cyl(0.029, 0.07, x, h / 2 + 0.1, -l / 2 - 0.06, "x", 12), (x < 0) and TAPE or TAPE2} end
  p[#p + 1] = {bx(0.006, 0.26, 0.32, x1 + 0.012, -0.02, 0.12), CARD}
  for _, q in ipairs({{0.1, 0.0}, {0.1, 0.24}, {-0.13, 0.0}, {-0.13, 0.24}}) do p[#p + 1] = {lash_x(x1 + 0.006, q[1], q[2], 0.014), TWINE} end
  p[#p + 1] = {lash_x(x0, y1 - 0.01, -0.1, 0.02), TWINE}
  part("chassis_trolley", p)
end

-- The wheelie bin: a tapering, hollow bin with ribbed sides, its lid flopped all the way open down its back, 0.6 x 0.75
-- x 0.72. The lid is its own part, "bin_lid", its origin on the hinge line (the bin's (0, 0.365, -0.36)), so the game
-- can swing it as the bin bounces down the hill.
do
  -- Council green plastic.
  local BIN = C(0.2, 0.5, 0.25)
  local h = 0.75
  local outer = at(extrude(rounded_rect{w=0.52, h=0.62, radius=0.06, segments=4}, {distance=h, segments=2, scale_end=v2(0.6 / 0.52, 0.72 / 0.62)}), 0, -h / 2, 0)
  local inner = at(extrude(rounded_rect{w=0.46, h=0.56, radius=0.04, segments=4}, {distance=h, segments=2, scale_end=v2(0.6 / 0.52, 0.72 / 0.62)}), 0, -h / 2 + 0.05, 0)
  -- Arm holes cut through either side near the top, toward the front: the driver sat inside reaches out through them.
  local holes = {}
  for _, s in ipairs({-1, 1}) do
    holes[#holes + 1] = at(scale(cylinder{radius=1, height=1, segments=20, axis="x"}, {factor=v3(0.2, 0.085, 0.12), pivot=origin()}), s * 0.28, 0.2, 0.13)
  end
  local body = paint(subtract(subtract(outer, inner), many(holes)), BIN)
  -- Darker inside.
  body = paint_if(body, shade(BIN, 0.7), function(f)
    return f.center.y > -h / 2 + 0.03 and math.abs(f.center.x) < 0.25 and math.abs(f.center.z) < 0.31 and f.center.y < h / 2 - 0.005
  end)
  local p = {{body}}
  -- The thick top lip; ribs down the front and sides.
  -- (a ring round the open top: the driver sits down inside it)
  local lip = at(extrude(rounded_rect{w=0.63, h=0.75, radius=0.07, segments=4}, {distance=0.05}), 0, h / 2 - 0.06, 0)
  lip = subtract(lip, at(extrude(rounded_rect{w=0.53, h=0.65, radius=0.05, segments=4}, {distance=0.09}), 0, h / 2 - 0.08, 0))
  p[#p + 1] = {lip, shade(BIN, 0.92)}
  for _, x in ipairs({-0.15, 0.15}) do
    p[#p + 1] = {rotate(rb(0.04, 0.55, 0.03, x, -0.03, 0.345, 0.008), {angle=-3, axis=axis_x(), pivot=v3(x, -0.03, 0.33)}), shade(BIN, 0.92)}
    p[#p + 1] = {rotate(rb(0.04, 0.55, 0.03, x, -0.03, -0.345, 0.008), {angle=3, axis=axis_x(), pivot=v3(x, -0.03, -0.33)}), shade(BIN, 0.92)}
  end
  for _, s in ipairs({-1, 1}) do
    for _, z in ipairs({-0.15}) do
      p[#p + 1] = {rotate(rb(0.03, 0.55, 0.04, s * 0.285, -0.03, z, 0.008), {angle=s * 3, axis=axis_z(), pivot=v3(s * 0.28, -0.03, z)}), shade(BIN, 0.92)}
    end
  end
  -- A sticker on the front: the house number.
  p[#p + 1] = {rotate(bx(0.2, 0.2, 0.006, 0, 0.12, 0.35), {angle=-3, axis=axis_x(), pivot=v3(0, 0.12, 0.34)}), white}
  p[#p + 1] = {rotate(bx(0.1, 0.022, 0.008, 0, 0.18, 0.354), {angle=-3, axis=axis_x(), pivot=v3(0, 0.12, 0.34)}), black}
  p[#p + 1] = {rotate(turn(bx(0.022, 0.15, 0.008, 0, 0, 0), -20, axis_z(), 0.015, 0.1, 0.354), {angle=-3, axis=axis_x(), pivot=v3(0, 0.12, 0.34)}), black}
  -- Its two wheels and their axle at the back, the handle at the back of the top, and the lid's hinge pins.
  for _, s in ipairs({-1, 1}) do
    p[#p + 1] = {at(hoop(0.03, 0.07, 0.05, 18, 0.6, 8), s * 0.24, -h / 2 + 0.07, -0.29), rubber}
    p[#p + 1] = {cyl(0.032, 0.054, s * 0.24, -h / 2 + 0.07, -0.29, "x", 10), iron}
  end
  p[#p + 1] = {cyl(0.012, 0.5, 0, -h / 2 + 0.07, -0.29, "x", 8), steel}
  p[#p + 1] = {at(capsule{radius=0.02, height=0.4, segments=10, axis="x"}, 0, h / 2 - 0.06, -0.39), iron}
  -- Bodged: a crack down its side taped over in a cross.
  p[#p + 1] = {tape(0.007, 0.22, 0.05, 0.285, -0.02, 0.08, 25, axis_x()), TAPE}
  p[#p + 1] = {tape(0.007, 0.22, 0.05, 0.2855, -0.02, 0.08, -25, axis_x()), TAPE2}
  for _, x in ipairs({-0.22, 0.22}) do p[#p + 1] = {cyl(0.018, 0.1, x, h / 2 - 0.01, -0.36, "x", 10), iron} end
  -- The bodged frame its springs hang from: the kart's wheels stand well out past the bin, so two wooden rails are
  -- bolted along its sides and cross beams join them out front and behind, at the springs' mounts (each corner of
  -- the kart's box, a little under its top: wheelLook), the bolts' heads on the rails.
  local FY = -h / 2 + 0.15            -- the springs' tops
  local FZ = 0.5                      -- the wheelbase's half (CHASSIS' base 1.0)
  for _, sx in ipairs({-1, 1}) do
    p[#p + 1] = {rb(0.05, 0.07, FZ * 2 + 0.12, sx * 0.295, FY, 0, 0.01), wood}
    for _, z in ipairs({-0.18, 0.18}) do p[#p + 1] = {cyl(0.016, 0.03, sx * 0.325, FY, z, "x", 8), iron} end
  end
  for _, sz in ipairs({-1, 1}) do
    p[#p + 1] = {rb(0.64, 0.06, 0.08, 0, FY, sz * FZ, 0.01), wood}
  end
  part("chassis_bin", p)

  -- The lid: flung open all the way, hanging down the bin's back from its hinge (here, the origin), leaning out from
  -- the wall enough to clear the frame's back cross beam behind it (its inside 5 cm behind the beam where it passes;
  -- the game's flap only ever swings it further out). Its top faces the bin; its rim along the bottom.
  local function hanging(m) return rotate(m, {angle=115, axis=axis_x(), pivot=origin()}) end
  local lid = {}
  lid[#lid + 1] = {hanging(rb(0.64, 0.035, 0.76, 0, 0.0175, 0.38, 0.01, 2)), shade(BIN, 0.86)}
  lid[#lid + 1] = {hanging(rb(0.5, 0.012, 0.6, 0, -0.006, 0.4, 0.004)), shade(BIN, 0.78)}
  lid[#lid + 1] = {hanging(rb(0.64, 0.05, 0.03, 0, -0.01, 0.75, 0.008)), shade(BIN, 0.86)}
  part("bin_lid", lid)
end

-- The canoe: an open wooden hull, pointed fore and aft, 0.7 x 0.3 x 2.7, gunwales, two thwarts and a paddle.
do
  local cy = 0.0
  local hull = scale(sphere{radius=1, segments=36, rings=16}, {factor=v3(0.35, 0.15, 1.35), pivot=origin()})
  hull = at(hull, 0, cy, 0)
  hull = intersect(hull, bx(1, 0.4, 3, 0, 0.08 - 0.2, 0))
  local hollow = at(scale(sphere{radius=1, segments=36, rings=16}, {factor=v3(0.31, 0.11, 1.22), pivot=origin()}), 0, cy + 0.03, 0)
  hull = subtract(hull, hollow)
  -- Varnished cedar.
  hull = paint(hull, C(0.82, 0.54, 0.3))
  -- A painted band along each side under the gunwale, and the inside's darker wood.
  hull = paint_if(hull, C(0.55, 0.14, 0.08), function(f)
    return f.center.y > 0.0 and f.center.y < 0.05 and math.abs(f.normal.y) < 0.8 and (f.center.x * f.normal.x) > 0
  end)
  hull = paint_if(hull, C(0.68, 0.42, 0.22), function(f)
    local c = f.center
    return (c.x / 0.316) ^ 2 + ((c.y - 0.03) / 0.116) ^ 2 + (c.z / 1.226) ^ 2 < 1.0 and c.y < 0.079
  end)
  local p = {{hull}}
  -- The gunwales: a wooden rail round the rim.
  local g = {}
  for i = 0, 47 do
    local a = 2 * math.pi * i / 48
    local ca, sa = math.cos(a), math.sin(a)
    g[#g + 1] = v3(0.287 * sa, 0.08, 1.11 * ca)
  end
  p[#p + 1] = {tube(g, 0.016, 8, true), wood}
  for _, t in ipairs({{0.5, 0.56}, {-0.6, 0.53}}) do p[#p + 1] = {board(t[2], 0.025, 0.08, 0, 0.06, t[1], wood, 200 + t[1] * 10, 0.006)} end
  -- The paddle, laid across the thwarts.
  p[#p + 1] = {rod(v3(-0.12, 0.088, -0.75), v3(0.08, 0.088, 0.45), 0.014, 8), wood}
  p[#p + 1] = {turn(ell(0.07, 0.012, 0.18, 0, 0, 0, 12), 9.5, axis_y(), 0.1, 0.088, 0.6), wood}
  p[#p + 1] = {turn(bx(0.08, 0.02, 0.02, 0, 0, 0), 9.5, axis_y(), -0.125, 0.088, -0.78), walnut}
  -- Bodged: a hole taped over on one side, a patch of other wood nailed over another, the paddle tied down.
  p[#p + 1] = {tape(0.008, 0.06, 0.2, 0.343, 0.0, 0.3, 12, axis_x()), TAPE}
  p[#p + 1] = {bx(0.008, 0.07, 0.26, -0.343, 0.0, -0.4), C(0.5, 0.34, 0.18)}
  for _, z in ipairs({-0.51, -0.29}) do p[#p + 1] = {nail(-0.348, 0.0, z, "x"), iron} end
  p[#p + 1] = {lash_x(0.0, 0.088, 0.13, 0.022), TWINE}
  part("chassis_canoe", p)
end

-- Wheels ------------------------------------------------------------------------------------------
-- Not tinted: their colours are their own. Each about its hub, its axle along x.

-- Laced spokes: n from the hub's flanges (alternate sides, x ±`half`, radius r0) to the rim at r1.
local function laced(n, r0, r1, half, rad)
  local s = {}
  for i = 0, n - 1 do
    local a = 2 * math.pi * i / n
    local side = (i % 2 == 0) and 1 or -1
    local ah = a + side * 0.18
    s[#s + 1] = rod(v3(side * half, math.cos(ah) * r0, math.sin(ah) * r0), v3(0, math.cos(a) * r1, math.sin(a) * r1), rad, 4)
  end
  return many(s)
end
-- A hub: a barrel with a flange at either end, `half` out from the middle.
local function hub(r, flange, half, seg)
  return lathe({{0.004, -half - 0.006}, {flange * 0.7, -half - 0.006}, {flange, -half + 0.002}, {flange, -half + 0.008}, {r, -half + 0.012},
    {r, half - 0.012}, {flange, half - 0.008}, {flange, half - 0.002}, {flange * 0.7, half + 0.006}, {0.004, half + 0.006}}, seg or 16)
end

-- Pram: a black tyre with white walls on a chrome rim, laced spokes, red hub caps, 0.18 m.
do
  part("wheel_pram", {
    {hoop(0.138, 0.182, 0.046, 40, 0.8, 12), rubber},
    {at(hoop(0.143, 0.163, 0.004, 40, 0.5, 8), 0.0212, 0, 0), cream},
    {at(hoop(0.143, 0.163, 0.004, 40, 0.5, 8), -0.0212, 0, 0), cream},
    {hoop(0.127, 0.141, 0.03, 40, 0.5, 8), chrome},
    {laced(16, 0.026, 0.13, 0.024, 0.0032), chrome},
    {hub(0.016, 0.03, 0.032, 16), chrome},
    {at(scale(sphere{radius=0.022, segments=14, rings=7}, {factor=v3(0.5, 1, 1), pivot=origin()}), 0.04, 0, 0), red},
    {at(scale(sphere{radius=0.022, segments=14, rings=7}, {factor=v3(0.5, 1, 1), pivot=origin()}), -0.04, 0, 0), red},
  })
end

-- Trolley caster: a grey rubber tyre on a blue plastic wheel, ribbed, its axle bolt through, 0.11 m.
do
  local wheel = lathe({{0.012, -0.012}, {0.035, -0.012}, {0.06, -0.019}, {0.08, -0.019}, {0.08, 0.019}, {0.06, 0.019}, {0.035, 0.012}, {0.012, 0.012}}, 28)
  local ribs = {}
  for i = 0, 5 do
    local a = 360 * i / 6
    for _, s in ipairs({-1, 1}) do
      ribs[#ribs + 1] = turn(rb(0.012, 0.042, 0.008, s * 0.016, 0.052, 0, 0.003), a, axis_x())
    end
  end
  part("wheel_trolley", {
    {hoop(0.074, 0.11, 0.05, 32, 0.6, 12), C(0.16, 0.16, 0.18)},
    {wheel, blue},
    {many(ribs), shade(blue, 0.7)},
    {cyl(0.011, 0.066, 0, 0, 0, "x", 10), steel},
    {bolt(0.032, 0, 0, "x", 0.018), chrome},
    {bolt(-0.032, 0, 0, "x", 0.018), chrome},
  })
end

-- Bike: a big thin tyre with gum walls and a knobbly tread, a red rim, many laced spokes, a reflector, 0.3 m.
do
  local tyre = paint(hoop(0.258, 0.302, 0.044, 56, 0.9, 10), rubber)
  tyre = paint_if(tyre, gumwall, function(f) local r = radial(f); return math.abs(f.center.x) > 0.01 and r < 0.29 end)
  local knobs = {}
  for i = 0, 47 do
    local a = 360 * i / 48
    local x = (i % 2 == 0) and 0.008 or -0.008
    knobs[#knobs + 1] = turn(bx(0.012, 0.008, 0.014, x, 0.3, 0), a, axis_x())
  end
  part("wheel_bike", {
    {tyre},
    {many(knobs), tread},
    {hoop(0.244, 0.262, 0.026, 56, 0.4, 8), red},
    {laced(P.spokes, 0.03, 0.247, 0.03, 0.0024), chrome},
    {hub(0.018, 0.034, 0.04, 16), chrome},
    {cyl(0.008, 0.11, 0, 0, 0, "x", 8), steel},
    -- The valve, and an orange reflector clipped to two spokes.
    {cyl(0.005, 0.03, 0, 0.235, 0, "y", 6), chrome},
    {rb(0.012, 0.07, 0.03, 0, -0.16, 0.0, 0.004), orange},
  })
end

-- Skateboard wheels: little hard urethane ones in mint, a white core and a bearing, 0.06 m.
do
  part("wheel_skate", {
    {hoop(0.026, 0.06, 0.05, 28, 0.55, 12), mint},
    {lathe({{0.012, -0.024}, {0.03, -0.024}, {0.03, 0.024}, {0.012, 0.024}}, 20), white},
    {cyl(0.017, 0.056, 0, 0, 0, "x", 14), black},
    {cyl(0.009, 0.07, 0, 0, 0, "x", 10), steel},
    {bolt(0.036, 0, 0, "x", 0.011), chrome},
  })
end

-- Toy tractor tyres: chunky chevron lugs on a yellow dished rim with its bolts and a red hub cap -- modelled at
-- 0.45 m and emitted at 70% of that, 0.315 m (WHEELS' radius).
do
  local lugs = {}
  local n = 16
  for i = 0, n - 1 do
    for _, s in ipairs({-1, 1}) do
      local a = 360 * (i + (s > 0 and 0.5 or 0)) / n
      local lug = turn(rb(0.1, 0.045, 0.06, 0, 0, 0, 0.01), s * 24, axis_y(), s * 0.055, 0.425, 0)
      lugs[#lugs + 1] = turn(lug, a, axis_x())
    end
  end
  local tyre = paint(hoop(0.24, 0.425, 0.23, 36, 0.55, 12), rubber)
  tyre = paint_if(tyre, tread, function(f) return math.abs(f.center.x) > 0.09 end)
  local bolts = {}
  for i = 0, 7 do
    local a = 2 * math.pi * i / 8
    for _, s in ipairs({-1, 1}) do bolts[#bolts + 1] = bolt(s * 0.064, math.cos(a) * 0.1, math.sin(a) * 0.1, "x", 0.013) end
  end
  part("wheel_tractor", {
    {tyre},
    {many(lugs), rubber},
    {lathe({{0.004, -0.06}, {0.13, -0.06}, {0.2, -0.105}, {0.25, -0.115}, {0.25, 0.115}, {0.2, 0.105}, {0.13, 0.06}, {0.004, 0.06}}, 32), yellow},
    {many(bolts), iron},
    {lathe({{0.004, -0.085}, {0.035, -0.085}, {0.055, -0.07}, {0.055, 0.07}, {0.035, 0.085}, {0.004, 0.085}}, 16), red},
  }, 0.7)
end

-- Go-kart slicks: wide, smooth, square-shouldered racing tyres with a white sidewall stripe, on a yellow alloy rim
-- with five spokes and chrome wheel nuts, 0.14 m.
do
  local tyre = paint(hoop(0.092, 0.14, 0.11, 44, 0.35, 16), rubber)
  tyre = paint_if(tyre, white, function(f)
    local r = radial(f); return math.abs(f.center.x) > 0.048 and r > 0.112 and r < 0.12
  end)
  local spokes, nuts = {}, {}
  for i = 0, 4 do
    local a = 360 * i / 5
    for _, s in ipairs({-1, 1}) do
      spokes[#spokes + 1] = turn(rb(0.014, 0.062, 0.022, s * 0.043, 0.058, 0, 0.005), a, axis_x())
      local r = 2 * math.pi * (i + 0.5) / 5
      nuts[#nuts + 1] = bolt(s * 0.05, math.cos(r) * 0.024, math.sin(r) * 0.024, "x", 0.007)
    end
  end
  part("wheel_slick", {
    {tyre},
    {lathe({{0.004, -0.04}, {0.07, -0.036}, {0.094, -0.05}, {0.094, 0.05}, {0.07, 0.036}, {0.004, 0.04}}, 36), yellow},
    {many(spokes), shade(yellow, 0.85)},
    {many(nuts), chrome},
    {bolt(0.05, 0, 0, "x", 0.015), chrome},
    {bolt(-0.05, 0, 0, "x", 0.015), chrome},
  })
end

-- Cart wheels: an old wooden wheel -- a turned hub, ten spokes, a wooden rim -- shod with an iron band and its
-- rivets, 0.24 m.
do
  local spokes, rivets = {}, {}
  for i = 0, 9 do
    local a = 2 * math.pi * i / 10
    spokes[#spokes + 1] = rod(v3(0, math.cos(a) * 0.04, math.sin(a) * 0.04), v3(0, math.cos(a) * 0.2, math.sin(a) * 0.2), 0.011, 6)
  end
  for i = 0, 19 do
    local a = 2 * math.pi * (i + 0.5) / 20
    for _, s in ipairs({-1, 1}) do rivets[#rivets + 1] = bolt(s * 0.027, math.cos(a) * 0.231, math.sin(a) * 0.231, "x", 0.005) end
  end
  part("wheel_cart", {
    {hoop(0.222, 0.24, 0.052, 48, 0.4, 8), iron},
    {many(rivets), steel},
    {hoop(0.188, 0.225, 0.046, 48, 0.5, 8), wood},
    {many(spokes), shade(wood, 1.25)},
    {lathe({{0.004, -0.055}, {0.03, -0.055}, {0.046, -0.025}, {0.046, 0.025}, {0.03, 0.055}, {0.004, 0.055}}, 18), walnut},
    {cyl(0.022, 0.13, 0, 0, 0, "x", 12), iron},
  })
end

-- Lawnmower wheels: chunky dark-grey plastic tyres with a chevron tread, on an orange hub with ribs, 0.13 m.
do
  local lugs, ribs = {}, {}
  local n = 18
  for i = 0, n - 1 do
    for _, s in ipairs({-1, 1}) do
      local a = 360 * (i + (s > 0 and 0.5 or 0)) / n
      local lug = turn(rb(0.03, 0.012, 0.016, 0, 0, 0, 0.003), s * 30, axis_y(), s * 0.013, 0.122, 0)
      lugs[#lugs + 1] = turn(lug, a, axis_x())
    end
  end
  for i = 0, 5 do
    for _, s in ipairs({-1, 1}) do ribs[#ribs + 1] = turn(rb(0.012, 0.05, 0.009, s * 0.02, 0.055, 0, 0.003), 60 * i, axis_x()) end
  end
  local grey = C(0.2, 0.2, 0.22)
  part("wheel_mower", {
    {hoop(0.088, 0.123, 0.056, 36, 0.6, 12), grey},
    {many(lugs), shade(grey, 0.75)},
    {lathe({{0.012, -0.016}, {0.04, -0.016}, {0.09, -0.024}, {0.09, 0.024}, {0.04, 0.016}, {0.012, 0.016}}, 28), orange},
    {many(ribs), shade(orange, 0.75)},
    {cyl(0.011, 0.07, 0, 0, 0, "x", 10), steel},
    {bolt(0.034, 0, 0, "x", 0.017), chrome},
    {bolt(-0.034, 0, 0, "x", 0.017), chrome},
  })
end

-- Plywood discs: a circle jigsawed out of an old sheet of ply, painted off-white and weathered, its cut edge showing
-- the layers, a big washer and nut each side on a threaded axle, 0.22 m.
do
  local ply = C(0.66, 0.64, 0.58)
  local layers = C(0.5, 0.38, 0.22)
  local disc = lathe({{0.004, -0.0095}, {0.213, -0.0095}, {0.213, 0.0095}, {0.004, 0.0095}}, 40)
  local nuts = {}
  for _, s in ipairs({-1, 1}) do
    nuts[#nuts + 1] = cyl(0.028, 0.004, s * 0.0117, 0, 0, "x", 16)
    nuts[#nuts + 1] = cyl(0.014, 0.012, s * 0.0198, 0, 0, "x", 6)
  end
  part("wheel_disc", {
    {disc, ply},
    {hoop(0.2115, 0.22, 0.021, 40, 0.5, 8), layers},
    {many(nuts), steel},
    {cyl(0.008, 0.11, 0, 0, 0, "x", 8), iron},
  })
end

-- Bodywork ----------------------------------------------------------------------------------------
-- Each in its own colours.

-- A solid of revolution along +z (a rocket's axis): `pts` are { radius, z } pairs, counter-clockwise.
local function lathe_z(pts, seg)
  local ps = {}
  for i, p in ipairs(pts) do ps[i] = v2(p[1], p[2]) end
  return rotate(revolve(poly{points=ps}, {segments=seg}), {angle=90, axis=axis_x(), pivot=origin()})
end

-- The cardboard rocket: a nose cone forward, taped bands, portholes, three fins and a nozzle.
do
  local cardb = C(0.93, 0.84, 0.66)
  local body = lathe_z({{0.004, -0.2}, {0.2, -0.2}, {0.25, -0.15}, {0.25, 0.3}, {0.235, 0.42}, {0.19, 0.54}, {0.11, 0.65}, {0.004, 0.72}}, 28)
  body = at(body, 0, 0.25, 0)
  body = paint(body, cardb)
  body = paint_if(body, red, function(f) return f.center.z > 0.43 end)
  local p = {{body}}
  -- Tape bands round it.
  for _, z in ipairs({-0.1, 0.25}) do p[#p + 1] = {at(cylinder{radius=0.254, height=0.04, segments=28, axis="z"}, 0, 0.25, z), C(0.75, 0.62, 0.42)} end
  -- Portholes, either side.
  for _, s in ipairs({-1, 1}) do
    p[#p + 1] = {at(torus{major_radius=0.06, minor_radius=0.014, major_segments=18, minor_segments=6, axis="x"}, s * 0.245, 0.3, 0.08), steel}
    p[#p + 1] = {cyl(0.05, 0.012, s * 0.244, 0.3, 0.08, "x", 18), glass}
  end
  -- Three fins about its tail, one up and two down either side.
  for i = 0, 2 do
    local fin = polyhedron{
      vertices={v3(-0.012, 0.2, -0.2), v3(-0.012, 0.2, 0.12), v3(-0.012, 0.46, -0.14), v3(-0.012, 0.46, -0.3),
                v3(0.012, 0.2, -0.2), v3(0.012, 0.2, 0.12), v3(0.012, 0.46, -0.14), v3(0.012, 0.46, -0.3)},
      faces={{1, 2, 3, 4}, {5, 8, 7, 6}, {1, 5, 6, 2}, {2, 6, 7, 3}, {3, 7, 8, 4}, {4, 8, 5, 1}},
    }
    fin = bev(fin, 0.005)
    p[#p + 1] = {at(rotate(fin, {angle=120 * i, axis=axis_z(), pivot=origin()}), 0, 0.25, 0), red}
  end
  -- The nozzle, a flame-orange inside.
  p[#p + 1] = {at(lathe_z({{0.1, -0.3}, {0.16, -0.32}, {0.16, -0.3}, {0.12, -0.19}, {0.1, -0.19}}, 20), 0, 0.25, 0), iron}
  p[#p + 1] = {at(cylinder{radius=0.1, height=0.012, segments=20, axis="z"}, 0, 0.25, -0.28), orange}
  part("deco_rocket", p)
end

-- The foam duck: a fat body with wings and a cocked tail, a round head, a beak, big eyes and a sailor's hat.
do
  local duck = C(0.99, 0.86, 0.2)
  local beak = C(1.0, 0.5, 0.06)
  local p = {}
  p[#p + 1] = {ell(0.3, 0.225, 0.39, 0, 0.25, 0, 22), duck}
  p[#p + 1] = {ell(0.22, 0.2, 0.2, 0, 0.3, 0.2, 16), duck}
  p[#p + 1] = {turn(ell(0.13, 0.08, 0.18, 0, 0, 0, 14), -35, axis_x(), 0, 0.4, -0.33), duck}
  for _, s in ipairs({-1, 1}) do
    p[#p + 1] = {turn(ell(0.06, 0.14, 0.24, 0, 0, 0, 14), -12, axis_x(), s * 0.27, 0.32, -0.04), shade(duck, 0.93)}
  end
  p[#p + 1] = {ell(0.13, 0.15, 0.13, 0, 0.47, 0.17, 14), duck}
  p[#p + 1] = {ball(0.18, 0, 0.62, 0.22, 20), duck}
  -- The beak, upper and lower.
  p[#p + 1] = {turn(ell(0.095, 0.03, 0.12, 0, 0, 0, 14), -8, axis_x(), 0, 0.6, 0.38), beak}
  p[#p + 1] = {turn(ell(0.075, 0.022, 0.09, 0, 0, 0, 12), 6, axis_x(), 0, 0.56, 0.36), shade(beak, 0.85)}
  -- The eyes: white, a black pupil, a glint.
  for _, s in ipairs({-1, 1}) do
    p[#p + 1] = {ell(0.05, 0.06, 0.03, s * 0.085, 0.69, 0.37, 12), white}
    p[#p + 1] = {ell(0.03, 0.038, 0.02, s * 0.088, 0.69, 0.392, 10), black}
    p[#p + 1] = {ball(0.009, s * 0.08, 0.71, 0.41, 6), white}
    p[#p + 1] = {ell(0.04, 0.02, 0.02, s * 0.14, 0.6, 0.33, 8), C(1.0, 0.55, 0.5)}
  end
  -- A little sailor's hat, tipped back.
  p[#p + 1] = {turn(cylinder{radius=0.11, height=0.05, segments=20}, -12, axis_x(), 0, 0.79, 0.19), white}
  p[#p + 1] = {turn(cylinder{radius=0.114, height=0.018, segments=20}, -12, axis_x(), 0, 0.775, 0.192), C(0.12, 0.25, 0.65)}
  part("deco_duck", p)
end

-- The giant shark head: bursting up nose first, its jaws wide, rows of teeth, a white belly, gills and a fin.
do
  local sharkc = C(0.6, 0.68, 0.76)
  local p = {}
  local head = ell(0.37, 0.42, 0.42, 0, 0.6, 0.06, 26)
  head = paint(head, sharkc)
  head = paint_if(head, white, function(f) return f.normal.z > 0.35 and f.center.y < 0.62 end)
  p[#p + 1] = {head}
  -- The snout, pushing forward over the jaws.
  local snout = paint(ell(0.26, 0.2, 0.25, 0, 0.72, 0.28, 18), sharkc)
  p[#p + 1] = {snout}
  local jaw = paint(ell(0.32, 0.13, 0.36, 0, 0.15, 0.1, 22), sharkc)
  jaw = paint_if(jaw, white, function(f) return f.normal.y < -0.2 or f.normal.z > 0.5 end)
  p[#p + 1] = {jaw}
  -- The mouth, dark red inside, a tongue.
  p[#p + 1] = {ell(0.27, 0.12, 0.14, 0, 0.33, 0.33, 18), C(0.45, 0.05, 0.08)}
  p[#p + 1] = {ell(0.15, 0.04, 0.12, 0, 0.27, 0.36, 12), C(0.9, 0.35, 0.4)}
  -- Teeth, top and bottom, round the front of the mouth.
  local teeth = {}
  for i = 0, 8 do
    local t = (i / 8 - 0.5) * 2
    local x = t * 0.24
    local z = 0.44 - t * t * 0.12
    teeth[#teeth + 1] = at(rotate(cone{radius=0.032, height=0.1, segments=6}, {angle=180, axis=axis_x(), pivot=origin()}), x, 0.41, z)
    teeth[#teeth + 1] = at(cone{radius=0.03, height=0.09, segments=6}, x, 0.25, z - 0.03)
  end
  p[#p + 1] = {many(teeth), white}
  -- Eyes, black and glinting; gill slits down each side.
  for _, s in ipairs({-1, 1}) do
    p[#p + 1] = {ell(0.03, 0.06, 0.06, s * 0.3, 0.74, 0.22, 12), black}
    p[#p + 1] = {ball(0.012, s * 0.325, 0.76, 0.25, 6), white}
    for k = 0, 2 do
      p[#p + 1] = {turn(rb(0.02, 0.2, 0.018, 0, 0, 0, 0.005), s * 8, axis_z(), s * 0.35, 0.5, -0.06 - k * 0.07), C(0.25, 0.3, 0.36)}
    end
  end
  -- The dorsal fin, swept back.
  local fin = polyhedron{vertices={v3(-0.035, 0.9, -0.32), v3(0.035, 0.9, -0.32), v3(0.035, 0.95, 0.12), v3(-0.035, 0.95, 0.12),
    v3(-0.006, 1.48, -0.42), v3(0.006, 1.48, -0.42)},
    faces={{1, 2, 3, 4}, {1, 5, 6, 2}, {2, 6, 3}, {3, 6, 5, 4}, {4, 5, 1}}}
  p[#p + 1] = {fin, shade(sharkc, 0.85)}
  part("deco_shark", p)
end

-- The rocket booster: a red tube on a cradle, a white nose, hazard bands, fins, its nozzle out the back.
do
  local p = {}
  p[#p + 1] = {at(cylinder{radius=0.16, height=0.75, segments=28, axis="z"}, 0, 0.22, 0), C(0.95, 0.25, 0.18)}
  p[#p + 1] = {at(lathe_z({{0.004, 0.37}, {0.16, 0.37}, {0.15, 0.45}, {0.12, 0.53}, {0.07, 0.6}, {0.004, 0.63}}, 28), 0, 0.22, 0), white}
  -- Hazard bands: yellow with black stripes.
  for _, z in ipairs({-0.3, 0.26}) do
    p[#p + 1] = {at(cylinder{radius=0.165, height=0.06, segments=28, axis="z"}, 0, 0.22, z), yellow}
    for i = 0, 7 do
      p[#p + 1] = {turn(bx(0.03, 0.012, 0.062, 0, 0.166, 0), 45 * i + 20, axis_z(), 0, 0.22, z), black}
    end
  end
  -- Four little fins at the back.
  for i = 0, 3 do
    p[#p + 1] = {at(rotate(rb(0.018, 0.12, 0.2, 0, 0.2, -0.27, 0.005), {angle=45 + 90 * i, axis=axis_z(), pivot=origin()}), 0, 0.22, 0), white}
  end
  -- The nozzle, glowing inside.
  p[#p + 1] = {at(lathe_z({{0.08, -0.4}, {0.165, -0.52}, {0.18, -0.52}, {0.11, -0.38}, {0.09, -0.36}}, 24), 0, 0.22, 0), steel}
  p[#p + 1] = {at(cylinder{radius=0.1, height=0.01, segments=20, axis="z"}, 0, 0.22, -0.39), orange}
  p[#p + 1] = {at(cone{radius=0.07, height=0.12, segments=14, axis="z"}, 0, 0.22, -0.44), yellow}
  -- The cradle: two straps over it, the legs down to the chassis.
  for _, z in ipairs({-0.15, 0.12}) do
    p[#p + 1] = {at(torus{major_radius=0.168, minor_radius=0.012, major_segments=28, minor_segments=6, axis="z"}, 0, 0.22, z), iron}
    p[#p + 1] = {rb(0.3, 0.04, 0.05, 0, 0.03, z, 0.008), iron}
    p[#p + 1] = {rod(v3(-0.12, 0.03, z), v3(-0.07, 0.1, z), 0.015, 6), iron}
    p[#p + 1] = {rod(v3(0.12, 0.03, z), v3(0.07, 0.1, z), 0.015, 6), iron}
  end
  -- Two of them, a little smaller, one either side of the driver (who sits on the kart's middle line, 0.3 ahead of
  -- this model's middle: assemble's body z and seat), on a crossbar behind the seat.
  local POD, SIDE = 0.75, 0.4
  local pods = {}
  for _, sx in ipairs({-1, 1}) do
    for _, q in ipairs(p) do
      pods[#pods + 1] = {at(scale(q[1], {factor=v3(POD, POD, POD), pivot=origin()}), sx * SIDE, 0, 0), q[2]}
    end
  end
  pods[#pods + 1] = {rb(2 * SIDE, 0.04, 0.06, 0, 0.025, -0.25, 0.008), iron}
  part("deco_booster", pods)
end

-- Glider wings: two broad plywood aerofoils, swept back and tipped up a little, roundels and red tips -- bolted to
-- the basket's sides at its rim, clear of the driver sat in it, their struts braced to its sides below.
do
  -- A symmetric aerofoil, chord c, t thick, its nose to +y (to be +z), counter-clockwise.
  local function aerofoil(c, t)
    local pts, n = {}, 12
    local function half(u) return 5 * t * (0.2969 * math.sqrt(u) - 0.126 * u - 0.3516 * u * u + 0.2843 * u ^ 3 - 0.1036 * u ^ 4) end
    for i = 0, n do local u = (i / n) ^ 2; pts[#pts + 1] = v2(-half(u) - 0.001, c / 2 - u * c) end
    for i = n - 1, 1, -1 do local u = (i / n) ^ 2; pts[#pts + 1] = v2(half(u) + 0.001, c / 2 - u * c) end
    return poly{points=pts}
  end
  local ply = C(0.95, 0.88, 0.72)
  -- Each wing from ROOT (the basket's side) out SPAN, its chord CHORD, at height Y (the rim); swept back SWEEP degrees,
  -- tipped up DIHEDRAL. Within the rules' two metres across.
  local ROOT, SPAN, CHORD, Y, SWEEP, DIHEDRAL = 0.31, 0.62, 0.4, -0.03, 12, 4
  local rise, back = math.tan(math.rad(DIHEDRAL)), math.sin(math.rad(SWEEP))
  local function wing(s)
    local m = extrude(aerofoil(CHORD, 0.05), {distance=SPAN, segments=5})
    m = rotate(m, {angle=-90, axis=axis_z(), pivot=origin()})   -- span along +x, thickness y
    m = at(m, ROOT, Y, 0)
    m = rotate(m, {angle=DIHEDRAL, axis=axis_z(), pivot=v3(ROOT, Y, 0)})
    m = rotate(m, {angle=SWEEP, axis=axis_y(), pivot=v3(ROOT, Y, 0)})
    if s < 0 then m = mirror(m, {normal=axis_x(), pivot=origin()}) end
    m = paint(m, ply)
    -- Ribs showing through the skin.
    return paint_if(m, shade(ply, 0.88), function(f)
      local k = math.floor((math.abs(f.center.x) - ROOT) / 0.15)
      return k % 2 == 1
    end)
  end
  local p = {{wing(1)}, {wing(-1)}}
  for _, s in ipairs({-1, 1}) do
    -- The tip, red, and a roundel near it on top.
    local tip = rotate(rb(0.05, 0.045, CHORD - 0.01, s * (ROOT + SPAN + 0.02), Y + SPAN * rise, 0, 0.012), {angle=s * SWEEP, axis=axis_y(), pivot=v3(s * ROOT, Y, 0)})
    p[#p + 1] = {tip, red}
    local out = SPAN * 0.6
    local rx, ry, rz = s * (ROOT + out), Y + out * rise + 0.022, -out * back + 0.02
    p[#p + 1] = {cyl(0.08, 0.006, rx, ry, rz, "y", 22), C(0.15, 0.3, 0.75)}
    p[#p + 1] = {cyl(0.053, 0.006, rx, ry + 0.004, rz, "y", 22), white}
    p[#p + 1] = {cyl(0.028, 0.006, rx, ry + 0.008, rz, "y", 22), red}
    -- The root's bracket on the basket's side, and a strut from low on the side up under the wing.
    p[#p + 1] = {rb(0.05, 0.07, CHORD * 0.7, s * (ROOT - 0.01), Y - 0.02, 0, 0.012), wood}
    local sx = ROOT + SPAN * 0.45
    p[#p + 1] = {rod(v3(s * 0.3, Y - 0.3, -0.03), v3(s * sx, Y + (sx - ROOT) * rise - 0.025, -(sx - ROOT) * back), 0.012, 6), walnut}
  end
  part("deco_wings", p)
end


-- The suspension, seen: a coil spring round a damper, 1 m tall about its middle (the game stretches it between the
-- chassis and each wheel, so it squashes as the spring does). Not tinted: a bright yellow coil, a red damper body,
-- a chrome shaft and blue spring seats, chunky enough to read at speed.
do
  local turns, coil_r, wire_r = 6, 0.08, 0.018
  local pts = {}
  local steps = turns * 16
  for i = 0, steps do
    local t = i / steps
    local a = t * turns * 2 * math.pi
    pts[#pts + 1] = v3(math.cos(a) * coil_r, -0.46 + t * 0.92, math.sin(a) * coil_r)
  end
  local coil = sweep(circle{radius=wire_r, segments=8}, path{points=pts}, {caps=true})
  local seat = lathe_y({{0.014, -0.02}, {0.1, -0.02}, {0.1, 0.0}, {0.075, 0.02}, {0.014, 0.02}}, 18)
  part("spring", {
    {coil, yellow},
    {at(cylinder{radius=0.042, height=0.48, segments=14}, 0, -0.22, 0), red},
    {at(cylinder{radius=0.046, height=0.03, segments=14}, 0, 0.03, 0), black},
    {at(cylinder{radius=0.017, height=0.43, segments=10}, 0, 0.245, 0), chrome},
    {at(seat, 0, 0.48, 0), blue},
    {at(rotate(seat, {angle=180, axis=axis_x(), pivot=origin()}), 0, -0.48, 0), blue},
  })
end

-- A coil of `turns` round y from y0 to y1, its radius radius(t) along it (t 0 to 1), wire `w` thick.
local function coil_of(turns, y0, y1, radius, w, per)
  local pts = {}
  local steps = math.floor(turns * (per or 16))
  for i = 0, steps do
    local t = i / steps
    local a = t * turns * 2 * math.pi
    local r = radius(t)
    pts[#pts + 1] = v3(math.cos(a) * r, y0 + t * (y1 - y0), math.sin(a) * r)
  end
  return sweep(circle{radius=w, segments=8}, path{points=pts}, {caps=true})
end
-- A flat wire ring round y at height y.
local function ring_y(r, y, w, n)
  local pts = {}
  n = n or 24
  for i = 0, n - 1 do
    local a = 2 * math.pi * i / n
    pts[#pts + 1] = v3(math.cos(a) * r, y, math.sin(a) * r)
  end
  return tube(pts, w, 8, true)
end

-- Bolted on: no suspension at all -- a rusty iron strut, flanged top and bottom and bolted through, the same
-- 1 m about its middle (drawn short: it hardly moves).
do
  local bolts = {}
  for _, y in ipairs({-0.48, 0.48}) do
    for _, x in ipairs({-0.04, 0.04}) do bolts[#bolts + 1] = bolt(x, y + (y > 0 and 0.018 or -0.018), 0, "y", 0.011) end
  end
  part("spring_bolted", {
    {rb(0.05, 0.92, 0.014, 0, 0, 0, 0.004), iron},
    {rb(0.014, 0.92, 0.04, 0, 0, 0.013, 0.004), shade(iron, 1.2)},
    {rb(0.13, 0.024, 0.07, 0, 0.47, 0.01, 0.005), iron},
    {rb(0.13, 0.024, 0.07, 0, -0.47, 0.01, 0.005), iron},
    {many(bolts), steel},
    {rb(0.03, 0.12, 0.016, 0.006, 0.12, -0.001, 0.004), rust},
    {rb(0.028, 0.09, 0.016, -0.008, -0.25, -0.001, 0.004), rust},
  })
end

-- Bed springs: a squat hourglass coil of thin steel wire off an old mattress, its end loops flat, a scrap of the
-- bed's wooden slat on top it was pulled off.
do
  local wire_c = C(0.72, 0.74, 0.78)
  part("spring_bed", {
    {coil_of(5, -0.46, 0.46, function(t) local u = 2 * t - 1; return 0.05 + 0.055 * u * u end, 0.01, 20), wire_c},
    {ring_y(0.105, 0.465, 0.01), wire_c},
    {ring_y(0.105, -0.465, 0.01), wire_c},
    {rb(0.26, 0.035, 0.09, 0, 0.495, 0, 0.008), wood},
  })
end

-- Pogo springs: a pogo stick's insides -- a long tight chrome coil running up into a red tube with a black grip
-- band, a fat rubber foot under it.
do
  part("spring_pogo", {
    {coil_of(13, -0.42, 0.08, function(_) return 0.048 end, 0.01, 14), chrome},
    {at(cylinder{radius=0.062, height=0.44, segments=18}, 0, 0.26, 0), red},
    {at(cylinder{radius=0.066, height=0.1, segments=18}, 0, 0.36, 0), black},
    {at(cylinder{radius=0.07, height=0.02, segments=18}, 0, 0.04, 0), chrome},
    {at(cylinder{radius=0.014, height=0.5, segments=10}, 0, -0.17, 0), chrome},
    {at(cone{radius=0.055, radius_top=0.035, height=0.06, segments=14}, 0, -0.48, 0), black},
  })
  -- What a spring is fixed to (`wheelLook` stretches it along x): a plain steel rod 1 m long, centred, 16 mm round --
  -- a stub axle from the spring's foot into its hub, or half the cross beam its top hangs from.
  part("strut", {
    {cyl(0.016, 1, 0, 0, 0, "x", 10), steel},
  })
end

-- Steering ------------------------------------------------------------------------------------------
-- Each about where the driver's hands hold it, its turning axis +y (the game tilts it toward the driver and
-- turns it about that as they steer). Not tinted.
--
--   steer_wheel   a go-kart wheel lying in the xz plane, its column running down -y into the chassis
--   steer_bars    bike handlebars along x, their stem down -y
--   steer_rope    two rope handles, the ropes running forward and down (+z, -y) to a bar on the front axle
--   steer_levers  two brake levers up from the chassis either side, a cable from each back to its rear wheel

do
  local p = {}
  -- The rim: black, red leather grips where the hands go, yellow stitching across them.
  local rim = paint(torus{major_radius=0.17, minor_radius=0.022, major_segments=48, minor_segments=10, axis="y"}, black)
  rim = paint_if(rim, C(0.75, 0.07, 0.05), function(f)
    local a = math.deg(math.atan(f.center.z, f.center.x))
    return math.abs(math.abs(a) - 90) > 38 or false
  end)
  rim = paint_if(rim, yellow, function(f)
    local a = math.deg(math.atan(f.center.z, f.center.x))
    local off = math.abs(math.abs(a) - 90)
    return off > 38 and math.abs(off - 52) < 3.8 or false
  end)
  p[#p + 1] = {rim}
  -- Three spokes, drilled aluminium.
  for i = 0, 2 do
    local a = 90 + i * 120
    p[#p + 1] = {rotate(rb(0.15, 0.012, 0.03, 0.09, 0, 0, 0.004), {angle=a, axis=axis_y(), pivot=origin()}), C(0.78, 0.8, 0.84)}
    p[#p + 1] = {rotate(cyl(0.007, 0.014, 0.1, 0.0, 0, "y", 8), {angle=a, axis=axis_y(), pivot=origin()}), iron}
  end
  -- The hub, its horn button, the column with its collar.
  p[#p + 1] = {lathe_y({{0.004, -0.025}, {0.045, -0.025}, {0.05, -0.01}, {0.05, 0.012}, {0.04, 0.022}, {0.004, 0.022}}, 20), iron}
  p[#p + 1] = {at(scale(sphere{radius=0.032, segments=16, rings=8}, {factor=v3(1, 0.4, 1), pivot=origin()}), 0, 0.022, 0), red}
  p[#p + 1] = {cyl(0.012, 0.008, 0, 0.034, 0, "y", 12), yellow}
  p[#p + 1] = {cyl(0.018, 0.45, 0, -0.245, 0, "y", 10), chrome}
  p[#p + 1] = {cyl(0.03, 0.04, 0, -0.07, 0, "y", 12), iron}
  p[#p + 1] = {rb(0.05, 0.05, 0.05, 0, -0.45, 0, 0.008), iron}
  part("steer_wheel", p)
end

do
  local p = {}
  -- The bar: rising and swept back toward the rider at either end.
  local pts = {}
  for i = 0, 16 do
    local x = -0.25 + 0.5 * i / 16
    local u = (math.abs(x) / 0.25) ^ 2
    pts[#pts + 1] = v3(x, 0.03 * u, -0.05 * u)
  end
  p[#p + 1] = {tube(pts, 0.014, 10), chrome}
  -- Blue ribbed grips, flanged.
  for _, s in ipairs({-1, 1}) do
    local gx = s * 0.205
    local u = (0.205 / 0.25) ^ 2
    local gy, gz = 0.03 * u, -0.05 * u
    local tilt = math.deg(math.atan(0.05 * 2 * 0.205 / 0.0625, 1))
    local function place(m) return at(rotate(m, {angle=s * tilt, axis=axis_y(), pivot=origin()}), gx, gy, gz) end
    local rings = {}
    for k = -2, 2 do rings[#rings + 1] = at(torus{major_radius=0.024, minor_radius=0.004, major_segments=14, minor_segments=4, axis="x"}, k * 0.018, 0, 0) end
    p[#p + 1] = {place(cylinder{radius=0.024, height=0.1, segments=14, axis="x"}), blue}
    p[#p + 1] = {place(join(at(cylinder{radius=0.032, height=0.012, segments=14, axis="x"}, -s * 0.054, 0, 0),
      at(cylinder{radius=0.026, height=0.008, segments=14, axis="x"}, s * 0.0545, 0, 0))), shade(blue, 0.5)}
    p[#p + 1] = {place(many(rings)), shade(blue, 0.6)}
  end
  -- The stem and its clamp.
  p[#p + 1] = {cyl(0.02, 0.36, 0, -0.19, 0, "y", 12), steel}
  p[#p + 1] = {rb(0.07, 0.05, 0.05, 0, 0, 0, 0.01), iron}
  for _, s in ipairs({-1, 1}) do p[#p + 1] = {bolt(s * 0.02, 0, 0.026, "z", 0.007), chrome} end
  -- A bell on the left, a brake lever on the right.
  p[#p + 1] = {at(lathe_y({{0.004, -0.02}, {0.028, -0.02}, {0.026, -0.005}, {0.016, 0.012}, {0.004, 0.016}}, 16), -0.12, 0.034, 0.0), chrome}
  p[#p + 1] = {cyl(0.006, 0.03, -0.12, 0.01, 0.0, "y", 8), iron}
  p[#p + 1] = {ell(0.012, 0.006, 0.006, -0.1, 0.03, 0.02, 8), red}
  p[#p + 1] = {rb(0.03, 0.03, 0.03, 0.14, -0.005, 0.01, 0.006), iron}
  p[#p + 1] = {rod(v3(0.15, -0.01, 0.025), v3(0.23, -0.02, 0.05), 0.006, 6), C(0.78, 0.8, 0.84)}
  part("steer_bars", p)
end

do
  local hand, axle = 0.17, v3(0, -0.27, 0.44)
  local hemp, hemp2 = C(0.82, 0.66, 0.4), C(0.62, 0.46, 0.24)
  local p = {}
  -- The handles: turned wooden toggles with dark grip bands.
  for _, s in ipairs({-1, 1}) do
    local hm = paint(at(capsule{radius=0.022, height=0.08, segments=12, axis="x"}, s * hand, 0, 0), C(0.7, 0.48, 0.25))
    hm = paint_if(hm, walnut, function(f) local u = math.abs(f.center.x - s * hand); return u > 0.012 and u < 0.024 end)
    p[#p + 1] = {hm}
    -- The rope: sagging a little, twisted (its strands in two shades), a knot at each end.
    local a, b = v3(s * hand, -0.004, 0.012), v3(s * 0.24, axle.y + 0.02, axle.z)
    local pts = {}
    for i = 0, 12 do
      local t = i / 12
      local q = lerp(a, b, t)
      pts[#pts + 1] = q + v3(0, -0.05 * math.sin(math.pi * t), 0)
    end
    local rope = paint(tube(pts, 0.011, 6), hemp)
    rope = paint_if(rope, hemp2, function(f)
      local d = f.center - a
      local t = dot(d, normalize(b - a)) / length(b - a)
      local ang = math.atan(f.center.y - lerp(a, b, t).y, f.center.x - lerp(a, b, t).x)
      return (math.floor(t * 30 + ang / math.pi * 1.5) % 2) == 0
    end)
    p[#p + 1] = {rope}
    p[#p + 1] = {ball(0.02, b.x, b.y, b.z, 10), hemp2}
    p[#p + 1] = {ball(0.018, a.x, a.y - 0.01, a.z + 0.012, 10), hemp2}
  end
  -- The bar across the front axle, iron capped.
  p[#p + 1] = {at(lathe({{0.004, -0.28}, {0.024, -0.28}, {0.028, -0.26}, {0.028, 0.26}, {0.024, 0.28}, {0.004, 0.28}}, 14), axle.x, axle.y, axle.z), C(0.7, 0.48, 0.25)}
  p[#p + 1] = {at(cyl(0.031, 0.02, 0, 0, 0, "x", 14), -0.29, axle.y, axle.z), iron}
  p[#p + 1] = {at(cyl(0.031, 0.02, 0, 0, 0, "x", 14), 0.29, axle.y, axle.z), iron}
  part("steer_rope", p)
end

do
  local p = {}
  local pivot = -0.34
  for _, s in ipairs({-1, 1}) do
    local x = s * 0.2
    -- The lever: a flat steel bar up from its pivot at the chassis, a red rubber grip at the top.
    p[#p + 1] = {rb(0.012, 0.36, 0.03, x, pivot + 0.18 - 0.02, 0, 0.004), steel}
    p[#p + 1] = {at(capsule{radius=0.019, height=0.08, segments=12, axis="y"}, x, 0.005, 0), red}
    p[#p + 1] = {cyl(0.021, 0.008, x, -0.04, 0, "y", 12), shade(red, 0.5)}
    -- Its pivot: a bolt through a bracket, a toothed quadrant behind it.
    p[#p + 1] = {rb(0.03, 0.06, 0.05, x - s * 0.018, pivot, 0, 0.006), iron}
    p[#p + 1] = {bolt(x + s * 0.008, pivot, 0, "x", 0.01), chrome}
    p[#p + 1] = {at(cyl(0.05, 0.006, 0, 0, 0, "x", 10), x - s * 0.034, pivot + 0.03, -0.02), iron}
    -- The cable from halfway up the lever, back and down to that side's rear wheel.
    local a, b = v3(x, pivot + 0.12, -0.018), v3(s * 0.26, pivot + 0.02, -0.55)
    local pts = {}
    for i = 0, 10 do
      local t = i / 10
      pts[#pts + 1] = lerp(a, b, t) + v3(0, -0.04 * math.sin(math.pi * t), 0)
    end
    p[#p + 1] = {tube(pts, 0.005, 6), black}
    p[#p + 1] = {ball(0.009, a.x, a.y, a.z, 8), chrome}
  end
  part("steer_levers", p)
end

-- Damage -------------------------------------------------------------------------------------------
-- What a kart falls to bits as, painted pale so the colour of what broke (Render.tint) is theirs too, each about its middle:
--
--   bit     a splinter knocked off by a hit
--   plank   a broken board, what the chassis bursts into when it is wrecked: a jagged end, a bent nail

-- A slab from an outline in the xz plane (points as { x, z }, counter-clockwise seen from above), t thick about y = 0,
-- its grain in stripes along x, its split ends (x past `split`) fresh pale wood.
local function slab(outline, t, cuts, split)
  local ps = {}
  for i, q in ipairs(outline) do ps[i] = v2(q[1], q[2]) end
  local m = extrude(poly{points=ps}, {distance=t})
  m = at(m, 0, -t / 2, 0)
  for _, z in ipairs(cuts) do m = knife(m, {normal=axis_z(), point=v3(0, 0, z)}) end
  m = paint(m, dpale)
  m = paint_if(m, dpale2, function(f)
    local k = 0
    for _, z in ipairs(cuts) do if f.center.z > z then k = k + 1 end end
    return k % 2 == 1
  end)
  return paint_if(m, fresh, function(f) return f.center.x > split and math.abs(f.normal.y) < 0.6 end)
end

part("bit", {
  {slab({{-0.11, -0.03}, {0.06, -0.03}, {0.09, -0.012}, {0.12, -0.004}, {0.1, 0.008}, {0.075, 0.012}, {0.09, 0.024}, {0.055, 0.03}, {-0.08, 0.03}, {-0.1, 0.018}, {-0.115, 0.01}, {-0.1, -0.005}},
    0.03, {-0.012, 0.01}, 0.05)},
})

do
  local outline = {{-0.36, -0.06}, {0.28, -0.06}, {0.33, -0.045}, {0.36, -0.02}, {0.32, -0.005}, {0.345, 0.012}, {0.31, 0.022}, {0.37, 0.04}, {0.33, 0.06}, {-0.36, 0.06}}
  part("plank", {
    {slab(outline, 0.04, {-0.038, -0.012, 0.015, 0.04}, 0.27)},
    -- A bent nail through it near the whole end, another's head, rusting.
    {join(bx(0.012, 0.07, 0.012, -0.3, 0.045, 0), turn(bx(0.04, 0.012, 0.012, 0, 0, 0), 30, axis_z(), -0.285, 0.085, 0)), rust},
    {nail(-0.3, 0.021, 0.035), iron},
    {nail(-0.3, -0.021, 0.0), iron},
  })
end
