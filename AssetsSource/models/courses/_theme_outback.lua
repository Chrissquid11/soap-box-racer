-- The outback course's own scenery kit (see THEME KITS in _course.lua), on top of the library's farms and fences
-- (keep = true): red dirt everywhere (T.paint), a great red monolith on the horizon and a huddle of domes far off the
-- other way, a corrugated-iron pub on stumps with its bowsers and a ute, a road train parked in a lay-by, two windmill
-- pumps with their tanks, kangaroos and emus by the road, yellow diamond signs (a kangaroo, GRID), termite mounds,
-- spinifex, ghost gums and other eucalypts, and red rocky outcrops.
local T = {keep = true}

-- The benches cut beside the road for what stands on level ground (T.shape, T.paint and T.build all read them): each a
-- line a -> b (x, z) and a radius.
local PUB = {ax = -21.0, az = -40.0, bx = -12.8, bz = -67.6, r = 12}
local LAYBY = {ax = 81.2, az = -115.9, bx = 126.9, bz = -144.7, r = 6}
local MILL1 = {ax = 41.5, az = -80.3, bx = 41.5, bz = -80.3, r = 9}
local MILL2 = {ax = 274.7, az = -171.8, bx = 274.7, bz = -171.8, r = 9}
local PADS = {PUB, LAYBY, MILL1, MILL2}
local BENCH = 1.3          -- a bench's height over the road beside it

local function clamp01(v) return (v < 0) and 0 or ((v > 1) and 1 or v) end
local function pad_d(p, x, z)
  local ex, ez = p.bx - p.ax, p.bz - p.az
  local l2 = ex * ex + ez * ez
  local t = (l2 > 0) and clamp01(((x - p.ax) * ex + (z - p.az) * ez) / l2) or 0
  local dx, dz = x - p.ax - ex * t, z - p.az - ez * t
  return math.sqrt(dx * dx + dz * dz)
end

function T.shape(x, z, off, y, road_y, TK)
  if off <= 8 then return nil end
  for _, p in ipairs(PADS) do
    local d = pad_d(p, x, z)
    if d < p.r then
      local t = clamp01((p.r - d) / 3) * clamp01((off - 8) / 2.5)
      return y + (road_y + BENCH - y) * t
    end
  end
  return nil
end

local INK
function T.paint(x, z, off, ink, TK)
  if not INK then
    local c = TK.col
    INK = {
      red = {c(0.5, 0.17, 0.07), c(0.62, 0.23, 0.09), c(0.7, 0.28, 0.1), c(0.76, 0.34, 0.13), c(0.82, 0.42, 0.17)},
      verge = c(0.58, 0.24, 0.11), sand = c(0.86, 0.56, 0.3), pan = c(0.9, 0.8, 0.68), straw = c(0.8, 0.66, 0.3),
      scrub = c(0.5, 0.48, 0.22), yard = {c(0.74, 0.5, 0.33), c(0.68, 0.44, 0.28)},
    }
  end
  local h = TK.hash(x, z)
  if off < 3.4 then return (h < 0.2) and INK.red[2] or INK.verge end
  for _, p in ipairs(PADS) do
    if pad_d(p, x, z) < p.r - 2 then return INK.yard[(h < 0.3) and 2 or 1] end
  end
  local n = noise3(x, 0, z, {frequency = 0.022, seed = 5})
  local n2 = noise3(x, 0, z, {frequency = 0.06, seed = 9})
  if n < -0.42 and n2 < 0 then return (h < 0.5) and INK.pan or INK.sand end          -- a claypan
  if n2 > 0.36 then return (h < 0.5) and INK.straw or INK.scrub end                  -- dry grass
  if n2 < -0.42 then return INK.sand end
  return INK.red[1 + math.floor(clamp01(n * 0.9 + 0.5 + (h - 0.5) * 0.45) * 4.99)]
end

