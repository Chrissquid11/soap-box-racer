-- The World's Worst Zoo's scenery kit (see THEME KITS in _course.lua): tired pens of wonky wooden and torn chain
-- fences beside the road -- giraffes peering over theirs, elephants, a yawning hippo in a mud pond, penguins on a
-- cracked concrete pool, a bored lion on a rock, flamingos -- giant enrichment balls lying about, a ZOO entrance
-- arch (its last O slipping), a gift shop, a broken ice-cream kiosk, signposts, litter bins and wonky palms.
-- Every piece is one colour's (K.sub by colour) but the spotted, striped and shaded ones, a few colours each.
local T = {trees = 0.3}

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local function rnd(a, b) return K.g:range(a, b) end
  local EDGE = K.WALL_T + 1          -- the road's own margin: nothing of the kit's nearer its edge
  local function one() return 1 end

  local WHITE, BLACK = col(0.93, 0.93, 0.9), col(0.03, 0.03, 0.03)
  local WOODS = {col(0.45, 0.3, 0.16), col(0.36, 0.25, 0.15), col(0.52, 0.38, 0.22), col(0.42, 0.37, 0.3)}
  local STEEL, MESH = col(0.5, 0.53, 0.52), col(0.62, 0.66, 0.62)
  local G_YEL, G_SPOT, G_MUZ, G_HOOF = col(0.95, 0.72, 0.25), col(0.5, 0.24, 0.06), col(0.9, 0.8, 0.6), col(0.2, 0.12, 0.06)
  local ELE, ELE2 = col(0.5, 0.52, 0.58), col(0.6, 0.5, 0.55)
  local HIP, HIP2, MOUTH = col(0.5, 0.36, 0.48), col(0.4, 0.28, 0.4), col(0.95, 0.4, 0.5)
  local MUD, MUDRIM = col(0.58, 0.44, 0.22), col(0.3, 0.2, 0.1)
  local POND, CONC, CONC2, POOL = col(0.2, 0.5, 0.45), col(0.62, 0.62, 0.6), col(0.42, 0.42, 0.42), col(0.3, 0.7, 0.9)
  local ORANGE, TAN, MANE, CREAM = col(0.95, 0.5, 0.05), col(0.85, 0.6, 0.25), col(0.45, 0.22, 0.06), col(0.95, 0.88, 0.7)
  local ROCK = col(0.5, 0.45, 0.4)
  local FLAM, FLAM2 = col(1.0, 0.35, 0.55), col(0.95, 0.55, 0.65)
  local TRUNK, TRUNK2 = col(0.5, 0.36, 0.2), col(0.4, 0.28, 0.15)
  local FROND, FROND2, DEAD = col(0.15, 0.55, 0.12), col(0.3, 0.62, 0.1), col(0.6, 0.45, 0.15)
  local RED, YEL, BLUE, GREEN, PINK, TEAL, PURPLE = col(0.88, 0.08, 0.05), col(0.98, 0.8, 0.05), col(0.08, 0.3, 0.9),
    col(0.1, 0.62, 0.2), col(0.98, 0.5, 0.7), col(0.05, 0.6, 0.62), col(0.55, 0.15, 0.8)
  local BALLS = {RED, YEL, BLUE, GREEN, PINK, ORANGE, PURPLE, TEAL}
  local GLASS, BIN = col(0.1, 0.2, 0.35), col(0.1, 0.4, 0.2)

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
  local function limb(root, c, p0, p1, r0, r1, n) tube(root, c, {p0, p1}, {r0, r1}, n or 6) end
  local T5 = {-0.95, -0.6, 0, 0.6, 0.95}
  local T7 = {-0.97, -0.78, -0.42, 0, 0.42, 0.78, 0.97}
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
  local function chain(root, c, pts, rr, n)
    for j = 1, #pts - 1 do
      limb(root, c, pts[j], pts[j + 1], rr[j], rr[j + 1], n)
      if j > 1 then sph(root, c, pts[j], rr[j] * 1.03, n) end
    end
  end

  -- ---------------------------------------------------------------- where
  local function off(x, z) local _, d = K.ground_d(x, z); return d - K.HW end   -- metres off the road's edge
  local function clear(x, z, m) return off(x, z) > EDGE + (m or 0.4) end
  local taken = {}
  local function free(x, z, R)
    for _, t in ipairs(taken) do
      local dx, dz = t[1] - x, t[2] - z
      if dx * dx + dz * dz < (t[3] + R) * (t[3] + R) then return false end
    end
    return true
  end
  local function take(x, z, R) taken[#taken + 1] = {x, z, R} end
  -- A plot beside the road near sample i: a along the road by b out from it (half sizes), gap off the margin.
  local function site(i, side, a, b, gap)
    for _, di in ipairs({0, 2, -2, 4, -4, 7, -7, 10, -10}) do
      for _, sd in ipairs({side, -side}) do
        local j = math.max(3, math.min(N - 2, i + di))
        local w, u = right[j] * sd, K.along(j)
        local c = pos[j] + w * (W[j] + EDGE + gap + b)
        local R = math.max(a, b)
        local ok = free(c.x, c.z, R * 0.9)
        if ok then
          for _, m in ipairs({{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}, {-0.5, -1}, {0.5, -1}, {0, 0}}) do
            local p = c + u * (m[1] * a) + w * (m[2] * b)
            if not clear(p.x, p.z, gap * 0.5) then ok = false; break end
          end
        end
        if ok then
          take(c.x, c.z, R * 0.9)
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

  -- ---------------------------------------------------------------- fences
  -- Round a loop of points: `wood` posts and two rails, leaning, a rail down here and there; or steel posts, a top
  -- rail and a lattice of chain link, a bay torn out now and then.
  local function fence(loop, kind, h)
    local posts = {}
    for e = 1, #loop do
      local p, q = loop[e], loop[e % #loop + 1]
      local n = math.max(1, math.floor(length(v3(q.x - p.x, 0, q.z - p.z)) / 2.3 + 0.5))
      for k = 0, n - 1 do
        local m = lerp(p, q, k / n)
        local rec = false
        if clear(m.x, m.z, 0.15) then
          local base = v3(m.x, K.ground(m.x, m.z), m.z)
          local lean = (kind == "wood") and 0.14 or 0.06
          rec = {base = base, top = base + UP * (h * rnd(0.9, 1.06)) + v3(rnd(-lean, lean), 0, rnd(-lean, lean))}
        end
        posts[#posts + 1] = rec
      end
    end
    for idx, a in ipairs(posts) do
      local b = posts[idx % #posts + 1]
      if a then
        if kind == "wood" then
          beam(K.solid, K.pick(WOODS), a.base - UP * 0.4, a.top, 0.09, 0.09)
        else
          beam(K.solid, STEEL, a.base - UP * 0.4, a.top, 0.05, 0.05)
        end
      end
      if a and b then
        if kind == "wood" then
          for _, f in ipairs({0.45, 0.86}) do
            local chance = rnd(0, 1)
            local p0, p1 = lerp(a.base, a.top, f), lerp(b.base, b.top, f)
            if chance < 0.12 then p1 = b.base + UP * 0.06 elseif chance < 0.2 then p0 = a.base + UP * 0.06 end
            if chance > 0.25 or chance < 0.2 then beam(K.solid, K.pick(WOODS), p0, p1, 0.03, 0.075) end
          end
        else
          beam(K.solid, STEEL, a.top - UP * 0.04, b.top - UP * 0.04, 0.03, 0.03)
          if rnd(0, 1) > 0.12 then
            local m = 2
            beam(K.deco, MESH, lerp(a.base, a.top, 0.5), lerp(b.base, b.top, 0.5), 0.012, 0.022)
            for k = 0, m - 1 do
              local b0, b1 = lerp(a.base, b.base, k / m) + UP * 0.1, lerp(a.base, b.base, (k + 1) / m) + UP * 0.1
              local t0, t1 = lerp(a.top, b.top, k / m) - UP * 0.06, lerp(a.top, b.top, (k + 1) / m) - UP * 0.06
              beam(K.deco, MESH, b0, t1, 0.012, 0.022)
              beam(K.deco, MESH, b1, t0, 0.012, 0.022)
            end
          end
        end
      end
    end
  end
  local function pen(s, kind, h)
    local a, b = s.a - 0.15, s.b - 0.15
    fence({s.c - s.u * a - s.w * b, s.c + s.u * a - s.w * b, s.c + s.u * a + s.w * b, s.c - s.u * a + s.w * b}, kind, h)
  end

  -- ---------------------------------------------------------------- balls, palms, small things
  local function bigball(root, x, z, r, y)
    local ci = math.min(#BALLS, math.floor(rnd(1, #BALLS + 1)))
    local c = BALLS[ci]
    local a1 = normalize(v3(rnd(-1, 1), rnd(-0.6, 0.6), rnd(0.2, 1)))
    local a2 = normalize(cross(a1, UP))
    local a3 = cross(a1, a2)
    local style = ci % 3
    K.ball(piece(root, "ball" .. ci), v3(x, (y or K.ground(x, z)) + r * 0.88, z), r, r, r, 12, 7, one, function(wv)
      local n = normalize(wv)
      local p = dot(n, a1)
      if style == 0 then
        if math.abs(p) > 0.93 then return WHITE end
        local x2, z2 = dot(n, a2), dot(n, a3)
        return (x2 * (x2 * 0.5 + z2 * 0.866) * (-x2 * 0.5 + z2 * 0.866) > 0) and c or WHITE
      elseif style == 1 then
        return (math.abs(p) < 0.3) and WHITE or c
      end
      return (math.abs(p) > 0.8) and WHITE or c
    end)
  end

  local function palm(x, z, h)
    local base = v3(x, K.ground(x, z) - 0.4, z)
    local ang = rnd(0, 6.28)
    local dir = v3(math.cos(ang), 0, math.sin(ang))
    local lean = rnd(0.12, 0.42)
    local pts, rr = {}, {}
    for k = 0, 4 do
      local f = k / 4
      pts[k + 1] = base + UP * (h * f) + dir * (lean * h * f * f)
      rr[k + 1] = 0.34 - 0.16 * f
    end
    for j = 1, 4 do limb(K.solid, (j % 2 == 0) and TRUNK or TRUNK2, pts[j], pts[j + 1] + UP * 0.05, rr[j], rr[j + 1] * 1.12, 6) end
    local top = pts[5]
    local n = 7
    local a0 = rnd(0, 6.28)
    for k = 1, n do
      local a = a0 + k / n * 6.283 + rnd(-0.2, 0.2)
      local o = v3(math.cos(a), 0, math.sin(a))
      local c = (k % 2 == 0) and FROND or FROND2
      local droop = rnd(0.7, 1.5)
      if k == 3 then c = DEAD; droop = 2.6 end
      local reach = (k == 3) and 0.9 or rnd(1.5, 2.0)
      local mid = top + o * reach + UP * rnd(0.3, 0.6)
      beam(K.deco, c, top - o * 0.1, mid, 0.34, 0.035)
      beam(K.deco, c, mid - o * 0.05, mid + o * (reach * 0.75) - UP * droop, 0.22, 0.03)
    end
    sph(K.deco, TRUNK2, top - UP * 0.3 + dir * 0.25, 0.2, 5)
    sph(K.deco, TRUNK2, top - UP * 0.35 - dir * 0.22, 0.18, 5)
  end

  local function signpost(x, z)
    local base = v3(x, K.ground(x, z) - 0.3, z)
    local top = base + UP * 3.6 + v3(rnd(-0.35, 0.35), 0, rnd(-0.35, 0.35))
    beam(K.solid, WOODS[2], base, top, 0.07, 0.07)
    for k = 1, 3 do
      local a = rnd(0, 6.28)
      local d = v3(math.cos(a), rnd(-0.15, 0.15), math.sin(a))
      local p = lerp(base, top, 0.62 + k * 0.11)
      local c = BALLS[(k + math.floor(x)) % #BALLS + 1]
      obox(K.deco, c, p + d * 0.5, d * 0.62, UP * 0.15, normalize(cross(d, UP)) * 0.1)
    end
  end

  local LITTER = {WHITE, RED, YEL, BLUE}
  local function bin(x, z)
    local y = K.ground(x, z)
    if rnd(0, 1) < 0.3 then
      local a = rnd(0, 6.28)
      local d = v3(math.cos(a), 0, math.sin(a))
      limb(K.solid, BIN, v3(x, y + 0.4, z) - d * 0.55, v3(x, y + 0.4, z) + d * 0.55, 0.42, 0.38, 8)
      for k = 1, 5 do
        local p = v3(x, y + 0.08, z) + d * (0.6 + k * 0.4) + v3(rnd(-0.5, 0.5), 0, rnd(-0.5, 0.5))
        obox(K.deco, LITTER[k % 4 + 1], v3(p.x, K.ground(p.x, p.z) + 0.1, p.z), d * 0.16, UP * 0.1, v3(-d.z, 0, d.x) * 0.12)
      end
    else
      K.column(piece(K.solid, BIN), x, z, y - 0.3, y + 1.05, 0.36, 0.42, 8, BIN)
      K.column(piece(K.solid, BLACK), x, z, y + 1.0, y + 1.14, 0.46, 0.46, 8, BLACK)
      for k = 1, 3 do
        local px, pz = x + rnd(-1, 1), z + rnd(-1, 1)
        obox(K.deco, LITTER[k], v3(px, K.ground(px, pz) + 0.1, pz), v3(0.15, 0, 0.05), UP * 0.09, v3(-0.05, 0, 0.13))
      end
    end
  end

  -- ---------------------------------------------------------------- animals
  -- A creature's frame: P(a, h, b) is a forward, h up, b to its side (times its scale); foot(a, b) on the ground.
  local function rig(x, z, f, sc, y)
    local s = v3(-f.z, 0, f.x)
    local o = v3(x, y or K.ground(x, z), z)
    local G = {f = f, s = s}
    function G.P(a, h, b) return o + f * (a * sc) + UP * (h * sc) + s * (b * sc) end
    function G.foot(a, b)
      local p = o + f * (a * sc) + s * (b * sc)
      return v3(p.x, (y or K.ground(p.x, p.z)) - 0.15, p.z)
    end
    return G
  end

  local giraffes = 0
  local function giraffe(x, z, f, sc, lean)
    giraffes = giraffes + 1
    local G = rig(x, z, f, sc)
    local P, s, D = G.P, G.s, K.deco
    local sd = giraffes * 13
    local function spots(o)
      return function(j, k) return (K.hash(j * 3.1 + o + sd, k * 1.7 + o) > 0.55) and G_SPOT or G_YEL end
    end
    egg(D, spots(1), P(0, 4.3, 0), P(1.7, 4.6, 0) - P(0, 4.3, 0), 0.95 * sc, 1.05 * sc, 8, nil, "giraffe", T7)
    local n0, n1 = P(1.25, 4.7, 0), P(1.3 + lean, 8.3, 0)
    local pts, rr = {}, {}
    for k = 0, 6 do pts[k + 1] = lerp(n0, n1, k / 6); rr[k + 1] = (0.66 - 0.34 * k / 6) * sc end
    tube(D, spots(2), pts, rr, 7, nil, 1, "giraffe")
    beam(D, G_SPOT, P(0.7, 5.0, 0), P(1.0 + lean, 8.5, 0), 0.07 * sc, 0.22 * sc)
    for _, a in ipairs({1.15, -1.2}) do
      for side = -1, 1, 2 do
        local hip, foot = P(a, 4.0, side * 0.5), G.foot(a * 1.08, side * 0.58)
        local knee = lerp(hip, foot, 0.5)
        tube(D, spots(a + side + 4), {hip, lerp(hip, knee, 0.5), knee}, {0.32 * sc, 0.26 * sc, 0.19 * sc}, 6, nil, 1, "giraffe")
        limb(D, G_MUZ, knee + UP * 0.1, foot + UP * 0.3, 0.18 * sc, 0.13 * sc, 6)
        limb(D, G_HOOF, foot, foot + UP * (0.5 * sc), 0.2 * sc, 0.16 * sc, 6)
      end
    end
    limb(D, G_YEL, P(-1.6, 4.5, 0), P(-2.05, 2.9, 0), 0.08 * sc, 0.05 * sc, 4)
    sph(D, G_HOOF, P(-2.08, 2.7, 0), 0.17 * sc, 5)
    local hx, hy = 1.3 + lean + 0.5, 8.4
    local function H(a, h, b) return P(hx + a, hy + h, b) end
    egg(D, G_YEL, H(0, 0, 0), (f * 0.9 - UP * 0.32) * sc, 0.42 * sc, 0.44 * sc, 7)
    egg(D, G_MUZ, H(0.78, -0.3, 0), (f * 0.4 - UP * 0.14) * sc, 0.33 * sc, 0.3 * sc, 6)
    for side = -1, 1, 2 do
      sph(D, WHITE, H(0.12, 0.2, side * 0.36), 0.17 * sc, 6)
      sph(D, BLACK, H(0.2, 0.2, side * 0.47), 0.09 * sc, 5)
      limb(D, G_YEL, H(-0.35, 0.3, side * 0.18), H(-0.5, 0.9, side * 0.24), 0.08 * sc, 0.07 * sc, 5)
      sph(D, G_HOOF, H(-0.52, 0.95, side * 0.24), 0.13 * sc, 5)
      egg(D, G_YEL, H(-0.55, 0.22, side * 0.6), s * (side * 0.34 * sc), 0.13 * sc, 0.08 * sc, 5)
      sph(D, G_HOOF, H(1.12, -0.36, side * 0.13), 0.06 * sc, 4)
    end
  end

  local function elephant(x, z, f, sc)
    local G = rig(x, z, f, sc)
    local P, s, D = G.P, G.s, K.deco
    egg(D, ELE, P(0, 2.6, 0), f * (2.0 * sc), 1.35 * sc, 1.4 * sc, 8)
    egg(D, ELE, P(2.2, 3.0, 0), (f * 0.95 - UP * 0.15) * sc, 1.0 * sc, 1.05 * sc, 7)
    for side = -1, 1, 2 do
      egg(D, ELE2, P(1.7, 3.1, side * 1.3), (UP * 1.1 + s * (side * 0.3)) * sc, 0.9 * sc, 0.13 * sc, 8, f)
      for _, a in ipairs({1.2, -1.25}) do
        limb(D, ELE, P(a, 2.2, side * 0.75), G.foot(a, side * 0.8), 0.5 * sc, 0.46 * sc, 7)
      end
      limb(D, WHITE, P(2.85, 2.35, side * 0.45), P(3.75, 2.0, side * 0.6), 0.13 * sc, 0.04 * sc, 5)
      sph(D, BLACK, P(2.85, 3.25, side * 0.72), 0.12 * sc, 5)
    end
    chain(D, ELE, {P(2.95, 2.8, 0), P(3.75, 1.95, 0), P(3.9, 0.95, 0), P(4.4, 0.5, 0)},
      {0.42 * sc, 0.33 * sc, 0.25 * sc, 0.2 * sc}, 6)
    limb(D, ELE, P(-1.9, 2.9, 0), P(-2.3, 1.5, 0), 0.09 * sc, 0.06 * sc, 4)
    sph(D, BLACK, P(-2.32, 1.4, 0), 0.14 * sc, 4)
  end

  -- (Standing in water: y is the water's level.)
  local function hippo(x, z, f, sc, y)
    local G = rig(x, z, f, sc, y)
    local P, D = G.P, K.deco
    egg(D, HIP, P(-1.0, 0.25, 0), f * (1.9 * sc), 1.25 * sc, 1.0 * sc, 8)
    egg(D, HIP, P(1.3, 0.75, 0), f * (0.95 * sc), 0.88 * sc, 0.78 * sc, 7)
    egg(D, HIP, P(2.4, 0.3, 0), f * (1.0 * sc), 0.82 * sc, 0.28 * sc, 7)
    egg(D, HIP, P(2.15, 1.38, 0), normalize(f * 0.75 + UP * 0.62) * (1.05 * sc), 0.82 * sc, 0.36 * sc, 7)
    egg(D, MOUTH, P(1.95, 0.82, 0), (f * 0.5 + UP * 0.3) * sc, 0.7 * sc, 0.45 * sc, 7)
    for side = -1, 1, 2 do
      limb(D, WHITE, P(3.05, 0.45, side * 0.42), P(3.12, 1.05, side * 0.42), 0.13 * sc, 0.06 * sc, 5)
      limb(D, WHITE, P(2.8, 1.9, side * 0.36), P(2.95, 1.5, side * 0.36), 0.11 * sc, 0.05 * sc, 5)
      sph(D, HIP2, P(2.78, 2.12, side * 0.3), 0.15 * sc, 5)
      sph(D, WHITE, P(1.2, 1.5, side * 0.5), 0.21 * sc, 6)
      sph(D, BLACK, P(1.34, 1.55, side * 0.57), 0.1 * sc, 5)
      sph(D, HIP2, P(0.75, 1.45, side * 0.68), 0.17 * sc, 5)
    end
  end

  local function penguin(x, z, f, sc, y)
    local G = rig(x, z, f, sc, y)
    local P, s, D = G.P, G.s, K.deco
    egg(D, BLACK, P(0, 0.64, 0), UP * (0.64 * sc), 0.38 * sc, 0.34 * sc, 7, f)
    egg(D, WHITE, P(0.12, 0.56, 0), UP * (0.5 * sc), 0.3 * sc, 0.29 * sc, 6, f)
    sph(D, BLACK, P(0, 1.32, 0), 0.27 * sc, 6)
    limb(D, ORANGE, P(0.18, 1.3, 0), P(0.55, 1.2, 0), 0.1 * sc, 0.02 * sc, 5)
    for side = -1, 1, 2 do
      sph(D, WHITE, P(0.2, 1.4, side * 0.13), 0.07 * sc, 4)
      egg(D, BLACK, P(0, 0.72, side * 0.42), (UP * 0.4 + s * (side * 0.14)) * sc, 0.06 * sc, 0.14 * sc, 5, f)
      obox(D, ORANGE, P(0.18, 0.03, side * 0.17), f * (0.2 * sc), UP * (0.04 * sc), s * (0.11 * sc))
    end
  end

  local function flamingo(x, z, f, sc, y)
    local G = rig(x, z, f, sc, y)
    local P, D = G.P, K.deco
    limb(D, FLAM2, G.foot(0, 0), P(0, 1.1, 0), 0.045 * sc, 0.045 * sc, 4)
    limb(D, FLAM2, P(0, 1.1, 0.1), P(-0.35, 0.8, 0.1), 0.045 * sc, 0.04 * sc, 4)
    egg(D, FLAM, P(0, 1.3, 0), (f * 0.46 + UP * 0.08) * sc, 0.27 * sc, 0.27 * sc, 6)
    egg(D, FLAM2, P(-0.45, 1.28, 0), (f * -0.25 - UP * 0.08) * sc, 0.14 * sc, 0.1 * sc, 5)
    chain(D, FLAM, {P(0.35, 1.38, 0), P(0.62, 1.95, 0), P(0.45, 2.35, 0), P(0.72, 2.52, 0)},
      {0.09 * sc, 0.07 * sc, 0.07 * sc, 0.07 * sc}, 5)
    sph(D, FLAM, P(0.74, 2.54, 0), 0.13 * sc, 5)
    limb(D, WHITE, P(0.8, 2.52, 0), P(0.96, 2.4, 0), 0.08 * sc, 0.06 * sc, 4)
    limb(D, BLACK, P(0.94, 2.42, 0), P(1.02, 2.2, 0), 0.06 * sc, 0.02 * sc, 4)
  end

  -- (Lying on its rock: y is the rock's top.)
  local function lion(x, z, f, sc, y)
    local G = rig(x, z, f, sc, y)
    local P, s, D = G.P, G.s, K.deco
    egg(D, TAN, P(0, 0.6, 0), f * (1.35 * sc), 0.62 * sc, 0.58 * sc, 7)
    egg(D, MANE, P(1.35, 1.15, 0), UP * (0.95 * sc), 0.95 * sc, 0.8 * sc, 8, f)
    egg(D, TAN, P(1.85, 1.15, 0), f * (0.5 * sc), 0.52 * sc, 0.55 * sc, 7)
    egg(D, CREAM, P(2.28, 0.98, 0), f * (0.22 * sc), 0.3 * sc, 0.24 * sc, 6)
    sph(D, BLACK, P(2.5, 1.05, 0), 0.09 * sc, 4)
    for side = -1, 1, 2 do
      obox(D, BLACK, P(2.24, 1.33, side * 0.2), f * (0.05 * sc), UP * (0.035 * sc), s * (0.12 * sc))
      sph(D, TAN, P(1.5, 2.0, side * 0.52), 0.18 * sc, 5)
      limb(D, TAN, P(1.0, 0.28, side * 0.42), P(2.7, 0.24, side * 0.42), 0.21 * sc, 0.18 * sc, 6)
      sph(D, TAN, P(-0.85, 0.6, side * 0.5), 0.5 * sc, 6)
    end
    chain(D, TAN, {P(-1.3, 0.6, 0), P(-2.1, 0.35, 0.5), P(-2.6, -0.6, 0.7)}, {0.09 * sc, 0.08 * sc, 0.07 * sc}, 4)
    sph(D, MANE, P(-2.62, -0.7, 0.7), 0.2 * sc, 5)
  end

  -- A round pool terraced into the slope: its bank (wider at the foot by `spread`) and the water's disc. Its level.
  local function pool(c, r, water, rimc, rimw, spread)
    local level = c.y + 0.15 * r
    local lo = level
    for k = 0, 7 do
      local a = k / 8 * 6.283
      lo = math.min(lo, K.ground(c.x + math.cos(a) * (r + rimw + spread), c.z + math.sin(a) * (r + rimw + spread)))
    end
    K.column(piece(K.solid, rimc), c.x, c.z, lo - 0.6, level, r + rimw + spread, r + rimw, 12, rimc)
    K.column(piece(K.deco, water), c.x, c.z, level - 0.4, level + 0.07, r, r, 12, water, 0.13)
    return level + 0.07
  end

  -- ---------------------------------------------------------------- the pens
  local made = {}
  local function count(k) made[k] = (made[k] or 0) + 1 end

  local function giraffe_pen(i, side)
    local s = site(i, side, 4.3, 3.3, 0.8)
    if not s then return end
    pen(s, "wood", 1.7)
    local p = s.at(rnd(-0.8, 0.8), 0.9)
    giraffe(p.x, p.z, normalize(s.w * -1 + s.u * rnd(-0.12, 0.12)), rnd(0.95, 1.08), rnd(3.5, 4.1))
    local q = s.at(rnd(2.2, 3.2) * (rnd(0, 1) < 0.5 and -1 or 1), rnd(-1.8, -1.0))
    bigball(K.deco, q.x, q.z, 0.8)
    count("giraffe pens")
  end

  local function elephant_pen(i, side)
    local s = site(i, side, 6.2, 4.6, 0.8)
    if not s then return end
    pen(s, "wood", 1.9)
    local p = s.at(1.0, 0.2)
    elephant(p.x, p.z, normalize(s.u * -0.85 - s.w * 0.5), 1.15)
    local q = s.at(-4.2, -2.6)
    bigball(K.deco, q.x, q.z, 1.2)
    q = s.at(4.4, 2.4)
    bigball(K.deco, q.x, q.z, 0.9)
    count("elephant pens")
  end

  local function hippo_pen(i, side)
    local s = site(i, side, 6.3, 6.3, 0.8)
    if not s then return end
    local level = pool(s.c, 4.3, MUD, MUDRIM, 0.7, 0.9)
    local f = normalize(s.w * -0.8 - s.u * 0.6)
    local p = s.c - f * 0.9
    hippo(p.x, p.z, f, 1.2, level - 0.12)
    local q = s.c + s.u * 2.6 + s.w * 1.2
    bigball(K.deco, q.x, q.z, 0.9, level - 0.5)
    pen(s, "wood", 1.3)
    count("hippo ponds")
  end

  local function flamingo_pen(i, side)
    local s = site(i, side, 5.6, 4.8, 0.8)
    if not s then return end
    local level = pool(s.c, 3.3, POND, CONC, 0.4, 0.5)
    for k = 1, 7 do
      local a, r = k / 7 * 6.283 + rnd(-0.3, 0.3), rnd(0.6, 2.7)
      local x, z = s.c.x + math.cos(a) * r, s.c.z + math.sin(a) * r
      local fa = rnd(0, 6.283)
      flamingo(x, z, v3(math.cos(fa), 0, math.sin(fa)), rnd(1.0, 1.25), level - 0.05)
    end
    for k = -1, 1, 2 do
      local p = s.at(k * 4.4, -3.4)
      local fa = rnd(0, 6.283)
      flamingo(p.x, p.z, v3(math.cos(fa), 0, math.sin(fa)), 1.15)
    end
    pen(s, "wood", 1.1)
    count("flamingo ponds")
  end

  local function penguin_pen(i, side)
    local s = site(i, side, 6.2, 4.4, 0.8)
    if not s then return end
    local u, w = s.u, s.w
    local a, b = 5.0, 3.3
    local level = s.at(0, 1.2).y + 0.1
    local lo = K.lowest(s.c, u, w, a, b) - 0.6
    local mid = v3(s.c.x, 0, s.c.z)
    obox(K.solid, CONC, mid + UP * ((lo + level) / 2), u * a, UP * ((level - lo) / 2), w * b)
    obox(K.deco, POOL, mid + UP * level - w * 1.5 - u * 0.4, u * 2.3, UP * 0.06, w * 1.3)
    -- Cracks and stains on the concrete, and a painted "iceberg" in the corner.
    for k = 1, 5 do
      local p0 = mid + UP * level + u * rnd(-4.5, 4.5) + w * rnd(-3, 2)
      beam(K.deco, CONC2, p0, p0 + u * rnd(-1.6, 1.6) + w * rnd(-1.2, 1.2), 0.05, 0.03)
    end
    for k = 0, 3 do
      beam(K.deco, CONC2, mid + UP * (level - 0.2) - w * (b + 0.01) + u * (-3.5 + k * 2.3),
        mid + UP * (level - 0.9 - rnd(0, 0.8)) - w * (b + 0.01) + u * (-3.5 + k * 2.3), 0.12, 0.02, w)
    end
    obox(K.deco, WHITE, mid + UP * (level + 0.5) + u * 3.6 + w * 0.4, u * 1.0 + w * 0.2, UP * 0.6, w * 0.8 - u * 0.2)
    obox(K.deco, POOL, mid + UP * (level + 1.25) + u * 3.4 + w * 0.5, u * 0.6 - w * 0.2, UP * 0.3, w * 0.5 + u * 0.15)
    for k = 1, 9 do
      local du, dw = -4.3 + k * 0.85 + rnd(-0.3, 0.3), rnd(-2.8, 0.2)
      if k > 7 then du = du - 3 end
      local p = mid + u * du + w * dw
      local f = normalize(w * -1 + u * rnd(-0.9, 0.9))
      penguin(p.x, p.z, f, rnd(1.15, 1.4), level + 0.02)
    end
    pen(s, "chain", 2.0)
    count("penguin pools")
  end

  local function lion_pen(i, side)
    local s = site(i, side, 6.2, 5.0, 0.8)
    if not s then return end
    local c = s.at(0, -0.6)
    local rock = piece(K.deco, "rock")
    local shade = K.shaded(ROCK)
    local cy, ry = c.y - 0.3, 2.5
    K.ball(rock, v3(c.x, cy, c.z), 3.4, ry, 3.0, 9, 6, function() return rnd(0.86, 1.06) end, shade)
    local q = s.at(3.6, 1.5)
    K.ball(rock, v3(q.x, q.y, q.z), 1.4, 1.1, 1.3, 7, 5, function() return rnd(0.8, 1.1) end, shade)
    lion(c.x, c.z, normalize(s.w * -1 - s.u * 0.45), 1.35, cy + ry * 0.9)
    q = s.at(-4.2, -2.8)
    bigball(K.deco, q.x, q.z, 0.8)
    pen(s, "chain", 2.7)
    count("lion pens")
  end

  -- ---------------------------------------------------------------- buildings
  -- The arch: two striped pillars outside the walls, a board 6.7 m up between them, ZOO in red (the last O slipped).
  local function entrance(i)
    local c, r, t = pos[i], right[i], K.along(i)
    local half = W[i] + EDGE + 0.95
    for sd = -1, 1, 2 do
      local p = c + r * (sd * half)
      local gy = K.ground(p.x, p.z) - 0.6
      local top = c.y + 9.7
      obox(K.solid, YEL, v3(p.x, (gy + top) / 2, p.z), r * 0.7, UP * ((top - gy) / 2), t * 0.7)
      for k = 0, 3 do obox(K.solid, GREEN, v3(p.x, c.y + 0.9 + k * 1.5, p.z), r * 0.73, UP * 0.36, t * 0.73) end
      bigball(K.deco, p.x, p.z, 1.0, top - 0.25)
      take(p.x, p.z, 1.6)
    end
    local bc = c + UP * 8.15
    obox(K.deco, TEAL, bc, r * (half - 0.2), UP * 1.45, t * 0.22)
    obox(K.deco, YEL, bc, r * (half - 1.0), UP * 1.25, t * 0.26)
    local function L(a, h) return bc - t * 0.28 + r * a + UP * h end
    local function stroke(a0, h0, a1, h1) beam(K.deco, RED, L(a0, h0), L(a1, h1), 0.17, 0.1, t) end
    stroke(-2.75, 0.85, -1.35, 0.85); stroke(-1.4, 0.9, -2.7, -0.9); stroke(-2.75, -0.85, -1.35, -0.85)
    local function O(ac, hc, turn)
      for k = 0, 7 do
        local a0, a1 = k / 8 * 6.283 + turn, (k + 1) / 8 * 6.283 + turn
        local function at(a)
          local x, y = math.cos(a) * 0.68, math.sin(a) * 0.9
          return ac + x * math.cos(turn) - y * math.sin(turn), hc + x * math.sin(turn) + y * math.cos(turn)
        end
        local x0, y0 = at(a0 - turn)
        local x1, y1 = at(a1 - turn)
        stroke(x0, y0, x1, y1)
      end
    end
    O(0, 0, 0)
    O(2.2, -0.3, -0.4)
    -- A ticket hut by the pillar, shut.
    count("entrance")
  end

  local function giftshop(i, side)
    local s = site(i, side, 5.2, 3.6, 1.0)
    if not s then return end
    local u, w = s.u, s.w
    local mid = v3(s.c.x, 0, s.c.z)
    local front = mid - w * 3.0
    local yf = K.ground(front.x, front.z)
    local lo = K.lowest(s.c, u, w, 4.6, 3.1) - 0.6
    local top = yf + 4.3
    obox(K.solid, PINK, mid + UP * ((lo + top) / 2), u * 4.5, UP * ((top - lo) / 2), w * 3.0)
    obox(K.deco, TEAL, mid + UP * (top + 0.1), u * 4.9, UP * 0.2, w * 3.4)
    obox(K.deco, WOODS[1], front + UP * (yf + 1.15), u * 0.65, UP * 1.2, w * 0.08)
    for k = -1, 1, 2 do
      obox(K.deco, GLASS, front + UP * (yf + 1.75) + u * (k * 2.7), u * 1.1, UP * 0.75, w * 0.07)
      obox(K.deco, WHITE, front + UP * (yf + 1.75) + u * (k * 2.7), u * 0.05, UP * 0.78, w * 0.1)
      -- Plush toys in the window: a ball each.
      sph(K.deco, BALLS[k + 3], front + UP * (yf + 1.4) + u * (k * 2.3) - w * 0.1, 0.3, 5)
      sph(K.deco, BALLS[k + 6], front + UP * (yf + 1.5) + u * (k * 3.1) - w * 0.1, 0.36, 5)
    end
    for k = -4, 3 do
      obox(K.deco, (k % 2 == 0) and RED or WHITE, front - w * 0.75 + UP * (yf + 3.05) + u * ((k + 0.5) * 1.1),
        u * 0.545, normalize(UP * 0.9 - w * 0.4) * 0.04, w * 0.8 + UP * 0.32)
    end
    -- The giant present on the roof: red, a yellow ribbon and bow.
    local gc = mid + UP * (top + 1.5) + u * 1.6
    local gu, gw = normalize(u + w * 0.35), normalize(w - u * 0.35)
    obox(K.deco, RED, gc, gu * 1.2, UP * 1.2, gw * 1.2)
    obox(K.deco, YEL, gc, gu * 0.22, UP * 1.24, gw * 1.24)
    obox(K.deco, YEL, gc, gu * 1.24, UP * 1.24, gw * 0.22)
    egg(K.deco, YEL, gc + UP * 1.5 + gu * 0.5, gu * 0.55 + UP * 0.2, 0.3, 0.3, 6)
    egg(K.deco, YEL, gc + UP * 1.5 - gu * 0.5, gu * -0.55 + UP * 0.2, 0.3, 0.3, 6)
    -- A smaller blue one beside it, and a rack of balls by the door.
    local g2 = mid + UP * (top + 0.85) - u * 2.2
    obox(K.deco, BLUE, g2, u * 0.6, UP * 0.6, w * 0.6)
    obox(K.deco, PINK, g2, u * 0.12, UP * 0.63, w * 0.63)
    obox(K.deco, PINK, g2, u * 0.63, UP * 0.63, w * 0.12)
    count("gift shops")
  end

  local function kiosk(i, side)
    local s = site(i, side, 2.6, 2.2, 0.8)
    if not s then return end
    local u, w = s.u, s.w
    local base = s.c - UP * 0.5
    local up = normalize(UP + u * 0.16 - w * 0.07)
    obox(K.solid, CREAM, base + up * 1.7, u * 1.2, up * 1.7, w * 1.2)
    obox(K.deco, PINK, base + up * 1.1, u * 1.23, up * 0.3, w * 1.23)
    obox(K.deco, BLACK, base + up * 2.3 - w * 1.2, u * 0.85, up * 0.5, w * 0.06)
    beam(K.deco, WOODS[1], base + up * 1.75 - w * 1.3 - u * 0.95, base + up * 2.85 - w * 1.3 + u * 0.95, 0.1, 0.03, w)
    beam(K.deco, WOODS[3], base + up * 2.85 - w * 1.32 - u * 0.95, base + up * 1.75 - w * 1.32 + u * 0.95, 0.1, 0.03, w)
    obox(K.deco, PINK, base + up * 3.5, u * 1.5, up * 0.1, w * 1.5)
    -- The awning, half off: its strips hang from the roof's edge, the far ones lower.
    for k = -2, 2 do
      local drop = 0.5 + (k + 2) * 0.16
      obox(K.deco, (k % 2 == 0) and RED or WHITE, base + up * 3.4 - w * 1.56 + u * (k * 0.56) - UP * drop,
        u * 0.275, UP * drop, w * 0.03 + UP * 0.01)
    end
    -- The giant cone on the roof, toppling; a scoop on the ground.
    local p0 = base + up * 3.55
    local dir = normalize(UP * 0.85 + u * 0.5 + w * 0.15)
    limb(K.deco, TAN, p0, p0 + dir * 1.9, 0.12, 0.66, 8)
    sph(K.deco, PINK, p0 + dir * 2.3, 0.74, 7)
    sph(K.deco, CREAM, p0 + dir * 3.15, 0.6, 7)
    sph(K.deco, RED, p0 + dir * 3.85, 0.2, 5)
    local q = s.at(1.9, -1.6)
    egg(K.deco, PINK, q + UP * 0.2, UP * 0.4, 0.8, 0.75, 7)
    limb(K.deco, TAN, q + UP * 0.45, q + UP * 0.6 + u * 1.1 + w * 0.3, 0.42, 0.06, 7)
    count("kiosks")
  end

  -- ---------------------------------------------------------------- the zoo, laid out down the road
  entrance(math.min(N - 4, K.start + 13))
  local plan = {
    {20, -1, kiosk}, {22, 1, giftshop},
    {36, -1, giraffe_pen}, {40, 1, elephant_pen},
    {54, -1, hippo_pen}, {56, 1, flamingo_pen},
    {70, -1, penguin_pen}, {72, 1, lion_pen},
    {86, 1, giraffe_pen}, {88, -1, flamingo_pen},
    {102, -1, elephant_pen}, {104, 1, hippo_pen},
    {118, 1, penguin_pen}, {120, -1, giraffe_pen},
    {134, -1, lion_pen}, {136, 1, kiosk}, {142, 1, flamingo_pen},
    {152, -1, hippo_pen}, {154, 1, giraffe_pen},
    {166, 1, elephant_pen}, {168, -1, penguin_pen},
    {180, -1, giraffe_pen}, {182, 1, lion_pen},
    {198, 1, giftshop}, {200, -1, flamingo_pen}, {6, -1, giraffe_pen}, {6, 1, flamingo_pen},
  }
  for _, e in ipairs(plan) do e[3](e[1], e[2]) end

  -- Beside the road, wherever there is room: lo..hi metres past the margin, a thing `rad` wide.
  local function scatter(n, lo, hi, rad, fn)
    local done = 0
    for _ = 1, n * 5 do
      if done >= n then break end
      local i = math.floor(rnd(3, N - 2))
      local sd = (rnd(0, 1) < 0.5) and -1 or 1
      local p = pos[i] + right[i] * (sd * (W[i] + EDGE + rnd(lo, hi)))
      if clear(p.x, p.z, rad + 0.2) and free(p.x, p.z, rad) then
        take(p.x, p.z, rad)
        fn(p.x, p.z)
        done = done + 1
      end
    end
    return done
  end
  local balls = scatter(26, 2.2, 9, 1.7, function(x, z) bigball(K.solid, x, z, rnd(0.9, 1.6)) end)
  balls = balls + scatter(22, 6, 30, 2.6, function(x, z) bigball(K.solid, x, z, rnd(1.5, 2.5)) end)
  local palms = scatter(46, 3.6, 26, 1.3, function(x, z) palm(x, z, rnd(6, 9.5)) end)
  scatter(12, 1.0, 2.2, 0.7, signpost)
  scatter(18, 0.9, 2.6, 0.7, bin)

  -- Out on the slopes: the ones that got out, more balls and palms.
  local function far(n, clearance, fn)
    for _ = 1, n * 3 do
      local x, z = K.spot(clearance)
      if x and free(x, z, 5) then
        take(x, z, 5)
        fn(x, z, rnd(0, 6.283))
        n = n - 1
        if n <= 0 then break end
      end
    end
  end
  far(4, 22, function(x, z, a) giraffe(x, z, v3(math.cos(a), 0, math.sin(a)), 1.2, rnd(1.2, 2.6)) end)
  far(3, 22, function(x, z, a) elephant(x, z, v3(math.cos(a), 0, math.sin(a)), 1.3) end)
  far(5, 18, function(x, z, a)
    for k = 1, 5 do
      local px, pz = x + rnd(-3.5, 3.5), z + rnd(-3.5, 3.5)
      flamingo(px, pz, v3(math.cos(a + k), 0, math.sin(a + k)), 1.3)
    end
  end)
  far(16, 16, function(x, z) bigball(K.deco, x, z, rnd(1.6, 3.2)) end)
  far(12, 14, function(x, z) palm(x, z, rnd(7, 11)) end)

  local list = {}
  for k, n in pairs(made) do list[#list + 1] = n .. " " .. k end
  table.sort(list)
  info("zoo: " .. table.concat(list, ", ") .. string.format(", %d balls, %d palms", balls, palms))
end

return T
