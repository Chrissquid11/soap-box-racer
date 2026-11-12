-- The pinball course's scenery kit (see THEME KITS in _course.lua): the karts are ball-sized on a giant playfield.
-- The ground is the playfield's artwork (a sunburst of blues, magenta rings, medallions, a yellow lane line), flatter
-- than a valley; on it pop bumpers, slingshots, drop targets, spinners, bells, rollover lanes, lit inserts (round,
-- arrows, stars), two giant flippers before the finish, chrome wire ramps overhead, a giant steel ball; round it the
-- wooden cabinet, and at the top the backbox with its backglass and score display.
local T = {trees = 0}

-- The playfield's art, a valley cell (some metres square) at a time.
local PC
function T.paint(x, z, off, ink, TK)
  if not PC then
    PC = {navy = TK.col(0.02, 0.04, 0.3), blue = TK.col(0.03, 0.14, 0.75), sky = TK.col(0.06, 0.4, 0.95),
      mag = TK.col(0.85, 0.04, 0.5), purple = TK.col(0.32, 0.05, 0.6), yel = TK.col(1, 0.76, 0.04),
      white = TK.col(0.92, 0.92, 0.96), orange = TK.col(1, 0.36, 0.03)}
  end
  if off < 10.5 then return PC.navy end
  if off < 16.5 then return PC.yel end
  if off < 22.5 then return PC.mag end
  -- medallions, one a big square of the field
  local G = 96
  local gx, gz = math.floor(x / G), math.floor(z / G)
  local cx, cz = (gx + 0.5) * G + (TK.hash(gx, gz) - 0.5) * 30, (gz + 0.5) * G + (TK.hash(gz, gx + 7) - 0.5) * 30
  local r = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2)
  if r < 8 then return PC.yel elseif r < 16 then return PC.orange elseif r < 23 then return PC.white elseif r < 31 then return PC.purple end
  -- the sunburst from behind the backbox, and rings round it
  local ox, oz = -220, -40
  local rr = math.sqrt((x - ox) ^ 2 + (z - oz) ^ 2)
  local m = rr % 120
  if m < 9 then return PC.mag elseif m < 15 then return PC.white end
  local a = math.atan(z - oz, x - ox)
  return (math.floor(a / 0.075) % 2 == 0) and PC.blue or PC.sky
end

-- A playfield, not a valley: beyond the verge the ground rises only gently, and without the hills' ripples.
function T.shape(x, z, off, y, road_y, TK)
  if off <= 8 then return nil end
  local t = math.min(1, (off - 8) / 10)
  local target = road_y - 0.5 + 1.74 + math.min((off - 8) * 0.1, 9)
  return y + (target - y) * t
end