-- A 3 x 5 dot face for the signs' words (rows from the top).
local FONT = {
  P = {"111", "101", "111", "100", "100"}, U = {"101", "101", "101", "101", "111"}, B = {"110", "101", "110", "101", "110"},
  F = {"111", "100", "110", "100", "100"}, E = {"111", "100", "110", "100", "111"}, L = {"100", "100", "100", "100", "111"},
  G = {"111", "100", "101", "101", "111"}, R = {"110", "101", "110", "101", "101"}, I = {"111", "010", "010", "010", "111"},
  D = {"110", "101", "101", "101", "110"}, O = {"111", "101", "101", "101", "111"}, A = {"010", "101", "111", "101", "101"},
  T = {"111", "010", "010", "010", "010"}, N = {"101", "111", "111", "101", "101"},
}

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local function rnd(a, b) return K.g:range(a, b) end
  local EDGE = K.WALL_T + 1          -- the road's own margin: nothing of the kit's nearer its edge

  local WHITE, BLACK = col(0.93, 0.93, 0.9), col(0.03, 0.03, 0.03)
  local YEL, RED, BLUE = col(0.98, 0.76, 0.04), col(0.8, 0.07, 0.04), col(0.08, 0.3, 0.8)
  local IRON, IRON2, IRON_DK = col(0.72, 0.74, 0.74), col(0.6, 0.63, 0.64), col(0.42, 0.45, 0.47)
  local RUST, RUST2 = col(0.5, 0.2, 0.1), col(0.4, 0.15, 0.08)
  local STEEL, DARK, GLASS = col(0.6, 0.63, 0.66), col(0.12, 0.12, 0.14), col(0.12, 0.25, 0.4)
  local TYRE, HUB = col(0.05, 0.05, 0.06), col(0.75, 0.75, 0.72)
  local WOOD, WOOD2 = col(0.42, 0.28, 0.15), col(0.3, 0.19, 0.1)
  local CONC, WATER = col(0.62, 0.6, 0.56), col(0.1, 0.45, 0.75)
  local ROCK = {col(0.62, 0.2, 0.08), col(0.72, 0.27, 0.1), col(0.5, 0.15, 0.07)}
  local ROCK_HI, ROCK_LO = col(0.85, 0.4, 0.15), col(0.36, 0.1, 0.06)
  local MOUND = {col(0.56, 0.24, 0.12), col(0.68, 0.34, 0.18), col(0.46, 0.18, 0.09)}
  local SPIN = {col(0.82, 0.74, 0.36), col(0.7, 0.66, 0.3), col(0.56, 0.6, 0.28), col(0.66, 0.7, 0.36)}
  local GUM_W, GUM_W2, BARK_R, BARK_D = col(0.92, 0.9, 0.84), col(0.8, 0.78, 0.72), col(0.5, 0.33, 0.24), col(0.3, 0.22, 0.17)
  local LEAF = {col(0.36, 0.46, 0.26), col(0.42, 0.5, 0.3), col(0.3, 0.42, 0.24)}
  local LEAF2 = {col(0.26, 0.36, 0.14), col(0.33, 0.4, 0.16)}
  local ROO = {col(0.55, 0.5, 0.46), col(0.8, 0.62, 0.44), col(0.66, 0.56, 0.48)}
  local ROO_DK = col(0.25, 0.2, 0.17)
  local EMU, EMU2, EMU_NECK, EMU_LEG = col(0.3, 0.24, 0.19), col(0.4, 0.33, 0.26), col(0.4, 0.5, 0.62), col(0.42, 0.38, 0.32)
  local UTE, TRUCK, TRUCK2 = col(0.92, 0.92, 0.88), col(0.82, 0.1, 0.05), col(0.1, 0.25, 0.6)

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
  -- A round tube through pts, a radius at each, n-sided (one frame for all its rings: gentle bends only).
  local function tube(root, c, pts, radii, n, key, phase)
    local e1, e2 = perp(normalize(pts[#pts] - pts[1]))
    local rings = {}
    for j, p in ipairs(pts) do
      local ring = {}
      for k = 0, n - 1 do
        local a = (k + 0.5 + (phase or 0)) / n * math.pi * 2
        ring[#ring + 1] = p + e1 * (math.cos(a) * radii[j]) + e2 * (math.sin(a) * radii[j])
      end
      rings[j] = ring
    end
    K.prism(piece(root, key or c), rings, K.flat(c), c, c)
  end
  local function limb(root, c, p0, p1, r0, r1, n, key, phase) tube(root, c, {p0, p1}, {r0, r1}, n, key, phase) end
  -- A frame: an origin and three axes; F.P(a, b, h) a point of it, box() a box by its ranges along each.
  local function frame(o, U, Wd, Nn)
    local F = {o = o, U = U, W = Wd, N = Nn}
    function F.P(a, b, h) return o + U * a + Wd * b + Nn * h end
    return F
  end
  local function box(F, root, c, a0, a1, b0, b1, h0, h1)
    obox(root, c, F.P((a0 + a1) / 2, (b0 + b1) / 2, (h0 + h1) / 2), F.U * ((a1 - a0) / 2), F.N * ((h1 - h0) / 2), F.W * ((b1 - b0) / 2))
  end
  local function gy(x, z) local y = K.ground(x, z); return y end
  local function gp(p) return v3(p.x, gy(p.x, p.z), p.z) end
  -- A frame lying on the ground at (x, z), heading u (level), for something l long and wd wide.
  local function gframe(x, z, u, l, wd)
    local w = v3(-u.z, 0, u.x)
    local c = v3(x, 0, z)
    local pf, pr = gp(c + u * (l / 2)), gp(c - u * (l / 2))
    local pl, pq = gp(c + w * (wd / 2)), gp(c - w * (wd / 2))
    local U = normalize(pf - pr)
    local Nn = normalize(cross(pl - pq, U))
    if Nn.y < 0 then Nn = Nn * -1 end
    local Wd = normalize(cross(U, Nn))
    if dot(Wd, w) < 0 then Wd = Wd * -1 end
    return frame(v3(x, (pf.y + pr.y + pl.y + pq.y) / 4, z), U, Wd, Nn)
  end
  -- A wheel on a frame: at a along, b across (its middle), radius r, half width hw.
  local function wheel(F, root, a, b, r, hw)
    limb(root, TYRE, F.P(a, b - hw, r), F.P(a, b + hw, r), r, r, 8)
    limb(root, HUB, F.P(a, b - hw - 0.02, r), F.P(a, b + hw + 0.02, r), r * 0.45, r * 0.45, 6)
  end
  -- Words in dots: middle o, ex to the reader's right, ey up, en towards the reader; px a dot.
  local function text(root, c, o, ex, ey, en, str, px)
    local x0 = -(#str * 4 - 1) * px / 2
    for ci = 1, #str do
      local g = FONT[str:sub(ci, ci)]
      if g then
        for r = 1, 5 do
          local row, k = g[r], 1
          while k <= 3 do
            if row:sub(k, k) == "1" then
              local e = k
              while e < 3 and row:sub(e + 1, e + 1) == "1" do e = e + 1 end
              local cx = x0 + (ci - 1) * 4 * px + (k - 1 + e) / 2 * px
              obox(root, c, o + ex * cx + ey * ((3 - r) * px) + en * 0.03, ex * ((e - k + 1) * px / 2 - 0.004), ey * (px / 2 - 0.004), en * 0.02)
              k = e + 1
            else
              k = k + 1
            end
          end
        end
      end
    end
  end
  -- A corrugated round tank from y0 to y1, capped capc.
  local function tank(root, x, z, y0, y1, r, n, capc)
    K.prism(piece(root, "tank"), {K.ring(v3(x, y0, z), r, r, n, 0), K.ring(v3(x, y1, z), r, r, n, 0)},
      function(_, k) return (k % 2 == 0) and IRON or IRON2 end, IRON2, capc)
  end

  -- ---------------------------------------------------------------- where
  local function gd(x, z) local y, d = K.ground_d(x, z); return y, d - K.HW end
  local taken = {}
  local function take(x, z, r) taken[#taken + 1] = {x, z, r} end
  local function free(x, z, r)
    for _, p in ipairs(PADS) do if pad_d(p, x, z) < p.r + r then return false end end
    for _, t in ipairs(taken) do
      local dx, dz = t[1] - x, t[2] - z
      if dx * dx + dz * dz < (t[3] + r) * (t[3] + r) then return false end
    end
    return true
  end
  -- A point beside the road, lo to hi metres off its edge (more of them near): x, z, the ground there, the sample.
  local function roadside(lo, hi, r)
    for _ = 1, 12 do
      local i = math.floor(rnd(3, N - 2))
      local side = (rnd(0, 1) < 0.5) and -1 or 1
      local f = rnd(0, 1)
      local p = pos[i] + right[i] * (side * (W[i] + lo + (hi - lo) * f * f))
      local y, o = gd(p.x, p.z)
      if o > lo * 0.85 and o > EDGE + 0.3 + (r or 0) and free(p.x, p.z, r or 0.3) then return p.x, p.z, y, i end
    end
    return nil
  end
  local function anywhere(clear, r)
    for _ = 1, 8 do
      local x, z = K.spot(clear)
      if x and free(x, z, r or 0.3) then return x, z, gy(x, z) end
    end
    return nil
  end
  local made = {}
  local function count(k, n) made[k] = (made[k] or 0) + (n or 1) end

  -- ---------------------------------------------------------------- the monolith and the domes
  do
    -- The rock: 124 m long, flat-topped, steep-sided, gullies down its flanks, south of the road, ahead of the start line down the valley.
    local CX, CZ, A, B, YAW = 58, -219, 58, 22, math.rad(-5)
    local cy, sy = math.cos(YAW), math.sin(YAW)
    local NP = 54
    local out, lo, hi, near = {}, math.huge, -math.huge, math.huge
    for k = 0, NP - 1 do
      local a = k / NP * math.pi * 2
      local ca, sa = math.abs(math.cos(a)), math.abs(math.sin(a))
      local r = 1 / ((ca / A) ^ 2.6 + (sa / B) ^ 2.6) ^ (1 / 2.6)
      r = r * (1 + 0.05 * math.sin(5 * a + 1) + 0.035 * math.sin(11 * a)) * ((k % 3 == 0) and 0.94 or 1)
      local lx, lz = math.cos(a) * r, math.sin(a) * r
      out[k + 1] = {lx * cy - lz * sy, lx * sy + lz * cy}
      local y, o = gd(CX + out[k + 1][1], CZ + out[k + 1][2])
      lo, hi, near = math.min(lo, y), math.max(hi, y), math.min(near, o)
    end
    local base, top = lo - 3, math.max(hi + 20, lo + 36)
    local PROF = {{0, 1}, {0.2, 0.985}, {0.46, 0.95}, {0.7, 0.88}, {0.87, 0.75}, {0.96, 0.55}, {1.0, 0.3}}
    local rings = {}
    for j, pf in ipairs(PROF) do
      local ring = {}
      for k = 1, NP do ring[k] = v3(CX + out[k][1] * pf[2], base + (top - base) * pf[1], CZ + out[k][2] * pf[2]) end
      rings[j] = ring
    end
    K.prism(piece(K.deco, "uluru"), rings, function(j, k)
      if j >= 5 then return (K.hash(j, k) < 0.3) and ROCK[2] or ROCK_HI end
      if k % 3 == 0 or k % 3 == 2 then return (j <= 2) and ROCK_LO or ROCK[3] end
      return (K.hash(k, j * 7) < 0.25) and ROCK[2] or ROCK[1]
    end, ROCK_LO, ROCK_HI)
    for k = -2, 2 do take(CX + k * 24 * cy, CZ + k * 24 * sy, 30) end
    info(string.format("monolith: ground %.1f to %.1f, top %.1f, %.1f m off the road", lo, hi, top, near))
    -- The domes: a huddle of round red heads far to the north-east, ahead of the run up to the finish.
    local DX, DZ = 272, -28
    for k, d in ipairs({{0, 0, 24, 30}, {26, 8, 18, 24}, {-20, 14, 17, 20}, {12, -22, 19, 26}, {-14, -18, 15, 18}, {34, -14, 13, 15}, {-34, -4, 12, 13}}) do
      local x, z = DX + d[1], DZ + d[2]
      local y = gy(x, z)
      K.ball(piece(K.deco, "domes"), v3(x, y - 2, z), d[3], d[4], d[3] * 0.9, 10, 6, function() return rnd(0.93, 1.06) end, function(w)
        local ny = w.y / math.max(1e-6, length(w))
        if ny > 0.6 then return ROCK_HI elseif ny > 0.2 then return ROCK[2] elseif ny > -0.1 then return ROCK[1] end
        return ROCK[3]
      end)
      take(x, z, d[3] + 2)
      count("domes")
    end
  end

  -- ---------------------------------------------------------------- the pub
  do
    local c = v3((PUB.ax + PUB.bx) / 2, 0, (PUB.az + PUB.bz) / 2)
    local u = normalize(v3(PUB.bx - PUB.ax, 0, PUB.bz - PUB.az))
    local w = v3(-u.z, 0, u.x)
    local _, o1 = gd(c.x + w.x * 8, c.z + w.z * 8)
    local _, o2 = gd(c.x - w.x * 8, c.z - w.z * 8)
    if o1 < o2 then w = w * -1 end          -- w: away from the road
    -- The floor: level with the ground at the uphill end, on stumps down the hill.
    local cc = c + w * 3
    local hi = K.lowest(cc, u, w, 7, 3.5)
    for _, a in ipairs({{-7, -0.5}, {-7, 6.5}, {-7, -4.3}}) do hi = math.max(hi, gy(c.x + u.x * a[1] + w.x * a[2], c.z + u.z * a[1] + w.z * a[2])) end
    hi = hi + 0.25
    local y0 = K.lowest(cc, u, w, 7, 3.5) - 0.6
    local F = frame(v3(c.x, hi, c.z), u, w, UP)
    K.hut(v3(cc.x, y0, cc.z), u, w, 7, 3.5, y0, hi + 3.3, function(k)
      if K.hash(k, 3) < 0.08 then return RUST end
      return (k % 2 == 0) and IRON or IRON2
    end, RUST, true, 1.9, 0.5)
    -- The verandah: a deck on stumps, posts, a lean-to roof in sheets, steps at the uphill end.
    box(F, K.solid, WOOD, -7.2, 7.2, -4.3, -0.56, -0.2, 0)
    for _, a in ipairs({-7, -3.5, 0, 3.5, 7}) do
      local p = F.P(a, -4.1, 0)
      beam(K.solid, WOOD2, v3(p.x, gy(p.x, p.z) - 0.4, p.z), p + UP * 2.66, 0.08, 0.08)
      local q = F.P(a, -0.9, 0)
      beam(K.solid, WOOD2, v3(q.x, gy(q.x, q.z) - 0.4, q.z), q - UP * 0.21, 0.1, 0.1)
    end
    do
      local dv = w * -1.9 + UP * -0.33
      local nn = normalize(cross(u, dv))
      for k = 0, 8 do
        obox(K.deco, (k % 2 == 0) and IRON_DK or IRON2, F.P(-6.56 + k * 1.64, -2.5, 2.95), u * 0.81, nn * 0.04, dv)
      end
    end
    box(F, K.solid, WOOD2, -8.3, -7.25, -3.6, -1.4, -0.5, -0.25)
    -- The door and the windows on the road's side, white-framed.
    box(F, K.deco, WOOD2, -1.5, -0.5, -0.57, -0.45, 0.02, 2.1)
    for _, a in ipairs({-4.6, 2.6}) do
      box(F, K.deco, WHITE, a - 1.0, a + 1.0, -0.56, -0.46, 0.95, 2.25)
      box(F, K.deco, GLASS, a - 0.85, a + 0.85, -0.6, -0.5, 1.08, 2.12)
    end
    -- The sign on the verandah's roof, to the road; a bench and drums on the deck.
    box(F, K.deco, RED, -2.2, 2.2, -4.26, -4.14, 2.75, 4.2)
    text(K.deco, WHITE, F.P(0, -4.27, 3.48), cross(w, UP), UP, w * -1, "PUB", 0.24)
    box(F, K.deco, WOOD2, 4.2, 6.2, -1.3, -0.8, 0.02, 0.5)
    for k, a in ipairs({-6.3, -5.5, 6.6}) do
      local p = F.P(a, -3.4 + (k % 2) * 0.5, 0)
      K.column(piece(K.deco, "drums"), p.x, p.z, p.y + 0.01, p.y + 0.9, 0.3, 0.3, 8, (k == 2) and BLUE or RUST)
    end
    -- The rainwater tank on its stand at the downhill end, and the dunny out the back at the other.
    do
      local p = F.P(9.9, 3, 0)
      local g0 = gy(p.x, p.z)
      for sa = -1, 1, 2 do for sb = -1, 1, 2 do
        beam(K.solid, WOOD2, v3(p.x + sa * 0.9, g0 - 0.6, p.z + sb * 0.9), v3(p.x + sa * 0.9, hi + 0.3, p.z + sb * 0.9), 0.09, 0.09)
      end end
      obox(K.solid, WOOD, v3(p.x, hi + 0.38, p.z), v3(1.3, 0, 0), v3(0, 0.07, 0), v3(0, 0, 1.3))
      tank(K.solid, p.x, p.z, hi + 0.46, hi + 3.0, 1.35, 14, IRON_DK)
      local q = F.P(-11, 6.5, 0)
      local D = frame(v3(q.x, gy(q.x, q.z) - 0.3, q.z), u, w, UP)
      box(D, K.solid, IRON2, -0.65, 0.65, -0.65, 0.65, 0, 2.5)
      obox(K.deco, RUST, D.P(0, 0, 2.62), u * 0.85, UP * 0.05 + w * 0.03, w * 0.85 + UP * -0.1)
      box(D, K.deco, WOOD2, -0.4, 0.4, -0.7, -0.6, 0.35, 2.2)
    end
    -- The roadside sign at the uphill end, to the karts coming down: PUB, FUEL.
    do
      local p = F.P(-12.5, -9.3, 0)
      local S = frame(v3(p.x, gy(p.x, p.z), p.z), w, u, UP)          -- a across, b down the road
      box(S, K.solid, IRON_DK, -0.14, 0.14, -0.14, 0.14, -0.6, 7.6)
      box(S, K.deco, RED, -1.9, 1.9, -0.26, -0.15, 5.2, 7.5)
      box(S, K.deco, YEL, -1.9, 1.9, -0.26, -0.15, 3.9, 5.14)
      local ex = cross(u, UP)
      text(K.deco, WHITE, S.P(0, -0.27, 6.35), ex, UP, u * -1, "PUB", 0.3)
      text(K.deco, BLACK, S.P(0, -0.27, 4.52), ex, UP, u * -1, "FUEL", 0.19)
    end
    -- The bowsers on their island: red, a white face, a glowing globe on top, a hose.
    for k, a in ipairs({1.2, 3.6}) do
      local p = F.P(a, -6.6, 0)
      local Bf = frame(v3(p.x, gy(p.x, p.z) - 0.25, p.z), u, w, UP)
      box(Bf, K.solid, CONC, -0.9, 0.9, -0.6, 0.6, 0, 0.5)
      box(Bf, K.solid, (k == 1) and RED or YEL, -0.33, 0.33, -0.24, 0.24, 0.51, 2.1)
      box(Bf, K.deco, WHITE, -0.24, 0.24, -0.27, 0.27, 1.25, 1.95)
      box(Bf, K.deco, DARK, -0.2, 0.2, -0.28, 0.28, 0.75, 1.1)
      K.ball(piece(K.deco, WHITE), Bf.P(0, 0, 2.38), 0.27, 0.27, 0.27, 6, 4, function() return 1 end, K.flat(WHITE))
      beam(K.deco, DARK, Bf.P(0.36, 0, 1.7), Bf.P(0.42, 0, 0.8), 0.03, 0.03)
      count("bowsers")
    end
    -- The ute at the bowsers: a white cab and bonnet, a flat tray, a bull bar, red dust to its sills.
    do
      local p = F.P(2.4, -8.7, 0)
      local V = gframe(p.x, p.z, u, 4.9, 1.8)
      box(V, K.solid, DARK, -2.4, 2.3, -0.8, 0.8, 0.3, 0.62)
      box(V, K.solid, UTE, 0.9, 2.4, -0.85, 0.85, 0.55, 1.08)
      box(V, K.solid, UTE, -0.5, 0.92, -0.88, 0.88, 0.63, 1.2)
      box(V, K.solid, UTE, -0.42, 0.7, -0.84, 0.84, 1.21, 1.78)
      box(V, K.deco, GLASS, 0.69, 0.76, -0.76, 0.76, 1.25, 1.7)
      box(V, K.deco, GLASS, -0.3, 0.55, -0.87, 0.87, 1.28, 1.68)
      box(V, K.solid, WOOD, -2.5, -0.56, -0.95, 0.95, 0.72, 0.82)
      for sb = -1, 1, 2 do box(V, K.deco, IRON_DK, -2.5, -0.56, sb * 0.93 - 0.03, sb * 0.93 + 0.03, 0.83, 1.12) end
      box(V, K.deco, IRON_DK, -0.62, -0.56, -0.9, 0.9, 0.83, 1.75)
      box(V, K.deco, IRON_DK, -2.52, -2.46, -0.9, 0.9, 0.83, 1.12)
      box(V, K.deco, STEEL, 2.45, 2.55, -0.95, 0.95, 0.4, 1.15)
      for sb = -1, 1, 2 do
        wheel(V, K.deco, 1.55, sb * 0.8, 0.38, 0.13)
        wheel(V, K.deco, -1.6, sb * 0.8, 0.38, 0.13)
        box(V, K.deco, YEL, 2.56, 2.6, sb * 0.6 - 0.14, sb * 0.6 + 0.14, 0.78, 1.0)
      end
      -- a dog in the tray: a blue heeler, sitting
      limb(K.deco, IRON_DK, V.P(-1.6, 0.2, 0.84), V.P(-1.4, 0.2, 1.35), 0.2, 0.15, 6)
      limb(K.deco, IRON_DK, V.P(-1.38, 0.2, 1.4), V.P(-1.12, 0.2, 1.5), 0.13, 0.07, 6)
    end
    count("pubs")
  end

  -- ---------------------------------------------------------------- the road train
  do
    local a0 = v3(LAYBY.ax, 0, LAYBY.az)
    local u = normalize(v3(LAYBY.bx - LAYBY.ax, 0, LAYBY.bz - LAYBY.az))
    local function unit(s, l) local p = a0 + u * s; return gframe(p.x, p.z, u, l, 2.5) end
    -- The prime mover: red bonnet and cab, a white sleeper roof, chrome stacks, tanks and bull bar.
    local V = unit(48.5, 7)
    box(V, K.solid, DARK, -3.5, 3.3, -0.55, 0.55, 0.55, 1.05)
    box(V, K.solid, TRUCK, 1.5, 3.3, -0.95, 0.95, 1.06, 2.15)
    box(V, K.solid, TRUCK, -0.4, 1.48, -1.22, 1.22, 1.06, 3.05)
    box(V, K.solid, WHITE, -1.7, -0.42, -1.22, 1.22, 1.06, 3.35)
    box(V, K.deco, GLASS, 1.47, 1.54, -1.08, 1.08, 2.25, 2.92)
    box(V, K.deco, GLASS, 0.1, 1.2, -1.25, 1.25, 2.2, 2.9)
    box(V, K.deco, STEEL, 3.32, 3.42, -0.8, 0.8, 1.15, 2.05)
    box(V, K.solid, STEEL, 3.5, 3.68, -1.3, 1.3, 0.45, 1.85)
    for k = -1, 1 do box(V, K.deco, DARK, 3.69, 3.73, k * 0.8 - 0.3, k * 0.8 + 0.3, 0.7, 1.6) end
    box(V, K.deco, YEL, 3.69, 3.74, -1.2, 1.2, 1.9, 2.3)
    for sb = -1, 1, 2 do
      box(V, K.deco, STEEL, -2.0, -1.8, sb * 1.12 - 0.09, sb * 1.12 + 0.09, 1.06, 4.3)
      limb(K.deco, STEEL, V.P(-1.4, sb * 1.0, 0.8), V.P(0.9, sb * 1.0, 0.8), 0.32, 0.32, 8)
      wheel(V, K.deco, 2.5, sb * 1.05, 0.52, 0.16)
      wheel(V, K.deco, -2.0, sb * 0.98, 0.52, 0.26)
      wheel(V, K.deco, -3.1, sb * 0.98, 0.52, 0.26)
      box(V, K.deco, YEL, 1.0, 1.3, sb * 1.0 - 0.12, sb * 1.0 + 0.12, 3.06, 3.2)
    end
    -- Three trailers: two double-deck stock crates and a fuel tanker, a dolly's wheels under each one's nose.
    for k = 1, 3 do
      local Tr = unit(48.5 - 3.5 - 1.1 - 6 - (k - 1) * 13.2, 12)
      box(Tr, K.solid, DARK, -6, 6, -1.2, 1.2, 1.05, 1.3)
      beam(K.deco, DARK, Tr.P(6, 0, 1.0), Tr.P(7.3, 0, 1.0), 0.08, 0.08)
      if k < 3 then
        box(Tr, K.solid, (k == 1) and IRON2 or IRON, -5.95, 5.95, -1.18, 1.18, 1.31, 4.3)
        for sb = -1, 1, 2 do
          for m = 0, 5 do box(Tr, K.deco, IRON_DK, -5.9, 5.9, sb * 1.2 - 0.03, sb * 1.2 + 0.03, 1.55 + m * 0.5, 1.75 + m * 0.5) end
          for m = -3, 3 do box(Tr, K.deco, STEEL, m * 1.95 - 0.07, m * 1.95 + 0.07, sb * 1.23 - 0.04, sb * 1.23 + 0.04, 1.32, 4.32) end
        end
      else
        tube(K.solid, IRON, {Tr.P(-5.9, 0, 2.6), Tr.P(-5.6, 0, 2.6), Tr.P(5.6, 0, 2.6), Tr.P(5.9, 0, 2.6)}, {0.9, 1.28, 1.28, 0.9}, 10)
        for sb = -1, 1, 2 do box(Tr, K.deco, RED, -5.2, 5.2, sb * 1.26 - 0.04, sb * 1.26 + 0.04, 2.35, 2.85) end
        box(Tr, K.deco, IRON_DK, -4.5, 4.5, -0.3, 0.3, 3.86, 3.98)
        -- the long-vehicle board across its tail
        box(Tr, K.deco, YEL, -6.12, -6.01, -1.15, 1.15, 1.35, 2.25)
        local ex = cross(Tr.U * -1, UP)
        text(K.deco, BLACK, Tr.P(-6.13, 0, 2.0), ex, Tr.N, Tr.U * -1, "ROAD", 0.07)
        text(K.deco, BLACK, Tr.P(-6.13, 0, 1.6), ex, Tr.N, Tr.U * -1, "TRAIN", 0.07)
      end
      for sb = -1, 1, 2 do
        for _, a in ipairs({-5.3, -4.15, -3.0, 4.0, 5.15}) do wheel(Tr, K.deco, a, sb * 0.98, 0.52, 0.26) end
        box(Tr, K.deco, RED, -6.06, -6.0, sb * 0.95 - 0.15, sb * 0.95 + 0.15, 1.08, 1.28)
      end
    end
    count("road trains")
  end

  -- ---------------------------------------------------------------- the windmills
  local function windmill(P, tank_side)
    local x, z = P.ax, P.az
    local i, best = 1, math.huge
    for k = 1, N do
      local dx, dz = pos[k].x - x, pos[k].z - z
      if dx * dx + dz * dz < best then best, i = dx * dx + dz * dz, k end
    end
    local f = normalize(v3(pos[i].x - x, 0, pos[i].z - z) + K.along(i) * -0.8)          -- the wheel faces up the road
    f = normalize(v3(f.x, 0, f.z))
    local s = v3(-f.z, 0, f.x)
    local g0 = gy(x, z)
    local top = v3(x, g0 + 10, z)
    local function leg(sa, sb, t)
      local b = v3(x, 0, z) + f * (sa * 1.4) + s * (sb * 1.4)
      b = v3(b.x, gy(b.x, b.z) - 0.4, b.z)
      local e = top + f * (sa * 0.22) + s * (sb * 0.22)
      return b + (e - b) * t
    end
    local CORN = {{1, 1}, {-1, 1}, {-1, -1}, {1, -1}}
    for q = 1, 4 do
      local a, b = CORN[q], CORN[q % 4 + 1]
      beam(K.solid, STEEL, leg(a[1], a[2], 0), leg(a[1], a[2], 1), 0.06, 0.06)
      for m = 1, 3 do
        beam(K.deco, STEEL, leg(a[1], a[2], m * 0.25 + (q % 2) * 0.012), leg(b[1], b[2], m * 0.25 + (q % 2) * 0.012), 0.035, 0.035)
        beam(K.deco, IRON_DK, leg(a[1], a[2], (m - 1) * 0.25 + 0.02), leg(b[1], b[2], m * 0.25 - 0.01), 0.025, 0.025)
      end
    end
    obox(K.deco, WOOD, top + UP * -1.6, f * 0.75, UP * 0.04, s * 0.75)
    -- The head: a gearbox, the wheel of sails with its rim, the tail and its vane.
    local H = top + UP * 0.45
    obox(K.deco, IRON_DK, H, f * 0.4, UP * 0.3, s * 0.22)
    beam(K.deco, IRON_DK, top + UP * -9.3, top + UP * 0.1, 0.03, 0.03)
    local hc = H + f * 0.62
    limb(K.deco, RED, H + f * 0.3, hc + f * 0.12, 0.2, 0.14, 6)
    local NB, pr = 16, nil
    for k = 0, NB do
      local a = k / NB * math.pi * 2
      local rad, tan = s * math.cos(a) + UP * math.sin(a), s * -math.sin(a) + UP * math.cos(a)
      if k < NB then
        local tw = normalize(tan * 0.92 + f * 0.38)
        obox(K.deco, (k % 2 == 0) and IRON or WHITE, hc + rad * 1.3, rad * 0.85, tw * 0.2, normalize(cross(rad, tw)) * 0.012)
      end
      local rp = hc + rad * 1.75 - f * 0.01
      if pr then
        local e = normalize(rp - pr) * 0.014
        beam(K.deco, STEEL, pr + e, rp - e, 0.03, 0.03)
      end
      pr = rp
    end
    beam(K.deco, STEEL, H - f * 0.3, H - f * 3.0, 0.04, 0.04)
    obox(K.deco, WHITE, H - f * 3.6, f * 0.85, UP * 0.6, s * 0.02)
    obox(K.deco, RED, H - f * 3.6, f * 0.5, UP * 0.2, s * 0.035)
    -- The tank beside it, full, and a trough the other side.
    local tc = v3(x, 0, z) + s * (tank_side * 4.6)
    local ty = math.min(gy(tc.x - 2.8, tc.z), gy(tc.x + 2.8, tc.z), gy(tc.x, tc.z - 2.8), gy(tc.x, tc.z + 2.8))
    local th = math.max(gy(tc.x, tc.z), g0) + 2.3
    tank(K.solid, tc.x, tc.z, ty - 0.5, th, 2.7, 18, WATER)
    beam(K.deco, IRON_DK, v3(x, g0 + 0.25, z), v3(tc.x, g0 + 0.3, tc.z) - s * (tank_side * 2.6), 0.05, 0.05)
    local qc = v3(x, 0, z) - s * (tank_side * 4.2) + f * 1.5
    local Tf = gframe(qc.x, qc.z, f, 3.2, 0.8)
    box(Tf, K.solid, CONC, -1.6, 1.6, -0.4, 0.4, -0.2, 0.5)
    box(Tf, K.deco, WATER, -1.45, 1.45, -0.28, 0.28, 0.3, 0.52)
    count("windmills")
  end
  windmill(MILL1, 1)
  windmill(MILL2, -1)

  -- ---------------------------------------------------------------- the signs
  -- A yellow diamond on a post beside the road at sample i, facing the karts coming down: a kangaroo or GRID.
  local function sign(i, side, kind)
    local p = pos[i] + right[i] * (side * (W[i] + EDGE + 1.0))
    local _, o = gd(p.x, p.z)
    if o < EDGE + 0.5 or not free(p.x, p.z, 0.5) then return end
    local t = K.along(i)
    local en = normalize(v3(-t.x, 0, -t.z))
    local ex = cross(en * -1, UP)
    local g0 = gy(p.x, p.z)
    local S = 1.25
    local c = v3(p.x, g0 + 3.3, p.z)
    beam(K.solid, IRON_DK, v3(p.x, g0 - 0.4, p.z) - en * 0.07, c - en * 0.07, 0.05, 0.04)
    local d1, d2 = (ex + UP) * (0.56 * S), (UP - ex) * (0.56 * S)
    obox(K.deco, BLACK, c - en * 0.012, d1 * 1.06, d2 * 1.06, en * 0.02)
    obox(K.deco, YEL, c + en * 0.005, d1, d2, en * 0.03)
    local layer = 0
    local function pb(x0, y0, x1, y1, th)
      layer = layer + 1
      local a, b = c + ex * (x0 * S) + UP * (y0 * S) + en * (0.06 + layer * 0.007), c + ex * (x1 * S) + UP * (y1 * S) + en * (0.06 + layer * 0.007)
      local d = (b - a) * 0.5
      obox(K.deco, BLACK, (a + b) * 0.5, d, normalize(cross(en, d)) * (th * S), en * 0.012)
    end
    if kind == 1 then
      local m = (side > 0) and -1 or 1          -- the kangaroo bounds towards the road
      pb(-0.22 * m, -0.08, 0.15 * m, 0.14, 0.13)
      pb(0.13 * m, 0.14, 0.31 * m, 0.34, 0.06)
      pb(0.27 * m, 0.36, 0.25 * m, 0.5, 0.025)
      pb(-0.2 * m, -0.1, -0.52 * m, -0.26, 0.04)
      pb(-0.12 * m, -0.08, 0.06 * m, -0.34, 0.06)
      pb(0.07 * m, -0.38, -0.14 * m, -0.4, 0.03)
      pb(0.14 * m, 0.06, 0.29 * m, -0.04, 0.03)
      count("kangaroo signs")
    else
      text(K.deco, BLACK, c + en * 0.04, ex, UP, en, "GRID", 0.075 * S)
      -- and under it a plate with the grid's bars
      local q = c + UP * (-1.2 * S)
      obox(K.deco, YEL, q, ex * 0.5, UP * 0.24, en * 0.03)
      for k = -2, 2 do obox(K.deco, BLACK, q + ex * (k * 0.18) + en * 0.06, ex * 0.045, UP * 0.17, en * 0.012) end
      count("grid signs")
    end
    take(p.x, p.z, 0.8)
  end
  for k, i in ipairs({16, 34, 50, 66, 84, 98, 124, 134, 146}) do
    sign(math.min(N - 2, i), (k % 2 == 0) and -1 or 1, (k % 2 == 1) and 1 or 2)
  end

  -- ---------------------------------------------------------------- the animals
  -- A kangaroo at p facing f (level): upright and watching, or bounding (lean, lift).
  local function roo(p, f, s, c, lean, lift)
    local sd = v3(-f.z, 0, f.x)
    local cs, sn = math.cos(lean), math.sin(lean)
    local function Q(a, h, b)
      local hh = h - 0.5
      return p + f * ((a * cs + hh * sn) * s) + UP * ((0.5 + lift - a * sn + hh * cs) * s) + sd * ((b or 0) * s)
    end
    local key = c
    tube(K.deco, c, {Q(-0.32, 0.4), Q(-0.1, 0.62), Q(0.12, 1.0), Q(0.2, 1.22)}, {0.15 * s, 0.3 * s, 0.22 * s, 0.13 * s}, 6, key)
    limb(K.deco, c, Q(0.18, 1.18), Q(0.3, 1.5), 0.1 * s, 0.11 * s, 6, key)
    limb(K.deco, c, Q(0.28, 1.52), Q(0.54, 1.44), 0.105 * s, 0.05 * s, 6, key, 0.5)
    tube(K.deco, c, {Q(-0.28, 0.44), Q(-0.75, 0.12), Q(-1.25, 0.05)}, {0.13 * s, 0.085 * s, 0.035 * s}, 5, key, 0.25)
    for sb = -1, 1, 2 do
      limb(K.deco, c, Q(-0.12, 0.62, sb * 0.2), Q(0.14, 0.2, sb * 0.22), 0.15 * s, 0.07 * s, 5, key)
      beam(K.deco, ROO_DK, Q(-0.08, 0.05, sb * 0.22), Q(0.42, 0.05, sb * 0.22), 0.055 * s, 0.04 * s)
      limb(K.deco, c, Q(0.2, 1.06, sb * 0.15), Q(0.38, 0.8, sb * 0.13), 0.05 * s, 0.035 * s, 4, key)
      beam(K.deco, ROO_DK, Q(0.24, 1.56, sb * 0.07), Q(0.2, 1.8, sb * 0.11), 0.045 * s, 0.015 * s, f)
    end
    count("kangaroos")
  end
  -- An emu at p facing f: a shaggy dark body, a long blue-grey neck, long legs.
  local function emu(p, f, s)
    local sd = v3(-f.z, 0, f.x)
    local function Q(a, h, b) return p + f * (a * s) + UP * (h * s) + sd * ((b or 0) * s) end
    K.prism(piece(K.deco, EMU), (function()
      local rings = {}
      for j, d in ipairs({{-0.62, 0.9, 0.1}, {-0.3, 1.05, 0.33}, {0.15, 1.08, 0.3}, {0.42, 1.14, 0.12}}) do
        local ring = {}
        for k = 0, 5 do
          local a = (k + 0.5) / 6 * math.pi * 2
          ring[#ring + 1] = Q(d[1], d[2] + math.sin(a) * d[3], math.cos(a) * d[3] * 0.85)
        end
        rings[j] = ring
      end
      return rings
    end)(), function(_, k) return (k <= 3) and EMU2 or EMU end, EMU, EMU)
    tube(K.deco, EMU_NECK, {Q(0.36, 1.16), Q(0.5, 1.6), Q(0.53, 1.92)}, {0.1 * s, 0.06 * s, 0.055 * s}, 5, nil, 0.25)
    limb(K.deco, EMU, Q(0.5, 1.93), Q(0.68, 1.95), 0.075 * s, 0.05 * s, 5)
    limb(K.deco, BLACK, Q(0.67, 1.94), Q(0.84, 1.91), 0.035 * s, 0.01 * s, 4, nil, 0.5)
    for sb = -1, 1, 2 do
      limb(K.deco, EMU_LEG, Q(sb * 0.08, 0.9, sb * 0.13), Q(-sb * 0.06, -0.15, sb * 0.13), 0.05 * s, 0.035 * s, 4)
      beam(K.deco, EMU_LEG, Q(-sb * 0.06 - 0.05, 0.03, sb * 0.13), Q(-sb * 0.06 + 0.22, 0.03, sb * 0.13), 0.05 * s, 0.025 * s)
    end
    count("emus")
  end
  local function mob(n, fn, lo, hi, spread)
    local x, z, _, i = roadside(lo, hi, 2.5)
    if not x then return end
    local heading = rnd(0, math.pi * 2)
    for _ = 1, n do
      local px, pz = x + rnd(-spread, spread), z + rnd(-spread, spread)
      local y, o = gd(px, pz)
      if o > EDGE + 1.6 and free(px, pz, 0.8) then
        local a = heading + rnd(-0.7, 0.7)
        fn(v3(px, y, pz), v3(math.cos(a), 0, math.sin(a)), i)
        take(px, pz, 0.9)
      end
    end
  end
  for m = 1, 8 do
    local hop = m % 3 == 0
    mob(math.floor(rnd(3, 5.99)), function(p, f, i)
      -- (the watchers turn to the road)
      if not hop and rnd(0, 1) < 0.6 then f = normalize(v3(pos[i].x - p.x, 0, pos[i].z - p.z)) end
      local s = rnd(1.15, 1.55)
      if hop then roo(p, f, s, K.pick(ROO), 0.55, rnd(0.25, 0.5)) else roo(p - UP * 0.06, f, s, K.pick(ROO), rnd(0, 0.15), 0) end
    end, 4.5, 20, 4)
  end
  for _ = 1, 5 do
    mob(math.floor(rnd(2, 4.99)), function(p, f) emu(p, f, rnd(1.1, 1.35)) end, 5, 24, 3.5)
  end

  -- ---------------------------------------------------------------- the outcrops
  local function outcrop(x, z, R)
    local n = math.floor(rnd(3, 6.99))
    for k = 1, n do
      local a, d = rnd(0, math.pi * 2), (k == 1) and 0 or rnd(0.3, 1) * R
      local px, pz = x + math.cos(a) * d, z + math.sin(a) * d
      local r = (k == 1) and R * rnd(0.5, 0.7) or R * rnd(0.22, 0.45)
      local y = gy(px, pz)
      local base = ROCK[1 + (k % 3)]
      K.ball(piece(K.deco, "rocks"), v3(px, y + r * 0.2, pz), r * rnd(0.85, 1.3), r * rnd(0.7, 1.15), r * rnd(0.85, 1.3), 6, 4,
        function() return rnd(0.78, 1.18) end, function(w)
          local ny = w.y / math.max(1e-6, length(w))
          if ny > 0.5 then return ROCK_HI elseif ny < -0.2 then return ROCK_LO end
          return base
        end)
    end
    -- A couple of tilted slabs leaning out of it.
    for _ = 1, math.floor(rnd(1, 3.99)) do
      local a = rnd(0, math.pi * 2)
      local d = v3(math.cos(a), 0, math.sin(a))
      local px, pz = x + d.x * R * 0.5, z + d.z * R * 0.5
      local l, tl = R * rnd(0.35, 0.6), rnd(0.25, 0.6)
      local e1 = normalize(d + UP * tl)
      local e2 = normalize(cross(e1, UP))
      local e3 = normalize(cross(e1, e2))
      obox(K.deco, K.pick(ROCK), v3(px, gy(px, pz) + l * 0.25, pz), e1 * l, e3 * (l * rnd(0.3, 0.5)), e2 * (l * rnd(0.5, 0.8)))
    end
    take(x, z, R * 1.1)
    count("outcrops")
  end
  for k = 1, 22 do
    local R = rnd(2.5, 5.5)
    local x, z
    if k <= 13 then x, z = roadside(9 + R, 55, R) else x, z = anywhere(30, R) end
    if x then outcrop(x, z, (k <= 13) and R or R * 1.6) end
  end

  -- ---------------------------------------------------------------- the trees
  -- A gum: a leaning trunk forking into two or three boughs, an open crown at the end of each. kind 1 a ghost gum
  -- (white bark, grey-green leaves), 2 a darker eucalypt, 3 a dead one.
  local function gum(x, z, y, s, kind)
    local trunk = (kind == 1) and ((rnd(0, 1) < 0.7) and GUM_W or GUM_W2) or ((kind == 2) and K.pick({BARK_R, BARK_D}) or GUM_W2)
    local leaf = (kind == 2) and K.pick(LEAF2) or K.pick(LEAF)
    local h = rnd(4.5, 7.5) * s
    local la = rnd(0, math.pi * 2)
    local base = v3(x, y - 0.5, z)
    local fork = v3(x, y, z) + UP * (h * 0.5) + v3(math.cos(la), 0, math.sin(la)) * (h * rnd(0.04, 0.14))
    limb(K.deco, trunk, base, fork, 0.24 * s, 0.16 * s, 5)
    local nb = (rnd(0, 1) < 0.5) and 2 or 3
    local a0 = rnd(0, math.pi * 2)
    for k = 1, nb do
      local a = a0 + k / nb * math.pi * 2 + rnd(-0.4, 0.4)
      local tip = fork + (v3(math.cos(a), 0, math.sin(a)) * rnd(1.0, 2.2) + UP * rnd(1.6, 3.0)) * s
      limb(K.deco, trunk, fork - UP * 0.1, tip, 0.13 * s, 0.06 * s, 5)
      if kind ~= 3 then
        K.ball(piece(K.deco, leaf), tip + UP * (0.3 * s), rnd(1.3, 2.1) * s, rnd(0.7, 1.05) * s, rnd(1.3, 2.1) * s, 6, 4,
          function() return rnd(0.8, 1.15) end, K.shaded(leaf))
      else
        local a2 = a + rnd(-1, 1)
        limb(K.deco, trunk, tip - UP * 0.05, tip + (v3(math.cos(a2), 0, math.sin(a2)) * 0.9 + UP * 1.1) * s, 0.06 * s, 0.025 * s, 4)
      end
    end
    take(x, z, 1.2)
    count("gums")
  end
  for k = 1, 150 do
    local x, z, y
    if k <= 95 then x, z, y = roadside(7.5, 60, 2.2) else x, z, y = anywhere(30, 2.2) end
    if x then
      local h = rnd(0, 1)
      gum(x, z, y, rnd(0.9, 1.35), (h < 0.55) and 1 or ((h < 0.92) and 2 or 3))
    end
  end

  -- ---------------------------------------------------------------- termite mounds and spinifex
  for k = 1, 130 do
    local x, z, y
    if k <= 95 then x, z, y = roadside(2.2, 45, 0.7) else x, z, y = anywhere(20, 0.7) end
    if x then
      local h = (rnd(0, 1) < 0.15) and rnd(3.4, 5) or rnd(1.1, 2.8)
      local r = h * rnd(0.26, 0.4)
      local turn = rnd(0, 6)
      local c1, c2 = K.pick(MOUND), K.pick(MOUND)
      K.prism(piece(K.deco, "mounds"), {
        K.ring(v3(x, y - rnd(0.3, 0.6), z), r, r * rnd(0.8, 1.1), 6, turn),
        K.ring(v3(x + rnd(-0.1, 0.1) * h, y + h * 0.5, z + rnd(-0.1, 0.1) * h), r * 0.72, r * 0.6, 6, turn + 0.3),
        K.ring(v3(x + rnd(-0.12, 0.12) * h, y + h, z + rnd(-0.12, 0.12) * h), r * 0.26, r * 0.22, 6, turn + 0.6),
      }, function(_, e) return (e % 2 == 0) and c1 or c2 end, c1, c2)
      take(x, z, r + 0.3)
      count("termite mounds")
    end
  end
  for k = 1, 760 do
    local x, z, y
    if k <= 560 then x, z, y = roadside(1.2, 50, 0.6) else x, z, y = anywhere(12, 0.6) end
    if x then
      local r = rnd(0.6, 1.35)
      local a, b = SPIN[(k % 2 == 0) and 1 or 2], SPIN[(k % 3 == 0) and 4 or 3]
      local q = piece(K.deco, "spinifex")
      local y1 = y - rnd(0.25, 0.4)
      local y2 = y1 + 0.12
      K.cone(q, K.ring(v3(x, y1, z), r, r * rnd(0.8, 1.1), 7, rnd(0, 6)), v3(x, y1, z), v3(x, y + r * 0.55, z),
        function(e) return (e % 2 == 0) and a or SPIN[2 - (k % 2)] end, a)
      K.cone(q, K.ring(v3(x, y2, z), r * 0.45, r * 0.45, 5, rnd(0, 6)), v3(x, y2, z), v3(x + rnd(-0.1, 0.1), y + r * 1.0, z + rnd(-0.1, 0.1)),
        function(e) return (e % 2 == 0) and b or SPIN[3] end, b)
      count("spinifex")
    end
  end

  local out = {}
  for k, n in pairs(made) do out[#out + 1] = n .. " " .. k end
  table.sort(out)
  info("outback: " .. table.concat(out, ", "))
end

return T
