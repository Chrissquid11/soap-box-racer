-- The Rooftop Delivery Route's scenery kit (see THEME KITS in _course.lua): the road runs over the roofs of an old
-- British city. The ground is roof felt, slate and lead for 16 m off the road, then falls down brick walls to the
-- streets far below (tarmac, pavements, back yards), where terraces of tall houses stand with pitched slate roofs,
-- chimney stacks and terracotta pots, cars and red buses between them. On the roofs beside the road: attics with
-- pitched roofs, chimney stacks, satellite dishes, TV aerials, skylights, water tanks, air-con units, scaffold
-- towers with planks and parcels, scaffold bridges over the road, pigeons, a roof terrace with its washing out.
-- Far off: church spires in the streets and office towers round the city's edge.
local T = {trees = 0, rocks = 0}

local ROOF = 16        -- the roofs end this far off the road's edge
local DEPTH = 24       -- the streets, this far under the road beside them
local DEEPEST = -14    -- (never lower: the valley's floor is 20 m under the road's lowest point, which is 0 here)

-- The ground: level roofs (the library's bank and ripple taken out past 8 m), then the streets.
function T.shape(x, z, off, y, road_y, TK)
  if off <= 8 then return nil end
  local away = off - 2.2
  local rise = math.min(away * 0.3, 18) + noise3(x, 0, z, {frequency = 0.04, seed = 3}) * math.min(away * 0.2, 2.5)
  local base = y - rise
  if off > ROOF then return math.max(base - DEPTH, DEEPEST) end
  local t = math.min(1, (off - 8) / 3)
  return y + (base + 1.74 - y) * t
end

-- The streets' grid: blocks of 7 cells of 6 m -- a street, a pavement, four cells of yards, a pavement.
local CELL, BLOCK = 6, 42
local INK
function T.paint(x, z, off, ink, TK)
  if not INK then
    local c = TK.col
    INK = {
      felt = c(0.2, 0.21, 0.23), felt2 = c(0.29, 0.3, 0.32), slate = c(0.2, 0.25, 0.36), slate2 = c(0.15, 0.19, 0.28),
      lead = c(0.46, 0.48, 0.52), gravel = c(0.42, 0.4, 0.36),
      brick = c(0.5, 0.19, 0.11), brick2 = c(0.38, 0.15, 0.1), stock = c(0.62, 0.5, 0.3),
      tarmac = c(0.07, 0.07, 0.08), pave = c(0.5, 0.5, 0.48), yard = c(0.33, 0.31, 0.29), garden = c(0.16, 0.36, 0.12),
      shed = c(0.24, 0.2, 0.18),
    }
  end
  local bx, bz = math.floor(x / CELL), math.floor(z / CELL)
  if off < 12.5 then
    if off < 3.4 then return INK.felt end
    local h = TK.hash(math.floor(x / 18), math.floor(z / 18))
    if h < 0.35 then return ((bx + bz) % 2 == 0) and INK.slate or INK.slate2
    elseif h < 0.7 then return (TK.hash(bx, bz) < 0.25) and INK.felt or INK.felt2
    elseif h < 0.87 then return INK.lead end
    return INK.gravel
  elseif off < 19.5 then
    local h = TK.hash(math.floor(x / 30) + 7, math.floor(z / 30))
    return (h < 0.5) and INK.brick or ((h < 0.8) and INK.brick2 or INK.stock)
  end
  local m, n = bx % 7, bz % 7
  if m == 0 or n == 0 then return INK.tarmac end
  if m == 1 or m == 6 or n == 1 or n == 6 then return INK.pave end
  local h = TK.hash(bx * 1.3, bz * 2.1)
  return (h < 0.4) and INK.garden or ((h < 0.8) and INK.yard or INK.shed)
end

function T.build(K)
  local Y = v3(0, 1, 0)
  local pi = math.pi
  local function rnd(a, b) return K.g:range(a, b) end
  local N, pos, right, W = K.N, K.pos, K.right, K.W
  local EDGE = K.WALL_T + 1          -- nothing nearer the road's edge than this
  local function one() return 1 end

  -- How many triangles the kit adds (said at the end).
  local function tris(b)
    local n = 0
    for _, f in ipairs(b.fs) do n = n + #f - 2 end
    for _, q in ipairs(b.more or {}) do for _, f in ipairs(q.fs) do n = n + #f - 2 end end
    return n
  end
  local before = tris(K.solid) + tris(K.deco)

  local col = K.col
  local BRICKS = {col(0.55, 0.2, 0.12), col(0.42, 0.16, 0.1), col(0.72, 0.58, 0.34), col(0.62, 0.55, 0.45), col(0.86, 0.8, 0.68)}
  local SLATES = {col(0.2, 0.25, 0.36), col(0.3, 0.34, 0.42), col(0.16, 0.18, 0.25), col(0.52, 0.2, 0.13)}
  local SLATES_DK = {}
  for k, c in ipairs(SLATES) do SLATES_DK[k] = K.tint(c, 0.7) end
  local EAVE, CAPC, POT, POT2 = col(0.12, 0.12, 0.14), col(0.7, 0.68, 0.62), col(0.9, 0.38, 0.14), col(0.75, 0.28, 0.1)
  local GLASS, LIT, SKY = col(0.06, 0.08, 0.14), col(1, 0.82, 0.35), col(0.4, 0.75, 0.98)
  local STEEL, STEEL_DK, AER = col(0.66, 0.69, 0.72), col(0.3, 0.32, 0.35), col(0.82, 0.84, 0.87)
  local DISH, DISH_DK, DARK = col(0.92, 0.92, 0.9), col(0.5, 0.52, 0.55), col(0.05, 0.05, 0.06)
  local WHITE, UNIT = col(0.93, 0.93, 0.9), col(0.78, 0.8, 0.78)
  local PLANK, PLANK2, WOOD = col(0.86, 0.64, 0.3), col(0.7, 0.5, 0.22), col(0.4, 0.24, 0.12)
  local SHEETS = {col(0.08, 0.4, 0.85), col(0.08, 0.6, 0.3), col(0.95, 0.45, 0.05)}
  local CARD, CARD2, TAPE = col(0.72, 0.5, 0.26), col(0.58, 0.38, 0.18), col(0.95, 0.88, 0.62)
  local BAGS = {col(0.95, 0.75, 0.08), col(0.9, 0.9, 0.88), col(0.1, 0.35, 0.8), col(0.85, 0.1, 0.1)}
  local DOORS = {col(0.8, 0.08, 0.06), col(0.06, 0.25, 0.7), col(0.05, 0.45, 0.2), col(0.95, 0.75, 0.05)}
  local TANKS = {col(0.6, 0.28, 0.12), col(0.62, 0.67, 0.7), col(0.1, 0.45, 0.5), col(0.15, 0.3, 0.6)}
  local CLOTHS = {col(0.95, 0.95, 0.95), col(0.9, 0.1, 0.1), col(1, 0.8, 0.05), col(0.1, 0.4, 0.9), col(0.95, 0.4, 0.7),
    col(0.1, 0.7, 0.35), col(1, 0.5, 0.05), col(0.55, 0.2, 0.8)}
  local PIGEONS = {col(0.45, 0.48, 0.6), col(0.3, 0.32, 0.4), col(0.6, 0.62, 0.68), col(0.88, 0.88, 0.88)}
  local PIG_HEAD = col(0.22, 0.3, 0.34)
  local STONE, STONE_DK, SPIRE, SPIRE_DK = col(0.62, 0.58, 0.5), col(0.45, 0.42, 0.37), col(0.3, 0.42, 0.4), col(0.2, 0.3, 0.3)
  local CARS = {col(0.8, 0.08, 0.06), col(0.1, 0.3, 0.7), col(0.9, 0.9, 0.88), col(0.1, 0.1, 0.12), col(0.75, 0.75, 0.78), col(0.95, 0.7, 0.05)}
  local BUS = col(0.85, 0.05, 0.04)
  local GREEN = col(0.15, 0.5, 0.12)

  -- A box of one colour, in that colour's piece of b (no painting): centre c, w along r, h up, d along t.
  local function box(b, colour, c, r, t, w, h, d)
    local q = K.sub(b, colour)
    q.ink = colour
    K.road_box(q, c, r, t, w, h, d)
  end
  -- A square bar from p0 to p1, th thick.
  local function beam(b, colour, p0, p1, th)
    local d = p1 - p0
    local e1 = cross(d, Y)
    if length(e1) < 1e-4 then e1 = v3(1, 0, 0) end
    e1 = normalize(e1) * (th / 2)
    local e2 = normalize(cross(d, e1)) * (th / 2)
    local q = K.sub(b, colour)
    q.ink = colour
    K.slab(q, p0, p1, e1, e2)
  end
  local function level(v)
    local l = math.sqrt(v.x * v.x + v.z * v.z)
    return v3(v.x / l, 0, v.z / l)
  end
  local function dir(yaw) return v3(math.cos(yaw), 0, math.sin(yaw)) end
  local function turn(d) return v3(-d.z, 0, d.x) end

  -- How far (x, z) is off the road's edge; whether a disc of radius r there keeps the road's clearance.
  local function off_road(x, z)
    local _, d = K.ground_d(x, z)
    return d - K.HW
  end
  local function clear(x, z, r) return off_road(x, z) > EDGE + r + 0.3 end
  local function inside(x, z, m) return x > K.X0 + m and x < K.X1 - m and z > K.Z1 + m and z < K.Z0 - m end
  -- What is built already: nothing else stands in it (kept by cell).
  local big, GC = {}, 12
  local function free(x, z, r)
    local list = big[math.floor(x / GC) * 4096 + math.floor(z / GC)]
    if not list then return true end
    for _, e in ipairs(list) do
      local dx, dz = x - e[1], z - e[2]
      local rr = e[3] + r
      if dx * dx + dz * dz < rr * rr then return false end
    end
    return true
  end
  local function take(x, z, r)
    local e = {x, z, r}
    local m = r + 5
    for gx = math.floor((x - m) / GC), math.floor((x + m) / GC) do
      for gz = math.floor((z - m) / GC), math.floor((z + m) / GC) do
        local key = gx * 4096 + gz
        big[key] = big[key] or {}
        big[key][#big[key] + 1] = e
      end
    end
  end

  -- The valley's grid (the library's STEP, worked out as it does): a thing stands on the roofs only where every
  -- corner of the grid's cell under it does, or the cell slopes away to the street under it.
  local STEP
  do
    local x0, x1, z0, z1 = math.huge, -math.huge, -math.huge, math.huge
    for i = 1, N do
      local p = pos[i]
      x0 = math.min(x0, p.x); x1 = math.max(x1, p.x); z1 = math.min(z1, p.z); z0 = math.max(z0, p.z)
    end
    STEP = math.max(5, math.ceil(math.sqrt((x1 - x0 + 140) * (z0 - z1 + 140) / 9000)))
  end
  local vflag = {}
  local function vert_on(c, r)
    local key = c * 4096 + r
    local f = vflag[key]
    if f == nil then
      f = off_road(K.X0 + c * STEP, K.Z0 - r * STEP) < ROOF - 0.01
      vflag[key] = f
    end
    return f
  end
  local function on_roof1(x, z)
    local c, r = math.floor((x - K.X0) / STEP), math.floor((K.Z0 - z) / STEP)
    return vert_on(c, r) and vert_on(c + 1, r) and vert_on(c, r + 1) and vert_on(c + 1, r + 1)
  end
  local function on_roof(x, z, r)
    return on_roof1(x - r, z - r) and on_roof1(x + r, z - r) and on_roof1(x - r, z + r) and on_roof1(x + r, z + r)
  end
  -- A place on the roofs beside the road for a thing of radius r, lo to hi past the clearance: its x, z, the way
  -- down the road there (u) and the way out from it (w); or nil.
  local function near(lo, hi, r)
    for _ = 1, 6 do
      local i = math.max(3, math.min(N - 3, math.floor(rnd(3, N - 2))))
      local s = (rnd(0, 1) < 0.5) and -1 or 1
      local o = EDGE + r + lo + (hi - lo) * rnd(0, 1)
      local p = pos[i] + right[i] * (s * (W[i] + o))
      if inside(p.x, p.z, 4) and free(p.x, p.z, r) and clear(p.x, p.z, r) and on_roof(p.x, p.z, r) then
        take(p.x, p.z, r)
        return p.x, p.z, level(K.along(i)), right[i] * s
      end
    end
    return nil
  end
  -- The lowest and highest ground under a rectangle.
  local function span(c, u, w, hu, hw)
    local lo, hi = math.huge, -math.huge
    for _, a in ipairs({{1, 1}, {-1, 1}, {-1, -1}, {1, -1}, {0, 0}}) do
      local p = c + u * (a[1] * hu) + w * (a[2] * hw)
      local y = K.ground(p.x, p.z)
      lo, hi = math.min(lo, y), math.max(hi, y)
    end
    return lo, hi
  end

  -- ------------------------------------------------------------------------------------------------ the pieces
  -- A pitched roof between two gable ends (e0, e1: the middle of each at the eaves), hw to either eave.
  local function gable(b, key, e0, e1, w, hw, rise, si, endc)
    local slate, dark = SLATES[si], SLATES_DK[si]
    local function sec(e)
      return {e - w * hw, e + Y * rise, e + w * hw, e + w * hw - Y * 0.2, e - w * hw - Y * 0.2}
    end
    K.prism(K.sub(b, key), {sec(e0), sec(e1)}, function(_, k) return (k == 1) and slate or ((k == 2) and dark or EAVE) end, endc, endc)
  end
  -- A chimney stack from y0 to y1, w wide along r, with a stone cap and `pots` terracotta pots in a row.
  local function stack(b, c, r, t, w, d, y0, y1, pots, brick, sides)
    box(b, brick, v3(c.x, (y0 + y1) / 2, c.z), r, t, w, y1 - y0, d)
    box(b, CAPC, v3(c.x, y1 + 0.1, c.z), r, t, w + 0.18, 0.16, d + 0.18)
    for k = 1, pots do
      local p = c + r * ((k - (pots + 1) / 2) * (w / pots))
      local tall = (k % 2 == 0) and 0.75 or 0.55
      local pc = (k % 3 == 0) and POT2 or POT
      K.column(K.sub(b, pc), p.x, p.z, y1 + 0.2, y1 + 0.2 + tall, 0.19, 0.13, sides or 6, pc, k)
    end
  end
  -- A TV aerial: a pole h high from p, a boom along `yaw` and its elements across it.
  local function aerial(b, p, h, yaw)
    local d = dir(yaw)
    local s = turn(d)
    box(b, AER, p + Y * (h / 2), d, s, 0.08, h, 0.08)
    local top = p + Y * (h - 0.2)
    beam(b, AER, top - d * 0.55, top + d * 1.2, 0.07)
    for k = 0, 4 do
      local c = top + d * (-0.42 + k * 0.38) + Y * 0.07
      local l = 0.6 - k * 0.07
      beam(b, AER, c - s * l, c + s * l, 0.05)
    end
  end
  -- A satellite dish of radius r, its middle at c, looking along `yaw` and up.
  local function dish(b, c, yaw, r)
    local d = dir(yaw)
    local e1 = turn(d)
    local a = normalize(d * 0.8 + Y * 0.6)
    local e2 = cross(a, e1)
    local back, front = {}, {}
    for k = 1, 8 do
      local an = (k - 0.5) / 8 * 2 * pi
      local o = e1 * math.cos(an) + e2 * math.sin(an)
      back[k] = c - a * (r * 0.36) + o * (r * 0.25)
      front[k] = c + o * r
    end
    K.prism(K.sub(b, DISH), {back, front}, K.flat(DISH_DK), DISH_DK, DISH)
    beam(b, STEEL_DK, c - e2 * (r * 0.92) + a * 0.02, c + a * (r * 0.8), 0.06)
    beam(b, DARK, c + a * (r * 0.7), c + a * (r * 0.95), 0.16)
  end
  local function dish_on_pole(b, p, yaw, r, h)
    box(b, STEEL_DK, p + Y * (h / 2 - 0.3), dir(yaw), turn(dir(yaw)), 0.1, h + 0.6, 0.1)
    dish(b, p + Y * (h + r * 0.5) + dir(yaw) * (r * 0.3), yaw, r)
  end
  -- A parcel: a cardboard box with tape over it, or a courier's bright bag.
  local function parcel(b, p, yaw, w, h, d)
    local r = dir(yaw)
    local t = turn(r)
    if rnd(0, 1) < 0.7 then
      box(b, (rnd(0, 1) < 0.6) and CARD or CARD2, p + Y * (h / 2), r, t, w, h, d)
      box(b, TAPE, p + Y * (h / 2 + 0.012), r, t, w * 0.16, h + 0.01, d + 0.03)
    else
      box(b, K.pick(BAGS), p + Y * (h / 2), r, t, w, h, d)
    end
  end
  -- A pile of n parcels about p, some on top of others.
  local function pile(b, p, n, spread)
    for k = 1, n do
      local q = p + v3(rnd(-spread, spread), 0, rnd(-spread, spread))
      local h = rnd(0.35, 0.7)
      parcel(b, q, rnd(0, 3), rnd(0.5, 0.95), h, rnd(0.45, 0.8))
      if k % 2 == 0 then parcel(b, q + Y * (h + 0.02), rnd(0, 3), rnd(0.35, 0.5), rnd(0.25, 0.4), rnd(0.3, 0.45)) end
    end
  end
  local function pigeon(b, p, yaw, s)
    local c = K.pick(PIGEONS)
    local d = dir(yaw)
    K.ball(K.sub(b, c), p + Y * (0.16 * s), 0.21 * s, 0.16 * s, 0.21 * s, 5, 3, one, K.flat(c))
    K.ball(K.sub(b, PIG_HEAD), p + Y * (0.37 * s) + d * (0.16 * s), 0.1 * s, 0.1 * s, 0.1 * s, 4, 3, one, K.flat(PIG_HEAD))
  end

  -- A scaffold tower: four standards from y0 up, a lift every LH above yg with ledgers, transoms, a brace and a deck
  -- of planks, a guard rail round the top, sometimes sheeting on its far side. c its middle, u along it, w across.
  local SC_U, SC_W, LH = 1.3, 0.75, 2.1
  local function scaffold(b, c, u, w, y0, yg, lifts, sheet, top_y)
    local top = top_y or (yg + lifts * LH + 1.15)
    local function at(a, bb, y) return v3(c.x, y, c.z) + u * a + w * bb end
    for su = -1, 1, 2 do
      for sw = -1, 1, 2 do
        box(b, STEEL, at(su * SC_U, sw * SC_W, (y0 + top) / 2), u, w, 0.1, top - y0, 0.1)
      end
    end
    for l = 1, lifts do
      local y = top_y and (top_y - 1.15 - (lifts - l) * LH) or (yg + l * LH)
      for s = -1, 1, 2 do
        beam(b, STEEL, at(-SC_U - 0.25, s * (SC_W + 0.1), y), at(SC_U + 0.25, s * (SC_W + 0.1), y), 0.09)
        beam(b, STEEL, at(s * (SC_U + 0.1), -SC_W - 0.25, y - 0.1), at(s * (SC_U + 0.1), SC_W + 0.25, y - 0.1), 0.09)
      end
      local sgn = (l % 2 == 0) and 1 or -1
      beam(b, STEEL, at(-sgn * SC_U, -SC_W - 0.2, y - LH + 0.15), at(sgn * SC_U, -SC_W - 0.2, y - 0.15), 0.08)
      box(b, (l % 2 == 0) and PLANK or PLANK2, at(0, 0, y + 0.09), u, w, SC_U * 2 + 0.5, 0.07, SC_W * 2 - 0.16)
    end
    for s = -1, 1, 2 do
      beam(b, STEEL, at(-SC_U - 0.2, s * (SC_W + 0.1), top - 0.1), at(SC_U + 0.2, s * (SC_W + 0.1), top - 0.1), 0.08)
    end
    if sheet then
      local ylo = top - 1.15 - (lifts - 1) * LH
      box(b, sheet, at(0, SC_W + 0.28, (ylo + top) / 2), u, w, SC_U * 2 + 0.3, top - ylo, 0.04)
    end
    return top - 1.15
  end

  -- -------------------------------------------------------------------------------- scaffold bridges over the road
  -- A tower either side and a deck of planks across, 7 m over the road, orange netting on its rails, parcels on it.
  local bridges = 0
  local function bridge(i)
    local u, r = level(K.along(i)), right[i]
    if K.lift(i, 1) > 0.01 or K.lift(i, -1) > 0.01 then return false end
    local out = W[i] + EDGE + 0.25 + SC_W + 0.4
    local cs = {}
    for _, s in ipairs({-1, 1}) do
      local c = pos[i] + r * (s * out)
      for su = -1, 1, 2 do
        for sw = -1, 1, 2 do
          local p = c + u * (su * (SC_U + 0.4)) + r * (sw * (SC_W + 0.4))
          if off_road(p.x, p.z) < EDGE + 0.05 then return false end
        end
      end
      if not (free(c.x, c.z, 1.6) and on_roof(c.x, c.z, 1.6)) then return false end
      cs[#cs + 1] = c
    end
    local dy = pos[i].y + 7.2
    for k, c in ipairs(cs) do
      take(c.x, c.z, 1.9)
      local lo = span(c, u, r, SC_U, SC_W)
      scaffold(K.solid, c, u, r, lo - 0.6, 0, 3, (k == 1) and SHEETS[bridges % 3 + 1] or nil, dy + 1.15)
    end
    local a, b2 = cs[1] + r * (SC_W + 0.3), cs[2] - r * (SC_W + 0.3)
    local function over(p, y, du) return v3(p.x, dy + y, p.z) + u * du end
    for s = -1, 1, 2 do
      beam(K.solid, STEEL, over(a, -0.12, s * 0.62), over(b2, -0.12, s * 0.62), 0.12)
      beam(K.solid, STEEL, over(a, 1.05, s * 0.7), over(b2, 1.05, s * 0.7), 0.08)
      local q = K.sub(K.deco, SHEETS[3])
      q.ink = SHEETS[3]
      K.slab(q, over(a, 0.56, s * 0.76), over(b2, 0.56, s * 0.76), Y * 0.4, u * 0.02)
    end
    local q = K.sub(K.solid, PLANK)
    q.ink = PLANK
    K.slab(q, over(a, 0.03, 0), over(b2, 0.03, 0), Y * 0.04, u * 0.6)
    local mid = v3(pos[i].x, dy + 0.08, pos[i].z)
    for k = -1, 1 do parcel(K.deco, mid + r * (k * 1.3 + rnd(-0.3, 0.3)), rnd(0, 3), 0.7, rnd(0.4, 0.7), 0.6) end
    bridges = bridges + 1
    return true
  end
  for _, at in ipairs({0.14, 0.3, 0.46, 0.62, 0.78, 0.9}) do
    local i0 = math.floor(K.start + (K.fin - K.start) * at)
    for k = 0, 14 do
      local i = i0 + ((k % 2 == 0) and 1 or -1) * math.floor((k + 1) / 2)
      if i > K.start + 12 and i < K.fin - 12 and bridge(i) then break end
    end
  end

  -- ---------------------------------------------------------------------------------- the roof terrace's washing
  -- Two posts with a cross bar each and `lines` lines between them, bright washing pegged along each.
  local function washing(c, u, w, y, len, lines)
    local function at(a, bb, h) return v3(c.x, y + h, c.z) + u * a + w * bb end
    for s = -1, 1, 2 do
      box(K.solid, WHITE, at(s * len / 2, 0, 1.1), u, w, 0.1, 2.4, 0.1)
      if lines > 1 then beam(K.solid, WHITE, at(s * len / 2, -0.5 * (lines - 1) - 0.1, 2.2), at(s * len / 2, 0.5 * (lines - 1) + 0.1, 2.2), 0.08) end
    end
    for l = 1, lines do
      local bb = (l - (lines + 1) / 2) * 1.0
      beam(K.deco, DARK, at(-len / 2, bb, 2.15), at(len / 2, bb, 2.15), 0.03)
      local a = -len / 2 + 0.3
      while a < len / 2 - 0.9 do
        local cw, ch = rnd(0.4, 1.0), rnd(0.5, 1.2)
        box(K.deco, K.pick(CLOTHS), at(a + cw / 2, bb, 2.12 - ch / 2), u, w, cw, ch, 0.05)
        a = a + cw + rnd(0.08, 0.3)
      end
    end
  end
  local terraces = 0
  for _ = 1, 30 do
    if terraces >= 2 then break end
    local x, z, u, w = near(0.4, 3, 4.6)
    if x then
      terraces = terraces + 1
      local c = v3(x, 0, z)
      local lo, hi = span(c, u, w, 3.6, 2.6)
      local ty = hi + 0.25
      local function at(a, bb, h) return v3(x, ty + (h or 0), z) + u * a + w * bb end
      box(K.solid, WOOD, v3(x, (lo - 0.4 + ty) / 2, z), u, w, 7.2, ty - lo + 0.4, 5.2)
      box(K.solid, PLANK2, at(0, 0, 0.03), u, w, 6.9, 0.05, 4.9)
      -- a rail on the three sides away from the road
      for a = -3.4, 3.41, 1.7 do box(K.solid, WHITE, at(a, 2.4, 0.55), u, w, 0.1, 1.0, 0.1) end
      for _, s in ipairs({-1, 1}) do
        box(K.solid, WHITE, at(s * 3.4, 0, 0.55), u, w, 0.1, 1.0, 0.1)
        box(K.solid, WHITE, at(s * 3.4, -2.3, 0.55), u, w, 0.1, 1.0, 0.1)
        beam(K.solid, WHITE, at(s * 3.4, -2.4, 1.08), at(s * 3.4, 2.34, 1.08), 0.08)
      end
      beam(K.solid, WHITE, at(-3.5, 2.4, 1.1), at(3.5, 2.4, 1.1), 0.08)
      washing(v3(x, 0, z) + w * 0.4, u, w, ty + 0.05, 5.6, 3)
      -- a parasol, a table under it, and pots of plants
      local pp = at(-2.3, -1.6)
      box(K.solid, WHITE, pp + Y * 1.2, u, w, 0.07, 2.4, 0.07)
      K.cone(K.sub(K.deco, "parasol"), K.ring(pp + Y * 2.1, 1.3, 1.3, 8, 0), pp + Y * 2.12, pp + Y * 2.6,
        function(k) return (k % 2 == 0) and CLOTHS[2] or CLOTHS[1] end, CLOTHS[1])
      K.column(K.sub(K.solid, WHITE), pp.x, pp.z, ty + 0.7, ty + 0.78, 0.6, 0.6, 8, WHITE)
      for _, e in ipairs({{3, -1.9}, {2.2, -2.0}, {-3, 1.9}}) do
        local p = at(e[1], e[2])
        K.column(K.sub(K.solid, POT), p.x, p.z, ty + 0.06, ty + 0.5, 0.2, 0.28, 6, POT)
        K.ball(K.sub(K.deco, GREEN), p + Y * 0.8, 0.4, 0.4, 0.4, 6, 4, one, K.shaded(GREEN))
      end
    end
  end

  -- ------------------------------------------------------------------------------------ scaffold towers, parcels
  local towers = 0
  for k = 1, 60 do
    if towers >= 26 then break end
    local x, z, u, w = near(0.2, 3.5, 2.0)
    if x then
      towers = towers + 1
      local c = v3(x, 0, z)
      local lo, hi = span(c, u, w, SC_U, SC_W)
      local lifts = 2 + k % 3
      local deck = scaffold(K.solid, c, u, w, lo - 0.6, hi, lifts, (k % 3 ~= 0) and SHEETS[k % 3 + 1] or nil)
      pile(K.deco, v3(x, deck + 0.14, z), 2, 0.35)
      pile(K.deco, v3(x, hi + LH + 0.14, z), 1, 0.3)
      -- more parcels on the roof at its foot, towards the road
      local f = c - w * (SC_W + 0.9)
      if clear(f.x, f.z, 0.9) then pile(K.solid, v3(f.x, K.ground(f.x, f.z) - 0.05, f.z), 4, 0.55) end
    end
  end
  for _ = 1, 26 do
    local x, z = near(0.1, 6, 1.3)
    if x then pile(K.solid, v3(x, K.ground(x, z) - 0.05, z), math.floor(rnd(4, 8.9)), 0.8) end
  end

  -- --------------------------------------------------------------------------------- attics: pitched slate roofs
  -- A low brick attic with a pitched slate roof, a chimney stack with its pots at one end, a bright door, a lit
  -- window; an aerial on the stack or a dish on the wall.
  local attics = 0
  for k = 1, 110 do
    if attics >= 46 then break end
    local hu, hw = rnd(2.2, 3.4), rnd(1.6, 2.2)
    local x, z, u, w = near(0.5, 7, math.sqrt(hu * hu + hw * hw) + 0.5)
    if x then
      attics = attics + 1
      if k % 3 == 0 then u, w = w, u end
      local c = v3(x, 0, z)
      local lo, hi = span(c, u, w, hu, hw)
      local ye = hi + rnd(1.5, 2.6)
      local rise = hw * rnd(0.8, 1.1)
      local wi, si = k % #BRICKS + 1, k % #SLATES + 1
      local wall = BRICKS[wi]
      local function at(a, bb, y) return v3(x, y, z) + u * a + w * bb end
      box(K.solid, wall, at(0, 0, (lo - 0.5 + ye) / 2), u, w, hu * 2, ye - lo + 0.5, hw * 2)
      gable(K.solid, "attic" .. wi .. si, at(-hu - 0.3, 0, ye + 0.02), at(hu + 0.3, 0, ye + 0.02), w, hw + 0.35, rise, si, wall)
      local sa = (k % 2 == 0) and 1 or -1
      local pots = 2 + k % 4
      local st = ye + rise + rnd(1.0, 1.9)
      stack(K.solid, at(sa * (hu - 0.75), 0, 0), w, u, 0.5 + pots * 0.42, 0.75, ye - 0.3, st, pots, BRICKS[(k + 1) % 2 + 1])
      -- the door and a window, on the sides the roof comes down to
      for _, s in ipairs({-1, 1}) do
        box(K.solid, K.pick(DOORS), at(-sa * hu * 0.45, s * (hw + 0.03), hi + 0.95), u, w, 0.85, 1.9, 0.1)
        box(K.solid, (rnd(0, 1) < 0.6) and LIT or GLASS, at(sa * hu * 0.3, s * (hw + 0.03), ye - 0.75), u, w, 0.9, 0.8, 0.1)
      end
      if k % 3 ~= 1 then
        aerial(K.deco, at(sa * (hu - 0.75), 0.6, st - 0.6), 2.6, rnd(0, 6.3))
      end
      if k % 2 == 0 then
        local yaw = rnd(0, 6.3)
        dish(K.deco, at(-sa * (hu + 0.75), 0, ye + 0.4), yaw, 0.55)
        beam(K.deco, STEEL_DK, at(-sa * (hu + 0.75), 0, ye + 0.3), at(-sa * (hu - 0.05), 0, ye - 0.2), 0.08)
      end
      if k % 4 == 0 then
        for q = 0, 1 do pigeon(K.deco, at(-sa * (0.3 + q * 0.7), 0, ye + rise - 0.06), rnd(0, 6.3), 1.2) end
      end
    end
  end

  -- ----------------------------------------------------------------------- chimney stacks standing on their own
  for k = 1, 90 do
    local pots = 3 + k % 5
    local wd = 0.5 + pots * 0.42
    local x, z, u, w = near(0.1, 8, wd / 2 + 0.4)
    if x then
      if k % 2 == 0 then u, w = w, u end
      local y = K.ground(x, z)
      local top = y + rnd(2.4, 4.6)
      stack(K.solid, v3(x, 0, z), u, w, wd, 0.85, y - 1.2, top, pots, BRICKS[k % 2 + 1])
      -- a band of brick standing out under the cap
      box(K.solid, BRICKS[(k + 1) % 2 + 1], v3(x, top - 0.45, z), u, w, wd + 0.14, 0.22, 0.99)
      if k % 3 == 0 then aerial(K.deco, v3(x, top - 0.8, z) + w * 0.52, 2.8, rnd(0, 6.3)) end
      if k % 4 == 1 then
        local yaw = rnd(0, 6.3)
        local p = v3(x, top - 0.9, z) - w * 0.9
        dish(K.deco, p, yaw, 0.5)
        beam(K.deco, STEEL_DK, p - Y * 0.1, v3(x, top - 1.2, z) - w * 0.4, 0.07)
      end
    end
  end

  -- ------------------------------------------------- satellite dishes on poles, and aerials on their own masts
  for k = 1, 70 do
    local big_one = k % 6 == 0
    local r = big_one and rnd(1.0, 1.5) or rnd(0.5, 0.75)
    local x, z = near(0.1, 8, r + 0.3)
    if x then dish_on_pole(big_one and K.solid or K.deco, v3(x, K.ground(x, z), z), rnd(0, 6.3), r, big_one and 1.6 or rnd(0.9, 2.2)) end
  end
  for _ = 1, 26 do
    local x, z = near(0.1, 8, 0.9)
    if x then aerial(K.deco, v3(x, K.ground(x, z) - 0.3, z), rnd(3.5, 5.5), rnd(0, 6.3)) end
  end

  -- -------------------------------------------------------------------------------------------------- skylights
  for k = 1, 60 do
    local x, z, u, w = near(0.2, 8, 1.6)
    if x then
      local lo, hi = span(v3(x, 0, z), u, w, 1.2, 0.8)
      local fy = hi + 0.3
      box(K.solid, WHITE, v3(x, (lo - 0.3 + fy) / 2, z), u, w, 2.4, fy - lo + 0.3, 1.7)
      -- the glass: a wedge, higher on one side
      local function g(a, bb, y) return v3(x, fy + y, z) + u * (a * 1.05) + w * (bb * 0.7) end
      local q = K.sub(K.solid, SKY)
      q.ink = SKY
      K.hexa(q, g(-1, -1, 0.02), g(1, -1, 0.02), g(1, 1, 0.02), g(-1, 1, 0.02), g(-1, -1, 0.12), g(1, -1, 0.12), g(1, 1, 0.6), g(-1, 1, 0.6))
      if k % 3 == 0 then box(K.solid, WHITE, v3(x, fy + 0.38, z), u, w, 0.07, 0.6, 1.5) end
    end
  end

  -- ------------------------------------------------------------------------------------------------ water tanks
  for k = 1, 30 do
    local x, z, u, w = near(0.8, 7, 2.0)
    if x then
      local lo, hi = span(v3(x, 0, z), u, w, 1.1, 1.1)
      local py = hi + 1.5
      for su = -1, 1, 2 do
        for sw = -1, 1, 2 do
          box(K.solid, STEEL_DK, v3(x, (lo - 0.4 + py) / 2, z) + u * (su * 1.0) + w * (sw * 1.0), u, w, 0.16, py - lo + 0.4, 0.16)
        end
      end
      beam(K.solid, STEEL_DK, v3(x, lo + 0.2, z) - u * 1.0 - w * 1.1, v3(x, py - 0.2, z) + u * 1.0 - w * 1.1, 0.1)
      beam(K.solid, STEEL_DK, v3(x, lo + 0.2, z) + u * 1.0 + w * 1.1, v3(x, py - 0.2, z) - u * 1.0 + w * 1.1, 0.1)
      box(K.solid, PLANK2, v3(x, py + 0.08, z), u, w, 2.7, 0.14, 2.7)
      local tc = TANKS[k % #TANKS + 1]
      local h = rnd(2.2, 3.0)
      K.column(K.sub(K.solid, tc), x, z, py + 0.17, py + 0.17 + h, 1.3, 1.3, 10, tc)
      K.column(K.sub(K.solid, STEEL_DK), x, z, py + 0.17 + h * 0.3, py + 0.17 + h * 0.36, 1.34, 1.34, 10, STEEL_DK)
      K.column(K.sub(K.solid, STEEL_DK), x, z, py + 0.17 + h * 0.7, py + 0.17 + h * 0.76, 1.34, 1.34, 10, STEEL_DK)
      local ly = py + 0.2 + h
      K.cone(K.sub(K.solid, "lid"), K.ring(v3(x, ly, z), 1.45, 1.45, 10, 0), v3(x, ly, z), v3(x, ly + 0.8, z),
        function(q) return (q % 2 == 0) and STEEL or STEEL_DK end, STEEL_DK)
    end
  end

  -- ------------------------------------------------------------------------------------ air-con units and ducts
  for k = 1, 70 do
    local x, z, u, w = near(0.2, 8, 1.4)
    if x then
      local lo, hi = span(v3(x, 0, z), u, w, 0.9, 0.6)
      local n = 1 + k % 2
      for q = 1, n do
        local c = v3(x, 0, z) + u * ((q - (n + 1) / 2) * 1.25)
        local top = hi + 1.0
        box(K.solid, UNIT, v3(c.x, (lo - 0.3 + top) / 2, c.z), u, w, 1.1, top - lo + 0.3, 1.0)
        K.column(K.sub(K.solid, DARK), c.x, c.z, top + 0.01, top + 0.07, 0.38, 0.38, 8, DARK)
        box(K.solid, STEEL_DK, v3(c.x, hi + 0.55, c.z) - w * 0.51, u, w, 0.9, 0.5, 0.04)
      end
      if k % 3 == 0 then
        -- a duct running off it and turning down into the roof
        local a = v3(x, hi + 0.6, z) + w * 0.56
        beam(K.solid, STEEL, a, a + w * 1.6, 0.4)
        box(K.solid, STEEL, a + w * 1.85 - Y * 0.3, u, w, 0.42, 1.4, 0.42)
      end
    end
  end

  -- ---------------------------------------------------------------------------------------------------- pigeons
  for _ = 1, 34 do
    local x, z = near(0.1, 7, 1.3)
    if x then
      for _ = 1, math.floor(rnd(3, 7.9)) do
        local px, pz = x + rnd(-1.2, 1.2), z + rnd(-1.2, 1.2)
        pigeon(K.deco, v3(px, K.ground(px, pz) - 0.03, pz), rnd(0, 6.3), rnd(1.1, 1.5))
      end
    end
  end

  -- ------------------------------------------------------------------------------- the streets: terraces, churches
  -- A terrace of tall houses: brick walls up to the eaves, a pitched slate roof, chimney stacks across the ridge
  -- with their pots, and (near the road) windows on its top floors.
  local houses = 0
  local function terrace(c, u, w, hu, hw, key)
    local lo, far_ = math.huge, math.huge
    for _, a in ipairs({{1, 1}, {-1, 1}, {-1, -1}, {1, -1}, {0, 0}}) do
      local p = c + u * (a[1] * hu) + w * (a[2] * hw)
      if not inside(p.x, p.z, 1) then return false end
      local y, d = K.ground_d(p.x, p.z)
      lo, far_ = math.min(lo, y), math.min(far_, d - K.HW)
    end
    if far_ < ROOF + 3.5 then return false end
    houses = houses + 1
    local close = far_ < 32
    local h1, h2 = K.hash(key, 1.7), K.hash(key, 5.1)
    local wi, si = math.floor(h1 * #BRICKS) + 1, math.floor(h2 * #SLATES) + 1
    local wall = BRICKS[wi]
    local gy = K.ground(c.x, c.z)
    local ye = gy + 12 + K.hash(key, 9.3) * 9
    local rise = hw * 0.85
    local b = K.deco
    local function at(a, bb, y) return v3(c.x, y, c.z) + u * a + w * bb end
    box(b, wall, at(0, 0, (lo - 1 + ye) / 2), u, w, hu * 2, ye - lo + 1, hw * 2)
    gable(b, "roof" .. wi .. si, at(-hu - 0.2, 0, ye + 0.02), at(hu + 0.2, 0, ye + 0.02), w, hw + 0.4, rise, si, wall)
    local n = close and math.max(2, math.floor(hu / 3.6)) or math.max(1, math.floor(hu / 6))
    for k = 1, n do
      local a = (k - 0.5) / n * 2 * hu - hu + 1.3
      stack(b, at(a, 0, 0), w, u, close and 2.0 or 1.7, 0.85, ye + rise - 1.4, ye + rise + 1.5, close and 4 or 2, BRICKS[(k + wi) % 2 + 1], close and 6 or 4)
    end
    if close then
      local per = math.max(2, math.floor(hu / 2.1))
      for f = 0, (far_ < 24) and 1 or 0 do
        for k = 1, per do
          local a = (k - 0.5) / per * 2 * hu - hu
          for s = -1, 1, 2 do
            local lit = K.hash(key + k * 3.3 + f, s * 2.9) < 0.3
            box(b, lit and LIT or GLASS, at(a, s * (hw + 0.03), ye - 1.7 - f * 3.2), u, w, 1.15, 1.7, 0.12)
          end
        end
      end
    end
    return true
  end
  -- A church: a nave with a steep roof, a square tower at one end, and a tall spire on it.
  local function church(c, u, w)
    local lo = span(c, u, w, 12, 6)
    local gy = K.ground(c.x, c.z)
    local function at(a, bb, y) return v3(c.x, y, c.z) + u * a + w * bb end
    local ye = gy + 13
    box(K.deco, STONE, at(-3, 0, (lo - 1 + ye) / 2), u, w, 17, ye - lo + 1, 10)
    gable(K.deco, "nave", at(-11.7, 0, ye + 0.02), at(5.7, 0, ye + 0.02), w, 5.4, 7, 1, STONE)
    for k = -2, 1 do
      for s = -1, 1, 2 do box(K.deco, (k % 2 == 0) and LIT or GLASS, at(-4 + k * 3.6, s * 5.03, ye - 4.5), u, w, 1.3, 5, 0.12) end
    end
    local ty = gy + 34
    local tc = at(9.2, 0, 0)
    box(K.deco, STONE, v3(tc.x, (lo - 1 + ty) / 2, tc.z), u, w, 7.4, ty - lo + 1, 7.4)
    box(K.deco, STONE_DK, v3(tc.x, ty + 0.4, tc.z), u, w, 8.2, 0.76, 8.2)
    for su = -1, 1, 2 do
      for sw = -1, 1, 2 do box(K.deco, STONE, v3(tc.x, ty + 2.2, tc.z) + u * (su * 3.5) + w * (sw * 3.5), u, w, 0.9, 2.8, 0.9) end
    end
    for s = -1, 1, 2 do
      box(K.deco, WHITE, v3(tc.x, ty - 4, tc.z) + w * (s * 3.72), u, w, 2.6, 2.6, 0.1)
      box(K.deco, WHITE, v3(tc.x, ty - 4, tc.z) + u * (s * 3.72), w, u, 2.6, 2.6, 0.1)
      box(K.deco, GLASS, v3(tc.x, ty - 10, tc.z) + w * (s * 3.72), u, w, 1.4, 4, 0.1)
      box(K.deco, GLASS, v3(tc.x, ty - 10, tc.z) + u * (s * 3.72), w, u, 1.4, 4, 0.1)
    end
    local sy = ty + 0.8
    K.cone(K.sub(K.deco, "spire"), K.ring(v3(tc.x, sy, tc.z), 3.4, 3.4, 8, pi / 8), v3(tc.x, sy, tc.z), v3(tc.x, sy + 30, tc.z),
      function(k) return (k % 2 == 0) and SPIRE or SPIRE_DK end, SPIRE_DK)
  end

  -- The blocks between the streets: two terraces back to back in each (halves where the roofs are in the way), a
  -- church in two of those well away from the road.
  local blocks, holy = {}, {}
  for bk = math.floor(K.X0 / BLOCK), math.floor(K.X1 / BLOCK) do
    for bl = math.floor(K.Z1 / BLOCK), math.floor(K.Z0 / BLOCK) do
      local c = v3(bk * BLOCK + 24, 0, bl * BLOCK + 24)
      if inside(c.x, c.z, 13) then
        local e = {c = c, key = bk * 31.7 + bl * 5.3, off = off_road(c.x, c.z)}
        blocks[#blocks + 1] = e
        if e.off > 42 and e.off < 85 then holy[#holy + 1] = e end
      end
    end
  end
  table.sort(holy, function(a, b) return K.hash(a.key, 3.3) < K.hash(b.key, 3.3) end)
  local churches = {}
  for _, e in ipairs(holy) do
    local ok = #churches < 3
    for _, o in ipairs(churches) do
      if length(o.c - e.c) < 170 then ok = false end
    end
    if ok then churches[#churches + 1] = e; e.church = true end
  end
  for _, e in ipairs(blocks) do
    local along_x = K.hash(e.key, 7.7) < 0.5
    local u, w = v3(1, 0, 0), v3(0, 0, 1)
    if not along_x then u, w = w, u end
    if e.church then
      church(e.c, u, w)
    elseif e.off > ROOF + 2 then
      for s = -1, 1, 2 do
        local c = e.c + w * (s * 7.3)
        if not terrace(c, u, w, 11.6, 4.4, e.key + s) then
          for h = -1, 1, 2 do terrace(c + u * (h * 6), u, w, 5.6, 4.4, e.key + s + h * 0.37) end
        end
      end
    end
  end

  -- Cars parked and red buses in the streets.
  local traffic = 0
  local function vehicle(x, z, u, k)
    local w = turn(u)
    local a, b2 = v3(x, 0, z) - u * 4, v3(x, 0, z) + u * 4
    if not (inside(a.x, a.z, 2) and inside(b2.x, b2.z, 2)) then return end
    local ya, da = K.ground_d(a.x, a.z)
    local yb, db = K.ground_d(b2.x, b2.z)
    if da - K.HW < ROOF + 9 or db - K.HW < ROOF + 9 or math.abs(ya - yb) > 1.2 then return end
    local y = math.max(ya, yb) - 0.1
    traffic = traffic + 1
    if k % 5 == 0 then
      box(K.deco, BUS, v3(x, y + 2.4, z), u, w, 9.5, 4.3, 2.5)
      box(K.deco, GLASS, v3(x, y + 1.9, z), u, w, 9.0, 0.9, 2.58)
      box(K.deco, GLASS, v3(x, y + 3.7, z), u, w, 9.0, 0.8, 2.58)
    else
      local c = CARS[k % #CARS + 1]
      box(K.deco, c, v3(x, y + 0.65, z), u, w, 4.3, 0.9, 1.8)
      box(K.deco, GLASS, v3(x, y + 1.42, z) - u * 0.2, u, w, 2.3, 0.6, 1.6)
    end
  end
  local vk = 0
  for bk = math.floor(K.X0 / BLOCK), math.floor(K.X1 / BLOCK) do
    for bl = math.floor(K.Z1 / BLOCK), math.floor(K.Z0 / BLOCK) do
      for q = 0, 2 do
        vk = vk + 1
        if K.hash(vk, 2.2) < 0.2 then
          local side = (K.hash(vk, 4.4) < 0.5) and -1.5 or 1.5
          vehicle(bk * BLOCK + 9 + q * 12 + K.hash(vk, 6.6) * 4, bl * BLOCK + 3 + side, v3(1, 0, 0), vk)
          vehicle(bk * BLOCK + 3 + side, bl * BLOCK + 9 + q * 12 + K.hash(vk, 8.8) * 4, v3(0, 0, 1), vk + 2)
        end
      end
    end
  end

  -- ---------------------------------------------------------------------- office towers round the city's edge
  -- Bands of glass and concrete, a plant room and a mast on top.
  local OFFICE = {{col(0.2, 0.45, 0.7), col(0.75, 0.77, 0.8)}, {col(0.1, 0.5, 0.55), col(0.9, 0.9, 0.88)},
    {col(0.1, 0.14, 0.22), col(0.55, 0.5, 0.42)}, {col(0.35, 0.6, 0.85), col(0.3, 0.33, 0.38)}}
  local offices = 0
  local function office(x, z, ex, ez)
    offices = offices + 1
    local gy = K.ground(ex, ez)
    local y0, y1 = gy - 6, gy + DEPTH + rnd(34, 95)
    local hx, hz = rnd(9, 15), rnd(9, 15)
    local set = OFFICE[offices % #OFFICE + 1]
    local rings = {}
    local y, j = y0, 0
    while y < y1 do
      rings[#rings + 1] = {v3(x - hx, y, z - hz), v3(x + hx, y, z - hz), v3(x + hx, y, z + hz), v3(x - hx, y, z + hz)}
      j = j + 1
      y = y + ((j % 2 == 1) and 3 or 7)
    end
    rings[#rings + 1] = {v3(x - hx, y, z - hz), v3(x + hx, y, z - hz), v3(x + hx, y, z + hz), v3(x - hx, y, z + hz)}
    K.prism(K.sub(K.deco, "office" .. (offices % #OFFICE)), rings, function(jj, _) return (jj % 2 == 1) and set[2] or set[1] end, set[2], set[2])
    box(K.deco, STEEL_DK, v3(x, y + 1.6, z), v3(1, 0, 0), v3(0, 0, 1), hx, 3.1, hz)
    if offices % 2 == 0 then
      box(K.deco, WHITE, v3(x + hx * 0.3, y + 3.2 + 6, z), v3(1, 0, 0), v3(0, 0, 1), 0.4, 12, 0.4)
      box(K.deco, CLOTHS[2], v3(x + hx * 0.3, y + 15.5, z), v3(1, 0, 0), v3(0, 0, 1), 0.7, 0.7, 0.7)
    end
  end
  for z = K.Z0 - 20, K.Z1 + 20, -72 do
    for _, e in ipairs({{K.X0, -1}, {K.X1, 1}}) do
      office(e[1] + e[2] * rnd(24, 60), z + rnd(-12, 12), e[1] - e[2], z)
    end
  end
  for x = K.X0 + 10, K.X1 - 10, 72 do
    office(x + rnd(-12, 12), K.Z0 + rnd(24, 60), x, K.Z0 - 1)
    office(x + rnd(-12, 12), K.Z1 - rnd(24, 60), x, K.Z1 + 1)
  end

  info(string.format("rooftop kit: %d triangles, %d bridges, %d towers, %d attics, %d terraces, %d vehicles, %d offices",
    tris(K.solid) + tris(K.deco) - before, bridges, towers, attics, houses, traffic, offices))
end

return T