function T.build(K)
  local Y = v3(0, 1, 0)
  local pi = math.pi
  local function rnd(a, b) return K.g:range(a, b) end
  local N, pos, right, W = K.N, K.pos, K.right, K.W
  local EDGE = K.WALL_T + 1

  local function tris(b)
    local n = 0
    for _, f in ipairs(b.fs) do n = n + #f - 2 end
    for _, q in ipairs(b.more or {}) do for _, f in ipairs(q.fs) do n = n + #f - 2 end end
    return n
  end
  local before = tris(K.solid) + tris(K.deco)

  local function unit(v)
    local l = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    return v3(v.x / l, v.y / l, v.z / l)
  end

  -- Colours.
  local RED, YELLOW, CYAN = K.col(0.9, 0.05, 0.05), K.col(1, 0.8, 0.05), K.col(0.05, 0.75, 0.95)
  local MAGENTA, ORANGE, GREEN = K.col(0.95, 0.08, 0.6), K.col(1, 0.42, 0.03), K.col(0.1, 0.85, 0.2)
  local WHITE, BLACK, DARK = K.col(0.95, 0.95, 0.95), K.col(0.03, 0.03, 0.04), K.col(0.1, 0.1, 0.13)
  local BLUE, PURPLE = K.col(0.08, 0.2, 0.9), K.col(0.4, 0.08, 0.7)
  local CHROME, CHROME_DK, CHROME_HI = K.col(0.78, 0.82, 0.88), K.col(0.42, 0.46, 0.54), K.col(0.96, 0.98, 1)
  local GOLD, GOLD_DK, GOLD_HI = K.col(0.95, 0.66, 0.1), K.col(0.6, 0.38, 0.05), K.col(1, 0.86, 0.35)
  local WOOD, WOOD2, WOOD_DK = K.col(0.5, 0.26, 0.09), K.col(0.42, 0.21, 0.07), K.col(0.25, 0.12, 0.04)
  local BRIGHT = {RED, YELLOW, CYAN, MAGENTA, ORANGE, GREEN}
  local LIGHTS = {YELLOW, ORANGE, RED, GREEN, CYAN, MAGENTA, WHITE}

  -- Where things may stand.
  local function off_road(x, z)
    local _, d = K.ground_d(x, z)
    return d - K.HW
  end
  local function clear(x, z, r) return off_road(x, z) > EDGE + r + 0.3 end
  local function inside(x, z, m) return x > K.X0 + m and x < K.X1 - m and z > K.Z1 + m and z < K.Z0 - m end
  local big, CELL = {}, 24
  local function free(x, z, r)
    local list = big[math.floor(x / CELL) * 4096 + math.floor(z / CELL)]
    if not list then return true end
    for _, e in ipairs(list) do
      local dx, dz = x - e[1], z - e[2]
      local rr = e[3] + r
      if dx * dx + dz * dz < rr * rr then return false end
    end
    return true
  end
  local function take(x, z, r)
    local e = {x, z, r}
    local m = r + 12
    for gx = math.floor((x - m) / CELL), math.floor((x + m) / CELL) do
      for gz = math.floor((z - m) / CELL), math.floor((z + m) / CELL) do
        local key = gx * 4096 + gz
        big[key] = big[key] or {}
        big[key][#big[key] + 1] = e
      end
    end
  end
  local function at_off(i, side, o) return pos[i] + right[i] * (side * (W[i] + o)) end
  local function near(lo, hi, r)
    for _ = 1, 4 do
      local i = math.max(1, math.min(N, math.floor(rnd(1, N + 1))))
      local s = (rnd(0, 1) < 0.5) and -1 or 1
      local p = at_off(i, s, EDGE + r + lo + (hi - lo) * rnd(0, 1) ^ 1.5)
      if inside(p.x, p.z, 4) and free(p.x, p.z, r) and clear(p.x, p.z, r) then return p.x, p.z end
    end
    return nil
  end

  -- The ground as built (the valley's grid, the higher of the two ways a cell may be cut): what lies flat on it.
  local STEP
  do
    local x0, x1, z0, z1 = math.huge, -math.huge, -math.huge, math.huge
    for i = 1, N do
      local p = pos[i]
      x0 = math.min(x0, p.x); x1 = math.max(x1, p.x); z1 = math.min(z1, p.z); z0 = math.max(z0, p.z)
    end
    STEP = math.max(5, math.ceil(math.sqrt((x1 - x0 + 140) * (z0 - z1 + 140) / 9000)))
  end
  local hts = {}
  local function node(c, r)
    local k = r * 4096 + c
    local y = hts[k]
    if not y then y = K.ground(K.X0 + c * STEP, K.Z0 - r * STEP); hts[k] = y end
    return y
  end
  local function gh(x, z)
    local fx, fz = (x - K.X0) / STEP, (K.Z0 - z) / STEP
    local c, r = math.floor(fx), math.floor(fz)
    local tx, tz = fx - c, fz - r
    local y00, y10, y01, y11 = node(c, r), node(c + 1, r), node(c, r + 1), node(c + 1, r + 1)
    local A = (tx > tz) and (y00 + (y10 - y00) * tx + (y11 - y10) * tz) or (y00 + (y01 - y00) * tz + (y11 - y01) * tx)
    local B = (tx + tz < 1) and (y00 + (y10 - y00) * tx + (y01 - y00) * tz) or (y11 + (y01 - y11) * (1 - tx) + (y10 - y11) * (1 - tz))
    return math.max(A, B)
  end

  -- Shapes, each in its colour's piece of b.
  local function box(b, colour, c, r, t, w, h, d)
    local q = K.sub(b, colour)
    q.ink = colour
    K.road_box(q, c, r, t, w, h, d)
  end
  local function cyl(b, colour, x, z, y0, y1, r0, r1, n, turn)
    K.column(K.sub(b, colour), x, z, y0, y1, r0, r1 or r0, n or 8, colour, turn)
  end
  -- A bar of rectangular section (hw across, hh up) through pts.
  local function sweep(b, colour, pts, hw, hh)
    local rings = {}
    for j, p in ipairs(pts) do
      local d = unit(pts[math.min(#pts, j + 1)] - pts[math.max(1, j - 1)])
      local s = v3(d.z, 0, -d.x)
      local sl = math.sqrt(s.x * s.x + s.z * s.z)
      if sl < 1e-4 then s = v3(1, 0, 0) else s = s * (1 / sl) end
      local up = v3(d.y * s.z - d.z * s.y, d.z * s.x - d.x * s.z, d.x * s.y - d.y * s.x)
      rings[j] = {p + s * hw + up * hh, p - s * hw + up * hh, p - s * hw - up * hh, p + s * hw - up * hh}
    end
    K.prism(K.sub(b, colour), rings, K.flat(colour), colour, colour)
  end
  -- A low dome lying on the ground: a ring's fan up to `tip` and its fan down to `under` (a closed shell).
  local function fan(b, colour, ring, tip, under)
    local base = #b.vs
    local n = #ring
    for k = 1, n do b.vs[base + k] = ring[k] end
    b.vs[base + n + 1], b.vs[base + n + 2] = tip, under
    local function tri(i1, i2, i3, up)
      local a, bb, c = b.vs[i1], b.vs[i2], b.vs[i3]
      local ny = (bb.z - a.z) * (c.x - a.x) - (bb.x - a.x) * (c.z - a.z)
      if (ny < 0) == up then b.fs[#b.fs + 1] = {i3, i2, i1} else b.fs[#b.fs + 1] = {i1, i2, i3} end
      b.cs[#b.fs] = colour
    end
    for k = 1, n do
      local k2 = k % n + 1
      tri(base + k, base + k2, base + n + 1, true)
      tri(base + k, base + k2, base + n + 2, false)
    end
  end
  -- A lit insert: `shape` a list of {dx, dz} round (x, z), draped on the ground `lift` over it, domed by `dome`.
  local function insert(colour, x, z, shape, lift, dome)
    local ring, sum = {}, 0
    local lo, hi = math.huge, -math.huge
    for k, d in ipairs(shape) do
      local px, pz = x + d[1], z + d[2]
      local y = gh(px, pz) + lift
      ring[k] = v3(px, y, pz)
      sum = sum + y
      lo, hi = math.min(lo, y), math.max(hi, y)
    end
    -- (not draped over a step in the playfield)
    if hi - lo > 1.8 or math.abs(gh(x, z) + lift - sum / #shape) > 0.8 then return end
    local yc = math.max(gh(x, z) + lift, sum / #shape)
    fan(K.sub(K.deco, colour), colour, ring, v3(x, yc + dome, z), v3(x, yc - 0.7 - lift, z))
  end
  local function circle(r, n, turn)
    local out = {}
    for k = 1, n do
      local a = (turn or 0) + k / n * 2 * pi
      out[k] = {math.cos(a) * r, math.sin(a) * r}
    end
    return out
  end
  local function star(r, turn)
    local out = {}
    for k = 1, 10 do
      local a = (turn or 0) + k / 10 * 2 * pi
      local rr = (k % 2 == 0) and r or r * 0.42
      out[k] = {math.cos(a) * rr, math.sin(a) * rr}
    end
    return out
  end
  local function round_light(x, z, r, colour)
    insert(WHITE, x, z, circle(r * 1.25, 10), 0.06, 0.16)
    insert(colour, x, z, circle(r, 10, 0.3), 0.2, 0.36)
  end
  local function star_light(x, z, r, colour, turn)
    insert(colour, x, z, star(r, turn), 0.1, 0.3)
    insert(WHITE, x, z, circle(r * 0.3, 6), 0.3, 0.3)
  end

  -- A pop bumper: a white skirt and striped body under a wide coloured cap, a chrome ring round its waist.
  local nb = 0
  local function bumper(x, z, s, ci)
    nb = nb + 1
    local cap = BRIGHT[(ci - 1) % #BRIGHT + 1]
    local y = K.ground(x, z)
    cyl(K.solid, WHITE, x, z, y - 1.5 - s, y + 0.5 * s, 2.2 * s, 2.0 * s, 12)
    K.prism(K.sub(K.solid, "bumper body" .. ci % #BRIGHT), {K.ring(v3(x, y + 0.3 * s, z), 1.5 * s, 1.5 * s, 12, 0.1), K.ring(v3(x, y + 2.5 * s, z), 1.5 * s, 1.5 * s, 12, 0.1)},
      function(_, k) return (k % 2 == 0) and WHITE or cap end, WHITE, WHITE)
    cyl(K.solid, CHROME, x, z, y + 0.95 * s, y + 1.2 * s, 2.5 * s, 2.5 * s, 12, 0.2)
    local lo, hi = K.tint(cap, 0.6), K.mix(cap, WHITE, 0.35)
    K.prism(K.sub(K.solid, "bumper cap" .. ci % #BRIGHT), {K.ring(v3(x, y + 2.3 * s, z), 2.7 * s, 2.7 * s, 12, 0), K.ring(v3(x, y + 2.8 * s, z), 2.7 * s, 2.7 * s, 12, 0),
      K.ring(v3(x, y + 3.25 * s, z), 1.8 * s, 1.8 * s, 12, 0)}, function(j, _) return (j == 1) and cap or hi end, lo, WHITE)
    cyl(K.solid, cap, x, z, y + 3.1 * s, y + 3.45 * s, 0.9 * s, 0.75 * s, 8, 0.3)
    take(x, z, 2.8 * s)
  end

  -- The giant flippers before the finish, one a side, their tips at the road like a table's over its drain.
  local FLIP = math.max(K.start + 30, K.fin - 16)
  local function flipper(i, side)
    local u, w = K.along(i), right[i] * side
    local R1, R2 = 3.4, 1.5
    local pivot = at_off(i, side, 21) - u * 5
    local tip, dir, perp
    local pts
    for o = EDGE + R2 + 0.5, 12, 1 do
      tip = at_off(i, side, o) + u * 4
      dir = unit(v3(tip.x - pivot.x, 0, tip.z - pivot.z))
      perp = v3(dir.z, 0, -dir.x)
      pts = {}
      for k = 0, 6 do
        local a = pi / 2 + k / 6 * pi
        pts[#pts + 1] = {pivot.x + (dir.x * math.cos(a) + perp.x * math.sin(a)) * R1, pivot.z + (dir.z * math.cos(a) + perp.z * math.sin(a)) * R1, pivot, R1, a}
      end
      for k = 0, 4 do
        local a = -pi / 2 + k / 4 * pi
        pts[#pts + 1] = {tip.x + (dir.x * math.cos(a) + perp.x * math.sin(a)) * R2, tip.z + (dir.z * math.cos(a) + perp.z * math.sin(a)) * R2, tip, R2, a}
      end
      local ok = true
      for _, p in ipairs(pts) do if off_road(p[1], p[2]) < EDGE + 0.4 then ok = false end end
      for f = 0.5, 0.95, 0.15 do
        local m = pivot + (tip - pivot) * f
        if off_road(m.x, m.z) < EDGE + R2 + 0.6 then ok = false end
      end
      if ok then break end
      pts = nil
    end
    if not pts then return end
    local top = -math.huge
    local r0, r1, r2, r3 = {}, {}, {}, {}
    for _, p in ipairs(pts) do top = math.max(top, K.ground(p[1], p[2])) end
    top = top + 3.2
    for k, p in ipairs(pts) do
      r0[k] = v3(p[1], K.ground(p[1], p[2]) - 1.5, p[2])
      r1[k] = v3(p[1], top, p[2])
      local c, rr = p[3], p[4] - 0.55
      local x, z = c.x + (dir.x * math.cos(p[5]) + perp.x * math.sin(p[5])) * rr, c.z + (dir.z * math.cos(p[5]) + perp.z * math.sin(p[5])) * rr
      r2[k] = v3(x, top - 0.5, z)
      r3[k] = v3(x, top + 0.45, z)
    end
    K.prism(K.sub(K.solid, RED), {r0, r1}, K.flat(RED), RED, RED)
    K.prism(K.sub(K.solid, WHITE), {r2, r3}, K.flat(WHITE), WHITE, WHITE)
    cyl(K.solid, CHROME, pivot.x, pivot.z, top + 0.2, top + 1.1, 1.5, 1.3, 10)
    cyl(K.solid, YELLOW, pivot.x, pivot.z, top + 0.9, top + 1.3, 0.8, 0.7, 8, 0.3)
    for f = 0, 1, 0.2 do
      local m = pivot + (tip - pivot) * f
      take(m.x, m.z, R1 + 0.5)
    end
  end
  flipper(FLIP, -1)
  flipper(FLIP, 1)

  -- The steel ball: chrome, the sky on its top and the playfield on its underside.
  local STEEL = {K.col(0.97, 0.98, 1), K.col(0.72, 0.78, 0.88), K.col(0.5, 0.56, 0.68), K.col(0.16, 0.18, 0.27), K.col(0.5, 0.18, 0.5), K.col(0.16, 0.22, 0.6)}
  local function steel(d)
    local l = math.sqrt(d.x * d.x + d.y * d.y + d.z * d.z)
    local ny = d.y / l
    if (d.x * 0.45 + d.y * 0.8 - d.z * 0.4) / l > 0.93 then return STEEL[1] end
    if ny > 0.8 then return STEEL[2] elseif ny > 0.45 then return STEEL[1] elseif ny > 0.12 then return STEEL[3]
    elseif ny > -0.15 then return STEEL[4] elseif ny > -0.55 then return STEEL[5] end
    return STEEL[6]
  end
  local function one() return 1 end
  local balls = 0
  local function steel_ball(x, z, R, segs, rings)
    K.ball(K.sub(K.solid, "steel" .. balls), v3(x, K.ground(x, z) + R * 0.94, z), R, R, R, segs, rings, one, steel)
    balls = balls + 1
    take(x, z, R + 1)
  end
  for _, try in ipairs({{0.5, 1, 27, 11}, {0.5, -1, 27, 11}, {0.4, 1, 27, 11}, {0.6, -1, 27, 11}, {0.3, 1, 24, 10}, {0.7, 1, 24, 10}}) do
    local i = math.floor(N * try[1])
    local p = at_off(i, try[2], try[3])
    if balls == 0 and off_road(p.x, p.z) > try[3] - 5 and inside(p.x, p.z, 14) and free(p.x, p.z, try[4] + 2) then
      steel_ball(p.x, p.z, try[4], 18, 12)
    end
  end

  -- Chrome wire ramps: two rails on posts, rising from the playfield, over the road high up and down again, a
  -- coloured plastic chute at either end.
  local ramps = 0
  local function wire(i0, i1, s0, s1, plastic)
    local C, G = {}, {}
    for i = i0, i1, 2 do
      local f = (i - i0) / (i1 - i0)
      local sm = f * f * (3 - 2 * f)
      local c = pos[i] + right[i] * (s0 + (s1 - s0) * sm)
      local e0, e1 = math.max(0, 1 - f / 0.2), math.max(0, (f - 0.8) / 0.2)
      local gy = K.ground(c.x, c.z)
      local y = pos[i].y + 12.5 + 2 * math.sin(f * pi)
      y = y - (y - gy - 0.9) * math.max(e0 * e0, e1 * e1)
      local o = off_road(c.x, c.z)
      if o < 4 and y - gy < 9.5 then return end
      if (e0 > 0 or e1 > 0) and o < EDGE + 3 then return end
      C[#C + 1] = {p = v3(c.x, y, c.z), r = right[i], g = gy, o = o, e = math.max(e0, e1)}
    end
    if #C < 6 then return end
    ramps = ramps + 1
    local L, R = {}, {}
    for j, c in ipairs(C) do
      L[j], R[j] = c.p - c.r * 1.3, c.p + c.r * 1.3
      if c.e == 0 and j % 2 == 0 then
        sweep(K.deco, CHROME_DK, {L[j] + Y * 1.5, L[j] * 0.88 + R[j] * 0.12 - Y * 0.6, R[j] * 0.88 + L[j] * 0.12 - Y * 0.6, R[j] + Y * 1.5}, 0.13, 0.13)
      end
      if j % 3 == 2 and c.p.y - c.g > 2.5 and c.o > 6 and free(c.p.x, c.p.z, 0.8) then
        cyl(K.solid, CHROME_DK, c.p.x, c.p.z, c.g - 1.2, c.p.y - 0.75, 0.3, 0.24, 6)
        take(c.p.x, c.p.z, 0.7)
      end
    end
    sweep(K.deco, CHROME, L, 0.2, 0.2)
    sweep(K.deco, CHROME, R, 0.2, 0.2)
    local a, b = {}, {}
    for j, c in ipairs(C) do
      if c.e > 0 or (C[j + 1] and C[j + 1].e > 0 and j < #C / 2) or (C[j - 1] and C[j - 1].e > 0 and j > #C / 2) then
        local p = c.p - Y * 0.32
        if j < #C / 2 then a[#a + 1] = p else b[#b + 1] = p end
      end
    end
    if #a > 1 then sweep(K.deco, plastic, a, 1.25, 0.07) end
    if #b > 1 then sweep(K.deco, plastic, b, 1.25, 0.07) end
  end
  do
    local span = math.floor((N - K.start - 60) / 6)
    local far = K.HW + 22
    local plan = {{1, -1}, {-1, 1}, {1, 1}, {-1, 1}, {1, -1}, {-1, -1}}
    for k = 0, 5 do
      local i0 = K.start + 14 + k * span
      local i1 = math.min(N - 8, i0 + math.min(46, span + 8))
      if math.abs(i0 - FLIP) > 12 and math.abs(i1 - FLIP) > 12 then
        wire(i0, i1, plan[k + 1][1] * far, plan[k + 1][2] * far, ({CYAN, ORANGE, GREEN, MAGENTA, YELLOW, CYAN})[k + 1])
      end
    end
  end

  -- A slingshot: a triangle of posts with a rubber band round them under a bright plastic.
  local function sling(i, side)
    local u, w = K.along(i), right[i] * side
    local base = at_off(i, side, EDGE + 1.6)
    local A, B, C = base - u * 6, base + u * 6, base + w * 6.5 - u * 2
    local cen = (A + B + C) * (1 / 3)
    if not (free(cen.x, cen.z, 5) and inside(cen.x, cen.z, 8)) then return end
    for f = 0, 1, 0.25 do
      local m = A + (B - A) * f
      if off_road(m.x, m.z) < EDGE + 1.1 then return end
    end
    if off_road(C.x, C.z) < EDGE + 3 then return end
    local top = math.max(K.ground(A.x, A.z), K.ground(B.x, B.z), K.ground(C.x, C.z)) + 2.7
    if top - 2.7 - math.min(K.ground(A.x, A.z), K.ground(B.x, B.z), K.ground(C.x, C.z)) > 3.5 then return end
    local ci = math.floor(K.hash(i, side) * 6) + 1
    local plastic, art = BRIGHT[ci], BRIGHT[ci % 6 + 1]
    local ps = {A, B, C}
    for k, p in ipairs(ps) do
      cyl(K.solid, CHROME, p.x, p.z, K.ground(p.x, p.z) - 1.5, top, 0.5, 0.5, 8)
      cyl(K.solid, RED, p.x, p.z, top - 1.75, top - 0.9, 0.78, 0.78, 8, 0.2)
      local q = ps[k % 3 + 1]
      local d = unit(q - p)
      sweep(K.solid, WHITE, {v3(p.x, top - 1.32, p.z) + d * 0.3, v3(q.x, top - 1.32, q.z) - d * 0.3}, 0.2, 0.3)
    end
    local function tri3(f, y) return {v3(cen.x + (A.x - cen.x) * f, y, cen.z + (A.z - cen.z) * f), v3(cen.x + (B.x - cen.x) * f, y, cen.z + (B.z - cen.z) * f), v3(cen.x + (C.x - cen.x) * f, y, cen.z + (C.z - cen.z) * f)} end
    K.prism(K.sub(K.solid, plastic), {tri3(1.14, top - 0.2), tri3(1.14, top + 0.2)}, K.flat(plastic), plastic, plastic)
    K.prism(K.sub(K.solid, art), {tri3(0.6, top + 0.05), tri3(0.6, top + 0.4)}, K.flat(art), art, art)
    take(cen.x, cen.z, 5.5); take(A.x, A.z, 2); take(B.x, B.z, 2)
    return true
  end

  -- A bank of drop targets, turned to face the karts coming down: white slabs with a bright spot each.
  local function drops(i, side)
    local u, w = K.along(i), right[i] * side
    local rd = unit(w * 0.8 + u * 0.6)
    local fn = v3(rd.z, 0, -rd.x)
    if fn.x * u.x + fn.z * u.z > 0 then fn = fn * -1 end
    local n = 4
    local p0 = at_off(i, side, EDGE + 1.5)
    local p1 = p0 + rd * (n * 2.1 + 0.4)
    local mid = (p0 + p1) * 0.5
    if not (free(mid.x, mid.z, 5) and inside(mid.x, mid.z, 8)) then return end
    for _, p in ipairs({p0 + fn * 0.8, p0 - fn * 2, p1 + fn * 0.8, p1 - fn * 2, mid + fn * 0.8}) do
      if off_road(p.x, p.z) < EDGE + 0.4 then return end
    end
    local lo = math.min(K.ground(p0.x, p0.z), K.ground(p1.x, p1.z)) - 1
    local top = math.max(K.ground(p0.x, p0.z), K.ground(p1.x, p1.z)) + 2.8
    if top - lo > 7 then return end
    local colour = BRIGHT[math.floor(K.hash(i, side * 5) * 6) + 1]
    for k = 0, n - 1 do
      local c = p0 + rd * (k * 2.1 + 1.25)
      box(K.solid, WHITE, v3(c.x, (lo + top) / 2, c.z), rd, fn, 1.75, top - lo, 0.5)
      box(K.deco, colour, v3(c.x, top - 1.1, c.z) + fn * 0.27, rd, fn, 1.1, 1.1, 0.14)
      box(K.deco, WHITE, v3(c.x, top - 1.1, c.z) + fn * 0.33, rd, fn, 0.45, 0.45, 0.14)
    end
    box(K.solid, DARK, v3(mid.x, (lo + top - 1.6) / 2, mid.z) - fn * 1.05, rd, fn, n * 2.1 + 0.9, top - 1.6 - lo, 1.5)
    box(K.solid, colour, v3(mid.x, top - 1.55, mid.z) - fn * 1.05, rd, fn, n * 2.1 + 1.1, 0.25, 1.7)
    take(mid.x, mid.z, 5.2)
    return true
  end

  -- A spinner: a gate across the karts' way beside the road, its plate caught mid spin.
  local function spinner(i, side)
    local u, w = K.along(i), right[i] * side
    local a, b = at_off(i, side, EDGE + 1.3), at_off(i, side, EDGE + 6.3)
    local mid = (a + b) * 0.5
    if not (free(mid.x, mid.z, 3.4) and inside(mid.x, mid.z, 8)) then return end
    if off_road(a.x, a.z) < EDGE + 0.9 or off_road(b.x, b.z) < EDGE + 3 then return end
    local ga, gb = K.ground(a.x, a.z), K.ground(b.x, b.z)
    if math.abs(ga - gb) > 3 then return end
    local top = math.max(ga, gb) + 4.6
    cyl(K.solid, CHROME, a.x, a.z, ga - 1.2, top, 0.3, 0.3, 6)
    cyl(K.solid, CHROME, b.x, b.z, gb - 1.2, top, 0.3, 0.3, 6)
    sweep(K.solid, CHROME, {v3(a.x, top - 0.3, a.z) - w * 0.5, v3(b.x, top - 0.3, b.z) + w * 0.5}, 0.22, 0.22)
    local c = v3(mid.x, top - 2.2, mid.z)
    sweep(K.deco, CHROME_DK, {c - w * 2.3, c + w * 2.3}, 0.1, 0.1)
    local an = rnd(0.3, 2.8)
    local n = u * math.cos(an) + Y * math.sin(an)
    local v = u * (-math.sin(an)) + Y * math.cos(an)
    local ci = math.floor(K.hash(i, side * 9) * 6) + 1
    local q = K.sub(K.deco, BRIGHT[ci]); q.ink = BRIGHT[ci]
    K.slab(q, c - n * 0.07, c + n * 0.07, w * 1.9, v * 1.4)
    q = K.sub(K.deco, WHITE); q.ink = WHITE
    K.slab(q, c - n * 0.12, c + n * 0.12, w * 1.1, v * 0.7)
    take(mid.x, mid.z, 3.4)
    return true
  end

  -- A bell: a brass gong on a dark bracket, its striker beside it.
  local function bell(i, side)
    local p = at_off(i, side, EDGE + 3.6)
    if not (free(p.x, p.z, 3) and clear(p.x, p.z, 2.7) and inside(p.x, p.z, 8)) then return end
    local y = K.ground(p.x, p.z)
    cyl(K.solid, DARK, p.x, p.z, y - 1.5, y + 3.2, 0.7, 0.55, 6)
    local prof = {{2.7, 2.6}, {3.0, 2.7}, {3.9, 2.3}, {4.7, 1.5}, {5.1, 0.6}}
    local rings = {}
    for j, e in ipairs(prof) do rings[j] = K.ring(v3(p.x, y + e[1], p.z), e[2], e[2], 12, 0) end
    K.prism(K.sub(K.solid, "bell"), rings, function(j, k)
      if j == 1 then return GOLD_DK end
      return (k % 4 == 1) and GOLD_HI or ((k % 4 == 3) and GOLD_DK or GOLD)
    end, GOLD_DK, GOLD_HI)
    cyl(K.solid, CHROME, p.x, p.z, y + 5.0, y + 5.5, 0.4, 0.3, 6)
    local u = K.along(i)
    local s = p - u * 3.1
    if clear(s.x, s.z, 0.6) then
      cyl(K.solid, CHROME, s.x, s.z, K.ground(s.x, s.z) - 1, y + 3.3, 0.38, 0.38, 6)
      cyl(K.solid, RED, s.x, s.z, y + 3.1, y + 3.9, 0.6, 0.6, 8, 0.2)
    end
    take(p.x, p.z, 3.2)
    return true
  end

  -- Rollover lanes: wire guides side by side along the road, a light in each lane between them.
  local function lanes(i, side)
    local u = K.along(i)
    local c0, c3 = at_off(i, side, EDGE + 1.2), at_off(i, side, EDGE + 12)
    local mid = (c0 + c3) * 0.5
    if not (free(mid.x, mid.z, 7.5) and inside(mid.x, mid.z, 10)) then return end
    for _, p in ipairs({c0 - u * 4.8, c0, c0 + u * 4.8}) do
      if off_road(p.x, p.z) < EDGE + 0.6 then return end
    end
    if off_road(c3.x, c3.z) < EDGE + 9 then return end
    for k = 0, 3 do
      local c = at_off(i, side, EDGE + 1.2 + k * 3.6)
      local a, b = c - u * 4.6, c + u * 4.6
      local ya, yb = K.ground(a.x, a.z), K.ground(b.x, b.z)
      sweep(K.solid, CHROME, {v3(a.x, ya - 0.7, a.z), v3(a.x, ya + 1.2, a.z) + u * 0.4, v3(b.x, yb + 1.2, b.z) - u * 0.4, v3(b.x, yb - 0.7, b.z)}, 0.24, 0.24)
      if k < 3 then
        local m = at_off(i, side, EDGE + 3 + k * 3.6)
        round_light(m.x, m.z, 1.0, LIGHTS[(i + k) % 3 + 1])
        local m2 = m - u * 3.2
        star_light(m2.x, m2.z, 0.9, WHITE, k)
      end
    end
    take(mid.x, mid.z, 7.5)
    return true
  end

  -- Three pop bumpers in a nest, a star between them; or one right beside the road.
  local function trio(i, side)
    local c = at_off(i, side, EDGE + 9.5)
    if not (free(c.x, c.z, 8) and inside(c.x, c.z, 12)) then return end
    local a0, made = rnd(0, 6.3), 0
    for k = 0, 2 do
      local a = a0 + k * 2 * pi / 3
      local s = rnd(0.95, 1.25)
      local x, z = c.x + math.cos(a) * 5, c.z + math.sin(a) * 5
      if clear(x, z, 2.8 * s) and free(x, z, 2.8 * s) then bumper(x, z, s, nb + 1); made = made + 1 end
    end
    if made > 0 and clear(c.x, c.z, 1.6) then star_light(c.x, c.z, 1.6, YELLOW, a0) end
    take(c.x, c.z, 2)
    return made > 0
  end
  local function single(i, side)
    local s = rnd(1.15, 1.55)
    local p = at_off(i, side, EDGE + 2.8 * s + 0.5)
    if free(p.x, p.z, 2.8 * s) and clear(p.x, p.z, 2.8 * s) and inside(p.x, p.z, 8) then bumper(p.x, p.z, s, nb + 1); return true end
  end

  -- Down the road, both sides: one thing after another.
  local KINDS = {trio, sling, drops, spinner, bell, lanes, single, drops, sling, trio, spinner, single}
  local count = 0
  for i = 4, N - 5, 6 do
    for _, side in ipairs({-1, 1}) do
      if math.abs(i - K.start) > 5 and math.abs(i - K.fin) > 9 and math.abs(i - FLIP) > 9 then
        local k = math.floor(K.hash(i * 1.37, side * 2.3) * #KINDS)
        for try = 0, 2 do
          if KINDS[(k + try * 5) % #KINDS + 1](i, side) then count = count + 1; break end
        end
      end
    end
  end

  -- Out on the playfield: bigger bumpers, in nests and alone, and a couple of captive balls.
  for _ = 1, 70 do
    local x, z = K.spot(16)
    if x and inside(x, z, 14) then
      local s = rnd(1.5, 2.4)
      if free(x, z, 2.8 * s + 2) then bumper(x, z, s, nb + 1) end
    end
  end
  for _ = 1, 30 do
    local x, z = near(3, 20, 3.4)
    if x then bumper(x, z, rnd(1.0, 1.3), nb + 1) end
  end
  for _ = 1, 12 do
    local x, z = near(4, 22, 4.6)
    if x and balls < 3 then steel_ball(x, z, 4.2, 12, 8) end
  end

  -- The inserts: arrows in rows pointing down the road, round lights along it, and stars and big lights all over.
  local lights = 0
  for i = 6, N - 6, 4 do
    for _, side in ipairs({-1, 1}) do
      local h = K.hash(i * 0.77, side * 4.1)
      local u, w = K.along(i), right[i] * side
      if h < 0.3 then
        for k = 0, 2 do
          local c = at_off(i, side, EDGE + 2.6) + u * (k * 3.3)
          if free(c.x, c.z, 1.7) and clear(c.x, c.z, 1.6) then
            local colour = ({YELLOW, ORANGE, RED})[k + 1]
            insert(WHITE, c.x, c.z, {{u.x * 2.0, u.z * 2.0}, {-u.x * 1.5 + w.x * 1.7, -u.z * 1.5 + w.z * 1.7}, {-u.x * 1.5 - w.x * 1.7, -u.z * 1.5 - w.z * 1.7}}, 0.06, 0.12)
            insert(colour, c.x, c.z, {{u.x * 1.5, u.z * 1.5}, {-u.x * 1.2 + w.x * 1.25, -u.z * 1.2 + w.z * 1.25}, {-u.x * 1.2 - w.x * 1.25, -u.z * 1.2 - w.z * 1.25}}, 0.2, 0.28)
            take(c.x, c.z, 1.7)
            lights = lights + 1
          end
        end
      elseif h < 0.75 then
        local r = 0.9 + K.hash(i, side) * 0.8
        local c = at_off(i, side, EDGE + r * 1.3 + 0.4 + K.hash(side, i) * 4)
        if free(c.x, c.z, r * 1.3) and clear(c.x, c.z, r * 1.3) then
          round_light(c.x, c.z, r, LIGHTS[math.floor(h * 97) % #LIGHTS + 1])
          take(c.x, c.z, r * 1.3)
          lights = lights + 1
        end
      end
    end
  end
  for k = 1, 260 do
    local r = rnd(1.2, 2.4)
    local x, z = near(1, 30, r * 1.3)
    if x then
      if k % 4 == 0 then star_light(x, z, r * 1.3, (k % 8 == 0) and WHITE or YELLOW, rnd(0, 6))
      else round_light(x, z, r, LIGHTS[k % #LIGHTS + 1]) end
      take(x, z, r * 1.3)
      lights = lights + 1
    end
  end
  for k = 1, 260 do
    local x, z = K.spot(14)
    local r = rnd(2.6, 4.6)
    if x and inside(x, z, 8) and free(x, z, r * 1.3) then
      if k % 3 == 0 then star_light(x, z, r * 1.5, (k % 2 == 0) and YELLOW or WHITE, rnd(0, 6))
      else round_light(x, z, r, LIGHTS[k % #LIGHTS + 1]) end
      take(x, z, r * 1.3)
      lights = lights + 1
    end
  end
  -- A yellow lane line either side of the road.
  for _, side in ipairs({-1, 1}) do
    local run = {}
    local function flush()
      if #run > 2 then sweep(K.deco, YELLOW, run, 0.3, 0.1) end
      run = {}
    end
    for i = 2, N - 1 do
      local p = at_off(i, side, EDGE + 1.6)
      if off_road(p.x, p.z) > EDGE + 0.9 and free(p.x, p.z, 0.2) and (i % 12) < 9 then
        run[#run + 1] = v3(p.x, gh(p.x, p.z) + 0.06, p.z)
      else
        flush()
      end
    end
    flush()
  end

  -- The cabinet: wooden sides round the playfield, a black rail on top and a stripe of the art inside.
  local STRIPE = {MAGENTA, YELLOW, CYAN}
  local nseg = 0
  local function side_wall(ax, az, bx, bz, nx, nz, up)
    local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
    local n = math.max(1, math.floor(len / 24 + 0.5))
    local r, t = v3((bx - ax) / len, 0, (bz - az) / len), v3(nx, 0, nz)
    local seg = len / n
    for k = 0, n - 1 do
      nseg = nseg + 1
      local lo, hi = math.huge, -math.huge
      for f = 0, 1, 0.5 do
        local s = (k + f) * seg
        local x, z = ax + r.x * s - nx * 1.5, az + r.z * s - nz * 1.5
        x, z = math.max(K.X0 + 1, math.min(K.X1 - 1, x)), math.max(K.Z1 + 1, math.min(K.Z0 - 1, z))
        local y = K.ground(x, z)
        lo, hi = math.min(lo, y), math.max(hi, y)
      end
      local mx, mz = ax + r.x * (k + 0.5) * seg, az + r.z * (k + 0.5) * seg
      local y0, y1 = lo - 10, hi + up
      box(K.deco, (nseg % 2 == 0) and WOOD or WOOD2, v3(mx + nx * 4.2, (y0 + y1) / 2, mz + nz * 4.2), r, t, seg - 0.08, y1 - y0, 9)
      box(K.deco, BLACK, v3(mx + nx * 4.2, y1 + 0.4, mz + nz * 4.2), r, t, seg - 0.12, 1.6, 9.8)
      box(K.deco, STRIPE[nseg % 3 + 1], v3(mx - nx * 0.35, hi + up * 0.55, mz - nz * 0.35), r, t, seg - 0.2, up * 0.22, 0.5)
      box(K.deco, WOOD_DK, v3(mx - nx * 0.33, hi + up * 0.2, mz - nz * 0.33), r, t, seg - 0.3, 0.6, 0.4)
    end
  end
  side_wall(K.X0, K.Z0, K.X1, K.Z0, 0, 1, 15)
  side_wall(K.X0, K.Z1, K.X1, K.Z1, 0, -1, 15)
  side_wall(K.X1, K.Z1 + 0.2, K.X1, K.Z0 - 0.2, 1, 0, 9)
  side_wall(K.X0, K.Z1 + 0.2, K.X0, K.Z0 - 0.2, -1, 0, 15)

  -- The backbox, over the top end: a wooden box with a black face, the backglass (a sunburst, stars, a red
  -- dome) over the score display, lamps round its edge and a beacon on top.
  do
    local BW = math.min(300, (K.Z0 - K.Z1) * 0.7)
    local zc = math.max(K.Z1 + BW / 2 + 12, math.min(K.Z0 - BW / 2 - 12, pos[K.start].z - BW * 0.3))
    local lo, hi = math.huge, -math.huge
    for f = -0.5, 0.5, 0.125 do
      local y = K.ground(K.X0 + 1, zc + f * BW)
      lo, hi = math.min(lo, y), math.max(hi, y)
    end
    local RT, OUT = v3(0, 0, -1), v3(1, 0, 0)      -- the face's right (as read) and the way it looks
    local yb, H, D = hi + 17, 124, 40
    local xf = K.X0 - 9.6                           -- the face
    local top = yb + H
    box(K.deco, WOOD, v3(xf - D / 2, (lo - 10 + top) / 2, zc), RT, OUT, BW, top - lo + 10, D)
    box(K.deco, WOOD_DK, v3(xf - D / 2, top + 1, zc), RT, OUT, BW + 5, 2.4, D + 5)
    box(K.deco, BLACK, v3(xf + 0.5, yb + H / 2, zc), RT, OUT, BW - 5, H - 5, 1.2)
    -- the backglass
    local gy0, gy1 = yb + 46, top - 9
    local gcy = (gy0 + gy1) / 2
    box(K.deco, PURPLE, v3(xf + 1.3, gcy, zc), RT, OUT, BW - 22, gy1 - gy0, 1)
    box(K.deco, MAGENTA, v3(xf + 1.5, gy0 + 3.5, zc), RT, OUT, BW - 30, 3, 1)
    box(K.deco, CYAN, v3(xf + 1.5, gy1 - 3.5, zc), RT, OUT, BW - 30, 3, 1)
    local function vprism(colour, pts, x0, x1)
      local a, b = {}, {}
      for k, p in ipairs(pts) do a[k], b[k] = v3(x0, p[1], p[2]), v3(x1, p[1], p[2]) end
      K.prism(K.sub(K.deco, colour), {a, b}, K.flat(colour), colour, colour)
    end
    local RR = (gy1 - gy0) / 2 - 8
    for k = 0, 15 do
      local a = k / 16 * 2 * pi + 0.1
      local d = 0.11
      vprism((k % 2 == 0) and YELLOW or ORANGE, {
        {gcy + math.sin(a - d * 0.5) * RR * 0.3, zc + math.cos(a - d * 0.5) * RR * 0.3}, {gcy + math.sin(a + d * 0.5) * RR * 0.3, zc + math.cos(a + d * 0.5) * RR * 0.3},
        {gcy + math.sin(a + d) * RR, zc + math.cos(a + d) * RR}, {gcy + math.sin(a - d) * RR, zc + math.cos(a - d) * RR}}, xf + 1.6, xf + 2.3)
    end
    local function vstar(colour, cy, cz, r, x0, x1, turn)
      local pts = {}
      for k = 1, 10 do
        local a = turn + k / 10 * 2 * pi
        local rr = (k % 2 == 0) and r or r * 0.42
        pts[k] = {cy + math.cos(a) * rr, cz + math.sin(a) * rr}
      end
      vprism(colour, pts, x0, x1)
    end
    local function vdisc(colour, cy, cz, r, x0, x1, n)
      local pts = {}
      for k = 1, n do pts[k] = {cy + math.cos(k / n * 2 * pi) * r, cz + math.sin(k / n * 2 * pi) * r} end
      vprism(colour, pts, x0, x1)
    end
    vstar(YELLOW, gcy, zc, RR * 0.62, xf + 2.0, xf + 3.4, 0)
    vdisc(RED, gcy, zc, RR * 0.26, xf + 2.6, xf + 4.4, 14)
    vdisc(WHITE, gcy + RR * 0.08, zc + RR * 0.08, RR * 0.08, xf + 3.2, xf + 4.8, 8)
    for _, s in ipairs({-1, 1}) do
      vstar(CYAN, gcy + 6, zc + s * BW * 0.3, RR * 0.55, xf + 1.7, xf + 2.8, 0.3)
      vdisc(MAGENTA, gcy + 6, zc + s * BW * 0.3, RR * 0.2, xf + 2.2, xf + 3.4, 12)
      vstar(WHITE, gcy - RR * 0.55, zc + s * BW * 0.17, RR * 0.22, xf + 1.7, xf + 2.6, 0.9)
      vstar(WHITE, gcy + RR * 0.6, zc + s * BW * 0.16, RR * 0.16, xf + 1.7, xf + 2.6, 0.5)
      vdisc(ORANGE, gcy - RR * 0.5, zc + s * BW * 0.41, RR * 0.2, xf + 1.7, xf + 2.6, 12)
    end
    -- the score display: seven-segment digits, lit orange
    local dy0, dy1 = yb + 7, yb + 40
    box(K.deco, K.col(0.07, 0.02, 0.01), v3(xf + 1.3, (dy0 + dy1) / 2, zc), RT, OUT, BW - 30, dy1 - dy0, 1)
    local SEG = {["0"] = "abcdef", ["1"] = "bc", ["2"] = "abged", ["3"] = "abgcd", ["4"] = "fgbc", ["5"] = "afgcd", ["6"] = "afgedc", ["7"] = "abc", ["8"] = "abcdefg", ["9"] = "abcdfg"}
    local LIT, DIM = K.col(1, 0.34, 0.02), K.col(0.2, 0.05, 0.01)
    local score = "02753190"
    local pitch = (BW - 56) / #score
    local dw, dh, th = pitch * 0.56, 23, 2.4
    local dcy = (dy0 + dy1) / 2
    for k = 1, #score do
      local on = SEG[score:sub(k, k)]
      local cz = zc + (BW - 56) / 2 - (k - 0.5) * pitch       -- read left to right: towards -z
      local function seg(name, right_, up, w, h)
        local lit = on:find(name, 1, true) ~= nil
        box(K.deco, lit and LIT or DIM, v3(xf + (lit and 2.0 or 1.9), dcy + up, cz - right_), RT, OUT, w, h, lit and 1.2 or 0.6)
      end
      seg("a", 0, dh / 2, dw - th * 1.6, th)
      seg("g", 0, 0, dw - th * 1.6, th)
      seg("d", 0, -dh / 2, dw - th * 1.6, th)
      seg("f", -dw / 2, dh / 4, th, dh / 2 - th * 1.4)
      seg("b", dw / 2, dh / 4, th, dh / 2 - th * 1.4)
      seg("e", -dw / 2, -dh / 4, th, dh / 2 - th * 1.4)
      seg("c", dw / 2, -dh / 4, th, dh / 2 - th * 1.4)
    end
    -- lamps round the edge
    local nl = 0
    local function lamp(y, z)
      nl = nl + 1
      box(K.deco, (nl % 2 == 0) and YELLOW or WHITE, v3(xf + 1.6, y, z), RT, OUT, 3.4, 3.4, 1.8)
    end
    for z = zc - BW / 2 + 6, zc + BW / 2 - 5.9, (BW - 12) / 24 do lamp(top - 5.5, z); lamp(yb + 43, z) end
    for y = gy0 + 6, gy1 - 6, (gy1 - gy0 - 12) / 6 do lamp(y, zc - BW / 2 + 6); lamp(y, zc + BW / 2 - 6) end
    -- the beacon
    cyl(K.deco, DARK, xf - D / 2, zc, top + 1.5, top + 5, 9, 9, 12)
    K.ball(K.sub(K.deco, "beacon"), v3(xf - D / 2, top + 6, zc), 8, 10, 8, 10, 6, one, K.shaded(RED))
  end

  info(string.format("pinball kit: %d triangles, %d bumpers, %d roadside features, %d wire ramps, %d lights, %d steel balls",
    tris(K.solid) + tris(K.deco) - before, nb, count, ramps, lights, balls))
end

return T
