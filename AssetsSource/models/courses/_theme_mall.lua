-- The shopping centre's scenery kit (see THEME KITS in _course.lua): a mall at night. Shopfronts with lit windows and
-- bright signs line both sides under a glass-railed gallery; escalators, tall atrium pillars carrying roof beams and
-- hanging sale banners, potted palms, cardboard displays, trolleys, benches, a map totem, fountains, and a food court
-- of kiosks, tables and chairs round the finish. No trees.
local T = {trees = 0}

-- A 3 x 5 block letter each, rows from the top.
local FONT = {
  A = {"010", "101", "111", "101", "101"}, B = {"110", "101", "110", "101", "110"}, C = {"011", "100", "100", "100", "011"},
  D = {"110", "101", "101", "101", "110"}, E = {"111", "100", "110", "100", "111"}, F = {"111", "100", "110", "100", "100"},
  G = {"011", "100", "101", "101", "011"}, H = {"101", "101", "111", "101", "101"}, I = {"111", "010", "010", "010", "111"},
  K = {"101", "101", "110", "101", "101"}, L = {"100", "100", "100", "100", "111"}, M = {"101", "111", "111", "101", "101"},
  N = {"110", "101", "101", "101", "101"}, O = {"111", "101", "101", "101", "111"}, P = {"110", "101", "110", "100", "100"},
  R = {"110", "101", "110", "101", "101"}, S = {"011", "100", "010", "001", "110"}, T = {"111", "010", "010", "010", "010"},
  U = {"101", "101", "101", "101", "111"}, Y = {"101", "101", "010", "010", "010"}, Z = {"111", "001", "010", "100", "111"},
  ["%"] = {"101", "001", "010", "100", "101"}, ["5"] = {"111", "100", "110", "001", "110"}, ["0"] = {"111", "101", "101", "101", "111"},
}

