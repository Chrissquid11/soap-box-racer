-- The Grand Canyon's scenery kit (see THEME KITS in _course.lua): banded sandstone all round -- cliff slabs and hoodoos
-- beside the road, buttes and mesas on the slopes, two rows of canyon wall round the valley, the far wall across the
-- Colorado beyond the bottom edge -- a stone lookout with its railing, ramada, viewers, flag and tourists, the park's
-- sign after the start, RVs on gravel pads, and the desert's plants: sagebrush, rabbitbrush, juniper, saguaro.
local T = {trees = 0}

function T.build(K)
  local Y = v3(0, 1, 0)
  local pi = math.pi
  local function rnd(a, b) return K.g:range(a, b) end
  local N, pos, right, W = K.N, K.pos, K.right, K.W
  local EDGE = K.WALL_T + 1          -- nothing nearer the road's edge than this

  -- How many triangles the kit adds (said at the end).
  local function tris(b)
    local n = 0
    for _, f in ipairs(b.fs) do n = n + #f - 2 end
    for _, q in ipairs(b.more or {}) do for _, f in ipairs(q.fs) do n = n + #f - 2 end end
    return n
  end
  local before = tris(K.solid) + tris(K.deco)

  -- The strata: one colour a band of height, the same band the same colour on every formation (so the layers line
  -- up across the canyon), some bands cliffs (near vertical) and the rest slopes (stepping in).
  local BH = 3.2
  local RED, ORANGE, CREAM = K.col(0.56, 0.15, 0.07), K.col(0.82, 0.36, 0.1), K.col(0.88, 0.72, 0.5)
  local RUST, BUFF, MAROON = K.col(0.68, 0.23, 0.08), K.col(0.9, 0.58, 0.3), K.col(0.4, 0.11, 0.08)
  local PINK = K.col(0.8, 0.42, 0.3)
  local SEQ = {RED, ORANGE, CREAM, RUST, RED, BUFF, MAROON, ORANGE, PINK, CREAM, RUST, ORANGE, RED, BUFF}
  local DARK = {}
  for _, c in ipairs(SEQ) do DARK[c] = K.tint(c, 0.8) end
  local function band_col(i) return SEQ[i % #SEQ + 1] end
  local function cliffy(i) return K.hash(i, 7.3) < 0.55 end
  local SUN = 0.9

  -- Rock goes into pieces of a few formations each (each piece painted alone).
  local nrock = {}
  local function rock(b, per)
    nrock[b] = (nrock[b] or 0) + 1
    return K.sub(b, "rock" .. math.floor(nrock[b] / (per or 5)))
  end

  -- A lathe of n-sided rings (prof: a list of {y, r}), each vertex's radius its own (m) so the outline is ragged;
  -- squashed to rx by rz and turned by ang. colour(j, lit) a band's.
  local function lathe(b, cx, cz, prof, rx, rz, n, ang, sd, colour, cap)
    local ca, sa = math.cos(ang), math.sin(ang)
    local dx, dz, lit = {}, {}, {}
    for k = 1, n do
      local a = (k - 1) / n * 2 * pi
      local m = 0.82 + 0.36 * K.hash(sd + k * 1.7, 3.1)
      local px, pz = math.cos(a) * rx * m, math.sin(a) * rz * m
      dx[k], dz[k] = px * ca - pz * sa, px * sa + pz * ca
      lit[k] = math.cos((k - 0.5) / n * 2 * pi + ang - SUN) > -0.25
    end
    local rings = {}
    for j, p in ipairs(prof) do
      local out = {}
      local f, y = p[2], p[1]
      for k = 1, n do
        local m = f * (0.96 + 0.08 * ((sd * 7.13 + k * 3.7 + j * 5.3) % 1))
        out[k] = v3(cx + dx[k] * m, y, cz + dz[k] * m)
      end
      rings[j] = out
    end
    K.prism(b, rings, function(j, k) return colour(j, lit[k]) end, cap, cap)
  end

  -- A formation of strata from y0 to y1: an ellipse rx by rz (rx along ang), in to `taper` of it at the top.
  local function formation(b, cx, cz, y0, y1, rx, rz, taper, n, ang, cap)
    local i0, i1 = math.floor(y0 / BH), math.floor((y1 - 0.05) / BH)
    local tot = 0
    for i = i0, i1 do tot = tot + (cliffy(i) and 0.12 or 1) end
    local prof, cols = {{y0, 1}}, {}
    local cum = 0
    for i = i0, i1 do
      cum = cum + (cliffy(i) and 0.12 or 1)
      prof[#prof + 1] = {math.min(y1, (i + 1) * BH), 1 - (1 - taper) * cum / tot}
      cols[#prof - 1] = band_col(i)
    end
    lathe(b, cx, cz, prof, rx, rz, n, ang, cx * 0.731 + cz * 0.377, function(j, lit)
      return lit and cols[j] or DARK[cols[j]]
    end, cap or K.tint(cols[#cols], 1.1))
  end

  -- A hoodoo: a thin waisted spire of thin bands under a wider cap rock.
  local HOO = {{0, 1}, {0.14, 0.78}, {0.28, 0.9}, {0.42, 0.6}, {0.56, 0.72}, {0.7, 0.48}, {0.8, 0.44}, {0.83, 0.86}, {0.93, 0.8}, {1, 0.36}}
  local function hoodoo(b, x, z, r, h)
    local y0 = K.ground(x, z) - 0.8
    local prof, cols = {}, {}
    for j, p in ipairs(HOO) do prof[j] = {y0 + p[1] * h, p[2]} end
    for j = 1, #HOO - 1 do
      cols[j] = (j >= 8) and MAROON or band_col(math.floor((prof[j][1] + prof[j + 1][1]) / 2 / 1.3))
    end
    lathe(b, x, z, prof, r, r, 6, rnd(0, 6), x * 1.31 + z * 0.77, function(j, lit) return lit and cols[j] or DARK[cols[j]] end, RUST)
  end

  -- How far (x, z) is off the road's edge; whether a disc of radius r there keeps the road's clearance.
  local function off_road(x, z)
    local _, d = K.ground_d(x, z)
    return d - K.HW
  end
  local function clear(x, z, r) return off_road(x, z) > EDGE + r + 0.3 end
  local function inside(x, z, m) return x > K.X0 + m and x < K.X1 - m and z > K.Z1 + m and z < K.Z0 - m end
  -- What is built already (pads, formations): nothing else stands in them.
  local big, CELL = {}, 24
  local function free(x, z, r)
    local list = big[math.floor(x / CELL) * 4096 + math.floor(z / CELL)]
    if not list then return true end
    for _, e in ipairs(list) do
      local dx, dz = x - e[1], z - e[2]
      local rr = e[3] + r
      if dx * dx + dz * dz < rr * rr then return false end
    end
    return true
  end
  -- (Kept by cell, in every cell it could matter to a thing up to 12 m across; a bigger thing asking may miss a
  -- neighbour in the next cell, which only lets two rocks merge.)
  local function take(x, z, r)
    local e = {x, z, r}
    local m = r + 12
    for gx = math.floor((x - m) / CELL), math.floor((x + m) / CELL) do
      for gz = math.floor((z - m) / CELL), math.floor((z + m) / CELL) do
        local key = gx * 4096 + gz
        big[key] = big[key] or {}
        big[key][#big[key] + 1] = e
      end
    end
  end
  -- A point beside the road, lo to hi beyond the clearance of a thing of radius r (nearer more often), or nil.
  local function near(lo, hi, r)
    for _ = 1, 4 do
      local i = math.max(1, math.min(N, math.floor(rnd(1, N + 1))))
      local s = (rnd(0, 1) < 0.5) and -1 or 1
      local o = EDGE + r + lo + (hi - lo) * rnd(0, 1) ^ 1.7
      local p = pos[i] + right[i] * (s * (W[i] + o))
      if inside(p.x, p.z, 4) and free(p.x, p.z, r) and clear(p.x, p.z, r) then return p.x, p.z end
    end
    return nil
  end

  -- A box of one colour, in that colour's piece of b (no painting): centre c, w along r, h up, d along t.
  local function box(b, colour, c, r, t, w, h, d)
    local q = K.sub(b, colour)
    q.ink = colour
    K.road_box(q, c, r, t, w, h, d)
  end
  local function post(b, colour, x, z, y0, y1, r0, r1, n)
    K.column(K.sub(b, colour), x, z, y0, y1, r0, r1 or r0, n or 5, colour)
  end
  local function one() return 1 end

  -- A level pad beside the road: the first sample from i0 to i1 (step by step) on `side` where a rectangle `depth`
  -- deep and 2 * hl long keeps clear of the road and of what is built, on ground within `rise` of level. Answers
  -- its centre, its axes (u along the road, w out from it), and its lowest and highest ground.
  local function pad(i0, i1, side, depth, hl, rise)
    local step = (i1 >= i0) and 3 or -3
    for i = math.max(12, math.min(N - 12, i0)), math.max(12, math.min(N - 12, i1)), step do
      local u, w = K.along(i), right[i] * side
      local c = pos[i] + w * (W[i] + EDGE + 0.6 + depth / 2)
      local ok, lo, hi = true, math.huge, -math.huge
      for a = -1, 1 do
        for bb = -1, 1 do
          local p = c + w * (a * depth / 2) + u * (bb * hl)
          if off_road(p.x, p.z) < EDGE + 0.4 then ok = false end
          local y = K.ground(p.x, p.z)
          lo, hi = math.min(lo, y), math.max(hi, y)
        end
      end
      local R = math.sqrt(depth * depth / 4 + hl * hl)
      if ok and hi - lo < rise and free(c.x, c.z, R * 0.8) and inside(c.x, c.z, 6) then
        take(c.x, c.z, R)
        return c, u, w, lo, hi, i
      end
    end
    return nil
  end
  local function sample(point) return math.floor((point - 1) * K.SUB + 1) end

  local STONE, STONE_DK, DECK = K.col(0.74, 0.56, 0.38), K.col(0.5, 0.34, 0.22), K.col(0.8, 0.66, 0.46)
  local WOOD, WOOD_DK = K.col(0.36, 0.2, 0.09), K.col(0.24, 0.13, 0.06)
  local STEEL, DARK_C = K.col(0.62, 0.64, 0.66), K.col(0.06, 0.07, 0.09)
  local SKIN = {K.col(0.85, 0.6, 0.45), K.col(0.55, 0.36, 0.24), K.col(0.93, 0.72, 0.56)}
  local SHIRTS = {K.col(0.9, 0.1, 0.1), K.col(0.1, 0.4, 0.9), K.col(1, 0.8, 0.05), K.col(0.1, 0.7, 0.3), K.col(0.95, 0.4, 0.7), K.col(0.95, 0.95, 0.95), K.col(1, 0.45, 0.05)}
  local LEGS = {K.col(0.12, 0.16, 0.32), K.col(0.6, 0.5, 0.32), K.col(0.2, 0.2, 0.2)}

  -- A tourist: legs, a bright shirt, a head, sometimes a sun hat.
  local function tourist(p, yaw)
    local r, t = v3(math.cos(yaw), 0, math.sin(yaw)), v3(-math.sin(yaw), 0, math.cos(yaw))
    local shirt, skin = K.pick(SHIRTS), K.pick(SKIN)
    box(K.deco, K.pick(LEGS), p + Y * 0.4, r, t, 0.34, 0.8, 0.22)
    box(K.deco, shirt, p + Y * 1.1, r, t, 0.46, 0.62, 0.27)
    K.ball(K.sub(K.deco, skin), p + Y * 1.58, 0.15, 0.17, 0.15, 5, 3, one, K.flat(skin))
    if rnd(0, 1) < 0.5 then box(K.deco, DECK, p + Y * 1.76, r, t, 0.5, 0.06, 0.5) end
  end

  -- The lookout: on the flat straight below the first bends, on the valley side -- a stone terrace with a rail all
  -- round, a ramada for shade, two coin viewers, the flag, and tourists.
  ;(function()
    local c, u, w, lo, hi
    for _, side in ipairs({1, -1}) do
      c, u, w, lo, hi = pad(sample(5.6), sample(9), side, 7, 6.2, 5)
      if c then break end
    end
    if not c then c, u, w, lo, hi = pad(sample(3), N - 30, 1, 7, 6.2, 5) end
    if not c then return end
    local hu, hw = 6, 3.5
    local ty = hi + 0.5
    local function at(a, bb, y) return v3(c.x, ty + (y or 0), c.z) + u * a + w * bb end
    box(K.solid, STONE, v3(c.x, (lo - 1 + ty) / 2, c.z), w, u, hw * 2, ty - lo + 1, hu * 2)
    box(K.solid, STONE_DK, at(0, 0, -0.5), w, u, hw * 2 + 0.16, 0.3, hu * 2 + 0.16)
    box(K.solid, DECK, at(0, 0, 0.01), w, u, hw * 2 - 0.3, 0.1, hu * 2 - 0.3)
    -- The rail: posts, a top rail and a mid rail on every edge.
    for a = -hu + 0.2, hu - 0.19, (hu * 2 - 0.4) / 6 do
      for _, s in ipairs({-1, 1}) do box(K.solid, WOOD_DK, at(a, s * (hw - 0.2), 0.5), w, u, 0.16, 1.3, 0.16) end
    end
    for bb = -hw + 0.2 + (hw * 2 - 0.4) / 4, hw - 0.3, (hw * 2 - 0.4) / 4 do
      for _, s in ipairs({-1, 1}) do box(K.solid, WOOD_DK, at(s * (hu - 0.2), bb, 0.5), w, u, 0.16, 1.3, 0.16) end
    end
    for _, s in ipairs({-1, 1}) do
      box(K.solid, WOOD, at(0, s * (hw - 0.2), 1.05), w, u, 0.1, 0.1, hu * 2 - 0.3)
      box(K.solid, WOOD, at(0, s * (hw - 0.2), 0.58), w, u, 0.08, 0.08, hu * 2 - 0.34)
      box(K.solid, WOOD, at(s * (hu - 0.2), 0, 1.03), w, u, hw * 2 - 0.5, 0.1, 0.1)
      box(K.solid, WOOD, at(s * (hu - 0.2), 0, 0.56), w, u, hw * 2 - 0.54, 0.08, 0.08)
    end
    -- The ramada over one end.
    for _, a in ipairs({-hu + 1, -hu + 5}) do
      for _, s in ipairs({-1, 1}) do box(K.solid, WOOD_DK, at(a, s * (hw - 1), 1.4), w, u, 0.26, 3, 0.26) end
    end
    box(K.solid, RUST, at(-hu + 3, 0, 3), w, u, hw * 2 - 0.7, 0.24, 5.4)
    box(K.solid, WOOD_DK, at(-hu + 3, 0, 2.82), w, u, hw * 2 - 1.2, 0.14, 4.9)
    -- Coin viewers on the valley side, and a bench under the ramada.
    for _, a in ipairs({1.2, 3.8}) do
      local p = at(a, hw - 0.9)
      post(K.solid, DARK_C, p.x, p.z, ty - 0.05, ty + 1.25, 0.09, 0.07)
      box(K.solid, STEEL, at(a, hw - 0.9, 1.4), w, u, 0.5, 0.3, 0.34)
      box(K.solid, DARK_C, at(a, hw - 1.2, 1.4), w, u, 0.12, 0.2, 0.22)
    end
    box(K.solid, WOOD, at(-hu + 3, -0.4, 0.45), w, u, 0.5, 0.1, 2.4)
    box(K.solid, WOOD_DK, at(-hu + 2.1, -0.4, 0.22), w, u, 0.4, 0.45, 0.12)
    box(K.solid, WOOD_DK, at(-hu + 3.9, -0.4, 0.22), w, u, 0.4, 0.45, 0.12)
    -- The flag.
    local fp = at(hu - 0.7, -hw + 0.7)
    post(K.solid, K.WHITE_C, fp.x, fp.z, ty - 0.05, ty + 8, 0.08, 0.05)
    local RED_F, BLUE_F = K.col(0.8, 0.05, 0.08), K.col(0.05, 0.1, 0.5)
    for k = 0, 6 do
      box(K.deco, (k % 2 == 0) and RED_F or K.WHITE_C, at(hu - 0.7 - 1.25, -hw + 0.7, 7.85 - k * 0.19), u, w, 2.3, 0.185, 0.05)
    end
    box(K.deco, BLUE_F, at(hu - 0.7 - 0.6, -hw + 0.7, 7.47), u, w, 1, 0.76, 0.09)
    for _ = 1, 7 do
      tourist(at(rnd(-hu + 0.8, hu - 1.4), rnd(-hw + 1.2, hw - 0.7), 0.06), rnd(0, 6.3))
    end
  end)()

  -- The park's sign, soon after the start, facing up the road: a brown board with cream lettering and the
  -- arrowhead, between two stone pillars on a stone plinth.
  ;(function()
    local c, u, w, lo, hi
    for _, side in ipairs({-1, 1}) do
      c, u, w, lo, hi = pad(K.start + 16, K.start + 70, side, 7, 1, 4)
      if c then break end
    end
    if not c then return end
    local ty = hi + 0.9
    local function at(a, bb, y) return v3(c.x, ty + (y or 0), c.z) + w * a + u * bb end
    box(K.solid, STONE, v3(c.x, (lo - 0.6 + ty) / 2, c.z), w, u, 6.6, ty - lo + 0.6, 1.3)
    for _, s in ipairs({-1, 1}) do
      box(K.solid, STONE, at(s * 2.9, 0, 1.4), w, u, 0.9, 3.2, 1.1)
      box(K.solid, STONE_DK, at(s * 2.9, 0, 3.08), w, u, 1.06, 0.2, 1.26)
    end
    box(K.solid, WOOD, at(0, 0, 1.45), w, u, 5.2, 2.2, 0.22)
    local CREAM_P = K.col(0.95, 0.88, 0.7)
    box(K.deco, CREAM_P, at(0.6, 0, 2.0), w, u, 2.9, 0.36, 0.3)
    box(K.deco, CREAM_P, at(0.6, 0, 1.45), w, u, 3.4, 0.36, 0.3)
    box(K.deco, CREAM_P, at(0.6, 0, 0.9), w, u, 2.2, 0.2, 0.3)
    -- The arrowhead: point down.
    local TAN, GREEN_A = K.col(0.78, 0.6, 0.34), K.col(0.1, 0.3, 0.12)
    local function head(d)
      local o = at(-1.85, d, 1.45)
      return {o + w * -0.42 + Y * 0.7, o + w * 0.42 + Y * 0.7, o + w * 0.5 + Y * 0.05, o + Y * -0.75, o + w * -0.5 + Y * 0.05}
    end
    local q = K.sub(K.deco, TAN)
    K.prism(q, {head(-0.16), head(0.16)}, K.flat(TAN), TAN, TAN)
    box(K.deco, GREEN_A, at(-1.85, 0, 1.62), w, u, 0.34, 0.5, 0.38)
  end)()

  -- RVs on gravel pads beside the flat stretches: a white box body with a cab, stripes, dark windows, four wheels
  -- and a roof box.
  local GRAVEL, RV_W = K.col(0.62, 0.5, 0.4), K.col(0.93, 0.92, 0.88)
  local STRIPES = {K.col(0.95, 0.4, 0.05), K.col(0.05, 0.5, 0.55), K.col(0.7, 0.1, 0.1), K.col(0.15, 0.3, 0.7)}
  local function rv(i0, i1, side)
    local c, u, w, lo, hi = pad(i0, i1, side, 3.6, 4.6, 1.8)
    if not c then return false end
    if rnd(0, 1) < 0.5 then u = u * -1 end
    local py = hi + 0.06
    box(K.solid, GRAVEL, v3(c.x, (lo - 0.5 + py) / 2, c.z), w, u, 3.5, py - lo + 0.5, 9)
    local function at(a, bb, y) return v3(c.x, py + y, c.z) + u * a + w * bb end
    local stripe = K.pick(STRIPES)
    box(K.solid, RV_W, at(-0.6, 0, 1.85), w, u, 2.4, 2.5, 5.6)
    box(K.solid, RV_W, at(2.9, 0, 1.3), w, u, 2.26, 1.4, 1.9)
    box(K.solid, RV_W, at(2.75, 0, 2.6), w, u, 2.34, 0.9, 1.5)
    box(K.solid, DARK_C, at(3.72, 0, 1.6), w, u, 2.0, 0.6, 0.3)
    box(K.solid, stripe, at(-0.6, 0, 1.5), w, u, 2.46, 0.34, 5.3)
    box(K.solid, K.tint(stripe, 0.6), at(-0.6, 0, 1.15), w, u, 2.45, 0.12, 5.2)
    box(K.solid, DARK_C, at(-2, 0, 2.3), w, u, 2.47, 0.62, 1.3)
    box(K.solid, DARK_C, at(0.4, 0, 2.3), w, u, 2.47, 0.62, 1.5)
    box(K.solid, DARK_C, at(2.9, 0, 1.62), w, u, 2.3, 0.5, 0.9)
    box(K.solid, STEEL, at(-1, 0, 3.2), w, u, 0.9, 0.3, 1.1)
    box(K.solid, STEEL, at(-3.48, 0, 0.75), w, u, 2.2, 0.22, 0.2)
    local tyre = K.sub(K.solid, DARK_C)
    for _, a in ipairs({-2.3, 2.6}) do
      for _, s in ipairs({-1, 1}) do
        local o = at(a, s * 1.05, 0.46)
        local rings = {}
        for e = 1, 2 do
          rings[e] = {}
          for k = 1, 8 do
            local an = (k - 0.5) / 8 * 2 * pi
            rings[e][k] = o + w * ((e * 2 - 3) * 0.16) + u * (math.cos(an) * 0.44) + Y * (math.sin(an) * 0.44)
          end
        end
        K.prism(tyre, rings, K.flat(DARK_C), DARK_C, DARK_C)
      end
    end
    return true
  end
  local rvs = 0
  for _, span in ipairs({{5.3, 9, -1}, {5.3, 9, 1}, {13, 16.5, 1}, {13, 16.5, -1}, {23, 26.5, -1}, {34, 37.5, 1}, {46.5, 50, -1}, {46.5, 50, 1}, {1.3, 2, 1}}) do
    if rvs < 6 and rv(sample(span[1]), sample(span[2]), span[3]) then rvs = rvs + 1 end
  end

  -- Beside the road: cliff slabs lying along it and clumps of hoodoos (not round the start or the finish).
  local function slab_clear(cx, cz, rx, rz, ang)
    local ca, sa = math.cos(ang), math.sin(ang)
    local lo, hi = math.huge, -math.huge
    for k = 0, 11 do
      local a = k / 12 * 2 * pi
      local px, pz = math.cos(a) * rx * 1.25, math.sin(a) * rz * 1.25
      local x, z = cx + px * ca - pz * sa, cz + px * sa + pz * ca
      if off_road(x, z) < EDGE + 0.5 then return nil end
      local y = K.ground(x, z)
      lo, hi = math.min(lo, y), math.max(hi, y)
    end
    return lo, hi
  end
  local function hoodoos(x, z, n)
    for k = 1, n do
      local r = rnd(0.9, 1.7)
      local hx, hz = x + ((k == 1) and 0 or rnd(-4.5, 4.5)), z + ((k == 1) and 0 or rnd(-4.5, 4.5))
      if clear(hx, hz, r * 1.2) and free(hx, hz, r) then
        hoodoo(rock(K.solid, 8), hx, hz, r, r * rnd(4.5, 7))
        take(hx, hz, r)
      end
    end
  end
  for i = 8, N - 8, 11 do
    for _, side in ipairs({-1, 1}) do
      local far = math.abs(i - K.start) > 22 and math.abs(i - K.fin) > 26
      local h = K.hash(i, side * 3.7)
      if far and h < 0.46 then
        local rx, rz = rnd(6, 10.5), rnd(2.8, 4.6)
        local u = K.along(i)
        local ang = math.atan(u.z, u.x)
        local c = pos[i] + right[i] * (side * (W[i] + EDGE + rz * 1.3 + rnd(0.8, 4.5)))
        local lo, hi = slab_clear(c.x, c.z, rx, rz, ang)
        if lo and free(c.x, c.z, rz) then
          formation(rock(K.solid, 4), c.x, c.z, lo - 1.5, hi + rnd(6, 14), rx, rz, rnd(0.62, 0.8), 10, ang)
          take(c.x, c.z, rz * 1.1)
          take(c.x + u.x * rx * 0.6, c.z + u.z * rx * 0.6, rz)
          take(c.x - u.x * rx * 0.6, c.z - u.z * rx * 0.6, rz)
        end
      elseif far and h < 0.62 then
        local c = pos[i] + right[i] * (side * (W[i] + EDGE + rnd(3, 8)))
        hoodoos(c.x, c.z, 3)
      end
    end
  end

  -- On the slopes: buttes (tall, tapering) and mesas (broad, flat-topped), and more hoodoos.
  for _ = 1, 30 do
    local r = rnd(5.5, 10)
    local x, z = near(5, 34, r)
    if x then
      local y = K.ground(x, z)
      formation(rock(K.solid, 4), x, z, y - 3, y + r * rnd(2.2, 3.6), r, r * rnd(0.7, 1), rnd(0.4, 0.6), 10, rnd(0, 3.1))
      take(x, z, r)
    end
  end
  for _ = 1, 16 do
    local x, z = K.spot(24)
    if x and inside(x, z, 16) and free(x, z, 15) then
      local r = rnd(11, 17)
      local y = K.ground(x, z)
      formation(rock(K.solid, 4), x, z, y - 5, y + rnd(11, 20), r, r * rnd(0.6, 0.9), rnd(0.74, 0.86), 12, rnd(0, 3.1))
      take(x, z, r)
    end
  end
  for _ = 1, 22 do
    local x, z = near(1, 26, 2)
    if x then hoodoos(x, z, math.floor(rnd(2, 4.99))) end
  end

  -- Round the valley: a row of canyon wall on its edge and a higher row behind it (the top and both sides; the
  -- bottom is open to the river).
  local function wall(x, z, gx, gz, rx, rz, ang, y0, up)
    local gy = K.ground(gx, gz)
    formation(rock(K.deco, 3), x, z, gy + y0, gy + up, rx, rz, 0.72, 8, ang)
  end
  for z = K.Z0 + 8, K.Z1 + 10, -25 do
    for _, e in ipairs({{K.X0, -1}, {K.X1, 1}}) do
      local gz = math.min(K.Z0 - 1, z)
      wall(e[1] + e[2] * 7 + rnd(-2, 2), z + rnd(-3, 3), e[1] - e[2], gz, rnd(15, 19), rnd(11, 14), pi / 2, -4, rnd(24, 46))
    end
  end
  for x = K.X0 + 12, K.X1 - 12, 25 do
    wall(x + rnd(-3, 3), K.Z0 + 7 + rnd(-2, 2), x, K.Z0 - 1, rnd(15, 19), rnd(11, 14), 0, -4, rnd(24, 46))
  end
  for z = K.Z0 + 30, K.Z1 + 20, -42 do
    for _, e in ipairs({{K.X0, -1}, {K.X1, 1}}) do
      local gz = math.min(K.Z0 - 1, z)
      wall(e[1] + e[2] * 36 + rnd(-4, 4), z + rnd(-5, 5), e[1] - e[2], gz, rnd(26, 32), rnd(20, 25), pi / 2, 14, rnd(58, 92))
    end
  end
  for x = K.X0 + 5, K.X1 - 5, 42 do
    wall(x + rnd(-5, 5), K.Z0 + 36 + rnd(-4, 4), x, K.Z0 - 1, rnd(26, 32), rnd(20, 25), 0, 14, rnd(58, 92))
  end

  -- The Colorado, beyond the bottom edge: green water with sand bars and white riffles, the far wall of the canyon
  -- across it as high as the rim, and a wall closing either end.
  local low = math.huge
  for i = 1, N do low = math.min(low, pos[i].y) end
  local yr = low + 5
  local RX0, RX1, RZ0, RZ1 = K.X0 - 190, K.X1 + 190, K.Z1 + 3, K.Z1 - 200
  local WATER, FOAM, SAND = K.col(0.08, 0.5, 0.42), K.col(0.8, 0.95, 0.9), K.col(0.9, 0.74, 0.5)
  local rc = v3((RX0 + RX1) / 2, yr - 1, (RZ0 + RZ1) / 2)
  box(K.deco, WATER, rc, v3(1, 0, 0), v3(0, 0, 1), RX1 - RX0, 2, RZ0 - RZ1)
  for k = 1, 16 do
    local x, z = rnd(RX0 + 60, RX1 - 60), rnd(RZ1 + 40, RZ0 - 30)
    box(K.deco, FOAM, v3(x, yr + 0.06 + k * 0.004, z), v3(1, 0, 0), v3(0, 0, 1), rnd(14, 34), 0.1, rnd(1.5, 3.5))
  end
  for _ = 1, 6 do
    local x, z = rnd(RX0 + 60, RX1 - 60), rnd(RZ1 + 40, RZ0 - 30)
    lathe(K.sub(K.deco, SAND), x, z, {{yr - 0.5, 1}, {yr + 0.5, 0.8}}, rnd(14, 30), rnd(5, 9), 9, rnd(-0.3, 0.3), x, function() return SAND end, SAND)
  end
  local rim = pos[1].y
  for x = RX0, RX1, 48 do
    formation(rock(K.deco, 2), x + rnd(-6, 6), RZ1 - 6 + rnd(-8, 8), yr - 2, math.max(yr + 70, rim + rnd(-30, 14)), rnd(32, 40), rnd(22, 30), 0.6, 8, 0)
  end
  for z = RZ0 + 20, RZ1, -55 do
    for _, x in ipairs({RX0 - 4, RX1 + 4}) do
      formation(rock(K.deco, 2), x + rnd(-6, 6), z, yr - 2, yr + rnd(70, 110), rnd(34, 40), rnd(24, 30), 0.62, 8, pi / 2)
    end
  end
  -- (Buttes standing on the far bank's foot.)
  for _ = 1, 7 do
    local x, r = rnd(RX0 + 40, RX1 - 40), rnd(9, 15)
    formation(rock(K.deco, 3), x, RZ1 + 34 + rnd(-8, 22), yr - 1.5, yr + rnd(22, 46), r, r * 0.8, 0.5, 8, rnd(0, 3))
  end

  -- The desert's plants and stones, mostly near the road.
  local SAGE = {K.col(0.42, 0.5, 0.34), K.col(0.5, 0.56, 0.4), K.col(0.34, 0.44, 0.24), K.col(0.86, 0.72, 0.1), K.col(0.72, 0.62, 0.3)}
  local JUN, BARK = {K.col(0.13, 0.3, 0.12), K.col(0.18, 0.36, 0.16), K.col(0.1, 0.25, 0.14)}, K.col(0.42, 0.34, 0.28)
  local CACTUS = {K.col(0.2, 0.48, 0.18), K.col(0.26, 0.54, 0.2)}
  local function lump() return rnd(0.8, 1.2) end
  local function somewhere(lo, hi, r, share)
    if rnd(0, 1) < share then return near(lo, hi, r) end
    local x, z = K.spot(EDGE + r + 1)
    if x and free(x, z, r) then return x, z end
    return nil
  end
  -- Sagebrush and rabbitbrush: low lumpy mounds.
  for k = 1, 470 do
    local x, z = somewhere(0, 22, 0.8, 0.8)
    if x then
      local c = (k % 6 == 0) and SAGE[4] or ((k % 9 == 0) and SAGE[5] or SAGE[k % 3 + 1])
      local s = rnd(0.6, 1.3)
      K.ball(K.sub(K.deco, "sage" .. (k % 6)), v3(x, K.ground(x, z) + 0.25 * s, z), 0.8 * s, 0.6 * s, 0.75 * s, 6, 3, lump, K.shaded(c))
    end
  end
  -- Junipers: a short twisted trunk under dark green clumps.
  for k = 1, 85 do
    local x, z = somewhere(1, 30, 1.6, 0.7)
    if x then
      local y, s = K.ground(x, z), rnd(0.8, 1.5)
      local q = K.sub(K.deco, "juniper" .. (k % 4))
      local lx, lz = rnd(-0.4, 0.4) * s, rnd(-0.4, 0.4) * s
      K.prism(q, {K.ring(v3(x, y - 0.3, z), 0.26 * s, 0.26 * s, 5, 0), K.ring(v3(x + lx, y + 1.5 * s, z + lz), 0.14 * s, 0.14 * s, 5, 0.6)}, K.flat(BARK), BARK, BARK)
      local green = JUN[k % 3 + 1]
      K.ball(q, v3(x + lx, y + 2.1 * s, z + lz), 1.3 * s, 1.0 * s, 1.3 * s, 7, 4, lump, K.shaded(green))
      K.ball(q, v3(x + lx + 0.8 * s, y + 1.5 * s, z + lz + rnd(-0.6, 0.6) * s), 0.9 * s, 0.7 * s, 0.9 * s, 6, 4, lump, K.shaded(green))
      K.ball(q, v3(x + lx - 0.7 * s, y + 1.7 * s, z + lz + rnd(-0.6, 0.6) * s), 0.8 * s, 0.65 * s, 0.85 * s, 6, 4, lump, K.shaded(green))
      take(x, z, 0.8)
    end
  end
  -- Saguaros: a ribbed green trunk with a rounded top and an arm or two turned up.
  for k = 1, 90 do
    local x, z = somewhere(0, 16, 1.4, 0.85)
    if x then
      local y, s = K.ground(x, z) - 0.3, rnd(0.8, 1.35)
      local green = CACTUS[k % 2 + 1]
      local shade = K.tint(green, 0.75)
      local q = K.sub(K.deco, "cactus" .. (k % 3))
      local function stem(cx, cz, y0, y1, r)
        K.prism(q, {K.ring(v3(cx, y0, cz), r, r, 6, 0.3), K.ring(v3(cx, y1 - r * 0.6, cz), r, r, 6, 0.3), K.ring(v3(cx, y1, cz), r * 0.5, r * 0.5, 6, 0.3)},
          function(_, kk) return (kk % 2 == 0) and green or shade end, shade, green)
      end
      local h, r = rnd(3.6, 5.8) * s, 0.36 * s
      stem(x, z, y, y + h, r)
      local a0 = rnd(0, 6.3)
      for arm = 1, math.floor(rnd(1, 3.3)) do
        local a = a0 + arm * 2.6
        local d = v3(math.cos(a), 0, math.sin(a))
        local side = v3(-d.z, 0, d.x)
        local ha, ra, out = y + h * rnd(0.36, 0.6), r * 0.68, r + rnd(0.5, 0.8) * s
        q.ink = green
        K.slab(q, v3(x, ha, z) + d * (r * 0.3), v3(x, ha, z) + d * (out + ra * 0.8), Y * ra, side * ra)
        stem(x + d.x * out, z + d.z * out, ha - ra * 0.7, ha + h * rnd(0.22, 0.4), ra * 0.92)
      end
    end
  end
  -- Loose boulders.
  for k = 1, 90 do
    local x, z = somewhere(0, 18, 1.5, 0.8)
    if x then
      local s = rnd(0.6, 1.7)
      local c = SEQ[k % 5 + 1]
      K.ball(K.sub(K.solid, "boulder" .. (k % 3)), v3(x, K.ground(x, z) + 0.2 * s, z), s * rnd(0.9, 1.4), s * 0.8, s * rnd(0.9, 1.3), 6, 4, lump, K.shaded(c))
    end
  end

  info(string.format("canyon kit: %d triangles, %d RVs", tris(K.solid) + tris(K.deco) - before, rvs))
end

return T
