-- Volcano Holiday Park's scenery kit (see THEME KITS in _course.lua): a cheerful holiday park on a live volcano.
-- Black and dark-brown volcanic ground with glowing lava rivers painted down it and raised lava pools off the road; a
-- smoking cone at the top edge; static caravans and A-frame chalets in rows on astroturf terraces, with deckchairs;
-- a steaming swimming pool under a sign "SLIGHTLY WARM"; a mini-golf, ice-cream kiosks, palms, warning signs,
-- sulphur-yellow vents with steam plumes and scattered pumice boulders. No trees.
local T = {trees = 0, rocks = 0.4}

-- A 3 x 5 block letter each, rows from the top.
local FONT = {
  A = {"010", "101", "111", "101", "101"}, C = {"011", "100", "100", "100", "011"}, D = {"110", "101", "101", "101", "110"},
  E = {"111", "100", "110", "100", "111"}, F = {"111", "100", "110", "100", "100"}, G = {"011", "100", "101", "101", "011"},
  H = {"101", "101", "111", "101", "101"}, I = {"111", "010", "010", "010", "111"}, K = {"101", "101", "110", "101", "101"},
  L = {"100", "100", "100", "100", "111"}, M = {"101", "111", "111", "101", "101"}, N = {"110", "101", "101", "101", "101"},
  O = {"111", "101", "101", "101", "111"}, P = {"110", "101", "110", "100", "100"}, R = {"110", "101", "110", "101", "101"},
  S = {"011", "100", "010", "001", "110"}, T = {"111", "010", "010", "010", "010"}, U = {"101", "101", "101", "101", "111"},
  V = {"101", "101", "101", "101", "010"}, W = {"101", "101", "111", "111", "101"}, Y = {"101", "101", "010", "010", "010"},
}

-- How far (x, z) is from the middle of the nearest lava river: seven of them wandering down the valley.
local function river(x, z)
  local best = 1e9
  for k = 0, 6 do
    local xr = -170 + k * 44 + 16 * math.sin(z * 0.03 + k * 1.7) + 6 * math.sin(z * 0.11 + k)
    best = math.min(best, math.abs(x - xr))
  end
  return best
end

-- The ground: black and dark-brown rock, ash by the road, the lava rivers glowing orange in scorched banks, embers.
local PC
function T.paint(x, z, off, ink, TK)
  if not PC then
    PC = {TK.col(0.035, 0.03, 0.03), TK.col(0.1, 0.06, 0.04), TK.col(0.16, 0.09, 0.05), ash = TK.col(0.13, 0.11, 0.1),
      lava = TK.col(1, 0.3, 0.01), hot = TK.col(1, 0.62, 0.05), scorch = TK.col(0.36, 0.05, 0.01)}
  end
  local h = TK.hash(math.floor(x / 5) + 0.5, math.floor(z / 5) + 0.5)
  if off > 9 then
    local d = river(x, z)
    if d < 3.2 then return (h < 0.3) and PC.hot or PC.lava end
    if d < 7.5 then return PC.scorch end
    if h > 0.988 then return PC.lava end
  end
  if off < 4 then return PC.ash end
  return PC[math.floor(h * 2.999) + 1]
end

