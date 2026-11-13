-- The Alien Scrap Planet's scenery kit (see THEME KITS in _course.lua): a weird junk world of purple and teal ground
-- veined with glowing green cracks and pocked with craters. Teal and magenta crystal spires, heaps of metal scrap,
-- crashed rockets and a crashed flying saucer (another hovering on its beam), giant horseshoe magnets with red tips --
-- three of them arching over the road -- scrap and rocks afloat in their fields, bulbous plants with glowing tips,
-- a cratered moon and a ringed planet on tall pillars, and little green aliens watching from the verge.
-- Every piece is one colour's (K.sub by colour) but the banded and shaded ones, a few colours each.
local T = {trees = 0, rocks = 0.3}

-- Craters: one, or none, in each cell of a coarse grid, wholly inside it. Its distance from (x, z) in radii, and its
-- radius -- nil outside its rim.
local CELL = 48
local function crater(x, z, hash)
  local cx, cz = math.floor(x / CELL), math.floor(z / CELL)
  if hash(cx * 3.1 + 11, cz * 1.7 + 5) > 0.66 then return nil end
  local R = 8 + hash(cx + 0.5, cz + 7.3) * 6
  local m = R * 1.4 + 1
  local ox = cx * CELL + m + hash(cx + 2.2, cz + 9.1) * (CELL - 2 * m)
  local oz = cz * CELL + m + hash(cx + 4.7, cz + 1.3) * (CELL - 2 * m)
  local d = math.sqrt((x - ox) * (x - ox) + (z - oz) * (z - oz))
  if d > R * 1.4 then return nil end
  return d / R, R
end

