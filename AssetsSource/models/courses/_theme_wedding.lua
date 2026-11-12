-- The Wedding Venue Disaster's scenery kit (see THEME KITS in _course.lua): a grand country-house wedding. A stately
-- manor with a portico, a giant (wonky) tiered cake by the start, white marquees strung with bunting, the valley cut
-- into lawn terraces edged with stone balustrades, clipped hedges and topiary along the road, flower arches over it,
-- round tables in white cloths with chairs, champagne towers, rose beds, a fountain, a string quartet, guests in
-- morning suits and bright dresses, a vintage wedding car trailing tin cans, and confetti cannons, balloons and
-- strewn confetti round the finish. Every piece is one colour's (K.sub by colour) but the shaded topiary.
local T = {trees = 0.4}

-- The terraces: past the road's own verge the valley is cut into level lawns TERR metres apart, a bank between.
-- (What the valley's grid was given at each of its corners is kept -- the level there, in terraces -- so that
-- T.paint can tell a lawn's cell from a bank's.)
local TERR = 4
local SEEN = {}
local function seen_key(x, z) return (x + 4096) * 16384 + (z + 4096) end
function T.shape(x, z, off, y)
  local whole = x == math.floor(x) and z == math.floor(z)
  if off < 8 then
    if whole then SEEN[seen_key(x, z)] = false end
    return nil
  end
  local t = math.min(1, (off - 8) / 10)
  t = t * t * (3 - 2 * t)
  local n = math.floor(y / TERR)
  local f = y / TERR - n
  local s = (f < 0.7) and 0 or (f - 0.7) / 0.3
  if whole then SEEN[seen_key(x, z)] = (t > 0.6) and (n + s) or false end
  return y + (TERR * (n + s) - y) * t
end

