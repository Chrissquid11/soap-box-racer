-- The Haunted Hospital's scenery kit (see THEME KITS in _course.lua): a derelict Victorian hospital at night. The
-- ground is dark green-grey lino tiles out to the wards' edge, rough dark grass beyond (T.paint). Corridor walls of
-- peeling paint over a green dado line the road, set back, with doorframes whose swing doors hang open, blade signs
-- (WARD n, X-RAY) by them and strip-light panels on arms -- lit, half lit or dead and dangling; ceiling ribs cross
-- high over the road with more lights and big green signs. In the corridor and the wards behind: runaway beds,
-- wheelchairs, drip stands, trolleys and filing cabinets, sheet ghosts (some riding), cobwebs, bats overhead. Beside
-- the road's end a graveyard lies before the crumbling gothic hospital and its clock tower; more graves, dead trees
-- and giant ghosts out on the slopes.
-- Every piece is one colour's (K.sub by colour) but the ghosts' sheets, two.
local T = {trees = 0, rocks = 0}

local function h2(a, b)
  local s = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
  return s - math.floor(s)
end

local INK
function T.paint(x, z, off, ink, TK)
  if not INK then
    INK = {l1 = TK.col(0.12, 0.19, 0.16), l2 = TK.col(0.17, 0.25, 0.21), stain = TK.col(0.08, 0.11, 0.09),
      edge = TK.col(0.2, 0.2, 0.21), g1 = TK.col(0.06, 0.11, 0.08), g2 = TK.col(0.08, 0.13, 0.09), mud = TK.col(0.13, 0.11, 0.1)}
  end
  local cx, cz = math.floor(x / 5), math.floor(z / 5)
  local h = h2(cx, cz)
  if off < 17 then
    if h < 0.05 then return INK.stain end
    return ((cx + cz) % 2 == 0) and INK.l1 or INK.l2
  end
  if off < 22 then return INK.edge end
  if h < 0.15 then return INK.mud end
  return (h < 0.6) and INK.g1 or INK.g2
