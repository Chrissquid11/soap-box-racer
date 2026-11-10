-- The inflatable start arch: one part, "arch", standing on its origin -- the middle of the ground between its legs --
-- spanning x, the road running through it along z (the karts drive through toward +z).
--
--   a puffy navy tube, sewn in segments that bulge between their seams, orange piping along both faces and round
--   every seam; the lower legs in a cream-and-navy chequer; each leg on a fat navy cushion with orange piping
--   a puffy orange sign on top reading SOAP BOX / MAYHEM in cream block letters outlined dark, chequered flags at its
--   top corners; under it a cream START banner with orange chevrons, and three amber start lights in a dark housing
--   (both faces carry the words and lights, each reading the right way round from its side)
--
-- Clear span 10 m between the cushions' inner sides at the ground (the legs' inner sides 10.5 m apart), apex inner
-- clearance 4.65 m (the lights' housing bottom 4.50 m), 12.7 m wide over the tube, 7.05 m high over the flags.
-- Colours on the vertices, one white material.
local p = params{
  tube_radius = { default = 0.55, min = 0.4, max = 0.7, doc = "Radius of the inflated tube, metres" },
  segments = { default = 10, min = 4, max = 16, integer = true, doc = "Sewn segments over the curve of the arch" },
  rings = { default = 6, min = 3, max = 10, integer = true, doc = "Rings per segment (smoothness of the bulges)" },
  bulge = { default = 0.07, min = 0, max = 0.15, doc = "How far a segment puffs out between its seams, share of the radius" },
  sway = { default = 2.5, min = 0, max = 5, doc = "How far the arch sways on its cushions as it wobbles, degrees" },
  period = { default = 3.2, min = 1.5, max = 8, doc = "Seconds for one sway of the wobble" },
}

local PAINT = material{name="Paint", base_color=v3(1,1,1), roughness=0.7, metallic=0}
-- Its sizes, skeleton and wobble: shared with its start lamps (_arch_rig.lua).
local RIG = include("_arch_rig.lua")

local NAVY = v3(0.012, 0.025, 0.13)
local ORANGE = v3(1.0, 0.3, 0.015)
local CREAM = v3(0.93, 0.85, 0.66)
local DARK = v3(0.02, 0.02, 0.05)
-- The start lights' lenses, off (dark smoked glass): lit, the game shows each lamp's own model over its lens.
local AMBER = v3(0.08, 0.05, 0.04)
local AMBER_HI = v3(0.3, 0.3, 0.32)
local HOUSING = v3(0.03, 0.03, 0.035)
local WHITE = v3(0.92, 0.92, 0.9)

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
local function paint_where(m, c, fn)
  local sel = faces_where(m, function(f) return fn(f.center, f.normal) == true end)
  if set_count(sel) == 0 then return m end
  return paint_faces(m, {faces=sel, color=c})
end
local pieces = {}
local function add(m) pieces[#pieces + 1] = m end
local function bx(sx, sy, sz, x, y, z) return translate(box{size=v3(sx, sy, sz)}, v3(x, y, z)) end

-- Vector arithmetic on components.
local function vadd(a, b) return v3(a.x + b.x, a.y + b.y, a.z + b.z) end
local function vsub(a, b) return v3(a.x - b.x, a.y - b.y, a.z - b.z) end
local function vmul(a, k) return v3(a.x * k, a.y * k, a.z * k) end

-- A tube through `pts` (radius radii[i] at each), `segs` round, closed into a loop or capped at its ends. Its frame at
-- each point: N = up x T, B = T x N; the ring's angle 0 on N, 90 on B.
local function tube(pts, radii, segs, closed, up)
  local n = #pts
  local verts, faces = {}, {}
  local frames = {}
  for i = 1, n do
    local a, b
    if closed then
      a, b = pts[(i - 2) % n + 1], pts[i % n + 1]
    else
      a, b = pts[math.max(1, i - 1)], pts[math.min(n, i + 1)]
    end
    local t = normalize(vsub(b, a))
    local nn = normalize(cross(up, t))
    local bb = cross(t, nn)
    frames[i] = {nn, bb}
    for j = 0, segs - 1 do
      local th = 2 * math.pi * j / segs
      local off = vadd(vmul(nn, math.cos(th) * radii[i]), vmul(bb, math.sin(th) * radii[i]))
      verts[#verts + 1] = vadd(pts[i], off)
    end
  end
  local function v(i, j) return (i - 1) * segs + (j % segs) + 1 end
  local last = closed and n or n - 1
  for i = 1, last do
    local i2 = i % n + 1
    for j = 0, segs - 1 do faces[#faces + 1] = {v(i, j), v(i, j + 1), v(i2, j + 1), v(i2, j)} end
  end
  if not closed then
    local s, e = {}, {}
    for j = segs - 1, 0, -1 do s[#s + 1] = v(1, j) end
    for j = 0, segs - 1 do e[#e + 1] = v(n, j) end
    faces[#faces + 1] = s
    faces[#faces + 1] = e
  end
  return polyhedron{vertices=verts, faces=faces}, frames
end

-- A rounded rectangle's outline, w by h, corners of radius cr, as points through map(u, v), counter-clockwise.
local function rr_outline(w, h, cr, per, map)
  local pts = {}
  local cs = {{w / 2 - cr, h / 2 - cr, 0}, {-w / 2 + cr, h / 2 - cr, 90}, {-w / 2 + cr, -h / 2 + cr, 180}, {w / 2 - cr, -h / 2 + cr, 270}}
  for _, c in ipairs(cs) do
    for k = 0, per do
      local a = rad(c[3] + 90 * k / per)
      pts[#pts + 1] = map(c[1] + cr * math.cos(a), c[2] + cr * math.sin(a))
    end
  end
  return pts
end
local function const(n, r) local t = {} for i = 1, n do t[i] = r end return t end

-- A pillow: a w by h rounded block (its profile in x and z), d thick along y, its sides puffed round over `puff`;
-- centred on the origin.
local function pillow(w, h, d, puff, cr)
  local secs = {}
  local K = 10
  for k = 0, K do
    local a = rad(-90 + 180 * k / K)
    local s = puff * (1 - math.cos(a))
    secs[#secs + 1] = {p=rounded_rect{w=w - 2 * s, h=h - 2 * s, radius=cr, segments=4}, at=v3(0, d / 2 * math.sin(a), 0)}
  end
  return loft(secs, {caps=true})
end
-- A pillow standing up: w wide (x), h high (y), d deep (z), centred at `at`.
local function pillow_up(w, h, d, puff, cr, at)
  local m = rotate(pillow(w, h, d, puff, cr), {angle=90, axis=axis_x(), pivot=origin()})
  return translate(m, at)
end

-- The tube ---------------------------------------------------------------------------------------------------------
local R = p.tube_radius
local LX = RIG.LX            -- each leg's centre line, x (the cushions' inner sides at 5.0)
local BASE_H = RIG.BASE_H    -- the cushions' height
local LEG_TOP = RIG.LEG_TOP  -- where the straight legs (and the chequer) end and the curve begins
local ARCH_B = RIG.ARCH_B    -- the curve's rise above LEG_TOP: a half ellipse LX across, ARCH_B high
local ROW = 0.3           -- the chequer's rows, up the legs
local AROUND = 24

-- The centre line: up the left leg, over the half ellipse by arc length, down the right leg.
local pts, radii, seams = {}, {}, {}
local leg = {0.4}
for y = BASE_H, LEG_TOP + 1e-6, ROW do leg[#leg + 1] = y end
for _, y in ipairs(leg) do pts[#pts + 1] = v3(-LX, y, 0); radii[#radii + 1] = R end
seams[#seams + 1] = #pts
do
  local dense, cum = {}, {0}
  local N = 600
  for i = 0, N do
    local f = math.pi * (1 - i / N)
    dense[#dense + 1] = v3(LX * math.cos(f), LEG_TOP + ARCH_B * math.sin(f), 0)
    if i > 0 then cum[#cum + 1] = cum[#cum] + length(vsub(dense[#dense], dense[#dense - 1])) end
  end
  local total = cum[#cum]
  local k = 1
  local steps = p.segments * p.rings
  for s = 1, steps do
    local want = total * s / steps
    while cum[k + 1] < want and k < N do k = k + 1 end
    local t = (want - cum[k]) / (cum[k + 1] - cum[k])
    pts[#pts + 1] = lerp(dense[k], dense[k + 1], t)
    local u = (s % p.rings) / p.rings
    radii[#radii + 1] = R * (1 + p.bulge * math.sin(math.pi * u))
    if s % p.rings == 0 then seams[#seams + 1] = #pts end
  end
end
for i = #leg - 1, 1, -1 do pts[#pts + 1] = v3(LX, leg[i], 0); radii[#radii + 1] = R end

local body, frames = tube(pts, radii, AROUND, false, axis_z())
body = paint(body, NAVY)
-- The chequer up the straight legs: a cell two columns round and one row up.
body = paint_where(body, CREAM, function(c, nn)
  if c.y < BASE_H or c.y > LEG_TOP or math.abs(c.x) < LX - R * 1.5 then return false end
  local th = math.atan(c.z, math.abs(c.x) - LX)
  local col = math.floor((th + math.pi) / (2 * math.pi) * AROUND / 2)
  local row = math.floor((c.y - BASE_H) / ROW)
  return (col + row) % 2 == 0
end)
add(body)

-- Piping: a line along either face of the tube, and a ring round every seam.
local pipes = {}
for _, sgn in ipairs({-1, 1}) do
  local line = {}
  for i, q in ipairs(pts) do line[i] = v3(q.x, q.y, sgn * radii[i]) end
  pipes[#pipes + 1] = (tube(line, const(#line, 0.03), 6, false, axis_z()))
end
for _, i in ipairs(seams) do
  local q, fr = pts[i], frames[i]
  local ring = {}
  local rr = radii[i] + 0.005
  for j = 0, 39 do
    local th = 2 * math.pi * j / 40
    ring[#ring + 1] = vadd(q, vadd(vmul(fr[1], math.cos(th) * rr), vmul(fr[2], math.sin(th) * rr)))
  end
  local t = normalize(cross(fr[1], fr[2]))
  pipes[#pipes + 1] = (tube(ring, const(#ring, 0.032), 6, true, t))
end
for _, m in ipairs(pipes) do add(paint(m, ORANGE)) end

-- The cushions under the legs, piped round their top and bottom edges.
for _, sx in ipairs({-1, 1}) do
  add(paint(translate(pillow(1.6, 1.6, BASE_H, 0.12, 0.22), v3(sx * LX, BASE_H / 2, 0)), NAVY))
  for _, y in ipairs({0.1, BASE_H - 0.1}) do
    local loop = rr_outline(1.6 - 0.07, 1.6 - 0.07, 0.2, 4, function(u, v) return v3(sx * LX + u, y, v) end)
    add(paint((tube(loop, const(#loop, 0.03), 6, true, axis_y())), ORANGE))
  end
end

-- Lettering ---------------------------------------------------------------------------------------------------------
-- Block capitals, each a set of rects on a grid {x0, y0, x1, y1}, its width in cells.
local GLYPH = {
  S = {3, {{0,4,3,5},{0,3,1,4},{0,2,3,3},{2,1,3,2},{0,0,3,1}}},
  O = {3, {{0,0,1,5},{2,0,3,5},{1,0,2,1},{1,4,2,5}}},
  A = {3, {{0,4,3,5},{0,0,1,4},{2,0,3,4},{1,2,2,3}}},
  P = {3, {{0,0,1,5},{1,4,3,5},{2,2,3,4},{1,2,2,3}}},
  B = {3, {{0,0,1,5},{1,4,2,5},{1,2,2,3},{1,0,2,1},{2,3,3,4},{2,1,3,2}}},
  X = {3, {{0,0,1,2},{2,0,3,2},{1,2,2,3},{0,3,1,5},{2,3,3,5}}},
  M = {5, {{0,0,1,5},{4,0,5,5},{1,3,2,4},{3,3,4,4},{2,2,3,3}}},
  Y = {3, {{0,3,1,5},{2,3,3,5},{0,2,3,3},{1,0,2,2}}},
  H = {3, {{0,0,1,5},{2,0,3,5},{1,2,2,3}}},
  E = {3, {{0,0,1,5},{1,4,3,5},{1,2,2.5,3},{1,0,3,1}}},
  T = {3, {{0,4,3,5},{1,0,2,4}}},
  R = {3, {{0,0,1,5},{1,4,2,5},{2,3,3,4},{1,2,2,3},{2,0,3,2}}},
  [">"] = {4, {{0,4,2,5},{1,3,3,4},{2,2,4,3},{1,1,3,2},{0,0,2,1}}},
  ["<"] = {4, {{2,4,4,5},{1,3,3,4},{0,2,2,3},{1,1,3,2},{2,0,4,1}}},
  [" "] = {1, {}},
}
local function text_width(s)
  local w = -1
  for ch in s:gmatch(".") do w = w + GLYPH[ch][1] + 1 end
  return w
end
-- Lays `s` on both faces of a board: centred on x = 0, its baseline at y0, cells `cell` metres, the faces at z = +-zf.
-- Each rect in `fill`, on a plate `rim` wider each way in `edge` behind it (no plate when edge is nil); chevrons in
-- `chev`. Read the right way round from either side.
local function lettering(s, cell, y0, zf, fill, edge, rim, chev)
  local fills, edges, chevs = {}, {}, {}
  local u0 = -text_width(s) * cell / 2
  for _, side in ipairs({-1, 1}) do
    -- From -z the viewer's right is -x; from +z it is +x.
    local dir = (side == -1) and -1 or 1
    local cx = 0
    for ch in s:gmatch(".") do
      local g = GLYPH[ch]
      local into = (ch == ">" or ch == "<") and chevs or fills
      for _, r in ipairs(g[2]) do
        local w, h = (r[3] - r[1]) * cell, (r[4] - r[2]) * cell
        local x = dir * (u0 + (cx + (r[1] + r[3]) / 2) * cell)
        local y = y0 + (r[2] + r[4]) / 2 * cell
        into[#into + 1] = bx(w - 0.004, h - 0.004, 0.04, x, y, side * (zf + 0.05))
        if edge then edges[#edges + 1] = bx(w + 2 * rim, h + 2 * rim, 0.05, x, y, side * (zf + 0.015)) end
      end
      cx = cx + g[1] + 1
    end
  end
  for _, m in ipairs(fills) do add(paint(m, fill)) end
  for _, m in ipairs(chevs) do add(paint(m, chev)) end
  for _, m in ipairs(edges) do add(paint(m, edge)) end
end

-- The sign ------------------------------------------------------------------------------------------------------------
local SIGN_W, SIGN_H, SIGN_D = 5.2, 1.7, 1.3
local SIGN_Y = RIG.SIGN_Y
add(paint(pillow_up(SIGN_W, SIGN_H, SIGN_D, 0.15, 0.3, v3(0, SIGN_Y, 0)), ORANGE))
do
  local seam = rr_outline(SIGN_W - 0.02, SIGN_H - 0.02, 0.3, 4, function(u, v) return v3(u, SIGN_Y + v, 0) end)
  add(paint((tube(seam, const(#seam, 0.035), 6, true, axis_z())), CREAM))
end
lettering("SOAP BOX", 0.1, 6.25, SIGN_D / 2, CREAM, DARK, 0.035)
lettering("MAYHEM", 0.13, 5.5, SIGN_D / 2, CREAM, DARK, 0.04)

-- Chequered flags at the sign's top corners, on poles leaning out.
for _, sx in ipairs({-1, 1}) do
  local a = v3(sx * (SIGN_W / 2 - 0.15), SIGN_Y + 0.5, 0)
  local b = v3(sx * (SIGN_W / 2 + 0.3), SIGN_Y + 0.95, 0)
  add(paint((tube({a, b}, {0.025, 0.025}, 8, false, axis_z())), WHITE))
  local cells = {{}, {}}
  local C = 0.11
  for i = 0, 3 do
    for j = 0, 2 do
      local x = b.x + sx * (0.02 + (i + 0.5) * C)
      local y = b.y - (j + 0.5) * C
      local t = cells[(i + j) % 2 + 1]
      t[#t + 1] = bx(C - 0.003, C - 0.003, 0.025, x, y, 0)
    end
  end
  for _, m in ipairs(cells[1]) do add(paint(m, DARK)) end
  for _, m in ipairs(cells[2]) do add(paint(m, WHITE)) end
end

-- The START banner over the sign's foot, chevrons pointing in at it.
local BAN_Y, BAN_H, BAN_D = 5.135, 0.55, 1.4
add(paint(pillow_up(3.6, BAN_H, BAN_D, 0.08, 0.15, v3(0, BAN_Y, 0)), CREAM))
lettering(">> START <<", 0.07, BAN_Y - 2.5 * 0.07, BAN_D / 2, ORANGE, DARK, 0.022, ORANGE)

-- The start lights: three amber lamps on either face of a dark housing hung under the banner.
local LY = RIG.LY
add(paint(pillow_up(1.7, 0.36, 1.0, 0.04, 0.08, v3(0, LY, 0)), HOUSING))
for _, side in ipairs({-1, 1}) do
  for _, x in ipairs(RIG.LAMP_X) do
    add(paint(translate(cylinder{radius=0.17, height=0.03, segments=24, axis="z"}, v3(x, LY, side * 0.505)), DARK))
    add(paint(translate(cylinder{radius=0.14, height=0.03, segments=24, axis="z"}, v3(x, LY, side * 0.525)), AMBER))
    add(paint(translate(cylinder{radius=0.055, height=0.01, segments=12, axis="z"}, v3(x + 0.035, LY + 0.035, side * 0.542)), AMBER_HI))
  end
end

-- One mesh, each piece keeping its colours (join would drop them).
local parts = {}
for _, m in ipairs(pieces) do parts[#parts + 1] = {mesh=smooth_normals(m, {angle=50}), material=PAINT} end
local whole = merge({parts=parts})[1].mesh

-- The wobble -----------------------------------------------------------------------------------------------------------
-- An inflatable never stands still: a skeleton up each leg and round each half of the curve, the sign on a joint of its
-- own, the mesh bound softly across them (wide envelopes, so the tube bends rather than hinges). Its clip `wobble`
-- sways the whole arch side to side and to and fro on its cushions, the curve bending a little after the legs and the
-- sign bobbing after the curve -- out of step, as air sloshes.
local skel = RIG.skeleton()
local envs = {
  envelope{joint="Root", radius=0.5},
  envelope{joint="Crown", radius=1.6},
  envelope{joint="LLeg", radius=1.1}, envelope{joint="RLeg", radius=1.1},
  envelope{joint="LCurve", radius=1.2}, envelope{joint="RCurve", radius=1.2},
}
-- Held whole: the cushions on the ground, and the sign, its banner, flags and lights on the Crown.
local regions = {
  region{joint="Root", min=v3(-20, -1, -3), max=v3(20, BASE_H + 0.02, 3), weight=1},
  -- (the sign and its flags; the banner and the lights inside the middle of it -- the tube either side
  -- left to bend)
  region{joint="Crown", min=v3(-4, SIGN_Y - SIGN_H / 2 - 0.03, -1), max=v3(4, 8, 1), weight=1},
  region{joint="Crown", min=v3(-1.9, LY - 0.25, -0.75), max=v3(1.9, 8, 0.75), weight=1},
}
emit(bind(whole, skel, {method="envelope", envelopes=envs, regions=regions}), {name="arch", material=PAINT})

RIG.wobble(skel, p.sway, p.period)
