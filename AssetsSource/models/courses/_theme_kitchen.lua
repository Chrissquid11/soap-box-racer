-- The Giant's Kitchen's scenery kit (see THEME KITS in _course.lua): the karts are toys on a giant's worktop. Beside
-- the road: a chopping board with its knife and a carrot, a sink with taps, rows of sausages and a frying pan, jars,
-- teapots, mugs, toasters, whisks, pots of utensils, cupboard units; a tiled backsplash round the valley's edges;
-- peas and crumbs scattered. No trees.
local T = {trees = 0}

function T.build(K)
  local Y = v3(0, 1, 0)
  local col, tint, hash, g = K.col, K.tint, K.hash, K.g
  local HW, WALL_T, N = K.HW, K.WALL_T, K.N
  local PI = math.pi

  local WOOD, WOOD_D = col(0.74, 0.5, 0.25), col(0.55, 0.34, 0.15)
  local STEEL, STEEL_D = col(0.74, 0.78, 0.83), col(0.45, 0.48, 0.53)
  local BLACK, IRON, IRON_L = col(0.05, 0.05, 0.06), col(0.11, 0.11, 0.13), col(0.2, 0.2, 0.23)
  local WHITE, CREAM = col(0.95, 0.95, 0.93), col(0.92, 0.85, 0.68)
  local RED, BLUE, YELLOW = col(0.86, 0.1, 0.08), col(0.1, 0.33, 0.85), col(0.98, 0.76, 0.08)
  local GREEN, PEA, ORANGE = col(0.2, 0.55, 0.15), col(0.38, 0.78, 0.14), col(0.96, 0.44, 0.04)
  local TEAL, PINK = col(0.05, 0.62, 0.58), col(0.95, 0.4, 0.55)
  local SAUS, SAUS_HI, SAUS_D = col(0.66, 0.26, 0.13), col(0.82, 0.4, 0.2), col(0.4, 0.14, 0.07)
  local WATER, COFFEE = col(0.2, 0.58, 0.92), col(0.3, 0.16, 0.07)
  local TOAST, CRUST = col(0.9, 0.66, 0.3), col(0.5, 0.27, 0.09)
  local GROUT, GLASS = col(0.62, 0.62, 0.6), col(0.8, 0.9, 0.9)

  -- A piece of the solid part (or the drawn-only one) for a key: a colour (its ink set) or a name (several colours).
  local function S(key) local b = K.sub(K.solid, key); if type(key) == "table" then b.ink = key end; return b end
  local function D(key) local b = K.sub(K.deco, key); if type(key) == "table" then b.ink = key end; return b end

  local function vert(b, p) b.vs[#b.vs + 1] = p; return #b.vs end
  local function face(b, ids, want, c)
    local a = b.vs[ids[1]]
    local n = cross(b.vs[ids[2]] - a, b.vs[ids[3]] - a)
    if dot(n, want) < 0 then
      local r = {}
      for i = #ids, 1, -1 do r[#r + 1] = ids[i] end
      ids = r
    end
    b.fs[#b.fs + 1] = ids
    b.cs[#b.fs] = c
  end

  -- Frames: an origin and three axes (x, y up, z); a point in one.
  local function frame(o, x, y, z) return {o = o, x = x, y = y, z = z} end
  local function at(F, x, y, z) return F.o + F.x * x + F.y * y + F.z * z end
  local function shift(F, x, y, z) return frame(at(F, x, y, z), F.x, F.y, F.z) end
  local function turned(F, deg)
    local a = math.rad(deg)
    local c, s = math.cos(a), math.sin(a)
    return frame(F.o, F.x * c + F.z * s, F.y, F.z * c - F.x * s)
  end
  local function scaled(F, s) return frame(F.o, F.x * s, F.y * s, F.z * s) end
  -- Turned by yaw, moved r0 out and y0 up, then leant `tilt` degrees outwards.
  local function lean(F, yaw, tilt, r0, y0)
    local G = turned(F, yaw)
    local a = math.rad(tilt)
    local c, s = math.cos(a), math.sin(a)
    return frame(at(G, r0, y0, 0), G.x * c - G.y * s, G.y * c + G.x * s, G.z)
  end

  -- A box in a frame: its middle and half sizes.
  local function box(b, F, cx, cy, cz, hx, hy, hz)
    local function v(x, y, z) return at(F, cx + x * hx, cy + y * hy, cz + z * hz) end
    K.hexa(b, v(-1,-1,-1), v(1,-1,-1), v(1,-1,1), v(-1,-1,1), v(-1,1,-1), v(1,1,-1), v(1,1,1), v(-1,1,1))
  end
  -- A shape turned about the frame's y axis at (cx, cz): its profile {r, y} from the axis, out and round, back to the
  -- axis (the outside on the right of the way along it); n sides; colour one, or colour(j) for the band from point j.
  local function lathe(b, F, cx, cz, prof, n, colour)
    local o = at(F, cx, 0, cz)
    local rings = {}
    for j, p in ipairs(prof) do
      if p[1] <= 1e-6 then
        rings[j] = vert(b, o + F.y * p[2])
      else
        local ids = {}
        for k = 0, n - 1 do
          local a = k / n * 2 * PI
          ids[k + 1] = vert(b, o + F.y * p[2] + (F.x * math.cos(a) + F.z * math.sin(a)) * p[1])
        end
        rings[j] = ids
      end
    end
    for j = 1, #prof - 1 do
      local p, q = prof[j], prof[j + 1]
      local dr, dy = q[1] - p[1], q[2] - p[2]
      local c = type(colour) == "function" and colour(j) or colour
      local A, B = rings[j], rings[j + 1]
      for k = 1, n do
        local k2 = k % n + 1
        local a = (k - 0.5) / n * 2 * PI
        local want = (F.x * math.cos(a) + F.z * math.sin(a)) * dy - F.y * dr
        if type(A) == "number" and type(B) == "number" then
        elseif type(A) == "number" then face(b, {A, B[k], B[k2]}, want, c)
        elseif type(B) == "number" then face(b, {A[k], A[k2], B}, want, c)
        else face(b, {A[k], A[k2], B[k2], B[k]}, want, c) end
      end
    end
  end
  -- A tube through points: radius one or one a point, n sides; colour one or colour(j, k).
  local function tube(b, pts, rad, n, colour)
    local rings = {}
    local u
    for j, p in ipairs(pts) do
      local t = normalize((pts[j + 1] or p) - (pts[j - 1] or p))
      if not u then
        u = cross(t, Y)
        if length(u) < 1e-3 then u = v3(1, 0, 0) end
      end
      u = normalize(u - t * dot(u, t))
      local w = cross(t, u)
      local r = type(rad) == "table" and rad[j] or rad
      local ring = {}
      for k = 0, n - 1 do
        local a = k / n * 2 * PI
        ring[k + 1] = p + (u * math.cos(a) + w * math.sin(a)) * r
      end
      rings[j] = ring
    end
    local fn = type(colour) == "function"
    local c0 = fn and colour(1, 1) or colour
    K.prism(b, rings, fn and colour or K.flat(colour), c0, c0)
  end
  local function path(F, m, fn)
    local pts = {}
    for s = 0, m do
      local x, y, z = fn(s / m)
      pts[#pts + 1] = at(F, x, y, z)
    end
    return pts
  end
  local function orb(b, c, rx, ry, rz, segs, rings, colour)
    K.ball(b, c, rx, ry, rz, segs, rings, function() return 1 end, function() return colour end)
  end

  -- Sites: how far a point is off the road's edge; places taken already.
  local function off_edge(x, z)
    local _, d = K.ground_d(x, z)
    return d - HW
  end
  local taken = {}
  local function rect_ok(x, z, t, r, a, b, need)
    for u = -2, 2 do
      for w = -1, 1 do
        local px, pz = x + t.x * a * u / 2 + r.x * b * w, z + t.z * a * u / 2 + r.z * b * w
        if px < K.X0 + 9 or px > K.X1 - 9 or pz < K.Z1 + 9 or pz > K.Z0 - 9 then return false end
        if off_edge(px, pz) < need then return false end
      end
    end
    local rad = math.max(a, b) * 0.85
    for _, q in ipairs(taken) do
      if (q[1] - x)^2 + (q[2] - z)^2 < (q[3] + rad + 1)^2 then return false end
    end
    return true
  end
  local function take(x, z, a, b) taken[#taken + 1] = {x, z, math.max(a, b) * 0.85} end
  local function flatdir(v) return normalize(v3(v.x, 0, v.z)) end
  -- Beside sample i on `side` (-1 left, 1 right): a footprint a along the road, b across it, `gap` off the wall.
  -- Calls fn(x, z, f, t): f towards the road, t down it.
  local function place(i, side, a, b, fn, gap)
    i = math.max(2, math.min(N - 1, i))
    gap = gap or 3.5
    local r, t = flatdir(K.right[i]), flatdir(K.along(i))
    local off = K.W[i] + WALL_T + gap + b
    for _ = 1, 24 do
      local c = K.pos[i] + r * (side * off)
      if rect_ok(c.x, c.z, t, r, a, b, WALL_T + gap - 0.6) then
        take(c.x, c.z, a, b)
        fn(c.x, c.z, r * (-side), t)
        return true
      end
      off = off + 2
    end
    return false
  end
  -- An upright frame at (x, z), z towards f, standing on the lower ground under its radius.
  local function stand(x, z, f, rad)
    local lo, hi = math.huge, -math.huge
    for k = 0, 8 do
      local a = k / 8 * 2 * PI
      local rr = (k == 8) and 0 or rad
      local y = K.ground(x + math.cos(a) * rr, z + math.sin(a) * rr)
      lo = math.min(lo, y); hi = math.max(hi, y)
    end
    return frame(v3(x, lo + (hi - lo) * 0.25, z), cross(Y, f), Y, f)
  end
  -- A frame lying on the ground at (x, z): x along h (flat), y the ground's normal there; over half sizes L, Wd.
  local function draped(x, z, h, L, Wd, up)
    local s = cross(h, Y)
    local function G(a, b)
      local px, pz = x + h.x * a + s.x * b, z + h.z * a + s.z * b
      return v3(px, K.ground(px, pz), pz)
    end
    local ux = normalize(G(L, 0) - G(-L, 0))
    local uz = normalize(G(0, Wd) - G(0, -Wd))
    local uy = normalize(cross(uz, ux))
    local o = (G(L, 0) + G(-L, 0) + G(0, Wd) + G(0, -Wd)) * 0.25
    return frame(o + uy * (up or 0), ux, uy, cross(ux, uy))
  end

  ---------------------------------------------------------------------------------------------------------------
  -- The things.

  local function sausage(F, len, r, key)
    local half = len / 2
    local xs = {-1, -0.93, -0.8, -0.45, 0, 0.45, 0.8, 0.93, 1}
    local rs = {0.3, 0.7, 1, 1, 1, 1, 1, 0.7, 0.3}
    local pts, rad = {}, {}
    for j, x in ipairs(xs) do
      pts[j] = at(F, x * half, r * 0.9, len * 0.09 * (1 - x * x))
      rad[j] = rs[j] * r
    end
    tube(key, pts, rad, 10, function(j, k)
      if j == 1 or j == #xs - 1 then return SAUS_D end
      return (k >= 7 and k <= 9) and SAUS_HI or SAUS
    end)
  end

  local function whisk(F, handle)
    lathe(S(handle), F, 0, 0, {{0, 0}, {0.6, 0}, {0.8, 3}, {0.6, 7.2}, {0, 7.2}}, 8, handle)
    local b = S(STEEL)
    for k = 0, 3 do
      local a = k * PI / 4
      local cx, cz = math.cos(a), math.sin(a)
      tube(b, path(F, 12, function(s)
        s = 0.06 + 0.88 * s
        local w = (2.9 - k * 0.12) * math.sin(2 * PI * s)
        return cx * w, 6.4 + (9.2 + k * 0.5) * (1 - math.cos(2 * PI * s)) / 2, cz * w
      end), 0.2, 5, STEEL)
    end
  end

  local function jar(x, z, f, content, lid, s)
    local F = scaled(stand(x, z, f, 3.4 * s), s)
    local b = S("jar")
    lathe(b, F, 0, 0, {{0, -1.5}, {3.4, -1.5}, {3.4, 1.6}, {3.4, 5}, {3.4, 6.5}, {2.6, 7.6}, {2.6, 8}, {2.95, 8}, {2.95, 9.6}, {0, 9.6}}, 14,
      function(j)
        if j == 3 then return WHITE elseif j == 5 or j == 6 then return GLASS elseif j >= 7 then return lid end
        return content
      end)
    box(S(content), F, 0, 3.3, 3.25, 1.4, 1.0, 0.3)
  end

  local function teapot(x, z, f, body, s, yaw)
    local F = turned(scaled(stand(x, z, f, 6.2 * s), s), yaw or 0)
    lathe(S("teapot"), F, 0, 0, {{0, -1.5}, {3.6, -1.5}, {5.3, 0.5}, {6.2, 3}, {6, 5.5}, {4.8, 7.6}, {2.9, 8.8}, {2.5, 9.5}, {0.7, 9.9},
      {0.7, 10.3}, {1.15, 10.9}, {0.6, 11.5}, {0, 11.5}}, 16,
      function(j)
        if j == 4 then return WHITE elseif j == 7 or j == 8 then return WHITE elseif j >= 9 then return YELLOW end
        return body
      end)
    local b = S(body)
    tube(b, {at(F, 4.6, 2.3, 0), at(F, 7.6, 3.4, 0), at(F, 9.2, 6, 0), at(F, 10.8, 8.4, 0)}, {1.6, 1.3, 0.95, 0.75}, 8, body)
    tube(b, path(F, 8, function(q)
      local a = PI / 2 + q * PI
      return -4.9 + math.cos(a) * 4.6, 4 + math.sin(a) * 3.3, 0
    end), 0.7, 6, body)
  end

  local function mug(x, z, f, c, stripe, s, yaw)
    local F = turned(scaled(stand(x, z, f, 3.6 * s), s), yaw or 0)
    lathe(S("mug"), F, 0, 0, {{0, -1.5}, {3.4, -1.5}, {3.6, 2}, {3.6, 4.6}, {3.6, 7.5}, {3.2, 7.5}, {3.1, 6.5}, {0, 6.5}}, 14,
      function(j)
        if j == 3 then return stripe elseif j == 6 then return WHITE elseif j == 7 then return COFFEE end
        return c
      end)
    tube(S(c), path(F, 8, function(q)
      local a = -PI / 2 + q * PI
      return 3.3 + math.cos(a) * 2.5, 3.4 + math.sin(a) * 2.3, 0
    end), 0.55, 6, c)
  end

  local function toaster(x, z, f, c)
    local F = stand(x, z, f, 7)
    box(S(c), F, 0, 3.5, 0, 7, 5, 4)
    box(S(BLACK), F, 0, -0.5, 0, 7.15, 1, 4.15)
    box(S(STEEL), F, 0, 8.9, 0, 6.6, 0.5, 3.6)
    for _, zz in ipairs({-1.6, 1.6}) do
      box(S(BLACK), F, 0, 9.2, zz, 5.2, 0.25, 0.8)
      box(S(CRUST), F, 0, 10.6, zz, 4.6, 3, 0.42)
      box(S(TOAST), F, 0, 10.6, zz, 4.2, 2.7, 0.5)
    end
    box(S(BLACK), F, 7.05, 4.5, 0, 0.1, 2.6, 0.4)
    box(S(BLACK), F, 7.6, 6.2, 0, 0.6, 0.5, 1.0)
    for _, zs in ipairs({-1, 1}) do
      local G = frame(at(F, 4.4, 2.6, 4 * zs), F.x, F.z * zs, F.y)
      lathe(S(WHITE), G, 0, 0, {{0, -0.3}, {1.1, -0.3}, {1.1, 0.4}, {0, 0.4}}, 10, WHITE)
      box(S(STEEL), F, -1.5, 5.5, 4.02 * zs, 3.6, 0.25, 0.1)
    end
  end

  local function utensil_pot(x, z, f, c, stripe)
    local F = stand(x, z, f, 4.6)
    lathe(S("pot"), F, 0, 0, {{0, -1.5}, {4.2, -1.5}, {4.4, 1.5}, {4.5, 3}, {4.6, 5.5}, {4.7, 8}, {4.2, 8}, {4.1, 7}, {0, 7}}, 14,
      function(j)
        if j == 3 or j == 5 then return stripe elseif j == 7 or j == 8 then return IRON end
        return c
      end)
    -- A wooden spoon, a spatula, a whisk and a fork, leaning out of it.
    local A = lean(F, 20, 14, 1.2, 5)
    tube(S(WOOD), {at(A, 0, 0, 0), at(A, 0, 12, 0)}, 0.45, 6, WOOD)
    orb(S(WOOD), at(A, 0, 13.4, 0), 1.5, 2.1, 1.5, 8, 5, WOOD)
    local B = lean(F, 140, 16, 1.2, 5)
    tube(S(STEEL), {at(B, 0, 0, 0), at(B, 0, 10, 0)}, 0.35, 6, STEEL)
    box(S(RED), B, 0, 12, 0, 0.3, 2.4, 1.7)
    whisk(scaled(lean(F, 255, 12, 1.0, 4.5), 0.85), TEAL)
    local E = lean(F, 320, 20, 1.6, 5)
    tube(S(STEEL), {at(E, 0, 0, 0), at(E, 0, 9.5, 0)}, 0.35, 6, STEEL)
    box(S(STEEL), E, 0, 10, 0, 0.2, 0.7, 1.3)
    for k = -1, 1 do box(S(STEEL), E, 0, 12, k * 0.95, 0.18, 1.6, 0.3) end
  end

  -- A cupboard unit: n doors facing the road under a worktop.
  local function cupboard(x, z, f, t, n, c)
    local half = n * 4.8
    local F = stand(x, z, f, half * 0.6)
    F = frame(F.o, cross(Y, f), Y, f)
    box(S(CREAM), F, 0, 5.5, -2.6, half - 0.2, 8, 2.6)
    box(S(WOOD), F, 0, 14.4, -2, half + 0.8, 0.7, 3.8)
    for k = 0, n - 1 do
      local dx = (k - (n - 1) / 2) * 9.6
      local hand = (k % 2 == 0) and 1 or -1
      box(S(c), F, dx, 5.6, 0.3, 4.6, 7.8, 0.6)
      box(S(tint(c, 1.25)), F, dx, 5.8, 0.95, 3.3, 6, 0.12)
      orb(S(YELLOW), at(F, dx + hand * 3.9, 6.5, 1.5), 0.7, 0.7, 0.7, 8, 5, YELLOW)
    end
  end

  local function chopping_board(x, z, f, t)
    local F = draped(x, z, t, 16, 10, 1.2)
    box(S(WOOD), F, 0, 0, 0, 16, 1.5, 10)
    local top = 1.5
    for k = -3, 3 do box(D(WOOD_D), F, 0, top, k * 2.8 + 0.6, 15.4, 0.05, 0.14) end
    lathe(D(WOOD_D), F, -13.2, 0, {{0, top - 0.3}, {1.4, top - 0.3}, {1.4, top + 0.06}, {0, top + 0.06}}, 10, WOOD_D)
    -- The knife, lying across it.
    local Kf = turned(shift(F, -3, top - 0.02, -4.5), -14)
    box(S(BLACK), Kf, -4.5, 0.7, 0, 4.5, 0.7, 1.0)
    for k = -1, 1 do lathe(D(STEEL), Kf, -4.5 + k * 2.6, 0, {{0, 1.3}, {0.35, 1.3}, {0.35, 1.46}, {0, 1.46}}, 6, STEEL) end
    local b = S(STEEL)
    local function v(xx, y, zz) return at(Kf, xx, y, zz) end
    K.hexa(b, v(-0.2, 0.45, -1.2), v(17.6, 0.45, -1.2), v(15, 0.45, 1.6), v(-0.2, 0.45, 2.6),
      v(-0.2, 0.85, -1.2), v(17.6, 0.85, -1.2), v(15, 0.85, 1.6), v(-0.2, 0.85, 2.6))
    box(D(WHITE), Kf, 6.5, 0.65, 1.55, 6, 0.215, 0.08)
    -- A carrot, half sliced.
    local C = turned(shift(F, 5, top, 4.2), 8)
    tube(S(ORANGE), {at(C, -1, 1.3, 0), at(C, 2, 1.3, 0), at(C, 6, 1.1, 0), at(C, 9, 0.7, 0)}, {1.4, 1.4, 1.1, 0.35}, 9,
      function(j, k) return (k >= 6 and k <= 8) and tint(ORANGE, 1.0) or tint(ORANGE, 0.82) end)
    for k = 0, 2 do
      tube(D(GREEN), {at(C, 8.8, 0.7, 0), at(C, 10.5, 1.0 + k * 0.5, (k - 1) * 0.9), at(C, 12, 1.2 + k * 0.4, (k - 1) * 1.8)}, {0.3, 0.35, 0.12}, 5, GREEN)
    end
    for k = 0, 4 do
      local sx, sz = -3.2 - k * 2.1, (hash(k, 5) - 0.5) * 3.5
      lathe(S("slices"), shift(F, 5 + sx, top - 0.05, 4.2 + sz), 0, 0, {{0, 0}, {1.4, 0}, {1.4, 0.55}, {0.8, 0.56}, {0, 0.56}}, 9,
        function(j) return (j == 4) and tint(ORANGE, 1.25) or ORANGE end)
    end
  end

  local function sink(x, z, f, t)
    local F = stand(x, z, f, 9)
    local b = S(WHITE)
    box(b, F, 0, 2, 8, 13, 4, 1)
    box(b, F, 0, 2, -8, 13, 4, 1)
    box(b, F, 12, 2, 0, 0.98, 3.99, 7.5)
    box(b, F, -12, 2, 0, 0.98, 3.99, 7.5)
    box(b, F, 0, 6.4, -10, 14, 0.5, 3.4)
    box(S(WATER), F, 0, 1.3, 0, 11.5, 3.2, 7.4)
    -- The mixer: a swan neck over the basin, running; a hot and a cold tap.
    local st = S(STEEL)
    lathe(st, F, 0, -10, {{0, 6.5}, {1.9, 6.5}, {1.6, 8}, {0, 8}}, 10, STEEL)
    tube(st, {at(F, 0, 7.5, -10), at(F, 0, 13.5, -10), at(F, 0, 16.5, -9), at(F, 0, 18, -6.5), at(F, 0, 17.6, -4), at(F, 0, 16, -2.6), at(F, 0, 14, -2.6)},
      1.0, 10, STEEL)
    tube(S(WATER), {at(F, 0, 14.6, -2.6), at(F, 0, 4.4, -2.6)}, {0.6, 0.75}, 8, WATER)
    for _, sx in ipairs({-1, 1}) do
      local c = (sx < 0) and RED or BLUE
      lathe(S("tap"), F, sx * 6.5, -10, {{0, 6.5}, {1.2, 6.5}, {0.8, 9.5}, {2.3, 9.7}, {2.3, 10.9}, {0, 11.1}}, 10,
        function(j) return (j >= 3) and c or STEEL end)
    end
    -- Suds.
    for k = 1, 7 do
      local r = 0.9 + hash(k, 3) * 1.2
      orb(D(WHITE), at(F, (hash(k, 1) - 0.5) * 18, 4.5 + r * 0.3, (hash(k, 2) - 0.5) * 10), r, r * 0.8, r, 7, 4, WHITE)
    end
    -- A sponge on the rim.
    box(S(YELLOW), F, 9.5, 7.6, -10, 2.4, 0.75, 1.5)
    box(S(GREEN), F, 9.5, 8.55, -10, 2.38, 0.22, 1.48)
  end

  local function pan(x, z, f, t)
    local F = stand(x, z, f, 9.5)
    F = frame(F.o, t, Y, cross(t, Y))
    lathe(S("pan"), F, 0, 0, {{0, -1.5}, {8, -1.5}, {9.6, 2.3}, {9.1, 2.3}, {7.8, 0.3}, {0, 0.3}}, 18,
      function(j) return (j >= 4) and IRON_L or IRON end)
    tube(S(BLACK), {at(F, -8.8, 1.6, 0), at(F, -13, 2.9, 0), at(F, -21, 3.5, 0)}, {1.0, 0.85, 0.85}, 8, BLACK)
    tube(S(RED), {at(F, -20.5, 3.46, 0), at(F, -22, 3.58, 0)}, 0.95, 8, RED)
    -- A fried egg and two sausages in it.
    local E = frame(at(F, 2.6, 0, 2.2), F.x * 1.15, F.y, F.z * 0.9)
    lathe(S(WHITE), E, 0, 0, {{0, 0.2}, {4.2, 0.2}, {3.9, 0.75}, {0, 0.85}}, 12, WHITE)
    lathe(S(YELLOW), E, 0.4, 0.2, {{0, 0.7}, {1.6, 0.7}, {1.35, 1.5}, {0.7, 1.95}, {0, 2.05}}, 10, YELLOW)
    sausage(turned(shift(F, -2.5, 0.2, -3.6), 20), 8.5, 1.05, S("sausage"))
    sausage(turned(shift(F, -4, 0.2, 1.2), 75), 7.5, 1.0, S("sausage"))
  end

  -- A row of sausages beside sample i on `side`, each along the road, the row running out from it.
  local function sausages(i, side, n)
    local r, t = flatdir(K.right[i]), flatdir(K.along(i))
    local made = 0
    for k = 0, n + 3 do
      if made >= n then break end
      local off = K.W[i] + WALL_T + 3.2 + 1.9 + k * 4.6
      local c = K.pos[i] + r * (side * off)
      if rect_ok(c.x, c.z, t, r, 7, 1.9, WALL_T + 2.6) then
        take(c.x, c.z, 7, 4)
        sausage(draped(c.x, c.z, (k % 2 == 0) and t or t * -1, 6.5, 1.8, 0.1), 14, 1.9, S("sausage"))
        made = made + 1
      end
    end
  end

  local function lying_whisk(x, z, f, t)
    local Dd = draped(x, z, t, 8, 3, 2.6)
    whisk(frame(at(Dd, -8, 0, 0) - Dd.y * 1.7, Dd.y, Dd.x + Dd.y * 0.02, cross(Dd.y, Dd.x)), RED)
  end

  ---------------------------------------------------------------------------------------------------------------
  -- Where they go: the board after the start, the sink half way, the sausages and the pan before the finish.
  local MUGS = {{RED, WHITE}, {BLUE, YELLOW}, {YELLOW, RED}, {TEAL, WHITE}, {PINK, WHITE}, {WHITE, BLUE}, {GREEN, YELLOW}}
  local JARS = {{RED, WHITE}, {YELLOW, ORANGE}, {GREEN, STEEL_D}, {ORANGE, BLUE}, {col(0.45, 0.1, 0.5), YELLOW}}
  local POTS = {RED, BLUE, TEAL, YELLOW, PINK}
  local function a_mug(k, s) return function(x, z, f) local m = MUGS[k % #MUGS + 1]; mug(x, z, f, m[1], m[2], s or 1, hash(x, z) * 360) end end
  local function a_jar(k, s) return function(x, z, f) local j = JARS[k % #JARS + 1]; jar(x, z, f, j[1], j[2], s or 1) end end
  local function a_teapot(k, s) return function(x, z, f) teapot(x, z, f, POTS[k % #POTS + 1], s or 1, 90 + (hash(z, x) - 0.5) * 80) end end
  local function a_toaster(k) return function(x, z, f) toaster(x, z, f, POTS[k % #POTS + 1]) end end
  local function a_pot(k) return function(x, z, f) local m = MUGS[k % #MUGS + 1]; utensil_pot(x, z, f, (k % 2 == 0) and CREAM or m[1], (k % 2 == 0) and BLUE or m[2]) end end
  local function a_cupboard(k, n) return function(x, z, f, t) cupboard(x, z, f, t, n, ({TEAL, BLUE, RED, GREEN})[k % 4 + 1]) end end

  place(34, 1, 16, 10, chopping_board, 4)
  place(94, -1, 14, 13, sink, 4)
  sausages(146, 1, 6)
  sausages(147, -1, 6)
  place(127, 1, 16, 10, pan, 4)

  place(14, -1, 3.6, 3.6, a_jar(0, 1.1))
  place(16, 1, 5.2, 5.2, a_mug(0, 1.1))
  place(25, -1, 7.5, 4.5, a_toaster(0))
  place(42, -1, 6, 6, a_pot(0))
  place(54, 1, 3.6, 3.6, a_jar(1, 1))
  place(57, 1, 3, 3, a_jar(2, 0.8))
  place(56, -1, 9, 3.5, lying_whisk)
  place(68, 1, 10, 10, a_teapot(0, 1))
  place(70, -1, 14.4, 5, a_cupboard(0, 3), 6)
  place(82, 1, 14.4, 5, a_cupboard(1, 3), 6)
  place(84, -1, 5.2, 5.2, a_mug(1, 1))
  place(100, 1, 7.5, 4.5, a_toaster(1))
  place(108, -1, 10, 10, a_teapot(1, 1.1))
  place(112, 1, 5.2, 5.2, a_mug(2, 1.15))
  place(115, 1, 5.2, 5.2, a_mug(3, 0.85))
  place(120, -1, 3.6, 3.6, a_jar(3, 1))
  place(123, -1, 3.2, 3.2, a_jar(4, 0.85))
  place(134, -1, 5.2, 5.2, a_mug(4, 1.1))
  place(158, -1, 6, 6, a_pot(1), 7)
  place(160, 1, 3.8, 3.8, a_jar(0, 1.15), 7)
  place(170, 1, 10, 10, a_teapot(2, 1.1), 9)
  place(172, -1, 7.5, 4.5, a_toaster(2), 9)
  place(182, 1, 6, 6, a_pot(2))
  place(183, -1, 5.2, 5.2, a_mug(5, 1.1))
  place(6, 1, 9.6, 5, a_cupboard(2, 2), 6)
  place(4, -1, 10, 10, a_teapot(3, 1))

  -- More of them further up the slopes, at random.
  local kinds = {
    {4, function(k) return a_mug(k, 0.9 + hash(k, 9) * 0.5) end}, {3.8, function(k) return a_jar(k, 0.9 + hash(k, 8) * 0.4) end},
    {7, function(k) return a_teapot(k, 1) end}, {8, a_toaster}, {6, a_pot}, {12, function(k) return a_cupboard(k, 2) end},
    {4, function(k) return a_mug(k + 3, 1.2) end}, {3.8, function(k) return a_jar(k + 2, 1.1) end},
  }
  local extra = 0
  for k = 1, 400 do
    if extra >= 46 then break end
    local x, z = K.spot(14)
    if x then
      local kind = kinds[k % #kinds + 1]
      local a = g:range(0, 2 * PI)
      local f = v3(math.cos(a), 0, math.sin(a))
      local t = cross(f, Y)
      if rect_ok(x, z, t, f, kind[1], kind[1], 8) then
        take(x, z, kind[1], kind[1])
        kind[2](k)(x, z, f, t)
        extra = extra + 1
      end
    end
  end

  -- The backsplash: tiles on a wall round the valley's edges, each stretch standing from its ground up.
  local TILE, ROWS = 5, 6
  local TILES = {WHITE, CREAM, BLUE, YELLOW, TEAL}
  local function wall(ax, az, bx, bz)
    local len = math.sqrt((bx - ax)^2 + (bz - az)^2)
    local dx, dz = (bx - ax) / len, (bz - az) / len
    local cols = math.floor(len / TILE)
    local F0 = frame(v3(0, 0, 0), v3(dx, 0, dz), Y, v3(-dz, 0, dx))
    for k = 0, cols - 1 do
      local s = (k + 0.5) * TILE + (len - cols * TILE) / 2
      local cx, cz = ax + dx * s, az + dz * s
      local r0 = math.floor((K.ground(cx, cz) - 4) / TILE)
      local par = k % 2
      local F = shift(F0, 0, 0, 0)
      F.o = v3(cx, 0, cz)
      box(D(GROUT), F, 0, (r0 + ROWS / 2) * TILE + par * 0.04, par * 0.03, TILE / 2 + 0.1, ROWS * TILE / 2 + 0.1, 0.3)
      for r = r0, r0 + ROWS - 1 do
        local h = hash(k * 7.13 + ax * 0.37 + bz * 0.11, r * 3.7 + az * 0.23)
        local c = (r == r0 + ROWS - 1) and BLUE or ((h < 0.1) and BLUE or (h < 0.17) and YELLOW or (h < 0.22) and TEAL or ((k + r) % 2 == 0) and WHITE or CREAM)
        box(D(c), F, 0, (r + 0.5) * TILE, 0, TILE / 2 - 0.16, TILE / 2 - 0.16, 0.5)
      end
    end
  end
  local x0, x1, z0, z1 = K.X0 + 2, K.X1 - 2, K.Z1 + 2, K.Z0 - 2
  wall(x0 + 1, z0, x1 - 1, z0)
  wall(x0 + 1, z1, x1 - 1, z1)
  wall(x0, z0 + 1, x0, z1 - 1)
  wall(x1, z0 + 1, x1, z1 - 1)

  -- Peas and crumbs.
  for _ = 1, 420 do
    local x, z = K.spot(3)
    if x then
      local r = g:range(0.45, 0.95)
      local c = (g:range(0, 1) < 0.25) and tint(PEA, 0.8) or PEA
      orb(D(c), v3(x, K.ground(x, z) + r * 0.75, z), r, r, r, 7, 5, c)
    end
  end
  local CRUMBS = {TOAST, CRUST, col(0.8, 0.55, 0.25), CREAM}
  for _ = 1, 520 do
    local x, z = K.spot(3)
    if x then
      local c = K.pick(CRUMBS)
      local a = g:range(0, 360)
      local s = g:range(0.3, 1.0)
      local F = turned(frame(v3(x, K.ground(x, z), z), v3(1, 0, 0), Y, v3(0, 0, 1)), a)
      local b = D(c)
      local function v(xx, y, zz) return at(F, xx * s, y * s, zz * s) end
      K.hexa(b, v(-1, -0.4, -0.8), v(1.1, -0.4, -0.6), v(0.9, -0.4, 0.9), v(-0.8, -0.4, 0.7),
        v(-0.6, 0.7, -0.5), v(0.7, 0.9, -0.3), v(0.5, 0.6, 0.6), v(-0.5, 0.8, 0.4))
    end
  end
end

return T
