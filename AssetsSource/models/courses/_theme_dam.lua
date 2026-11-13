-- The dam course's scenery kit (see THEME KITS in _course.lua): a huge concrete arch dam in a mountain gorge. The
-- dam's curved wall stands along the east side, its downstream face to the road -- three stepped spillways pouring
-- white water down it, mist at their feet -- the reservoir behind it (T.shape, T.paint) with its intake towers, and a
-- river from the dam's foot down the gorge to the crossing at the finish. Concrete beside the road, rock beyond,
-- rising to the gorge's rim (pines up there). Along the road: yellow gantry cranes over it, valve towers, penstock
-- pipes, a control building, warning signs, floodlights, railings and small stepped cascades down the bank.
local T = {trees = 0.3}

-- The dam in plan: an arc of radius R about (CX, CZ), from angle A0 (its south end) to A1 (north), the reservoir
-- outside it. Its crest's height, the water's, and how much the downstream face leans (metres out a metre down).
local CX, CZ, R = -172, -40, 230
local A0, A1 = math.rad(-28.6), math.rad(26.3)
local CREST, WATER, BAT = 190, 186.5, 0.22
-- The river: down the dam's foot, round the gorge and across the road at the finish.
local RIVER = {{38.9, -10.4}, {33.2, -58}, {17.3, -101.5}, {1.1, -132}, {10, -170}, {8, -215}, {-4, -276}, {-12, -372}}
local RIVER_HW = 8

local function river_d(x, z)
  local best = 1e18
  for k = 1, #RIVER - 1 do
    local ax, az, bx, bz = RIVER[k][1], RIVER[k][2], RIVER[k + 1][1], RIVER[k + 1][2]
    local ex, ez = bx - ax, bz - az
    local t = ((x - ax) * ex + (z - az) * ez) / (ex * ex + ez * ez)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local dx, dz = x - ax - ex * t, z - az - ez * t
    local d = dx * dx + dz * dz
    if d < best then best = d end
  end
  return math.sqrt(best)
end
local function polar(x, z)
  local dx, dz = x - CX, z - CZ
  return math.sqrt(dx * dx + dz * dz), math.atan(dz, dx)
end
local function clamp01(v) return (v < 0) and 0 or ((v > 1) and 1 or v) end

-- The ground: the river's bed cut in, the reservoir level behind the dam, an apron kept low at the dam's foot, rock
-- rising steeply to the gorge's rim everywhere else, and a ridge off each end of the dam to hold the water.
function T.shape(x, z, off, y, road_y, TK)
  if off <= 8 then return nil end
  local r, a = polar(x, z)
  local inarc = a > A0 and a < A1
  local zone = inarc and r > R - 55
  if zone and r <= R - 0.5 then y = math.min(y, road_y + 6) end
  local dr = river_d(x, z)
  if dr < RIVER_HW + 8 then
    local bed = road_y - 3.5
    local target = bed + (y - bed) * clamp01((dr - RIVER_HW) / 8)
    return y + (target - y) * clamp01((off - 8) / 5)
  end
  if inarc and r > R - 0.5 then return y + (WATER - y) * clamp01((off - 8) / 6) end
  local rise = math.max(0, math.min(50, (off - 26) * 1.1))
  local n = noise3(x, 0, z, {frequency = 0.05, seed = 7})
  rise = (rise + n * math.min(7, rise * 0.3)) * clamp01((dr - RIVER_HW - 8) / 20)
  if zone then rise = 0 elseif inarc and r > R - 80 then rise = rise * (R - 55 - r) / 25 end
  y = y + rise
  if not inarc and r > R - 20 then
    local da = (a < A0) and (A0 - a) or (a - A1)
    if da < 0.2 then
      local t = clamp01((off - 9) / 14) * clamp01((r - (R - 20)) / 10) * clamp01((0.2 - da) / 0.05)
      local top = CREST + 7 + n * 5
      if top > y then y = y + (top - y) * t end
    end
  end
  return y
end

local INK
function T.paint(x, z, off, ink, TK)
  if not INK then
    local c = TK.col
    INK = {
      conc = {c(0.6, 0.6, 0.58), c(0.54, 0.54, 0.53), c(0.66, 0.66, 0.63)}, stain = c(0.4, 0.41, 0.41),
      apron = {c(0.58, 0.58, 0.57), c(0.5, 0.5, 0.5)},
      rock = {c(0.36, 0.34, 0.33), c(0.43, 0.4, 0.37), c(0.3, 0.3, 0.32), c(0.48, 0.45, 0.41)}, moss = c(0.2, 0.33, 0.14),
      river = c(0.1, 0.4, 0.75), river2 = c(0.2, 0.55, 0.85), foam = c(0.93, 0.96, 0.97),
      lake = c(0.05, 0.25, 0.5), lake2 = c(0.08, 0.33, 0.6), lake3 = c(0.03, 0.18, 0.4), glint = c(0.55, 0.75, 0.9),
    }
  end
  local h = TK.hash(x, z)
  local slab = (math.floor(x / 10) + math.floor(z / 10)) % 2
  if off < 9.5 then return (h < 0.07) and INK.stain or INK.conc[1 + slab] end
  local dr = river_d(x, z)
  if dr < RIVER_HW + 1.5 then return (h < 0.3) and INK.foam or ((h < 0.65) and INK.river or INK.river2) end
  local r, a = polar(x, z)
  local inarc = a > A0 and a < A1
  if inarc and r > R - 0.5 then
    local s = math.sin(x * 0.09 + z * 0.05) + math.sin(z * 0.13 - x * 0.04 + 1.1)
    if h < 0.025 then return INK.glint end
    if s > 1.0 then return INK.lake2 elseif s < -1.0 then return INK.lake3 end
    return INK.lake
  end
  if off < 14 then return (h < 0.08) and INK.stain or INK.conc[(h < 0.25) and 3 or (1 + slab)] end
  if inarc and r > R - 55 then return (h < 0.06) and INK.stain or INK.apron[1 + slab] end
  if off > 55 and h < 0.14 then return INK.moss end
  local n = noise3(x, 0, z, {frequency = 0.03, seed = 11})
  return INK.rock[1 + math.floor(clamp01(n * 0.6 + 0.5 + (h - 0.5) * 0.5) * 3.99)]