function T.build(K)
  local col, g, hash, pos, right, W, N = K.col, K.g, K.hash, K.pos, K.right, K.W, K.N
  local UP = v3(0, 1, 0)
  local X0, X1, Z0, Z1 = K.X0, K.X1, K.Z0, K.Z1
  local WHITE, CREAM, PALE = col(0.92, 0.92, 0.88), col(0.9, 0.8, 0.5), col(0.75, 0.88, 0.8)
  local RED, BLUE, TEAL, ORANGE = col(0.8, 0.05, 0.04), col(0.04, 0.25, 0.75), col(0.0, 0.55, 0.5), col(0.95, 0.4, 0.02)
  local GREEN, YELLOW, PINK = col(0.1, 0.5, 0.12), col(1, 0.8, 0.04), col(1, 0.3, 0.55)
  local GLASS, DARK, WOOD = col(0.1, 0.2, 0.3), col(0.04, 0.04, 0.05), col(0.45, 0.28, 0.13)
  local STEEL, ROCK, BASALT = col(0.55, 0.57, 0.6), col(0.09, 0.07, 0.06), col(0.05, 0.045, 0.045)
  local LAVA, HOT, EMBER = col(1, 0.3, 0.01), col(1, 0.65, 0.06), col(0.75, 0.1, 0.01)
  local LAWN, FELT, FELT2 = col(0.2, 0.62, 0.12), col(0.08, 0.45, 0.14), col(0.3, 0.75, 0.25)
  local TILE, WATER, STEAM = col(0.85, 0.78, 0.62), col(0.05, 0.7, 0.85), col(0.93, 0.95, 0.96)
  local SULPH, SULPH2, PUMICE = col(0.95, 0.85, 0.08), col(0.8, 0.62, 0.04), col(0.74, 0.71, 0.64)
  local TRUNK, PALM1, PALM2, NUT = col(0.42, 0.27, 0.12), col(0.1, 0.52, 0.12), col(0.25, 0.7, 0.15), col(0.25, 0.13, 0.05)
  local WAFER, CHOC = col(0.82, 0.54, 0.2), col(0.25, 0.11, 0.04)
  local BRIGHT = {RED, YELLOW, BLUE, PINK, ORANGE, TEAL, GREEN}
  local SHADES = {CREAM, PALE, WHITE, col(0.7, 0.84, 0.95), col(0.98, 0.75, 0.7), col(0.95, 0.9, 0.55)}
  local ROOFS = {col(0.3, 0.31, 0.33), col(0.6, 0.15, 0.1), col(0.1, 0.35, 0.45)}
  local AFRAME = {RED, TEAL, YELLOW, BLUE, ORANGE, PINK}
  local MINE = K.WALL_T + 1.2

  local function S(c) local q = K.sub(K.solid, c); q.ink = c; return q end
  local function D(c) local q = K.sub(K.deco, c); q.ink = c; return q end
  local function one() return 1 end
  -- An upright box: `base` the middle of its bottom, half-sizes hu along u and hw along w, h tall.
  local function box(b, base, u, w, hu, hw, h) K.slab(b, base, base + v3(0, h, 0), u * hu, w * hw) end
  -- A square bar from p to q, th its half thickness.
  local function bar(b, p, q, th)
    local d = normalize(q - p)
    local a = normalize(cross(d, (math.abs(d.y) > 0.9) and v3(1, 0, 0) or UP))
    K.slab(b, p, q, a * th, cross(d, a) * th)
  end
  -- A profile in the (u, up) plane -- {along u, height} points round it -- pushed hw each way along w.
  local function extrude(b, c, u, w, hw, prof, colour)
    local r1, r2 = {}, {}
    for k, p in ipairs(prof) do
      local q = c + u * p[1] + v3(0, p[2], 0)
      r1[k] = q - w * hw; r2[k] = q + w * hw
    end
    K.prism(b, {r1, r2}, K.flat(colour), colour, colour)
  end
  local function drum(b, c, u, w, hl, r, colour)
    local r1, r2 = {}, {}
    for k = 0, 7 do
      local a = k / 8 * math.pi * 2
      local o = u * (math.cos(a) * r) + v3(0, math.sin(a) * r, 0)
      r1[k + 1] = c - w * hl + o; r2[k + 1] = c + w * hl + o
    end
    K.prism(b, {r1, r2}, K.flat(colour), colour, colour)
  end
  local function gable(b, c, u, w, hu, hw, rise, colour)
    local function sec(s)
      local e = c + u * (s * hu)
      return {e - w * hw, e + v3(0, rise, 0), e + w * hw}
    end
    K.prism(b, {sec(-1), sec(1)}, K.flat(colour), colour, colour)
  end
  local function puff(p, r, c)
    K.ball(D(c or STEAM), p, r, r * 0.85, r, 6, 4, function() return g:range(0.85, 1.1) end, K.flat(c or STEAM))
  end

  -- Block letters on a face whose outward normal is n, centred on `at`; a board behind them (bw by bh) if asked.
  local function text(c, at, n, cell, word)
    local q = D(c)
    local ax = normalize(cross(UP, n))
    local tw = (4 * #word - 1) * cell
    for l = 1, #word do
      local gl = FONT[word:sub(l, l)]
      if gl then
        local ox = (l - 1) * 4 * cell
        for rr = 1, 5 do
          local row = gl[rr]
          local a = nil
          for cx = 1, 4 do
            local on = cx <= 3 and row:sub(cx, cx) == "1"
            if on and not a then a = cx end
            if not on and a then
              local x0, x1 = (a - 1) * cell, (cx - 1) * cell
              local ctr = at + ax * (ox + (x0 + x1) / 2 - tw / 2) + UP * (2.5 * cell - (rr - 0.5) * cell)
              K.slab(q, ctr - n * 0.03, ctr + n * 0.07, ax * ((x1 - x0) / 2 - 0.004), UP * (cell * 0.46))
              a = nil
            end
          end
        end
      end
    end
  end
  -- A sign board facing n, its middle at `at`, on two posts down to the ground; lines of text on it.
  local function sign(at, n, bw, bh, back, ink, cell, lines)
    local ax = normalize(cross(UP, n))
    K.slab(S(back), at - n * 0.16, at - n * 0.01, ax * (bw / 2), UP * (bh / 2))
    for k = -1, 1, 2 do
      local p = at + ax * (k * (bw / 2 - 0.3)) - n * 0.3
      K.column(S(WOOD), p.x, p.z, K.ground(p.x, p.z) - 0.6, at.y + bh / 2 - 0.1, 0.12, 0.12, 6, WOOD)
    end
    for l, word in ipairs(lines) do
      text(ink, at + UP * ((#lines / 2 - l + 0.5) * cell * 6.4), n, cell, word)
    end
  end

  local function edge(x, z) local _, d = K.ground_d(x, z); return d - K.HW end
  local taken = {}
  local function free(x, z, r)
    for _, q in ipairs(taken) do
      local dx, dz, rr = x - q[1], z - q[2], r + q[3]
      if dx * dx + dz * dz < rr * rr then return false end
    end
    return true
  end
  local function claim(x, z, r) taken[#taken + 1] = {x, z, r} end
  local function span(c, u, w, hu, hw)
    local lo, hi = math.huge, -math.huge
    for _, a in ipairs({{1, 1}, {-1, 1}, {-1, -1}, {1, -1}, {0, 0}}) do
      local p = c + u * (a[1] * hu) + w * (a[2] * hw)
      local y = K.ground(p.x, p.z)
      lo = math.min(lo, y); hi = math.max(hi, y)
    end
    return lo, hi
  end
  -- A levelled terrace of rock under a footprint, topped in `top`; its top's height returned.
  local function pad(c, u, w, hu, hw, share, top)
    local lo, hi = span(c, u, w, hu, hw)
    local y = lo + (hi - lo) * share + 0.08
    K.slab(S(ROCK), v3(c.x, lo - 0.7, c.z), v3(c.x, y - 0.06, c.z), u * hu, w * hw)
    K.slab(S(top), v3(c.x, y - 0.3, c.z), v3(c.x, y, c.z), u * (hu - 0.15), w * (hw - 0.15))
    return y
  end
  -- A site by the road (as the caravan kit's): a footprint centred `off` past the road's edge, clear of every bend.
  local function site(i0, i1, off, hu, hw, first)
    i0, i1 = math.max(3, math.min(N - 2, math.floor(i0))), math.max(3, math.min(N - 2, math.floor(i1)))
    for i = i0, i1, (i1 >= i0) and 2 or -2 do
      for s = 1, 2 do
        local side = ((s == 1) == (first == 1)) and 1 or -1
        local r, t = right[i] * side, K.along(i)
        local c = pos[i] + r * (W[i] + off)
        local ok = edge(c.x, c.z) > off - 0.8 and free(c.x, c.z, math.max(hu, hw) + 1)
        for _, a in ipairs({{1, 1}, {-1, 1}, {-1, -1}, {1, -1}}) do
          local p = c + t * (a[1] * hu) + r * (a[2] * hw)
          if ok and edge(p.x, p.z) < off - hw - 0.8 then ok = false end
        end
        if ok then return c, t, r end
      end
    end
  end

  -- A deckchair at p (its feet at p.y) facing f.
  local function deckchair(p, f, c)
    local q = 1.3
    local s = v3(-f.z, 0, f.x)
    p = p - v3(0, 0.05, 0)
    local A, B = p + f * (0.35 * q) + v3(0, 0.28 * q, 0), p - f * (0.45 * q) + v3(0, 1.05 * q, 0)
    local nrm = normalize(cross(B - A, s)) * 0.018
    for k = -1, 1 do
      K.slab(D(k == 0 and WHITE or c), A + s * (k * 0.2 * q), B + s * (k * 0.2 * q), s * (0.097 * q), nrm)
    end
    for k = -1, 1, 2 do
      local o = s * (k * 0.34 * q)
      bar(D(WOOD), p + f * (0.55 * q) + o - v3(0, 0.3, 0), p - f * (0.5 * q) + o + v3(0, 1.12 * q, 0), 0.03)
      bar(D(WOOD), p - f * (0.65 * q) + o - v3(0, 0.3, 0), p + f * (0.05 * q) + o + v3(0, 0.62 * q, 0), 0.03)
    end
  end
  local function chair_on_ground(p, f, c) deckchair(v3(p.x, K.ground(p.x, p.z), p.z), f, c) end
  -- A parasol: a pole and a striped cone.
  local function parasol(p, c)
    K.column(D(WHITE), p.x, p.z, p.y - 0.23, p.y + 2.5, 0.05, 0.05, 5, WHITE)
    local top = p + v3(0, 2.2, 0)
    K.cone(K.sub(K.deco, "parasol"), K.ring(top, 1.7, 1.7, 8, 0), top, top + v3(0, 0.75, 0),
      function(k) return (k % 2 == 0) and c or WHITE end, WHITE)
  end

  -- A palm: a leaning trunk, a crown of drooping fronds, coconuts.
  local function palm(p, s, lean)
    local base = v3(p.x, K.ground(p.x, p.z) - 0.6, p.z)
    local H = 6.5 * s
    local rings, top = {}, base
    for j = 0, 4 do
      local f = j / 4
      top = base + UP * (H * f + 0.6) + lean * (1.7 * s * f * f)
      local rr = 0.32 * s * (1 - 0.45 * f)
      rings[#rings + 1] = K.ring(top, rr, rr, 6, j * 0.4)
    end
    K.prism(S(TRUNK), rings, K.flat(TRUNK), TRUNK, TRUNK)
    local a0 = g:range(0, 6.28)
    for k = 0, 6 do
      local a = a0 + k / 7 * math.pi * 2
      local o = v3(math.cos(a), 0, math.sin(a))
      local sd = v3(-o.z, 0, o.x)
      local c = (k % 2 == 0) and PALM1 or PALM2
      local mid, tip = top + o * (1.8 * s) + UP * (0.55 * s), top + o * (3.4 * s) - UP * (0.9 * s)
      K.slab(D(c), top - UP * 0.05, mid, sd * (0.48 * s), normalize(cross(mid - top, sd)) * 0.04)
      K.slab(D(c), lerp(mid, tip, 0.04), tip, sd * (0.3 * s), normalize(cross(tip - mid, sd)) * 0.04)
    end
    for k = 0, 2 do
      local a = a0 + k * 2.1
      K.ball(D(NUT), top + v3(math.cos(a) * 0.3 * s, -0.3 * s, math.sin(a) * 0.3 * s), 0.2 * s, 0.2 * s, 0.2 * s, 5, 3, one, K.flat(NUT))
    end
  end

  -- A sulphur vent: a yellow crusted mound, a dark throat, a plume of steam.
  local function vent(x, z, s)
    local y = K.ground(x, z)
    K.column(S(SULPH), x, z, y - 0.6, y + 0.9 * s, 1.6 * s, 0.6 * s, 7, SULPH, x)
    K.column(D(SULPH2), x, z, y - 0.45, y + 0.3 * s, 2.3 * s, 1.5 * s, 7, SULPH2, z)
    K.column(D(DARK), x, z, y + 0.8 * s, y + 0.96 * s, 0.42 * s, 0.42 * s, 6, DARK)
    local dx, dz = g:range(-0.25, 0.25), g:range(-0.25, 0.25)
    for k = 1, 4 do
      puff(v3(x + dx * k * k * 0.5, y + (0.6 + k * 1.35) * s, z + dz * k * k * 0.5), (0.4 + 0.24 * k) * s)
    end
  end

  -- A raised lava pool: a basalt rim, the lava brimming in it, a hot heart and bubbles.
  local function lava_pool(x, z, R)
    local lo, hi = span(v3(x, 0, z), v3(1, 0, 0), v3(0, 0, 1), R, R)
    K.column(K.sub(K.solid, "rim"), x, z, lo - 1, hi + 0.7, R + 1.3, R, 10, BASALT, x)
    K.column(D(LAVA), x, z, hi + 0.3, hi + 0.82, R - 0.45, R - 0.45, 10, LAVA, x)
    K.column(D(HOT), x + R * 0.12, z - R * 0.1, hi + 0.5, hi + 0.9, R * 0.5, R * 0.5, 8, HOT, z)
    for k = 1, 3 do
      local a, d = g:range(0, 6.28), g:range(0.3, 0.75) * R
      local r = g:range(0.45, 0.95)
      K.ball(D(k == 2 and HOT or LAVA), v3(x + math.cos(a) * d, hi + 0.85, z + math.sin(a) * d), r, r * 0.8, r, 6, 4, one, K.flat(k == 2 and HOT or LAVA))
    end
  end

  -- A static caravan (a holiday home): long and low under a shallow roof, a deck and patio doors on its w side.
  local function static(c, u, w, body, stripe, roof)
    box(S(DARK), c, u, w, 4.3, 1.45, 0.42)
    box(S(body), c + v3(0, 0.38, 0), u, w, 4.4, 1.55, 2.4)
    gable(S(roof), c + v3(0, 2.74, 0), u, w, 4.6, 1.78, 0.6, roof)
    box(D(stripe), c + v3(0, 1.0, 0), u, w, 4.42, 1.57, 0.22)
    local gl = D(GLASS)
    box(gl, c + u * -2.3 + w * 1.55 + v3(0, 0.5, 0), u, w, 0.9, 0.04, 1.85)
    box(gl, c + u * 0.7 + w * 1.55 + v3(0, 1.35, 0), u, w, 0.7, 0.04, 0.9)
    box(gl, c + u * 2.9 + w * 1.55 + v3(0, 1.35, 0), u, w, 0.7, 0.04, 0.9)
    box(gl, c + u * 4.4 + v3(0, 1.35, 0), u, w, 0.04, 1.0, 0.9)
    box(D(WOOD), c + u * -0.9 + w * 2.5 + v3(0, 0.02, 0), u, w, 3.2, 0.93, 0.36)
    local r0, r1 = c + u * -4.05 + w * 3.38 + v3(0, 1.3, 0), c + u * 2.25 + w * 3.38 + v3(0, 1.3, 0)
    bar(D(WHITE), r0, r1, 0.05)
    for k = 0, 3 do
      local p = lerp(r0, r1, k / 3 * 0.98 + 0.01)
      bar(D(WHITE), p - v3(0, 1.0, 0), p - v3(0, 0.06, 0), 0.045)
    end
  end
  -- An A-frame chalet: a bright steep roof to the ground, a glazed gable and a deck towards w.
  local function chalet(c, u, w, roof)
    extrude(S(roof), c, u, w, 3.0, {{-3.1, 0.02}, {3.1, 0.02}, {0, 5.4}}, roof)
    extrude(D(WHITE), c + w * 3.0, u, w, 0.06, {{-2.6, 0.1}, {2.6, 0.1}, {0, 4.6}}, WHITE)
    extrude(D(GLASS), c + w * 3.06, u, w, 0.05, {{-1.5, 2.3}, {1.5, 2.3}, {0, 4.0}}, GLASS)
    box(D(GLASS), c + w * 3.08 - u * 0.8 + v3(0, 0.3, 0), u, w, 0.55, 0.05, 1.7)
    box(D(WOOD), c + w * 3.08 + u * 0.8 + v3(0, 0.3, 0), u, w, 0.45, 0.05, 1.8)
    box(D(WOOD), c + w * 4.1 + v3(0, 0.02, 0), u, w, 3.0, 0.95, 0.3)
    local p = c - w * 1.2 + u * 0.9
    K.column(D(DARK), p.x, p.z, c.y + 2.5, c.y + 4.6, 0.22, 0.22, 6, DARK)
  end

  -- ------------------------------------------------------------------ the volcano, at the top edge
  ;(function()
    local cx, cz = (X0 + X1) / 2 - 5, Z0 - 28
    local R = math.min(48, edge(cx, cz) - 8)
    if R < 20 then return end
    claim(cx, cz, R + 2)
    local y0 = K.ground(cx, cz) - 24
    local H = 24 + R * 1.45
    local prof = {{1, 0}, {0.8, 0.26}, {0.6, 0.48}, {0.42, 0.66}, {0.29, 0.82}, {0.2, 0.94}, {0.17, 1}}
    local SIDES = 14
    local rings = {}
    for j, p in ipairs(prof) do
      local ring = {}
      for k = 0, SIDES - 1 do
        local a = k / SIDES * math.pi * 2
        local rr = R * p[1] * (0.9 + 0.2 * hash(j * 3.1, k * 7.7))
        ring[k + 1] = v3(cx + math.cos(a) * rr, y0 + H * p[2] + ((j == #prof) and 2.5 * hash(k, 3) or 0), cz + math.sin(a) * rr)
      end
      rings[j] = ring
    end
    local C1, C2, C3 = col(0.07, 0.055, 0.05), col(0.13, 0.08, 0.05), col(0.2, 0.11, 0.06)
    local FLOW = {[2] = 2, [6] = 4, [9] = 3, [12] = 2}
    K.prism(K.sub(K.solid, "volcano"), rings, function(j, k)
      if FLOW[k] and j >= FLOW[k] then return ((j + k) % 3 == 0) and HOT or LAVA end
      if FLOW[k - 1] and j >= FLOW[k - 1] + 2 then return EMBER end
      local h = hash(j * 5.3, k * 2.9)
      return (h < 0.35) and C1 or ((h < 0.7) and C2 or C3)
    end, C1, HOT)
    -- The lava brimming in the crater, and the smoke.
    local top = y0 + H
    K.column(D(LAVA), cx, cz, top - 3, top + 1.2, R * 0.12, R * 0.1, 8, LAVA)
    local GREYS = {col(0.3, 0.29, 0.28), col(0.42, 0.41, 0.4), col(0.55, 0.54, 0.53), col(0.66, 0.65, 0.64)}
    local px, py, pz = cx, top + 4, cz
    for k = 1, 7 do
      local r = 4 + k * 1.7
      local c = GREYS[(k - 1) % 4 + 1]
      K.ball(K.sub(K.deco, "smoke" .. (k % 2)), v3(px, py, pz), r, r * 0.8, r, 8, 5, function() return g:range(0.8, 1.15) end, K.shaded(c))
      px, py, pz = px + r * 0.55, py + r * 1.0, pz - r * 0.3
    end
    -- Lava bombs lying about its foot.
    for k = 1, 10 do
      local a = k * 0.7
      local x, z = cx + math.cos(a) * (R + 4), cz + math.sin(a) * (R + 4)
      if x > X0 + 3 and x < X1 - 3 and z < Z0 - 3 and edge(x, z) > 6 then
        local r = 1.2 + hash(k, 9) * 1.4
        K.ball(K.sub(K.solid, "bomb"), v3(x, K.ground(x, z) + r * 0.4, z), r, r * 0.8, r, 6, 4, function() return g:range(0.8, 1.15) end,
          function(wv) return (wv.y < -0.1 or hash(wv.x * 9, wv.z * 9) < 0.25) and LAVA or BASALT end)
      end
    end
  end)()

  local SPAN = K.fin - K.start
  local function at(f) return K.start + SPAN * f end

  -- ------------------------------------------------------------------ the welcome sign
  ;(function()
    local c, t, r = site(at(0.03), at(0.2), 7, 6.5, 1.2, 1)
    if not c then return end
    claim(c.x, c.z, 6.5)
    local n = normalize(t * -1 - r * 0.45)
    sign(v3(c.x, K.ground(c.x, c.z) + 4.6, c.z), n, 12.2, 4.2, YELLOW, RED, 0.25, {"VOLCANO", "HOLIDAY PARK"})
  end)()

  -- ------------------------------------------------------------------ the pool: "SLIGHTLY WARM"
  ;(function()
    local c, t, r = site(at(0.2), at(0.6), 12.5, 10, 6.5, -1)
    if not c then c, t, r = site(at(0.6), at(0.95), 12.5, 10, 6.5, 1) end
    if not c then return end
    claim(c.x, c.z, 12.5)
    local u, w = t, r * -1
    local y = pad(c, u, w, 10, 6.5, 0.8, TILE)
    c = v3(c.x, y, c.z)
    local pc = c + w * 1.6
    box(S(WATER), pc - v3(0, 0.2, 0), u, w, 7, 3.4, 0.5)
    for k = -1, 1, 2 do
      box(S(WHITE), pc + w * (k * 3.6) - v3(0, 0.1, 0), u, w, 7.45, 0.25, 0.55)
      box(S(WHITE), pc + u * (k * 7.2) - v3(0, 0.1, 0), u, w, 0.25, 3.3, 0.55)
    end
    -- lane floats, a diving board, a ladder
    for k = -3, 3 do K.column(D(RED), (pc + u * (k * 1.8)).x, (pc + u * (k * 1.8)).z, y + 0.2, y + 0.42, 0.2, 0.2, 6, RED) end
    box(D(BLUE), pc + u * 6.6 + v3(0, 0.75, 0), u, w, 1.6, 0.35, 0.1)
    box(D(STEEL), pc + u * 7.7 + v3(0, 0.02, 0), u, w, 0.3, 0.3, 0.72)
    for k = -1, 1, 2 do
      local p = pc - u * 7.0 + w * (k * 0.35 - 2)
      bar(D(STEEL), p + v3(0, 0.1, 0), p + v3(0, 1.3, 0), 0.04)
      bar(D(STEEL), p + v3(0, 1.3, 0) + u * 0.02, p + v3(0, 1.3, 0) - u * 0.7, 0.04)
    end
    -- steam off the water
    for k = 1, 12 do
      local p = pc + u * g:range(-6, 6) + w * g:range(-2.6, 2.6)
      puff(p + v3(0, g:range(0.9, 4.2), 0), g:range(0.45, 1.0))
    end
    -- loungers and parasols round it
    for k = -2, 2 do
      deckchair(c - w * 3.4 + u * (k * 3.1 + 0.6), w, BRIGHT[(k + 3) % #BRIGHT + 1])
    end
    parasol(c - w * 3.6 + u * 2.2, RED)
    parasol(c - w * 3.6 - u * 4.0, BLUE)
    parasol(c + u * 8.9 + w * 2.5, YELLOW)
    deckchair(c - u * 8.8 + w * 1.5, u, PINK)
    deckchair(c - u * 8.8 + w * 3.5, u, TEAL)
    -- the sign, at the back, turned a little to meet the karts
    local n = normalize(w - t * 0.35)
    sign(c - w * 5.6 + v3(0, 4.3, 0), n, 10.6, 4.4, WHITE, RED, 0.29, {"SLIGHTLY", "WARM"})
    -- a thermometer beside it, in the red
    local tp = c - w * 5.5 + u * 7.6
    K.column(D(WHITE), tp.x, tp.z, y + 0.01, y + 4.6, 0.3, 0.3, 6, WHITE)
    K.column(D(RED), tp.x, tp.z, y + 0.3, y + 4.75, 0.17, 0.17, 6, RED, 0.5)
    K.ball(D(RED), tp + v3(0, 0.5, 0), 0.6, 0.6, 0.6, 6, 4, one, K.flat(RED))
  end)()

  -- ------------------------------------------------------------------ the mini-golf
  ;(function()
    local c, t, r = site(at(0.55), at(0.9), 12, 9, 6.2, 1)
    if not c then c, t, r = site(at(0.5), at(0.1), 12, 9, 6.2, 1) end
    if not c then return end
    claim(c.x, c.z, 11.5)
    local u, w = t, r * -1
    local y = pad(c, u, w, 9, 6.2, 0.8, FELT)
    c = v3(c.x, y, c.z)
    for k = -1, 1 do
      local lc = c + w * (k * 3.6 + 0.6)
      box(D(FELT2), lc + v3(0, 0.01, 0), u, w, 6.8, 1.05, 0.07)
      for q = -1, 1, 2 do box(D((k == 0) and YELLOW or RED), lc + w * (q * 1.2) + v3(0, 0.012, 0), u, w, 7.0, 0.1, 0.25) end
      local hole = lc + u * 5.9
      K.column(D(DARK), hole.x, hole.z, y + 0.02, y + 0.1, 0.24, 0.24, 6, DARK)
      bar(D(WHITE), hole + v3(0, 0.05, 0), hole + v3(0, 2.2, 0), 0.03)
      extrude(D(BRIGHT[k + 3]), hole + v3(0, 1.6, 0), u, w, 0.02, {{0.04, 0}, {0.8, 0.28}, {0.04, 0.56}}, BRIGHT[k + 3])
      local ball = lc - u * 5.2 + w * 0.3
      K.ball(D(WHITE), ball + v3(0, 0.22, 0), 0.16, 0.16, 0.16, 5, 3, one, K.flat(WHITE))
      local o = lc + u * 0.5 + v3(0, 0.085, 0)
      local y = y + 0.085
      if k == -1 then       -- a little volcano
        K.column(D(TRUNK), o.x, o.z, y, y + 1.5, 1.0, 0.35, 7, TRUNK)
        K.column(D(LAVA), o.x, o.z, y + 1.4, y + 1.6, 0.3, 0.3, 6, LAVA, 0.3)
        puff(o + v3(0.2, 2.2, 0), 0.4)
      elseif k == 0 then    -- a windmill
        box(D(BLUE), o + w * 0.02, u, w, 0.6, 0.6, 2.4)
        K.cone(D(RED), K.ring(o + v3(0, 2.38, 0), 0.95, 0.95, 4, 0.785), o + v3(0, 2.38, 0), o + v3(0, 3.4, 0), K.flat(RED), RED)
        local hub = o - u * 0.68 + v3(0, 2.0, 0)
        for q = 0, 3 do
          local a = q * math.pi / 2 + 0.5
          local d = w * math.cos(a) + UP * math.sin(a)
          K.slab(D(WHITE), hub + d * 0.32, hub + d * 1.6, cross(d, u) * 0.22, u * 0.03)
        end
      else                  -- a hoop
        for q = -1, 1, 2 do bar(D(PINK), o + w * (q * 0.8) + v3(0, 0.02, 0), o + w * (q * 0.8) + v3(0, 1.3, 0), 0.08) end
        bar(D(PINK), o - w * 0.9 + v3(0, 1.4, 0), o + w * 0.9 + v3(0, 1.4, 0), 0.08)
      end
    end
    sign(c - w * 5.3 + v3(0, 3.4, 0), normalize(w - t * 0.35), 6.4, 2.3, GREEN, WHITE, 0.3, {"GOLF"})
  end)()

  -- ------------------------------------------------------------------ the ice-cream kiosks
  for q, f in ipairs({0.1, 0.45, 0.82}) do (function()
    local c, t, r = site(at(f), at(f + 0.15), 7.6, 3, 2.3, (q % 2 == 0) and 1 or -1)
    if not c then return end
    claim(c.x, c.z, 4.5)
    local u, w = t, r * -1
    local y = pad(c, u, w, 3.2, 2.5, 0.85, TILE)
    c = v3(c.x, y, c.z)
    box(S(WHITE), c, u, w, 2.1, 1.6, 2.7)
    for k = -2, 2 do box(D(PINK), c + u * (k * 0.84) + v3(0, 0.015, 0), u, w, 0.21, 1.62, 1.1) end
    box(D(GLASS), c + w * 1.6 + v3(0, 1.2, 0), u, w, 1.5, 0.04, 1.0)
    box(D(PINK), c + v3(0, 2.68, 0), u, w, 2.4, 1.9, 0.22)
    for k = 1, 6 do
      local a = c + w * 1.9 + v3(0, 2.6, 0) + u * ((k - 3.5) * 0.7)
      K.slab(D((k % 2 == 1) and PINK or WHITE), a, a + w * 1.2 - v3(0, 0.4, 0), u * 0.34, v3(0, 0.03, 0))
    end
    sign(c + w * 1.3 + v3(0, 3.6, 0), w, 3.6, 1.1, TEAL, WHITE, 0.17, {"ICES"})
    local p = c - w * 0.5
    K.column(D(WAFER), p.x, p.z, y + 2.85, y + 5.0, 0.12, 0.8, 8, WAFER)
    K.ball(D(WHITE), p + v3(0, 5.3, 0), 0.95, 0.8, 0.95, 8, 5, one, K.flat(WHITE))
    K.ball(D(PINK), p + v3(0, 6.2, 0), 0.68, 0.6, 0.68, 7, 4, one, K.flat(PINK))
    bar(D(CHOC), p + u * 0.3 + v3(0, 5.8, 0), p + u * 1.1 + v3(0, 7.2, 0), 0.12)
    parasol(c + w * 3.6 + u * 2.6 - v3(0, y - K.ground((c + w * 3.6 + u * 2.6).x, (c + w * 3.6 + u * 2.6).z), 0), ORANGE)
  end)() end

  -- ------------------------------------------------------------------ the rows: statics, chalets, statics
  for row, off in ipairs({12.5, 25.5, 38.5}) do
    for side = -1, 1, 2 do
      local acc = off * 0.3
      for i = 3, N - 1 do
        acc = acc + length(pos[i] - pos[i - 1])
        if acc >= ((row == 2) and 11.5 or 14) then
          acc = 0
          local r, t = right[i] * side, K.along(i)
          local c = pos[i] + r * (W[i] + off)
          local fr = c - r * 5.6
          if hash(i, off + side) < 0.8 and edge(c.x, c.z) > off - 1 and edge(fr.x, fr.z) > off - 7 and free(c.x, c.z, 5.6)
            and river(c.x, c.z) > 9 and c.x > X0 + 8 and c.x < X1 - 8 and c.z > Z1 + 8 and c.z < Z0 - 8 then
            claim(c.x, c.z, 5.6)
            local u, w = t * ((hash(i, off) < 0.5) and 1 or -1), r * -1
            if row == 2 then
              local y = pad(c + w * 1.9, u, w, 3.9, 5.3, 0.8, LAWN)
              local cc = v3(c.x, y, c.z)
              chalet(cc, u, w, K.pick(AFRAME))
              deckchair(cc + w * 6.0 + u * 1.6, w, K.pick(BRIGHT))
              if hash(i, 4) < 0.5 then parasol(cc + w * 6.2 - u * 1.5, K.pick(BRIGHT)) end
            else
              local y = pad(c + w * 1.9, u, w, 5.1, 3.7, 0.8, LAWN)
              local cc = v3(c.x, y, c.z)
              static(cc, u, w, K.pick(SHADES), K.pick(BRIGHT), K.pick(ROOFS))
              deckchair(cc + w * 4.6 + u * 3.4, w, K.pick(BRIGHT))
              deckchair(cc + w * 4.6 + u * 2.1, normalize(w - u * 0.3), K.pick(BRIGHT))
              if hash(i, 8) < 0.4 then parasol(cc + w * 4.7 - u * 0.2, K.pick(BRIGHT)) end
            end
          end
        end
      end
    end
  end

  -- ------------------------------------------------------------------ along the road: palms, signs, vents, chairs
  local WARN = {{"DANGER", "LAVA"}, {"HOT"}, {"KEEP OFF", "THE LAVA"}, {"NO DIVING"}}
  for side = -1, 1, 2 do
    local acc, slot = 2 + side * 2, (side == 1) and 3 or 0
    for i = 3, N - 1 do
      acc = acc + length(pos[i] - pos[i - 1])
      if acc >= 7.5 then
        acc = 0
        slot = slot + 1
        local r, t = right[i] * side, K.along(i)
        local kind = slot % 6
        local function place(off, clear)
          local p = pos[i] + r * (W[i] + off)
          if edge(p.x, p.z) > off - 0.5 and free(p.x, p.z, clear) then return p end
        end
        if kind == 0 or kind == 3 then
          local p = place(MINE + 2.4, 0.8)
          if p then palm(p, g:range(0.85, 1.25), normalize(r * g:range(0.6, 1) + t * g:range(-0.5, 0.5))) end
        elseif kind == 1 then
          local p = place(MINE + 2.6, 2.2)
          if p then
            if hash(i, 71) < 0.5 then
              -- a warning triangle on a post, facing up the road
              local y = K.ground(p.x, p.z)
              local n = t * -1
              K.column(S(STEEL), p.x, p.z, y - 0.5, y + 2.2, 0.07, 0.07, 6, STEEL)
              local a = v3(p.x, y + 2.1, p.z)
              extrude(D(RED), a, r, n, 0.04, {{-1.0, 0}, {1.0, 0}, {0, 1.7}}, RED)
              extrude(D(YELLOW), a + n * 0.05 + UP * 0.16, r, n, 0.03, {{-0.7, 0}, {0.7, 0}, {0, 1.2}}, YELLOW)
              -- a flame in it
              extrude(D(DARK), a + n * 0.09 + UP * 0.24, r, n, 0.02, {{-0.22, 0.1}, {0.22, 0.1}, {0.05, 0.75}}, DARK)
            else
              local lines = WARN[math.floor(hash(i, 13) * #WARN) + 1]
              local y = K.ground(p.x, p.z)
              local bh = (#lines == 2) and 2.0 or 1.15
              sign(v3(p.x, y + 2.9, p.z), normalize(t * -1 - r * 0.25), 3.9, bh, (hash(i, 5) < 0.5) and RED or YELLOW,
                (hash(i, 5) < 0.5) and WHITE or DARK, 0.115, lines)
            end
          end
        elseif kind == 2 then
          local p = place(MINE + 2.2, 1.6)
          if p then
            chair_on_ground(p + t * 0.7, r * -1, K.pick(BRIGHT))
            chair_on_ground(p - t * 0.7, normalize(r * -1 + t * 0.3), K.pick(BRIGHT))
          end
        elseif kind == 4 then
          local p = place(MINE + 3.6, 2.6)
          if p then claim(p.x, p.z, 2.4); vent(p.x, p.z, g:range(0.85, 1.3)) end
        else
          local p = place(MINE + 2.2, 1.6)
          if p then
            for k = 1, 2 do
              local q = p + t * ((k - 1.5) * 1.7) + r * (k * 0.5)
              local rr = g:range(0.5, 0.95)
              K.ball(K.sub(K.solid, "pumice" .. (k % 3)), v3(q.x, K.ground(q.x, q.z) + rr * 0.45, q.z), rr, rr * 0.75, rr, 6, 4,
                function() return g:range(0.8, 1.15) end, K.shaded(PUMICE))
            end
          end
        end
      end
    end
  end

  -- ------------------------------------------------------------------ out on the slopes
  -- Raised lava pools, well off the road.
  local pools = 0
  for _ = 1, 90 do
    if pools >= 16 then break end
    local x, z = K.spot(15)
    local R = g:range(4, 8.5)
    if x and free(x, z, R + 3) and x > X0 + 12 and x < X1 - 12 and z > Z1 + 12 and z < Z0 - 12 then
      claim(x, z, R + 2)
      lava_pool(x, z, R)
      pools = pools + 1
    end
  end
  -- Vents steaming on the slopes.
  for _ = 1, 40 do
    local x, z = K.spot(8)
    if x and free(x, z, 3) and river(x, z) > 5 then
      claim(x, z, 2.5)
      vent(x, z, g:range(1.1, 2.0))
    end
  end
  -- Pumice boulders, pale against the black.
  for k = 1, 150 do
    local x, z = K.spot(5)
    if x and free(x, z, 2) then
      local rr = g:range(0.6, 2.1)
      K.ball(K.sub(K.solid, "pumice" .. (k % 3)), v3(x, K.ground(x, z) + rr * 0.4, z), rr, rr * 0.75, rr * g:range(0.8, 1.2), 6, 4,
        function() return g:range(0.78, 1.18) end, K.shaded(PUMICE))
    end
  end
  -- Palms in clumps further out.
  for _ = 1, 110 do
    local x, z = K.spot(7)
    if x and free(x, z, 1.5) and river(x, z) > 6 then
      claim(x, z, 1.2)
      local a = g:range(0, 6.28)
      palm(v3(x, 0, z), g:range(0.9, 1.5), v3(math.cos(a), 0, math.sin(a)))
    end
  end
end

return T