end

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local function rnd(a, b) return K.g:range(a, b) end
  local EDGE = K.WALL_T + 1          -- the road's own margin: nothing of the kit's nearer its edge
  local BANK = K.P.bank

  local WHITE, BLACK = col(0.93, 0.93, 0.9), col(0.03, 0.03, 0.03)
  local WALLC, WALLC2, DADO = col(0.7, 0.76, 0.6), col(0.62, 0.7, 0.56), col(0.08, 0.3, 0.24)
  local PLASTER, BRICK = col(0.5, 0.47, 0.4), col(0.55, 0.22, 0.14)
  local FRAMEW, DOOR1, DOOR2, PORT = col(0.28, 0.16, 0.09), col(0.15, 0.5, 0.6), col(0.8, 0.74, 0.5), col(0.95, 0.95, 0.55)
  local STEEL, STEEL2 = col(0.6, 0.63, 0.65), col(0.75, 0.78, 0.8)
  local LIT, DIM, DEAD, HOUSE = col(1.0, 1.0, 0.7), col(0.5, 0.56, 0.36), col(0.16, 0.18, 0.17), col(0.3, 0.33, 0.33)
  local RIBC, SIGNG, SIGNY = col(0.2, 0.28, 0.27), col(0.03, 0.34, 0.2), col(0.95, 0.78, 0.08)
  local SHEET, PILLOW, BEDF = col(0.9, 0.9, 0.86), col(0.82, 0.8, 0.7), col(0.85, 0.84, 0.75)
  local BLANKETS = {col(0.4, 0.68, 0.85), col(0.45, 0.85, 0.68), col(0.92, 0.55, 0.68), col(0.9, 0.82, 0.35)}
  local SEATS = {col(0.75, 0.1, 0.08), col(0.1, 0.3, 0.75), col(0.1, 0.5, 0.25)}
  local POTIONS = {col(0.4, 0.95, 0.25), col(0.7, 0.3, 0.95), col(1.0, 0.55, 0.1), col(0.2, 0.85, 0.9)}
  local CABS = {{col(0.4, 0.47, 0.36), col(0.52, 0.6, 0.46)}, {col(0.6, 0.52, 0.38), col(0.72, 0.64, 0.48)}}
  local GHOST, GHOST2 = col(0.97, 0.98, 1.0), col(0.72, 0.8, 0.92)
  local BAT, BAT2, EYE = col(0.28, 0.13, 0.4), col(0.5, 0.27, 0.66), col(1.0, 0.85, 0.1)
  local WEB = col(0.86, 0.88, 0.92)
  local GRAVES = {col(0.55, 0.57, 0.6), col(0.44, 0.47, 0.5), col(0.4, 0.5, 0.42)}
  local DEADW = col(0.36, 0.32, 0.3)
  local STONE, STONE2, ROOF = col(0.4, 0.38, 0.48), col(0.5, 0.48, 0.56), col(0.15, 0.17, 0.26)
  local WIN_Y, WIN_G, WIN_D = col(1.0, 0.82, 0.25), col(0.45, 1.0, 0.4), col(0.05, 0.05, 0.09)
  local CLOCK, BONE = col(0.96, 0.93, 0.74), col(0.9, 0.88, 0.75)

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
  -- A round tube through pts, radius rr[j] at each, n-sided.
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
  local T3 = {-0.9, 0, 0.9}
  local function egg(root, c, cen, axis, r1, r2, n, ts)
    local pts, rr = {}, {}
    for _, t in ipairs(ts or T5) do
      pts[#pts + 1] = cen + axis * t
      rr[#rr + 1] = r1 * math.sqrt(1 - t * t)
    end
    tube(root, c, pts, rr, n or 6, nil, r2 / r1)
  end
  local function rightof(v) return normalize(v3(-v.z, 0, v.x)) end

  -- Block letters, three by five: each row's runs a box. Centred on cen, reading along xd, px a block, proud by n.
  local FONT = {
    W = "101101101111101", A = "010101111101101", R = "110101110101101", D = "110101101101110", X = "101101010101101",
    Y = "101101010010010", ["-"] = "000000111000000", H = "101101111101101", O = "111101101101111", S = "111100111001111",
    P = "111101111100100", I = "111010010010111", T = "111010010010010", L = "100100100100111", E = "111100111100111",
    ["0"] = "111101101101111", ["1"] = "010110010010111", ["2"] = "111001111100111", ["3"] = "111001111001111",
    ["4"] = "101101111001001", ["5"] = "111100111001111", ["6"] = "111100111101111", ["7"] = "111001001001001",
    ["8"] = "111101111101111", ["9"] = "111101111001111", [" "] = "000000000000000",
  }
  local function text(root, c, str, cen, xd, px, n, th)
    local q = piece(root, c, c)
    local wide = (#str * 4 - 1) * px
    local o = cen - xd * (wide / 2) + UP * (2.5 * px)
    th = th or 0.04
    for ci = 1, #str do
      local gl = FONT[str:sub(ci, ci)]
      for r = 0, 4 do
        local k = 0
        while k < 3 do
          if gl:sub(r * 3 + k + 1, r * 3 + k + 1) == "1" then
            local k1 = k
            while k1 < 2 and gl:sub(r * 3 + k1 + 2, r * 3 + k1 + 2) == "1" do k1 = k1 + 1 end
            local x0, x1 = ((ci - 1) * 4 + k) * px, ((ci - 1) * 4 + k1 + 1) * px
            local m = o + xd * ((x0 + x1) / 2) - UP * ((r + 0.5) * px)
            local a, b, d = xd * ((x1 - x0) / 2), UP * (px * 0.52), n * th
            K.hexa(q, m - a - b - d, m + a - b - d, m + a - b + d, m - a - b + d, m - a + b - d, m + a + b - d, m + a + b + d, m - a + b + d)
            k = k1 + 1
          else
            k = k + 1
          end
        end
      end
    end
  end

  -- ---------------------------------------------------------------- where: a grid of what is taken
  local grid = {}
  local function free(x, z, R)
    local cx, cz = math.floor(x / 6), math.floor(z / 6)
    for dx = -1, 1 do
      for dz = -1, 1 do
        local cell = grid[(cx + dx) * 10007 + cz + dz]
        if cell then
          for _, t in ipairs(cell) do
            local ex, ez = t[1] - x, t[2] - z
            if ex * ex + ez * ez < (t[3] + R) * (t[3] + R) then return false end
          end
        end
      end
    end
    return true
  end
  local function take(x, z, R)
    local key = math.floor(x / 6) * 10007 + math.floor(z / 6)
    local cell = grid[key]
    if not cell then cell = {}; grid[key] = cell end
    cell[#cell + 1] = {x, z, R}
  end
  local made = {}
  local function count(what) made[what] = (made[what] or 0) + 1 end

  -- A thing's frame on the sloping ground by sample i: P(a, h, b) is a forward, h up off the floor, b to its side.
  local function stand(x, z, y, ang, i, sd, lean)
    local al, out = K.along(i), right[i] * sd
    local j = math.min(N - 1, i)
    local run = pos[j + 1] - pos[j]
    local s = run.y / math.max(0.2, length(v3(run.x, 0, run.z)))
    local function tilt(v) return normalize(v + UP * (dot(v, al) * s + dot(v, out) * BANK * 0.8)) end
    local f0 = v3(math.cos(ang), 0, math.sin(ang))
    local G = {o = v3(x, y, z), F = tilt(f0), S = tilt(v3(-f0.z, 0, f0.x))}
    G.N = normalize(cross(G.S, G.F))
    if G.N.y < 0 then G.N = G.N * -1 end
    if lean then G.N = normalize(G.N + G.F * rnd(-lean, lean) + G.S * rnd(-lean, lean)) end
    function G.P(a, h, b) return G.o + G.F * a + G.N * h + G.S * b end
    return G
  end
  -- The same thing fallen on its side, `up` its half width.
  local function tipped(G, up)
    local H = {o = G.o + G.N * up, F = G.F, N = G.S, S = G.N * -1}
    function H.P(a, h, b) return H.o + H.F * a + H.N * h + H.S * b end
    return H
  end
  local function boxer(G, sc)
    return function(root, c, a, h, b, ha, hh, hb)
      obox(root, c, G.P(a * sc, h * sc, b * sc), G.F * (ha * sc), G.N * (hh * sc), G.S * (hb * sc))
    end
  end

  -- ---------------------------------------------------------------- ghosts, bats, webs
  -- A sheet ghost: o under it, f the way it looks, sc its size (1.45 sc tall), `upv` its lean.
  local GR = {{0.22, 0.56}, {0.5, 0.44}, {0.78, 0.38}, {1.0, 0.4}, {1.2, 0.36}, {1.36, 0.22}, {1.43, 0.08}}
  local function ghost(o, f, sc, upv)
    f = normalize(v3(f.x, 0, f.z))
    local s = v3(-f.z, 0, f.x)
    upv = upv or normalize(UP + f * 0.12)
    local n = 10
    local rings = {}
    local hem = {}
    for k = 0, n - 1 do
      local a = k / n * math.pi * 2
      local r = (k % 2 == 0) and 0.8 or 0.62
      hem[#hem + 1] = o + upv * (((k % 2 == 0) and 0 or 0.13) * sc) + (f * math.cos(a) + s * math.sin(a)) * (r * sc)
    end
    rings[1] = hem
    for j, g in ipairs(GR) do
      local ring = {}
      for k = 0, n - 1 do
        local a = k / n * math.pi * 2
        ring[#ring + 1] = o + upv * (g[1] * sc) + (f * math.cos(a) + s * math.sin(a)) * (g[2] * sc)
      end
      rings[j + 1] = ring
    end
    K.prism(piece(K.deco, "ghost"), rings, function(j, _) return (j <= 2) and GHOST2 or GHOST end, GHOST2, GHOST)
    local function P(a, h, b) return o + f * (a * sc) + upv * (h * sc) + s * (b * sc) end
    for side = -1, 1, 2 do
      egg(K.deco, BLACK, P(0.36, 1.1, side * 0.15), UP * (0.13 * sc), 0.075 * sc, 0.075 * sc, 5, T3)
      limb(K.deco, GHOST, P(0, 0.85, side * 0.3), P(0.22, 1.2, side * 0.85), 0.17 * sc, 0.09 * sc, 5)
    end
    egg(K.deco, BLACK, P(0.4, 0.84, 0), UP * (0.1 * sc), 0.09 * sc, 0.09 * sc, 5, T3)
    count("ghosts")
  end

  local function bat(o, f, sc)
    local s = v3(-f.z, 0, f.x)
    egg(K.deco, BAT, o, f * (0.24 * sc), 0.13 * sc, 0.13 * sc, 5)
    local fl = rnd(-0.25, 0.45)
    for side = -1, 1, 2 do
      local p0 = o + s * (side * 0.08 * sc)
      local p1 = p0 + (s * (side * 0.6) + UP * fl) * sc
      local p2 = p1 + (s * (side * 0.55) - UP * (fl * 0.8 + 0.1)) * sc
      beam(K.deco, BAT2, p0, p1, 0.22 * sc, 0.015 * sc)
      beam(K.deco, BAT2, p1 - s * (side * 0.03 * sc), p2, 0.15 * sc, 0.015 * sc)
      obox(K.deco, EYE, o + f * (0.2 * sc) + UP * (0.06 * sc) + s * (side * 0.06 * sc), f * (0.03 * sc), UP * (0.03 * sc), s * (0.03 * sc))
    end
    count("bats")
  end

  -- A quarter cobweb in a corner: spokes fanning from C between e1 and e2, two rings of threads; n its plane's normal.
  local function web(C, e1, e2, size, n)
    local ds = {}
    for j = 0, 3 do
      local a = j / 3 * math.pi / 2
      ds[j + 1] = e1 * math.cos(a) + e2 * math.sin(a)
      beam(K.deco, WEB, C, C + ds[j + 1] * size, 0.022, 0.008, n)
    end
    for _, fr in ipairs({0.45, 0.82}) do
      for j = 1, 3 do
        beam(K.deco, WEB, C + ds[j] * (size * fr), C + ds[j + 1] * (size * fr * 0.97), 0.016, 0.008, n)
      end
    end
    count("cobwebs")
  end

  -- ---------------------------------------------------------------- the furniture
  local function bed(G, sc, haunted)
    local B = boxer(G, sc)
    B(K.solid, STEEL, 0, 0.5, 0, 1.1, 0.04, 0.5)
    B(K.solid, SHEET, 0, 0.66, 0, 1.05, 0.12, 0.48)
    B(K.deco, PILLOW, 0.75, 0.84, 0, 0.22, 0.07, 0.36)
    local bl = K.pick(BLANKETS)
    B(K.deco, bl, -0.35, 0.68, 0, 0.75, 0.125, 0.52)
    for side = -1, 1, 2 do
      B(K.solid, BEDF, 1.12, 0.76, side * 0.48, 0.035, 0.64, 0.035)
      B(K.solid, BEDF, -1.12, 0.585, side * 0.48, 0.035, 0.465, 0.035)
      B(K.deco, BLACK, 1.12, 0.07, side * 0.48, 0.08, 0.07, 0.04)
      B(K.deco, BLACK, -1.12, 0.07, side * 0.48, 0.08, 0.07, 0.04)
    end
    B(K.deco, BEDF, 1.12, 1.38, 0, 0.03, 0.035, 0.5)
    B(K.deco, BEDF, 1.12, 1.02, 0, 0.025, 0.03, 0.46)
    B(K.deco, BEDF, -1.12, 1.03, 0, 0.03, 0.035, 0.5)
    B(K.deco, BEDF, -1.12, 0.78, 0, 0.025, 0.03, 0.46)
    if haunted == 1 then
      ghost(G.P(-0.1 * sc, 0.72 * sc, 0), G.F * -1, 0.7 * sc, G.N)
    elseif haunted == 2 then
      egg(K.deco, bl, G.P(-0.25 * sc, 0.84 * sc, 0), G.F * (0.6 * sc), 0.3 * sc, 0.2 * sc, 6)
    end
    count("beds")
  end

  local function wheelchair(G, sc)
    local B = boxer(G, sc)
    local seat = K.pick(SEATS)
    local function P(a, h, b) return G.P(a * sc, h * sc, b * sc) end
    B(K.solid, seat, 0, 0.5, 0, 0.25, 0.04, 0.25)
    B(K.solid, seat, -0.25, 0.85, 0, 0.035, 0.32, 0.25)
    for side = -1, 1, 2 do
      limb(K.solid, BLACK, P(-0.1, 0.33, side * 0.3), P(-0.1, 0.33, side * 0.36), 0.33 * sc, 0.33 * sc, 10)
      limb(K.deco, STEEL2, P(-0.1, 0.33, side * 0.29), P(-0.1, 0.33, side * 0.37), 0.12 * sc, 0.12 * sc, 6)
      B(K.deco, BLACK, 0.3, 0.08, side * 0.24, 0.08, 0.08, 0.03)
      B(K.deco, BLACK, 0, 0.72, side * 0.27, 0.2, 0.025, 0.03)
      beam(K.deco, STEEL, P(0.25, 0.5, side * 0.24), P(0.4, 0.16, side * 0.24), 0.02 * sc, 0.02 * sc)
      beam(K.deco, STEEL, P(-0.27, 1.1, side * 0.25), P(-0.52, 1.16, side * 0.25), 0.02 * sc, 0.02 * sc)
    end
    B(K.deco, STEEL, 0.42, 0.16, 0, 0.08, 0.02, 0.24)
    if rnd(0, 1) < 0.3 then ghost(P(0, 0.5, 0), G.F, 0.62 * sc, G.N) end
    count("wheelchairs")
  end

  local function drip(G, sc)
    local B = boxer(G, sc)
    B(K.solid, STEEL2, 0, 1.05, 0, 0.025, 1.05, 0.025)
    B(K.solid, STEEL, 0, 0.04, 0, 0.3, 0.03, 0.04)
    B(K.solid, STEEL, 0, 0.05, 0, 0.04, 0.03, 0.3)
    B(K.deco, STEEL2, 0, 2.08, 0, 0.22, 0.02, 0.02)
    B(K.deco, K.pick(POTIONS), 0.19, 1.84, 0, 0.09, 0.17, 0.045)
    if rnd(0, 1) < 0.5 then B(K.deco, K.pick(POTIONS), -0.19, 1.86, 0, 0.08, 0.15, 0.045) end
    beam(K.deco, WHITE, G.P(0.19 * sc, 1.67 * sc, 0), G.P(0.06 * sc, 0.95 * sc, 0), 0.012 * sc, 0.012 * sc)
    count("drip stands")
  end

  local function trolley(G, sc)
    local B = boxer(G, sc)
    for a = -1, 1, 2 do
      for b = -1, 1, 2 do
        B(K.solid, STEEL, a * 0.4, 0.5, b * 0.25, 0.02, 0.42, 0.02)
        B(K.deco, BLACK, a * 0.4, 0.05, b * 0.25, 0.05, 0.05, 0.03)
      end
    end
    B(K.solid, STEEL2, 0, 0.9, 0, 0.45, 0.025, 0.3)
    B(K.solid, STEEL2, 0, 0.35, 0, 0.45, 0.02, 0.3)
    B(K.deco, K.pick(POTIONS), 0.2, 1.05, 0.1, 0.06, 0.13, 0.06)
    B(K.deco, K.pick(POTIONS), -0.12, 1.0, -0.1, 0.07, 0.08, 0.07)
    B(K.deco, WHITE, -0.2, 0.4, 0, 0.15, 0.03, 0.2)
    B(K.deco, STEEL, -0.48, 1.05, 0, 0.015, 0.02, 0.3)
    count("trolleys")
  end

  local function cabinet(G, sc, papers)
    local B = boxer(G, sc)
    local cc = K.pick(CABS)
    B(K.solid, cc[1], 0, 0.66, 0, 0.3, 0.66, 0.24)
    local out = math.floor(rnd(0, 6))
    for j = 0, 3 do
      local h = 0.18 + j * 0.32
      if j == out then
        B(K.deco, cc[2], 0.5, h, 0, 0.22, 0.14, 0.21)
        B(K.deco, WHITE, 0.52, h + 0.16, 0, 0.14, 0.05, 0.16)
        B(K.deco, BLACK, 0.73, h + 0.05, 0, 0.012, 0.02, 0.08)
      else
        B(K.deco, cc[2], 0.31, h, 0, 0.02, 0.14, 0.21)
        B(K.deco, BLACK, 0.34, h + 0.05, 0, 0.012, 0.02, 0.08)
      end
    end
    if papers then
      for _ = 1, 3 do B(K.deco, WHITE, rnd(0.55, 1.2), 0.03, rnd(-0.6, 0.6), 0.1, 0.012, 0.14) end
    end
    count("filing cabinets")
  end

  -- ---------------------------------------------------------------- the corridor's walls
  local SEG, WOFF = 4, 4.2
  local WARDS = {"WARD 1", "X-RAY", "WARD 2", "WARD 7", "X-RAY", "WARD 13", "WARD 4", "X-RAY", "WARD 9", "WARD 6"}
  local doors = 0
  local function light(at, dh, nrm, top, r)
    local base = at(0, top - 0.3) + nrm * 0.05
    local tip = base + nrm * 1.9 + UP * 0.25
    beam(K.deco, STEEL, base, tip, 0.03, 0.03)
    local pc = tip - UP * 0.22 - nrm * 0.2
    if r < 0.4 then
      obox(K.deco, HOUSE, pc + UP * 0.1, dh * 0.85, UP * 0.04, nrm * 0.3)
      obox(K.deco, LIT, pc, dh * 0.8, UP * 0.08, nrm * 0.26)
    elseif r < 0.7 then
      obox(K.deco, HOUSE, pc + UP * 0.1, dh * 0.85, UP * 0.04, nrm * 0.3)
      obox(K.deco, LIT, pc - dh * 0.41, dh * 0.39, UP * 0.08, nrm * 0.26)
      obox(K.deco, DIM, pc + dh * 0.41, dh * 0.39, UP * 0.08, nrm * 0.26)
    else
      local ax = normalize(dh - UP * 0.55)
      local e2 = normalize(cross(ax, nrm))
      local c = tip - UP * 0.1 + ax * 0.8
      obox(K.deco, HOUSE, c + e2 * 0.1, ax * 0.85, e2 * 0.04, nrm * 0.3)
      obox(K.deco, DEAD, c, ax * 0.8, e2 * 0.08, nrm * 0.26)
    end
    count("lights")
  end

  local function wallseg(A, B, sd, k)
    local q0, q1 = A.p, B.p
    local flatd = v3(q1.x - q0.x, 0, q1.z - q0.z)
    local L = length(flatd) / 2
    if L < 0.9 or L > 5 then return end
    local dh = flatd * (1 / (2 * L))
    local i = A.i
    local nrm = right[math.min(N, i + 2)] * -sd
    nrm = normalize(nrm - dh * dot(nrm, dh))
    local mid, d3 = (q0 + q1) * 0.5, (q1 - q0) * 0.5
    local function at(t, h) return mid + d3 * t + UP * h end
    local r = K.hash(i * 1.7 + sd * 31, k * 2.3)
    if (k + ((sd > 0) and 4 or 0)) % 6 == 3 and L >= 1.95 then
      -- A doorway: stubs of wall, the frame, a transom over it, and two swing doors hanging open.
      doors = doors + 1
      local sL = 1.75 / L
      if sL < 0.93 then
        for e = -1, 1, 2 do
          obox(K.solid, WALLC, at(e * (1 + sL) / 2, 1.7), d3 * ((1 - sL) / 2 * 0.97), UP * 2.3, nrm * 0.15)
          obox(K.solid, DADO, at(e * (1 + sL) / 2, 0.4), d3 * ((1 - sL) / 2 * 0.98), UP * 1.0, nrm * 0.18)
        end
      end
      for e = -1, 1, 2 do obox(K.solid, FRAMEW, at(e * 1.68 / L, 1.25), dh * 0.09, UP * 1.75, nrm * 0.2) end
      obox(K.solid, WALLC2, at(0, 3.5), d3 * (1.74 / L), UP * 0.5, nrm * 0.16)
      obox(K.deco, FRAMEW, at(0, 3.0), d3 * (1.72 / L), UP * 0.09, nrm * 0.21)
      local sense = (r < 0.5) and 1 or -1
      local dc = (doors % 3 == 0) and DOOR2 or DOOR1
      for e = -1, 1, 2 do
        local ang = math.rad(rnd(35, 110))
        local s2 = (rnd(0, 1) < 0.25) and -sense or sense
        local dir = dh * (-e * math.cos(ang)) + nrm * (s2 * math.sin(ang))
        local hinge = at(e * 1.58 / L, 0)
        local upv = UP
        if rnd(0, 1) < 0.25 then upv = normalize(UP + dir * 0.22) end
        local ln = normalize(cross(dir, upv))
        local c = hinge + dir * 0.78 + upv * 1.45
        obox(K.solid, dc, c, dir * 0.74, upv * 1.32, ln * 0.04)
        limb(K.deco, PORT, c + upv * 0.55 - ln * 0.06, c + upv * 0.55 + ln * 0.06, 0.3, 0.3, 8)
        obox(K.deco, STEEL, c - upv * 1.05, dir * 0.72, upv * 0.22, ln * 0.052)
      end
      local e = (doors % 2 == 0) and -1 or 1
      web(at(e * 1.56 / L, 2.9) + nrm * 0.02, dh * -e, UP * -1, 1.25, nrm)
      -- Its blade sign, out from the wall at the end the karts come from.
      local uu = dh
      if dot(dh, K.along(i)) < 0 then uu = dh * -1 end
      local tu = (dot(uu, dh) > 0) and -0.96 or 0.96
      local word = WARDS[(doors - 1) % #WARDS + 1]
      local xr = word == "X-RAY"
      local Q = at(tu, 3.42) + nrm * 1.45
      obox(K.deco, xr and SIGNY or WHITE, Q, nrm * 1.3, UP * 0.42, uu * 0.05)
      text(K.deco, xr and BLACK or SIGNG, word, Q - uu * 0.07, rightof(uu), 2.3 / (#word * 4 - 1), uu * -1)
      local m = mid + nrm * 1.3
      take(m.x, m.z, 2.0)
      count("doorways")
      return
    end
    if r < 0.1 then
      -- Fallen in: a low jagged stub and its rubble.
      obox(K.solid, WALLC2, at(0, 0.1), d3 * 0.9, UP * 0.7 + dh * 0.12, nrm * 0.15)
      obox(K.solid, DADO, at(-0.1, 0), d3 * 0.7, UP * 0.6, nrm * 0.18)
      for _ = 1, 3 do
        local c = at(rnd(-0.7, 0.7), 0.25) - nrm * rnd(0.5, 1.4)
        obox(K.solid, (rnd(0, 1) < 0.5) and WALLC or PLASTER, c, normalize(dh + UP * rnd(-0.4, 0.4)) * rnd(0.3, 0.55),
          normalize(UP + nrm * rnd(-0.5, 0.5)) * rnd(0.15, 0.3), nrm * rnd(0.2, 0.4))
      end
      return
    end
    local top = 3.3 + 0.9 * K.hash(k * 3.1, sd * 7 + i)
    obox(K.solid, (k % 2 == 0) and WALLC or WALLC2, at(0, (top - 0.6) / 2), d3 * 0.985, UP * ((top + 0.6) / 2), nrm * 0.15)
    obox(K.solid, DADO, at(0, 0.4), d3 * 0.99, UP * 1.0, nrm * 0.18)
    for _ = 1, 2 do
      local t, hh = rnd(-0.7, 0.7), rnd(1.95, top - 0.7)
      local sx, sy = rnd(0.3, 0.75), rnd(0.25, 0.55)
      local a = d3 * (sx / L) + UP * rnd(-0.12, 0.12)
      obox(K.deco, PLASTER, at(t, hh), a, UP * sy + dh * rnd(-0.1, 0.1), nrm * 0.165)
      if rnd(0, 1) < 0.6 then obox(K.deco, BRICK, at(t, hh) + dh * rnd(-0.1, 0.1), a * 0.55, UP * (sy * 0.6), nrm * 0.178) end
    end
    if k % 3 == 1 then light(at, dh, nrm, top, K.hash(k * 5.3 + sd, i * 0.7)) end
    count("wall bays")
  end

  for _, sd in ipairs({-1, 1}) do
    local pts = {}
    for i = 3, N - 3, SEG do
      local p = pos[i] + right[i] * (sd * (W[i] + EDGE + WOFF))
      local y, d = K.ground_d(p.x, p.z)
      pts[#pts + 1] = {p = v3(p.x, y, p.z), i = i, ok = (d - K.HW) > EDGE + 2.5 and math.abs(y - (pos[i].y + 0.6)) < 3}
    end
    for k = 1, #pts - 1 do
      if pts[k].ok and pts[k + 1].ok then wallseg(pts[k], pts[k + 1], sd, k) end
    end
  end

  -- ---------------------------------------------------------------- the ceiling's ribs, high over the road
  local RIBW = {"WARD 1", "X-RAY", "WARD 13", "WARD 7", "X-RAY", "WARD 9", "WARD 2", "X-RAY"}
  local ribs = 0
  local function rib(i, word)
    local r, u = right[i], K.along(i)
    local offp = W[i] + EDGE + 0.9
    local Y = pos[i].y + math.max(K.lift(i, -1), K.lift(i, 1), 0) + 6.5
    local feet = {}
    for e = -1, 1, 2 do
      local p = pos[i] + r * (e * offp)
      local y, d = K.ground_d(p.x, p.z)
      if d - K.HW < EDGE + 0.6 or y > Y - 3 then return false end
      feet[#feet + 1] = {p, y, e}
    end
    for _, ft in ipairs(feet) do
      local p, y, e = ft[1], ft[2], ft[3]
      obox(K.solid, RIBC, v3(p.x, (y - 0.6 + Y) / 2, p.z), r * 0.14, UP * ((Y - y + 0.6) / 2), u * 0.14)
      web(v3(p.x, Y - 0.02, p.z) - r * (e * 0.15), r * -e, UP * -1, 0.8, u)
      take(p.x, p.z, 0.6)
    end
    local cb = v3(pos[i].x, Y + 0.25, pos[i].z)
    obox(K.deco, RIBC, cb, r * (offp + 0.3), UP * 0.25, u * 0.2)
    for e = -1, 1, 2 do
      local h = K.hash(i * 0.37, e * 5.1)
      obox(K.deco, (h < 0.6) and LIT or ((h < 0.85) and DIM or DEAD), cb + r * (e * 1.4) - UP * 0.3, r * 1.0, UP * 0.1, u * 0.32)
    end
    if word then
      local bc = cb + UP * 1.2
      local ex = word == "EXIT"
      obox(K.deco, SIGNG, bc, r * 2.7, UP * 0.9, u * 0.06)
      obox(K.deco, WHITE, bc, r * 2.8, UP * 1.0, u * 0.04)
      text(K.deco, ex and LIT or WHITE, word, bc - u * 0.08, r, math.min(0.19, 4.8 / (#word * 4 - 1)), u * -1)
    end
    count("ribs")
    return true
  end
  for i = K.start + 14, K.fin - 34, 30 do
    ribs = ribs + 1
    rib(i, (ribs % 2 == 1) and RIBW[((ribs - 1) / 2) % #RIBW + 1] or nil)
  end
  rib(K.fin - 12, "EXIT")

  -- ---------------------------------------------------------------- strewn down the corridor and the wards behind
  -- lo..hi metres past the road's margin, a thing `rad` wide: fn(x, z, y, i, sd).
  local function strew(n, lo, hi, rad, fn)
    local done = 0
    for _ = 1, n * 4 do
      if done >= n then break end
      local i = math.floor(rnd(4, N - 3))
      local sd = (rnd(0, 1) < 0.5) and -1 or 1
      local offr = EDGE + rnd(lo, hi)
      local p = pos[i] + right[i] * (sd * (W[i] + offr))
      if free(p.x, p.z, rad) then
        local y, d = K.ground_d(p.x, p.z)
        if d - K.HW > EDGE + math.min(lo, rad) and math.abs(y - pos[i].y) < 5 then
          take(p.x, p.z, rad)
          fn(p.x, p.z, y, i, sd)
          done = done + 1
        end
      end
    end
    return done
  end
  -- (the way the road runs at sample i, as an angle)
  local function heading(i)
    local a = K.along(i)
    return math.atan(a.z, a.x)
  end
  local function a_bed(x, z, y, i, sd)
    local G = stand(x, z, y, heading(i) + rnd(-0.4, 0.4) + ((rnd(0, 1) < 0.5) and math.pi or 0), i, sd)
    local h = rnd(0, 1)
    if h < 0.14 then bed(tipped(G, 0.52 * 1.25), 1.25, 0) else bed(G, 1.25, (h < 0.42) and 1 or ((h < 0.7) and 2 or 0)) end
  end
  local function a_chair(x, z, y, i, sd) wheelchair(stand(x, z, y, heading(i) + rnd(-0.9, 0.9), i, sd), 1.3) end
  local function a_drip(x, z, y, i, sd) drip(stand(x, z, y, rnd(0, 6.28), i, sd, 0.16), 1.25) end
  local function a_trolley(x, z, y, i, sd) trolley(stand(x, z, y, heading(i) + rnd(-0.6, 0.6), i, sd), 1.25) end
  local function a_cabinet(x, z, y, i, sd)
    local face = right[i] * -sd
    local G = stand(x, z, y, math.atan(face.z, face.x) + rnd(-0.5, 0.5), i, sd)
    if rnd(0, 1) < 0.25 then cabinet(tipped(G, 0.24 * 1.25), 1.25, false) else cabinet(G, 1.25, true) end
  end
  local function a_ghost(lo, hi)
    return function(x, z, y, i, sd)
      ghost(v3(x, y + 0.35, z), right[i] * -sd - K.along(i) * 0.9, rnd(lo, hi))
    end
  end
  strew(30, 1.45, 2.7, 1.4, a_bed)
  strew(22, 1.0, 3.0, 0.8, a_chair)
  strew(34, 0.6, 3.4, 0.45, a_drip)
  strew(20, 0.9, 3.1, 0.75, a_trolley)
  strew(26, 2.6, 3.3, 0.6, a_cabinet)
  strew(16, 1.2, 3.0, 1.0, a_ghost(1.2, 1.7))
  -- the wards, behind the walls
  strew(24, 6.0, 12.5, 1.5, a_bed)
  strew(8, 5.6, 12, 0.8, a_chair)
  strew(12, 5.4, 12, 0.5, a_drip)
  strew(10, 5.4, 9, 0.7, a_cabinet)
  strew(16, 6.2, 13, 2.0, a_ghost(2.2, 3.4))

  -- Bats, a few together, over the walls.
  for _ = 1, 16 do
    local i = math.floor(rnd(6, N - 6))
    local sd = (rnd(0, 1) < 0.5) and -1 or 1
    local c = pos[i] + right[i] * (sd * (W[i] + EDGE + rnd(1.5, 7))) + UP * rnd(5, 9)
    local u = K.along(i)
    for _ = 1, 5 do
      local p = c + v3(rnd(-2.5, 2.5), rnd(-1.2, 1.2), rnd(-2.5, 2.5))
      local y, d = K.ground_d(p.x, p.z)
      if d - K.HW > EDGE + 1.6 and p.y > y + 3 then
        bat(p, normalize(u * ((rnd(0, 1) < 0.5) and -1 or 1) + right[i] * rnd(-0.6, 0.6)), rnd(1.1, 1.7))
      end
    end
  end

  -- ---------------------------------------------------------------- outside: graves and dead trees
  local function grave(x, z, y, f)
    local s = v3(-f.z, 0, f.x)
    local gc = K.pick(GRAVES)
    local upv = normalize(UP + s * rnd(-0.2, 0.2) + f * rnd(-0.25, 0.25))
    local o = v3(x, y, z)
    local kind = rnd(0, 1)
    if kind < 0.62 then
      local w, h, t = rnd(0.5, 0.7), rnd(1.1, 1.8), 0.12
      local prof = {{-w, -0.4}, {w, -0.4}, {w, h}, {0.7 * w, h + 0.45 * w}, {0, h + 0.62 * w}, {-0.7 * w, h + 0.45 * w}, {-w, h}}
      local r1, r2 = {}, {}
      for j, p in ipairs(prof) do
        r1[j] = o + s * p[1] + upv * p[2] - f * t
        r2[j] = o + s * p[1] + upv * p[2] + f * t
      end
      K.prism(piece(K.solid, gc), {r1, r2}, K.flat(gc), gc, gc)
    elseif kind < 0.88 then
      local h = rnd(1.5, 2.1)
      obox(K.solid, gc, o + upv * (h / 2 - 0.2), s * 0.13, upv * (h / 2 + 0.2), f * 0.11)
      obox(K.solid, gc, o + upv * (h * 0.7), s * 0.5, upv * 0.12, f * 0.1)
    else
      local h = rnd(2.2, 3.0)
      tube(K.solid, gc, {o - upv * 0.4, o + upv * h, o + upv * (h + 0.5)}, {0.42, 0.26, 0.03}, 4)
    end
    count("gravestones")
  end

  local function deadtree(x, z, y, h)
    local a0 = rnd(0, 6.28)
    local dir = v3(math.cos(a0), 0, math.sin(a0))
    local p0 = v3(x, y - 0.5, z)
    local p1 = p0 + UP * (h * 0.5) + dir * (h * 0.08)
    local p2 = p0 + UP * h - dir * (h * 0.06)
    tube(K.solid, DEADW, {p0, p1, p2}, {0.34, 0.24, 0.1}, 5)
    for k = 1, 4 do
      local a = a0 + k * 1.7 + rnd(-0.4, 0.4)
      local o = v3(math.cos(a), 0, math.sin(a))
      local b0 = lerp(p1, p2, (k - 1) / 4)
      local b1 = b0 + o * rnd(1.4, 2.4) + UP * rnd(0.6, 1.5)
      limb(K.deco, DEADW, b0, b1, 0.12, 0.06, 5)
      limb(K.deco, DEADW, b1 - o * 0.05, b1 + o * rnd(0.4, 0.9) + UP * rnd(0.7, 1.4) + v3(rnd(-0.5, 0.5), 0, rnd(-0.5, 0.5)), 0.06, 0.02, 4)
    end
    count("dead trees")
  end

  -- ---------------------------------------------------------------- the hospital, beside the road near its end
  -- (facing the road: the first site whose whole footprint, and its graveyard's, is well clear of the road)
  local HU, HW_, HC
  for _, off in ipairs({48, 56, 66}) do
    for i = N - 6, math.max(K.fin - 120, 10), -8 do
      for _, sd in ipairs({1, -1}) do
        if not HC then
          local w = right[i] * sd
          local u = v3(-w.z, 0, w.x)
          local c = pos[i] + w * (W[i] + off)
          local ok = true
          for a = -33, 33, 11 do
            for b = -30, 12, 6 do
              local q = c + u * a + w * b
              local _, d = K.ground_d(q.x, q.z)
              if d - K.HW < ((b < -14) and 14 or 24) or q.x < K.X0 + 4 or q.x > K.X1 - 4 or q.z > K.Z0 - 4 or q.z < K.Z1 + 4 then
                ok = false
              end
            end
          end
          if ok then HU, HW_, HC = u, w, c end
        end
      end
    end
  end
  if not HC then
    HU, HW_ = right[N], K.along(N)
    HC = pos[N] + right[N] * 80
  end
  do
    local front = HC - HW_ * 10
    local yb = K.ground(front.x, front.z) + 0.6
    local y0 = math.min(yb - 3, K.lowest(v3(HC.x, 0, HC.z), HU, HW_, 27, 11) - 1)
    local function HP(a, y, b) return v3(HC.x, 0, HC.z) + HU * a + HW_ * b + UP * y end
    -- a box from a0..a1 across, y0..y1 up, b0..b1 deep
    local function hb(root, c, a0, a1, ya, yb2, b0, b1)
      obox(root, c, HP((a0 + a1) / 2, (ya + yb2) / 2, (b0 + b1) / 2), HU * ((a1 - a0) / 2), UP * ((yb2 - ya) / 2), HW_ * ((b1 - b0) / 2))
    end
    local function tri3(root, c, p1, p2, p3, q1, q2, q3)
      K.prism(piece(root, c), {{p1, p2, p3}, {q1, q2, q3}}, K.flat(c), c, c)
    end
    -- the main block and its roof
    hb(K.solid, STONE, -17, 17, y0, yb + 12, -7, 7)
    tri3(K.deco, ROOF, HP(-17.3, yb + 12, -7.5), HP(-17.3, yb + 18, 0), HP(-17.3, yb + 12, 7.5),
      HP(17.3, yb + 12, -7.5), HP(17.3, yb + 18, 0), HP(17.3, yb + 12, 7.5))
    -- gabled bays
    for _, a in ipairs({-11.5, 11.5}) do
      hb(K.solid, STONE2, a - 3.2, a + 3.2, y0, yb + 12.5, -9, -6)
      tri3(K.deco, ROOF, HP(a - 3.6, yb + 12.5, -9.3), HP(a, yb + 16.6, -9.3), HP(a + 3.6, yb + 12.5, -9.3),
        HP(a - 3.6, yb + 12.5, 0.2), HP(a, yb + 16.6, 0.2), HP(a + 3.6, yb + 12.5, 0.2))
      hb(K.deco, WIN_G, a - 0.9, a + 0.9, yb + 3, yb + 9, -9.08, -8.9)
      tri3(K.deco, WIN_G, HP(a - 0.9, yb + 9.02, -9.08), HP(a + 0.9, yb + 9.02, -9.08), HP(a, yb + 10.6, -9.08),
        HP(a - 0.9, yb + 9.02, -8.9), HP(a + 0.9, yb + 9.02, -8.9), HP(a, yb + 10.6, -8.9))
      hb(K.deco, STONE, a - 0.08, a + 0.08, yb + 3, yb + 9, -9.12, -8.9)
      hb(K.deco, STONE, a - 0.9, a + 0.9, yb + 6, yb + 6.16, -9.12, -8.9)
    end
    -- the clock tower
    hb(K.solid, STONE2, -3.5, 3.5, y0, yb + 27, -10, -3)
    hb(K.deco, STONE, -3.9, 3.9, yb + 27.02, yb + 27.7, -10.4, -2.6)
    do
      local h, y = 3.9, yb + 27.72
      local c = HP(0, y, -6.5)
      local pts = {c + HU * h + HW_ * h, c - HU * h + HW_ * h, c - HU * h - HW_ * h, c + HU * h - HW_ * h}
      K.cone(piece(K.deco, ROOF), pts, c, c + UP * 10.5, function() return ROOF end, ROOF)
      for a = -1, 1, 2 do
        for b = -1, 1, 2 do
          local p = HP(a * 3.5, yb + 27.7, -6.5 + b * 3.5)
          tube(K.deco, STONE2, {p, p + UP * 2.2, p + UP * 4}, {0.5, 0.45, 0.04}, 4)
        end
      end
    end
    local cc = HP(0, yb + 22, -10)
    limb(K.deco, STONE, cc - HW_ * 0.12, cc + HW_ * 0.2, 2.9, 2.9, 14)
    limb(K.deco, CLOCK, cc - HW_ * 0.22, cc + HW_ * 0.2, 2.5, 2.5, 14)
    for k = 0, 11 do
      local a = k / 12 * math.pi * 2
      local d = HU * math.sin(a) + UP * math.cos(a)
      beam(K.deco, BLACK, cc - HW_ * 0.24 + d * 1.95, cc - HW_ * 0.24 + d * 2.35, (k % 3 == 0) and 0.12 or 0.06, 0.03, HW_)
    end
    beam(K.deco, BLACK, cc - HW_ * 0.27, cc - HW_ * 0.27 + (UP * 0.866 - HU * 0.5) * 2.0, 0.1, 0.03, HW_)
    beam(K.deco, BLACK, cc - HW_ * 0.3, cc - HW_ * 0.3 + (UP * 0.99 + HU * 0.1) * 1.35, 0.14, 0.03, HW_)
    hb(K.deco, WIN_Y, -0.5, 0.5, yb + 12, yb + 15.5, -10.08, -9.9)
    -- the door, its steps, the name over it (a letter down)
    hb(K.deco, WIN_D, -1.5, 1.5, yb - 0.8, yb + 3.4, -10.1, -9.9)
    tri3(K.deco, WIN_D, HP(-1.5, yb + 3.42, -10.1), HP(1.5, yb + 3.42, -10.1), HP(0, yb + 5.2, -10.1),
      HP(-1.5, yb + 3.42, -9.9), HP(1.5, yb + 3.42, -9.9), HP(0, yb + 5.2, -9.9))
    hb(K.solid, STONE, -2.6, 2.6, y0, yb - 0.8, -11.4, -9.95)
    hb(K.solid, STONE2, -3.1, 3.1, y0, yb - 1.5, -12.9, -11.45)
    text(K.deco, BONE, "HOSP TAL", HP(0, yb + 8.2, -10.06), HU, 0.2, HW_ * -1, 0.07)
    obox(K.deco, BONE, HP(1.3, yb - 0.6, -11.0), normalize(HU + UP * 0.5) * 0.3, normalize(UP - HU * 0.5) * 0.5, HW_ * 0.07)
    -- windows, two storeys: lit yellow, a ghostly green, or dark
    for a = -15.2, 15.3, 3.3 do
      if math.abs(a) > 4.6 and math.abs(math.abs(a) - 11.5) > 3.9 then
        for st = 0, 1 do
          local h = K.hash(a * 1.3, st * 7.7)
          local c = (h < 0.5) and WIN_Y or ((h < 0.72) and WIN_G or WIN_D)
          local yw = yb + 1.6 + st * 5.2
          hb(K.deco, c, a - 0.6, a + 0.6, yw, yw + 2.6, -7.1, -6.9)
          tri3(K.deco, c, HP(a - 0.6, yw + 2.62, -7.1), HP(a + 0.6, yw + 2.62, -7.1), HP(a, yw + 3.6, -7.1),
            HP(a - 0.6, yw + 2.62, -6.9), HP(a + 0.6, yw + 2.62, -6.9), HP(a, yw + 3.6, -6.9))
        end
      end
    end
    -- leaning chimneys
    for _, a in ipairs({-9, 5.5, 13}) do
      obox(K.deco, STONE2, HP(a, yb + 18.5, 0.5), HU * 0.7, (UP + HU * ((a < 0) and -0.14 or 0.1)) * 2.6, HW_ * 0.7)
    end
    -- the ruined wing: jagged stumps of wall, bare rafters, rubble
    local FH = {3, 6.5, 4.5, 9, 11.2}
    local BH = {7, 5, 9.5, 8, 12}
    for j = 1, 5 do
      local a = -27 + (j - 1) * 2.0
      hb(K.solid, (j % 2 == 0) and STONE or STONE2, a, a + 1.94, y0, yb + FH[j], -7, -6)
      hb(K.solid, (j % 2 == 1) and STONE or STONE2, a, a + 1.94, y0, yb + BH[j], 6, 7)
    end
    hb(K.solid, STONE, -27.4, -26.6, y0, yb + 4.5, -5.9, -1.5)
    hb(K.solid, STONE2, -27.4, -26.6, y0, yb + 7.5, -1.4, 2.5)
    hb(K.solid, STONE, -27.4, -26.6, y0, yb + 3.2, 2.6, 5.9)
    for k = 0, 2 do
      beam(K.deco, FRAMEW, HP(-17, yb + 12.3 + k * 2.4, -6.5 + k * 2.6), HP(-17 - rnd(3, 6), yb + 11.6 + k * 2.4 - rnd(0, 1.5), -6.5 + k * 2.6), 0.14, 0.14)
    end
    for _ = 1, 12 do
      local p = HP(rnd(-29, -15), 0, rnd(-11, -7.6))
      local y = K.ground(p.x, p.z)
      obox(K.solid, (rnd(0, 1) < 0.5) and STONE or STONE2, v3(p.x, y + 0.25, p.z), normalize(HU + UP * rnd(-0.4, 0.4)) * rnd(0.4, 0.9),
        normalize(UP + HW_ * rnd(-0.4, 0.4)) * rnd(0.3, 0.6), HW_ * rnd(0.3, 0.7))
    end
    -- its residents: a giant ghost rising out of the ruin, bats round the tower
    ghost(HP(-22, yb + 1, 1), HW_ * -1, 7.5)
    for _ = 1, 10 do
      local a = rnd(0, 6.28)
      bat(HP(math.cos(a) * rnd(6, 12), yb + rnd(22, 37), -6.5 + math.sin(a) * rnd(6, 12)), v3(-math.sin(a), 0, math.cos(a)), rnd(1.8, 2.6))
    end
    for _, a in ipairs({-31, 21, 25}) do
      local p = HP(a, 0, rnd(-13, -9))
      deadtree(p.x, p.z, K.ground(p.x, p.z), rnd(6, 8))
    end
  end
  local function near_hospital(x, z)
    local dx, dz = x - HC.x, z - HC.z
    return dx * dx + dz * dz < 36 * 36
  end

  -- The graveyard before its door, in rows; more plots out on the slopes.
  for b = 0, 3 do
    for a = -6, 6 do
      if rnd(0, 1) < 0.82 then
        local p = HC - HW_ * (15.5 + b * 3.7 + rnd(-0.5, 0.5)) + HU * (a * 3.3 + rnd(-0.6, 0.6))
        local y, d = K.ground_d(p.x, p.z)
        if d - K.HW > 15 and a ~= 0 then grave(p.x, p.z, y, HW_ * -1) end
      end
    end
  end
  local plots = 0
  for _ = 1, 40 do
    if plots >= 11 then break end
    local x, z = K.spot(26)
    if x and not near_hospital(x, z) and free(x, z, 7) then
      take(x, z, 7)
      plots = plots + 1
      local a = rnd(0, 6.28)
      local f = v3(math.cos(a), 0, math.sin(a))
      local s = v3(-f.z, 0, f.x)
      for gi = -1, 1 do
        for gj = -1, 1 do
          if rnd(0, 1) < 0.85 then
            local p = v3(x, 0, z) + f * (gi * 3.2) + s * (gj * 2.8 + rnd(-0.4, 0.4))
            grave(p.x, p.z, K.ground(p.x, p.z), f)
          end
        end
      end
    end
  end
  local function far(n, clearance, R, fn)
    for _ = 1, n * 4 do
      if n <= 0 then break end
      local x, z = K.spot(clearance)
      if x and not near_hospital(x, z) and free(x, z, R) then
        take(x, z, R)
        fn(x, z, K.ground(x, z))
        n = n - 1
      end
    end
  end
  far(16, 23, 4, function(x, z, y) deadtree(x, z, y, rnd(5.5, 8.5)) end)
  far(9, 24, 6, function(x, z, y)
    local a = rnd(0, 6.28)
    ghost(v3(x, y + 0.6, z), v3(math.cos(a), 0, math.sin(a)), rnd(4, 6))
  end)

  local list = {}
  for k, n in pairs(made) do list[#list + 1] = n .. " " .. k end
  table.sort(list)
  info(string.format("hospital at %.0f %.0f %.0f; ", HC.x, K.ground(HC.x, HC.z), HC.z) ..table.concat(list, ", "))
end

return T