-- The ground: a bowl with a raised rim at each crater (none within 8.5 m of the road's edge).
function T.shape(x, z, off, y, road_y, TK)
  if off < 8.5 then return nil end
  local t, R = crater(x, z, TK.hash)
  if not t then return nil end
  local f = math.min(1, (off - 8.5) / 7)
  if t < 1 then return y - R * 0.34 * (1 - t * t) * f end
  local u = (t - 1.2) / 0.2
  return y + R * 0.1 * (1 - u * u) * f
end

-- Its colour: purples with teal patches, glowing green cracks winding through, the craters dark with a pale rim and
-- a glowing pool in the bottom of some.
local PAL
function T.paint(x, z, off, ink, TK)
  if not PAL then
    PAL = {p1 = TK.col(0.3, 0.12, 0.42), p2 = TK.col(0.24, 0.09, 0.36), p3 = TK.col(0.38, 0.17, 0.5),
      deep = TK.col(0.14, 0.05, 0.24), t1 = TK.col(0.05, 0.4, 0.42), t2 = TK.col(0.04, 0.3, 0.36),
      glow = TK.col(0.3, 1.0, 0.2), glow2 = TK.col(0.6, 1.0, 0.3), rim = TK.col(0.55, 0.36, 0.66),
      verge = TK.col(0.34, 0.2, 0.44), verge2 = TK.col(0.28, 0.16, 0.4)}
  end
  if off < -0.5 then return nil end
  local h = TK.hash(math.floor(x / 5) + 3, math.floor(z / 5) + 17)
  if off > 2 and math.abs(noise3(x, 0, z, {frequency = 0.021, seed = 40})) < 0.028 then
    return (h > 0.7) and PAL.glow2 or PAL.glow
  end
  if off > 9 then
    local t = crater(x, z, TK.hash)
    if t then
      if t < 0.34 and TK.hash(math.floor(x / CELL) + 0.3, math.floor(z / CELL) + 0.9) < 0.35 then return PAL.glow end
      if t < 0.95 then return (h > 0.5) and PAL.deep or PAL.p2 end
      return PAL.rim
    end
  end
  if off < 4 then return (h > 0.5) and PAL.verge or PAL.verge2 end
  local n = noise3(x, 0, z, {frequency = 0.035, seed = 41})
  if n > 0.2 then return (h > 0.5) and PAL.t1 or PAL.t2 end
  if n < -0.3 then return (h > 0.6) and PAL.deep or PAL.p2 end
  return (h > 0.66) and PAL.p3 or ((h > 0.33) and PAL.p1 or PAL.p2)
end

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local function rnd(a, b) return K.g:range(a, b) end
  local function rint(a, b) return math.min(b, math.floor(rnd(a, b + 1))) end
  local EDGE = K.WALL_T + 1          -- the road's own margin: nothing of the kit's nearer its edge
  local D, S = K.deco, K.solid
  local function one() return 1 end

  local WHITE, BLACK = col(0.93, 0.93, 0.9), col(0.02, 0.02, 0.03)
  local GLOW, GLOW2 = col(0.3, 1.0, 0.2), col(0.6, 1.0, 0.3)
  local TEALS = {col(0.05, 0.75, 0.7), col(0.03, 0.5, 0.56), col(0.35, 0.95, 0.88)}
  local MAGS = {col(0.92, 0.1, 0.62), col(0.62, 0.05, 0.46), col(1.0, 0.42, 0.8)}
  local STEEL, STEEL2, STEEL3, DARK = col(0.55, 0.6, 0.68), col(0.4, 0.44, 0.52), col(0.72, 0.76, 0.82), col(0.13, 0.13, 0.17)
  local RED, RUST, RUST2 = col(0.9, 0.05, 0.04), col(0.55, 0.22, 0.08), col(0.4, 0.15, 0.06)
  local YEL, ORANGE, TEALM = col(0.98, 0.78, 0.05), col(0.98, 0.42, 0.03), col(0.1, 0.5, 0.55)
  local JUNK = {RUST, STEEL, YEL, TEALM, DARK, RUST2, STEEL3, ORANGE}
  local SCRAP = {col(0.3, 0.26, 0.26), col(0.42, 0.3, 0.2), col(0.22, 0.22, 0.27)}
  local ALIEN, ALIEN2, ALIEN_D = col(0.25, 0.85, 0.15), col(0.45, 0.9, 0.2), col(0.1, 0.5, 0.1)
  local TIPS = {col(0.7, 1.0, 0.2), col(0.3, 1.0, 0.9), col(1.0, 0.95, 0.3), col(1.0, 0.4, 0.85)}
  local BULBS = {{col(0.75, 0.12, 0.6), col(0.95, 0.5, 0.85)}, {col(0.95, 0.4, 0.05), col(1.0, 0.8, 0.2)},
    {col(0.15, 0.3, 0.9), col(0.4, 0.8, 1.0)}, {col(0.5, 0.15, 0.8), col(0.3, 1.0, 0.6)}}
  local STALKS = {col(0.08, 0.35, 0.4), col(0.3, 0.1, 0.45), col(0.1, 0.45, 0.3)}
  local GLASS, BEAM = col(0.2, 0.85, 0.9), col(0.65, 1.0, 0.6)
  local SMOKE = {col(0.12, 0.12, 0.14), col(0.22, 0.22, 0.25), col(0.33, 0.33, 0.36)}
  local ROCK, ROCK2, ROCK3 = col(0.36, 0.2, 0.5), col(0.26, 0.13, 0.38), col(0.5, 0.32, 0.62)

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
  -- A round tube through pts (parallel rings square to its whole run), radius rr[j] at each, n-sided; c a colour, or
  -- colour(j, k) with a key for its piece. `squash` flattens it the second way.
  local function tube(root, c, pts, rr, n, hint, squash, key)
    local fn = type(c) == "function"
    local q = piece(root, key or c)
    local e1, e2 = perp(normalize(pts[#pts] - pts[1]), hint)
    local rings = {}
    for j, p in ipairs(pts) do
      local ring = {}
      for k = 0, n - 1 do
        local a = (k + 0.5) / n * math.pi * 2
        ring[#ring + 1] = p + e1 * (math.cos(a) * rr[j]) + e2 * (math.sin(a) * rr[j] * (squash or 1))
      end
      rings[j] = ring
    end
    K.prism(q, rings, fn and c or K.flat(c), fn and c(1, 1) or c, fn and c(#pts - 1, 1) or c)
  end
  -- A bent tube through pts, each ring square to the run there; `nrm` the normal of the plane it bends in.
  local function pipe(root, c, pts, rr, n, nrm, key)
    local fn = type(c) == "function"
    local q = piece(root, key or c)
    local rings = {}
    for j, p in ipairs(pts) do
      local t = normalize(pts[math.min(#pts, j + 1)] - pts[math.max(1, j - 1)])
      local e1 = nrm - t * dot(nrm, t)
      if length(e1) < 0.05 then e1 = perp(t) else e1 = normalize(e1) end
      local e2 = cross(t, e1)
      local ring = {}
      for k = 0, n - 1 do
        local a = (k + 0.5) / n * math.pi * 2
        ring[#ring + 1] = p + e1 * (math.cos(a) * rr[j]) + e2 * (math.sin(a) * rr[j])
      end
      rings[j] = ring
    end
    K.prism(q, rings, fn and c or K.flat(c), fn and c(1, 1) or c, fn and c(#pts - 1, 1) or c)
  end
  local function limb(root, c, p0, p1, r0, r1, n) tube(root, c, {p0, p1}, {r0, r1}, n or 6) end
  local T3 = {-0.9, 0, 0.9}
  local T5 = {-0.95, -0.6, 0, 0.6, 0.95}
  -- An ellipsoid: half-length vector `axis`, radius r1 across (level, or across hint) and r2 the other way.
  local function egg(root, c, cen, axis, r1, r2, n, hint, key, ts)
    local pts, rr = {}, {}
    for _, t in ipairs(ts or T5) do
      pts[#pts + 1] = cen + axis * t
      rr[#rr + 1] = r1 * math.sqrt(1 - t * t)
    end
    tube(root, c, pts, rr, n or 7, hint, r2 / r1, key)
  end
  local function sph(root, c, cen, r, n) egg(root, c, cen, UP * r, r, r, n or 6) end
  local function blob(root, c, cen, r, n) egg(root, c, cen, UP * r, r, r, n or 5, nil, nil, T3) end

  -- ---------------------------------------------------------------- where
  local function off(x, z) local _, d = K.ground_d(x, z); return d - K.HW end   -- metres off the road's edge
  local function clear(x, z, m) return off(x, z) > EDGE + (m or 0.4) end
  -- A level direction from (x, z) along which `reach` metres on is still m clear of the road's margin (straight away
  -- from the road, where none of the random ones is).
  local function away(x, z, reach, m)
    for _ = 1, 8 do
      local a = K.g:range(0, 6.28)
      local o = v3(math.cos(a), 0, math.sin(a))
      if clear(x + o.x * reach, z + o.z * reach, m) and clear(x + o.x * reach * 0.5, z + o.z * reach * 0.5, m) then return o end
    end
    local d0 = off(x, z)
    local best, bo = -1e9, v3(1, 0, 0)
    for k = 0, 11 do
      local o = v3(math.cos(k * 0.5236), 0, math.sin(k * 0.5236))
      local d = off(x + o.x * 2, z + o.z * 2) - d0
      if d > best then best, bo = d, o end
    end
    return bo
  end
  local taken = {}
  local function free(x, z, R)
    for _, t in ipairs(taken) do
      local dx, dz = t[1] - x, t[2] - z
      if dx * dx + dz * dz < (t[3] + R) * (t[3] + R) then return false end
    end
    return true
  end
  local function take(x, z, R) taken[#taken + 1] = {x, z, R} end
  -- A place beside the road near sample i, its middle d past the margin and R clear all round: x, z, the sample, side.
  local function beside(i, side, d, R)
    for _, di in ipairs({0, 3, -3, 6, -6}) do
      for _, sd in ipairs({side, -side}) do
        local j = math.max(4, math.min(N - 3, i + di))
        local c = pos[j] + right[j] * (sd * (W[j] + EDGE + d + R))
        if clear(c.x, c.z, R + 0.3) and free(c.x, c.z, R) then
          take(c.x, c.z, R)
          return c.x, c.z, j, sd
        end
      end
    end
    return nil
  end
  -- A place on the slopes, R clear all round.
  local function slope(R, clr)
    for _ = 1, 6 do
      local x, z = K.spot(clr or (R + 6))
      if x and free(x, z, R) then take(x, z, R); return x, z end
    end
    return nil
  end
  -- The valley's mesh under (x, z): its 5 m grid's corners, between them as it is drawn.
  local STEP = math.max(5, math.ceil(math.sqrt((K.X1 - K.X0) * (K.Z0 - K.Z1) / 9000)))
  local corners = {}
  local function corner(c, r)
    local k = c * 4096 + r
    local v = corners[k]
    if not v then v = K.ground(K.X0 + c * STEP, K.Z0 - r * STEP); corners[k] = v end
    return v
  end
  local function mesh_y(x, z)
    local fc, fr = (x - K.X0) / STEP, (K.Z0 - z) / STEP
    local c, r = math.floor(fc), math.floor(fr)
    local u, v = fc - c, fr - r
    local a = corner(c, r) + (corner(c + 1, r) - corner(c, r)) * u
    local b = corner(c, r + 1) + (corner(c + 1, r + 1) - corner(c, r + 1)) * u
    return a + (b - a) * v
  end

  -- ---------------------------------------------------------------- crystals
  -- A cluster of faceted spires, one tall and the rest leaning out round it.
  local function crystals(x, z, s, set, root)
    local key = (set == TEALS) and "teal" or "magenta"
    local n = rint(3, 5)
    local a0 = rnd(0, 6.28)
    for k = 1, n do
      local a = a0 + k / n * 6.283 + rnd(-0.3, 0.3)
      local o = v3(math.cos(a), 0, math.sin(a))
      local main = (k == 1)
      local h = s * (main and rnd(4.5, 7) or rnd(1.6, 3.6))
      local r = h * 0.1 + 0.18 * s
      local bx, bz = x + (main and 0 or o.x * r * 2.2), z + (main and 0 or o.z * r * 2.2)
      local b = v3(bx, K.ground(bx, bz) - 0.6, bz)
      local d = normalize(UP + o * (main and rnd(0.02, 0.15) or rnd(0.3, 0.6)))
      local sides = main and 6 or 5
      local turn = rint(0, 2)
      tube(root or S, function(j, f) return set[(f + j + turn) % 3 + 1] end,
        {b, b + d * (h * 0.78), b + d * h}, {r, r * 0.85, 0.04}, sides, nil, nil, key)
    end
  end

  -- ---------------------------------------------------------------- scrap
  local function junk(p, o, s)
    local c = K.pick(JUNK)
    local e1, e2 = perp(o, v3(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)))
    local kind = rint(1, 5)
    if kind == 1 then
      obox(D, c, p, e1 * (s * rnd(0.5, 1.1)), e2 * (s * rnd(0.4, 0.9)), o * 0.06)
    elseif kind == 2 then
      limb(D, c, p - o * 0.5, p + o * (s * rnd(1.2, 2.6)), 0.15 * s, 0.15 * s, 6)
    elseif kind == 3 then
      beam(D, c, p - o * 0.6, p + normalize(o + e1 * rnd(-0.6, 0.6)) * (s * rnd(2, 3.4)), 0.13 * s, 0.2 * s)
    elseif kind == 4 then
      -- a cog: a disc with a hub and four teeth
      tube(D, c, {p, p + o * (0.28 * s)}, {0.7 * s, 0.7 * s}, 8)
      limb(D, DARK, p + o * (0.3 * s), p + o * (0.5 * s), 0.25 * s, 0.25 * s, 6)
      for q = 0, 3 do
        local w = e1 * math.cos(q * 1.5708 + 0.4) + e2 * math.sin(q * 1.5708 + 0.4)
        obox(D, c, p + o * (0.14 * s) + w * (0.82 * s), w * (0.16 * s), o * (0.12 * s), cross(o, w) * (0.16 * s))
      end
    else
      -- a bent fin: two plates
      obox(D, c, p, e1 * (s * 0.7), o * (s * 0.6), e2 * 0.05)
      obox(D, K.pick(JUNK), p + o * (s * 0.65) + e2 * (s * 0.3), e1 * (s * 0.55), normalize(o + e2) * (s * 0.4), normalize(o - e2) * 0.05)
    end
  end
  local function heap(x, z, r)
    local cen = v3(x, K.ground(x, z) - r * 0.12, z)
    K.ball(piece(S, "heap"), cen, r, r * 0.62, r, 9, 5, function() return rnd(0.8, 1.16) end, function(w)
      local h = K.hash(math.floor(w.x * 2.3) + x, math.floor(w.z * 2.3) + math.floor(w.y * 3) * 7)
      return (h < 0.4) and SCRAP[1] or ((h < 0.75) and SCRAP[2] or SCRAP[3])
    end)
    for _ = 1, rint(6, 9) do
      local a, e = rnd(0, 6.28), rnd(0.25, 1.4)
      local o = v3(math.cos(a) * math.cos(e), math.sin(e), math.sin(a) * math.cos(e))
      local js = rnd(0.7, 1.15) * math.min(1.5, r / 2.6)
      local jp = cen + v3(o.x * r * 0.8, o.y * r * 0.52, o.z * r * 0.8)
      if clear(jp.x + o.x * js * 3.6, jp.z + o.z * js * 3.6, 0.8) then junk(jp, o, js) end
    end
    return cen + UP * (r * 0.62)
  end
  -- Bits of scrap hanging in the air round p.
  local function afloat(p, n, spread, s)
    for _ = 1, n do
      local q = p + v3(rnd(-spread, spread), rnd(-spread * 0.4, spread), rnd(-spread, spread))
      if clear(q.x, q.z, 1.2) then
        local o = normalize(v3(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)) + UP * 0.01)
        local e1, e2 = perp(o)
        local c = K.pick(JUNK)
        if rnd(0, 1) < 0.6 then
          obox(D, c, q, e1 * (s * rnd(0.3, 0.7)), e2 * (s * rnd(0.25, 0.5)), o * 0.05)
        else
          limb(D, c, q, q + o * (s * rnd(0.6, 1.4)), 0.1 * s, 0.1 * s, 5)
        end
      end
    end
  end

  -- ---------------------------------------------------------------- magnets
  -- A horseshoe: its tips at base -+ a*R, its legs L along u, the bend beyond; th its half thickness, the tips red
  -- for tipL.
  local function magnet(root, base, a, u, R, L, th, tipL)
    local pts = {base - a * R, base - a * R + u * tipL, base - a * R + u * L}
    local cen = base + u * L
    for k = 1, 7 do
      local ang = math.pi - k * math.pi / 8
      pts[#pts + 1] = cen + a * (R * math.cos(ang)) + u * (R * math.sin(ang))
    end
    pts[#pts + 1] = base + a * R + u * L
    pts[#pts + 1] = base + a * R + u * tipL
    pts[#pts + 1] = base + a * R
    local rr = {}
    for j = 1, #pts do rr[j] = th * 1.4142 end
    local last = #pts - 1
    pipe(root, function(j, k)
      if j == 1 or j == last then return RED end
      return (k % 2 == 0) and STEEL or STEEL3
    end, pts, rr, 4, normalize(cross(a, u)), "magnet")
  end
  -- One arching over the road at sample i, its red tips in the ground either side; false where it would not fit.
  local function arch(i)
    local th = 0.9
    local R = W[i] + EDGE + 1.4 + th
    local a = right[i]
    if dot(K.along(math.max(1, i - 10)), K.along(math.min(N, i + 10))) < 0.94 then return false end
    for _, sd in ipairs({-1, 1}) do
      local p = pos[i] + a * (sd * R)
      if not clear(p.x, p.z, th * 1.5 + 0.2) or not free(p.x, p.z, th * 1.5) then return false end
    end
    -- nowhere over another stretch of the road lower than it should be
    for k = -8, 8 do
      local s = k / 8 * (R + th)
      local p = pos[i] + a * s
      local y, d = K.ground_d(p.x, p.z)
      if d - K.HW < EDGE and math.abs(y + 0.5 - pos[i].y) > 1.5 then return false end
    end
    for _, sd in ipairs({-1, 1}) do
      local p = pos[i] + a * (sd * R)
      take(p.x, p.z, th * 1.6)
    end
    magnet(S, pos[i] - UP * 2.2, a, UP, R, 5.8, th, 4.6)
    return true
  end
  -- One standing on its bend beside the road, tips up, scrap afloat over them.
  local function standing(x, z, s)
    local an = rnd(0, 6.28)
    local o = v3(math.cos(an), 0, math.sin(an))
    local u = normalize(UP * -1 + o * rnd(0.05, 0.3))
    local a = normalize(cross(u, o + UP * 0.01))
    local R, L, th = 1.5 * s, 3.0 * s, 0.5 * s
    local top = v3(x, K.ground(x, z), z) - u * ((L + R + th) * 0.93)
    magnet(S, top, a, u, R, L, th, 1.3 * s)
    afloat(top + UP * (1.6 * s), rint(5, 8), 1.9 * s, s)
  end

  -- ---------------------------------------------------------------- plants
  local function tip(p, r) blob(D, K.pick(TIPS), p, r, 5) end
  -- A stalk from b, h tall, bending the way `dir`: its points.
  local function stalk(b, h, dir, bend, n)
    local pts = {}
    for k = 0, n do
      local f = k / n
      pts[#pts + 1] = b + UP * (h * (f - 0.25 * f * f * bend)) + dir * (bend * h * f * f * 0.6)
    end
    return pts
  end
  local function plant(x, z, s, kind)
    local b = v3(x, K.ground(x, z) - 0.2, z)
    local set = K.pick(BULBS)
    local sc = K.pick(STALKS)
    local a0 = rnd(0, 6.28)
    if kind == 1 then
      -- a fat spotted pod, glowing-tipped feelers curling out of its top
      local r = s * rnd(0.7, 1.1)
      egg(S, function(j, k) return ((j * 2 + k) % 3 == 0) and set[2] or set[1] end, b + UP * (r * 0.9), UP * (r * 1.15), r, r, 7,
        nil, tostring(set[1]) .. "pod")
      local top = b + UP * (r * 1.95)
      local n = rint(3, 5)
      for k = 1, n do
        local a = a0 + k / n * 6.283
        local dir = v3(math.cos(a), 0, math.sin(a))
        local pts = stalk(top - UP * 0.15, s * rnd(1.0, 1.9), dir, rnd(0.6, 1.3), 3)
        pipe(D, sc, pts, {0.09 * s, 0.075 * s, 0.06 * s, 0.05 * s}, 4, cross(UP, dir))
        tip(pts[4], 0.2 * s)
      end
    elseif kind == 2 then
      -- a tall stalk nodding over, a big glowing bulb hung from its end and lesser ones up it
      local h = s * rnd(3.6, 5.6)
      local dir = away(x, z, h * 0.85, 1)
      local pts = stalk(b, h, dir, rnd(0.7, 1.1), 5)
      pts[#pts + 1] = pts[6] + dir * (h * 0.14) - UP * (h * 0.1)
      pipe(S, sc, pts, {0.3 * s, 0.25 * s, 0.21 * s, 0.17 * s, 0.14 * s, 0.11 * s, 0.09 * s}, 5, cross(UP, dir))
      egg(S, function(j, k) return ((j + k) % 2 == 0) and set[1] or set[2] end, b + UP * (0.35 * s), UP * (0.5 * s), 0.6 * s, 0.6 * s, 6,
        nil, tostring(set[1]) .. "pod", T3)
      local e = pts[7] - UP * (0.45 * s)
      egg(D, K.pick(TIPS), e, UP * (0.6 * s), 0.45 * s, 0.45 * s, 6)
      for k = 2, 4 do
        local side = cross(UP, dir) * ((k % 2 == 0) and 1 or -1)
        local q = pts[k + 1] + side * (0.45 * s)
        limb(D, sc, pts[k + 1], q, 0.05 * s, 0.05 * s, 3)
        blob(D, set[2], q + side * (0.15 * s), 0.22 * s, 5)
      end
    else
      -- a stack of puffballs, the top one alight
      local y = 0
      local r = s * rnd(0.55, 0.8)
      for k = 1, 3 do
        local c = b + UP * (y + r * 0.8) + v3(rnd(-0.12, 0.12), 0, rnd(-0.12, 0.12)) * s
        if k < 3 then
          K.ball(piece(S, tostring(set[1]) .. "puff"), c, r, r * 0.8, r, 7, 4, one, function(w)
            return (w.y > r * 0.25) and set[2] or set[1]
          end)
        else
          sph(D, K.pick(TIPS), c, r, 6)
        end
        y = y + r * 1.4
        r = r * 0.72
      end
    end
  end

  -- ---------------------------------------------------------------- aliens
  -- A little green one at (x, z) facing f: a big head, black eyes, two feelers with lit ends, an arm or two up.
  local function alien(x, z, f, s, y)
    local sd = normalize(cross(UP, f))
    local p = v3(x, y or K.ground(x, z), z)
    local g = (rnd(0, 1) < 0.5) and ALIEN or ALIEN2
    for _, m in ipairs({-1, 1}) do
      limb(D, ALIEN_D, p + sd * (m * 0.14 * s) - UP * 0.15, p + sd * (m * 0.11 * s) + UP * (0.42 * s), 0.07 * s, 0.09 * s, 4)
    end
    egg(D, g, p + UP * (0.64 * s), UP * (0.34 * s), 0.27 * s, 0.22 * s, 6, f)
    local head = p + UP * (1.22 * s)
    egg(D, g, head, UP * (0.31 * s), 0.43 * s, 0.35 * s, 7, f)
    for _, m in ipairs({-1, 1}) do
      egg(D, BLACK, head + f * (0.27 * s) + sd * (m * 0.17 * s) + UP * (0.03 * s), normalize(UP * 0.8 + sd * (m * 0.55)) * (0.16 * s),
        0.1 * s, 0.07 * s, 5, f, nil, T3)
      local e = head + sd * (m * 0.34 * s) + UP * (0.62 * s)
      limb(D, ALIEN_D, head + sd * (m * 0.14 * s) + UP * (0.25 * s), e, 0.028 * s, 0.022 * s, 3)
      blob(D, TIPS[3], e, 0.075 * s, 4)
      local sh = p + UP * (0.82 * s) + sd * (m * 0.2 * s)
      local up = rnd(0, 1) < 0.55
      limb(D, g, sh, sh + sd * (m * 0.36 * s) + UP * ((up and 0.45 or -0.3) * s) + f * (0.08 * s), 0.055 * s, 0.045 * s, 4)
    end
  end
  -- A few of them together, looking at (tx, tz).
  local function crowd(x, z, n, tx, tz)
    for k = 1, n do
      local px, pz = x + rnd(-0.25, 0.25) + (k - (n + 1) / 2) * 0, z + rnd(-0.25, 0.25)
      if k > 1 then
        local a = rnd(0, 6.28)
        px, pz = x + math.cos(a) * rnd(0.9, 1.5), z + math.sin(a) * rnd(0.9, 1.5)
      end
      if clear(px, pz, 0.6) then
        local f = v3(tx - px, 0, tz - pz)
        if length(f) > 0.1 then alien(px, pz, normalize(f), rnd(0.95, 1.3)) end
      end
    end
  end

  -- ---------------------------------------------------------------- ships
  local function smoke(p, s, lean)
    local r = 0.5 * s
    local q = p
    for k = 1, 4 do
      q = q + UP * (r * 1.5) + lean * (r * 0.7)
      r = r * 1.32
      local c = SMOKE[math.min(3, k)]
      K.ball(piece(D, c, c), q, r, r * 0.85, r, 6, 4, function() return rnd(0.8, 1.15) end, function() return c end)
    end
  end
  -- A rocket nose-down in the ground, its tail in the air and smoking.
  local function rocket(x, z, s)
    local o = away(x, z, 9 * s, 2.5)
    local d = normalize(UP + o * rnd(0.3, 0.75))
    local nose = v3(x, K.ground(x, z) - 1.3 * s, z)
    local L, r = 7.5 * s, 1.0 * s
    local c2 = K.pick({RED, ORANGE, TEALM, MAGS[1]})
    tube(S, function(j, _) return (j == 1 or j == 4) and c2 or ((j == 3) and WHITE or STEEL3) end,
      {nose, nose + d * (L * 0.2), nose + d * (L * 0.42), nose + d * (L * 0.62), nose + d * (L * 0.88), nose + d * L},
      {0.06, r * 0.62, r, r, r, r * 0.72}, 8, nil, nil, tostring(c2) .. "rocket")
    local e1, e2 = perp(d)
    for k = 0, 2 do
      local a = k * 2.094 + 0.5
      local w = e1 * math.cos(a) + e2 * math.sin(a)
      obox(S, c2, nose + d * (L * 0.86) + w * (r * 1.45), w * (r * 0.62), d * (L * 0.12), cross(d, w) * (0.07 * s))
      blob(D, GLASS, nose + d * (L * 0.55) + (e1 * math.cos(a + 1) + e2 * math.sin(a + 1)) * (r * 0.93), 0.3 * s, 6)
    end
    limb(S, DARK, nose + d * (L + 0.02), nose + d * (L * 1.1), r * 0.45, r * 0.62, 6)
    smoke(nose + d * (L * 1.1), s, d * 0.3 + o * 0.4)
  end
  -- A flying saucer: its middle c, its axis ax, R across.
  local function saucer(root, c, ax, R)
    tube(root, function(j, k)
      if j == 1 then return DARK elseif j == 2 then return STEEL2 elseif j == 3 then return (k % 2 == 0) and STEEL3 or STEEL end
      return STEEL
    end, {c - ax * (R * 0.22), c - ax * (R * 0.12), c, c + ax * (R * 0.1), c + ax * (R * 0.2)},
      {R * 0.3, R * 0.75, R, R * 0.72, R * 0.42}, 14, nil, nil, "saucer")
    egg(D, GLASS, c + ax * (R * 0.2), ax * (R * 0.3), R * 0.38, R * 0.38, 8)
    limb(D, MAGS[1], c - ax * (R * 0.225), c - ax * (R * 0.3), R * 0.26, R * 0.18, 8)
    local e1, e2 = perp(ax)
    for k = 0, 9 do
      local a = k / 10 * 6.283
      blob(D, TIPS[k % 4 + 1], c + (e1 * math.cos(a) + e2 * math.sin(a)) * (R * 0.87) + ax * (R * 0.07), R * 0.075, 5)
    end
  end

  -- ---------------------------------------------------------------- moons
  -- Somewhere out past sample i on `side`, far from the road and inside the valley.
  local function far(i, side)
    for _, sd in ipairs({side, -side}) do
      for d = 50, 110, 6 do
        local p = pos[i] + right[i] * (sd * d)
        if p.x > K.X0 + 20 and p.x < K.X1 - 20 and p.z > K.Z1 + 20 and p.z < K.Z0 - 20 and off(p.x, p.z) > 40 then return p.x, p.z end
      end
    end
    return (side > 0) and (K.X1 - 24) or (K.X0 + 24), (K.Z0 + K.Z1) * 0.5
  end
  local function pillar(x, z, h, r)
    local y = K.ground(x, z)
    local q = piece(S, "pillar")
    K.prism(q, {K.ring(v3(x, y - 3, z), r * 1.7, r * 1.7, 8, 0), K.ring(v3(x, y + h * 0.3, z), r, r, 8, 0.3),
      K.ring(v3(x, y + h * 0.75, z), r * 0.8, r * 0.8, 8, 0.6), K.ring(v3(x, y + h, z), r * 1.5, r * 1.5, 8, 0.9)},
      function(j, k) return ((j + k) % 2 == 0) and ROCK or ROCK2 end, ROCK2, ROCK3)
    take(x, z, r * 2 + 2)
    return v3(x, y + h, z)
  end
  do
    -- a pale cratered moon
    local x, z = far(math.floor(N * 0.3), 1)
    local R = 14
    local c = pillar(x, z, 30, 2.6) + UP * (R * 0.85)
    local pits = {}
    for k = 1, 9 do pits[k] = {normalize(v3(rnd(-1, 1), rnd(-0.8, 0.9), rnd(-1, 1))), rnd(0.9, 0.975)} end
    local M1, M2, M3 = col(0.85, 0.82, 0.68), col(0.55, 0.52, 0.5), col(0.95, 0.93, 0.8)
    K.ball(piece(D, "moon"), c, R, R, R, 16, 10, one, function(w)
      local n = normalize(w)
      for _, p in ipairs(pits) do
        local q = dot(n, p[1])
        if q > p[2] then return M2 end
        if q > p[2] - 0.022 then return M3 end
      end
      return M1
    end)
    crystals(x + 6, z + 3, 1.8, MAGS)
    crystals(x - 5, z - 5, 1.5, TEALS)
    -- a banded planet with a ring round it
    x, z = far(math.floor(N * 0.72), -1)
    R = 11
    c = pillar(x, z, 34, 2.3) + UP * (R * 0.85)
    local B = {col(0.95, 0.45, 0.1), col(0.85, 0.2, 0.45), col(1.0, 0.7, 0.3), col(0.6, 0.15, 0.55)}
    K.ball(piece(D, "planet"), c, R, R * 0.95, R, 16, 10, one, function(w)
      return B[math.floor((w.y / R + 1) * 4.49) % 4 + 1]
    end)
    local ax = normalize(v3(0.35, 1, 0.2))
    local e1, e2 = perp(ax)
    local n = 20
    for k = 0, n - 1 do
      local a0, a1 = (k + 0.04) / n * 6.283, (k + 0.96) / n * 6.283
      local function at(a, r, h) return c + (e1 * math.cos(a) + e2 * math.sin(a)) * r + ax * h end
      local ri, ro = R * 1.35, R * 1.9
      K.hexa(piece(D, TEALS[k % 2 + 1], TEALS[k % 2 + 1]), at(a0, ri, -0.15), at(a1, ri, -0.15), at(a1, ro, -0.15), at(a0, ro, -0.15),
        at(a0, ri, 0.15), at(a1, ri, 0.15), at(a1, ro, 0.15), at(a0, ro, 0.15))
    end
    crystals(x - 6, z + 4, 1.8, TEALS)
    crystals(x + 5, z - 5, 1.5, MAGS)
  end

  -- ---------------------------------------------------------------- the big pieces, along the road
  local function at_frac(f) return math.max(12, math.min(N - 8, math.floor(N * f))) end
  -- Magnets arching over the road.
  for _, f in ipairs({0.13, 0.4, 0.63, 0.86}) do
    local i0 = at_frac(f)
    for _, di in ipairs({0, 4, -4, 8, -8, 12, -12, 16, -16, 20, -20}) do
      local i = i0 + di
      if i > K.start + 14 and math.abs(i - K.fin) > 14 and i < N - 6 and arch(i) then
        afloat(pos[i] + UP * 15.5, 6, 2.6, 1.2)
        break
      end
    end
  end
  -- The crashed saucer, its rim dug into the ground, smoking; aliens gathered round it.
  do
    local x, z, j, sd = beside(at_frac(0.24), 1, 2.5, 6.5)
    if x then
      local R = 6.2
      local o = right[j] * -sd
      local ax = normalize(UP + (o + K.along(j) * 0.5) * 0.55)
      local c = v3(x, K.ground(x, z) + R * 0.2, z)
      saucer(S, c, ax, R)
      smoke(c + ax * (R * 0.3) - o * (R * 0.5), 1.5, v3(0.3, 0, 0.2))
      for k = 1, 5 do
        local a = k * 1.3
        local px, pz = x + math.cos(a) * (R + 1.6), z + math.sin(a) * (R + 1.6)
        if clear(px, pz, 0.6) then alien(px, pz, normalize(v3(x - px, 0, z - pz)), rnd(1, 1.3)) end
      end
      for _ = 1, 3 do junk(c + v3(rnd(-R, R), 0.4, rnd(-R, R)) * 1.25, normalize(v3(rnd(-1, 1), 1, rnd(-1, 1))), 1) end
    end
  end
  -- Saucers hovering on their beams.
  for _, f in ipairs({0.52, 0.93}) do
    local x, z = beside(at_frac(f), -1, 3.5, 4.8)
    if x then
      local y = K.ground(x, z)
      local c = v3(x, y + 13, z)
      local ax = normalize(UP + v3(rnd(-0.12, 0.12), 0, rnd(-0.12, 0.12)))
      saucer(D, c, ax, 4.6)
      K.cone(piece(D, BEAM, BEAM), K.ring(v3(x, y - 0.3, z), 2.7, 2.7, 8, 0), v3(x, y - 0.4, z), c - ax * 1.2, K.flat(BEAM), BEAM)
      heap(x, z, 1.6)
      afloat(v3(x, y + 5, z), 7, 1.3, 0.8)
    end
  end
  -- Crashed rockets.
  for k, f in ipairs({0.07, 0.33, 0.47, 0.7, 0.8, 0.97}) do
    local x, z = beside(at_frac(f), (k % 2 == 0) and 1 or -1, rnd(2.5, 6), 2.6)
    if x then rocket(x, z, rnd(0.9, 1.25)) end
  end
  -- Magnets standing beside it.
  for k, f in ipairs({0.04, 0.18, 0.28, 0.44, 0.57, 0.67, 0.76, 0.9}) do
    local x, z = beside(at_frac(f), (k % 2 == 0) and -1 or 1, rnd(1.5, 4), 2.8)
    if x then standing(x, z, rnd(1.1, 1.6)) end
  end

  -- ---------------------------------------------------------------- the rest, down both sides
  local i = 9
  while i < N - 5 do
    for _, side in ipairs({1, -1}) do
      local c = rnd(0, 1)
      if c < 0.26 then
        local s = rnd(0.8, 1.3)
        local x, z = beside(i, side, rnd(0.6, 4), 1.7 * s)
        if x then crystals(x, z, s, (rnd(0, 1) < 0.5) and TEALS or MAGS) end
      elseif c < 0.4 then
        local r = rnd(2, 3.4)
        local x, z, j, sd = beside(i, side, rnd(1, 5), r)
        if x then
          local top = heap(x, z, r)
          if rnd(0, 1) < 0.5 then alien(top.x, top.z, right[j] * -sd, rnd(0.95, 1.2), top.y - 0.25) end
          if rnd(0, 1) < 0.35 then afloat(top + UP * 3, 5, 1.6, 0.9) end
        end
      elseif c < 0.66 then
        local s = rnd(0.85, 1.35)
        local x, z = beside(i, side, rnd(0.4, 4), 1.1 * s)
        if x then plant(x, z, s, rint(1, 3)) end
      elseif c < 0.92 then
        local x, z, j, sd = beside(i, side, rnd(0.3, 1.2), 0.8)
        if x then
          local t = pos[j]
          crowd(x, z, rint(1, 3), t.x, t.z)
        end
      end
    end
    i = i + rint(5, 8)
  end

  -- ---------------------------------------------------------------- the slopes: bigger and sparser
  for k = 1, 46 do
    local s = rnd(1.5, 2.8)
    local x, z = slope(2.2 * s, 7)
    if x then crystals(x, z, s, (k % 2 == 0) and TEALS or MAGS) end
  end
  for _ = 1, 24 do
    local r = rnd(3, 5.5)
    local x, z = slope(r, r + 5)
    if x then
      local top = heap(x, z, r)
      if rnd(0, 1) < 0.4 then afloat(top + UP * 4, 6, 2.2, 1.3) end
    end
  end
  for _ = 1, 44 do
    local s = rnd(1.5, 2.6)
    local x, z = slope(1.3 * s, 6)
    if x then plant(x, z, s, rint(1, 3)) end
  end
  for _ = 1, 5 do
    local x, z = slope(3.5, 9)
    if x then rocket(x, z, rnd(1.3, 1.8)) end
  end
  for _ = 1, 5 do
    local x, z = slope(4, 9)
    if x then standing(x, z, rnd(1.8, 2.4)) end
  end
  -- Rocks afloat in the low gravity, a crystal or two grown on each.
  for _ = 1, 14 do
    local r = rnd(1.4, 2.8)
    local x, z = slope(r, r + 6)
    if x then
      local c = v3(x, K.ground(x, z) + rnd(5, 11), z)
      K.ball(piece(D, "floater"), c, r, r * 0.6, r * 0.85, 7, 5, function() return rnd(0.78, 1.2) end, function(w)
        return (w.y > r * 0.2) and ROCK3 or ((w.y > -r * 0.2) and ROCK or ROCK2)
      end)
      local set = (rnd(0, 1) < 0.5) and TEALS or MAGS
      local key = (set == TEALS) and "teal" or "magenta"
      tube(D, function(j, f) return set[(f + j) % 3 + 1] end, {c + UP * (r * 0.3), c + UP * (r * 1.3), c + UP * (r * 1.7)},
        {r * 0.22, r * 0.18, 0.04}, 5, nil, nil, key)
      tube(D, function(j, f) return ROCK2 end, {c - UP * (r * 0.4), c - UP * (r * 1.5)}, {r * 0.5, 0.05}, 5, nil, nil, ROCK2)
    end
  end

  -- ---------------------------------------------------------------- glowing veins by the road
  -- A jagged crack of light lying on the ground, forking now and then.
  local function vein(x, z, a, n, w)
    local p = v3(x, mesh_y(x, z) + 0.02, z)
    for k = 1, n do
      a = a + rnd(0.35, 1.0) * ((k % 2 == 0) and 1 or -1)
      local len = rnd(1.4, 2.6)
      local nx, nz = x + math.cos(a) * len, z + math.sin(a) * len
      if not clear(nx, nz, 0.3) then return end
      local q = v3(nx, mesh_y(nx, nz) + 0.02 + (k % 2) * 0.012, nz)
      beam(D, (k % 3 == 0) and GLOW2 or GLOW, p, q, w * (1 - k * 0.07), 0.1)
      if k == 2 and n > 3 and rnd(0, 1) < 0.5 then vein(nx, nz, a + 1.3, 2, w * 0.7) end
      p, x, z = q, nx, nz
    end
  end
  i = 6
  while i < N - 4 do
    for _, side in ipairs({1, -1}) do
      if rnd(0, 1) < 0.7 then
        local c = pos[i] + right[i] * (side * (W[i] + EDGE + rnd(0.6, 7)))
        if clear(c.x, c.z, 0.4) then vein(c.x, c.z, rnd(0, 6.28), rint(4, 6), 0.2) end
      end
    end
    i = i + rint(3, 5)
  end
end

return T
