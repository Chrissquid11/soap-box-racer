-- The Council Tip's scenery kit (see THEME KITS in _course.lua): a recycling centre and landfill on mud and gravel.
-- Big coloured skips under their signs (WOOD, METAL, GARDEN, ELECTRICAL, RUBBLE and one of REJECTS: rival karts),
-- heaps of junk -- sofas, armchairs, fridges, washing machines, tellies, mattresses, tyres, bikes, prams, broken
-- soap-box karts -- traffic cones, grab cranes dangling a find over the road, bulldozers, a portakabin office, a
-- weighbridge with a skip lorry on it, mounds of black bin bags and the gulls circling over them.
-- Every piece is one colour's (K.sub by colour) but the banded and shaded ones, a few colours each.
local T = {trees = 0.2}

-- The ground: gravel by the road, then a patchwork of mud, wet mud, hardcore and sour scrub, puddles here and there.
local PAL
function T.paint(x, z, off, ink, TK)
  if not PAL then
    PAL = {gravel = TK.col(0.36, 0.34, 0.3), gravel2 = TK.col(0.29, 0.27, 0.24), mud = TK.col(0.24, 0.16, 0.09),
      mud2 = TK.col(0.16, 0.105, 0.06), clay = TK.col(0.36, 0.25, 0.14), scrub = TK.col(0.25, 0.27, 0.12),
      puddle = TK.col(0.16, 0.2, 0.24), ash = TK.col(0.2, 0.2, 0.2)}
  end
  if off < -0.5 then return nil end
  local h2 = TK.hash(math.floor(x / 3) + 31, math.floor(z / 3) + 7)
  if off < 7 then
    if h2 > 0.93 then return PAL.puddle end
    return (h2 > 0.45) and PAL.gravel or PAL.gravel2
  end
  local h = TK.hash(math.floor(x / 11), math.floor(z / 11))
  if h2 > 0.95 then return PAL.puddle end
  if h < 0.28 then return (h2 > 0.5) and PAL.mud or PAL.mud2 end
  if h < 0.46 then return (h2 > 0.4) and PAL.clay or PAL.mud end
  if h < 0.62 then return (h2 > 0.5) and PAL.gravel or PAL.gravel2 end
  if h < 0.72 then return (h2 > 0.6) and PAL.ash or PAL.gravel2 end
  if h < 0.86 then return (h2 > 0.3) and PAL.scrub or PAL.mud end
  return (h2 > 0.5) and PAL.mud2 or PAL.clay