-- The ground: a gravel walk along the walls; lawn mown in a chequerboard of two greens; the terraces' banks dark, as clipped.
local LAWN, CELL
function T.paint(x, z, off, _, TK)
  LAWN = LAWN or {TK.col(0.8, 0.73, 0.56), TK.col(0.17, 0.52, 0.12), TK.col(0.27, 0.66, 0.18), TK.col(0.14, 0.42, 0.11),
    TK.col(0.2, 0.5, 0.14), TK.col(0.07, 0.3, 0.09), TK.col(0.09, 0.35, 0.1)}
  if off < 3.4 then return LAWN[1] end
  if not CELL then
    for st = 5, 12 do
      if SEEN[seen_key(x - st / 2, z - st / 2)] ~= nil and SEEN[seen_key(x + st / 2, z + st / 2)] ~= nil then CELL = st; break end
    end
  end
  local k = (math.floor(x / 5 + 0.001) + math.floor(z / 5 + 0.001)) % 2
  if CELL then
    local h = CELL / 2
    local lo, hi = math.huge, -math.huge
    for _, m in ipairs({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do
      local v = SEEN[seen_key(x + m[1] * h, z + m[2] * h)]
      if not v then lo = nil; break end
      lo, hi = math.min(lo, v), math.max(hi, v)
    end
    if lo and hi - lo > 0.3 then return LAWN[6 + k] end
  end
  if off > 55 then return LAWN[4 + k] end
  return LAWN[2 + k]
end

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local function rnd(a, b) return K.g:range(a, b) end
  local function irnd(n) return math.min(n, math.floor(rnd(1, n + 1))) end
  local EDGE = K.WALL_T + 1          -- the road's own margin: nothing of the kit's nearer its edge

  local WHITE, WHITE2, BLACK = col(0.96, 0.96, 0.93), col(0.84, 0.86, 0.9), col(0.04, 0.04, 0.05)
  local STONE, STONE2, STONE3 = col(0.86, 0.77, 0.58), col(0.72, 0.68, 0.6), col(0.6, 0.57, 0.52)
  local SLATE, BRICK, GLASS, LIT, DOOR = col(0.26, 0.3, 0.38), col(0.6, 0.25, 0.15), col(0.12, 0.2, 0.34), col(1, 0.85, 0.4), col(0.08, 0.25, 0.12)
  local HEDGE, HEDGE2, LEAF = col(0.07, 0.33, 0.1), col(0.1, 0.42, 0.13), col(0.2, 0.55, 0.15)
  local TERRA, EARTH, TRUNK = col(0.72, 0.36, 0.2), col(0.3, 0.19, 0.1), col(0.4, 0.27, 0.14)
  local RED, PINK, ROSE, YEL, BLUE, LILAC, TEAL, ORANGE, GREEN = col(0.88, 0.06, 0.1), col(1.0, 0.5, 0.7), col(0.95, 0.25, 0.45),
    col(0.99, 0.82, 0.1), col(0.1, 0.35, 0.9), col(0.65, 0.4, 0.9), col(0.05, 0.7, 0.7), col(0.98, 0.5, 0.08), col(0.2, 0.75, 0.25)
  local GOLD, CHAMP, SILVER, CHROME = col(0.9, 0.68, 0.15), col(0.98, 0.86, 0.5), col(0.75, 0.77, 0.8), col(0.85, 0.87, 0.9)
  local ICING, IVORY, WATER, SPRAY = col(0.98, 0.95, 0.88), col(0.95, 0.9, 0.74), col(0.2, 0.55, 0.85), col(0.82, 0.94, 1.0)
  local WOOD, WOOD2, STRING = col(0.55, 0.3, 0.12), col(0.4, 0.2, 0.08), col(0.9, 0.9, 0.85)
  local SUITS = {col(0.45, 0.47, 0.52), col(0.1, 0.14, 0.32), col(0.2, 0.2, 0.23), col(0.5, 0.42, 0.34)}
  local TROUSER, HATGREY = col(0.3, 0.3, 0.34), col(0.55, 0.56, 0.6)
  local DRESSES = {PINK, YEL, TEAL, LILAC, ORANGE, GREEN, BLUE, RED}
  local SKINS = {col(0.95, 0.72, 0.55), col(0.8, 0.55, 0.38), col(0.5, 0.32, 0.2), col(0.98, 0.8, 0.66)}
  local HAIRS = {col(0.25, 0.14, 0.06), col(0.85, 0.65, 0.2), col(0.08, 0.06, 0.05), col(0.6, 0.25, 0.08)}
  local BLOOMS = {RED, PINK, ROSE, WHITE, YEL}
  local BRIGHT = {RED, YEL, BLUE, PINK, GREEN, ORANGE, LILAC, TEAL, WHITE}
  local BUNT = {RED, WHITE, BLUE, YEL, PINK, GREEN}

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
  -- A round tube through pts, radius rr[j] at each, n-sided, of one colour; `squash` flattens it the second way.
  local function tube(root, c, pts, rr, n, hint, squash)
    local q = piece(root, c)
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
    K.prism(q, rings, K.flat(c), c, c)
  end
  local function limb(root, c, p0, p1, r0, r1, n) tube(root, c, {p0, p1}, {r0, r1}, n or 6) end
  local T5 = {-0.95, -0.6, 0, 0.6, 0.95}
  local T3 = {-0.85, 0, 0.85}
  -- An ellipsoid: half-length vector `axis`, radius r1 across (level, or across hint) and r2 the other way.
  local function egg(root, c, cen, axis, r1, r2, n, hint, ts)
    local pts, rr = {}, {}
    for _, t in ipairs(ts or T5) do
      pts[#pts + 1] = cen + axis * t
      rr[#rr + 1] = r1 * math.sqrt(1 - t * t)
    end
    tube(root, c, pts, rr, n or 7, hint, r2 / r1)
  end
  local function sph(root, c, cen, r, n) egg(root, c, cen, UP * r, r, r, n or 6) end
  local function blob(root, c, cen, r, n) egg(root, c, cen, UP * r, r * 1.25, r * 1.25, n or 5, nil, T3) end
  local function cyl(root, c, p, y0, y1, r0, r1, n) K.column(piece(root, c), p.x, p.z, y0, y1, r0, r1 or r0, n or 8, c) end
  -- A heart facing along f: two lobes leaning apart from its point.
  local function heart(root, c, cen, f, sz)
    local s = normalize(v3(-f.z, 0, f.x))
    for k = -1, 1, 2 do
      egg(root, c, cen + (UP * 0.3 + s * (k * 0.27)) * sz, normalize(UP * 0.8 + s * (k * 0.5)) * (0.62 * sz), 0.4 * sz, 0.22 * sz, 7, f)
    end
  end

  -- ---------------------------------------------------------------- where
  local function gd(x, z) local y, d = K.ground_d(x, z); return y, d - K.HW end   -- height, metres off the road's edge
  local function off(x, z) local _, d = K.ground_d(x, z); return d - K.HW end
  local function clear(x, z, m) return off(x, z) > EDGE + (m or 0.4) end
  local function at(x, z) return v3(x, K.ground(x, z), z) end
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
        u = normalize(v3(u.x, 0, u.z))
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
          s.c = at(c.x, c.z)
          function s.at(du, dw)
            local p = c + u * du + w * dw
            return at(p.x, p.z)
          end
          return s
        end
      end
    end
    return nil
  end
  local made = {}
  local function count(k, n) made[k] = (made[k] or 0) + (n or 1) end

  -- ---------------------------------------------------------------- people
  -- A guest standing at o, facing f: a man in a morning suit and top hat, a woman in a bright dress and a big hat,
  -- the bride (white, a veil, a bouquet) or the groom (black). `cheer` throws the arms up.
  local function person(o, f, kind, sc, cheer, root)
    local D = root or K.deco
    f = normalize(v3(f.x, 0, f.z))
    local s = v3(-f.z, 0, f.x)
    local function P(a, h, b) return o + f * (a * sc) + UP * (h * sc) + s * (b * sc) end
    local skin = K.pick(SKINS)
    local sleeve
    if kind == "man" or kind == "groom" then
      local suit = (kind == "groom") and BLACK or K.pick(SUITS)
      sleeve = suit
      for b = -1, 1, 2 do limb(D, TROUSER, P(0, -0.2, b * 0.1), P(0, 0.9, b * 0.11), 0.085 * sc, 0.1 * sc, 4) end
      limb(D, suit, P(0, 0.8, 0), P(0, 1.47, 0), 0.2 * sc, 0.25 * sc, 6)
      obox(D, WHITE, P(0.2, 1.27, 0), f * (0.03 * sc), UP * (0.17 * sc), s * (0.07 * sc))
      local hat = (kind == "groom") and BLACK or HATGREY
      limb(D, hat, P(0, 1.77, 0), P(0, 2.02, 0), 0.125 * sc, 0.135 * sc, 6)
      limb(D, hat, P(0, 1.755, 0), P(0, 1.79, 0), 0.215 * sc, 0.215 * sc, 6)
    else
      local dress = (kind == "bride") and WHITE or K.pick(DRESSES)
      local wide = (kind == "bride") and 0.72 or 0.45
      sleeve = skin
      limb(D, dress, P(0, -0.2, 0), P(0, 1.02, 0), wide * sc, 0.17 * sc, 7)
      limb(D, dress, P(0, 0.99, 0), P(0, 1.46, 0), 0.175 * sc, 0.215 * sc, 6)
      if kind == "bride" then
        egg(D, WHITE2, P(-0.2, 1.3, 0), (UP * 0.55 - f * 0.12) * sc, 0.3 * sc, 0.1 * sc, 6, f, T3)
        blob(D, PINK, P(0.3, 1.05, 0), 0.15 * sc)
      else
        local hat = K.pick(DRESSES)
        limb(D, hat, P(0, 1.77, 0.02), P(0.02, 1.8, 0.02), 0.36 * sc, 0.34 * sc, 7)
        blob(D, hat, P(0, 1.84, 0), 0.11 * sc, 4)
      end
    end
    for b = -1, 1, 2 do
      local hand = cheer and P(0.08, 1.98, b * 0.46) or P(0.1, 0.9, b * 0.34)
      limb(D, sleeve, P(0, 1.41, b * 0.28), hand, 0.07 * sc, 0.06 * sc, 4)
    end
    blob(D, skin, P(0, 1.63, 0), 0.115 * sc)
  end
  local function guest(o, f, sc, cheer)
    person(o, f, (rnd(0, 1) < 0.5) and "man" or "woman", sc or 1.25, cheer)
    count("guests")
  end
  -- A knot of guests round (x, z), turned to each other or to `face`.
  local function knot(x, z, n, R, face, cheer)
    for k = 1, n do
      local a = k / n * 6.283 + rnd(-0.3, 0.3)
      local px, pz = x + math.cos(a) * R, z + math.sin(a) * R
      local y, o = gd(px, pz)
      if o > EDGE + 0.5 then
        guest(v3(px, y, pz), face or v3(-math.cos(a), 0, -math.sin(a)), rnd(1.15, 1.35), cheer and rnd(0, 1) < 0.6)
      end
    end
  end

  -- ---------------------------------------------------------------- garden pieces
  -- Topiary in a terracotta pot: a cone, a ball on a stem, three balls or a cube with a ball.
  local topis = 0
  local function topiary(x, z, kind, y, sc)
    topis = topis + 1
    y = y or K.ground(x, z)
    sc = sc or 1
    local p = v3(x, y, z)
    local q = piece(K.solid, "topi" .. (topis % 4))
    local shade = K.shaded(HEDGE2)
    local function one() return 1 end
    cyl(K.solid, TERRA, p, y - 0.4, y + 0.6 * sc, 0.42 * sc, 0.56 * sc, 8)
    if kind == 1 then
      K.cone(q, K.ring(v3(x, y + 0.65 * sc, z), 1.05 * sc, 1.05 * sc, 8, rnd(0, 1)), v3(x, y + 0.65 * sc, z), v3(x, y + 4.4 * sc, z),
        function(k) return (k % 2 == 0) and HEDGE or HEDGE2 end, HEDGE)
    elseif kind == 2 then
      limb(K.solid, TRUNK, p + UP * (0.5 * sc), p + UP * (2.0 * sc), 0.1 * sc, 0.09 * sc, 5)
      K.ball(q, p + UP * (2.8 * sc), 1.1 * sc, 1.1 * sc, 1.1 * sc, 8, 5, one, shade)
    elseif kind == 3 then
      limb(K.solid, TRUNK, p + UP * (0.5 * sc), p + UP * (3.6 * sc), 0.1 * sc, 0.08 * sc, 5)
      K.ball(q, p + UP * (1.45 * sc), 1.0 * sc, 0.85 * sc, 1.0 * sc, 8, 5, one, shade)
      K.ball(q, p + UP * (2.85 * sc), 0.75 * sc, 0.65 * sc, 0.75 * sc, 8, 5, one, shade)
      K.ball(q, p + UP * (3.95 * sc), 0.5 * sc, 0.48 * sc, 0.5 * sc, 7, 4, one, shade)
    else
      obox(K.solid, HEDGE, p + UP * (1.45 * sc), v3(0.8, 0, 0.12) * sc, UP * (0.85 * sc), v3(-0.12, 0, 0.8) * sc)
      K.ball(q, p + UP * (2.8 * sc), 0.6 * sc, 0.6 * sc, 0.6 * sc, 7, 4, one, shade)
    end
  end

  -- A stone urn of flowers on a pier.
  local function urn(p, h)
    obox(K.solid, STONE2, p + UP * (h / 2 - 0.3), v3(0.36, 0, 0), UP * (h / 2 + 0.3), v3(0, 0, 0.36))
    limb(K.deco, STONE3, p + UP * (h + 0.02), p + UP * (h + 0.6), 0.16, 0.42, 6)
    blob(K.deco, K.pick(BLOOMS), p + UP * (h + 0.8), 0.33)
  end

  -- A run of stone balustrade from p0 to p1 (its foot): a plinth, square balusters, a rail.
  local function balustrade(p0, p1, root, gap)
    local len = length(p1 - p0)
    if len < 0.6 then return end
    root = root or K.deco
    local a, b = lerp(p0, p1, 0.02), lerp(p0, p1, 0.98)
    beam(root, STONE2, a - UP * 0.5, b - UP * 0.5, 0.24, 0.64)
    beam(root, STONE, a + UP * 1.02, b + UP * 1.02, 0.22, 0.08)
    local n = math.max(1, math.floor(len / (gap or 1.5) + 0.5))
    for k = 1, n do
      local m = lerp(a, b, (k - 0.5) / n)
      obox(K.deco, STONE, m + UP * 0.54, v3(0.1, 0, 0), UP * 0.41, v3(0, 0, 0.1))
    end
    count("balustrade m", math.floor(len + 0.5))
  end
  local function pier(p, root)
    obox(root or K.deco, STONE2, p + UP * 0.1, v3(0.33, 0, 0), UP * 1.25, v3(0, 0, 0.33))
  end

  -- A string of bunting from p0 to p1, sagging: n triangular flags.
  local bseed = 0
  local function bunting(p0, p1, sag, n, flag)
    local d = p1 - p0
    local hd = normalize(v3(d.x, 0, d.z))
    local nrm = v3(-hd.z, 0, hd.x) * 0.02
    flag = flag or 0.75
    local pts = {}
    for k = 0, n do
      local f = k / n
      pts[k + 1] = lerp(p0, p1, f) - UP * (sag * 4 * f * (1 - f))
    end
    for k = 1, n do
      local a, b = pts[k], pts[k + 1]
      beam(K.deco, STRING, lerp(a, b, 0.03), lerp(a, b, 0.97), 0.025, 0.025)
      bseed = bseed + 1
      local c = BUNT[bseed % #BUNT + 1]
      local m0, m1 = lerp(a, b, 0.1), lerp(a, b, 0.9)
      local tip = (m0 + m1) * 0.5 - UP * flag
      K.prism(piece(K.deco, c), {{m0 + nrm, m1 + nrm, tip + nrm}, {m0 - nrm, m1 - nrm, tip - nrm}}, K.flat(c), c, c)
    end
    count("bunting flags", n)
  end
  local function pole(p, h, root)
    beam(root or K.solid, WHITE, p - UP * 0.5, p + UP * h, 0.07, 0.07)
    blob(K.deco, GOLD, p + UP * (h + 0.12), 0.14, 4)
    return p + UP * (h - 0.1)
  end

  -- A bunch of balloons on strings from p.
  local function balloons(p, n)
    for k = 1, n do
      local a = rnd(0, 6.283)
      local top = p + UP * rnd(2.6, 4.4) + v3(math.cos(a), 0, math.sin(a)) * rnd(0.3, 1.1)
      beam(K.deco, STRING, p, top - UP * 0.5, 0.015, 0.015)
      egg(K.deco, K.pick({WHITE, PINK, GOLD, ROSE, LILAC}), top, UP * 0.62, 0.5, 0.5, 6)
    end
    count("balloons", n)
  end

  -- A rose bed: a long mound of earth, bushes in bloom.
  local function rosebed(c, u, a, b, y)
    local w = v3(-u.z, 0, u.x)
    y = y or K.ground(c.x, c.z)
    local o = v3(c.x, y, c.z)
    egg(K.deco, EARTH, o - UP * 0.1, u * a, b, 0.45, 8, UP)
    local n = math.max(3, math.floor(a * 1.5))
    for k = 1, n do
      local p = o + u * ((k - 0.5) / n * 2 - 1) * (a * 0.85) + w * rnd(-b * 0.35, b * 0.35)
      p = v3(p.x, y or K.ground(p.x, p.z), p.z)
      blob(K.deco, (k % 2 == 0) and HEDGE2 or LEAF, p + UP * 0.6, 0.42, 6)
      local bl = BLOOMS[(k + math.floor(c.x)) % #BLOOMS + 1]
      blob(K.deco, bl, p + UP * 1.1 + v3(rnd(-0.2, 0.2), 0, rnd(-0.2, 0.2)), 0.2, 4)
      blob(K.deco, bl, p + UP * 0.8 + v3(rnd(-0.45, 0.45), 0, rnd(-0.45, 0.45)), 0.18, 4)
    end
    count("rose beds")
  end

  -- A round table in a white cloth to the ground, a centrepiece, chairs in white covers with a sash each.
  local function tableset(p, sc, chairs)
    local y = p.y
    cyl(K.solid, WHITE, p, y - 0.5, y + 1.0 * sc, 1.25 * sc, 1.1 * sc, 10)
    limb(K.deco, SILVER, p + UP * (1.0 * sc + 0.01), p + UP * (1.45 * sc), 0.08 * sc, 0.14 * sc, 5)
    blob(K.deco, K.pick(BLOOMS), p + UP * (1.62 * sc), 0.24 * sc)
    local sash = K.pick({PINK, GOLD, LILAC, ROSE})
    local a0 = rnd(0, 6.283)
    for k = 1, chairs or 5 do
      local a = a0 + k / (chairs or 5) * 6.283
      local o = v3(math.cos(a), 0, math.sin(a))
      local s = v3(-o.z, 0, o.x)
      local q = p + o * (1.85 * sc)
      q = v3(q.x, K.ground(q.x, q.z), q.z)
      obox(K.deco, WHITE, q + UP * (0.1 * sc), o * (0.27 * sc), UP * (0.5 * sc), s * (0.27 * sc))
      obox(K.deco, WHITE2, q + o * (0.24 * sc) + UP * (0.95 * sc), o * (0.05 * sc), UP * (0.45 * sc), s * (0.25 * sc))
      obox(K.deco, sash, q + o * (0.25 * sc) + UP * (0.95 * sc), o * (0.07 * sc), UP * (0.09 * sc), s * (0.27 * sc))
    end
    count("tables")
  end

  -- A champagne tower on its table: coupes stacked four layers high, giant.
  local function champagne(p, sc)
    local y = p.y
    cyl(K.solid, WHITE, p, y - 0.5, y + 1.0, 1.5 * sc, 1.35 * sc, 10)
    local d, h = 0.5 * sc, 0.56 * sc
    for l = 0, 3 do
      local n = 4 - l
      local base = y + 1.03 + l * (h + 0.07 * sc)
      for i = 1, n do
        for j = 1, n do
          local q = p + v3((i - (n + 1) / 2) * d, 0, (j - (n + 1) / 2) * d)
          limb(K.deco, CHAMP, v3(q.x, base, q.z), v3(q.x, base + h, q.z), 0.05 * sc, 0.235 * sc, 6)
        end
      end
      if l < 3 then
        obox(K.deco, WHITE2, v3(p.x, base + h + 0.035 * sc, p.z), v3(n * d * 0.5 + 0.04, 0, 0), UP * (0.02 * sc), v3(0, 0, n * d * 0.5 + 0.04))
      end
    end
    -- A magnum pouring over the top.
    local top = v3(p.x, y + 1.03 + 4 * (h + 0.07 * sc) + 0.5, p.z)
    limb(K.deco, DOOR, top + v3(0.9, 0.9, 0) * sc, top + v3(0.25, 0.25, 0) * sc, 0.2 * sc, 0.2 * sc, 6)
    limb(K.deco, GOLD, top + v3(0.27, 0.27, 0) * sc, top + v3(0.02, 0.02, 0) * sc, 0.08 * sc, 0.07 * sc, 5)
    limb(K.deco, CHAMP, top, top - UP * 0.5, 0.05 * sc, 0.1 * sc, 5)
    count("champagne towers")
  end

  -- ---------------------------------------------------------------- the big pieces
  -- The manor: a long stone front of three floors of sash windows under a hipped slate roof, a wing at each end, a
  -- white portico with a pediment, steps and a red carpet, on a terrace with urns.
  local function manor(i, side)
    local s = site(i, side, 18, 8.5, 6) or site(i + 14, side, 18, 8.5, 6) or site(i - 14, side, 18, 8.5, 4)
    if not s then return end
    local u, w = s.u * (-side), s.w
    local fy = s.at(0, -8.5).y + 0.7
    local lo = math.min(K.lowest(s.c, u, w, 18, 8.5), fy - 1) - 1
    local o = v3(s.c.x, fy, s.c.z)
    local function P(a, h, b) return o + u * a + UP * h + w * b end
    local function B(root, c, a, h, b, ha, hh, hb) obox(root, c, P(a, h, b), u * ha, UP * hh, w * hb) end
    local function hip(a, b, ha, hb, y, rise, inset)
      local r1, r2 = {}, {}
      for _, m in ipairs({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do
        r1[#r1 + 1] = P(a + m[1] * ha, y, b + m[2] * hb)
        r2[#r2 + 1] = P(a + m[1] * (ha - inset), y + rise, b + m[2] * (hb - inset))
      end
      local dk = K.tint(SLATE, 0.8)
      K.prism(piece(K.solid, SLATE), {r1, r2}, function(_, k) return (k % 2 == 0) and dk or SLATE end, SLATE, dk)
    end
    local H = 11
    B(K.solid, STONE2, 0, (lo - fy) / 2, 0, 17.6, (fy - lo) / 2, 8.3)
    B(K.solid, STONE, 0, H / 2 - 0.1, 1.5, 12.5, H / 2, 4.5)
    B(K.deco, WHITE, 0, H - 0.05, 1.5, 12.75, 0.2, 4.75)
    B(K.deco, WHITE, 0, 3.75, 1.5, 12.6, 0.12, 4.6)
    hip(0, 1.5, 12.95, 4.95, H + 0.16, 3.2, 3.9)
    for k = -1, 1, 2 do
      B(K.solid, STONE, k * 14.2, H / 2 + 0.3, 0.4, 3.3, H / 2 + 0.4, 6.1)
      B(K.deco, WHITE, k * 14.2, H + 0.75, 0.4, 3.55, 0.2, 6.35)
      hip(k * 14.2, 0.4, 3.75, 6.55, H + 0.96, 2.9, 3.0)
      for f, wh in ipairs({1.9, 5.6, 8.95}) do
        B(K.deco, WHITE, k * 14.2, wh, -5.72, 1.1, 1.12, 0.04)
        B(K.deco, (rnd(0, 1) < 0.4) and LIT or GLASS, k * 14.2, wh, -5.76, 0.92, (f == 3) and 0.8 or 0.95, 0.05)
      end
      for _, a in ipairs({5.5, 10.2}) do
        B(K.solid, BRICK, k * a, H + 3.4, 1.5, 0.55, 1.5, 0.55)
        B(K.deco, STONE2, k * a, H + 4.95, 1.5, 0.68, 0.1, 0.68)
      end
      urn(P(k * 16.6, 0, -7.4), 1.0)
      urn(P(k * 5.6, 0, -7.4), 1.0)
      topiary(P(k * 8.6, 0, -6.6).x, P(k * 8.6, 0, -6.6).z, 1, fy)
      topiary(P(k * 11.3, 0, -6.6).x, P(k * 11.3, 0, -6.6).z, 2, fy)
    end
    for f, wh in ipairs({1.9, 5.6, 8.95}) do
      for a = -10.5, 10.6, 3 do
        if not (f == 1 and math.abs(a) < 2) then
          B(K.deco, WHITE, a, wh, -3.02, 0.82, 1.12, 0.04)
          B(K.deco, (rnd(0, 1) < 0.4) and LIT or GLASS, a, wh, -3.06, 0.66, (f == 3) and 0.8 or 0.95, 0.05)
        end
      end
    end
    B(K.deco, WHITE, 0, 1.75, -3.02, 1.25, 1.85, 0.05)
    B(K.deco, DOOR, 0, 1.55, -3.07, 0.95, 1.55, 0.05)
    -- The portico.
    for _, a in ipairs({-4.5, -1.6, 1.6, 4.5}) do
      local p = P(a, 0, -6.0)
      cyl(K.solid, WHITE, p, fy - 0.1, fy + 7.25, 0.46, 0.38, 8)
      obox(K.deco, WHITE2, p + UP * 0.25, u * 0.6, UP * 0.3, w * 0.6)
    end
    B(K.deco, WHITE, 0, 7.65, -4.7, 5.4, 0.42, 1.85)
    local t1, t2 = {}, {}
    for _, m in ipairs({{-5.7, 8.08}, {5.7, 8.08}, {0, 10.5}}) do
      t1[#t1 + 1] = P(m[1], m[2], -6.7)
      t2[#t2 + 1] = P(m[1], m[2], -2.9)
    end
    K.prism(piece(K.deco, STONE), {t1, t2}, K.flat(WHITE2), STONE, STONE)
    heart(K.deco, RED, P(0, 8.5, -6.85), w, 1.5)
    -- Steps down to the lawn and the red carpet.
    for k = 0, 3 do
      B(K.solid, STONE3, 0, -0.3 - k * 0.42, -8.3 - 0.45 - k * 0.8, 3.2 + k * 0.45, 0.42, 0.8)
    end
    B(K.deco, RED, 0, 0.04, -5.65, 1.05, 0.05, 2.6)
    -- Bunting from the portico out to poles on the terrace corners.
    for k = -1, 1, 2 do
      local top = pole(P(k * 17.0, 0, -7.9), 6.5)
      bunting(P(k * 5.3, 8.1, -6.6), top, 1.2, 13, 0.9)
    end
    person(P(-0.8, 0.02, -7.2), w * -1, "bride", 1.5)
    person(P(0.8, 0.02, -7.2), w * -1, "groom", 1.5)
    count("manor")
    return s
  end

  -- The cake: four wonky tiers of white icing on a silver board, pink ribbons, gold pearls, roses tumbling down, the
  -- happy couple on top.
  local function cake(i, side, sc)
    local s = site(i, side, 5.2 * sc, 5.2 * sc, 1.0)
    if not s then return end
    local c = s.c
    local y = K.lowest(c, s.u, s.w, 4.5 * sc, 4.5 * sc) - 0.5
    local top = c.y + 0.5
    cyl(K.solid, SILVER, c, y, top, 5.0 * sc, 5.0 * sc, 16)
    local R = {4.2, 3.2, 2.25, 1.4}
    local Hh = {2.4, 2.1, 1.9, 1.7}
    local p = v3(c.x, 0, c.z)
    local base = top - 0.05
    for t = 1, 4 do
      local r, h = R[t] * sc, Hh[t] * sc
      if t > 1 then p = p + v3(rnd(-0.3, 0.3), 0, rnd(-0.3, 0.3)) * sc end
      cyl(K.solid, ICING, p, base, base + h, r, r * 0.985, 16)
      cyl(K.deco, (t % 2 == 1) and PINK or ROSE, p, base + 0.12 * sc, base + 0.5 * sc, r + 0.05, r + 0.05, 16)
      local n = 16 - t * 2
      for k = 1, n do
        local a = k / n * 6.283
        blob(K.deco, GOLD, v3(p.x + math.cos(a) * r * 0.97, base + h, p.z + math.sin(a) * r * 0.97), 0.16 * sc, 4)
      end
      -- Roses down one side.
      local a0 = 2.2 + t * 0.35
      for k = 1, 4 do
        local a = a0 + rnd(-0.35, 0.35)
        local rr = r + rnd(0.0, 0.5) * sc
        blob(K.deco, (k == 4) and LEAF or K.pick({RED, ROSE, PINK}), v3(p.x + math.cos(a) * rr, base + h + 0.15 * sc, p.z + math.sin(a) * rr), rnd(0.28, 0.42) * sc, 5)
      end
      base = base + h - 0.02
    end
    local f = s.w * -1
    local sd = v3(-f.z, 0, f.x)
    person(v3(p.x, base, p.z) + sd * (0.42 * sc), f, "bride", 1.25 * sc, false, K.deco)
    person(v3(p.x, base, p.z) - sd * (0.42 * sc), f, "groom", 1.25 * sc, true, K.deco)
    count("cakes")
  end

  -- The marquee: white walls, two peaks, a scalloped pink-and-white valance, an open doorway, bunting to poles.
  local function marquee(i, side)
    local s = site(i, side, 8.2, 5.2, 1.4)
    if not s then return end
    local u, w = s.u, s.w
    local front = s.at(0, -4.6)
    local fy = front.y
    local lo = K.lowest(s.c, u, w, 7.6, 4.6) - 0.6
    local o = v3(s.c.x, fy, s.c.z)
    local function P(a, h, b) return o + u * a + UP * h + w * b end
    obox(K.solid, WHITE, P(0, (lo - fy + 3.1) / 2, 0), u * 7.5, UP * ((3.1 - lo + fy) / 2), w * 4.5)
    local tops = {}
    for k = -1, 1, 2 do
      local cen = P(k * 3.78, 3.13, 0)
      local pts = {}
      for _, m in ipairs({{-1, -1}, {0, -1}, {1, -1}, {1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}}) do
        pts[#pts + 1] = cen + u * (m[1] * 3.9) + w * (m[2] * 4.95)
      end
      local tip = cen + UP * 3.4
      K.cone(piece(K.solid, "tent"), pts, cen, tip, function(q) return (q % 2 == 0) and WHITE or WHITE2 end, WHITE2)
      tops[#tops + 1] = pole(tip - UP * 0.3, 1.6, K.deco)
      obox(K.deco, PINK, tip + UP * 1.1 + u * 0.5, u * 0.5, UP * 0.22, w * 0.02)
    end
    for k = -7, 6 do
      obox(K.deco, (k % 2 == 0) and PINK or WHITE2, P((k + 0.5) * 1.07, 2.75, -4.58), u * 0.5, UP * 0.42, w * 0.05)
    end
    obox(K.deco, GLASS, P(0, 1.2, -4.5), u * 1.5, UP * 1.25, w * 0.06)
    for k = -1, 1, 2 do
      limb(K.deco, WHITE2, P(k * 1.7, 0, -4.62), P(k * 1.7, 2.5, -4.62), 0.3, 0.22, 6)
      obox(K.deco, GOLD, P(k * 1.7, 1.3, -4.62), u * 0.3, UP * 0.08, w * 0.3)
    end
    local corners = {}
    for _, m in ipairs({{-1, -1}, {1, -1}}) do
      local g = s.at(m[1] * 8.0, m[2] * 5.0)
      corners[#corners + 1] = pole(g, 3.6)
    end
    bunting(tops[1], corners[1], 0.8, 9)
    bunting(tops[2], corners[2], 0.8, 9)
    bunting(tops[1], tops[2], 0.9, 9)
    bunting(corners[1], corners[2], 0.7, 16)
    count("marquees")
    return s
  end

  -- A flower arch over the road: two green pillars outside the walls and a half ring 6.6 m up, thick with blooms, a
  -- heart on its crown.
  local function flowerarch(i)
    local c, r, t = pos[i], right[i], K.along(i)
    t = normalize(v3(t.x, 0, t.z))
    local half = W[i] + EDGE + 1.25
    local spring = c.y + 6.7
    local function bloom(p, rr)
      local a = rnd(0, 6.283)
      local d = normalize(v3(math.cos(a) * 0.4, rnd(-1, 1), math.sin(a) * 0.4) + t * ((rnd(0, 1) < 0.5) and 1 or -1))
      blob(K.deco, K.pick(BLOOMS), p + d * rr, rnd(0.3, 0.45), 5)
    end
    for sd = -1, 1, 2 do
      local p = c + r * (sd * half)
      local gy = K.ground(p.x, p.z) - 0.6
      limb(K.solid, HEDGE, v3(p.x, gy, p.z), v3(p.x, spring + 0.05, p.z), 0.62, 0.58, 7)
      for k = 1, 8 do bloom(v3(p.x, gy + 1.0 + k * (spring - gy - 1) / 8, p.z), 0.55) end
      take(p.x, p.z, 1.4)
    end
    local n = 10
    local cen = v3(c.x, spring, c.z)
    local prev
    for k = 0, n do
      local a = k / n * math.pi
      local p = cen + r * (math.cos(a) * half) + UP * (math.sin(a) * half)
      if prev then
        limb(K.deco, (k % 2 == 0) and HEDGE or HEDGE2, lerp(prev, p, -0.04), lerp(prev, p, 1.04), 0.56, 0.56, 7)
        for q = 1, 3 do bloom(lerp(prev, p, (q - 0.5) / 3), 0.5) end
      end
      prev = p
    end
    heart(K.deco, RED, cen + UP * (half + 0.5), t, 2.2)
    count("flower arches")
  end

  -- Bunting across the road between two tall poles, well clear of the karts.
  local function crossbunt(i)
    local c, r = pos[i], right[i]
    local half = W[i] + EDGE + 0.6
    local tops = {}
    for sd = -1, 1, 2 do
      local p = c + r * (sd * half)
      local g = at(p.x, p.z)
      tops[#tops + 1] = pole(g, c.y + 9.4 - g.y)
      take(p.x, p.z, 0.6)
    end
    bunting(tops[1], tops[2], 1.3, 12, 0.9)
  end

  -- The fountain: a round stone basin, two bowls on a stem, jets falling from each.
  local function fountain(i, side)
    local s = site(i, side, 4.4, 4.4, 1.2)
    if not s then return end
    local c = s.c
    local y = c.y + 0.3
    local lo = K.lowest(c, s.u, s.w, 4, 4) - 0.6
    cyl(K.solid, STONE2, c, lo, y + 0.75, 3.9, 3.8, 14)
    cyl(K.deco, WATER, c, y + 0.5, y + 0.86, 3.45, 3.45, 14)
    cyl(K.solid, STONE, c, y + 0.6, y + 2.7, 0.55, 0.4, 8)
    cyl(K.solid, STONE, c, y + 2.6, y + 3.1, 0.5, 2.0, 10)
    cyl(K.deco, WATER, c, y + 3.0, y + 3.2, 1.8, 1.8, 10)
    cyl(K.solid, STONE2, c, y + 3.05, y + 4.5, 0.32, 0.25, 7)
    cyl(K.solid, STONE, c, y + 4.4, y + 4.8, 0.3, 1.0, 8)
    cyl(K.deco, WATER, c, y + 4.72, y + 4.9, 0.86, 0.86, 8)
    limb(K.deco, SPRAY, c + UP * (4.8 - c.y + y), c + UP * (6.6 - c.y + y), 0.22, 0.04, 5)
    local cc = v3(c.x, y, c.z)
    for k = 1, 8 do
      local a = k / 8 * 6.283
      local d = v3(math.cos(a), 0, math.sin(a))
      limb(K.deco, SPRAY, cc + d * 0.85 + UP * 4.85, cc + d * 1.5 + UP * 3.15, 0.04, 0.06, 4)
      if k % 2 == 0 then limb(K.deco, SPRAY, cc + d * 1.85 + UP * 3.15, cc + d * 2.9 + UP * 0.85, 0.05, 0.08, 4) end
    end
    count("fountains")
    return s
  end

  -- The string quartet on a white round stage: four in black, seated, two violins, a viola and a cello, their stands.
  local function quartet(i, side)
    local s = site(i, side, 3.6, 3.0, 1.0)
    if not s then return end
    local c = s.c
    local lo = K.lowest(c, s.u, s.w, 3.2, 2.8) - 0.5
    local y = c.y + 0.45
    cyl(K.solid, WHITE, c, lo, y, 3.4, 3.4, 12)
    cyl(K.deco, PINK, c, y - 0.3, y - 0.12, 3.44, 3.44, 12)
    local sc = 1.35
    for k = 1, 4 do
      local a = (k - 2.5) * 0.62
      local out = normalize(s.w * math.cos(a) + s.u * math.sin(a))      -- from the stage's front-centre to the player
      local o = v3(c.x, y, c.z) - s.w * 1.2 + out * 2.3
      local f = normalize(s.w * -1 + (s.u * -math.sin(a)) * 0.5)         -- facing the road
      local sd = v3(-f.z, 0, f.x)
      local function P(q, h, b) return o + f * (q * sc) + UP * (h * sc) + sd * (b * sc) end
      obox(K.deco, GOLD, P(-0.05, 0.25, 0), f * (0.24 * sc), UP * (0.25 * sc), sd * (0.24 * sc))
      obox(K.deco, GOLD, P(-0.27, 0.8, 0), f * (0.03 * sc), UP * (0.32 * sc), sd * (0.22 * sc))
      for b = -1, 1, 2 do
        limb(K.deco, BLACK, P(0, 0.55, b * 0.12), P(0.45, 0.55, b * 0.14), 0.1 * sc, 0.09 * sc, 4)
        limb(K.deco, BLACK, P(0.45, 0.58, b * 0.14), P(0.48, 0, b * 0.14), 0.08 * sc, 0.07 * sc, 4)
      end
      limb(K.deco, BLACK, P(0, 0.5, 0), P(0, 1.15, 0), 0.2 * sc, 0.24 * sc, 6)
      blob(K.deco, K.pick(SKINS), P(0, 1.32, 0), 0.115 * sc)
      blob(K.deco, K.pick(HAIRS), P(-0.05, 1.4, 0), 0.105 * sc)
      if k == 4 then
        -- the cello, upright between the knees
        egg(K.deco, WOOD, P(0.5, 0.62, 0), UP * (0.5 * sc), 0.3 * sc, 0.14 * sc, 7, sd)
        limb(K.deco, WOOD2, P(0.48, 1.05, 0), P(0.4, 1.75, 0), 0.04 * sc, 0.035 * sc, 4)
        limb(K.deco, BLACK, P(0.5, 0.15, 0), P(0.5, -0.02, 0), 0.02 * sc, 0.02 * sc, 4)
        limb(K.deco, BLACK, P(0.05, 1.08, 0.26), P(0.52, 0.8, 0.1), 0.06 * sc, 0.05 * sc, 4)
        limb(K.deco, BLACK, P(0.05, 1.08, -0.26), P(0.44, 1.35, -0.05), 0.06 * sc, 0.05 * sc, 4)
        beam(K.deco, WHITE, P(0.66, 0.75, -0.5), P(0.66, 0.85, 0.5), 0.015, 0.015)
      else
        -- a violin under the chin, the bow across it
        local v0, v1 = P(0.12, 1.2, 0.12), P(0.42, 1.12, 0.5)
        egg(K.deco, (k == 2) and WOOD2 or WOOD, lerp(v0, v1, 0.4), (v1 - v0) * 0.42, 0.14 * sc, 0.05 * sc, 6, UP)
        limb(K.deco, BLACK, lerp(v0, v1, 0.7), lerp(v0, v1, 1.35), 0.025 * sc, 0.02 * sc, 4)
        limb(K.deco, BLACK, P(0.05, 1.08, 0.26), lerp(v0, v1, 1.2), 0.06 * sc, 0.05 * sc, 4)
        limb(K.deco, BLACK, P(0.05, 1.08, -0.26), P(0.42, 1.2, -0.05), 0.06 * sc, 0.05 * sc, 4)
        beam(K.deco, WHITE, P(0.42, 1.2, -0.1), P(0.3, 1.5, 0.55), 0.015, 0.015)
      end
      -- the music stand
      beam(K.deco, BLACK, P(1.0, 0, 0), P(1.0, 0.95, 0), 0.025, 0.025)
      obox(K.deco, BLACK, P(1.0, 1.1, 0), (f * 0.05 + UP * 0.02) * sc, (UP * 0.2 - f * 0.06) * sc, sd * (0.26 * sc))
      obox(K.deco, WHITE, P(0.96, 1.11, 0), (f * 0.02 + UP * 0.01) * sc, (UP * 0.16 - f * 0.05) * sc, sd * (0.2 * sc))
    end
    count("quartets")
    return s
  end

  -- The wedding car: a cream vintage tourer, a white ribbon over its bonnet, JUST MARRIED hearts and tin cans behind.
  local function car(i, side)
    local s = site(i, side, 4.6, 1.9, 0.9)
    if not s then return end
    local sc = 1.3
    local p0, p1, q0, q1 = s.at(-2, 0), s.at(2, 0), s.at(0, -1), s.at(0, 1)
    local f, sd = normalize(p1 - p0), normalize(q1 - q0)
    local up = normalize(cross(sd, f))
    if up.y < 0 then up = up * -1 end
    local o = (p0 + p1 + q0 + q1) * 0.25 + f * 0.6
    local function P(a, h, b) return o + f * (a * sc) + up * (h * sc) + sd * (b * sc) end
    local function B(root, c, a, h, b, ha, hh, hb) obox(root, c, P(a, h, b), f * (ha * sc), up * (hh * sc), sd * (hb * sc)) end
    B(K.solid, BLACK, 0, 0.42, 0, 2.35, 0.07, 0.88)
    B(K.solid, IVORY, 1.2, 0.93, 0, 0.88, 0.36, 0.48)
    B(K.deco, CHROME, 2.1, 0.93, 0, 0.05, 0.44, 0.42)
    blob(K.deco, CHROME, P(2.1, 1.48, 0), 0.07 * sc, 4)
    B(K.solid, IVORY, -0.55, 0.98, 0, 0.98, 0.46, 0.74)
    B(K.deco, GLASS, -0.5, 1.68, 0, 0.84, 0.27, 0.68)
    B(K.deco, IVORY, -0.55, 1.99, 0, 0.98, 0.06, 0.76)
    B(K.solid, IVORY, -1.9, 0.86, 0, 0.42, 0.3, 0.6)
    for a = -1, 1, 2 do
      for b = -1, 1, 2 do
        local wc = P(a * 1.5, 0.42, b * 0.86)
        limb(K.solid, BLACK, wc - sd * (0.13 * sc), wc + sd * (0.13 * sc), 0.43 * sc, 0.43 * sc, 10)
        limb(K.deco, WHITE, wc - sd * (0.15 * sc), wc + sd * (0.15 * sc), 0.27 * sc, 0.27 * sc, 8)
        B(K.deco, BLACK, a * 1.5, 0.92, b * 0.86, 0.58, 0.04, 0.17)
      end
    end
    local sw = P(-2.42, 0.95, 0)
    limb(K.deco, BLACK, sw - f * (0.1 * sc), sw + f * (0.1 * sc), 0.4 * sc, 0.4 * sc, 10)
    for b = -1, 1, 2 do
      blob(K.deco, CHROME, P(2.08, 1.15, b * 0.66), 0.13 * sc, 5)
      beam(K.deco, WHITE, P(2.14, 1.42, 0), P(0.32, 1.76, b * 0.72), 0.07 * sc, 0.02, up)
    end
    blob(K.deco, PINK, P(2.12, 1.45, 0), 0.16 * sc, 5)
    -- The board and its hearts, and the cans.
    B(K.deco, WHITE, -2.6, 0.5, 0, 0.03, 0.2, 0.62)
    for b = -1, 1, 2 do heart(K.deco, RED, P(-2.66, 0.36, b * 0.3), f * -1, 0.3 * sc) end
    for k = 1, 6 do
      local b = (k - 3.5) * 0.3
      local e = s.at(-2 + (-2.9 - rnd(0.5, 2.4)) * sc + 0.6, b * 1.6 + rnd(-0.3, 0.3)) + UP * 0.14
      local from = P(-2.36, 0.4, b * 0.8)
      local d = normalize(v3(rnd(-1, 1), 0, rnd(-1, 1)) + v3(0.01, 0, 0))
      if clear(e.x, e.z, 0.5) then
        beam(K.deco, STRING, from, e, 0.015, 0.015)
        limb(K.deco, (k % 2 == 0) and SILVER or CHROME, e - d * 0.2, e + d * 0.2, 0.14, 0.14, 6)
      end
    end
    count("wedding cars")
    return s
  end

  -- A confetti cannon aimed up over the road: a striped barrel on a block, a burst of paper above.
  local function cannon(i, side)
    local j = math.max(3, math.min(N - 2, i))
    local w = right[j] * side
    local p = pos[j] + w * (W[j] + EDGE + 1.3)
    if not (clear(p.x, p.z, 0.8) and free(p.x, p.z, 0.8)) then return end
    take(p.x, p.z, 1.0)
    local g = at(p.x, p.z)
    local dir = normalize(UP * 1 - w * 0.4)
    local c1, c2 = K.pick({RED, BLUE, LILAC, TEAL}), GOLD
    obox(K.solid, BLACK, g + UP * 0.2, v3(0.55, 0, 0), UP * 0.6, v3(0, 0, 0.55))
    local b0 = g + UP * 0.7
    for k = 0, 3 do
      limb(K.solid, (k % 2 == 0) and c1 or c2, b0 + dir * (k * 0.55), b0 + dir * (k * 0.55 + 0.53), 0.3 + k * 0.045, 0.3 + (k + 1) * 0.045, 8)
    end
    local mouth = b0 + dir * 2.3
    local e1, e2 = perp(dir)
    local n = 0
    for _ = 1, 34 do
      local dist = rnd(1.5, 8.5)
      local spread = dist * 0.42
      local q = mouth + dir * dist + e1 * rnd(-spread, spread) + e2 * rnd(-spread, spread)
      local _, o = gd(q.x, q.z)
      if o > EDGE + 0.3 or q.y > pos[j].y + 6.6 then
        local a = normalize(v3(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)) + v3(0.01, 0, 0))
        local b1, b2 = perp(a)
        obox(K.deco, K.pick(BRIGHT), q, b1 * 0.2, a * 0.015, b2 * 0.13)
        n = n + 1
      end
    end
    count("cannons")
    count("confetti", n)
  end

  -- ---------------------------------------------------------------- the wedding, laid out down the road
  local S, F = K.start, K.fin
  cake(S + 4, 1, 1)
  marquee(S + 10, -1)
  manor(S + 26, -1)
  flowerarch(math.min(N - 4, S + 17))

  -- A reception lawn: tables, a champagne tower, guests.
  local function reception(i, side)
    local s = site(i, side, 6.5, 4.2, 1.0)
    if not s then return end
    tableset(s.at(-4.2, -1.6), 1.3, 5)
    tableset(s.at(4.2, -1.4), 1.3, 5)
    tableset(s.at(0, 2.0), 1.3, 6)
    if rnd(0, 1) < 0.6 then champagne(s.at(0, -2.4), 1.5) else knot(s.at(0, -2.4).x, s.at(0, -2.4).z, 4, 1.0) end
    local g = s.at(-4.4, 2.2)
    knot(g.x, g.z, 3, 0.9)
    g = s.at(4.4, 2.4)
    knot(g.x, g.z, 3, 0.9)
    count("receptions")
  end
  local function roses(i, side)
    local s = site(i, side, 5.5, 2.4, 0.8)
    if not s then return end
    for k = -1, 1, 2 do
      local c = s.at(k * 2.8, 0)
      rosebed(c, s.u, 2.3, 1.5)
    end
    topiary(s.c.x, s.c.z, irnd(4))
    urn(s.at(-5.3, -1.8), 0.8)
    urn(s.at(5.3, -1.8), 0.8)
  end
  local function toast(i, side)
    local s = site(i, side, 3.2, 3.2, 1.0)
    if not s then return end
    champagne(s.c, 1.9)
    knot(s.c.x, s.c.z, 6, 3.4, nil, true)
  end

  local plan = {
    {S + 40, 1, reception}, {S + 44, -1, roses}, {S + 52, -1, fountain}, {S + 56, 1, quartet},
    {S + 64, 1, car}, {S + 68, -1, reception}, {S + 78, 1, roses}, {S + 82, -1, toast},
    {S + 92, -1, marquee}, {S + 96, 1, reception}, {S + 108, 1, fountain}, {S + 110, -1, roses},
    {S + 120, -1, quartet}, {S + 124, 1, toast}, {S + 134, 1, roses}, {S + 138, -1, reception},
    {S + 148, -1, car}, {S + 152, 1, marquee}, {S + 162, 1, roses}, {S + 164, -1, toast},
    {S + 174, -1, fountain}, {S + 176, 1, reception}, {S + 20, 1, roses}, {S - 4, -1, car}, {S - 5, 1, reception},
  }
  for _, e in ipairs(plan) do
    if e[1] > 4 and e[1] < F - 14 then e[3](e[1], e[2]) end
  end
  flowerarch(S + 88)
  flowerarch(S + 144)
  for _, i in ipairs({S + 34, S + 60, S + 104, S + 128, S + 168}) do
    if i < F - 16 then crossbunt(i) end
  end

  -- The finish: a second cake, cannons either side firing over the road, balloons, a cheering crowd, and paper
  -- everywhere.
  flowerarch(math.max(8, F - 14))
  for _, di in ipairs({-9, -5, -1, 3}) do
    for sd = -1, 1, 2 do cannon(F + di, sd) end
  end
  cake(math.min(N - 4, F + 7), -1, 0.7)
  crossbunt(math.max(8, F - 3))
  for i = math.max(6, F - 12), math.min(N - 3, F + 8), 2 do
    for sd = -1, 1, 2 do
      local p = pos[i] + right[i] * (sd * (W[i] + EDGE + rnd(2.4, 4.5)))
      if clear(p.x, p.z, 1.0) and free(p.x, p.z, 0.9) then
        take(p.x, p.z, 0.9)
        local g = at(p.x, p.z)
        if (i / 2 + (sd + 1) / 2) % 2 < 1 then
          balloons(g, 5)
        else
          guest(g, right[i] * -sd, rnd(1.2, 1.4), true)
          local g2 = at(p.x + 0.9, p.z + 0.7)
          if clear(g2.x, g2.z, 0.6) then guest(g2, right[i] * -sd, rnd(1.2, 1.4), true) end
        end
      end
    end
  end
  local strewn = 0
  for _ = 1, 420 do
    local i = math.floor(rnd(math.max(4, F - 16), math.min(N - 2, F + 10)))
    local sd = (rnd(0, 1) < 0.5) and -1 or 1
    local p = pos[i] + right[i] * (sd * (W[i] + EDGE + 0.3 + rnd(0, 1) ^ 2 * 11)) + v3(rnd(-1.2, 1.2), 0, rnd(-1.2, 1.2))
    local y, o = gd(p.x, p.z)
    if o > EDGE + 0.3 then
      local a = rnd(0, 6.283)
      local d = v3(math.cos(a), 0, math.sin(a))
      obox(K.deco, K.pick(BRIGHT), v3(p.x, y + 0.07, p.z), d * 0.24, UP * 0.035, v3(-d.z, 0, d.x) * 0.15)
      strewn = strewn + 1
    end
  end
  count("confetti", strewn)

  -- Along the road, in stretches: a clipped hedge with topiary at its ends, or a stone balustrade with urns; and
  -- bunting from pole to pole over some.
  for sd = -1, 1, 2 do
    local pts = {}
    for i = 3, N - 2 do
      local p = pos[i] + right[i] * (sd * (W[i] + EDGE + 1.05))
      local y, o = gd(p.x, p.z)
      pts[i] = (o > EDGE + 0.6 and free(p.x, p.z, 0.7)) and v3(p.x, y, p.z) or false
    end
    for i = 3, N - 3 do
      local a, b = pts[i], pts[i + 1]
      local block = math.floor(i / 12)
      local h = K.hash(block * 7.3 + sd, 3.1)
      local first, last = (i % 12 == 0) or not pts[i - 1], (i % 12 == 11) or not pts[i + 2]
      if a and b and length(b - a) > 0.8 and length(b - a) < 6 then
        if h < 0.5 then
          local hh = 0.62 + 0.12 * ((i % 2 == 0) and 1 or 0)
          beam(K.solid, (i % 2 == 0) and HEDGE or HEDGE2, lerp(a, b, 0.02) + UP * (hh - 0.4), lerp(a, b, 0.98) + UP * (hh - 0.4), 0.5, hh)
          count("hedge m", math.floor(length(b - a) + 0.5))
          if first then topiary(a.x - right[i].x * sd * -1.0, a.z - right[i].z * sd * -1.0, 1 + block % 4) end
        elseif h < 0.78 then
          balustrade(a, b, K.solid)
          if first then urn(a, 1.25) end
          if last and i % 12 ~= 11 then urn(b, 1.25) end
        end
      end
      if a and i % 4 == 0 and K.hash(block * 3.7 + sd, 9.2) < 0.45 then
        local q = pts[i + 4]
        if q and length(q - a) < 16 then
          local out = right[i] * (sd * 0.75)
          local out2 = right[i + 4] * (sd * 0.75)
          local t0, t1 = pole(a + out, 4.3), pole(q + out2 + v3(0.03, 0, 0.03), 4.3)
          bunting(t0, t1, 0.7, 9)
        end
      end
    end
  end

  -- The terraces' edges: a stone balustrade along the lip of each, where the valley's own grid says the lawn drops
  -- (the grid's cells marched, so the rail lies on the ground as drawn), a pier with a ball where two runs meet.
  local STEP = CELL or 5          -- the grid's own cell, as T.paint found it
  local cells, vert_h, piers = {}, {}, {}
  local cols = math.floor((K.X1 - K.X0) / STEP) + 1
  local function vh(cx, cz)
    local key = cz * cols + cx
    local v = vert_h[key]
    if not v then
      local x, z = K.X0 + cx * STEP, K.Z0 - cz * STEP
      local y, o = gd(x, z)
      v = {x = x, z = z, y = y, o = o}
      vert_h[key] = v
    end
    return v
  end
  for i = 3, N - 2 do
    for sd = -1, 1, 2 do
      for dist = 17, 27, 3 do
        local p = pos[i] + right[i] * (sd * (W[i] + dist))
        local cx, cz = math.floor((p.x - K.X0) / STEP), math.floor((K.Z0 - p.z) / STEP)
        cells[cz * cols + cx] = {cx, cz}
      end
    end
  end
  local keys = {}
  for k in pairs(cells) do keys[#keys + 1] = k end
  table.sort(keys)
  local function pier_at(p)
    local key = math.floor(p.x * 10 + 0.5) * 100000 + math.floor(p.z * 10 + 0.5)
    if not piers[key] then
      piers[key] = true
      pier(p)
    end
  end
  for _, k in ipairs(keys) do
    local cx, cz = cells[k][1], cells[k][2]
    local v = {vh(cx, cz), vh(cx + 1, cz), vh(cx + 1, cz + 1), vh(cx, cz + 1)}
    local hmax, hmin, omin = -math.huge, math.huge, math.huge
    for q = 1, 4 do
      hmax = math.max(hmax, v[q].y); hmin = math.min(hmin, v[q].y); omin = math.min(omin, v[q].o)
    end
    local L = math.floor((hmax + 0.7) / TERR)
    local lip = TERR * L - 0.7
    if omin > 15.5 and hmin < lip - 0.5 and hmax - hmin < TERR * 1.6 then
      local cross_pts = {}
      for q = 1, 4 do
        local a, b = v[q], v[q % 4 + 1]
        if (a.y < lip) ~= (b.y < lip) then
          local f = (lip - a.y) / (b.y - a.y)
          cross_pts[#cross_pts + 1] = v3(a.x + (b.x - a.x) * f, lip, a.z + (b.z - a.z) * f)
        end
      end
      if #cross_pts == 2 then
        local a, b = cross_pts[1], cross_pts[2]
        local len = length(b - a)
        if len > 1.2 then
          local d = (b - a) * (1 / len)
          balustrade(a + d * 0.36, b - d * 0.36, nil, 2.4)
          pier_at(a)
          pier_at(b)
        end
      end
    end
  end

  -- On the terraces: wherever a lawn lies level, topiary, rose beds, tables, knots of guests.
  local function lawn(lo, hi, R)
    for _ = 1, 8 do
      local i = math.floor(rnd(4, N - 3))
      local sd = (rnd(0, 1) < 0.5) and -1 or 1
      local p = pos[i] + right[i] * (sd * (W[i] + rnd(lo, hi)))
      local cx, cz = math.floor((p.x - K.X0) / STEP), math.floor((K.Z0 - p.z) / STEP)
      local lo_y, hi_y, omin = math.huge, -math.huge, math.huge
      for _, m in ipairs({{0, 0}, {1, 0}, {1, 1}, {0, 1}}) do
        local v = vh(cx + m[1], cz + m[2])
        lo_y, hi_y, omin = math.min(lo_y, v.y), math.max(hi_y, v.y), math.min(omin, v.o)
      end
      if hi_y - lo_y < 0.3 and omin > 12 then
        local j = math.max(0, STEP / 2 - R - 0.2)
        local x, z = K.X0 + (cx + 0.5) * STEP + rnd(-j, j), K.Z0 - (cz + 0.5) * STEP + rnd(-j, j)
        if free(x, z, R) then
          take(x, z, R)
          return v3(x, (lo_y + hi_y) / 2, z), i, sd
        end
      end
    end
    return nil
  end
  local function lawns(n, lo, hi, R, fn)
    local got = 0
    for _ = 1, n do
      local p, i, sd = lawn(lo, hi, R)
      if p then fn(p, i, sd); got = got + 1 end
    end
    return got
  end
  lawns(34, 19, 40, 1.4, function(p) topiary(p.x, p.z, irnd(4), p.y, rnd(1.1, 1.6)) end)
  lawns(12, 19, 38, 2.6, function(p, i) rosebed(p, normalize(v3(K.along(i).x, 0, K.along(i).z)), 2.4, 1.5, p.y) end)
  lawns(12, 19, 36, 2.6, function(p)
    tableset(p, 1.3, 5)
    if rnd(0, 1) < 0.6 then guest(p + v3(2.9, 0, 0.6), v3(-1, 0, 0), 1.3) end
  end)
  lawns(14, 19, 36, 1.6, function(p, i, sd)
    for k = 1, 3 do
      local a = k * 2.1 + rnd(-0.3, 0.3)
      guest(p + v3(math.cos(a), 0, math.sin(a)) * 1.0, right[i] * -sd, rnd(1.2, 1.4), rnd(0, 1) < 0.3)
    end
  end)
  lawns(8, 19, 36, 1.2, function(p) balloons(p, 4) end)

  local list = {}
  for k, n in pairs(made) do list[#list + 1] = n .. " " .. k end
  table.sort(list)
  info("wedding: " .. table.concat(list, ", ") .. ", " .. topis .. " topiary")
end

return T