function T.build(K)
  local UP = v3(0, 1, 0)
  local col, g = K.col, K.g
  local N, pos, right, W = K.N, K.pos, K.right, K.W
  local solid, deco = K.solid, K.deco

  local WHITE, DARK, BLACK = col(0.95, 0.95, 0.92), col(0.05, 0.05, 0.07), col(0.015, 0.015, 0.02)
  local STEEL, GLASS = col(0.45, 0.48, 0.52), col(0.45, 0.8, 0.92)
  local WARM, COOL = col(1, 0.82, 0.4), col(0.7, 0.92, 1)
  local PILLAR, PILLAR_B, BEAM = col(0.82, 0.78, 0.68), col(0.3, 0.28, 0.26), col(0.1, 0.11, 0.14)
  local FLOOR_C = col(0.6, 0.58, 0.54)
  local POT, SOIL, TRUNK = col(0.9, 0.88, 0.82), col(0.12, 0.07, 0.04), col(0.4, 0.24, 0.1)
  local PALM1, PALM2 = col(0.1, 0.5, 0.12), col(0.2, 0.68, 0.15)
  local CARD, CARD2, WOOD = col(0.62, 0.42, 0.2), col(0.5, 0.32, 0.14), col(0.5, 0.26, 0.08)
  local STONE, WATER, FOAM = col(0.7, 0.7, 0.72), col(0.1, 0.5, 0.95), col(0.8, 0.93, 1)
  local RED, YELLOW = col(0.9, 0.04, 0.04), col(1, 0.8, 0.05)
  local NEON = {col(1, 0.08, 0.45), col(0.05, 0.8, 1), YELLOW, col(0.4, 1, 0.1), col(1, 0.35, 0.02),
    col(0.75, 0.08, 0.95), RED, col(0.1, 0.3, 1)}
  local BODY = {col(0.05, 0.07, 0.2), col(0.17, 0.05, 0.16), col(0.09, 0.09, 0.11), col(0.04, 0.15, 0.17), col(0.2, 0.1, 0.05)}
  local SHOPS = {"TOYS", "SHOES", "BOOKS", "GAMES", "TECH", "SPORT", "PETS", "MUSIC", "GIFTS", "OPTIC", "BIKES", "HATS", "ZOOM"}
  local FOOD = {"PIZZA", "SUSHI", "CAFE", "TACOS", "CHIPS", "BURGER"}

  -- A piece of builder b for colour c, inked.
  local function S(b, c)
    local q = K.sub(b, c)
    q.ink = c
    return q
  end
  -- A box: bottom centre `base`, w along ax, h up, d along n.
  local function ob(b, c, base, ax, n, w, h, d)
    K.road_box(S(b, c), base + v3(0, h / 2, 0), ax, n, w, h, d)
  end
  local function pole(b, c, x, z, y0, y1, r0, r1, n, turn)
    K.column(S(b, c), x, z, y0, y1, r0, r1, n, c, turn)
  end
  -- An upright disc facing n: centre ctr, from t0 to t1 along n.
  local function disc(b, c, ctr, ax, n, rad, sides, t0, t1)
    local function rg(o)
      local out = {}
      for k = 0, sides - 1 do
        local a = k / sides * math.pi * 2
        out[#out + 1] = ctr + ax * (math.cos(a) * rad) + UP * (math.sin(a) * rad) + n * o
      end
      return out
    end
    K.prism(S(b, c), {rg(t0), rg(t1)}, K.flat(c), c, c)
  end
  -- Block letters on a face whose outward normal is n, centred on `at` (a point on the face); ax = cross(UP, n) is
  -- the reader's left to right. `vertical` stacks the letters downwards.
  local function text(b, c, at, n, cell, word, vertical)
    local q = S(b, c)
    local ax = normalize(cross(UP, n))
    local len = #word
    local tw = vertical and 3 * cell or (4 * len - 1) * cell
    local th = vertical and (6 * len - 1) * cell or 5 * cell
    for l = 1, len do
      local gl = FONT[word:sub(l, l)]
      if gl then
        local ox = vertical and 0 or (l - 1) * 4 * cell
        local oy = vertical and (l - 1) * 6 * cell or 0
        for rr = 1, 5 do
          local row = gl[rr]
          local a = nil
          for cx = 1, 4 do
            local on = cx <= 3 and row:sub(cx, cx) == "1"
            if on and not a then a = cx end
            if not on and a then
              local x0, x1 = (a - 1) * cell, (cx - 1) * cell
              local ctr = at + ax * (ox + (x0 + x1) / 2 - tw / 2) + UP * (th / 2 - oy - (rr - 0.5) * cell)
              K.slab(q, ctr - n * 0.06, ctr + n * 0.07, ax * ((x1 - x0) / 2 - 0.004), UP * (cell * 0.46))
              a = nil
            end
          end
        end
      end
    end
  end

  -- Sample i's frame on a side: r out from the road, t down it; P a point d off the road's edge and a along it, on
  -- the ground; off() how far a point is off the road's edge.
  local function frame(i, side) return right[i] * side, K.along(i) end
  local function P(i, side, d, a)
    local r, t = frame(i, side)
    local p = pos[i] + r * (W[i] + d) + t * (a or 0)
    return v3(p.x, K.ground(p.x, p.z), p.z)
  end
  local function grounded(p) return v3(p.x, K.ground(p.x, p.z), p.z) end
  local function off(p)
    local _, d = K.ground_d(p.x, p.z)
    return d - K.HW
  end
  local function flatdist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) end
  local nth = 0
  local function nextof(list) nth = nth + 1; return list[(nth * 7) % #list + 1] end

  -- A potted indoor palm.
  local function palm(p, s)
    local x, y, z = p.x, p.y, p.z
    pole(solid, POT, x, z, y - 0.5, y + 0.9 * s, 0.9 * s, 1.1 * s, 8, 0.39)
    pole(deco, SOIL, x, z, y + 0.3, y + 0.9 * s + 0.05, 0.9 * s, 0.9 * s, 8, 0.39)
    local lean = v3(g:range(-0.4, 0.4), 0, g:range(-0.4, 0.4)) * s
    local h = 3.4 * s
    local base = v3(x, y + 0.8 * s, z)
    K.prism(S(deco, TRUNK), {K.ring(base, 0.24 * s, 0.24 * s, 6, 0), K.ring(base + lean * 0.6 + UP * (h * 0.55), 0.18 * s, 0.18 * s, 6, 0),
      K.ring(base + lean + UP * h, 0.13 * s, 0.13 * s, 6, 0)}, K.flat(TRUNK), TRUNK, TRUNK)
    local c = base + lean + UP * (h - 0.05)
    local a0 = g:range(0, 6.28)
    for k = 1, 8 do
      local a = a0 + k / 8 * math.pi * 2
      local dir, sd = v3(math.cos(a), 0, math.sin(a)), v3(-math.sin(a), 0, math.cos(a))
      local gc = (k % 2 == 0) and PALM1 or PALM2
      local L = (1.2 + (k % 2) * 0.25) * s
      local m = c + dir * L + UP * (0.55 * s)
      K.slab(S(deco, gc), c + dir * (0.1 + k * 0.012), m, sd * (0.3 * s), UP * 0.03)
      K.slab(S(deco, gc), m - dir * 0.06, c + dir * (L * 1.9) - UP * (0.4 * s), sd * (0.22 * s), UP * 0.025)
    end
  end

  -- A shop: two storeys, a lit window and a bright sign with its name, a gallery with a glass balustrade.
  local D0, DEP = 9.2, 6
  local function shop(i, side, w)
    local r = frame(i, side)
    local n = r * -1
    local ax = normalize(cross(UP, n))
    local F = P(i, side, D0)
    local fl, fr = grounded(F - ax * (w / 2)), grounded(F + ax * (w / 2))
    if off(fl) < 5 or off(fr) < 5 then return end
    local yf = math.max(fl.y, fr.y, F.y) + 0.1
    local ylow = math.min(fl.y, fr.y, F.y) - 0.6
    local H1, H2 = 4.5, 8.2 + g:range(0, 2)
    local body, sign, sign2 = nextof(BODY), nextof(NEON), nextof(NEON)
    local O = v3(F.x, yf, F.z)
    local function bx(b, c, u, y0, out0, wu, hy, dout)
      ob(b, c, O + ax * u + n * (out0 + dout / 2) + UP * y0, ax, n, wu, hy, dout)
    end
    bx(solid, body, 0, ylow - yf, -DEP, w, H2 - (ylow - yf), DEP)
    bx(deco, WARM, 0, 0.5, -0.1, w - 1.6, 2.3, 0.18)
    bx(deco, COOL, 0, 0.02, -0.1, 1.5, 2.75, 0.26)
    for s = -1, 1, 2 do
      bx(deco, DARK, s * (w - 1.6) * 0.3, 0.4, -0.1, 0.14, 2.5, 0.22)
      bx(deco, DARK, s * (w - 1.4) * 0.28, H1 + 0.5, -0.1, 0.14, 2.4, 0.22)
    end
    bx(deco, sign, 0, 3.0, -0.1, w - 0.5, 1.15, 0.4)
    local word = nextof(SHOPS)
    local ink = (sign == YELLOW or sign == NEON[4] or sign == NEON[2]) and BLACK or WHITE
    text(deco, ink, O + UP * 3.575 + n * 0.3, n, math.min(0.19, (w - 1.3) / (4 * #word - 1)), word)
    bx(deco, (nth % 2 == 0) and COOL or WARM, 0, H1 + 0.6, -0.1, w - 1.4, 2.2, 0.16)
    bx(deco, sign2, 0, H2 - 0.75, -0.1, w - 0.3, 0.4, 0.28)
    -- The gallery, when its front is clear of the road.
    local gl, gr = fl + n * 2.7, fr + n * 2.7
    if off(gl) >= 3.5 and off(gr) >= 3.5 then
      bx(solid, FLOOR_C, 0, H1 - 0.3, -0.2, w - 0.04, 0.3, 2.9)
      bx(deco, GLASS, 0, H1 - 0.05, 2.6, w - 0.2, 1.05, 0.06)
      bx(deco, STEEL, 0, H1 + 0.97, 2.55, w - 0.1, 0.08, 0.16)
      for s = -1, 1 do bx(deco, STEEL, s * (w / 2 - 0.15), H1 - 0.05, 2.57, 0.1, 1.04, 0.12) end
      for s = -1, 1, 2 do bx(solid, PILLAR, s * (w / 2 - 0.5), -2.2, 2.2, 0.32, H1 - 0.25 + 2.2, 0.32) end
    end
  end

  -- A food kiosk: a counter under a striped canopy, a big sign on its roof, some with a giant cup.
  local KD0 = 10.4
  local function kiosk(i, side, w)
    local r = frame(i, side)
    local n = r * -1
    local ax = normalize(cross(UP, n))
    local F = P(i, side, KD0)
    local fl, fr = grounded(F - ax * (w / 2)), grounded(F + ax * (w / 2))
    if off(fl) < 6 or off(fr) < 6 then return end
    local yf = math.max(fl.y, fr.y, F.y) + 0.1
    local ylow = math.min(fl.y, fr.y, F.y) - 0.6
    local accent, sign = nextof(NEON), nextof(NEON)
    local O = v3(F.x, yf, F.z)
    local function bx(b, c, u, y0, out0, wu, hy, dout)
      ob(b, c, O + ax * u + n * (out0 + dout / 2) + UP * y0, ax, n, wu, hy, dout)
    end
    bx(solid, WHITE, 0, ylow - yf, -4, w, 3.4 - (ylow - yf), 4)
    bx(deco, WARM, 0, 1.1, -0.1, w - 1.2, 1.35, 0.16)
    bx(solid, accent, 0, ylow - yf, -0.1, w - 0.4, 1.1 - (ylow - yf), 0.7)
    bx(deco, WHITE, 0, 2.55, -0.1, w + 0.3, 0.22, 1.5)
    local ns = math.max(2, math.floor(w / 1.6))
    local sw = (w + 0.3) / (ns * 2 - 1)
    for s = 0, ns - 1 do
      bx(deco, accent, -(w + 0.3) / 2 + sw * (2 * s + 0.5), 2.53, -0.08, sw, 0.26, 1.51)
    end
    bx(deco, sign, 0, 3.3, -0.7, w - 0.6, 1.6, 0.5)
    local word = nextof(FOOD)
    local ink = (sign == YELLOW or sign == NEON[4] or sign == NEON[2]) and BLACK or WHITE
    text(deco, ink, O + UP * 4.1 - n * 0.2, n, math.min(0.24, (w - 1.4) / (4 * #word - 1)), word)
    if nth % 2 == 0 then
      local c = O - n * 2.6 + ax * (w * 0.2)
      pole(deco, RED, c.x, c.z, yf + 3.3, yf + 5.5, 0.6, 0.9, 8, 0)
      pole(deco, WHITE, c.x, c.z, yf + 5.45, yf + 5.7, 0.98, 0.98, 8, 0)
      ob(deco, YELLOW, v3(c.x + 0.3, yf + 5.6, c.z), ax, n, 0.14, 1.3, 0.14)
    end
  end

  -- A pair of escalators up to a landing, along the road.
  local function escalator(i, side)
    local r, t = frame(i, side)
    local function cpt(d, a) return pos[i] + r * (W[i] + d) + t * a end
    if off(cpt(5.6, 4.6)) < 4 or off(cpt(5.6, -8.5)) < 4 or off(cpt(5.6, 0)) < 4 then return false end
    local yb = P(i, side, 7.4, 4.5).y
    local top = yb + 4.75
    for e = 0, 1 do
      local dC = 6.6 + e * 1.7
      local b0, t0 = cpt(dC, 4.5), cpt(dC, -4.5)
      local pB, pT = v3(b0.x, yb + 0.15, b0.z), v3(t0.x, top, t0.z)
      K.slab(S(solid, BEAM), pB, pT, r * 0.62, UP * 0.4)
      for s = 0, 11 do
        local p = lerp(pB, pT, (s + 0.5) / 12)
        ob(deco, (s % 2 == 0) and STEEL or YELLOW, p + UP * 0.3, r, t, 1.0, 0.3, 0.7)
      end
      for sg = -1, 1, 2 do
        K.slab(S(deco, GLASS), pB + r * (sg * 0.6) + UP * 0.9, pT + r * (sg * 0.6) + UP * 0.9, r * 0.04, UP * 0.55)
        K.slab(S(deco, BLACK), pB + r * (sg * 0.6) + UP * 1.5, pT + r * (sg * 0.6) + UP * 1.5, r * 0.08, UP * 0.07)
      end
      local m = P(i, side, dC, -1.5)
      pole(solid, PILLAR_B, m.x, m.z, m.y - 0.5, yb + 2.9, 0.22, 0.22, 6, 0)
    end
    local L = cpt(7.45, -6.4)
    ob(solid, FLOOR_C, v3(L.x, top - 0.3, L.z), r, t, 4.2, 0.35, 4.0)
    ob(deco, GLASS, v3(L.x, top, L.z) - r * 2.05, r, t, 0.06, 1.0, 3.9)
    ob(deco, GLASS, v3(L.x, top, L.z) - t * 1.95, r, t, 4.0, 1.0, 0.06)
    ob(deco, GLASS, v3(L.x, top, L.z) + r * 2.05, r, t, 0.06, 1.0, 3.9)
    for sg = -1, 1, 2 do
      local q = grounded(cpt(7.45 + sg * 1.6, -7.8))
      pole(solid, PILLAR, q.x, q.z, q.y - 0.5, top - 0.2, 0.25, 0.25, 6, 0)
    end
    -- A lit arrow board over the landing.
    local sgn = nextof(NEON)
    ob(deco, sgn, v3(L.x, top + 2.3, L.z) - t * 1.8, r, t, 3.6, 1.0, 0.2)
    ob(deco, PILLAR_B, v3(L.x, top, L.z) - t * 1.8 - r * 1.9, r, t, 0.12, 2.4, 0.12)
    ob(deco, PILLAR_B, v3(L.x, top, L.z) - t * 1.8 + r * 1.9, r, t, 0.12, 2.4, 0.12)
    return true
  end

  -- A fountain: a round stone basin, a bowl on a pedestal, jets.
  local function fountain(i, side)
    local c = P(i, side, 8.4)
    if off(c) < 7.5 then return false end
    local lo = P(i, side, 5).y
    local y = c.y
    pole(solid, STONE, c.x, c.z, lo - 0.5, y + 0.7, 3.2, 3.2, 12, 0)
    pole(deco, WATER, c.x, c.z, y + 0.3, y + 0.74, 2.8, 2.8, 12, 0)
    pole(solid, STONE, c.x, c.z, y + 0.5, y + 2.2, 0.5, 0.4, 8, 0)
    pole(deco, STONE, c.x, c.z, y + 2.0, y + 2.6, 0.45, 1.6, 10, 0)
    pole(deco, WATER, c.x, c.z, y + 2.3, y + 2.65, 1.35, 1.35, 10, 0)
    pole(deco, FOAM, c.x, c.z, y + 2.5, y + 5.2, 0.3, 0.05, 6, 0)
    for k = 1, 6 do
      local a = k / 6 * math.pi * 2
      pole(deco, FOAM, c.x + math.cos(a) * 1.9, c.z + math.sin(a) * 1.9, y + 0.6, y + 2.0, 0.16, 0.03, 5, 0)
    end
    return true
  end

  -- The small things by the road, each facing the karts coming down.
  local function bench(p, r)
    local n = r * -1
    local ax = normalize(cross(UP, n))
    ob(deco, WOOD, p + UP * 0.38, ax, n, 2.3, 0.12, 0.55)
    ob(deco, WOOD, p + UP * 0.42 - n * 0.26, ax, n, 2.3, 0.6, 0.09)
    for s = -1, 1, 2 do ob(deco, DARK, p + ax * (s * 0.95) - UP * 0.4, ax, n, 0.12, 0.82, 0.5) end
  end
  local function trolleys(p, r, t)
    for k = 0, 2 do
      local q = grounded(p + t * (k * 0.5))
      local ww = 0.62 - k * 0.03
      ob(deco, DARK, q - UP * 0.2, r, t, ww - 0.1, 0.4, 0.8)
      ob(deco, STEEL, q + UP * 0.42, r, t, ww, 0.5, 0.86)
      ob(deco, RED, q + UP * 0.98 - t * 0.5, r, t, ww + 0.04, 0.08, 0.08)
      ob(deco, STEEL, q + UP * 0.8 - t * 0.46, r, t, 0.06, 0.2, 0.05)
    end
  end
  local function boxstack(p, ax, n)
    local rows = {{-0.85, 0, 0.85}, {-0.42, 0.42}, {0}}
    for lvl, row in ipairs(rows) do
      for _, u in ipairs(row) do
        local b = p + ax * u + UP * ((lvl - 1) * 0.8 - (lvl == 1 and 0.3 or 0))
        ob(deco, ((lvl + math.floor(u * 3)) % 2 == 0) and CARD or CARD2, b, ax, n, 0.78, 0.78 + (lvl == 1 and 0.3 or 0), 0.78)
        ob(deco, nextof(NEON), b + UP * ((lvl == 1 and 0.3 or 0) + 0.2) + n * 0.38, ax, n, 0.5, 0.36, 0.06)
      end
    end
  end
  local function standee(p, ax, n)
    local c = nextof(NEON)
    ob(deco, CARD, p - UP * 0.3, ax, n, 1.6, 3.0, 0.1)
    ob(deco, c, p + UP * 0.1 + n * 0.05, ax, n, 1.4, 2.45, 0.06)
    ob(deco, CARD2, p - UP * 0.3 - n * 0.4, ax, n, 0.3, 1.4, 0.7)
    disc(deco, (c == YELLOW) and RED or YELLOW, p + UP * 1.75, ax, n, 0.6, 8, 0.06, 0.15)
    text(deco, (c == YELLOW) and WHITE or RED, p + UP * 1.75 + n * 0.14, n, 0.15, "%")
    ob(deco, WHITE, p + UP * 0.45 + n * 0.07, ax, n, 1.1, 0.22, 0.06)
    ob(deco, WHITE, p + UP * 0.8 + n * 0.07, ax, n, 0.8, 0.14, 0.06)
  end
  local function salesign(p, ax, n)
    ob(deco, RED, p + UP * 1.5, ax, n, 3.5, 1.5, 0.12)
    ob(deco, YELLOW, p + UP * 2.95, ax, n, 3.6, 0.2, 0.16)
    text(deco, WHITE, p + UP * 2.25 + n * 0.06, n, 0.2, (nth % 2 == 0) and "SALE" or "50%")
    for s = -1, 1, 2 do ob(deco, STEEL, p + ax * (s * 1.5) - UP * 0.4, ax, n, 0.12, 2.0, 0.08) end
  end
  local function mapsign(p, ax, n)
    ob(solid, col(0.03, 0.06, 0.2), p - UP * 0.4, ax, n, 1.6, 3.5, 0.3)
    ob(deco, COOL, p + UP * 0.8 + n * 0.12, ax, n, 1.3, 1.35, 0.1)
    local blocks = {{-0.35, 1.7, 0.4, 0.3, 1}, {0.25, 1.75, 0.5, 0.22, 2}, {-0.3, 1.2, 0.3, 0.4, 4}, {0.3, 1.25, 0.45, 0.35, 5}, {0, 0.93, 1.0, 0.12, 8}}
    for _, b in ipairs(blocks) do
      ob(deco, NEON[b[5]], p + ax * b[1] + UP * b[2] + n * 0.15, ax, n, b[3], b[4], 0.08)
    end
    disc(deco, RED, p + UP * 1.5 + n * 0.1, ax, n, 0.1, 6, 0.06, 0.12)
    ob(deco, NEON[2], p + UP * 2.3 + n * 0.12, ax, n, 1.3, 0.62, 0.1)
    text(deco, BLACK, p + UP * 2.61 + n * 0.17, n, 0.09, "MAP")
  end
  local function tableset(p)
    local c = nextof(NEON)
    pole(deco, WHITE, p.x, p.z, p.y + 0.72, p.y + 0.8, 0.62, 0.62, 8, 0)
    pole(deco, DARK, p.x, p.z, p.y - 0.3, p.y + 0.75, 0.09, 0.09, 4, 0)
    local a0 = g:range(0, 1.5)
    for k = 0, 3 do
      local a = a0 + k * math.pi / 2
      local dir, sd = v3(math.cos(a), 0, math.sin(a)), v3(-math.sin(a), 0, math.cos(a))
      local q = grounded(p + dir * 0.98)
      ob(deco, c, q - UP * 0.3, sd, dir, 0.42, 0.75, 0.42)
      ob(deco, c, q + UP * 0.4 + dir * 0.2, sd, dir, 0.42, 0.55, 0.07)
    end
  end

  -- Along the road: a slot every four samples a side.
  local zone = K.fin - 18
  local slots = {}
  for i = 3, N - 3, 4 do slots[#slots + 1] = i end
  local kf1 = math.floor(#slots * 0.42)
  local kf2 = 1
  for k, i in ipairs(slots) do if i < zone then kf2 = k end end
  for side = -1, 1, 2 do
    local fr, bk = {}, {}
    for k, i in ipairs(slots) do
      local d0 = (i >= zone) and KD0 or D0
      fr[k], bk[k] = P(i, side, d0), P(i, side, d0 + ((i >= zone) and 4 or DEP))
    end
    for k, i in ipairs(slots) do
      local r, t = frame(i, side)
      local w = 11
      for nb = k - 1, k + 1, 2 do
        if fr[nb] then w = math.min(w, flatdist(fr[k], fr[nb]) - 0.8, flatdist(bk[k], bk[nb]) - 0.8) end
      end
      local front = true
      if i >= zone then
        front = false
        if w >= 4 then kiosk(i, side, math.min(w, 8.5)) end
      elseif (k == kf1 and side == -1) or (k == kf2 and side == 1) then
        if fountain(i, side) then front = false end
      elseif k % 7 == 3 and ((k % 14 == 3) == (side == 1)) then
        escalator(i, side)
      elseif w >= 4 then
        shop(i, side, w)
      end
      -- Something in front of it, by the road.
      local p = P(i, side, 4.5)
      if front and off(p) >= 3.6 then
        local n = normalize(t * -0.75 - r * 0.66)
        local ax = normalize(cross(UP, n))
        local kind = (k * 3 + (side == 1 and 1 or 0)) % 7
        if k % 9 == 4 then mapsign(p, ax, n)
        elseif kind == 0 then bench(p, r)
        elseif kind == 1 then standee(p, ax, n)
        elseif kind == 2 then trolleys(p, r, t)
        elseif kind == 3 then salesign(p, ax, n)
        elseif kind == 4 then boxstack(p, ax, n)
        elseif kind == 5 then palm(p, 0.7)
        else standee(p, ax, n) end
      end
    end
  end

  -- The atrium: tall pillars in pairs every eight samples, a roof beam across each pair and along each side, sale
  -- banners hanging over the road (their feet 7.9 m up); big palms between the pairs.
  local prev = {}
  local nb = 0
  for i = 5, N - 2, 4 do
    local pair = ((i - 5) % 8 == 0)
    local t = K.along(i)
    local top = pos[i].y + 16
    if pair and math.abs(i - K.start) > 2 and math.abs(i - K.fin) > 2 then
      local both = true
      for side = -1, 1, 2 do
        local p = P(i, side, 3.3)
        if off(p) >= 3.2 then
          pole(solid, PILLAR, p.x, p.z, p.y - 0.5, top - 0.5, 0.6, 0.6, 8, math.pi / 8)
          ob(solid, PILLAR_B, v3(p.x, p.y - 0.5, p.z), right[i], t, 1.5, 1.4, 1.5)
          pole(deco, NEON[(nb + (side == 1 and 3 or 0)) % #NEON + 1], p.x, p.z, p.y + 3.2, p.y + 3.7, 0.68, 0.68, 8, math.pi / 8)
          ob(deco, PILLAR_B, v3(p.x, top - 0.9, p.z), right[i], t, 1.7, 0.9, 1.7)
          local q = v3(p.x, top - 0.45, p.z)
          if prev[side] then K.slab(S(deco, BEAM), lerp(prev[side], q, 0.015), lerp(prev[side], q, 0.99), UP * 0.25, right[i] * 0.2) end
          prev[side] = q
        else
          both = false
          prev[side] = nil
        end
      end
      if both then
        nb = nb + 1
        K.road_box(S(deco, BEAM), pos[i] + UP * 15.3, right[i], t, 2 * (W[i] + 3.3), 0.6, 0.5)
        local n = t * -1
        for j = -1, 1 do
          local c = pos[i] + right[i] * (j * 2.4)
          local bc = NEON[(nb * 3 + j + 1) % #NEON + 1]
          local ink = (bc == YELLOW or bc == NEON[4] or bc == NEON[2]) and BLACK or WHITE
          if j == 0 then
            ob(deco, bc, c + UP * 7.9, right[i], t, 1.4, 7.2, 0.1)
            text(deco, ink, c + UP * 11.5 + n * 0.05, n, 0.27, (nb % 3 == 0) and "50%" or "SALE", true)
          else
            ob(deco, bc, c + UP * 10.6, right[i], t, 1.5, 4.5, 0.1)
            text(deco, ink, c + UP * 13.4 + n * 0.05, n, 0.3, "%")
            ob(deco, ink, c + UP * 11.1 + n * 0.03, right[i], t, 1.2, 0.3, 0.1)
          end
        end
      end
    elseif not pair and i < zone then
      for side = -1, 1, 2 do
        local p = P(i, side, 5.3)
        if off(p) >= 4.6 then palm(p, 1) end
      end
    end
  end

  -- The food court: tables and chairs both sides, from before the finish to the road's end.
  for j = zone, N - 2 do
    for side = -1, 1, 2 do
      local p = P(j, side, (j % 2 == 0) and 5.1 or 7.8)
      if off(p) >= 3.6 then tableset(p) end
    end
  end
end

return T