end

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local function rnd(a, b) return K.g:range(a, b) end
  local EDGE = K.WALL_T + 1          -- the road's own margin: nothing of the kit's nearer its edge
  local D, S = K.deco, K.solid

  local WHITE, BLACK = col(0.93, 0.93, 0.9), col(0.03, 0.03, 0.03)
  local CREAM, MINT = col(0.9, 0.85, 0.68), col(0.55, 0.85, 0.7)
  local WOODS = {col(0.45, 0.3, 0.16), col(0.36, 0.25, 0.15), col(0.52, 0.38, 0.22)}
  local STEEL, DKGREY, HUB, RUST = col(0.5, 0.53, 0.55), col(0.14, 0.14, 0.15), col(0.45, 0.45, 0.47), col(0.5, 0.2, 0.07)
  local RED, YEL, BLUE, GREEN, PINK, TEAL, PURPLE, ORANGE = col(0.88, 0.08, 0.05), col(0.98, 0.75, 0.03),
    col(0.08, 0.3, 0.9), col(0.1, 0.55, 0.16), col(0.98, 0.45, 0.65), col(0.05, 0.6, 0.62), col(0.5, 0.15, 0.75),
    col(0.98, 0.38, 0.02)
  local BRIGHT = {RED, YEL, BLUE, GREEN, PINK, TEAL, PURPLE, ORANGE}
  local SOFAS = {{col(0.55, 0.3, 0.12), col(0.75, 0.55, 0.3)}, {col(0.75, 0.2, 0.3), PINK}, {col(0.8, 0.6, 0.1), CREAM},
    {col(0.1, 0.4, 0.42), TEAL}, {col(0.35, 0.5, 0.2), col(0.7, 0.75, 0.3)}, {col(0.4, 0.2, 0.5), col(0.8, 0.6, 0.85)}}
  local GLASS, SCREEN = col(0.1, 0.2, 0.35), col(0.45, 0.6, 0.55)
  local MATT, MSTRIPE = col(0.85, 0.82, 0.7), col(0.3, 0.45, 0.8)
  local BAG, BAG_HI = col(0.035, 0.035, 0.04), col(0.13, 0.13, 0.15)
  local MUD, MUD_HI = col(0.22, 0.15, 0.09), col(0.33, 0.25, 0.16)
  local LEAF = col(0.2, 0.5, 0.1)
  local LEAFS = K.shaded(LEAF)
  local RUBBLE, RUBBLE2 = col(0.55, 0.53, 0.5), col(0.4, 0.38, 0.36)
  local BEAK, GULLGREY = col(0.98, 0.7, 0.05), col(0.55, 0.58, 0.62)
  local CABIN, CABIN2 = col(0.72, 0.76, 0.7), col(0.25, 0.3, 0.3)
  local SIGN_G, SIGN_BR, SIGN_GY, SIGN_BL, SIGN_R = col(0.03, 0.35, 0.12), col(0.4, 0.22, 0.08), col(0.25, 0.28, 0.32),
    col(0.05, 0.2, 0.6), col(0.7, 0.05, 0.03)
  local SKIP_Y, SKIP_B, SKIP_G, SKIP_R, SKIP_O = {YEL, col(0.6, 0.42, 0.02)}, {BLUE, col(0.04, 0.15, 0.5)},
    {GREEN, col(0.05, 0.3, 0.08)}, {RED, col(0.5, 0.04, 0.03)}, {ORANGE, col(0.6, 0.2, 0.01)}

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
  -- A round tube through pts, radius rr[j] at each, n-sided; c a colour, or colour(j, k) with a key for its piece.
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
  local function egg(root, c, cen, axis, r1, r2, n, hint)
    local pts, rr = {}, {}
    for _, t in ipairs(T5) do
      pts[#pts + 1] = cen + axis * t
      rr[#rr + 1] = r1 * math.sqrt(1 - t * t)
    end
    tube(root, c, pts, rr, n or 6, hint, r2 / r1)
  end
  local function sph(root, c, cen, r, n) egg(root, c, cen, UP * r, r, r, n or 6) end

  -- A thing's own frame: P(a, h, b) is a forward, h up, b to its side (times its scale).
  local function frame(o, f, up, sc)
    up = normalize(up or UP)
    local s = cross(up, f)
    if length(s) < 0.05 then s = cross(up, v3(1, 0, 0.3)) end
    s = normalize(s)
    f = normalize(cross(s, up))
    sc = sc or 1
    local F = {o = o, f = f, s = s, up = up, sc = sc}
    function F.P(a, h, b) return o + f * (a * sc) + up * (h * sc) + s * (b * sc) end
    function F.box(root, c, a, h, b, ha, hh, hb) obox(root, c, F.P(a, h, b), f * (ha * sc), up * (hh * sc), s * (hb * sc)) end
    function F.bar(root, c, a0, h0, b0, a1, h1, b1, t) beam(root, c, F.P(a0, h0, b0), F.P(a1, h1, b1), t * sc, t * sc) end
    -- A wheel: its axle along the side.
    function F.disc(root, c, a, h, b, r, th, n) limb(root, c, F.P(a, h, b - th), F.P(a, h, b + th), r * sc, r * sc, n or 8) end
    return F
  end
  local function gnormal(x, z, r)
    local hx = K.ground(x + r, z) - K.ground(x - r, z)
    local hz = K.ground(x, z + r) - K.ground(x, z - r)
    return normalize(v3(-hx / (2 * r), 1, -hz / (2 * r)))
  end
  local function gframe(x, z, ang, sc, sink)
    return frame(v3(x, K.ground(x, z) - (sink or 0.08), z), v3(math.cos(ang), 0, math.sin(ang)), gnormal(x, z, 1), sc)
  end

  -- ---------------------------------------------------------------- lettering: 5 rows a glyph, a box a run
  local FONT = {
    A = {"010", "101", "111", "101", "101"}, B = {"110", "101", "110", "101", "110"}, C = {"011", "100", "100", "100", "011"},
    D = {"110", "101", "101", "101", "110"}, E = {"111", "100", "110", "100", "111"}, F = {"111", "100", "110", "100", "100"},
    G = {"0111", "1000", "1011", "1001", "0110"}, H = {"101", "101", "111", "101", "101"}, I = {"1", "1", "1", "1", "1"},
    J = {"001", "001", "001", "101", "010"}, K = {"1001", "1010", "1100", "1010", "1001"}, L = {"100", "100", "100", "100", "111"},
    M = {"10001", "11011", "10101", "10001", "10001"}, N = {"1001", "1101", "1011", "1001", "1001"},
    O = {"111", "101", "101", "101", "111"}, P = {"110", "101", "110", "100", "100"}, R = {"110", "101", "110", "101", "101"},
    S = {"011", "100", "010", "001", "110"}, T = {"111", "010", "010", "010", "010"}, U = {"101", "101", "101", "101", "111"},
    W = {"10001", "10001", "10101", "11011", "10001"}, Y = {"101", "101", "010", "010", "010"},
  }
  local function textw(str)
    local w = 0
    for k = 1, #str do
      local gl = FONT[str:sub(k, k)]
      w = w + (gl and #gl[1] or 2) + 1
    end
    return w - 1
  end
  -- str centred on cen: tx the way it reads, up its up, nrm towards the reader; px a pixel's size.
  local function text(root, c, cen, tx, up, nrm, str, px)
    local x = -textw(str) / 2
    for i = 1, #str do
      local gl = FONT[str:sub(i, i)]
      if gl then
        for r = 1, 5 do
          local row, k = gl[r], 1
          while k <= #row do
            if row:sub(k, k) == "1" then
              local k2 = k
              while k2 < #row and row:sub(k2 + 1, k2 + 1) == "1" do k2 = k2 + 1 end
              obox(root, c, cen + tx * ((x + (k - 1 + k2) / 2) * px) + up * ((3 - r) * px) + nrm * 0.035,
                tx * ((k2 - k + 1) * px / 2 - px * 0.04), up * (px * 0.47), nrm * 0.03)
              k = k2 + 1
            else
              k = k + 1
            end
          end
        end
        x = x + #gl[1] + 1
      else
        x = x + 3
      end
    end
  end
  -- A sign board read from the side w points away from (w: from the reader to the board), on two posts or none.
  local function signboard(cen, w, label, c, px, posts)
    local tx = normalize(cross(w, UP))
    local hw = textw(label) * px / 2 + px * 1.6
    obox(D, c, cen, tx * hw, UP * (px * 4.2), w * 0.06)
    obox(D, WHITE, cen + w * 0.02, tx * (hw + px * 0.5), UP * (px * 4.7), w * 0.05)
    text(D, WHITE, cen - w * 0.06, tx, UP, w * -1, label, px)
    if posts then
      for sd = -1, 1, 2 do
        local p = cen + tx * (sd * (hw - 0.2)) + w * 0.14
        beam(S, STEEL, v3(p.x, K.ground(p.x, p.z) - 0.4, p.z), p + UP * (px * 4), 0.06, 0.06)
      end
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
    for _, di in ipairs({0, 2, -2, 4, -4}) do
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

  -- ---------------------------------------------------------------- junk, each in a frame F
  local function sofa(root, F, half)
    local c = K.pick(SOFAS)
    local hb = half or 0.95
    F.box(root, c[1], 0, 0.25, 0, 0.45, 0.25, hb)
    F.box(root, c[1], -0.4, 0.62, 0, 0.13, 0.5, hb + 0.01)
    for sd = -1, 1, 2 do
      F.box(root, c[1], 0.03, 0.4, sd * (hb + 0.1), 0.5, 0.4, 0.14)
      if not half then F.box(root, c[2], 0.1, 0.56, sd * 0.45, 0.36, 0.08, 0.42) end
    end
    if half then F.box(root, c[2], 0.1, 0.56, 0, 0.36, 0.08, hb - 0.04) end
  end
  local function armchair(root, F) sofa(root, F, 0.4) end
  local function fridge(root, F)
    local c = K.pick({WHITE, WHITE, CREAM, MINT})
    F.box(root, c, 0, 0.9, 0, 0.33, 0.9, 0.36)
    F.box(root, DKGREY, 0.335, 1.22, 0, 0.012, 0.025, 0.34)
    F.box(root, STEEL, 0.36, 1.45, 0.26, 0.025, 0.14, 0.025)
    F.box(root, STEEL, 0.36, 0.95, 0.26, 0.025, 0.18, 0.025)
  end
  local function washer(root, F)
    F.box(root, WHITE, 0, 0.45, 0, 0.32, 0.45, 0.33)
    limb(root, STEEL, F.P(0.3, 0.4, 0), F.P(0.35, 0.4, 0), 0.26 * F.sc, 0.26 * F.sc, 8)
    limb(root, GLASS, F.P(0.31, 0.4, 0), F.P(0.38, 0.4, 0), 0.19 * F.sc, 0.17 * F.sc, 8)
    F.box(root, DKGREY, 0.325, 0.8, 0, 0.012, 0.055, 0.3)
  end
  local function tv(root, F)
    local c = K.pick({WOODS[1], DKGREY, WOODS[2]})
    F.box(root, c, 0, 0.36, 0, 0.26, 0.34, 0.44)
    F.box(root, c, -0.36, 0.33, 0, 0.16, 0.22, 0.3)
    F.box(root, SCREEN, 0.265, 0.38, -0.07, 0.012, 0.25, 0.3)
    F.box(root, STEEL, 0.265, 0.38, 0.33, 0.012, 0.25, 0.05)
    F.bar(root, STEEL, 0, 0.7, 0, -0.1, 1.2, 0.3, 0.015)
    F.bar(root, STEEL, 0, 0.7, 0, -0.1, 1.2, -0.3, 0.015)
  end
  local function mattress(root, F)
    F.box(root, MATT, 0, 0.13, 0, 1.0, 0.12, 0.7)
    for k = -2, 2 do F.box(root, MSTRIPE, k * 0.36, 0.13, 0, 0.06, 0.126, 0.706) end
  end
  local function tyre(root, F, a, h, b, r)
    r = r or 0.38
    limb(root, BLACK, F.P(a, h, b), F.P(a, h + r * 0.63, b), r * F.sc, r * F.sc, 8)
    limb(root, HUB, F.P(a, h - 0.012, b), F.P(a, h + r * 0.63 + 0.012, b), r * 0.5 * F.sc, r * 0.5 * F.sc, 6)
  end
  local function tyres(root, F)
    local n = math.floor(rnd(2, 6.9))
    for k = 0, n - 1 do tyre(root, F, rnd(-0.06, 0.06), k * 0.27, rnd(-0.06, 0.06)) end
  end
  local function bike(root, F)
    local c = K.pick(BRIGHT)
    F.disc(root, BLACK, -0.52, 0.36, 0, 0.36, 0.025)
    F.disc(root, BLACK, 0.52, 0.36, 0, 0.36, 0.025)
    local t = 0.028
    F.bar(root, c, -0.52, 0.36, 0, -0.05, 0.32, 0, t)
    F.bar(root, c, -0.05, 0.32, 0, -0.2, 0.88, 0, t)
    F.bar(root, c, -0.2, 0.85, 0, -0.52, 0.36, 0, t)
    F.bar(root, c, -0.2, 0.84, 0, 0.4, 0.86, 0, t)
    F.bar(root, c, -0.05, 0.32, 0, 0.4, 0.8, 0, t)
    F.bar(root, STEEL, 0.38, 1.02, 0, 0.52, 0.36, 0, t)
    F.bar(root, DKGREY, 0.38, 1.02, -0.28, 0.38, 1.02, 0.28, t)
    F.box(root, DKGREY, -0.22, 0.92, 0, 0.13, 0.03, 0.06)
  end
  local function pram(root, F)
    local c = K.pick({BLUE, PURPLE, TEAL, RED})
    F.box(root, c, 0, 0.72, 0, 0.42, 0.2, 0.26)
    F.box(root, DKGREY, -0.2, 1.04, 0, 0.22, 0.14, 0.27)
    for _, a in ipairs({-0.32, 0.32}) do
      for sd = -1, 1, 2 do
        F.disc(root, BLACK, a, 0.17, sd * 0.3, 0.17, 0.03, 6)
        F.bar(root, STEEL, a, 0.17, sd * 0.25, a * 0.6, 0.55, sd * 0.22, 0.02)
      end
    end
    for sd = -1, 1, 2 do F.bar(root, STEEL, -0.4, 0.85, sd * 0.2, -0.75, 1.15, sd * 0.2, 0.02) end
    F.bar(root, STEEL, -0.75, 1.15, -0.22, -0.75, 1.15, 0.22, 0.02)
  end
  -- A rejected soap-box kart: a plank, a bright box body and nose, a seat back, a wheel or two gone.
  local function kart(root, F)
    local c, c2 = K.pick(BRIGHT), K.pick(BRIGHT)
    F.box(root, WOODS[3], 0, 0.3, 0, 0.95, 0.05, 0.3)
    F.box(root, c, -0.12, 0.53, 0, 0.55, 0.18, 0.33)
    F.box(root, c2, 0.62, 0.45, 0, 0.26, 0.1, 0.26)
    F.box(root, c2, -0.62, 0.8, 0, 0.06, 0.32, 0.31)
    local gone = math.floor(rnd(1, 4.99))
    local k = 0
    for _, a in ipairs({-0.66, 0.66}) do
      for sd = -1, 1, 2 do
        k = k + 1
        if k ~= gone then
          F.disc(root, BLACK, a, 0.26, sd * 0.46, 0.27, 0.07)
          F.disc(root, HUB, a, 0.26, sd * 0.46, 0.12, 0.08, 6)
        end
      end
    end
    F.bar(root, STEEL, -0.66, 0.26, -0.44, -0.66, 0.26, 0.44, 0.025)
    F.bar(root, STEEL, 0.3, 0.68, 0, 0.1, 0.98, 0, 0.025)
    limb(root, DKGREY, F.P(0.1, 0.98, 0), F.P(0.07, 1.02, 0), 0.17 * F.sc, 0.17 * F.sc, 6)
    for sd = -1, 1, 2 do
      limb(root, WHITE, F.P(-0.12, 0.54, sd * 0.33), F.P(-0.12, 0.54, sd * 0.35), 0.15 * F.sc, 0.15 * F.sc, 6)
    end
  end
  local function lump() return rnd(0.82, 1.14) end
  local function bag(root, p, r)
    K.ball(piece(root, "bags"), p, r, r * 0.78, r, 6, 4, lump, function(w) return (w.y > r * 0.3) and BAG_HI or BAG end)
  end
  local function bags(root, F)
    for k = 1, 3 do bag(root, F.P(rnd(-0.5, 0.5), 0.3 + (k == 3 and 0.4 or 0), rnd(-0.5, 0.5)), rnd(0.42, 0.6) * F.sc) end
  end
  local JUNK = {sofa, sofa, armchair, fridge, fridge, washer, tv, mattress, tyres, tyres, bike, pram, kart, kart, bags}

  local function trafficcone(x, z)
    local F
    if rnd(0, 1) < 0.25 then
      local a = rnd(0, 6.28)
      F = frame(v3(x, K.ground(x, z) + 0.3, z), UP, v3(math.cos(a), 0.12, math.sin(a)), 1.35)
    else
      F = gframe(x, z, rnd(0, 6.28), 1.35)
    end
    F.box(S, ORANGE, 0, 0.03, 0, 0.24, 0.035, 0.24)
    tube(S, function(j, _) return (j == 2) and WHITE or ORANGE end,
      {F.P(0, 0.06, 0), F.P(0, 0.3, 0), F.P(0, 0.5, 0), F.P(0, 0.78, 0)}, {0.18 * F.sc, 0.13 * F.sc, 0.09 * F.sc, 0.035 * F.sc}, 6,
      nil, 1, "cones")
  end

  -- ---------------------------------------------------------------- gulls
  local function gull(p, dir, sc, bank)
    local F = frame(p, dir, normalize(UP + v3(-dir.z, 0, dir.x) * bank), sc)
    egg(D, WHITE, F.P(0, 0, 0), F.f * (0.42 * sc), 0.16 * sc, 0.15 * sc, 5)
    sph(D, WHITE, F.P(0.42, 0.08, 0), 0.11 * sc, 4)
    limb(D, BEAK, F.P(0.5, 0.07, 0), F.P(0.7, 0.03, 0), 0.045 * sc, 0.012 * sc, 4)
    local flap = rnd(-0.12, 0.4)
    for sd = -1, 1, 2 do
      beam(D, WHITE, F.P(0.05, 0.03, sd * 0.1), F.P(0.08, 0.03 + flap * 0.5, sd * 0.64), 0.18 * sc, 0.022 * sc, F.up)
      beam(D, GULLGREY, F.P(0.08, 0.03 + flap * 0.5, sd * 0.6), F.P(-0.08, 0.03 + flap * 0.25, sd * 1.25), 0.12 * sc, 0.018 * sc, F.up)
    end
    beam(D, GULLGREY, F.P(-0.34, 0.01, 0), F.P(-0.64, 0, 0), 0.1 * sc, 0.016 * sc, F.up)
    count("gulls")
  end
  local function perched(p, dir, sc)
    local F = frame(p, dir, UP, sc)
    for sd = -1, 1, 2 do F.bar(D, BEAK, 0, 0, sd * 0.06, 0, 0.24, sd * 0.06, 0.015) end
    egg(D, WHITE, F.P(0, 0.36, 0), (F.f * 0.36 + UP * 0.08) * sc, 0.16 * sc, 0.16 * sc, 6)
    beam(D, GULLGREY, F.P(0.05, 0.47, 0), F.P(-0.48, 0.36, 0), 0.13 * sc, 0.03 * sc, F.up)
    sph(D, WHITE, F.P(0.3, 0.6, 0), 0.11 * sc, 5)
    limb(D, BEAK, F.P(0.38, 0.6, 0), F.P(0.56, 0.56, 0), 0.045 * sc, 0.012 * sc, 4)
    count("gulls")
  end
  -- Gulls circling over (x, z): never lower than 9 m over the ground (or the road) below each.
  local function flock(x, z, n, r0, r1)
    local a0 = rnd(0, 6.28)
    for k = 1, n do
      local a = a0 + k / n * 6.283 + rnd(-0.3, 0.3)
      local r = rnd(r0, r1)
      local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
      local y = math.max(K.ground(px, pz), K.ground(x, z)) + rnd(9.5, 17)
      gull(v3(px, y, pz), v3(-math.sin(a), 0, math.cos(a)), rnd(1.5, 2.1), -0.35)
    end
  end

  -- ---------------------------------------------------------------- heaps
  -- A mound of muck with junk stuck in it at all angles.
  local function heap(x, z, R, hgt, n, isc, root)
    local y = K.ground(x, z) - 0.25
    K.ball(piece(root, "mound"), v3(x, y, z), R, hgt, R, 9, 4, lump, function(w) return (w.y > hgt * 0.5) and MUD_HI or MUD end)
    for _ = 1, n do
      local a, r = rnd(0, 6.283), rnd(0.1, 0.85)
      local px, pz = x + math.cos(a) * r * R, z + math.sin(a) * r * R
      if clear(px, pz, 1.3 * isc) then
        local h = math.max(y + hgt * math.sqrt(1 - r * r) * 0.9, K.ground(px, pz) - 0.1)
        local up = normalize(UP + v3(math.cos(a), 0, math.sin(a)) * (r * rnd(0.3, 1.1)) + v3(rnd(-0.3, 0.3), 0, rnd(-0.3, 0.3)))
        local fa = rnd(0, 6.283)
        K.pick(JUNK)(root, frame(v3(px, h, pz), v3(math.cos(fa), 0, math.sin(fa)), up, isc))
      end
    end
  end
  local function bagmound(x, z, R, hgt, n, root)
    local y = K.ground(x, z) - 0.3
    K.ball(piece(root, "bags"), v3(x, y, z), R * 0.92, hgt * 0.92, R * 0.92, 8, 4, lump, function() return BAG end)
    for k = 1, n do
      local a, r = rnd(0, 6.283), math.sqrt(rnd(0.0, 1.0))
      local px, pz = x + math.cos(a) * r * R, z + math.sin(a) * r * R
      if clear(px, pz, 0.9) then
        local h = math.max(y + hgt * math.sqrt(1 - r * r), K.ground(px, pz) + 0.1)
        bag(D, v3(px, h, pz), rnd(0.55, 0.85))
        if k % 16 == 0 then
          local fa = rnd(0, 6.283)
          perched(v3(px, h + 0.5, pz), v3(math.cos(fa), 0, math.sin(fa)), 1.5)
        end
      end
    end
    flock(x, z, 4, R * 0.6, R * 1.6)
  end
  local function tyreheap(x, z, R, n, root)
    for k = 1, n do
      local a, r = rnd(0, 6.283), math.sqrt(rnd(0, 1)) * R
      local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
      if clear(px, pz, 1.0) then
        local h = K.ground(px, pz) + (1 - r / R) * 1.6 + rnd(-0.1, 0.2)
        local up = normalize(UP + v3(rnd(-0.7, 0.7), 0, rnd(-0.7, 0.7)))
        local F = frame(v3(px, h, pz), v3(1, 0, 0), up, rnd(1.2, 1.5))
        tyre(root, F, 0, 0, 0)
      end
    end
    -- A tractor tyre stood on the heap.
    local a = rnd(0, 3.14)
    local F = frame(v3(x, K.ground(x, z) + 2.4, z), UP, v3(math.cos(a), 0, math.sin(a)), 1)
    tyre(root, F, 0, -0.35, 0, 1.1)
  end

  -- ---------------------------------------------------------------- skips
  local function skipbox(root, F, c)
    local function ring(b) return {F.P(-1.25, 0, b), F.P(1.25, 0, b), F.P(1.9, 1.5, b), F.P(-1.9, 1.5, b)} end
    K.prism(piece(root, c[1]), {ring(-0.9), ring(0.9)}, K.flat(c[1]), c[1], c[1])
    for sd = -1, 1, 2 do
      F.box(root, c[2], 0, 1.5, sd * 0.9, 1.96, 0.06, 0.06)
      F.box(root, c[2], sd * 1.9, 1.49, 0, 0.06, 0.05, 0.86)
      for _, a in ipairs({-0.8, 0, 0.8}) do F.box(root, c[2], a, 0.74, sd * 0.92, 0.06, 0.68, 0.035) end
    end
  end
  local KINDS = {
    wood = {"WOOD", SIGN_BR, SKIP_Y, function(F)
      F.box(D, WOODS[2], 0, 1.4, 0, 1.7, 0.1, 0.8)
      for _ = 1, 8 do
        local a, b = rnd(-1.4, 1.4), rnd(-0.6, 0.6)
        beam(D, K.pick(WOODS), F.P(a, 1.3, b), F.P(a + rnd(-0.9, 0.9), rnd(2.0, 2.9), b + rnd(-0.5, 0.5)), 0.13 * F.sc, 0.04 * F.sc)
      end
      F.box(D, WOODS[3], 0.4, 1.62, 0.1, 0.9, 0.05, 0.5)
    end},
    metal = {"METAL", SIGN_GY, SKIP_B, function(F)
      F.box(D, STEEL, 0, 1.4, 0, 1.7, 0.1, 0.8)
      bike(D, frame(F.P(-0.8, 1.55, 0), F.f + F.up * 0.3, F.up + F.s * 0.5, F.sc * 1.2))
      bike(D, frame(F.P(0.9, 1.5, 0.2), F.s + F.up * 0.2, F.up - F.f * 0.8, F.sc * 1.2))
      for _ = 1, 4 do
        local a, b = rnd(-1.4, 1.4), rnd(-0.6, 0.6)
        beam(D, K.pick({STEEL, RUST, HUB}), F.P(a, 1.3, b), F.P(a + rnd(-0.8, 0.8), rnd(2.0, 2.8), b + rnd(-0.4, 0.4)), 0.05 * F.sc, 0.05 * F.sc)
      end
      F.box(D, RUST, 0.1, 1.6, -0.3, 0.45, 0.2, 0.3)
    end},
    garden = {"GARDEN", SIGN_G, SKIP_G, function(F)
      for k = -2, 2 do
        local p = F.P(k * 0.7 + rnd(-0.1, 0.1), 1.45 + rnd(0, 0.25), rnd(-0.25, 0.25))
        K.ball(piece(D, "leaf"), p, 0.75 * F.sc, 0.6 * F.sc, 0.7 * F.sc, 7, 4, lump, LEAFS)
      end
      for _ = 1, 4 do
        local a = rnd(-1.3, 1.3)
        beam(D, WOODS[2], F.P(a, 1.4, 0), F.P(a + rnd(-0.7, 0.7), rnd(2.3, 2.9), rnd(-0.6, 0.6)), 0.04 * F.sc, 0.04 * F.sc)
      end
    end},
    electrical = {"ELECTRICAL", SIGN_BL, SKIP_R, function(F)
      F.box(D, DKGREY, 0, 1.4, 0, 1.7, 0.1, 0.8)
      tv(D, frame(F.P(-1.1, 1.5, 0.1), F.s, F.up + F.f * 0.2, F.sc * 1.2))
      tv(D, frame(F.P(0.1, 1.5, -0.2), F.s * -1 + F.f * 0.4, F.up - F.s * 0.25, F.sc * 1.2))
      washer(D, frame(F.P(1.1, 1.45, 0), F.s * -1, F.up + F.f * 0.3, F.sc))
      fridge(D, frame(F.P(-0.4, 1.75, 0.35), F.up, F.f + F.up * 0.25, F.sc * 0.9))
    end},
    rubble = {"RUBBLE", SIGN_GY, SKIP_O, function(F)
      for k = -2, 2 do
        local p = F.P(k * 0.7 + rnd(-0.1, 0.1), 1.4 + rnd(0, 0.15), rnd(-0.2, 0.2))
        K.ball(piece(D, "rubble"), p, 0.7 * F.sc, 0.4 * F.sc, 0.7 * F.sc, 6, 4, lump, function(w) return (w.y > 0.25) and RUBBLE or RUBBLE2 end)
      end
    end},
    rejects = {"REJECTS", SIGN_R, SKIP_Y, function(F)
      F.box(D, DKGREY, 0, 1.4, 0, 1.7, 0.1, 0.8)
      kart(D, frame(F.P(-0.9, 1.5, 0), F.f + F.up * 0.5, F.up - F.f * 0.4 + F.s * 0.2, F.sc * 0.95))
      kart(D, frame(F.P(0.8, 1.7, 0.1), F.f * -1 + F.s * 0.3, F.up * -1 + F.f * 0.3, F.sc * 0.95))
      kart(D, frame(F.P(0, 2.3, -0.1), F.s + F.f * 0.4, F.up + F.s * 0.5, F.sc * 0.95))
    end},
  }
  local function skip_at(x, z, u, w, kind, sign)
    local kd = KINDS[kind]
    local F = frame(v3(x, K.ground(x, z) - 0.25, z), u, gnormal(x, z, 2.5), 1.5)
    skipbox(S, F, kd[3])
    kd[4](F)
    if sign then
      local px = (#kd[1] > 7) and 0.105 or 0.15
      local c = v3(x, 0, z) + w * 1.75
      signboard(v3(c.x, K.ground(x, z) + 4.6, c.z), w, kd[1], kd[2], px, true)
    end
    if rnd(0, 1) < 0.5 then
      local e = (rnd(0, 1) < 0.5) and -1 or 1
      perched(F.P(e * 1.85, 1.56, rnd(-0.6, 0.6)), u * e, 1.5)
    end
    count("skips")
  end
  local function skip(kind)
    return function(i, side)
      local s = site(i, side, 3.3, 2.0, 0.8)
      if s then skip_at(s.c.x, s.c.z, s.u, s.w, kind, true) end
    end
  end

  -- ---------------------------------------------------------------- the plant
  -- A grab crane on tracks: its boom out over the road (the grab and its catch well over 6 m up) or along it.
  local function crane_at(o, u, toward, reach, top_y, road)
    local B = frame(o, u, UP, 1)
    for sd = -1, 1, 2 do B.box(S, BLACK, 0, 0.5, sd * 1.5, 2.6, 0.5, 0.45) end
    B.box(S, DKGREY, 0, 0.95, 0, 1.3, 0.35, 1.05)
    local H = frame(o, toward, UP, 1)
    H.box(S, YEL, -0.4, 2.1, 0, 2.0, 0.8, 1.4)
    H.box(S, DKGREY, -2.6, 1.9, 0, 0.5, 0.7, 1.35)
    H.box(S, GLASS, 1.0, 3.5, 0.82, 0.7, 0.6, 0.5)
    H.box(S, YEL, 1.0, 4.16, 0.82, 0.78, 0.07, 0.58)
    for _, a in ipairs({-0.9, 0.9}) do H.box(S, BLACK, a * 0.5 - 0.6, 2.0, 1.41, 0.3, 0.08, 0.012) end
    local th = top_y - o.y
    local foot, elbow, tip = H.P(0.5, 2.9, -0.3), H.P(reach * 0.42, th + 1.2, -0.3), H.P(reach, th, -0.3)
    beam(D, YEL, foot, elbow, 0.3, 0.3)
    beam(D, YEL, elbow, tip, 0.22, 0.22)
    sph(D, DKGREY, elbow, 0.45, 6)
    beam(D, STEEL, H.P(1.5, 2.9, -0.3), lerp(foot, elbow, 0.45), 0.1, 0.1)
    beam(D, STEEL, lerp(foot, elbow, 0.7), lerp(elbow, tip, 0.35), 0.08, 0.08)
    beam(D, BLACK, tip, tip - UP * 1.7, 0.04, 0.04)
    local hub = tip - UP * 1.9
    sph(D, DKGREY, hub, 0.38, 6)
    for k = 0, 3 do
      local a = k * 1.5708 + 0.6
      local d = v3(math.cos(a), 0, math.sin(a))
      beam(D, DKGREY, hub + d * 0.2, hub + d * 1.35 - UP * 0.7, 0.13, 0.08)
      beam(D, DKGREY, hub + d * 1.35 - UP * 0.62, hub + d * 0.85 - UP * 1.95, 0.11, 0.07)
    end
    local fa = rnd(0, 6.283)
    local F = frame(hub - UP * 2.75, v3(math.cos(fa), 0, math.sin(fa)), UP + v3(rnd(-0.3, 0.3), 0, rnd(-0.3, 0.3)), 1.3)
    if road then kart(D, F) else K.pick({sofa, fridge, kart, washer})(D, F) end
    count("cranes")
  end
  local function crane(over)
    return function(i, side)
      local s = site(i, side, 3.2, 3.0, 1.2)
      if not s then return end
      local j = s.i
      local o = v3(s.c.x, K.lowest(s.c, s.u, s.w, 2.6, 2.0) - 0.15, s.c.z)
      if over then
        local to = v3(pos[j].x - o.x, 0, pos[j].z - o.z)
        crane_at(o, s.u, to, length(to), math.max(o.y, pos[j].y, pos[math.max(1, j - 3)].y) + 13, true)
      else
        crane_at(o, s.u, s.u * ((rnd(0, 1) < 0.5) and -1 or 1) + s.w * 0.35, 5.5, s.c.y + 10, false)
      end
    end
  end

  local function dozer_at(x, z, f)
    local F = frame(v3(x, K.ground(x, z) - 0.1, z), f, gnormal(x, z, 2), 1.3)
    for sd = -1, 1, 2 do
      F.box(S, BLACK, 0, 0.45, sd * 1.0, 1.7, 0.45, 0.3)
      for _, a in ipairs({-1.2, 0, 1.2}) do F.disc(D, HUB, a, 0.45, sd * 1.3, 0.28, 0.02, 6) end
      F.bar(S, YEL, 0, 0.75, sd * 1.4, 2.25, 0.6, sd * 1.4, 0.09)
    end
    F.box(S, YEL, -0.1, 1.15, 0, 1.5, 0.45, 0.68)
    F.box(S, YEL, 0.75, 1.8, 0, 0.8, 0.3, 0.55)
    F.box(S, GLASS, -0.7, 2.2, 0, 0.6, 0.6, 0.62)
    F.box(S, YEL, -0.7, 2.86, 0, 0.72, 0.07, 0.74)
    for _, a in ipairs({-1.28, -0.12}) do
      for sd = -1, 1, 2 do F.box(S, YEL, a, 2.2, sd * 0.62, 0.05, 0.62, 0.05) end
    end
    limb(S, DKGREY, F.P(1.1, 2.1, 0.35), F.P(1.1, 3.0, 0.35), 0.09 * F.sc, 0.09 * F.sc, 6)
    F.box(S, STEEL, 2.4, 0.8, 0, 0.1, 0.8, 1.6)
    F.box(S, DKGREY, 2.52, 0.1, 0, 0.06, 0.1, 1.62)
    -- What it is pushing.
    for k = 1, 5 do
      local p = F.P(3.3 + rnd(-0.3, 0.8), 0.35, (k - 3) * 0.75)
      if clear(p.x, p.z, 0.8) then bag(D, p, rnd(0.6, 0.85)) end
    end
    local p = F.P(4.6, 0.2, 0.3)
    if clear(p.x, p.z, 1.6) then sofa(S, frame(p, F.s + F.f * 0.4, F.up + F.f * 0.5, 1.3)) end
    count("bulldozers")
  end
  local function dozer(i, side)
    local s = site(i, side, 5.0, 2.6, 0.9)
    if not s then return end
    local c = s.at(-1.4, 0)
    dozer_at(c.x, c.z, s.u)
  end

  local function office(i, side)
    local s = site(i, side, 5.2, 2.6, 1.0)
    if not s then return end
    local lo = K.lowest(s.c, s.u, s.w, 4.6, 2.0) - 0.4
    local hi = lo
    for _, m in ipairs({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do hi = math.max(hi, s.at(m[1] * 4.6, m[2] * 2.0).y) end
    local F = frame(v3(s.c.x, hi + 0.3, s.c.z), s.u, UP, 1)
    local sg = (dot(F.s, s.w) > 0) and -1 or 1          -- the side facing the road
    obox(S, DKGREY, v3(s.c.x, (lo + hi + 0.3) / 2, s.c.z), s.u * 4.2, UP * ((hi + 0.3 - lo) / 2), s.w * 1.6)
    F.box(S, CABIN, 0, 1.4, 0, 4.5, 1.37, 1.8)
    F.box(D, CABIN2, 0, 2.86, 0, 4.65, 0.08, 1.95)
    F.box(D, SIGN_BL, 0, 2.45, sg * 1.81, 4.45, 0.12, 0.012)
    for _, a in ipairs({-2.5, 2.5}) do
      F.box(D, WHITE, a, 1.55, sg * 1.8, 1.0, 0.6, 0.02)
      F.box(D, GLASS, a, 1.55, sg * 1.8, 0.9, 0.5, 0.04)
    end
    F.box(D, BLUE, 0, 1.1, sg * 1.8, 0.5, 1.05, 0.04)
    F.box(S, STEEL, 0, -0.05, sg * 2.2, 0.7, 0.1, 0.4)
    F.box(S, STEEL, 0, -0.3, sg * 2.75, 0.7, 0.1, 0.3)
    local c = F.P(0, 3.75, sg * 1.5)
    signboard(c, s.w, "TIP OFFICE", SIGN_G, 0.15, false)
    for _, a in ipairs({-2.5, 2.5}) do F.box(D, STEEL, a, 3.1, sg * 1.5 - sg * 0.12, 0.05, 0.3, 0.05) end
    -- A skip of tea-break chairs beside it, and a gull on the roof.
    perched(F.P(3.5, 2.95, 0.5), s.u, 1.5)
    perched(F.P(-3.2, 2.95, -0.8), s.w * -1, 1.5)
    count("offices")
  end

  -- The weighbridge: a steel deck beside the road, a skip lorry stood on it, a barrier arm up at its end.
  local function weighbridge(i, side)
    local s = site(i, side, 6.6, 2.3, 0.7)
    if not s then return end
    local F = frame(s.c - UP * 0.05, s.u, gnormal(s.c.x, s.c.z, 4), 1)
    F.box(S, STEEL, 0, 0.12, 0, 6.2, 0.14, 1.75)
    for sd = -1, 1, 2 do
      F.box(S, YEL, 0, 0.36, sd * 1.82, 6.2, 0.11, 0.07)
      for k = -2, 2 do F.box(D, DKGREY, k * 2.4, 0.27, sd * 0.7, 1.0, 0.012, 0.25) end
    end
    -- The lorry.
    local L = frame(F.P(-0.6, 0.27, 0), F.f, F.up, 1)
    L.box(S, DKGREY, 0, 0.75, 0, 3.6, 0.13, 0.85)
    for _, a in ipairs({2.6, -1.3, -2.5}) do
      for sd = -1, 1, 2 do
        L.disc(S, BLACK, a, 0.5, sd * 0.95, 0.5, 0.16)
        L.disc(D, HUB, a, 0.5, sd * 0.95, 0.22, 0.17, 6)
      end
    end
    L.box(S, WHITE, 2.9, 1.85, 0, 0.8, 0.95, 1.12)
    L.box(D, GLASS, 3.71, 2.15, 0, 0.012, 0.4, 0.98)
    L.box(D, ORANGE, 2.9, 1.25, 0, 0.82, 0.12, 1.14)
    for sd = -1, 1, 2 do
      L.box(D, GLASS, 3.1, 2.15, sd * 1.125, 0.4, 0.38, 0.012)
      L.bar(S, YEL, 1.6, 0.9, sd * 1.0, 0.2, 3.3, sd * 1.0, 0.09)
      L.bar(D, BLACK, 0.2, 3.3, sd * 0.95, -0.9, 2.3, sd * 0.9, 0.03)
    end
    local kind = K.pick({"metal", "rubble", "wood"})
    local Sk = frame(L.P(-0.9, 0.9, 0), L.f, L.up, 1.0)
    skipbox(S, Sk, KINDS[kind][3])
    KINDS[kind][4](Sk)
    -- The barrier, up; and the sign behind.
    local b0 = F.P(6.0, 0, 2.05)
    beam(S, STEEL, b0 - UP * 0.4, b0 + UP * 1.1, 0.12, 0.12)
    local d = normalize(F.s * -1 + UP * 1.3)
    for k = 0, 5 do
      beam(D, (k % 2 == 0) and RED or WHITE, b0 + UP * 1.0 + d * (k * 0.62 + 0.01), b0 + UP * 1.0 + d * (k * 0.62 + 0.6), 0.06, 0.06, F.f)
    end
    local c = s.c + s.w * 2.15 - s.u * 1.5
    signboard(v3(c.x, s.c.y + 5.3, c.z), s.w, "WEIGHBRIDGE", SIGN_BL, 0.13, true)
    count("weighbridges")
  end

  -- The way in: a gantry over the road, its boards well clear of it.
  local function gantry(i)
    local d = K.along(i)
    d = normalize(v3(d.x, 0, d.z))
    local r = right[i]
    local half = W[i] + EDGE + 1.0
    local top = pos[i].y + 6.8
    for sd = -1, 1, 2 do
      local p = pos[i] + r * (sd * half)
      beam(S, STEEL, v3(p.x, K.ground(p.x, p.z) - 0.5, p.z), v3(p.x, top + 3.3, p.z), 0.16, 0.16)
      take(p.x, p.z, 1.2)
    end
    local c = v3(pos[i].x, top + 1.25, pos[i].z)
    signboard(c + d * 0.2, d, "COUNCIL TIP", SIGN_G, 0.18, false)
    signboard(c + UP * 1.55 + d * 0.2, d, "NO RACING", SIGN_R, 0.11, false)
    beam(D, STEEL, c - r * half + UP * 0.9 + d * 0.38, c + r * half + UP * 0.9 + d * 0.38, 0.08, 0.08)
    beam(D, STEEL, c - r * half - UP * 0.6 + d * 0.38, c + r * half - UP * 0.6 + d * 0.38, 0.08, 0.08)
    perched(c + UP * 2.1 + r * 2.5 + d * 0.2, d * -1, 1.6)
    perched(c + UP * 2.1 - r * 3.1 + d * 0.2, d * -1 + r * 0.5, 1.6)
  end

  local function junkheap(i, side)
    local s = site(i, side, 3.6, 3.6, 1.0)
    if not s then return end
    heap(s.c.x, s.c.z, 3.4, 1.7, 9, 1.3, S)
    count("junk heaps")
  end
  local function bagsite(i, side)
    local s = site(i, side, 4.6, 4.6, 0.9)
    if not s then return end
    bagmound(s.c.x, s.c.z, 4.3, 2.6, 34, S)
    count("bin-bag mounds")
  end
  local function tyresite(i, side)
    local s = site(i, side, 3.2, 3.2, 0.9)
    if not s then return end
    tyreheap(s.c.x, s.c.z, 2.9, 22, S)
    count("tyre heaps")
  end

  -- ---------------------------------------------------------------- the tip, laid out down the road
  gantry(math.min(N - 4, K.start + 7))
  office(K.start + 13, -1)
  weighbridge(K.start + 16, 1)
  local seq = {skip("wood"), junkheap, skip("metal"), crane(true), skip("garden"), bagsite, skip("electrical"), dozer,
    junkheap, skip("rejects"), tyresite, crane(false), skip("rubble"), junkheap, weighbridge, bagsite}
  local k = 0
  for i = K.start + 26, N - 6, 9 do
    k = k + 1
    local sd = (k % 2 == 0) and 1 or -1
    seq[(k - 1) % #seq + 1](i, sd)
    seq[(k * 5 + 6) % #seq + 1](i + 4, -sd)
  end
  -- Before the start line too.
  skip("rejects")(5, 1)
  junkheap(5, -1)

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
  local loose = scatter(64, 1.4, 12, 1.7, function(x, z)
    local fn = K.pick(JUNK)
    local tip = (fn ~= tyres and rnd(0, 1) < 0.3) and rnd(0.3, 0.9) or 0
    local a = rnd(0, 6.283)
    local F = gframe(x, z, a, 1.3)
    if tip > 0 then
      F = frame(F.o + UP * 0.35, F.f, F.up + F.s * tip + F.f * rnd(-0.3, 0.3), 1.3)
    end
    fn(S, F)
  end)
  local cones = scatter(80, 0.5, 3.0, 0.45, trafficcone)

  -- Out on the slopes: the landfill itself.
  local function far(n, clearance, R, fn)
    for _ = 1, n * 4 do
      local x, z = K.spot(clearance)
      if x and free(x, z, R) then
        take(x, z, R)
        fn(x, z, rnd(0, 6.283))
        n = n - 1
        if n <= 0 then break end
      end
    end
  end
  far(6, 16, 8, function(x, z) heap(x, z, rnd(5, 7.5), rnd(2.4, 3.6), 9, 1.9, D); count("junk heaps") end)
  far(4, 16, 8, function(x, z) bagmound(x, z, rnd(5, 7), rnd(3, 4), 30, D); count("bin-bag mounds") end)
  far(3, 14, 5, function(x, z) tyreheap(x, z, 3.5, 22, D); count("tyre heaps") end)
  local kinds = {"wood", "metal", "garden", "electrical", "rubble", "rejects"}
  far(6, 14, 5, function(x, z, a)
    local u = v3(math.cos(a), 0, math.sin(a))
    skip_at(x, z, u, v3(-u.z, 0, u.x), K.pick(kinds), rnd(0, 1) < 0.5)
  end)
  far(3, 20, 7, function(x, z, a)
    local u = v3(math.cos(a), 0, math.sin(a))
    crane_at(v3(x, K.ground(x, z) - 0.6, z), u, v3(-u.z, 0, u.x), 6, K.ground(x, z) + 10, false)
  end)
  far(3, 16, 6, function(x, z, a) dozer_at(x, z, v3(math.cos(a), 0, math.sin(a))) end)
  far(4, 12, 4, function(x, z) flock(x, z, 4, 4, 10) end)

  local list = {}
  for name, n in pairs(made) do list[#list + 1] = n .. " " .. name end
  table.sort(list)
  info("tip: " .. table.concat(list, ", ") .. string.format(", %d loose junk, %d cones", loose, cones))
end

return T
