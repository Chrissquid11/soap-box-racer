-- The Multistorey Car Park's scenery kit (see THEME KITS in _course.lua): the valley flattened into concrete ramps
-- at the road's own height (T.shape; a level is every LH metres down), painted grey with tarmac aisles, oil stains and a yellow chequered verge
-- (T.paint); rows of white-lined bays full of parked cars, yellow hatched boxes at their ends, shopping trolleys and
-- trolley shelters, pay machines, lift towers; by the road concrete pillars with yellow and black bases and a band of
-- their level's colour, a big LEVEL board where each level begins, low-clearance gantries (well over the road),
-- bollards, CCTV and strip-light posts; a parapet round the edge with the town beyond, and a green EXIT at the bottom.
-- Every piece is one colour's (K.sub by colour) but the banded prisms, a few colours each.
local LH = 5                       -- a level's height
local T = {trees = 0, rocks = 0}

local function h2(a, b)
  local s = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
  return s - math.floor(s)
end

-- The decks. By the road the ground is a bare concrete ramp at the road's own height (no banks); further out it
-- steps down the hill in terraces TB metres deep (flat for 15 m, then a 5 m bank: the valley's grid is 5 m, and its
-- rows lie on the terraces' edges), at about the road's height as it passes: this course falls TS a metre southwards
-- from TOP.
local TB, TOP, TS = 20, 113, 0.42
local function terrace(z)
  local t = math.floor((-z + 0.01) / TB)
  return math.max(-6, TOP - TS * (t * TB + TB / 2)) - 0.5   -- (never down to the valley's floor, 20 m under the road's lowest)
end
function T.shape(x, z, off, y, road_y, TK)
  if off <= 8 then return nil end
  local deck = road_y - 0.5
  if off < 11.5 then
    local t = (off - 8) / 3.5
    t = t * t * (3 - 2 * t)
    return y + (deck - y) * t
  end
  if off <= 12 then return deck end
  local ter = terrace(z)
  if off >= 21 then return ter end
  local t = (off - 12) / 9
  t = t * t * (3 - 2 * t)
  return deck + (ter - deck) * t
end

local INK
function T.paint(x, z, off, ink, TK)
  if not INK then
    INK = {yel = TK.col(0.95, 0.75, 0.05), dark = TK.col(0.12, 0.12, 0.13), kerb = TK.col(0.62, 0.62, 0.6),
      kerb2 = TK.col(0.57, 0.57, 0.56), oil = TK.col(0.2, 0.2, 0.22), lane = TK.col(0.27, 0.27, 0.29),
      lane2 = TK.col(0.3, 0.3, 0.31), c1 = TK.col(0.46, 0.46, 0.45), c2 = TK.col(0.5, 0.5, 0.49), c3 = TK.col(0.42, 0.43, 0.43)}
  end
  local cx, cz = math.floor(x / 5), math.floor(z / 5)
  local h = h2(cx, cz)
  if off < 3.6 then return ((cx + cz) % 2 == 0) and INK.yel or INK.dark end
  if off < 9 then return (h < 0.5) and INK.kerb or INK.kerb2 end
  if h < 0.035 then return INK.oil end
  -- (a terrace is four rows of cells: its bank, a row of bays, the aisle, a row of bays)
  if cz % 4 == 2 then return (h < 0.5) and INK.lane or INK.lane2 end
  if cz % 4 == 0 then return (h < 0.5) and INK.kerb or INK.kerb2 end
  return (h < 0.33) and INK.c1 or ((h < 0.66) and INK.c2 or INK.c3)
end

function T.build(K)
  local col = K.col
  local UP = v3(0, 1, 0)
  local pos, right, W, N = K.pos, K.right, K.W, K.N
  local function rnd(a, b) return K.g:range(a, b) end
  local EDGE = K.WALL_T + 1          -- the road's own margin: nothing of the kit's nearer its edge

  local WHITE, BLACK = col(0.95, 0.95, 0.92), col(0.04, 0.04, 0.04)
  local CONC, CONC2, CONC3 = col(0.66, 0.66, 0.63), col(0.52, 0.52, 0.5), col(0.4, 0.4, 0.4)
  local YEL, STEEL, STEEL2 = col(0.98, 0.78, 0.04), col(0.55, 0.58, 0.6), col(0.75, 0.77, 0.78)
  local RED, GREEN, BLUE, ORANGE = col(0.88, 0.08, 0.05), col(0.05, 0.6, 0.2), col(0.06, 0.25, 0.8), col(0.98, 0.45, 0.04)
  local GLASS, TYRE, LAMP, REAR = col(0.1, 0.18, 0.3), col(0.05, 0.05, 0.06), col(1, 0.98, 0.8), col(0.8, 0.05, 0.05)
  local LIT = col(0.98, 0.85, 0.4)
  local LVC = {RED, ORANGE, col(0.1, 0.65, 0.25), col(0.05, 0.6, 0.65), BLUE, col(0.55, 0.15, 0.8), col(0.95, 0.3, 0.6),
    col(0.35, 0.75, 0.1)}
  local CARS = {RED, BLUE, col(0.9, 0.9, 0.88), col(0.1, 0.1, 0.12), col(0.6, 0.62, 0.65), col(0.98, 0.8, 0.05),
    col(0.1, 0.5, 0.2), ORANGE, col(0.05, 0.6, 0.65), col(0.5, 0.1, 0.5), col(0.5, 0.05, 0.08), col(0.3, 0.6, 0.95),
    col(0.95, 0.5, 0.7), col(0.75, 0.7, 0.55)}
  local TOWN = {col(0.62, 0.3, 0.22), col(0.8, 0.74, 0.6), col(0.5, 0.55, 0.62), col(0.7, 0.7, 0.68), col(0.72, 0.45, 0.3),
    col(0.4, 0.45, 0.5), col(0.85, 0.8, 0.72)}

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
  -- A tapered box: a, d the bottom's half-vectors at cen, the top `h` up, its halves scaled by fa, fd.
  local function taper(root, c, cen, a, d, h, fa, fd)
    local t = cen + UP * h
    local a2, d2 = a * fa, d * fd
    K.hexa(piece(root, c, c), cen - a - d, cen + a - d, cen + a + d, cen - a + d, t - a2 - d2, t + a2 - d2, t + a2 + d2, t - a2 + d2)
  end
  -- A round bar from p0 to p1, n-sided.
  local function cyl(root, c, p0, p1, r, n, key)
    local d = normalize(p1 - p0)
    local e1 = cross(d, UP)
    if length(e1) < 0.05 then e1 = cross(d, v3(1, 0, 0)) end
    e1 = normalize(e1)
    local e2 = normalize(cross(d, e1))
    local rings = {}
    for j, p in ipairs({p0, p1}) do
      local ring = {}
      for k = 0, n - 1 do
        local a = (k + 0.5) / n * math.pi * 2
        ring[#ring + 1] = p + e1 * (math.cos(a) * r) + e2 * (math.sin(a) * r)
      end
      rings[j] = ring
    end
    K.prism(piece(root, key or c), rings, K.flat(c), c, c)
  end
  -- A banded bar: a rectangle (half-vectors a, b) swept through the points pts, band j coloured cols[j].
  local function banded(root, key, pts, a, b, cols)
    local rings = {}
    for j, p in ipairs(pts) do rings[j] = {p - a - b, p + a - b, p + a + b, p - a + b} end
    K.prism(piece(root, key), rings, function(j, _) return cols[(j - 1) % #cols + 1] end, cols[1], cols[(#pts - 2) % #cols + 1])
  end
  -- A viewer looking along v has this to their right.
  local function rightof(v) return normalize(v3(-v.z, 0, v.x)) end

  -- Block letters, three by five: each row's runs a box. Centred on cen, reading along xd, px a block, proud by n.
  local FONT = {
    L = "100100100100111", E = "111100111100111", V = "101101101101010", X = "101101010101101", I = "111010010010111",
    T = "111010010010010", P = "111101111100100", m = "000000111111101", ["."] = "000000000000010",
    ["0"] = "111101101101111", ["1"] = "010110010010111", ["2"] = "111001111100111", ["3"] = "111001111001111",
    ["4"] = "101101111001001", ["5"] = "111100111001111", ["6"] = "111100111101111", ["7"] = "111001001001001",
    ["8"] = "111101111101111", ["9"] = "111101111001111", [" "] = "000000000000000",
  }
  local function text(root, c, str, cen, xd, px, n, th)
    local q = piece(root, c, c)
    local wide = (#str * 4 - 1) * px
    local o = cen - xd * (wide / 2) + UP * (2.5 * px)
    th = th or 0.05
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

  -- ---------------------------------------------------------------- where
  local function off(x, z) local _, d = K.ground_d(x, z); return d - K.HW end   -- metres off the road's edge
  local function clear(x, z, m) return off(x, z) > EDGE + (m or 0.3) end
  local function level(y) return math.floor(y / LH + 0.5) end
  local function lvc(l) return LVC[l % #LVC + 1] end
  -- A point d off the road's edge at sample i, on the ground.
  local function beside(i, side, d)
    local p = pos[i] + right[i] * (side * (W[i] + d))
    return v3(p.x, K.ground(p.x, p.z), p.z)
  end

  -- ---------------------------------------------------------------- pillars, posts, bollards
  -- A square concrete pillar: a yellow and black base, a band of its level's colour, up to y = top.
  local function pillar(root, b, u, w, half, top, band, body)
    local a, d = u * half, w * half
    body = body or CONC
    local ys = {-0.6, 0.4, 0.75, 1.1, 1.45, 3.0, 3.6}
    local pts = {}
    for j, y in ipairs(ys) do pts[j] = b + UP * y end
    pts[#pts + 1] = v3(b.x, top, b.z)
    banded(root, band, pts, a, d, {YEL, BLACK, YEL, BLACK, body, band, body})
  end
  for i = 6, N - 4, 12 do
    for side = -1, 1, 2 do
      local b = beside(i, side, EDGE + 1.3)
      if clear(b.x, b.z, 0.75) then
        local top = pos[i].y + 7.6
        pillar(K.solid, b, K.along(i), right[i], 0.42, top, lvc(level(pos[i].y)))
        obox(K.solid, CONC2, v3(b.x, top + 0.14, b.z), K.along(i) * 0.6, UP * 0.15, right[i] * 0.6)
      end
    end
  end
  -- Strip lights: a post with a tube along the road on top; CCTV: a post with a white camera looking at the road.
  local nl = 0
  for i = 12, N - 4, 12 do
    nl = nl + 1
    local side = (nl % 2 == 0) and 1 or -1
    local b = beside(i, side, EDGE + 0.9)
    if clear(b.x, b.z, 0.5) then
      local u, w = K.along(i), right[i] * side
      if nl % 4 == 0 then
        local top = b + UP * 4.6
        obox(K.solid, STEEL, b + UP * 2.1, u * 0.07, UP * 2.6, w * 0.07)
        local dir = normalize(w * -1 + UP * -0.45)
        local e2 = normalize(cross(dir, u))
        local cc = top + w * 0.05 + UP * 0.12
        obox(K.deco, WHITE, cc, u * 0.13, e2 * 0.11, dir * 0.3)
        obox(K.deco, BLACK, cc + dir * 0.31, u * 0.09, e2 * 0.08, dir * 0.03)
        obox(K.deco, WHITE, cc + e2 * -0.13 + dir * 0.06, u * 0.16, e2 * 0.02, dir * 0.38)
      else
        obox(K.solid, STEEL, b + UP * 2.3, u * 0.07, UP * 2.9, w * 0.07)
        obox(K.deco, LAMP, b + UP * 5.24, u * 1.3, UP * 0.08, w * 0.1)
        obox(K.deco, CONC3, b + UP * 5.37, u * 1.4, UP * 0.04, w * 0.2)
      end
    end
  end
  -- Bollards, in runs.
  for i = 8, N - 6, 2 do
    local m = i % 62
    if m >= 20 and m <= 36 then
      for side = -1, 1, 2 do
        local b = beside(i, side, EDGE + 0.5)
        if clear(b.x, b.z, 0.3) then
          local rings = {}
          for j, y in ipairs({-0.3, 0.55, 0.75, 1.0}) do rings[j] = K.ring(b + UP * y, 0.14, 0.14, 6, 0) end
          K.prism(piece(K.solid, "bollard"), rings, function(j, _) return (j == 2) and BLACK or YEL end, YEL, YEL)
        end
      end
    end
  end

  -- ---------------------------------------------------------------- level boards
  -- Where each level begins: a board in the level's colour, LEVEL over its number, facing up the road.
  local last, ns = nil, 0
  for i = K.start + 6, K.fin - 10 do
    local l = level(pos[i].y)
    if l ~= last and i % 12 == 3 then
      last = l
      ns = ns + 1
      for _, side in ipairs((ns % 2 == 0) and {1, -1} or {-1, 1}) do
        local p1, p2 = beside(i, side, EDGE + 0.9), beside(i, side, EDGE + 5.3)
        local pm = (p1 + p2) * 0.5
        if clear(p1.x, p1.z, 0.6) and clear(p2.x, p2.z, 3) and clear(pm.x, pm.z, 2) then
          local t, r = K.along(i), right[i]
          local y0, y1 = pos[i].y + 1.5, pos[i].y + 5.9
          for _, p in ipairs({p1, p2}) do
            obox(K.solid, STEEL, v3(p.x, (p.y - 0.5 + y1) / 2, p.z), r * 0.1, UP * ((y1 - p.y + 0.5) / 2), t * 0.1)
          end
          local c = v3(pm.x, (y0 + y1) / 2, pm.z) - t * 0.16
          obox(K.deco, lvc(l), c, r * 2.5, UP * ((y1 - y0) / 2), t * 0.06)
          obox(K.deco, WHITE, c + UP * 0.72 + t * 0.005, r * 2.3, UP * 0.05, t * 0.07)
          text(K.deco, WHITE, "LEVEL", c + UP * 1.4 - t * 0.06, r, 0.2, t, 0.04)
          text(K.deco, WHITE, tostring(l), c - UP * 0.75 - t * 0.06, r, 0.48, t, 0.04)
          break
        end
      end
    end
  end

  -- ---------------------------------------------------------------- low-clearance gantries
  local function gantry(i, exit)
    local t, r = K.along(i), right[i]
    local p1, p2 = beside(i, -1, EDGE + 0.8), beside(i, 1, EDGE + 0.8)
    if not (clear(p1.x, p1.z, 0.45) and clear(p2.x, p2.z, 0.45)) then return false end
    local yb = pos[i].y + math.max(K.lift(i, 1), K.lift(i, -1)) + 6.7
    local band = exit and GREEN or YEL
    pillar(K.solid, p1, t, r, 0.28, yb + 0.6, band, STEEL)
    pillar(K.solid, p2, t, r, 0.28, yb + 0.6, band, STEEL)
    local c = v3(pos[i].x, yb, pos[i].z)
    local hw = W[i] + EDGE + 1.3
    if exit then
      obox(K.deco, GREEN, c + UP * 1.4 - t * 0.4, r * hw, UP * 1.4, t * 0.1)
      obox(K.deco, WHITE, c + UP * 0.2 - t * 0.41, r * (hw - 0.3), UP * 0.06, t * 0.11)
      obox(K.deco, WHITE, c + UP * 2.6 - t * 0.41, r * (hw - 0.3), UP * 0.06, t * 0.11)
      text(K.deco, WHITE, "EXIT", c + UP * 1.4 - t * 0.5, r, 0.4, t, 0.05)
      return true
    end
    local pts, n = {}, 13
    for k = 0, n do pts[#pts + 1] = c + UP * 0.3 + r * (hw * (k / n * 2 - 1)) end
    banded(K.deco, "beam", pts, t * 0.25, UP * 0.3, {YEL, BLACK})
    -- the hanging height bar, red and white, on two chains
    local bar = {}
    for k = 0, 8 do bar[#bar + 1] = c - UP * 0.32 + r * ((W[i] - 0.3) * (k / 8 * 2 - 1)) end
    banded(K.deco, "bar", bar, t * 0.07, UP * 0.07, {RED, WHITE})
    for s = -1, 1, 2 do
      obox(K.deco, STEEL, c - UP * 0.1 + r * (s * (W[i] - 1)), r * 0.02, UP * 0.17, t * 0.02)
    end
    -- the roundel: a red ring round white, 2.1m
    local rc = c + UP * 1.75
    cyl(K.deco, RED, rc - t * 0.2, rc - t * 0.08, 1.1, 14)
    cyl(K.deco, WHITE, rc - t * 0.24, rc - t * 0.05, 0.8, 14)
    text(K.deco, BLACK, "2.1m", rc - t * 0.25, r, 0.09, t, 0.02)
    obox(K.deco, STEEL, c + UP * 0.72, r * 0.08, UP * 0.14, t * 0.08)
    return true
  end
  local ng = 0
  for i = 45, N - 30, 60 do
    if i > K.start + 20 and math.abs(i - K.fin) > 25 then
      if gantry(i) or gantry(i + 4) or gantry(i - 4) then ng = ng + 1 end
    end
  end

  -- ---------------------------------------------------------------- cars, trolleys, machines
  local UPV = UP                     -- the up of the plot being built: its deck's slope
  local function car(c, f, s)
    local body = K.pick(CARS)
    local L = rnd(1.8, 2.2)
    if rnd(0, 1) < 0.14 then
      -- a van
      obox(K.solid, body, c + UPV * 1.2, s * 0.92, UPV * 0.9, f * (L * 1.08))
      obox(K.deco, GLASS, c + UPV * 1.6 + f * (L * 1.08), s * 0.8, UPV * 0.3, f * 0.03)
      obox(K.deco, BLACK, c + UPV * 0.45 + f * (L * 1.08), s * 0.9, UPV * 0.1, f * 0.05)
      L = L * 1.08
    else
      obox(K.solid, body, c + UPV * 0.58, s * 0.86, UPV * 0.3, f * L)
      local cf = c - f * (0.14 * L) + UPV * 0.85
      taper(K.deco, GLASS, cf, s * 0.8, f * (0.6 * L), 0.56, 0.82, 0.62)
      obox(K.deco, body, cf + UPV * 0.57, s * 0.67, UPV * 0.035, f * (0.38 * L))
      obox(K.deco, LAMP, c + UPV * 0.66 + f * L, s * 0.72, UPV * 0.07, f * 0.03)
    end
    obox(K.deco, REAR, c + UPV * 0.68 - f * L, s * 0.74, UPV * 0.07, f * 0.03)
    for _, e in ipairs({0.62, -0.62}) do
      local a = c + f * (e * L) + UPV * 0.31
      cyl(K.deco, TYRE, a - s * 0.9, a + s * 0.9, 0.31, 6)
    end
  end
  local HANDLES = {RED, BLUE, GREEN, ORANGE}
  local function trolley(c, f, s, hc)
    taper(K.deco, STEEL2, c + UPV * 0.5, s * 0.2, f * 0.3, 0.48, 1.35, 1.5)
    obox(K.deco, STEEL, c + UPV * 0.22, s * 0.2, UPV * 0.03, f * 0.42)
    obox(K.deco, STEEL, c + UPV * 0.36 - f * 0.3, s * 0.03, UPV * 0.15, f * 0.03)
    obox(K.deco, TYRE, c + UPV * 0.08 + f * 0.34, s * 0.22, UPV * 0.07, f * 0.06)
    obox(K.deco, TYRE, c + UPV * 0.08 - f * 0.34, s * 0.22, UPV * 0.07, f * 0.06)
    obox(K.deco, hc or K.pick(HANDLES), c + UPV * 1.03 - f * 0.5, s * 0.28, UPV * 0.035, f * 0.04)
  end
  local function stray(c)
    local a = rnd(0, 6.28)
    local f = v3(math.cos(a), 0, math.sin(a))
    f = normalize(f - UPV * dot(f, UPV))
    trolley(c, f, normalize(cross(UPV, f)))
  end
  -- A pay machine facing f: a yellow cabinet, a screen, a blue P over it.
  local function paymachine(c, f)
    f = normalize(v3(f.x, 0, f.z))
    local s = rightof(f * -1)
    obox(K.solid, YEL, c + UP * 0.9, s * 0.45, UP * 1.0, f * 0.3)
    obox(K.deco, GLASS, c + UP * 1.4 + f * 0.3, s * 0.28, UP * 0.2, f * 0.02)
    obox(K.deco, STEEL, c + UP * 0.95 + f * 0.3, s * 0.2, UP * 0.1, f * 0.03)
    obox(K.deco, BLACK, c + UP * 0.6 + f * 0.3, s * 0.25, UP * 0.06, f * 0.025)
    obox(K.deco, STEEL, c + UP * 2.1, s * 0.05, UP * 0.25, f * 0.05)
    obox(K.deco, BLUE, c + UP * 2.95, s * 0.65, UP * 0.65, f * 0.07)
    text(K.deco, WHITE, "P", c + UP * 2.95 + f * 0.07, s, 0.2, f, 0.03)
    text(K.deco, WHITE, "P", c + UP * 2.95 - f * 0.07, s * -1, 0.2, f, 0.03)
  end

  -- ---------------------------------------------------------------- the decks' plots
  local taken = {}
  local function free(x, z, R)
    for _, t in ipairs(taken) do
      local dx, dz = t[1] - x, t[2] - z
      if dx * dx + dz * dz < (t[3] + R) * (t[3] + R) then return false end
    end
    return true
  end
  local AROUND = {{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}}
  -- A flat plot on a deck beside sample i: a along the road by b out (half sizes), its near side d0 off the edge. The
  -- deck is level a grid cell (5 m) round it, so everything on it stands on the ground as drawn.
  -- The valley as drawn: its grid's vertices (5 m apart), and a height between them (and how twisted the cell is).
  local HC = {}
  local function vh(gx, gz)
    local k = gx * 4096 + gz
    local y = HC[k]
    if not y then y = K.ground(K.X0 + gx * 5, K.Z0 - gz * 5); HC[k] = y end
    return y
  end
  local function mh(x, z)
    local fx, fz = (x - K.X0) / 5, (K.Z0 - z) / 5
    local gx, gz = math.floor(fx), math.floor(fz)
    local tx, tz = fx - gx, fz - gz
    local y00, y10, y01, y11 = vh(gx, gz), vh(gx + 1, gz), vh(gx, gz + 1), vh(gx + 1, gz + 1)
    return y00 * (1 - tx) * (1 - tz) + y10 * tx * (1 - tz) + y01 * (1 - tx) * tz + y11 * tx * tz, math.abs(y00 + y11 - y10 - y01)
  end
  -- A plot on a deck beside sample i: a along the road by b out (half sizes), its near side d0 off the edge; the
  -- deck there one plane as drawn (it slopes with the road), which everything on the plot stands square to.
  local function plot(i, side, d0, a, b)
    local u, w = K.along(i), right[i] * side
    local c = pos[i] + w * (W[i] + d0 + b)
    if not free(c.x, c.z, 2.4) then return nil end
    local function gy(du, dw)
      local p = c + u * du + w * dw
      return mh(p.x, p.z)
    end
    local yu0, yu1, yw0, yw1 = gy(-a, 0), gy(a, 0), gy(0, -b), gy(0, b)
    local y0 = (yu0 + yu1 + yw0 + yw1) / 4
    local su, sw = (yu1 - yu0) / (2 * a), (yw1 - yw0) / (2 * b)
    if math.abs(su) > 0.4 or math.abs(sw) > 0.25 then return nil end
    if math.abs(gy(0, 0) - y0) > 0.1 then return nil end
    for _, m in ipairs(AROUND) do
      local du, dw = m[1] * (a + 0.4), m[2] * (b + 0.6)
      local y, tw = gy(du, dw)
      if tw > 0.5 or math.abs(y - (y0 + su * du + sw * dw)) > 0.14 then return nil end
      if m[2] < 0 then
        local p = c + u * du + w * dw
        if off(p.x, p.z) < 9 then return nil end
      end
    end
    taken[#taken + 1] = {c.x, c.z, 2.4}
    local U, Wv = normalize(u + UP * su), normalize(w + UP * sw)
    local n = normalize(cross(U, Wv))
    if n.y < 0 then n = n * -1 end
    return {c = v3(c.x, y0, c.z), u = U, w = Wv, n = n, fu = u, fw = w, a = a, b = b, l = level(y0 + 0.5),
      slots = math.floor(a / 1.25 + 0.5), steep = math.abs(su) > 0.2 or math.abs(sw) > 0.12}
  end
  -- A thin flat stripe on the deck from p0 to p1.
  local function stripe(c, p0, p1, hw)
    local d = (p1 - p0) * 0.5
    local e = normalize(cross(d, UPV)) * hw
    obox(K.deco, c, (p0 + p1) * 0.5 + UPV * 0.025, e, UPV * 0.03, d)
  end
  local nrow, ncar = 0, 0
  -- A row: three bays between white lines, cars in most, and a yellow hatched box at one end with something in it.
  local function bays(s)
    nrow = nrow + 1
    local c, u, w = s.c, s.u, s.w
    local n = s.slots
    local flip = (nrow % 2 == 0) and 1 or -1         -- the hatched end
    local hs = (n >= 3) and ((flip > 0) and (n - 1) or 0) or -1
    for j = 0, n do
      local x = (j - n / 2) * 2.5
      stripe(WHITE, c + u * x - w * 2.5, c + u * x + w * 2.5, 0.06)
    end
    for k = 0, n - 1 do
      local x = (k + 0.5 - n / 2) * 2.5
      if k == hs then
      elseif rnd(0, 1) < 0.72 then
        ncar = ncar + 1
        local f = w * ((rnd(0, 1) < 0.6) and -1 or 1)
        f = normalize(f + u * rnd(-0.05, 0.05))
        car(c + u * (x + rnd(-0.12, 0.12)) + w * rnd(-0.3, 0.3), f, normalize(cross(UPV, f)))
      elseif rnd(0, 1) < 0.35 then
        stray(c + u * (x + rnd(-0.6, 0.6)) + w * rnd(-1.5, 1.5))
      end
    end
    if hs < 0 then return end
    -- the hatched box: 2.5 by 5, its border and diagonals yellow
    local h0 = c + u * ((hs + 0.5 - n / 2) * 2.5)
    stripe(YEL, h0 - u * 1.1 - w * 2.42, h0 + u * 1.1 - w * 2.42, 0.06)
    stripe(YEL, h0 - u * 1.1 + w * 2.42, h0 + u * 1.1 + w * 2.42, 0.06)
    stripe(YEL, h0 + u * (flip * 1.12) - w * 2.3, h0 + u * (flip * 1.12) + w * 2.3, 0.06)
    for k = 0, 3 do
      local z0 = -2.3 + k * 1.15
      stripe(YEL, h0 - u * 1.0 + w * z0, h0 + u * 1.0 + w * (z0 + 1.1), 0.09)
    end
    local kind = nrow % 4
    if kind == 0 then
      local top = c.y + 7.4
      pillar(K.solid, h0, s.fu, s.fw, 0.45, top, lvc(s.l))
      obox(K.solid, CONC2, v3(h0.x, top + 0.14, h0.z), s.fu * 0.65, UP * 0.15, s.fw * 0.65)
    elseif kind == 1 then
      stray(h0 + u * rnd(-0.4, 0.4) + w * rnd(-1.5, 1.5))
      stray(h0 + u * rnd(-0.4, 0.4) + w * rnd(-1.5, 1.5))
    elseif kind == 2 then
      obox(K.solid, STEEL, h0 + UP * 2.4, s.fu * 0.07, UP * 2.9, s.fw * 0.07)
      obox(K.deco, LAMP, h0 + UP * 5.34, s.fu * 0.1, UP * 0.08, s.fw * 1.3)
      obox(K.deco, CONC3, h0 + UP * 5.47, s.fu * 0.2, UP * 0.04, s.fw * 1.4)
    end
  end
  -- A parapet behind a plot: a low concrete wall with a steel rail.
  local function parapet(s, gap)
    local m = s.c + s.w * (s.b + (gap or 0.8))
    local L = s.a + 0.25
    obox(K.solid, CONC, m + UPV * 0.3, s.u * L, UPV * 0.8, s.w * 0.14)
    obox(K.deco, STEEL, m + UPV * 1.28, s.u * L, UPV * 0.04, s.w * 0.05)
    for k = -1, 1 do obox(K.deco, STEEL, m + UPV * 1.17 + s.u * (k * (L - 0.3)), s.u * 0.04, UPV * 0.08, s.w * 0.04) end
  end
  -- A lift tower: a tall concrete shaft, steel doors in an orange frame, a strip of glass, a band of the level's
  -- colour with a P, a machine room's lid, and a lower stair block beside it.
  local function tower(s)
    local c, u, w = s.c, s.fu, s.fw
    local H = 15 + rnd(0, 4)
    obox(K.solid, CONC, c + UP * (H / 2 - 1.5), u * 2.3, UP * (H / 2 + 1.5), w * 2.3)
    obox(K.deco, CONC3, c + UP * (H + 0.3), u * 2.6, UP * 0.3, w * 2.6)
    obox(K.deco, lvc(s.l), c + UP * (H - 2.2), u * 2.34, UP * 0.9, w * 2.34)
    obox(K.deco, ORANGE, c - w * 2.3 + UP * 1.25, u * 1.3, UP * 1.3, w * 0.06)
    obox(K.deco, STEEL2, c - w * 2.37 + UP * 1.1 + u * 0.54, u * 0.5, UP * 1.1, w * 0.03)
    obox(K.deco, STEEL2, c - w * 2.37 + UP * 1.1 - u * 0.54, u * 0.5, UP * 1.1, w * 0.03)
    obox(K.deco, GLASS, c - w * 2.3 + UP * (H / 2 + 0.4), u * 0.6, UP * (H / 2 - 3.4), w * 0.05)
    local xr = rightof(w)
    text(K.deco, WHITE, "P", c - w * 2.36 + UP * (H - 2.2), xr, 0.3, w, 0.04)
    text(K.deco, WHITE, "P", c + w * 2.36 + UP * (H - 2.2), xr * -1, 0.3, w, 0.04)
    text(K.deco, WHITE, "P", c + u * 2.36 + UP * (H - 2.2), rightof(u * -1), 0.3, u, 0.04)
    text(K.deco, WHITE, "P", c - u * 2.36 + UP * (H - 2.2), rightof(u), 0.3, u, 0.04)
    -- the stairs
    if s.slots >= 4 then
      local sc = c + u * 3.5
      obox(K.solid, CONC2, sc + UP * 4.2, u * 1.15, UP * 6.7, w * 1.9)
      for k = 0, 2 do obox(K.deco, GLASS, sc - w * 1.9 + UP * (2.6 + k * 3.2), u * 0.8, UP * 0.5, w * 0.04) end
    end
    paymachine(c - u * 3.1 - w * 1.4, w * -1)
  end
  -- A trolley shelter: two lanes of nested trolleys under a blue lid on four posts, and a pay machine by it.
  local function shelter(s)
    local c, u, w = s.c - s.u * 2.4, s.u, s.w
    for _, e in ipairs({{-1.25, -2.2}, {1.25, -2.2}, {1.25, 2.2}, {-1.25, 2.2}}) do
      obox(K.solid, STEEL, c + u * e[1] + w * e[2] + UPV * 1.1, u * 0.05, UPV * 1.25, w * 0.05)
    end
    obox(K.deco, col(0.3, 0.6, 0.9), c + UPV * 2.4, u * 1.45, UPV * 0.05, w * 2.45)
    for sd = -1, 1, 2 do
      obox(K.deco, STEEL, c + u * (sd * 1.25) + UPV * 0.55, u * 0.03, UPV * 0.03, w * 2.15)
      local hc = HANDLES[(nrow + sd + 1) % #HANDLES + 1]
      local n = 5 + math.floor(rnd(0, 3))
      for k = 0, n - 1 do trolley(c + u * (sd * 0.55) + w * (1.6 - k * 0.33), w * -1, u, hc) end
    end
    paymachine(s.c + u * 1.2 - w * 0.5, w * -1)
    stray(s.c + u * 3.2 + w * 1.2)
    stray(s.c + u * 2.6 - w * 1.6)
    stray(s.c + u * 4.2 - w * 0.3)
  end

  -- Each level's run of the road, in pieces of about 14 m: either side, rows of as many bays as lie flat there.
  local np, ntow, nshel = 0, 0, 0
  local TKEEP = 0.55
  local wantT, wantS = false, false
  local function fill(s)
    np = np + 1
    if np % 18 == 3 then wantT = true end
    if np % 18 == 12 then wantS = true end
    UPV = s.n
    if wantT and s.slots >= 3 and not s.steep then
      tower(s); ntow = ntow + 1; wantT = false
    elseif wantS and s.slots >= 4 then
      shelter(s); nshel = nshel + 1; wantS = false
    else
      bays(s)
    end
  end
  local function piece_at(i, len)
    for side = -1, 1, 2 do
      local outer
      for _, d0 in ipairs({11, 16.6}) do
        local s
        for n = math.min(5, math.floor(len / 2.5)), 2, -1 do
          s = plot(i, side, d0, n * 1.25, 2.5)
          if s then break end
        end
        if s then
          fill(s)
          outer = s
        end
      end
      if outer then UPV = outer.n; parapet(outer) end
    end
  end
  -- The terraces: two rows of bays along each, one nosed up to the bank and one along the drop behind a parapet,
  -- an aisle between them -- those within sight of the road, most of them.
  local nter = 0
  for t = math.ceil(-K.Z0 / TB), math.floor(-K.Z1 / TB) - 1 do
    local ty = terrace(-t * TB - 1)
    for row = 1, 2 do
      local zc = (row == 1) and (-t * TB - 2.8) or (-t * TB - 12.2)
      local w = v3(0, 0, (row == 1) and 1 or -1)
      local u = v3(1, 0, 0)
      local x = K.X0 + 7 + (t % 3) * 2.5
      while x < K.X1 - 20 do
        local n = 3 + math.floor(rnd(0, 2.99))
        local a = n * 1.25
        local cx = x + a
        local ok = off(cx, zc) < 50
        if ok then
          for _, m in ipairs({{0, 0}, {-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do
            if math.abs(mh(cx + m[1] * (a + 0.2), zc + m[2] * 2.6) - ty) > 0.03 then ok = false; break end
          end
        end
        if ok and rnd(0, 1) < TKEEP then
          nter = nter + 1
          local s = {c = v3(cx, ty, zc), u = u, w = w, n = UP, fu = u, fw = w, a = a, b = 2.5, l = level(ty + 0.5), slots = n, steep = false}
          fill(s)
          if row == 2 then UPV = UP; parapet(s, 0.2) end
        end
        x = x + 2 * a + 0.6
      end
    end
  end
  for i = 10, N - 6, 12 do piece_at(i, 13) end

  -- ---------------------------------------------------------------- the edge, and the town beyond
  local X0, X1, Z0, Z1 = K.X0, K.X1, K.Z0, K.Z1
  local function wallrun(ax, az, bx, bz)
    local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
    local n = math.floor(len / 5 + 0.5)
    local d = normalize(v3(bx - ax, 0, bz - az))
    local e = rightof(d)
    for k = 0, n - 1 do
      local p, q = v3(ax, 0, az) + d * (k * 5 + 0.03), v3(ax, 0, az) + d * (k * 5 + 4.97)
      local y0, y1 = K.ground(p.x, p.z), K.ground(q.x, q.z)
      local lo, hi = math.min(y0, y1) - 1.5, math.max(y0, y1) + 1.2 + 0.001 * (k % 7)
      obox(K.deco, CONC, v3((p.x + q.x) / 2, (lo + hi) / 2, (p.z + q.z) / 2), d * 2.47, UP * ((hi - lo) / 2), e * 0.2)
    end
  end
  wallrun(X0 + 0.5, Z0 - 0.5, X1 - 0.5, Z0 - 0.5)
  wallrun(X1 - 0.5, Z0 - 0.5, X1 - 0.5, Z1 + 0.5)
  wallrun(X1 - 0.5, Z1 + 0.5, X0 + 0.5, Z1 + 0.5)
  wallrun(X0 + 0.5, Z1 + 0.5, X0 + 0.5, Z0 - 0.5)
  -- The town: blocks of flats and offices past the parapet, bands of windows (some lit) round their top floors.
  local nb = 0
  local function block(x, z, top, hx, hz)
    nb = nb + 1
    local wall = K.pick(TOWN)
    local seed = nb
    local floors = 3
    local ys = {-20}
    local yb = top - 1 - floors * 3.4
    for k = 0, floors - 1 do
      ys[#ys + 1] = yb + k * 3.4
      ys[#ys + 1] = yb + k * 3.4 + 2
    end
    ys[#ys + 1] = top
    local pts = {}
    for j, y in ipairs(ys) do pts[j] = v3(x, y, z) end
    local rings = {}
    for j, p in ipairs(pts) do
      rings[j] = {p + v3(-hx, 0, -hz), p + v3(hx, 0, -hz), p + v3(hx, 0, hz), p + v3(-hx, 0, hz)}
    end
    K.prism(piece(K.deco, wall), rings, function(j, k)
      if j % 2 == 1 then return wall end
      return (h2(seed * 7 + j, k) < 0.3) and LIT or GLASS
    end, wall, CONC3)
    if nb % 3 == 0 then
      obox(K.deco, CONC3, v3(x + hx * 0.2, top + 1.2, z - hz * 0.1), v3(hx * 0.4, 0, 0), UP * 1.25, v3(0, 0, hz * 0.4))
    end
  end
  local function town(ax, az, bx, bz, ox, oz)
    local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
    local t = 0
    while t < len - 8 do
      local hx = rnd(5, 9)
      local f = (t + hx) / len
      local x, z = ax + (bx - ax) * f, az + (bz - az) * f
      local g = K.ground(math.max(X0 + 1, math.min(X1 - 1, x)), math.max(Z1 + 1, math.min(Z0 - 1, z)))
      local out = rnd(11, 20)
      block(x + ox * out, z + oz * out, math.max(8, g + rnd(-24, 7)), (ox ~= 0) and rnd(5, 8) or hx, (ox ~= 0) and hx or rnd(5, 8))
      if rnd(0, 1) < 0.6 then
        local out2 = out + rnd(22, 40)
        block(x + ox * out2 + oz * rnd(-4, 4), z + oz * out2 + ox * rnd(-4, 4), math.max(16, g + rnd(-12, 26)), rnd(6, 10), rnd(6, 10))
      end
      t = t + hx * 2 + rnd(2, 7)
    end
  end
  town(X0, Z0, X1, Z0, 0, 1)
  town(X1, Z0, X1, Z1, 1, 0)
  town(X1, Z1, X0, Z1, 0, -1)
  town(X0, Z1, X0, Z0, -1, 0)

  -- ---------------------------------------------------------------- the way out
  -- Past the finish: a green EXIT board over the road, a raised barrier and a pay booth beside it.
  local ie = math.min(N - 4, K.fin + 15)
  local okx = gantry(ie, true) or gantry(ie - 3, true)
  local ib = ie - 7
  for side = -1, 1, 2 do
    local b = beside(ib, side, EDGE + 1.7)
    if clear(b.x, b.z, 1.3) then
      local u, w = K.along(ib), right[ib] * side
      obox(K.solid, ORANGE, b + UP * 0.35, u * 0.25, UP * 0.75, w * 0.25)
      local dir = normalize(UP - w * 0.22)
      local e1 = u
      local e2 = normalize(cross(dir, e1))
      local pts = {}
      for k = 0, 8 do pts[#pts + 1] = b + UP * 1.0 + dir * (k * 0.5 + 0.02) end
      banded(K.deco, "boom", pts, e1 * 0.05, e2 * 0.07, {RED, WHITE})
    end
  end
  local bb = beside(ib, 1, EDGE + 4.2)
  if clear(bb.x, bb.z, 3) then
    local u, w = K.along(ib), right[ib]
    obox(K.solid, WHITE, bb + UP * 1.0, u * 1.3, UP * 1.4, w * 1.0)
    obox(K.deco, GLASS, bb + UP * 1.6, u * 1.32, UP * 0.45, w * 1.02)
    obox(K.deco, BLUE, bb + UP * 2.5, u * 1.5, UP * 0.1, w * 1.2)
  end

  info(string.format("carpark: %d plots (%d on terraces; %d cars, %d towers, %d shelters), %d gantries, %d level boards, %d town blocks, exit %s",
    np, nter, ncar, ntow, nshel, ng, ns, nb, tostring(okx)))
end

return T