end

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local function rnd(a, b) return K.g:range(a, b) end
  local EDGE = K.WALL_T + 1          -- the road's own margin: nothing of the kit's nearer its edge
  local function one() return 1 end

  local WHITE, BLACK = col(0.93, 0.93, 0.9), col(0.03, 0.03, 0.03)
  local CONC, CONC2, CONC3, STAIN = col(0.6, 0.6, 0.58), col(0.5, 0.5, 0.49), col(0.7, 0.7, 0.67), col(0.38, 0.39, 0.39)
  local ASPH = col(0.2, 0.2, 0.22)
  local WATER_C, WATER_L, FOAM = col(0.1, 0.42, 0.8), col(0.45, 0.72, 0.92), col(0.95, 0.97, 0.98)
  local LAKE = col(0.05, 0.25, 0.5)
  local MIST, MIST2 = col(0.86, 0.92, 0.96), col(0.74, 0.84, 0.92)
  local YEL, RED, BLUE, GREEN, ORANGE = col(0.98, 0.76, 0.04), col(0.85, 0.08, 0.05), col(0.08, 0.3, 0.85),
    col(0.1, 0.55, 0.3), col(0.95, 0.45, 0.05)
  local STEEL, DARK, GLASS, LAMP = col(0.55, 0.58, 0.6), col(0.14, 0.15, 0.17), col(0.1, 0.22, 0.38), col(1.0, 0.95, 0.6)
  local CTRL = col(0.86, 0.88, 0.86)
  local ROCKS = {col(0.36, 0.34, 0.33), col(0.44, 0.41, 0.38), col(0.3, 0.3, 0.32)}
  local PINES = {col(0.05, 0.22, 0.08), col(0.07, 0.28, 0.09), col(0.05, 0.25, 0.13)}
  local PINE_LO, BARK = col(0.03, 0.13, 0.05), col(0.28, 0.16, 0.08)
  local PIPES = {BLUE, GREEN, ORANGE}
  local PIPE_DK = {K.tint(BLUE, 0.6), K.tint(GREEN, 0.6), K.tint(ORANGE, 0.6)}

  -- ---------------------------------------------------------------- shapes
  local function piece(root, key, c)
    local q = K.sub(root, key)
    if c then q.ink = c end
    return q
  end
  -- A box of three half-vectors about its centre.
  local function obox(root, c, cen, a, b, d)
    K.hexa(piece(root, c, c), cen - a - b - d, cen + a - b - d, cen + a - b + d, cen - a - b + d,
      cen - a + b - d, cen + a + b - d, cen + a + b + d, cen - a + b + d)
  end
  local function perp(d, hint)
    local e1 = cross(d, hint or UP)
    if length(e1) < 0.05 then e1 = cross(d, v3(1, 0, 0)) end
    e1 = normalize(e1)
    return e1, normalize(cross(d, e1))
  end
  -- A bar from p0 to p1: t1 its half width across (level, or across `hint`), t2 the other half thickness.
  local function beam(root, c, p0, p1, t1, t2, hint)
    local d = (p1 - p0) * 0.5
    local e1, e2 = perp(normalize(d), hint)
    obox(root, c, (p0 + p1) * 0.5, e1 * t1, d, e2 * t2)
  end
  -- A round tube from p0 to p1, radius r0 to r1, n-sided.
  local function limb(root, c, p0, p1, r0, r1, n)
    local e1, e2 = perp(normalize(p1 - p0))
    local rings = {}
    for j = 1, 2 do
      local p, rr = (j == 1) and p0 or p1, (j == 1) and r0 or r1
      local ring = {}
      for k = 0, n - 1 do
        local a = (k + 0.5) / n * math.pi * 2
        ring[#ring + 1] = p + e1 * (math.cos(a) * rr) + e2 * (math.sin(a) * rr)
      end
      rings[j] = ring
    end
    K.prism(piece(root, c), rings, K.flat(c), c, c)
  end
  local function sph(root, c, cen, r, n)
    K.ball(piece(root, c), cen, r, r, r, n or 6, 4, one, K.flat(c))
  end

  -- ---------------------------------------------------------------- where
  -- The ground's height at (x, z) and how far that is off the road's edge.
  local function gd(x, z) local y, d = K.ground_d(x, z); return y, d - K.HW end
  local function clear(x, z, m) local _, o = gd(x, z); return o > EDGE + (m or 0.4) end
  local taken = {}
  local function free(x, z, Rr)
    for _, t in ipairs(taken) do
      local dx, dz = t[1] - x, t[2] - z
      if dx * dx + dz * dz < (t[3] + Rr) * (t[3] + Rr) then return false end
    end
    return true
  end
  local function take(x, z, Rr) taken[#taken + 1] = {x, z, Rr} end
  -- A plot beside the road near sample i: a along the road by b out from it (half sizes), gap off the margin.
  local function site(i, side, a, b, gap)
    for _, di in ipairs({0, 2, -2, 4, -4, 7, -7, 10, -10}) do
      for _, sd in ipairs({side, -side}) do
        local j = math.max(3, math.min(N - 2, i + di))
        local w, u = right[j] * sd, K.along(j)
        local c = pos[j] + w * (W[j] + EDGE + gap + b)
        local Rr = math.max(a, b)
        local ok = free(c.x, c.z, Rr * 0.9) and river_d(c.x, c.z) > RIVER_HW + Rr
        if ok then
          for _, m in ipairs({{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}, {0, 0}}) do
            local p = c + u * (m[1] * a) + w * (m[2] * b)
            if not clear(p.x, p.z, gap * 0.5) then ok = false; break end
          end
        end
        if ok then
          take(c.x, c.z, Rr * 0.9)
          local s = {u = u, w = w, a = a, b = b, i = j}
          s.c = v3(c.x, K.ground(c.x, c.z), c.z)
          function s.at(du, dw)
            local p = c + u * du + w * dw
            return v3(p.x, K.ground(p.x, p.z), p.z)
          end
          return s
        end
      end
    end
    return nil
  end
  local made = {}
  local function count(k, n) made[k] = (made[k] or 0) + (n or 1) end

  -- A blob of mist: a pale flattened ball, lighter on top.
  local function mist(c, r)
    K.ball(piece(K.deco, MIST), c, r * rnd(1.0, 1.4), r * rnd(0.5, 0.75), r * rnd(1.0, 1.4), 8, 5,
      function() return rnd(0.85, 1.12) end, function(w) return (w.y > 0) and MIST or MIST2 end)
    count("mist blobs")
  end
  -- A floodlight: a mast at `base`, a bank of six lamps at its top facing along f (level).
  local function floodlight(root, base, h, f)
    local s = v3(-f.z, 0, f.x)
    local top = base + UP * h
    beam(root, DARK, base - UP * 0.5, top, 0.14, 0.14)
    obox(K.deco, DARK, top + UP * 0.2 + f * 0.1, s * 1.35, UP * 0.62, f * 0.1)
    for k = -1, 1 do
      for m = 0, 1 do
        obox(K.deco, LAMP, top + f * 0.24 + s * (k * 0.85) + UP * (m * 0.6 - 0.1), s * 0.33, UP * 0.22, f * 0.07)
      end
    end
    count("floodlights")
  end

  -- ---------------------------------------------------------------- the dam
  local function rf(y) return R - 5 - (CREST - y) * BAT end      -- the downstream face's radius at height y
  local function PP(a, r, y) return v3(CX + r * math.cos(a), y, CZ + r * math.sin(a)) end
  local Y0, NS, NR = 40, 15, 36
  local a0, a1 = A0 - 0.02, A1 + 0.02
  do
    -- The wall: one shell along the arc, its section the crest, the leaning face in lifts of concrete, the base,
    -- and the upright upstream face.
    local rings = {}
    for j = 0, NR do
      local a = a0 + (a1 - a0) * j / NR
      local ring = {PP(a, R + 5, CREST), PP(a, R - 5, CREST)}
      for s = 1, NS do
        local y = CREST - (CREST - Y0) * s / NS
        ring[#ring + 1] = PP(a, rf(y), y)
      end
      ring[#ring + 1] = PP(a, R + 5, Y0)
      rings[#rings + 1] = ring
    end
    K.prism(piece(K.deco, "dam"), rings, function(j, k)
      if k == 1 then return ASPH end
      if k > NS + 1 then return CONC2 end
      if K.hash(j * 1.7, k * 3.1) < 0.1 then return STAIN end
      if k > 3 and K.hash(j, 11) < 0.14 then return CONC2 end
      return (k % 2 == 0) and CONC or CONC3
    end, CONC2, CONC2)
    -- A parapet along each edge of the crest.
    for _, rr in ipairs({R - 4.7, R + 4.7}) do
      local pr = {}
      for j = 0, NR do
        local a = a0 + 0.001 + (a1 - a0 - 0.002) * j / NR
        pr[#pr + 1] = {PP(a, rr - 0.25, CREST - 0.2), PP(a, rr + 0.25, CREST - 0.2), PP(a, rr + 0.25, CREST + 1.2), PP(a, rr - 0.25, CREST + 1.2)}
      end
      K.prism(piece(K.deco, CONC3), pr, K.flat(CONC3), CONC3, CONC3)
    end
  end
  -- The ground at the face's foot at angle a.
  local function foot(a)
    local p = PP(a, R - 15, 0)
    local y = K.ground(p.x, p.z)
    for _ = 1, 3 do
      p = PP(a, rf(y) - 2, 0)
      y = K.ground(p.x, p.z)
    end
    return y
  end

  local SPILL = {math.rad(9), math.rad(-5), math.rad(-19)}
  local function near_spill(a, m)
    for _, s in ipairs(SPILL) do if math.abs(a - s) < m then return true end end
    return false
  end
  for si, a in ipairs(SPILL) do
    local er, et = v3(math.cos(a), 0, math.sin(a)), v3(-math.sin(a), 0, math.cos(a))
    local yg = foot(a)
    local ybase = yg - 5
    local H, HWID = 5, 6.5
    -- The gates at the top: four piers, three dark gates between them, white water under each.
    for k = -3, 3, 2 do
      obox(K.deco, CONC3, PP(a, R - 7.4, CREST - 3.5) + et * (k * 2.4), et * 0.6, UP * 5.6, er * 2.6)
    end
    for k = -1, 1 do
      obox(K.deco, DARK, PP(a, R - 6.3, CREST - 3.2) + et * (k * 4.8), et * 1.82, UP * 2.6, er * 1.2)
      obox(K.deco, FOAM, PP(a, R - 7.4, CREST - 7.2) + et * (k * 4.8), et * 1.7, UP * 1.5, er * 1.5)
    end
    -- The steps: a blue riser, foam on its tread and white streaks down it.
    local n = 0
    while true do
      local yt = CREST - 8 - n * H
      local yb = yt - H
      if yt < ybase then break end
      local r_out, r_in = rf(yb) - 2.2, rf(yt) + 1
      local mid = PP(a, (r_out + r_in) / 2, (yt + yb) / 2)
      obox(K.deco, (n % 2 == 0) and WATER_L or WATER_C, mid, et * HWID, UP * (H / 2 - 0.01), er * ((r_in - r_out) / 2))
      obox(K.deco, FOAM, PP(a, r_out + 0.55, yt + 0.2), et * (HWID + 0.15), UP * 0.3, er * 1.1)
      for k = 1, 3 do
        local o = (k - 2) * 4.1 + (K.hash(si * 7 + n, k) - 0.5) * 2.4
        local len = 1.2 + K.hash(n, k * 3 + si) * 1.1
        obox(K.deco, FOAM, PP(a, r_out - 0.05, yt - len - 0.1) + et * o, et * (0.5 + K.hash(k, n) * 0.6), UP * len, er * 0.2)
      end
      n = n + 1
    end
    count("spillway steps", n)
    -- The training walls each side of the chute, and a red-and-white gauge down the face beside it.
    local ptop, pbot = PP(a, rf(CREST - 3) - 1.2, CREST - 3), PP(a, rf(ybase) - 1.2, ybase)
    for sd = -1, 1, 2 do
      obox(K.deco, CONC2, (ptop + pbot) * 0.5 + et * (sd * (HWID + 0.75)), et * 0.55, (pbot - ptop) * 0.5, er * 2.9)
    end
    local g = 0
    for y = CREST - 6, yg, -6 do
      obox(K.deco, (g % 2 == 0) and RED or WHITE, PP(a, rf(y - 3) - 0.1, y - 3) + et * (HWID + 4), et * 1.0, UP * 2.97 + er * (-2.97 * BAT), er * 0.3)
      g = g + 1
    end
    -- The foaming pool at its foot, and the mist over it.
    local pc = PP(a, rf(yg) - 8, 0)
    local py = K.ground(pc.x, pc.z)
    K.column(piece(K.deco, FOAM), pc.x, pc.z, py - 3, py + 0.5, 9.5, 9.5, 12, FOAM)
    K.column(piece(K.deco, WATER_L), pc.x, pc.z, py - 3, py + 0.3, 13, 13, 12, WATER_L, 0.2)
    for k = 1, 14 do
      local q = PP(a + rnd(-0.05, 0.05), rf(yg) - rnd(1, 20), 0)
      mist(v3(q.x, K.ground(q.x, q.z) + rnd(2, 8), q.z), rnd(3.5, 7))
    end
    for k = 1, 5 do
      local y = yg + k * 4.5
      mist(PP(a + rnd(-0.02, 0.02), rf(y) - 4.5, y + 2), rnd(2.5, 4))
    end
    -- A gantry crane on the crest over the gates: two yellow portals, a girder between them, its trolley and hook.
    for sd = -1, 1, 2 do
      local c = PP(a, R, CREST) + et * (sd * 9)
      for k = -1, 1, 2 do obox(K.deco, YEL, c + er * (k * 3.6) + UP * 5, et * 0.35, UP * 5, er * 0.35) end
      obox(K.deco, YEL, c + UP * 10.4, et * 0.45, UP * 0.5, er * 5.6)
    end
    obox(K.deco, YEL, PP(a, R - 2, CREST + 11.5), et * 10.5, UP * 0.7, er * 0.6)
    for k = -3, 3 do obox(K.deco, BLACK, PP(a, R - 2, CREST + 11.5) + et * (k * 2.8), et * 0.5, UP * 0.72, er * 0.62) end
    obox(K.deco, RED, PP(a, R - 2, CREST + 10.3) + et * 2.5, et * 1.3, UP * 0.5, er * 1.1)
    beam(K.deco, DARK, PP(a, R - 2, CREST + 9.8) + et * 2.5, PP(a, R - 2, CREST + 5) + et * 2.5, 0.07, 0.07)
    obox(K.deco, YEL, PP(a, R - 2, CREST + 4.6) + et * 2.5, et * 0.5, UP * 0.45, er * 0.3)
    count("spillways")
  end
  -- Floodlights along the crest, shining down the face.
  for j = 1, NR - 1, 2 do
    local a = a0 + (a1 - a0) * j / NR
    if not near_spill(a, 0.06) then
      floodlight(K.deco, PP(a, R - 3.6, CREST), 11, v3(-math.cos(a), 0, -math.sin(a)))
    end
  end
  -- Intake towers in the reservoir: a concrete drum, a band of windows, a red roof, a footbridge to the crest.
  for _, a in ipairs({math.rad(17), math.rad(2), math.rad(-12), math.rad(-25)}) do
    local c = PP(a, R + 27, 0)
    local er, et = v3(math.cos(a), 0, math.sin(a)), v3(-math.sin(a), 0, math.cos(a))
    K.column(piece(K.deco, CONC), c.x, c.z, WATER - 10, CREST + 9, 5.2, 4.6, 10, CONC)
    K.column(piece(K.deco, GLASS), c.x, c.z, CREST + 4.6, CREST + 6.8, 4.85, 4.8, 10, GLASS)
    K.column(piece(K.deco, CONC3), c.x, c.z, CREST + 9, CREST + 9.8, 5.8, 5.8, 10, CONC3)
    local top = v3(c.x, CREST + 9.8, c.z)
    K.cone(piece(K.deco, RED), K.ring(top, 5.4, 5.4, 10, 0), top, top + UP * 3.4, K.flat(RED), DARK)
    obox(K.deco, STEEL, PP(a, R + 13.5, CREST + 0.2), et * 1.0, UP * 0.2, er * 9.5)
    for sd = -1, 1, 2 do
      obox(K.deco, YEL, PP(a, R + 13.5, CREST + 1.35) + et * (sd * 0.95), et * 0.05, UP * 0.05, er * 9.4)
      for k = -3, 3 do obox(K.deco, YEL, PP(a, R + 13.5 + k * 3, CREST + 0.9) + et * (sd * 0.95), et * 0.05, UP * 0.5, er * 0.05) end
    end
    count("intake towers")
  end

  -- ---------------------------------------------------------------- beside the road
  -- A point `gap` past the road's margin at sample i on side sd, on the ground; and how far off the road's edge it is.
  local function along_pt(i, sd, gap)
    local p = pos[i] + right[i] * (sd * (W[i] + EDGE + gap))
    local y, o = gd(p.x, p.z)
    return v3(p.x, y, p.z), o
  end

  -- A yellow gantry crane over the road: A-frame legs outside the walls, a striped girder 9 m up, a trolley and hook.
  local function gantry(i)
    for d = 0, 14 do
      if K.lift(i + d, 1) == 0 and K.lift(i + d, -1) == 0 then i = i + d; break end
    end
    local c, r, t = pos[i], right[i], K.along(i)
    local half = W[i] + EDGE + 1.1
    for sd = -1, 1, 2 do
      local p = c + r * (sd * half)
      local top = v3(p.x, c.y + 10, p.z)
      for k = -1, 1, 2 do
        local b = p + t * (k * 1.7)
        beam(K.solid, YEL, v3(b.x, K.ground(b.x, b.z) - 0.6, b.z), top + t * (k * 0.2), 0.24, 0.24)
      end
      obox(K.solid, YEL, v3(p.x, c.y + 3.2, p.z), t * 1.3, UP * 0.14, r * 0.14)
      take(p.x, p.z, 2.3)
    end
    local gc = c + UP * 9.6
    obox(K.deco, YEL, gc, r * (half + 0.9), UP * 0.6, t * 0.5)
    for k = -3, 3 do obox(K.deco, BLACK, gc + r * (k * (half / 3.4)), r * 0.4, UP * 0.62, t * 0.52) end
    local tc = gc + r * (half * 0.35) - UP * 1.0
    obox(K.deco, RED, tc, r * 0.9, UP * 0.38, t * 0.8)
    beam(K.deco, DARK, tc - UP * 0.4, tc - UP * 1.2, 0.05, 0.05)
    obox(K.deco, YEL, tc - UP * 1.4, r * 0.3, UP * 0.22, t * 0.2)
    count("gantry cranes")
  end

  -- The control building: a white block, bands of blue glass, a blue stripe, a flat roof with a mast and a dish.
  local function control(i, side)
    local s = site(i, side, 7, 4, 1.0)
    if not s then return end
    local u, w = s.u, s.w
    local mid = v3(s.c.x, 0, s.c.z)
    local front = mid - w * 4
    local yf = K.ground(front.x, front.z)
    local lo = K.lowest(s.c, u, w, 7, 4) - 0.6
    local top = yf + 7.2
    obox(K.solid, CTRL, mid + UP * ((lo + top) / 2), u * 7, UP * ((top - lo) / 2), w * 4)
    obox(K.deco, BLUE, mid + UP * (yf + 3.55), u * 7.06, UP * 0.3, w * 4.06)
    obox(K.deco, DARK, mid + UP * (top + 0.15), u * 7.5, UP * 0.2, w * 4.5)
    obox(K.deco, GLASS, front + UP * (yf + 5.3), u * 6.2, UP * 0.85, w * 0.09)
    for k = -2, 2 do obox(K.deco, CTRL, front + UP * (yf + 5.3) + u * (k * 2.5), u * 0.12, UP * 0.88, w * 0.12) end
    obox(K.deco, GLASS, front + UP * (yf + 2.0) + u * 3.4, u * 2.4, UP * 0.75, w * 0.09)
    obox(K.deco, ORANGE, front + UP * (yf + 1.2) - u * 3.6, u * 0.8, UP * 1.25, w * 0.09)
    -- On the roof: a lattice mast with a red tip, a dish, a plant box, and a yellow-and-black board.
    local rc = mid + UP * (top + 0.35)
    beam(K.deco, STEEL, rc + u * 5, rc + u * 5 + UP * 7, 0.12, 0.12)
    sph(K.deco, RED, rc + u * 5 + UP * 7.2, 0.35, 6)
    K.ball(piece(K.deco, WHITE), rc + u * 3 + UP * 1.6, 1.3, 1.3, 0.4, 8, 4, one, K.flat(WHITE))
    beam(K.deco, STEEL, rc + u * 3, rc + u * 3 + UP * 1.5, 0.08, 0.08)
    obox(K.deco, STEEL, rc - u * 4 + UP * 0.7, u * 1.4, UP * 0.7, w * 1.1)
    obox(K.deco, YEL, rc - w * 3.6 + UP * 1.3, u * 3.2, UP * 1.0, w * 0.1)
    for k = -2, 2 do obox(K.deco, BLACK, rc - w * 3.72 + UP * 1.3 + u * (k * 1.3), u * 0.3 + UP * 0.25, UP * 0.9 - u * 0.1, w * 0.03) end
    count("control buildings")
  end

  -- A valve tower: a concrete drum with a blue band, a red handwheel on top, a bright pipe out each side into the ground.
  local function valve(i, side)
    local s = site(i, side, 4.6, 3.0, 0.8)
    if not s then return end
    local c, u = s.c, s.u
    local ci = math.min(3, math.floor(rnd(1, 4)))
    K.column(piece(K.solid, CONC), c.x, c.z, c.y - 1.2, c.y + 7.5, 2.3, 2.0, 10, CONC)
    K.column(piece(K.deco, BLUE), c.x, c.z, c.y + 5.0, c.y + 5.8, 2.2, 2.17, 10, BLUE)
    K.column(piece(K.deco, CONC3), c.x, c.z, c.y + 7.5, c.y + 8.0, 2.7, 2.7, 10, CONC3)
    K.column(piece(K.deco, STEEL), c.x, c.z, c.y + 8.0, c.y + 9.1, 0.2, 0.2, 6, STEEL)
    K.column(piece(K.deco, RED), c.x, c.z, c.y + 9.1, c.y + 9.35, 1.4, 1.4, 10, RED)
    for sd = -1, 1, 2 do
      local p0, p1 = c + UP * 2.4 + u * (sd * 1.6), c + UP * 2.4 + u * (sd * 3.7)
      limb(K.solid, PIPES[ci], p0, p1, 0.6, 0.6, 8)
      limb(K.deco, PIPE_DK[ci], p0 + u * (sd * 0.7), p0 + u * (sd * 1.0), 0.78, 0.78, 8)
      sph(K.deco, PIPES[ci], p1, 0.68, 8)
      local g = s.at(sd * 3.7, 0)
      limb(K.solid, PIPES[ci], p1 - UP * 0.05, v3(p1.x, g.y - 0.6, p1.z), 0.6, 0.6, 8)
    end
    count("valve towers")
  end

  -- A stepped cascade down the bank to the road's edge: blue steps with foam lips between concrete kerbs, a headwall
  -- at the top, mist at the bottom.
  local function cascade(i, side)
    for _, sd in ipairs({side, -side}) do
      local u, w = K.along(i), right[i] * sd
      local steps, last, lasto = 0, nil, 0
      for k = 0, 9 do
        local p = pos[i] + w * (W[i] + EDGE + 1.0 + 1.2 + k * 2.4)
        local y, o = gd(p.x, p.z)
        if o < lasto + 1 or not free(p.x, p.z, 3.4) or river_d(p.x, p.z) < RIVER_HW + 12 then break end
        lasto = o
        local c = v3(p.x, y, p.z)
        obox(K.deco, (k % 2 == 0) and WATER_C or WATER_L, c - UP * 0.6, u * 2.6, UP * 1.0, w * 1.19)
        obox(K.deco, FOAM, c + UP * 0.38 - w * 0.95, u * 2.55, UP * 0.16, w * 0.4)
        for e = -1, 1, 2 do obox(K.solid, CONC3, c + u * (e * 3.0) - UP * 0.3, u * 0.38, UP * 1.3, w * 1.19) end
        steps, last = steps + 1, c
      end
      if steps >= 3 then
        for k = 0, steps - 1 do
          local p = pos[i] + w * (W[i] + EDGE + 2.2 + k * 2.4)
          take(p.x, p.z, 3.4)
        end
        obox(K.solid, CONC, last + w * 1.9 + UP * 0.9, u * 4.2, UP * 2.2, w * 0.6)
        limb(K.deco, DARK, last + w * 1.25 + UP * 1.5, last + w * 1.6 + UP * 1.5, 1.1, 1.1, 10)
        obox(K.deco, FOAM, last + w * 0.6 + UP * 0.75, u * 0.8, UP * 0.5, w * 0.6)
        local b = pos[i] + w * (W[i] + EDGE + 4)
        for k = 1, 3 do
          local q = b + u * rnd(-3, 3) + w * rnd(0, 4)
          if clear(q.x, q.z, 2.4) then mist(v3(q.x, K.ground(q.x, q.z) + rnd(1.4, 2.6), q.z), rnd(1.5, 2.2)) end
        end
        count("cascades")
        return
      end
    end
  end

  -- A penstock along the road from sample i0 to i1: lengths of bright pipe, a flange and a concrete saddle at each joint.
  local function pipeline(i0, i1, sd, ci)
    local rad, prev = 0.8, nil
    local c, dk = PIPES[ci], PIPE_DK[ci]
    for i = i0, i1, 3 do
      local p, o = along_pt(i, sd, 2.4)
      local q = nil
      if o > EDGE + rad + 0.4 and free(p.x, p.z, 1.0) and river_d(p.x, p.z) > RIVER_HW + 2 then
        q = p + UP * (rad + 0.55)
        local t = K.along(i)
        obox(K.solid, CONC2, p + UP * 0.1, t * 0.32, UP * 0.75, right[i] * 1.0)
        limb(K.deco, dk, q - t * 0.2, q + t * 0.2, rad * 1.25, rad * 1.25, 10)
        if prev then
          local d = normalize(q - prev)
          limb(K.solid, c, prev + d * 0.03, q - d * 0.03, rad, rad, 10)
          count("pipe lengths")
        else
          limb(K.solid, c, q + UP * 0.02, p - UP * 0.8, rad, rad, 10)
        end
      elseif prev then
        limb(K.solid, c, prev - UP * 0.02, prev - UP * (rad + 1.4), rad, rad, 10)
      end
      prev = q
    end
    if prev then limb(K.solid, c, prev - UP * 0.02, prev - UP * (rad + 1.4), rad, rad, 10) end
  end

  -- A yellow railing along the road's margin from sample i0 to i1.
  local function railing(i0, i1, sd)
    local prev
    for i = i0, i1, 2 do
      local p, o = along_pt(i, sd, 0.45)
      if o > EDGE + 0.3 and free(p.x, p.z, 0.2) then
        beam(K.deco, YEL, p - UP * 0.3, p + UP * 1.15, 0.05, 0.05)
        if prev then
          for _, h in ipairs({0.6, 1.1}) do
            local a, b = prev + UP * h, p + UP * h
            local d = normalize(b - a)
            beam(K.deco, YEL, a + d * 0.02, b - d * 0.02, 0.035, 0.035)
          end
          count("railing bays")
        end
        prev = p
      else
        prev = nil
      end
    end
  end

  -- A warning sign facing up the road: a yellow diamond with a black edge and an exclamation mark, or a red-and-white
  -- striped board.
  local function sign(i, sd, kind)
    local p, o = along_pt(i, sd, 0.95)
    if o < EDGE + 0.8 or not free(p.x, p.z, 0.6) then return end
    local t = K.along(i)
    local s = right[i]
    local f = t * -1
    beam(K.solid, STEEL, p - UP * 0.4, p + UP * 2.3, 0.06, 0.06)
    local c = p + UP * 2.9
    if kind == 0 then
      local d1, d2 = (s + UP) * 0.7071, (UP - s) * 0.7071
      obox(K.deco, BLACK, c, d1 * 0.82, d2 * 0.82, f * 0.03)
      obox(K.deco, YEL, c + f * 0.03, d1 * 0.7, d2 * 0.7, f * 0.03)
      obox(K.deco, BLACK, c + f * 0.07 + UP * 0.12, s * 0.09, UP * 0.3, f * 0.02)
      obox(K.deco, BLACK, c + f * 0.07 - UP * 0.38, s * 0.09, UP * 0.09, f * 0.02)
    else
      obox(K.deco, WHITE, c, s * 1.0, UP * 0.5, f * 0.03)
      for k = -2, 2, 2 do obox(K.deco, RED, c + f * 0.03 + s * (k * 0.4), s * 0.2 + UP * 0.1, UP * 0.5 - s * 0.1, f * 0.02) end
    end
    count("warning signs")
  end

  -- ---------------------------------------------------------------- laid out down the road
  control(K.start + 16, 1)
  for _, f in ipairs({0.12, 0.29, 0.47, 0.65, 0.84}) do gantry(math.floor(N * f)) end
  for k, f in ipairs({0.07, 0.2, 0.38, 0.56, 0.74, 0.91}) do valve(math.floor(N * f), (k % 2 == 0) and 1 or -1) end
  for k, f in ipairs({0.16, 0.34, 0.43, 0.6, 0.79, 0.95}) do cascade(math.floor(N * f), (k % 2 == 0) and -1 or 1) end

  -- The water crossing at the finish: a headwall each side of the road's bank, three culverts through it.
  do
    local i = K.fin
    local u = K.along(i)
    for sd = -1, 1, 2 do
      local w = right[i] * sd
      local hc = pos[i] + w * (W[i] + 11.6)
      obox(K.deco, CONC3, hc - UP * 2.2, u * 6.2, UP * 2.5, w * 0.5)
      obox(K.deco, CONC2, hc + UP * 0.45, u * 6.4, UP * 0.18, w * 0.7)
      for k = -1, 1 do
        local c = hc + u * (k * 3.6) - UP * 2.3
        limb(K.deco, CONC, c + w * 0.3, c + w * 0.75, 1.5, 1.5, 10)
        limb(K.deco, DARK, c + w * 0.4, c + w * 0.85, 1.2, 1.2, 10)
        obox(K.deco, FOAM, c + w * 1.6 - UP * 1.0, u * 0.9, UP * 0.3 - w * 0.25, w * 1.0)
      end
      for k = 1, 4 do
        local q = pos[i] + w * (W[i] + rnd(15, 30)) + u * rnd(-8, 8)
        if clear(q.x, q.z, 7) then mist(v3(q.x, K.ground(q.x, q.z) + rnd(1.5, 3), q.z), rnd(2.5, 4)) end
      end
      take(hc.x, hc.z, 6.5)
    end
    count("culvert headwalls", 2)
  end

  -- Down the road in stretches: railings, penstocks, floodlights and warning signs.
  local BLOCK = 24
  for b = 0, math.floor((N - 8) / BLOCK) - 1 do
    local i0 = 4 + b * BLOCK
    local i1 = math.min(N - 4, i0 + BLOCK - 4)
    for sd = -1, 1, 2 do
      local h = K.hash(b * 3.7 + sd, 21)
      if h < 0.7 then railing(i0, i1, sd) end
      if K.hash(b * 5.3 + sd, 4) < 0.45 then pipeline(i0, i1, sd, 1 + (b + ((sd > 0) and 1 or 0)) % 3) end
    end
    local sd = (b % 2 == 0) and 1 or -1
    local p, o = along_pt(i0 + 8, sd, 1.05)
    if o > EDGE + 0.8 and free(p.x, p.z, 0.4) then floodlight(K.solid, p, 9.5, right[i0 + 8] * -sd) end
    sign(i0 + 16, -sd, b % 3 == 0 and 1 or 0)
    if b % 2 == 1 then sign(i0 + 3, sd, 0) end
  end

  -- ---------------------------------------------------------------- the gorge
  local function dry(x, z)
    if river_d(x, z) < RIVER_HW + 6 then return false end
    local r, a = polar(x, z)
    return not (a > A0 - 0.03 and a < A1 + 0.03 and r > R - 40)
  end
  -- Boulders on the gorge's sides, and pines along its rim.
  local rocks, pines = 0, 0
  for _ = 1, 900 do
    if rocks >= 240 then break end
    local x, z = K.spot(20)
    if x and dry(x, z) then
      local ci = 1 + rocks % 3
      local s = rnd(1.2, 4.2)
      K.ball(piece(K.deco, ROCKS[ci]), v3(x, K.ground(x, z) - 0.2 * s, z), s * rnd(0.9, 1.5), s * rnd(0.6, 1.0), s * rnd(0.8, 1.3), 8, 5,
        function() return rnd(0.75, 1.2) end, K.shaded(ROCKS[ci]))
      rocks = rocks + 1
    end
  end
  for _ = 1, 700 do
    if pines >= 90 then break end
    local x, z = K.spot(60)
    if x and dry(x, z) then
      local y = K.ground(x, z) - 0.4
      local s = rnd(1.1, 2.0)
      local green = PINES[1 + pines % 3]
      local turn = rnd(0, 1.5)
      K.column(piece(K.deco, BARK), x, z, y - 0.4, y + 3.0 * s, 0.26 * s, 0.17 * s, 6, BARK, turn)
      for tier = 0, 3 do
        local base = v3(x, y + (1.6 + tier * 1.25) * s, z)
        local rad = (2.5 - tier * 0.52) * s
        K.cone(piece(K.deco, green), K.ring(base, rad, rad, 9, turn + tier * 0.6), base, base + UP * (2.3 * s), K.flat(green), PINE_LO)
      end
      pines = pines + 1
    end
  end

  -- How near the dam's face comes to any road (the road runs on past both its ends).
  local nearest = 1e9
  for j = 0, NR do
    local a = a0 + (a1 - a0) * j / NR
    local p = PP(a, rf(foot(a)) - 3, 0)
    local _, o = gd(p.x, p.z)
    if o < nearest then nearest = o end
  end
  local list = {}
  for k, n in pairs(made) do list[#list + 1] = n .. " " .. k end
  table.sort(list)
  info("dam: " .. table.concat(list, ", ") .. string.format(", %d boulders, %d pines; the dam's foot %.0f m off the road at its nearest", rocks, pines, nearest))
end

return T
