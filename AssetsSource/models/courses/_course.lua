-- The course library: one course built from its design -- the road along a Catmull-Rom curve through its
-- control points (SUB samples a segment), hay-bale walls either side, the valley round it rising away, a
-- start arch and a chequered finish arch, trees, bushes, flowers and rocks on the slopes, flags,
-- bunting, marquees, fences and a farm or two. Metres, Y up. A leading underscore keeps it out of the
-- build: each course's own script (cNN.lua, written by scripts/courses.ts from src/game/courses.ts)
-- includes it and calls build with its design and its params:
--
--   C: points ({x, y, z} each), berms (a number a point: metres the outside of the bend there is built up, + the
--      right edge, - the left), half_width, widths (a share of half_width a sample: the road narrowing and
--      widening), wall_h, start_point and finish_point (1-based), road, grass and
--      hay ({r, g, b}, linear), seed (the scenery's), urban (a city street: red and white water barriers for walls,
--      pavements and paving for fields, terraced houses and lamp posts for farms and fences; hay the barriers' colour),
--      start_ramp (the first stretch a steep wooden ramp off a raised start deck, on timber trestles),
--      shortcut ({from, to (1-based samples), half_width, pond_from, pond_to (shares of its length)} or nil: a
--      straight road across a bend from sample `from` to `to`, a gap over a duck pond in it -- src/game/courses.ts'
--      Shortcut; the game measures the race along it as src/game/track.ts' routeAt)
--   P: trees, bank -- the course script's params{}
--
-- The game measures the race along the same curve (src/game/track.ts), so SUB and the curve stay as they
-- are here, and src/game/sim.ts mirrors the road's top and the walls' inner faces: those stay exactly as they
-- are (the road's top at pos +/- right*W[i], each wall's inner face at +/-W[i] from -0.6 to wall_h). Every part
-- has one white material and its colours painted on its faces (vertex colours); the game's track entity gives
-- the whole model a MeshCollider: road, walls, valley and scenery all collide.
local M = {}

function M.build(C, P)
  local POINTS = C.points
  local SUB = 10
  local HW = C.half_width
  local START_POINT = C.start_point
  local FINISH_POINT = C.finish_point
  local WALL_T = 0.7

  -- One white material: every part's colours are painted on its faces (glTF multiplies them by it).
  local WHITE = material{name="Painted", base_color=v3(1,1,1), roughness=0.9, metallic=0}
  local SHINY = material{name="Painted gloss", base_color=v3(1,1,1), roughness=0.55, metallic=0}

  -- Colours, cached so equal colours are one object (a part is painted one pass per distinct colour).
  local KEYS = {}
  local function col(r, g_, b)
    r = math.max(0, math.min(1, r)); g_ = math.max(0, math.min(1, g_)); b = math.max(0, math.min(1, b))
    local k = string.format("%.3f %.3f %.3f", r, g_, b)
    local c = KEYS[k]
    if not c then c = {v=v3(r, g_, b)}; KEYS[k] = c end
    return c
  end
  local function tint(c, f) return col(c.v.x*f, c.v.y*f, c.v.z*f) end
  local function mix(a, b, t) return col(a.v.x + (b.v.x - a.v.x)*t, a.v.y + (b.v.y - a.v.y)*t, a.v.z + (b.v.z - a.v.z)*t) end
  local ROAD = col(C.road[1], C.road[2], C.road[3])
  local GRASS = col(C.grass[1], C.grass[2], C.grass[3])
  local HAY = col(C.hay[1], C.hay[2], C.hay[3])
  local SNOW = C.grass[2] > 0.7          -- the snowy course: no meadows, frosted crowns
  -- The city and the start ramp, in one table (the function is near Lua's limit of locals): whether each, the start
  -- ramp's timber (deck planks in a few tones, the trestles' beams), the pavement's and the parks' colours, houses built.
  -- `railed`: the first courses' walls are straw bales alone, each backed by a steel crowd barrier -- no sponsors'
  -- wraps, water barriers, timber rails or odd junk in the line.
  local X = {urban = C.urban == true, ramp = C.start_ramp == true, railed = C.railed == true, bare = C.bare == true, houses = 0,
    wood = {col(0.55, 0.36, 0.18), col(0.48, 0.3, 0.14), col(0.6, 0.41, 0.21)}, timber = col(0.34, 0.21, 0.1)}
  -- A themed course (C.theme: the tour's, src/game/courses.ts' THEMED): its scenery kit, _theme_<theme>.lua -- a table
  -- with build(K) (called near the end with the library's tools: see THEME KITS below) and, optionally, trees (a share
  -- of the slopes' trees kept, 1 if left out). A kit has no farm, fences or finish marquees of the library's.
  if C.theme then X.T = include("_theme_" .. C.theme .. ".lua") end
  -- (What T.paint and T.shape get as their last argument: filled in as the tools are made.)
  X.TK = {col = col, tint = tint, mix = mix}
  local PAINT_W = col(0.92, 0.92, 0.9)
  local PAINT_K = col(0.03, 0.03, 0.03)
  local RED = col(0.8, 0.05, 0.03)
  local BRIGHT = {
    col(0.85, 0.06, 0.04), col(0.05, 0.25, 0.85), col(0.95, 0.72, 0.03), col(0.06, 0.6, 0.15),
    col(0.9, 0.3, 0.02), col(0.55, 0.1, 0.75), col(0.95, 0.2, 0.5), col(0.02, 0.6, 0.7),
  }

  -- The curve, sampled: pos[i] and its flat right-hand direction right[i].
  local function pt(i)
    local n = #POINTS
    if i < 1 then i = 1 end
    if i > n then i = n end
    local p = POINTS[i]
    return v3(p[1], p[2], p[3])
  end
  local function catmull(p0, p1, p2, p3, t)
    local t2, t3 = t*t, t*t*t
    return (p1*2 + (p2 - p0)*t + (p0*2 - p1*5 + p2*4 - p3)*t2 + (p1*3 - p0 - p2*3 + p3)*t3) * 0.5
  end
  local pos = {}
  for i = 1, #POINTS - 1 do
    for s = 0, SUB - 1 do
      pos[#pos + 1] = catmull(pt(i-1), pt(i), pt(i+1), pt(i+2), s / SUB)
    end
  end
  pos[#pos + 1] = pt(#POINTS)
  local N = #pos
  local right = {}
  for i = 1, N do
    local a = pos[math.max(1, i-1)]
    local b = pos[math.min(N, i+1)]
    local t = normalize(v3(b.x - a.x, 0, b.z - a.z))
    right[i] = v3(-t.z, 0, t.x)
  end
  -- Each sample's half width: the road narrowing and widening along the course -- C.widths, a share of HW a sample,
  -- as src/game/track.ts' widthProfile makes them (the designed width, HW, where none is given).
  local W = {}
  for i = 1, N do W[i] = HW * ((C.widths and C.widths[i]) or 1) end
  -- The shortcut (the first course's, over the duck pond): its chord from main sample A to B, and where a point is
  -- against it -- `u` its share along, `d` across (metres, + its right), `y` its road's height there.
  if C.shortcut then
    local S = C.shortcut
    local a, b = pos[S.from + 1], pos[S.to + 1]
    -- Its road's heights at either end, as the game measures them (track.ts' withShortcut): a straight slope meeting
    -- the main road's surface where it leaves the road's edge and where it comes back over it.
    if S.y_from then a, b = v3(a.x, S.y_from, a.z), v3(b.x, S.y_to, b.z) end
    local len = math.sqrt((b.x - a.x)^2 + (b.z - a.z)^2)
    X.cut = {a=a, b=b, len=len, ux=(b.x - a.x) / len, uz=(b.z - a.z) / len, hw=S.half_width, pond_from=S.pond_from, pond_to=S.pond_to}
    function X.cut_at(x, z)
      local c = X.cut
      local u = ((x - c.a.x) * c.ux + (z - c.a.z) * c.uz) / c.len
      local d = (x - c.a.x) * -c.uz + (z - c.a.z) * c.ux
      return u, d, c.a.y + (c.b.y - c.a.y) * math.max(0, math.min(1, u))
    end
    -- The pond: an ellipse about the gap's middle, along the chord and across it.
    local mid = (S.pond_from + S.pond_to) / 2
    X.pond = {u=mid, ra=(S.pond_to - S.pond_from) * len / 2 + 5, rd=10}
    function X.in_pond(x, z, grow)
      local u, d = X.cut_at(x, z)
      local q = X.pond
      return ((u - q.u) * X.cut.len / (q.ra + grow))^2 + (d / (q.rd + grow))^2 < 1
    end
  end

  -- The berms, a point's straight on to the next's along its samples (as src/game/track.ts has them): each
  -- sample's bank, + its right edge built up, - its left; and how high the road is at `side` (-1 left, 1 right).
  local BERMS = C.berms or {}
  local bank = {}
  for i = 1, N do
    local p, t = math.floor((i - 1) / SUB), ((i - 1) % SUB) / SUB
    bank[i] = (BERMS[p + 1] or 0) * (1 - t) + (BERMS[math.min(#POINTS, p + 2)] or 0) * t
  end
  local function lift(i, side)
    local b = bank[i]
    if (b > 0 and side > 0) or (b < 0 and side < 0) then return math.abs(b) end
    return 0
  end

  -- A mesh built of closed shells: vertices, faces wound so their normal points along `want`, and each
  -- face's colour (the builder's `ink` when it was made).
  local function builder()
    return {vs={}, fs={}, cs={}, ink=PAINT_W}
  end
  local function vert(b, p)
    b.vs[#b.vs + 1] = p
    return #b.vs
  end
  local function face(b, f)
    b.fs[#b.fs + 1] = f
    b.cs[#b.fs] = b.ink
  end
  local function quad(b, i1, i2, i3, i4, want)
    local a, c, d = b.vs[i1], b.vs[i2], b.vs[i3]
    local n = cross(c - a, d - a)
    if dot(n, want) < 0 then face(b, {i4, i3, i2, i1}) else face(b, {i1, i2, i3, i4}) end
  end
  local function tri(b, i1, i2, i3, want)
    local a = b.vs[i1]
    local n = cross(b.vs[i2] - a, b.vs[i3] - a)
    if dot(n, want) < 0 then face(b, {i3, i2, i1}) else face(b, {i1, i2, i3}) end
  end
  local UP = axis_y()
  -- Emitted open by the check's count (blocks butt end to end); painted a pass per colour, by face order.
  local function done(b, name, mat)
    local function painted(b)
    local m = polyhedron{vertices=b.vs, faces=b.fs}
    local order, seen = {}, {}
    local cs = b.cs
    for f = 1, #b.fs do
      local c = cs[f]
      if not seen[c] then seen[c] = true; order[#order + 1] = c end
    end
    local count, most = {}, order[1]
    for f = 1, #b.fs do local c = cs[f]; count[c] = (count[c] or 0) + 1; if count[c] > count[most] then most = c end end
    m = paint_faces(m, {faces=faces_in_box(m, {min=v3(-1e7, -1e7, -1e7), max=v3(1e7, 1e7, 1e7)}), color=most.v})
    for _, c in ipairs(order) do
      if c ~= most then
        local k = 0
        m = paint_faces(m, {faces=faces_where(m, function(_) k = k + 1; return cs[k] == c end), color=c.v})
      end
    end
    return m
    end
    -- (The first course's parts come in pieces -- b.more, builders of whole shells each, by X.sub -- each painted by
    -- itself, a few colours a piece, then merged into the one part: a pass a colour over every face of a big part is
    -- more than Gladius's instruction budget allows.)
    if b.more then
      local parts = {}
      for _, q in ipairs(b.more) do
        if #q.fs > 0 then parts[#parts + 1] = {mesh=painted(q), material=mat or WHITE} end
      end
      if #b.fs > 0 then parts[#parts + 1] = {mesh=painted(b), material=mat or WHITE} end
      if #parts == 1 then emit(parts[1].mesh, {name=name, material=mat or WHITE, open=true}) end
      if #parts > 1 then emit(merge({parts=parts, mode="compatible"})[1].mesh, {name=name, material=mat or WHITE, open=true}) end
      return
    end
    if #b.fs == 0 then return end
    emit(painted(b), {name=name, material=mat or WHITE, open=true})
  end
  -- A piece of builder `b` for `key` (a colour, a palette, a name): on the first course a builder of its own, painted
  -- alone and merged into b's part by `done`; on every other course b itself.
  function X.sub(b, key)
    if not (X.bare or X.T) then return b end
    b.more, b.keys = b.more or {}, b.keys or {}
    local q = b.keys[key]
    if not q then
      q = builder()
      b.keys[key] = q
      b.more[#b.more + 1] = q
    end
    return q
  end

  -- A closed six-sided shell: a0..a3 its bottom ring, b0..b3 the top ring above them, wound outwards.
  local function hexa(b, a0, a1, a2, a3, b0, b1, b2, b3)
    local c = (a0 + a1 + a2 + a3 + b0 + b1 + b2 + b3) * 0.125
    local i = {vert(b, a0), vert(b, a1), vert(b, a2), vert(b, a3), vert(b, b0), vert(b, b1), vert(b, b2), vert(b, b3)}
    local function side(p, q, r, s)
      local m = (b.vs[i[p]] + b.vs[i[q]] + b.vs[i[r]] + b.vs[i[s]]) * 0.25
      quad(b, i[p], i[q], i[r], i[s], m - c)
    end
    side(1, 2, 3, 4)
    side(5, 6, 7, 8)
    side(1, 2, 6, 5)
    side(2, 3, 7, 6)
    side(3, 4, 8, 7)
    side(4, 1, 5, 8)
  end

  -- A prism through rings of equal count (each ring a convex loop, in order round it): its sides, coloured
  -- by colour(j, k) (j the band between ring j and j+1, k the edge from point k), and both ends capped with
  -- a fan to the ring's middle, coloured cap0 and cap1.
  local function prism(b, rings, colour, cap0, cap1)
    local n = #rings[1]
    local ids, cens = {}, {}
    for j, ring in ipairs(rings) do
      ids[j] = {}
      local c = v3(0, 0, 0)
      for k, p in ipairs(ring) do ids[j][k] = vert(b, p); c = c + p end
      cens[j] = c * (1 / n)
    end
    for j = 1, #rings - 1 do
      local mid = (cens[j] + cens[j+1]) * 0.5
      for k = 1, n do
        local k2 = k % n + 1
        local a, bb, c, d = ids[j][k], ids[j][k2], ids[j+1][k2], ids[j+1][k]
        b.ink = colour(j, k)
        quad(b, a, bb, c, d, (b.vs[a] + b.vs[bb] + b.vs[c] + b.vs[d]) * 0.25 - mid)
      end
    end
    for e = 1, 2 do
      local j, o = (e == 1) and 1 or #rings, (e == 1) and 2 or (#rings - 1)
      local want = cens[j] - cens[o]
      local ci = vert(b, cens[j])
      b.ink = (e == 1) and cap0 or cap1
      for k = 1, n do tri(b, ids[j][k], ids[j][k % n + 1], ci, want) end
    end
  end
  -- A horizontal ring of n points round c, radius r (or rx, rz), turned by `turn` radians.
  local function ring(c, rx, rz, n, turn)
    local out = {}
    for k = 0, n - 1 do
      local a = turn + k / n * math.pi * 2
      out[#out + 1] = c + v3(math.cos(a) * rx, 0, math.sin(a) * rz)
    end
    return out
  end
  local function flat(c) return function(_, _) return c end end
  -- An upright cylinder (or a tapered one: r1 at the top), from y0 to y1 at x, z.
  local function column(b, x, z, y0, y1, r0, r1, n, c, turn)
    prism(b, {ring(v3(x, y0, z), r0, r0, n, turn or 0), ring(v3(x, y1, z), r1, r1, n, turn or 0)}, flat(c), c, c)
  end
  -- A cone: a ring (of points about centre `under`), its tip, and its underside a fan to `under`.
  local function cone(b, pts, under, tip, colour, undercol)
    local ti, ui = vert(b, tip), vert(b, under)
    local ids = {}
    for k, p in ipairs(pts) do ids[k] = vert(b, p) end
    local n = #pts
    for k = 1, n do
      local k2 = k % n + 1
      local m = (pts[k] + pts[k2]) * 0.5
      b.ink = colour(k)
      tri(b, ids[k], ids[k2], ti, v3(m.x - under.x, 0, m.z - under.z))
      b.ink = undercol
      tri(b, ids[k], ids[k2], ui, v3(0, -1, 0))
    end
  end
  -- A lumpy ball: centre c, radii rx, ry, rz, `segs` round and `rings_` from pole to pole; each vertex pushed
  -- out by lump() (a factor), each face coloured colour(face's centre, its outward direction).
  local function ball(b, c, rx, ry, rz, segs, rings_, lump, colour)
    local top = vert(b, c + v3(0, ry * lump(), 0))
    local bot = vert(b, c - v3(0, ry * lump(), 0))
    local R = {}
    for j = 1, rings_ - 1 do
      local phi = j / rings_ * math.pi
      local sy, cy = math.sin(phi), math.cos(phi)
      R[j] = {}
      for k = 0, segs - 1 do
        local a = (k + (j % 2) * 0.5) / segs * math.pi * 2
        local f = lump()
        R[j][k + 1] = vert(b, c + v3(math.cos(a) * sy * rx * f, cy * ry * f, math.sin(a) * sy * rz * f))
      end
    end
    local function want(...)
      local s = v3(0, 0, 0)
      local ps = {...}
      for _, i in ipairs(ps) do s = s + b.vs[i] end
      return s * (1 / #ps) - c
    end
    for k = 1, segs do
      local k2 = k % segs + 1
      local w = want(R[1][k], R[1][k2], top)
      b.ink = colour(w); tri(b, R[1][k], R[1][k2], top, w)
      local l = rings_ - 1
      w = want(R[l][k], R[l][k2], bot)
      b.ink = colour(w); tri(b, R[l][k], R[l][k2], bot, w)
    end
    -- Rings offset half a step each: the band between two is triangles, zig-zag.
    for j = 1, rings_ - 2 do
      for k = 1, segs do
        local k2 = k % segs + 1
        local a, a2, d, d2 = R[j][k], R[j][k2], R[j+1][k], R[j+1][k2]
        local w = want(a, a2, (j % 2 == 1) and d2 or d)
        b.ink = colour(w)
        if j % 2 == 1 then tri(b, a, a2, d2, w) else tri(b, a, a2, d, w) end
        w = want(a, d, d2)
        b.ink = colour(w)
        if j % 2 == 1 then tri(b, a, d2, d, w) else tri(b, a2, d2, d, w) end
      end
    end
  end

  -- A small LCG of its own: the same scenery every build.
  local seed = C.seed
  local g = {range = function(_, lo, hi)
    seed = (seed * 1103515245 + 12345) % 2147483648
    return lo + (hi - lo) * seed / 2147483648
  end}
  local function pick(list) return list[math.min(#list, math.floor(g:range(1, #list + 1)))] end
  -- A stable hash in [0, 1) of a few numbers: patterns that do not shift when the LCG's draws change.
  local function hash(a, b)
    local s = math.sin(a * 12.9898 + (b or 0) * 78.233) * 43758.5453
    return s - math.floor(s)
  end

  X.TK.hash = hash
  -- The start ramp: from the road's first sample to the end of the first stretch past the start line.
  X.ramp_end = START_POINT * SUB + 1
  -- How far the ground falls away under the start ramp: the deck stands on trestles, highest behind the start line.
  X.rise = 2.6
  function X.drop(i)
    if not X.ramp or i >= X.ramp_end then return 0 end
    local s0 = (START_POINT - 1) * SUB + 1
    if i <= s0 then return X.rise end
    return X.rise * (1 - (i - s0) / (X.ramp_end - s0))
  end

  -- The road on past both ends, for the look alone (the race, src/game/track.ts, knows nothing of it): ROAD_ON metres
  -- more behind the start and past the finish, bending gently away and falling on as the road fell (a share less
  -- steep, ON_FALL), so the course reads as a stretch of a real road. X.ext[1] runs back from the first sample,
  -- X.ext[2] on from the last: each a list of {p (its middle, on its top), r (its right)}. Drawn as the road is (and
  -- walked on: the road's part), the valley shaped round it as round the road (`nearest`).
  X.ext = {}
  do
    local ROAD_ON, ON_STEP, ON_FALL = 120, 3, 0.8
    for k, e in ipairs({{1, 2, -1}, {N, N - 1, 1}}) do
      local i, j, dir = e[1], e[2], e[3]
      local p = pos[i]
      local d = v3(p.x - pos[j].x, 0, p.z - pos[j].z)
      local run = math.sqrt(d.x * d.x + d.z * d.z)
      d = d * (1 / math.max(run, 1e-6))
      local fall = (p.y - pos[j].y) / math.max(run, 1e-6) * ON_FALL
      -- Each end its own gentle bend, one way or the other (radians a metre).
      local bend = (hash(C.seed or 1, k * 7) - 0.5) * 0.014
      local list = {}
      for n = 1, math.floor(ROAD_ON / ON_STEP) do
        local a = bend * ON_STEP
        d = v3(d.x * math.cos(a) - d.z * math.sin(a), 0, d.x * math.sin(a) + d.z * math.cos(a))
        p = p + d * ON_STEP + v3(0, fall * ON_STEP, 0)
        list[n] = {p = p, r = v3(-d.z, 0, d.x) * dir}
      end
      X.ext[k] = list
    end
  end

  -- The road: a slab half a metre deep along the curve, its vertices shared, closed at both ends; its top
  -- painted segment by segment in a few tones of the course's road, so it reads as patched and worn.
  local road = builder()
  local DEEP = v3(0, -0.5, 0)
  local L, R, Lb, Rb = {}, {}, {}, {}
  for i = 1, N do
    -- Each edge raised by its berm: the road slopes straight up to the outside of a bend.
    local ul, ur = v3(0, lift(i, -1), 0), v3(0, lift(i, 1), 0)
    L[i] = vert(road, pos[i] - right[i]*W[i] + ul)
    R[i] = vert(road, pos[i] + right[i]*W[i] + ur)
    Lb[i] = vert(road, pos[i] - right[i]*W[i] + DEEP)
    Rb[i] = vert(road, pos[i] + right[i]*W[i] + DEEP)
  end
  local ROAD_TONES = {tint(ROAD, 0.86), tint(ROAD, 0.94), ROAD, tint(ROAD, 1.07), tint(ROAD, 1.15)}
  local ROAD_SIDE = tint(ROAD, 0.6)
  for i = 1, N - 1 do
    local w = math.sin(i * 0.37) * 0.8 + math.sin(i * 0.11 + 1.3) + (hash(i, 3) - 0.5) * 1.4
    road.ink = ROAD_TONES[math.max(1, math.min(5, math.floor(w + 3.5)))]
    -- Ramshackle: here and there a patch of fresh black filler, a muddy stretch, a run of gravel.
    local p = hash(i, 9)
    if p < 0.06 then road.ink = tint(ROAD, 0.55) elseif X.urban then
      -- A city street: a patch of fresh tarmac now and then, a drain cover's grey.
      if p < 0.1 then road.ink = tint(ROAD, 1.3) end
    elseif p < 0.1 then road.ink = mix(ROAD, col(0.36, 0.25, 0.14), 0.6) elseif p < 0.13 then road.ink = mix(ROAD, col(0.62, 0.6, 0.56), 0.5) end
    if X.ramp and i < X.ramp_end then road.ink = X.wood[i % 3 + 1] end
    quad(road, L[i], R[i], R[i+1], L[i+1], UP)
    road.ink = ROAD_SIDE
    quad(road, Lb[i], Rb[i], Rb[i+1], Lb[i+1], UP * -1)
    quad(road, L[i], L[i+1], Lb[i+1], Lb[i], right[i] * -1)
    quad(road, R[i], R[i+1], Rb[i+1], Rb[i], right[i])
  end
  local function along(i) return v3(right[i].z, 0, -right[i].x) end   -- down the road
  quad(road, L[1], R[1], Rb[1], Lb[1], along(1) * -1)
  quad(road, L[N], R[N], Rb[N], Lb[N], along(N))
  -- The road on past its ends (X.ext): the same slab, from a hair past each end (its own shell), a dashed white line
  -- down its middle as a road in use has.
  for k, list in ipairs(X.ext) do
    local first = {p = (k == 1) and pos[1] or pos[N], r = (k == 1) and right[1] or right[N]}
    local prev = first
    for n, q in ipairs(list) do
      local a0 = (n == 1) and lerp(prev.p, q.p, 0.01) or prev.p
      -- (Each segment's near corners the last one's far ones: one shell, its vertices shared.)
      local l0, r0, lb0, rb0
      if n == 1 then
        l0, r0 = vert(road, a0 - prev.r * HW), vert(road, a0 + prev.r * HW)
        lb0, rb0 = vert(road, a0 - prev.r * HW + DEEP), vert(road, a0 + prev.r * HW + DEEP)
      else
        l0, r0, lb0, rb0 = X.lastV[1], X.lastV[2], X.lastV[3], X.lastV[4]
      end
      local l1, r1 = vert(road, q.p - q.r * HW), vert(road, q.p + q.r * HW)
      local lb1, rb1 = vert(road, q.p - q.r * HW + DEEP), vert(road, q.p + q.r * HW + DEEP)
      X.lastV = {l1, r1, lb1, rb1}
      local w = math.sin(n * 0.37 + k) * 0.8 + (hash(n, 3 + k) - 0.5) * 1.4
      road.ink = ROAD_TONES[math.max(1, math.min(5, math.floor(w + 3.5)))]
      -- (Wound so its top faces up whichever way the list runs.)
      if k == 1 then quad(road, l1, r1, r0, l0, UP) else quad(road, l0, r0, r1, l1, UP) end
      road.ink = ROAD_SIDE
      if k == 1 then quad(road, lb1, rb1, rb0, lb0, UP * -1) else quad(road, lb0, rb0, rb1, lb1, UP * -1) end
      quad(road, l0, l1, lb1, lb0, prev.r * -1)
      quad(road, r0, r1, rb1, rb0, prev.r)
      if n == 1 then quad(road, l0, r0, rb0, lb0, (q.p - a0) * -1) end
      if n == #list then quad(road, l1, r1, rb1, lb1, q.p - a0) end
      -- A dash of the centre line every other step, a hair over the top.
      if n % 2 == 0 then
        local m0, m1 = lerp(a0, q.p, 0.2) + v3(0, 0.01, 0), lerp(a0, q.p, 0.8) + v3(0, 0.01, 0)
        road.ink = PAINT_W
        local lo, hi = v3(0, -0.01, 0), v3(0, 0.004, 0)
        hexa(road, m0 - q.r * 0.07 + lo, m0 + q.r * 0.07 + lo, m1 + q.r * 0.07 + lo, m1 - q.r * 0.07 + lo,
          m0 - q.r * 0.07 + hi, m0 + q.r * 0.07 + hi, m1 + q.r * 0.07 + hi, m1 - q.r * 0.07 + hi)
      end
      prev = q
    end
  end

  -- Rustic: the odd dirt patch, loose straw blown off the bales, and bits of junk dropped by earlier karts -- flat
  -- shapes a hair over the road's top (MUCK_UP: the wheels never feel it), in the road's own mesh (no draw call of
  -- their own). Never on the start ramp's deck nor the start grid.
  local MUCK_UP = 0.012
  -- (Their own part, "muck": drawn, but never solid -- a low kart never snags on a patch's edge.)
  local muck = builder()
  -- The road's top at sample `f` (fractional, between samples) and `d` metres across it (+ its right).
  local function top(f, d)
    f = math.max(1, math.min(N - 0.001, f))
    local i = math.floor(f)
    local t = f - i
    -- (Each sample its own width: as far a share across at either end.)
    local a = lerp(road.vs[L[i]], road.vs[R[i]], math.max(0, math.min(1, (d + W[i]) / (2 * W[i]))))
    local b = lerp(road.vs[L[i + 1]], road.vs[R[i + 1]], math.max(0, math.min(1, (d + W[i + 1]) / (2 * W[i + 1]))))
    return lerp(a, b, t) + v3(0, MUCK_UP, 0)
  end
  -- A flat blob: `n` points round sample `i`'s `d` across, `rx` along and `rz` across (metres), each its own reach.
  local function blob(i, d, rx, rz, n, turn, key)
    local si = math.max(1, math.min(N - 1, math.floor(i)))
    local seg = math.max(0.2, length(pos[si + 1] - pos[si]))
    -- A thin closed slab: its top a hair over the road, its underside a hair into it. Kept clear of the road's
    -- edges as a whole (its middle moved in), so no point is pinched against them; wound one way all round.
    d = math.max(-W[si] + 0.15 + rz * 1.2, math.min(W[si] - 0.15 - rz * 1.2, d))
    local DOWN = v3(0, -MUCK_UP * 2, 0)
    local ct = top(i, d)
    local c, cb = vert(muck, ct), vert(muck, ct + DOWN)
    local ring_, under = {}, {}
    for k = 0, n - 1 do
      local a = turn + k / n * math.pi * 2
      local reach = 0.7 + hash(key, k + 40) * 0.5
      local u, v = math.cos(a) * rx * reach, math.sin(a) * rz * reach
      local q = top(i + u / seg, d + v)
      ring_[#ring_ + 1] = vert(muck, q)
      under[#under + 1] = vert(muck, q + DOWN)
    end
    -- Which way round the ring runs, seen from above.
    local n1 = cross(muck.vs[ring_[1]] - ct, muck.vs[ring_[2]] - ct)
    local ccw = n1.y > 0
    for k = 1, n do
      local k2 = k % n + 1
      local a, b = ring_[k], ring_[k2]
      local ua, ub = under[k], under[k2]
      if not ccw then a, b, ua, ub = b, a, ub, ua end
      face(muck, {c, a, b})
      face(muck, {cb, ub, ua})
      face(muck, {b, a, ua, ub})
    end
  end
  local DIRT = {mix(ROAD, col(0.33, 0.22, 0.12), 0.75), mix(ROAD, col(0.42, 0.3, 0.17), 0.7), col(0.28, 0.2, 0.12)}
  local STRAWS = {tint(HAY, 1.05), tint(HAY, 0.9), mix(HAY, col(0.85, 0.7, 0.35), 0.4)}
  local JUNK = {col(0.45, 0.33, 0.2), col(0.12, 0.12, 0.13), col(0.55, 0.53, 0.5), col(0.6, 0.2, 0.12)}
  local from = (X.ramp and X.ramp_end or 1) + 2
  local grid = (START_POINT - 1) * SUB + 1
  for i = from, N - 2 do
    if math.abs(i - grid) > 6 then
      -- A dirt patch: a muddy smear, wider than long, somewhere across the road.
      if hash(i, 51) < 0.035 then
        muck.ink = DIRT[math.floor(hash(i, 52) * #DIRT) + 1]
        blob(i, (hash(i, 53) - 0.5) * W[i] * 1.4, 0.9 + hash(i, 54) * 1.6, 0.6 + hash(i, 55) * 1.2, 9, hash(i, 56) * 3, i)
      end
      -- Loose straw: a scatter of thin wisps, near the walls mostly, where the bales shed it.
      if hash(i, 61) < 0.09 then
        muck.ink = STRAWS[math.floor(hash(i, 62) * #STRAWS) + 1]
        local side = hash(i, 63) < 0.5 and -1 or 1
        local d0 = side * (W[i] - 0.4 - hash(i, 64) * W[i] * 0.6)
        for w = 0, 4 + math.floor(hash(i, 65) * 5) do
          local dw = math.max(-W[i] + 0.1, math.min(W[i] - 0.1, d0 + (hash(i * 7 + w, 66) - 0.5) * 1.4))
          blob(i + (hash(i * 7 + w, 67) - 0.5) * 0.8, dw, 0.22 + hash(i * 7 + w, 68) * 0.18, 0.025, 4, hash(i * 7 + w, 69) * 6.28, i * 13 + w)
        end
      end
      -- Junk: a bit of plank, a bottle top, a dropped bolt -- small and few.
      if hash(i, 71) < 0.03 then
        muck.ink = JUNK[math.floor(hash(i, 72) * #JUNK) + 1]
        blob(i, (hash(i, 73) - 0.5) * W[i] * 1.6, 0.14 + hash(i, 74) * 0.2, 0.06 + hash(i, 75) * 0.06, 5, hash(i, 76) * 6.28, i * 3 + 1)
      end
    end
  end
  done(road, "road")
  done(muck, "muck")

  -- The walls, both sides: a bale a segment, sunk into the ground, its inner face flat on the road's edge (+/-W[i]) (the physics'
  -- wall) and its outer top edge chamfered. Most are straw in a few tones with two red twines round them; runs
  -- of them, and every one near the start and the finish, are wrapped in a sponsor's plastic with a white band.
  local walls = builder()
  local H = C.wall_h
  local SINK = -0.6
  local STRAW = {tint(HAY, 0.9), HAY, tint(HAY, 1.06), mix(HAY, col(0.75, 0.55, 0.25), 0.35), tint(HAY, 0.82)}
  local TWINE = col(0.6, 0.1, 0.04)
  local WRAPS = {BRIGHT[1], BRIGHT[2], BRIGHT[3], BRIGHT[4], BRIGHT[7], PAINT_K}
  local s_start, s_fin = (START_POINT - 1) * SUB + 1, (FINISH_POINT - 1) * SUB + 1
  local CH = math.min(0.15, H * 0.25)
  -- The share of a city course's runs of wall (three bales a run) that are straw bales, not water barriers -- each of
  -- those bales backed by a steel crowd barrier (`crowd_barrier`).
  local STRAW_RUNS = 0.35
  -- A crowd barrier: a galvanised panel a bale long, behind the bale (out past its bulge), a tube frame round
  -- upright bars, two flat feet across. From p0 to p1 at the ground (y = up), r the way out from the road.
  local STEEL = col(0.6, 0.62, 0.64)
  local STEEL_DK = col(0.4, 0.42, 0.44)
  local BAR_H, BARS, TUBE, BAR = 1.1, 11, 0.022, 0.01
  local function slab(b, p, q, u, v)
    hexa(b, p - u - v, p + u - v, p + u + v, p - u + v, q - u - v, q + u - v, q + u + v, q - u + v)
  end
  local function crowd_barrier(b, p0, p1, r, up)
    local t = normalize(p1 - p0)
    local Y = v3(0, 1, 0)
    local function at(s, y) return lerp(p0, p1, s) + v3(0, up + y, 0) end
    b.ink = STEEL
    -- the frame: two uprights down into the ground, the top and bottom rails between them
    for _, s in ipairs({0.02, 0.98}) do slab(b, at(s, SINK), at(s, BAR_H), t * TUBE, r * TUBE) end
    slab(b, at(0.02, BAR_H - TUBE), at(0.98, BAR_H - TUBE), Y * TUBE, r * TUBE)
    slab(b, at(0.02, 0.14), at(0.98, 0.14), Y * TUBE * 0.8, r * TUBE * 0.8)
    -- the upright bars
    for k = 1, BARS do
      local s = 0.02 + 0.96 * k / (BARS + 1)
      slab(b, at(s, 0.14), at(s, BAR_H - TUBE), t * BAR, r * BAR)
    end
    -- the feet: flat bars across, under each upright
    b.ink = STEEL_DK
    for _, s in ipairs({0.05, 0.95}) do
      local c = at(s, 0.012)
      slab(b, c - r * 0.3, c + r * 0.3, Y * 0.012, t * 0.035)
    end
  end
  for i = 1, N - 1 do
    for side = -1, 1, 2 do
      local r0, r1 = right[i]*side, right[i+1]*side
      -- Where the shortcut runs through this wall (leaving the road or rejoining it): an opening, no bale -- and a
      -- wide mouth at either end of it, CUT_MOUTH samples either way on the shortcut's side, no wall nose between the
      -- two roads (as track.ts' cutOpening has it).
      local opening = false
      if X.cut then
        local w = lerp(pos[i], pos[i+1], 0.5) + r0 * ((W[i] + W[i+1]) / 2 + WALL_T * 0.5)
        local u, d = X.cut_at(w.x, w.z)
        opening = u > -0.02 and u < 1.02 and math.abs(d) < X.cut.hw + 0.6
        for _, e in ipairs({{C.shortcut.from + 1, 0.15}, {C.shortcut.to + 1, 0.85}}) do
          if not opening and math.abs(i - e[1]) <= 8 then
            local c = X.cut
            local q = v3(c.a.x + c.ux * c.len * e[2], 0, c.a.z + c.uz * c.len * e[2])
            local across = (q.x - pos[i].x) * right[i].x + (q.z - pos[i].z) * right[i].z
            if (across > 0 and side > 0) or (across < 0 and side < 0) then opening = true end
          end
        end
      end
      -- (A bare course has no walls: loose bales line it, laid by the game.)
      if not opening and not X.bare then
      -- A couple of centimetres short at both ends: the bales stand apart, never sharing a corner.
      local p0, p1 = lerp(pos[i], pos[i+1], 0.01), lerp(pos[i], pos[i+1], 0.99)
      local i0, i1 = p0 + r0*(W[i] + (W[i+1] - W[i]) * 0.01), p1 + r1*(W[i] + (W[i+1] - W[i]) * 0.99)
      local o0, o1 = i0 + r0*WALL_T, i1 + r1*WALL_T
      local run = math.floor((i - 1) / 3)
      local near = math.abs(i - s_start) < 12 or math.abs(i - s_fin) < 16
      -- (In the city, now and then a run of straw bales stands in for the water barriers: STRAW_RUNS of the runs.)
      local strawRun = X.urban and hash(run, side + 29) < STRAW_RUNS
      local wrapped = not X.railed and (near or (X.urban and not strawRun) or (X.ramp and i < X.ramp_end) or hash(run, side) < 0.14)
      -- Ramshackle: each bale its own height and sagging a little out of true at its top, its outer side further
      -- out or in (the inner face stays where the road's edge is: the physics' wall).
      -- (Not the sponsors' plastic-wrapped ones: those are neat, and their bands must stay in order up their sides.)
      local sag = wrapped and 0 or (hash(i, side + 11) - 0.5) * 0.34
      local slump = wrapped and 1 or 1 + (hash(i, side + 13) - 0.5) * 0.42
      -- Each end of its outer side its own way out or in: the bale stands twisted, not square to the road.
      local bulge0 = (hash(i, side + 17) - 0.5) * 0.36
      local bulge1 = (hash(i, side + 19) - 0.5) * 0.36
      local function section(t)
        local a, o = lerp(i0, i1, t), lerp(o0, o1, t)
        o = o + r0 * (bulge0 + (bulge1 - bulge0) * t)
        -- On a berm the wall stands on the built-up edge: its top raised with it, its foot still in the ground.
        local up = lift(i, side) * (1 - t) + lift(i + 1, side) * t
        local h = H * slump + up
        local pts = {a + v3(0, SINK, 0)}
        if wrapped then
          pts[#pts + 1] = a + v3(0, up + H * 0.3, 0)
          pts[#pts + 1] = a + v3(0, up + H * 0.7, 0)
        end
        pts[#pts + 1] = a + v3(0, math.max(up + H, h), 0)
        pts[#pts + 1] = lerp(a, o, 0.8) + v3(0, h + sag, 0)
        pts[#pts + 1] = o + v3(0, h + sag - CH, 0)
        if wrapped then
          pts[#pts + 1] = o + v3(0, up + H * 0.7, 0)
          pts[#pts + 1] = o + v3(0, up + H * 0.3, 0)
        end
        pts[#pts + 1] = o + v3(0, SINK, 0)
        return pts
      end
      if wrapped then
        local wrap = WRAPS[math.floor(hash(run, side + 7) * #WRAPS) + 1]
        if near then wrap = WRAPS[(run + (side > 0 and 1 or 0)) % 2 == 0 and 1 or 2] end
        -- The city's water barriers: red and white by turns; the start ramp's timber rails.
        if X.urban and not near then wrap = (i % 2 == 0) and HAY or PAINT_W end
        if X.ramp and i < X.ramp_end then wrap = X.timber end
        prism(walls, {section(0), section(1)}, function(_, k) return (k == 2 or k == 7) and PAINT_W or wrap end, wrap, wrap)
      else
        local straw = STRAW[math.floor(hash(i, side + 3) * #STRAW) + 1]
        -- Where the bales ran out: an old pallet, a stack of tyres, a sheet of rusty tin, stood in their place.
        local odd = X.railed and 1 or hash(i, side + 23)
        if odd < 0.07 then straw = col(0.45, 0.33, 0.2) elseif odd < 0.11 then straw = col(0.06, 0.06, 0.07) elseif odd < 0.14 then straw = col(0.5, 0.26, 0.12) end
        local cut = tint(straw, 0.85)
        prism(walls, {section(0), section(0.28), section(0.31), section(0.69), section(0.72), section(1)},
          function(j, _) return (j == 2 or j == 4) and TWINE or straw end, cut, cut)
        -- In the city, the straw stands in front of a steel crowd barrier: the barrier out past the bale's bulge.
        if X.urban or X.railed then
          local back = WALL_T + 0.32
          local up = math.min(lift(i, side), lift(i + 1, side))
          crowd_barrier(walls, i0 + r0 * back, i1 + r1 * back, normalize(r0 + r1), up)
        end
        -- Now and then one more bale slung on top, askew and set back from the road: a heap, not a line.
        if hash(i, side + 31) < 0.1 and not near then
          local h0 = H * slump + lift(i, side)
          local back = r0 * (0.15 + hash(i, side + 33) * 0.2)
          local skew = (hash(i, side + 35) - 0.5) * 0.3
          local q0 = lerp(i0, i1, 0.15 + skew * 0.3) + back
          local q1 = lerp(i0, i1, 0.85 + skew * 0.3) + back
          local o0b, o1b = q0 + r0 * (WALL_T * 0.75 + skew), q1 + r0 * (WALL_T * 0.75 - skew)
          local bh = H * 0.6
          local function lay(a, o, t)
            local y = h0 + sag * 0.8 + (t - 0.5) * skew * 0.4
            return {a + v3(0, y - 0.05, 0), a + v3(0, y + bh, 0), o + v3(0, y + bh - CH * 0.6, 0), o + v3(0, y - 0.05, 0)}
          end
          local top_straw = STRAW[math.floor(hash(i, side + 37) * #STRAW) + 1]
          prism(walls, {lay(q0, o0b, 0), lay(q1, o1b, 1)}, function() return top_straw end, tint(top_straw, 0.85), tint(top_straw, 0.85))
        end
      end
      end
    end
  end
  -- A bare course: no walls (loose bales and crowd barriers line it, laid by the game) -- a grass verge either side at the road's
  -- height for them to stand on.
  if X.bare then
    -- (The crowd barriers are the game's own, loose: src/game/systems/course.ts stands them on the verge, 1.02 m out.)
    local VERGE = WALL_T + 0.9
    local VERGE_C = mix(GRASS, col(0.45, 0.4, 0.2), 0.3)
    for i = 1, N - 1 do
      for side = -1, 1, 2 do
        local r0, r1 = right[i]*side, right[i+1]*side
        -- (A hair short at both ends, as the bales: no two pieces share a face.)
        local p0, p1 = lerp(pos[i], pos[i+1], 0.005), lerp(pos[i], pos[i+1], 0.995)
        local i0, i1 = p0 + r0*W[i], p1 + r1*W[i+1]
        local u0, u1 = lift(i, side) - 0.01, lift(i + 1, side) - 0.01
        walls.ink = VERGE_C
        hexa(walls, i0 + v3(0, SINK, 0), i1 + v3(0, SINK, 0), i1 + r1*VERGE + v3(0, SINK, 0), i0 + r0*VERGE + v3(0, SINK, 0),
          i0 + v3(0, u0, 0), i1 + v3(0, u1, 0), i1 + r1*VERGE + v3(0, u1, 0), i0 + r0*VERGE + v3(0, u0, 0))
      end
    end
  end
  -- A wall across each end: behind the start grid, and at the end of the run-out.
  -- (None now: the road runs on past both ends, X.ext.)
  for _, e in ipairs({}) do
    local i, out = e[1], e[2]
    local t = along(i) * out
    local a = pos[i] - right[i]*(W[i] + WALL_T)
    local c = pos[i] + right[i]*(W[i] + WALL_T)
    local d = t * WALL_T
    local Hv, Sv = v3(0, H, 0), v3(0, SINK, 0)
    walls.ink = X.railed and HAY or BRIGHT[1]
    hexa(walls, a + Sv, c + Sv, c + d + Sv, a + d + Sv, a + Hv, c + Hv, c + d + Hv, a + d + Hv)
  end
  done(walls, "hay")

  -- The valley: a grid whose height is the nearest road sample's, a little under it, rising away; a
  -- slab down to a flat floor far below, so the part is closed.
  -- The road's samples as plain numbers, read fast; the nearest found coarse to fine -- every COARSE-th
  -- sample, then those round the best -- so the big courses' valleys stay inside Gladius's budget.
  local PX, PZ = {}, {}
  for i = 1, N do PX[i], PZ[i] = pos[i].x, pos[i].z end
  -- (And the road on past its ends, X.ext: their points after the road's, each its height and the designed width.)
  local NP, EY = N, {}
  for _, list in ipairs(X.ext) do
    for _, q in ipairs(list) do NP = NP + 1; PX[NP], PZ[NP], EY[NP] = q.p.x, q.p.z, q.p.y end
  end
  -- (Coarser on a long road -- the mountain courses -- so a valley vertex never searches more than about a hundred.)
  local COARSE = math.max(4, math.ceil(N / 110))
  local function nearest(x, z)
    local best, bi = 1e18, 1
    for i = 1, NP, COARSE do
      local dx, dz = PX[i] - x, PZ[i] - z
      local d = dx*dx + dz*dz
      if d < best then best, bi = d, i end
    end
    for i = math.max(1, bi - COARSE), math.min(NP, bi + COARSE) do
      local dx, dz = PX[i] - x, PZ[i] - z
      local d = dx*dx + dz*dz
      if d < best then best, bi = d, i end
    end
    -- Measured from the road's edge there as if the road were its designed width (less as much as it is wider): every
    -- distance off the road below (HW + so far) is then so far off its edge, however wide the road is there.
    return math.sqrt(best) - ((W[bi] or HW) - HW), bi
  end
  local function ground_d(x, z)
    local d, i = nearest(x, z)
    local y = (i <= N and pos[i].y - X.drop(i) or EY[i]) - 0.5
    -- (A bare course's ground stays low further out: none of it rising through the verge its bales stand on.)
    local away = d - HW - WALL_T - 1.5 - (X.bare and 6 or 0)
    if away > 0 then y = y + math.min(away * P.bank, 18) + noise3(x, 0, z, {frequency=0.04, seed=3}) * math.min(away * 0.2, 2.5) end
    -- Round the shortcut: the ground as low as the nearer road asks (the slopes rising away from either), and down
    -- into the duck pond's basin.
    if X.cut then
      local u, dc, yc = X.cut_at(x, z)
      if u > -0.05 and u < 1.05 then
        local away2 = math.abs(dc) - X.cut.hw - WALL_T - 1.5
        local y2 = yc - 0.5 + (away2 > 0 and math.min(away2 * P.bank, 18) or 0)
        if y2 < y then y = y2 end
        d = math.min(d, math.abs(dc) + HW - X.cut.hw)
      end
      if X.in_pond(x, z, 3) then
        local water = X.cut.a.y + (X.cut.b.y - X.cut.a.y) * X.pond.u - 2.6
        y = math.min(y, X.in_pond(x, z, 0) and water - 1.4 or water + 0.4)
      end
    end
    -- (A themed course's kit may shape its own ground: T.shape, THEME KITS below.)
    if X.T and X.T.shape then y = X.T.shape(x, z, d - HW, y, i <= N and pos[i].y or EY[i], X.TK) or y end
    return y, d
  end
  local function ground(x, z) return (ground_d(x, z)) end
  -- Whether (x, z) is within `clear` of the shortcut (or its pond): nothing planted there.
  if X.cut then
    function X.cut_clear(x, z, clear)
      local u, d = X.cut_at(x, z)
      return (u > -0.1 and u < 1.1 and math.abs(d) < X.cut.hw + clear) or X.in_pond(x, z, clear)
    end
  end
  -- The first course's village (X.V), planned here -- before the valley is painted and the scenery scattered, so
  -- neither a field wall nor a tree lands in a garden -- and built with the scenery, below. A site is a building `d`
  -- metres back from the road's edge at sample `s` on `side`: its middle c, u down the road and w away from it (its
  -- front faces the road), half its frontage hu and half its depth hw, and the garden plot round it. Rows of cottages
  -- either side below the start, a second row up each slope behind a back lane, a pub, a shop, the church over the
  -- green where the fete is; a farm and the odd cottage further down.
  if X.bare then (function()
    local V = {sites = {}, rects = {}, lanes = {}}
    X.V = V
    -- A point `d` metres off the road's edge at sample `s` (whole or between two): it, the way down the road, the way
    -- out from it, and the road's height there.
    function V.at(s, side, d)
      local i = math.max(1, math.min(N - 1, math.floor(s)))
      local f = s - i
      local p = lerp(pos[i], pos[i + 1], f)
      local r = normalize(lerp(right[i], right[i + 1], f))
      return v3(p.x, 0, p.z) + r * (side * (W[i] + (W[i + 1] - W[i]) * f + d)), v3(r.z, 0, -r.x), r * side, p.y
    end
    -- Ground spoken for: nothing scattered there, no field wall through it.
    function V.rect(c, u, w, hu, hw)
      local q = {c = c, u = u, w = w, hu = hu, hw = hw}
      V.rects[#V.rects + 1] = q
      return q
    end
    function X.taken(x, z, clear)
      local m = (clear >= 9) and 3.2 or ((clear >= 4) and 1.2 or 0.6)
      -- (first against a circle round each piece of ground: cheap, and most points are far from all of them)
      for _, q in ipairs(V.rects) do
        local dx, dz = x - q.c.x, z - q.c.z
        if not q.r then q.r = math.sqrt(q.hu * q.hu + q.hw * q.hw) + 3.3 end
        if dx * dx + dz * dz < q.r * q.r and math.abs(dx * q.u.x + dz * q.u.z) < q.hu + m and math.abs(dx * q.w.x + dz * q.w.z) < q.hw + m then return true end
      end
      for _, l in ipairs(V.lanes) do
        if x > l.x0 - m and x < l.x1 + m and z > l.z0 - m and z < l.z1 + m then
          for k = 1, #l.pts - 1 do
            local a, b = l.pts[k], l.pts[k + 1]
            local ex, ez = b.x - a.x, b.z - a.z
            local t = math.max(0, math.min(1, ((x - a.x) * ex + (z - a.z) * ez) / (ex * ex + ez * ez)))
            local dx, dz = x - a.x - ex * t, z - a.z - ez * t
            if dx * dx + dz * dz < (l.hw + m) ^ 2 then return true end
          end
        end
      end
      return false
    end
    local function site(s, side, d, kind, hu, hw, o)
      local S = o or {}
      S.c, S.u, S.w = V.at(s, side, d + hw)
      S.fg, S.bg, S.gu = S.fg or 3.5, S.bg or 4, S.gu or (hu + 2.4)
      -- its ground: the garden plot, or (no garden) the building and a little round it
      local q = {c = S.c + S.w * ((S.bg - S.fg) / 2), u = S.u, w = S.w, hu = S.gu, hw = hw + (S.fg + S.bg) / 2}
      if S.yard == false then q = {c = S.c, u = S.u, w = S.w, hu = hu + (S.pad or 1), hw = hw + (S.pad or 1)} end
      -- (Inside a bend the rows crowd together: a site whose ground runs into one already there is left out.)
      for i = -4, 4 do
        for j = -4, 4 do
          local p = q.c + q.u * (q.hu * i / 4) + q.w * (q.hw * j / 4)
          for _, e in ipairs(V.rects) do
            local dx, dz = p.x - e.c.x, p.z - e.c.z
            if math.abs(dx * e.u.x + dz * e.u.z) < e.hu + 0.4 and math.abs(dx * e.w.x + dz * e.w.z) < e.hw + 0.4 then return nil end
          end
        end
      end
      S.s, S.side, S.kind, S.hu, S.hw, S.id = s, side, kind, hu, hw, #V.sites + 1
      V.sites[S.id] = S
      V.rects[#V.rects + 1] = q
      if S.yard ~= false then S.plot = q end
      return S
    end
    local function cottages(side, list, d, far)
      for _, s in ipairs(list) do
        site(s, side, d + hash(s, side + 3) * (far and 1.5 or 2.2), "cottage", 3.7 + hash(s, side + 5) * 0.9, 2.6 + hash(s, side + 7) * 0.4, {far = far})
      end
    end
    -- the churchyard (the church in it), the green and the orchard; the pub on the left, the shop by the start
    V.church = site(23.8, 1, 25.5, "church", 6.5, 3.3, {yard = false})
    do
      local c, u, w = V.at(23.3, 1, 28.8)
      V.yard = V.rect(c, u, w, 11.8, 9.3)
      c, u, w = V.at(23.1, 1, 12.5)
      V.green = V.rect(c, u, w, 12.5, 6)
      c, u, w = V.at(53, 1, 15)
      V.orchard = V.rect(c, u, w, 6.4, 6.5)
    end
    site(16.6, -1, 10.5, "pub", 6.2, 3.5, {fg = 4.6, gu = 7.2, two = true, thatch = false, fence = "open", tone = 1, roof = 1})
    site(10, 1, 9.8, "shop", 4.8, 3.2, {yard = false, pad = 2.4, two = true, thatch = false, tone = 2, roof = 2})
    -- the left: a row along the road, a second row up the slope; the right the same, round the green
    cottages(-1, {6, 11, 23, 31, 36, 41, 46}, 9.6, false)
    cottages(-1, {9, 15, 21, 33, 39, 45}, 30, true)
    cottages(1, {5, 16, 31, 36, 41, 46}, 9.6, false)
    cottages(1, {8, 14, 33, 39, 45}, 30, true)
    -- further down: a farmhouse and its barn, the odd cottage, two past the finish
    site(60, -1, 13, "farm", 4.6, 3.0, {two = true, thatch = false})
    site(65.6, -1, 15, "barn", 5, 3.4, {yard = false, pad = 3, two = true, thatch = false, roof = 1})
    cottages(1, {58, 67, 99}, 11.5, false)
    cottages(-1, {103}, 11.5, false)
    -- the lanes: a spur off the road between the gardens to a back lane along the slope, either side
    local function lane(pts)
      local l = {pts = pts, hw = 1.3, x0 = math.huge, x1 = -math.huge, z0 = math.huge, z1 = -math.huge}
      for _, p in ipairs(pts) do
        l.x0, l.x1, l.z0, l.z1 = math.min(l.x0, p.x), math.max(l.x1, p.x), math.min(l.z0, p.z), math.max(l.z1, p.z)
      end
      V.lanes[#V.lanes + 1] = l
    end
    local function back(side, s0, s1)
      local pts = {}
      local s = s0
      while s < s1 - 0.5 do
        pts[#pts + 1] = (V.at(s, side, 24.5))
        s = s + 2
      end
      pts[#pts + 1] = (V.at(s1, side, 24.5))
      lane(pts)
    end
    lane({(V.at(27, -1, 2.3)), (V.at(27, -1, 23.15))})
    back(-1, 6, 48)
    lane({(V.at(12.7, 1, 2.3)), (V.at(12.7, 1, 23.15))})
    back(1, 5, 18.6)
    lane({(V.at(28, 1, 2.3)), (V.at(28, 1, 23.15))})
    back(1, 27.6, 48)
  end)() end
  local grass = builder()
  -- The valley's extent: the road's, and a margin round it.
  local X0, X1, Z0, Z1 = math.huge, -math.huge, -math.huge, math.huge
  local LOW = math.huge
  for _, p in ipairs(pos) do
    X0 = math.min(X0, p.x); X1 = math.max(X1, p.x); Z1 = math.min(Z1, p.z); Z0 = math.max(Z0, p.z); LOW = math.min(LOW, p.y)
  end
  -- (The road's own extent: what the grid's cells are counted on, below.)
  X.area0 = (X1 - X0 + 140) * (Z0 - Z1 + 140)
  -- (The road on past its ends too: the valley round all of it.)
  for _, list in ipairs(X.ext) do
    for _, q in ipairs(list) do
      local p = q.p
      X0 = math.min(X0, p.x); X1 = math.max(X1, p.x); Z1 = math.min(Z1, p.z); Z0 = math.max(Z0, p.z); LOW = math.min(LOW, p.y)
    end
  end
  -- (A coarser grid on the biggest courses, so the valley stays inside Gladius's budget: about 9,000 cells at most.)
  -- (And no more cells for the road on past its ends than the road alone had: the grid a little coarser instead, the
  -- build's cost the same.)
  local MARGIN, STEP = 70, math.max(5, math.ceil(math.sqrt(X.area0 / 9000)))
  STEP = math.max(STEP, math.ceil(math.sqrt((X1 - X0 + 140) * (Z0 - Z1 + 140) / (X.area0 / (STEP * STEP)))))
  X0, X1, Z0, Z1 = math.floor((X0 - MARGIN) / STEP) * STEP, math.ceil((X1 + MARGIN) / STEP) * STEP, math.ceil((Z0 + MARGIN) / STEP) * STEP, math.floor((Z1 - MARGIN) / STEP) * STEP
  local FLOOR = LOW - 20
  local cols = math.floor((X1 - X0) / STEP) + 1
  local rows = math.floor((Z0 - Z1) / STEP) + 1
  local top, bot, dist = {}, {}, {}
  for r = 0, rows - 1 do
    for c = 0, cols - 1 do
      local x, z = X0 + c*STEP, Z0 - r*STEP
      local y, d = ground_d(x, z)
      top[r*cols + c + 1] = vert(grass, v3(x, y, z))
      bot[r*cols + c + 1] = vert(grass, v3(x, FLOOR, z))
      dist[r*cols + c + 1] = d
    end
  end
  -- The valley painted: fields of a few greens where cheap ripples say so, a buttercup meadow here and there,
  -- bare earth in rare patches and a trampled verge along the walls. (The floor and the rim take the darkest.)
  local DIRT = SNOW and col(0.42, 0.42, 0.44) or col(0.3, 0.2, 0.1)
  local G_DEEP, G_DARK, G_LIGHT = tint(GRASS, 0.78), tint(GRASS, 0.9), col(GRASS.v.x*1.2 + 0.03, GRASS.v.y*1.18 + 0.03, GRASS.v.z*1.1)
  local G_DRY = SNOW and tint(GRASS, 0.93) or mix(GRASS, col(0.55, 0.5, 0.18), 0.35)
  local G_MEADOW = SNOW and tint(GRASS, 1.04) or mix(GRASS, col(0.85, 0.75, 0.08), 0.32)
  local G_FRESH = SNOW and tint(GRASS, 0.95) or mix(GRASS, col(0.3, 0.75, 0.12), 0.45)
  local G_VERGE = mix(GRASS, DIRT, 0.4)
  local G_EARTH = mix(GRASS, DIRT, 0.75)
  local G_UNDER = tint(GRASS, 0.55)
  X.kerb, X.park = mix(GRASS, col(0.75, 0.74, 0.72), 0.45), col(0.16, 0.38, 0.1)
  -- The first course's fields: the valley cut into fields along the grid's own lines (so a wall or a hedge stands
  -- exactly on a boundary, the ground straight under it) -- columns of cells, each cut into fields down its length --
  -- and each field a kind: 1 pasture, 2 mown in stripes, 3 wheat, 4 plough, 5 rape, 6 a flower meadow, 7 cut hay.
  if X.bare then (function()
    local F = {col = {}, row = {}}
    X.F = F
    local c, ci = 0, 0
    while c < cols do
      local wd = 6 + math.floor(hash(ci, 91) * 4)
      for k = c, math.min(cols - 1, c + wd - 1) do F.col[k] = ci end
      c, ci = c + wd, ci + 1
    end
    for i = 0, ci - 1 do
      F.row[i] = {}
      local r, rj = -math.floor(hash(i, 93) * 7), 0
      while r < rows do
        local hg = 8 + math.floor(hash(i * 31 + rj, 95) * 5)
        for k = math.max(0, r), math.min(rows - 1, r + hg - 1) do F.row[i][k] = rj end
        r, rj = r + hg, rj + 1
      end
    end
    function F.id(c, r)
      local i = F.col[c]
      return i * 100 + F.row[i][r]
    end
    function F.kind(id)
      local h = hash(id * 0.731, 17)
      if h < 0.3 then return 1 elseif h < 0.5 then return 2 elseif h < 0.64 then return 3 elseif h < 0.74 then return 4
      elseif h < 0.82 then return 5 elseif h < 0.94 then return 6 end
      return 7
    end
    local WHEAT, PLOUGH = {col(0.62, 0.47, 0.14), col(0.68, 0.53, 0.18)}, {col(0.26, 0.17, 0.09), col(0.33, 0.22, 0.12)}
    local RAPE, CLOVER = col(0.7, 0.66, 0.06), mix(GRASS, col(0.8, 0.45, 0.6), 0.3)
    local LAWN, CUT = mix(G_FRESH, G_LIGHT, 0.5), mix(G_DRY, G_LIGHT, 0.5)
    function X.field(c, r, x, z, d, ink)
      if d < HW + WALL_T + 3.2 then return ink end
      -- the mown green along the road, in stripes down it
      if d < HW + 13.5 then return (c % 2 == 0) and G_FRESH or LAWN end
      -- (the village's own ground: grass, whatever the field it stands in grows)
      if X.taken(x, z, 9) then return (hash(x, z) < 0.5) and GRASS or G_LIGHT end
      local id = F.id(c, r)
      local kind = F.kind(id)
      local stripe = (hash(id, 5) < 0.5) and c or r
      if kind == 1 then return ink
      elseif kind == 2 then return (stripe % 2 == 0) and G_LIGHT or GRASS
      elseif kind == 3 then return WHEAT[(stripe + ((hash(x, z) < 0.2) and 1 or 0)) % 2 + 1]
      elseif kind == 4 then return PLOUGH[stripe % 2 + 1]
      elseif kind == 5 then return (hash(x, z) < 0.15) and G_MEADOW or RAPE
      elseif kind == 6 then
        local h = hash(x, z)
        return (h < 0.22) and CLOVER or ((h < 0.5) and G_MEADOW or G_LIGHT)
      end
      return (stripe % 2 == 0) and G_DRY or CUT
    end
  end)() end
  for r = 0, rows - 2 do
    for c = 0, cols - 2 do
      local a = r*cols + c + 1
      local x, z = X0 + (c + 0.5)*STEP, Z0 - (r + 0.5)*STEP
      local d = (dist[a] + dist[a + 1] + dist[a + cols] + dist[a + cols + 1]) * 0.25
      local f = math.sin(x * 0.045 + math.sin(z * 0.03) * 2.2) + math.sin(z * 0.05 - x * 0.012)
      local f2 = math.sin(x * 0.021 - z * 0.017 + 1.7) + math.sin(z * 0.033 + math.sin(x * 0.05) * 1.5)
      local h = hash(x, z)
      local ink
      if d < HW + WALL_T + 3.2 then ink = G_VERGE
      elseif f2 > 1.7 then ink = G_EARTH
      elseif f2 < -1.3 then ink = G_MEADOW
      elseif f2 > 1.1 then ink = G_FRESH
      elseif f > 0.9 then ink = G_LIGHT
      elseif f > 0.25 then ink = (h < 0.15) and G_DRY or GRASS
      elseif f > -0.6 then ink = G_DARK
      else ink = G_DEEP end
      if X.urban then
        -- Pavement along the barriers, then paving and yards in a few stone tones, a little park here and there.
        if d < HW + WALL_T + 4 then ink = X.kerb
        elseif f2 < -1.3 then ink = X.park
        elseif f > 0.6 then ink = tint(GRASS, 1.1)
        elseif f > -0.4 then ink = GRASS
        else ink = tint(GRASS, 0.88) end
      end
      if X.field then ink = X.field(c, r, x, z, d, ink) end
      -- (A themed course's kit may paint its own ground: T.paint, THEME KITS below.)
      if X.T and X.T.paint then ink = X.T.paint(x, z, d - HW, ink, X.TK) or ink end
      grass.ink = ink
      quad(grass, top[a], top[a + 1], top[a + cols + 1], top[a + cols], UP)
      grass.ink = G_UNDER
      quad(grass, bot[a], bot[a + 1], bot[a + cols + 1], bot[a + cols], UP * -1)
    end
  end
  local function rim(a, b2, out)
    quad(grass, top[a], top[b2], bot[b2], bot[a], out)
  end
  for c = 0, cols - 2 do
    rim(c + 1, c + 2, v3(0, 0, 1))
    rim((rows - 1)*cols + c + 1, (rows - 1)*cols + c + 2, v3(0, 0, -1))
  end
  for r = 0, rows - 2 do
    rim(r*cols + 1, (r + 1)*cols + 1, v3(-1, 0, 0))
    rim(r*cols + cols, (r + 1)*cols + cols, v3(1, 0, 0))
  end
  done(grass, "grass")
  -- The first course: the valley's height as built, between its grid's vertices (the higher of the two ways a cell is
  -- cut in two), for what stands on it; its vertices' heights and their distances off the road.
  if X.bare then
    X.hts, X.dist = {}, dist
    for k = 1, rows * cols do X.hts[k] = grass.vs[top[k]].y end
    function X.gh(x, z)
      local fx, fz = (x - X0) / STEP, (Z0 - z) / STEP
      local c, r = math.max(0, math.min(cols - 2, math.floor(fx))), math.max(0, math.min(rows - 2, math.floor(fz)))
      local tx, tz = math.max(0, math.min(1, fx - c)), math.max(0, math.min(1, fz - r))
      local a = r * cols + c + 1
      local y00, y10, y01, y11 = X.hts[a], X.hts[a + 1], X.hts[a + cols], X.hts[a + cols + 1]
      local A = (tx > tz) and (y00 + (y10 - y00) * tx + (y11 - y10) * tz) or (y00 + (y01 - y00) * tz + (y11 - y01) * tx)
      local B = (tx + tz < 1) and (y00 + (y10 - y00) * tx + (y01 - y00) * tz) or (y11 + (y01 - y11) * (1 - tx) + (y10 - y11) * (1 - tz))
      return math.max(A, B)
    end
  end

  -- A box turned to the road: centre c, w across it (along r), h up, d along it (along t).
  local function road_box(b, c, r, t, w, h, d)
    local function v(x, y, z) return c + r*(x*w/2) + v3(0, y*h/2, 0) + t*(z*d/2) end
    hexa(b, v(-1,-1,-1), v(1,-1,-1), v(1,-1,1), v(-1,-1,1), v(-1,1,-1), v(1,1,-1), v(1,1,1), v(-1,1,1))
  end

  -- The markings: a line across the road at the start and a chequered one at the finish; kerbs of red and
  -- white along both edges, a white line inside them and a dashed one down the middle; and patches of tar and
  -- dust. All paint-thin (the kart collides with the road as drawn), each a little short of its neighbours
  -- (never sharing a corner).
  local marks = builder()
  local function sample_of(point) return (point - 1) * SUB + 1 end
  local function line(s, checks)
    local p, r = pos[s], right[s]
    local t = along(s)
    local lift, thick = v3(0, 0.005, 0), v3(0, 0.03, 0)
    local rows_ = checks and 2 or 1
    local n = checks and 10 or 1
    local w = W[s] * 2 / n
    local depth = 0.8
    for row = 0, rows_ - 1 do
      for k = 0, n - 1 do
        marks.ink = ((k + row) % 2 == 0 or not checks) and PAINT_W or PAINT_K
        local a0 = p - r*W[s] + r*(k*w + 0.005) + t*(row*depth + 0.005) + lift
        local a1 = a0 + r*(w - 0.01)
        local a2, a3 = a1 + t*(depth - 0.01), a0 + t*(depth - 0.01)
        hexa(marks, a0, a1, a2, a3, a0 + thick, a1 + thick, a2 + thick, a3 + thick)
      end
    end
  end
  line(sample_of(START_POINT), false)
  line(sample_of(FINISH_POINT), true)
  -- A strip on segment i from u0 to u1 along it, `at` - half to `at` + half across, lifted and thick as given -- with
  -- `edge`, each `at` measured as at the designed width (HW) and carried with the road's edge as it narrows and widens.
  local function strip(i, u0, u1, at0, at1, lift_, thick_, edge)
    local function p(u, a)
      if edge then a = a + (a < 0 and -1 or 1) * (W[i] + (W[i+1] - W[i]) * u - HW) end
      return lerp(pos[i], pos[i+1], u) + lerp(right[i], right[i+1], u) * a + v3(0, lift_, 0)
    end
    local a0, a1, b1, b0 = p(u0, at0), p(u0, at1), p(u1, at1), p(u1, at0)
    local th = v3(0, thick_, 0)
    hexa(marks, a0, a1, b1, b0, a0 + th, a1 + th, b1 + th, b0 + th)
  end
  local TAR, DUST = tint(ROAD, 0.62), mix(ROAD, col(0.7, 0.62, 0.5), 0.3)
  for i = 1, N - 1 do
    for side = -1, 1, 2 do
      for half = 0, 1 do
        marks.ink = ((2*i + half) % 2 == 0) and RED or PAINT_W
        local u0, u1 = half * 0.5 + 0.01, half * 0.5 + 0.49
        if side < 0 then strip(i, u0, u1, -(HW - 0.06), -(HW - 0.5), 0.001, 0.003, true)
        else strip(i, u0, u1, HW - 0.5, HW - 0.06, 0.001, 0.003, true) end
      end
      marks.ink = PAINT_W
      strip(i, 0.02, 0.98, side * (HW - 0.62), side * (HW - 0.7), 0.001, 0.003, true)
    end
    if i % 4 < 2 then strip(i, 0.02, 0.98, -0.07, 0.07, 0.001, 0.003) end
    -- A patch, now and then, in one lane: tar or dust, short of the lines round it.
    if hash(i, 11) < 0.3 then
      local side = (hash(i, 12) < 0.5) and -1 or 1
      local room = math.min(W[i], W[i + 1]) - 0.85 - 0.25
      if room > 0.6 then
        local w = room * (0.35 + 0.6 * hash(i, 13))
        local a = 0.25 + (room - w) * hash(i, 14)
        local u0 = 0.05 + 0.4 * hash(i, 15)
        local u1 = math.min(0.95, u0 + 0.2 + 0.5 * hash(i, 16))
        marks.ink = (hash(i, 17) < 0.6) and TAR or DUST
        strip(i, u0, u1, side * a, side * (a + w), 0.0005, 0.0015)
      end
    end
  end
  done(marks, "markings", SHINY)

  -- The arches: two striped posts, flags on top, and a banner across high overhead (its underside above
  -- 4.4 m): the start's in a sponsor's colours, the finish's chequered with a red board above.
  local arches = builder()
  local function arch(s, checks)
    local p, r = pos[s], right[s]
    local t = along(s)
    local span = W[s] + WALL_T + 0.4
    local band_a, band_b = checks and PAINT_K or RED, PAINT_W
    for side = -1, 1, 2 do
      local c = p + r*(span*side)
      local y0 = ground(c.x, c.z) - 0.8
      local hs = {y0}
      local y = p.y + 0.6
      while y < p.y + 6.4 do hs[#hs + 1] = y; y = y + 0.6 end
      hs[#hs + 1] = p.y + 6.4
      local rings_ = {}
      for _, hy in ipairs(hs) do rings_[#rings_ + 1] = ring(v3(c.x, hy, c.z), 0.24, 0.24, 10, 0) end
      prism(arches, rings_, function(j, _) return (j % 2 == 0) and band_b or band_a end, band_a, band_a)
      -- A ball on top, and a pennant.
      arches.ink = BRIGHT[3]
      ball(arches, c + v3(0, p.y + 6.62 - c.y, 0), 0.26, 0.26, 0.26, 8, 5, function() return 1 end, function() return BRIGHT[3] end)
      column(arches, c.x, c.z, p.y + 6.9, p.y + 8.3, 0.035, 0.03, 5, PAINT_W)
      local fb = c + v3(0, p.y + 8.2 - c.y, 0)
      local tip = fb - t * 1.1 + v3(0, -0.3, 0)
      local fl = BRIGHT[(s + side) % #BRIGHT + 1]
      arches.ink = fl
      hexa(arches, fb + r*0.02, fb - r*0.02, tip - r*0.02 + v3(0, 0.01, 0), tip + r*0.02 + v3(0, 0.01, 0),
        fb + r*0.02 + v3(0, -0.6, 0), fb - r*0.02 + v3(0, -0.6, 0), tip - r*0.02, tip + r*0.02)
    end
    local inner = span - 0.26
    if not checks then
      arches.ink = PAINT_W
      road_box(arches, p + v3(0, 6.05, 0), r, t, inner*2, 0.22, 0.2)
      arches.ink = BRIGHT[2]
      road_box(arches, p + v3(0, 5.25, 0), r, t, inner*2, 1.3, 0.16)
      arches.ink = PAINT_W
      road_box(arches, p + v3(0, 4.52, 0), r, t, inner*2, 0.12, 0.2)
      -- Sponsor panels on the banner, both faces: blocks of colour a few centimetres proud.
      for k = -2, 2 do
        arches.ink = BRIGHT[(k + 2) % 2 == 0 and 3 or 1]
        for face_ = -1, 1, 2 do
          road_box(arches, p + v3(0, 5.25, 0) + r*(k * inner * 0.36) + t*(face_ * 0.105), r, t, inner * 0.26, 0.8, 0.04)
        end
      end
    else
      local n = 12
      local w = inner * 2 / n
      for k = 0, n - 1 do
        for row = 0, 1 do
          arches.ink = ((k + row) % 2 == 0) and PAINT_W or PAINT_K
          road_box(arches, p - r*inner + r*(w*(k + 0.5)) + v3(0, 4.95 + row*0.5, 0), r, t, w - 0.01, 0.49, 0.15)
        end
      end
      arches.ink = RED
      road_box(arches, p + v3(0, 5.85, 0), r, t, inner*2, 0.28, 0.2)
      arches.ink = BRIGHT[3]
      road_box(arches, p + v3(0, 6.08, 0), r, t, inner*2, 0.14, 0.22)
    end
  end
  -- (The start's arch is the game's own: the inflatable one, course/arch, placed by src/game/systems/course.ts.)
  arch(sample_of(FINISH_POINT), true)
  done(arches, "arches", SHINY)

  -- The scenery: trees on the slopes -- pines of layered, ragged tiers and round leafy trees in several
  -- greens and some autumn colours, now and then a birch -- bushes, flowers and rocks, never near the road.
  local trunks, pines, leafy, autumn, bushes, rocks = builder(), builder(), builder(), builder(), builder(), builder()
  local PINES = {col(0.05, 0.22, 0.08), col(0.07, 0.28, 0.09), col(0.05, 0.25, 0.13), col(0.1, 0.32, 0.1)}
  local LEAFY = {col(0.12, 0.36, 0.05), col(0.2, 0.44, 0.07), col(0.08, 0.28, 0.04), col(0.28, 0.48, 0.1)}
  local AUTUMN = {col(0.78, 0.3, 0.02), col(0.62, 0.08, 0.03), col(0.88, 0.62, 0.05), col(0.7, 0.42, 0.04)}
  local BARK = {col(0.28, 0.16, 0.08), col(0.22, 0.13, 0.07), col(0.34, 0.22, 0.12)}
  local BIRCH = col(0.85, 0.84, 0.78)
  local FROST = col(0.9, 0.93, 0.96)
  -- Somewhere on the slopes at least `clear` metres off the road, or nil.
  local function spot(clear)
    local x = g:range(X0 + 5, X1 - 5)
    local z = g:range(Z1 + 5, Z0 - 5)
    if nearest(x, z) > HW + clear and not (X.cut and X.cut_clear(x, z, clear)) and not (X.taken and X.taken(x, z, clear)) then return x, z end
    return nil
  end
  -- A face's shade on a crown: lit from above, darker beneath, so a single colour reads as a round mass.
  local function shaded(base)
    local hi, mid, lo = tint(base, 1.22), base, tint(base, 0.72)
    return function(w)
      local ny = w.y / math.max(1e-6, length(w))
      if ny > 0.45 then return (SNOW and ny > 0.7) and FROST or hi elseif ny > -0.3 then return mid else return lo end
    end
  end
  -- The first course's village and countryside (X.bare), built: honey and cream Cotswold stone cottages with stone-slate
  -- or thatched roofs, chimneys, windows, doors and dormers, each in its garden behind a dry stone wall, a hedge or a
  -- picket fence; the pub, the shop, the church with its square tower in its churchyard; the lanes; the fete on the
  -- green -- cake stall, tea tent, hay cart, maypole, balloons -- and bunting strung over the road; dry stone walls and
  -- hedgerows on the fields' boundaries, sheep in the pastures, rolled hay in the cut fields; an orchard. (Its own
  -- function, for its locals; its boxes written straight into pieces a colour each -- X.sub -- which cost no painting.)
  -- Buildings, walls and fences go into the buildings and the rocks (solid); what nobody should snag on -- lanes,
  -- paths, flowers, sheep -- into the bushes (not solid).
  if X.bare then (function()
    local V, gh, F = X.V, X.gh, X.F
    X.build, X.flags = builder(), builder()
    local build, flags = X.build, X.flags
    local Y = v3(0, 1, 0)
    local floor, cos, sin, max, min = math.floor, math.cos, math.sin, math.max, math.min
    local function mono(b, c)
      local q = X.sub(b, c)
      q.ink = c
      return q
    end
    -- A six-sided shell written straight in: a0..a3 one face's ring, b0..b3 the ring opposite, in the same order.
    local function hex(b, a0, a1, a2, a3, b0, b1, b2, b3)
      local vs, fs, cs = b.vs, b.fs, b.cs
      local n, f, ink = #vs, #fs, b.ink
      vs[n+1], vs[n+2], vs[n+3], vs[n+4], vs[n+5], vs[n+6], vs[n+7], vs[n+8] = a0, a1, a2, a3, b0, b1, b2, b3
      if dot(cross(a1 - a0, a3 - a0), b0 - a0) > 0 then
        fs[f+1] = {n+4, n+3, n+2, n+1}; fs[f+2] = {n+5, n+6, n+7, n+8}; fs[f+3] = {n+1, n+2, n+6, n+5}
        fs[f+4] = {n+2, n+3, n+7, n+6}; fs[f+5] = {n+3, n+4, n+8, n+7}; fs[f+6] = {n+4, n+1, n+5, n+8}
      else
        fs[f+1] = {n+1, n+2, n+3, n+4}; fs[f+2] = {n+8, n+7, n+6, n+5}; fs[f+3] = {n+5, n+6, n+2, n+1}
        fs[f+4] = {n+6, n+7, n+3, n+2}; fs[f+5] = {n+7, n+8, n+4, n+3}; fs[f+6] = {n+8, n+5, n+1, n+4}
      end
      cs[f+1], cs[f+2], cs[f+3], cs[f+4], cs[f+5], cs[f+6] = ink, ink, ink, ink, ink, ink
    end
    -- A box: its middle and its three half-extents.
    local function box(b, c, ax, ay, az)
      local p, q, d1, d2 = c - az, c + az, ax + ay, ax - ay
      hex(b, p - d1, p + d2, p + d1, p - d2, q - d1, q + d2, q + d1, q - d2)
    end
    local function cbox(b, colour, c, ax, ay, az) box(mono(b, colour), c, ax, ay, az) end
    -- A bar from p to q, t1 thick across and t2 up.
    local function beam(b, colour, p, q, t1, t2)
      local d = q - p
      local s = cross(d, Y)
      if length(s) < 1e-4 then s = v3(1, 0, 0) end
      s = normalize(s)
      box(mono(b, colour), (p + q) * 0.5, d * 0.5, normalize(cross(s, d)) * (t2 or t1), s * t1)
    end
    -- A disc standing any way: its middle, its axis n, a direction ta in its plane.
    local function disc(b, colour, c, n, ta, r, half, seg)
      local tb = cross(n, ta)
      local r0, r1 = {}, {}
      for k = 0, seg - 1 do
        local a = k / seg * 6.2832
        local o = ta * (cos(a) * r) + tb * (sin(a) * r)
        r0[k + 1], r1[k + 1] = c - n * half + o, c + n * half + o
      end
      prism(mono(b, colour), {r0, r1}, flat(colour), colour, colour)
    end
    local function on(p, dy) return v3(p.x, gh(p.x, p.z) + (dy or 0), p.z) end
    local function pickh(list, a, b) return list[1 + floor(hash(a, b) * #list * 0.9999)] end
    local function one() return 1 end
    local function frame(c, u, w)
      return {c = c, u = u, w = w, at = function(a, y, b) return v3(c.x + u.x * a + w.x * b, y, c.z + u.z * a + w.z * b) end}
    end

    -- The colours (linear). A house's stone: four tones and its plinth's.
    local STONE = {
      {col(0.68, 0.48, 0.2), col(0.62, 0.43, 0.17), col(0.74, 0.54, 0.24), col(0.56, 0.39, 0.16), col(0.44, 0.31, 0.14)},
      {col(0.8, 0.68, 0.42), col(0.74, 0.62, 0.37), col(0.85, 0.74, 0.48), col(0.68, 0.57, 0.34), col(0.53, 0.45, 0.28)},
      {col(0.6, 0.5, 0.3), col(0.54, 0.45, 0.27), col(0.66, 0.56, 0.35), col(0.49, 0.41, 0.25), col(0.39, 0.33, 0.21)},
    }
    -- Roofs: three tones and the dark of the eaves -- stone slates, blue slates; thatch.
    local ROOFS = {
      {col(0.28, 0.24, 0.18), col(0.33, 0.28, 0.2), col(0.24, 0.21, 0.16), col(0.16, 0.14, 0.11)},
      {col(0.14, 0.16, 0.2), col(0.17, 0.19, 0.24), col(0.11, 0.13, 0.16), col(0.07, 0.08, 0.1)},
    }
    local THATCH = {col(0.55, 0.4, 0.16), col(0.48, 0.34, 0.13), col(0.62, 0.46, 0.2), col(0.34, 0.24, 0.1)}
    local GLASS = {col(0.07, 0.11, 0.18), col(0.16, 0.24, 0.33)}
    local FRAMES = {col(0.9, 0.9, 0.86), col(0.9, 0.9, 0.86), col(0.28, 0.4, 0.27), col(0.18, 0.27, 0.45)}
    local DOORS = {col(0.5, 0.06, 0.05), col(0.05, 0.12, 0.35), col(0.06, 0.25, 0.1), col(0.05, 0.05, 0.06), col(0.3, 0.42, 0.28), col(0.8, 0.55, 0.05)}
    local WALLS = {col(0.5, 0.44, 0.3), col(0.44, 0.39, 0.27), col(0.56, 0.5, 0.35), col(0.39, 0.35, 0.26)}
    local COPE, POT, LEAD = col(0.34, 0.31, 0.24), col(0.6, 0.27, 0.13), col(0.3, 0.32, 0.35)
    local LANE = {col(0.6, 0.53, 0.4), col(0.54, 0.48, 0.36)}
    local WOOD, DARKWOOD = col(0.42, 0.28, 0.14), col(0.2, 0.13, 0.07)
    local FLOWERS = {col(0.95, 0.85, 0.1), col(0.95, 0.95, 0.92), col(0.9, 0.2, 0.45), col(0.55, 0.25, 0.85), col(0.95, 0.4, 0.05), col(0.85, 0.05, 0.05)}
    local HEDGES = {col(0.1, 0.3, 0.06), col(0.14, 0.36, 0.07), col(0.08, 0.25, 0.08)}
    local GOLD, WOOL, YEW = col(0.9, 0.68, 0.1), col(0.9, 0.88, 0.8), col(0.04, 0.16, 0.07)
    local CORNERS = {{1, 1}, {-1, 1}, {-1, -1}, {1, -1}}
    local ROUND = {1, 0.86, 0.5, 0}

    -- Trees: an oak (a crown of five lumpy balls), a tall poplar, a pine, a small tree in blossom, a yew.
    function X.tree(x, z, s, kind)
      local y = gh(x, z) - 0.35
      local turn = hash(x, z) * 6.28
      local bark = pickh(BARK, x, z + 2)
      local function lump() return g:range(0.88, 1.12) end
      if kind == "pine" then
        local green = pickh(PINES, x + 1, z)
        local q = X.sub(pines, green)
        column(trunks, x, z, y - 0.3, y + 2.6*s, 0.24*s, 0.16*s, 6, bark, turn)
        for tier = 0, 3 do
          local base = y + (1.5 + tier*1.15)*s
          local rad = (2.5 - tier*0.52)*s
          local pts = {}
          for k = 0, 11 do
            local a = turn + tier*0.5 + k / 12 * math.pi * 2
            local rr = rad * ((k % 2 == 0) and 1 or 0.78)
            pts[#pts + 1] = v3(x + cos(a)*rr, base - ((k % 2 == 0) and 0.18*s or 0), z + sin(a)*rr)
          end
          local shade = (tier % 2 == 0) and green or tint(green, 1.15)
          cone(q, pts, v3(x, base + 0.35*s, z), v3(x, base + (2.3 - tier*0.2)*s, z), function() return shade end, tint(green, 0.6))
        end
      elseif kind == "poplar" then
        local base = pickh(LEAFY, x, z + 5)
        column(trunks, x, z, y - 0.3, y + 1.8*s, 0.2*s, 0.16*s, 6, bark, turn)
        ball(X.sub(leafy, base), v3(x, y + 5.4*s, z), 1.2*s, 4.3*s, 1.2*s, 8, 7, lump, shaded(base))
      elseif kind == "blossom" then
        local dots = (hash(x, z + 7) < 0.5) and col(0.95, 0.6, 0.7) or col(0.96, 0.95, 0.9)
        local sh = shaded(LEAFY[2])
        local k = 0
        column(trunks, x, z, y - 0.3, y + 1.6*s, 0.13*s, 0.1*s, 5, bark, turn)
        ball(X.sub(leafy, dots), v3(x, y + 2.5*s, z), 1.6*s, 1.3*s, 1.6*s, 8, 5, lump, function(w)
          k = k + 1
          if k % 3 == 0 then return dots end
          return sh(w)
        end)
      elseif kind == "yew" then
        column(trunks, x, z, y - 0.3, y + 1.2*s, 0.22*s, 0.2*s, 6, bark, turn)
        ball(X.sub(pines, YEW), v3(x, y + 2.9*s, z), 1.4*s, 2.6*s, 1.4*s, 8, 6, lump, shaded(YEW))
      else
        local fall = hash(x + 3, z) < 0.12
        local base = fall and pickh(AUTUMN, x, z + 9) or pickh(LEAFY, x, z + 9)
        local crown = X.sub(fall and autumn or leafy, base)
        local sh = shaded(base)
        column(trunks, x, z, y - 0.3, y + 3.1*s, 0.3*s, 0.2*s, 8, bark, turn)
        ball(crown, v3(x, y + 4.4*s, z), 2.1*s, 1.7*s, 2.1*s, 10, 7, lump, sh)
        for k = 0, 3 do
          local a = turn + k * 1.57 + hash(x + k, z) * 0.6
          local rr = (1.25 + hash(x, z + k) * 0.4) * s
          ball(crown, v3(x + cos(a)*rr, y + (3.5 + hash(x + k, z + k) * 1.5)*s, z + sin(a)*rr), 1.3*s, 1.05*s, 1.3*s, 7, 5, lump, sh)
        end
      end
    end

    -- A dry stone wall from p0 to p1 over the ground, into `b`: pieces each its own height, width and tone, a hair
    -- apart; coping stones along the top.
    local function stone_wall(b, p0, p1, h, th, key, cope)
      local len = length(p1 - p0)
      if len < 0.3 then return end
      local n = max(1, floor(len / 1.5 + 0.5))
      local dir = (p1 - p0) * (1 / len)
      local sd = v3(dir.z, 0, -dir.x)
      for k = 0, n - 1 do
        local A, B = on(lerp(p0, p1, (k + 0.004) / n)), on(lerp(p0, p1, (k + 0.996) / n))
        local hh = h + (hash(k, key) - 0.5) * 0.12
        local t = sd * (th * (0.5 + (hash(k, key + 1) - 0.5) * 0.08))
        local dn, up = v3(0, -0.45, 0), v3(0, hh, 0)
        hex(mono(b, pickh(WALLS, k, key + 2)), A - t + dn, B - t + dn, B + t + dn, A + t + dn, A - t + up, B - t + up, B + t + up, A + t + up)
        if cope then
          local c0, c1, t2 = lerp(A, B, 0.03), lerp(A, B, 0.97), t * 0.72
          local u0, u1 = v3(0, hh - 0.03, 0), v3(0, hh + 0.12 + hash(k, key + 3) * 0.06, 0)
          hex(mono(b, COPE), c0 - t2 + u0, c1 - t2 + u0, c1 + t2 + u0, c0 + t2 + u0, c0 - t2 + u1, c1 - t2 + u1, c1 + t2 + u1, c0 + t2 + u1)
        end
      end
    end
    -- A hedge from p0 to p1: one lumpy length, lighter on top.
    local function hedge(p0, p1, h, th, key)
      local len = length(p1 - p0)
      if len < 0.6 then return end
      local n = max(1, floor(len / 1.4 + 0.5))
      local dir = (p1 - p0) * (1 / len)
      local sd = v3(dir.z, 0, -dir.x)
      local base = pickh(HEDGES, key, 3)
      local hi, lo = tint(base, 1.25), tint(base, 0.72)
      local rings = {}
      for k = 0, n do
        local q = on(lerp(p0, p1, (k + ((k == 0) and 0.004 or ((k == n) and -0.004 or 0))) / n))
        local f = (k == 0 or k == n) and 1 or (0.86 + hash(k, key) * 0.28)
        local w1, w2 = sd * (th * 0.5), sd * (th * 0.34)
        rings[k + 1] = {q - w1 * 0.85 + v3(0, -0.3, 0), q - w1 * f + v3(0, h * 0.55, 0), q - w2 + v3(0, h * f, 0),
          q + w2 + v3(0, h * f, 0), q + w1 * f + v3(0, h * 0.55, 0), q + w1 * 0.85 + v3(0, -0.3, 0)}
      end
      prism(X.sub(bushes, base), rings, function(_, k) return (k == 3) and hi or ((k == 2 or k == 4) and base or lo) end, lo, lo)
    end
    -- A white picket fence from p0 to p1: pickets, a post every eighth, two rails behind them.
    local function picket(p0, p1)
      local len = length(p1 - p0)
      if len < 0.5 then return end
      local dir = (p1 - p0) * (1 / len)
      local sd = v3(dir.z, 0, -dir.x)
      local wb = mono(build, PAINT_W)
      local n = max(1, floor(len / 0.27))
      for k = 0, n do
        local p = on(lerp(p0, p1, k / n))
        local post = (k % 8 == 0) or k == n
        box(wb, p + v3(0, post and 0.35 or 0.42, 0), dir * (post and 0.055 or 0.04), Y * (post and 0.75 or 0.48), sd * (post and 0.055 or 0.012))
      end
      local m = max(1, floor(len / 2.1 + 0.5))
      for k = 0, m - 1 do
        local a, b = on(lerp(p0, p1, (k + 0.01) / m)) + sd * 0.032, on(lerp(p0, p1, (k + 0.99) / m)) + sd * 0.032
        for _, hy in ipairs({0.3, 0.7}) do
          local lo, hi, t = v3(0, hy - 0.035, 0), v3(0, hy + 0.035, 0), sd * 0.018
          hex(wb, a - t + lo, b - t + lo, b + t + lo, a + t + lo, a - t + hi, b - t + hi, b + t + hi, a + t + hi)
        end
      end
    end
    -- Paving over the ground, into the bushes (never solid): a strip from p0 to p1, hw either side, in slabs.
    local function paving(p0, p1, hw, tones, step)
      local len = length(p1 - p0)
      if len < 0.2 then return end
      local n = max(1, floor(len / (step or 1.7) + 0.5))
      local dir = (p1 - p0) * (1 / len)
      local sd = v3(dir.z, 0, -dir.x) * hw
      for j = 0, n - 1 do
        local a, b = lerp(p0, p1, (j + 0.003) / n), lerp(p0, p1, (j + 0.997) / n)
        for half = 0, 1 do
          local f0, f1 = (half == 0) and -1 or 0.003, (half == 0) and -0.003 or 1
          local a0, a1, b0, b1 = on(a + sd * f0), on(a + sd * f1), on(b + sd * f0), on(b + sd * f1)
          local dn, up = v3(0, -0.4, 0), v3(0, 0.07, 0)
          hex(mono(bushes, tones[(j + half) % #tones + 1]), a0 + dn, b0 + dn, b1 + dn, a1 + dn, a0 + up, b0 + up, b1 + up, a1 + up)
        end
      end
    end

    -- A building's parts. Its walls: a banded shell round a rectangle (its middle ca, cb in the frame `at`), each
    -- course of stone in the house's tones; the heights of its courses from the plinth up.
    local function heights(lo, fl, top, band)
      local ys = {lo - 0.6, fl + 0.25, fl + 0.3}
      local nb = max(1, floor((top - fl - 0.3) / band + 0.5))
      for k = 1, nb do ys[#ys + 1] = fl + 0.3 + (top - fl - 0.3) * k / nb end
      return ys
    end
    local function banded(at, ca, cb, hu, hw, ys, tones, key)
      local rings = {}
      for j, y in ipairs(ys) do
        local ex = (j <= 2) and 0.06 or 0
        local pts = {}
        for q = 1, 4 do
          local a, b = CORNERS[q], CORNERS[q % 4 + 1]
          local n = max(1, floor(((a[1] ~= b[1]) and 2 * hu or 2 * hw) / 1.7 + 0.5))
          for k = 0, n - 1 do
            local t = k / n
            pts[#pts + 1] = at(ca + (a[1] + (b[1] - a[1]) * t) * (hu + ex), y, cb + (a[2] + (b[2] - a[2]) * t) * (hw + ex))
          end
        end
        rings[j] = pts
      end
      prism(X.sub(build, tones), rings, function(j, k)
        if j <= 2 then return tones[5] end
        local h = hash(j * 13 + k, key * 7)
        return tones[(h < 0.52) and 1 or ((h < 0.72) and 2 or ((h < 0.9) and 3 or 4))]
      end, tones[1], tones[1])
    end
    -- The ground under a footprint: its lowest corner, and the highest along its front.
    local function footing(c, u, w, hu, hw)
      local lo, fr = math.huge, -math.huge
      for a = -1, 1 do
        for b = -1, 1, 2 do
          local y = gh(c.x + u.x * a * hu + w.x * b * hw, c.z + u.z * a * hu + w.z * b * hw)
          lo = min(lo, y)
          if b < 0 then fr = max(fr, y) end
        end
      end
      return lo, fr
    end
    -- A roof's section at `a` along the ridge: three rows up each slope (straight, or rounded for thatch), its eaves
    -- `thick`.
    local function roof_section(at, a, hwo, yb, H, thick, round)
      local pts = {}
      for k = -3, 3 do
        local f = round and ROUND[math.abs(k) + 1] or (1 - math.abs(k) / 3)
        pts[#pts + 1] = at(a, yb + H * f, hwo * k / 3)
      end
      pts[#pts + 1] = at(a, yb - thick, hwo)
      pts[#pts + 1] = at(a, yb - thick, -hwo)
      return pts
    end
    -- A steep slate roof between two coped gables of the house's stone, a ridge of dark tiles.
    local function slate_roof(fr, hu, hw, eave, rise, set, key, tones)
      local at = fr.at
      local ov = 0.28
      local hwo, L = hw + ov, hu - 0.31
      local yb, H = eave - ov * rise / hw, rise * (hw + ov) / hw
      local n = max(2, floor(2 * L / 1.8 + 0.5))
      local rings = {}
      for k = 0, n do rings[k + 1] = roof_section(at, -L + 2 * L * k / n, hwo, yb, H, 0.14, false) end
      prism(X.sub(build, set), rings, function(j, k)
        if k >= 7 then return set[4] end
        return set[1 + floor(hash(j * 7 + k, key * 3) * 2.999)]
      end, set[4], set[4])
      cbox(build, set[4], at(0, eave + rise + 0.03, 0), fr.u * L, Y * 0.07, fr.w * 0.14)
      for sg = -1, 1, 2 do
        local function sec(a)
          return {at(a, eave - 0.1, -hw - 0.1), at(a, eave + 0.2, -hw - 0.1), at(a, eave + rise + 0.28, 0), at(a, eave + 0.2, hw + 0.1), at(a, eave - 0.1, hw + 0.1)}
        end
        prism(mono(build, tones[2]), {sec(sg * (hu - 0.3)), sec(sg * (hu + 0.006))}, flat(tones[2]), tones[2], tones[2])
      end
    end
    -- A thatched roof: thick, rounded, hipped at both ends, a dark ridge.
    local function thatch_roof(fr, hu, hw, eave, rise, key)
      local at = fr.at
      local hwo, yb, H = hw + 0.45, eave - 0.3, rise + 0.3
      local inner = hu - hw * 0.75
      local as = {-(hu + 0.5)}
      local n = max(1, floor(2 * inner / 1.8 + 0.5))
      for k = 0, n do as[#as + 1] = -inner + 2 * inner * k / n end
      as[#as + 1] = hu + 0.5
      local rings = {}
      for k, a in ipairs(as) do rings[k] = roof_section(at, a, hwo, yb, (k == 1 or k == #as) and 0.3 or H, 0.3, true) end
      prism(X.sub(build, THATCH), rings, function(j, k)
        if k >= 7 then return THATCH[4] end
        return THATCH[1 + floor(hash(j * 7 + k, key * 3) * 2.999)]
      end, THATCH[4], THATCH[4])
      cbox(build, THATCH[4], at(0, eave + rise + 0.04, 0), fr.u * (inner + 0.2), Y * 0.12, fr.w * 0.42)
    end
    local function chimney(fr, a, b, y0, y1, tones)
      cbox(build, tones[2], fr.at(a, (y0 + y1) / 2, b), fr.u * 0.38, Y * ((y1 - y0) / 2), fr.w * 0.3)
      cbox(build, tones[5], fr.at(a, y1 + 0.05, b), fr.u * 0.44, Y * 0.05, fr.w * 0.36)
      for sg = -1, 1, 2 do
        local p = fr.at(a + sg * 0.17, 0, b)
        column(mono(build, POT), p.x, p.z, y1 + 0.1, y1 + 0.42, 0.1, 0.085, 6, POT)
      end
    end
    -- A window on a wall: pc on the wall's face, ta along it, n out of it. Its frame and glass; near the road its
    -- glazing bars, a stone sill and a lintel too.
    local function window(pc, ta, n, hx, hy, near, fc, lint)
      cbox(build, fc, pc + n * 0.015, ta * (hx + 0.09), Y * (hy + 0.09), n * 0.03)
      cbox(build, pickh(GLASS, pc.x + pc.y, pc.z), pc + n * 0.03, ta * hx, Y * hy, n * 0.04)
      if near then
        cbox(build, fc, pc + n * 0.045, ta * 0.03, Y * hy, n * 0.04)
        cbox(build, fc, pc + n * 0.04, ta * hx, Y * 0.03, n * 0.04)
        cbox(build, lint, pc - Y * (hy + 0.14) + n * 0.06, ta * (hx + 0.17), Y * 0.05, n * 0.08)
        cbox(build, lint, pc + Y * (hy + 0.17) + n * 0.02, ta * (hx + 0.2), Y * 0.085, n * 0.03)
      end
    end
    -- A pointed window (or door): a tall panel under a point, in a surround.
    local function lancet(pc, ta, n, hx, hy, colour, surround)
      local d0, d1 = (hx + 0.1) / 2, hx / 2
      cbox(build, surround, pc + n * 0.012, ta * (hx + 0.1), Y * (hy + 0.04), n * 0.03)
      cbox(build, surround, pc + Y * hy + n * 0.014, (ta + Y) * d0, (Y - ta) * d0, n * 0.03)
      cbox(build, colour, pc + n * 0.03, ta * hx, Y * hy, n * 0.035)
      cbox(build, colour, pc + Y * hy + n * 0.033, (ta + Y) * d1, (Y - ta) * d1, n * 0.035)
    end
    -- A door: pb at its foot on the wall's face. A stone surround, the leaf, a light over it, a step; a little gabled
    -- porch on posts for some.
    local function door(pb, ta, n, dc, lint, porch, roofc)
      cbox(build, lint, pb + Y * 1.1 + n * 0.02, ta * 0.62, Y * 1.14, n * 0.035)
      cbox(build, dc, pb + Y * 1.0 + n * 0.045, ta * 0.45, Y * 1.0, n * 0.04)
      cbox(build, GLASS[2], pb + Y * 1.62 + n * 0.06, ta * 0.22, Y * 0.16, n * 0.035)
      cbox(build, lint, pb - Y * 0.2 + n * 0.31, ta * 0.72, Y * 0.3, n * 0.32)
      if porch then
        local function sec(o) return {pb + n * o - ta * 0.95 + Y * 2.26, pb + n * o + Y * 2.86, pb + n * o + ta * 0.95 + Y * 2.26} end
        prism(mono(build, roofc), {sec(-0.02), sec(0.85)}, flat(roofc), roofc, roofc)
        for sg = -1, 1, 2 do cbox(build, PAINT_W, pb + n * 0.75 + ta * (sg * 0.8) + Y * 1.1, ta * 0.045, Y * 1.22, n * 0.045) end
      end
    end
    -- A gabled dormer standing on the front wall.
    local function dormer(fr, a, hw, eave, tones, set, fc)
      local at, u, w = fr.at, fr.u, fr.w
      cbox(build, tones[1], at(a, eave + 0.42, -hw + 0.44), u * 0.62, Y * 0.56, w * 0.46)
      local function sec(b) return {at(a - 0.82, eave + 0.93, b), at(a, eave + 1.62, b), at(a + 0.82, eave + 0.93, b)} end
      prism(mono(build, set[2]), {sec(-hw - 0.16), sec(-hw + 1.35)}, flat(set[2]), set[2], set[2])
      window(at(a, eave + 0.38, -hw - 0.02), u, w * -1, 0.36, 0.38, false, fc, tones[3])
    end
    -- A stack of straw bales: n along the bottom, one fewer each course up.
    local function stack(p, u, w, n)
      for level = 0, n - 1 do
        for k = 0, n - 1 - level do
          cbox(build, STRAW[1 + (k + level * 2) % #STRAW], p + u * ((k - (n - 1 - level) / 2) * 1.25) + Y * (level * 0.62 + 0.3), u * 0.6, Y * 0.3, w * 0.45)
        end
      end
    end

    -- A house: a cottage of a storey and a half (dormers in a slate roof, or thatch) or of two storeys; the pub, the
    -- shop, the farmhouse and the barn are houses too.
    local function house(S)
      local c, u, w, hu, hw, id, kind = S.c, S.u, S.w, S.hu, S.hw, S.id, S.kind
      local fr = frame(c, u, w)
      local at = fr.at
      local lo, front = footing(c, u, w, hu, hw)
      local fl = front + 0.12
      local two = S.two
      if two == nil then two = hash(id, 11) < 0.38 end
      local thatch = (not two) and hash(id, 13) < 0.45
      if S.thatch ~= nil then thatch = S.thatch end
      local eave = fl + (two and 5.15 or 2.9)
      local rise = hw * (thatch and 1.05 or 1.2)
      local tones = STONE[S.tone or (1 + floor(hash(id, 15) * 2.999))]
      local set = ROOFS[S.roof or ((hash(id, 17) < 0.7) and 1 or 2)]
      local near = not S.far
      local nF = w * -1
      local fc, lint = pickh(FRAMES, id, 21), tones[3]
      S.fl, S.fr, S.tones, S.set = fl, fr, tones, set
      banded(at, 0, 0, hu, hw, heights(lo, fl, eave, 0.8), tones, id)
      if thatch then thatch_roof(fr, hu, hw, eave, rise, id) else slate_roof(fr, hu, hw, eave, rise, set, id, tones) end
      local e1 = (hash(id, 19) < 0.5) and -1 or 1
      if kind == "barn" then
        -- a barn: tall doors of dark boards under a timber lintel, slits high in its walls, bales by its end
        cbox(build, DARKWOOD, at(0, fl + 1.7, -hw) + nF * 0.03, u * 1.4, Y * 1.7, nF * 0.04)
        cbox(build, WOOD, at(0, fl + 3.52, -hw) + nF * 0.04, u * 1.7, Y * 0.13, nF * 0.06)
        cbox(build, WOOD, at(0, fl + 1.7, -hw) + nF * 0.05, u * 0.04, Y * 1.7, nF * 0.035)
        for _, a in ipairs({-hu * 0.6, hu * 0.6}) do cbox(build, GLASS[1], at(a, fl + 3.4, -hw) + nF * 0.02, u * 0.09, Y * 0.5, nF * 0.03) end
        stack(on(at(hu + 2.2, 0, -hw * 0.3)), w, u, 3)
        return
      end
      if thatch then
        chimney(fr, e1 * (hu - hw * 0.75 - 0.2), 0, eave + rise - 0.6, eave + rise + 1.2, tones)
      else
        chimney(fr, e1 * (hu - 0.45), 0, eave + rise - 0.5, eave + rise + 1.25, tones)
        if two or hash(id, 20) < 0.4 then chimney(fr, -e1 * (hu - 0.45), 0, eave + rise - 0.5, eave + rise + 1.25, tones) end
      end
      -- the front: the door, a window either side (the pub two), their shutters or flower boxes
      local da = (kind == "cottage" or kind == "farm") and ((hash(id, 23) - 0.5) * hu * 0.24) or 0
      S.da = da
      local wins = {-hu * 0.6, hu * 0.6}
      if kind == "pub" then wins = {-hu * 0.72, -hu * 0.36, hu * 0.36, hu * 0.72} end
      if kind == "shop" then wins = {} end
      door(at(da, fl, -hw), u, nF, pickh(DOORS, id, 25), lint, kind == "pub" or (kind ~= "shop" and hash(id, 27) < 0.5), set[4])
      local shut = (near and hash(id, 29) < 0.3) and pickh(DOORS, id, 30) or nil
      local boxes = near and hash(id, 35) < 0.5
      for k, a in ipairs(wins) do
        local pc = at(a, fl + 1.45, -hw)
        window(pc, u, nF, 0.5, 0.6, near, fc, lint)
        if shut then
          for sg = -1, 1, 2 do cbox(build, shut, pc + u * (sg * 0.79) + nF * 0.02, u * 0.19, Y * 0.6, nF * 0.03) end
        end
        if boxes then
          cbox(build, POT, pc - Y * 0.92 + nF * 0.14, u * 0.5, Y * 0.09, nF * 0.09)
          cbox(build, pickh(FLOWERS, id, k), pc - Y * 0.78 + nF * 0.14, u * 0.45, Y * 0.07, nF * 0.075)
        end
      end
      if two then
        local ups = {da}
        for _, a in ipairs(wins) do ups[#ups + 1] = a end
        if kind == "shop" then ups = {-hu * 0.6, 0, hu * 0.6} end
        for _, a in ipairs(ups) do window(at(a, fl + 4.0, -hw), u, nF, 0.48, 0.55, near, fc, lint) end
        for _, a in ipairs({-hu * 0.5, hu * 0.5}) do window(at(a, fl + 4.0, hw), u, w, 0.48, 0.55, false, fc, lint) end
      elseif not thatch then
        for _, a in ipairs({-hu * 0.6, hu * 0.6}) do dormer(fr, a, hw, eave, tones, set, fc) end
      end
      -- a lean-to against one end, for some
      local lean = (kind == "cottage" and hash(id, 37) < 0.4) and -e1 or 0
      if lean ~= 0 then
        local a0, a1, b0, b1 = lean * (hu - 0.2), lean * (hu + 2.0), -hw * 0.45, hw * 0.75
        local yl = lo - 0.52
        hex(mono(build, tones[2]), at(a0, yl, b0), at(a1, yl, b0), at(a1, yl, b1), at(a0, yl, b1),
          at(a0, fl + 2.9, b0), at(a1, fl + 2.06, b0), at(a1, fl + 2.06, b1), at(a0, fl + 2.9, b1))
        local ai, ao = lean * (hu + 0.01), lean * (hu + 2.2)
        hex(mono(build, set[1]), at(ai, fl + 2.85, b0 - 0.15), at(ao, fl + 2.0, b0 - 0.15), at(ao, fl + 2.0, b1 + 0.15), at(ai, fl + 2.85, b1 + 0.15),
          at(ai, fl + 2.99, b0 - 0.15), at(ao, fl + 2.14, b0 - 0.15), at(ao, fl + 2.14, b1 + 0.15), at(ai, fl + 2.99, b1 + 0.15))
        window(at(lean * (hu + 1.05), fl + 1.3, b0), u, nF, 0.36, 0.42, near, fc, lint)
      end
      -- the gable ends: a window low and one high, a slit in the attic
      for sg = -1, 1, 2 do
        local n = u * sg
        if sg ~= lean then window(at(sg * hu, fl + 1.45, -hw * 0.35), w, n, 0.42, 0.55, near, fc, lint) end
        if two then window(at(sg * hu, fl + 4.0, 0), w, n, 0.42, 0.5, near, fc, lint) end
        if not thatch then window(at(sg * (hu + 0.006), eave + rise * 0.36, 0), w, n, 0.24, 0.34, false, fc, lint) end
      end
      -- roses up the front, for some
      if near and hash(id, 41) < 0.5 then
        local rose = pickh(FLOWERS, id, 43)
        local sh = shaded(HEDGES[1])
        local k = 0
        local p = at((da > 0) and (da - 1.25) or (da + 1.25), fl + 1.5, -hw - 0.08)
        ball(X.sub(bushes, rose), p, 0.5 + math.abs(w.x) * -0.3, 1.6, 0.5 + math.abs(w.z) * -0.3, 6, 6, one, function(d)
          k = k + 1
          if k % 4 == 0 then return rose end
          return sh(d)
        end)
      end
    end

    -- A garden round a house: its plot fenced -- a low front (a wall, pickets or a hedge) with a gate between two
    -- piers, walls or hedges round the rest -- a path of slabs to the door, flowers along the front of the house,
    -- shrubs, a fruit tree behind, a shed or a row of vegetables for some.
    local function pier(p, h)
      local q = on(p)
      cbox(build, WALLS[1], q + Y * ((h - 0.4) / 2), v3(0.27, 0, 0), Y * ((h + 0.4) / 2), v3(0, 0, 0.27))
      cbox(build, COPE, q + Y * (h + 0.05), v3(0.32, 0, 0), Y * 0.06, v3(0, 0, 0.32))
    end
    local function garden(S)
      local G = S.plot
      if not G then return end
      local c, u, w, gu, gw, id = G.c, G.u, G.w, G.hu, G.hw, S.id
      local function gp(a, b) return v3(c.x + u.x * a + w.x * b, 0, c.z + u.z * a + w.z * b) end
      local da = S.da or 0
      local h31 = hash(id, 31)
      local fk = S.fence or ((h31 < 0.4) and "wall" or ((h31 < 0.72) and "picket" or "hedge"))
      local sk = (hash(id, 33) < 0.6) and "wall" or "hedge"
      local function run(kind, p0, p1, key, low)
        if kind == "wall" then stone_wall(build, p0, p1, low and 0.85 or 1.2, 0.42, key, true)
        elseif kind == "picket" then picket(p0, p1)
        elseif kind == "hedge" then hedge(p0, p1, low and 1.0 or 1.5, 0.9, key) end
      end
      run(fk, gp(-gu + 0.3, -gw), gp(da - 0.95, -gw), id * 10 + 1, true)
      run(fk, gp(da + 0.95, -gw), gp(gu - 0.3, -gw), id * 10 + 2, true)
      run(sk, gp(-gu, -gw + 0.3), gp(-gu, gw - 0.3), id * 10 + 3)
      run(sk, gp(gu, -gw + 0.3), gp(gu, gw - 0.3), id * 10 + 4)
      run(sk, gp(-gu + 0.3, gw), gp(gu - 0.3, gw), id * 10 + 5)
      for _, q in ipairs(CORNERS) do pier(gp(q[1] * gu, q[2] * gw), (q[2] < 0) and 1.05 or 1.4) end
      if fk ~= "open" then
        pier(gp(da - 0.85, -gw), 1.2)
        pier(gp(da + 0.85, -gw), 1.2)
        cbox(build, pickh(DOORS, id, 25), on(gp(da, -gw), 0.5), u * 0.58, Y * 0.4, w * 0.03)
      end
      -- the path, and the flowers either side of the door
      local hf = -gw + S.fg                       -- the house's front, in the plot
      local b = -gw + 0.55
      while b < hf - 0.5 do
        cbox(bushes, LANE[1], on(gp(da + (hash(b, id) - 0.5) * 0.2, b), -0.02), u * 0.42, Y * 0.07, w * 0.34)
        b = b + 0.85
      end
      local a = -S.hu + 0.5
      local k = 0
      while a < S.hu - 0.4 do
        k = k + 1
        if math.abs(a - da) > 1.0 then
          local p = on(gp(a, hf - 0.5), 0.2)
          if k % 3 == 0 then
            local green = pickh(HEDGES, a, id)
            ball(X.sub(bushes, green), p + Y * 0.15, 0.5, 0.5, 0.5, 6, 4, one, shaded(green))
          else
            local bloom = pickh(FLOWERS, a, id)
            ball(mono(bushes, bloom), p, 0.32, 0.26, 0.32, 5, 3, one, function() return bloom end)
          end
        end
        a = a + 0.8
      end
      -- shrubs in the front corners, a fruit tree and the odd thing behind
      for sg = -1, 1, 2 do
        if hash(id, 45 + sg) < 0.6 then
          local green = pickh(HEDGES, id, sg)
          ball(X.sub(bushes, green), on(gp(sg * (gu - 1.1), -gw + 1.1), 0.4), 0.8, 0.75, 0.8, 7, 5, one, shaded(green))
        end
      end
      local bh = hf + 2 * S.hw                    -- the house's back
      if hash(id, 47) < 0.75 then
        local p = gp(((hash(id, 49) < 0.5) and -1 or 1) * (gu - 2.2), gw - 1.9)
        X.tree(p.x, p.z, 0.7 + hash(id, 51) * 0.25, "blossom")
      end
      if hash(id, 53) < 0.4 then
        -- a shed: boards, a felt roof, a door
        local p = on(gp(((hash(id, 49) < 0.5) and 1 or -1) * (gu - 1.5), gw - 1.4), 0)
        cbox(build, WOOD, p + Y * 0.8, u * 0.9, Y * 1.1, w * 0.7)
        hex(mono(build, ROOFS[2][3]), p + Y * 1.95 - u * 1.0 - w * 0.8, p + Y * 1.95 + u * 1.0 - w * 0.8, p + Y * 1.75 + u * 1.0 + w * 0.8, p + Y * 1.75 - u * 1.0 + w * 0.8,
          p + Y * 2.05 - u * 1.0 - w * 0.8, p + Y * 2.05 + u * 1.0 - w * 0.8, p + Y * 1.85 + u * 1.0 + w * 0.8, p + Y * 1.85 - u * 1.0 + w * 0.8)
        cbox(build, DARKWOOD, p + Y * 0.75 - w * 0.71, u * 0.35, Y * 0.85, w * 0.02)
      elseif hash(id, 53) < 0.75 and bh + 1.2 < gw - 0.8 then
        -- rows of vegetables in dug earth
        local p = on(gp(((hash(id, 49) < 0.5) and 1 or -1) * (gu - 2.4), (bh + gw) / 2), 0)
        cbox(bushes, col(0.26, 0.17, 0.09), p, u * 1.6, Y * 0.08, w * 1.2)
        for r = -1, 1 do
          for q = -3, 3 do
            cbox(bushes, HEDGES[2 + (r % 2)], p + u * (q * 0.45) + w * (r * 0.7) + Y * 0.16, u * 0.14, Y * 0.12, w * 0.14)
          end
        end
      end
    end

    -- The pub: its board along the front, hanging baskets, tables and parasols on the forecourt, barrels by the door,
    -- its sign on a post by the road.
    local function pub(S)
      local at, u, w, hu, hw, fl = S.fr.at, S.u, S.w, S.hu, S.hw, S.fl
      local nF = w * -1
      cbox(build, col(0.05, 0.2, 0.1), at(0, fl + 2.82, -hw) + nF * 0.03, u * (hu * 0.82), Y * 0.24, nF * 0.035)
      cbox(build, GOLD, at(0, fl + 2.82, -hw) + nF * 0.05, u * (hu * 0.5), Y * 0.08, nF * 0.03)
      for k = -2, 2 do
        if k ~= 0 then
          local bloom = FLOWERS[(k + 2) % #FLOWERS + 1]
          ball(mono(bushes, bloom), at(k * hu * 0.27, fl + 2.35, -hw - 0.4), 0.26, 0.2, 0.26, 5, 3, one, function() return bloom end)
          cbox(build, DARKWOOD, at(k * hu * 0.27, fl + 2.5, -hw - 0.2), u * 0.015, Y * 0.015, w * 0.22)
        end
      end
      paving(on(at(-hu - 0.5, 0, -hw - 2.2)), on(at(hu + 0.5, 0, -hw - 2.2)), 2.1, LANE, 2.2)
      for k = -1, 1, 2 do
        -- a table with its benches, a parasol over it
        local p = on(at(k * hu * 0.55, 0, -hw - 2.6))
        cbox(build, WOOD, p + Y * 0.74, u * 0.9, Y * 0.03, w * 0.38)
        for sg = -1, 1, 2 do
          cbox(build, WOOD, p + Y * 0.44 + w * (sg * 0.62), u * 0.9, Y * 0.025, w * 0.13)
          cbox(build, DARKWOOD, p + Y * 0.355 + u * (sg * 0.65), u * 0.04, Y * 0.355, w * 0.6)
        end
        column(mono(build, PAINT_W), p.x, p.z, p.y, p.y + 2.5, 0.03, 0.03, 5, PAINT_W)
        local a, b = BRIGHT[(k > 0) and 1 or 2], PAINT_W
        cone(X.sub(build, a), ring(p + Y * 2.05, 1.35, 1.35, 8, 0.2), p + Y * 2.2, p + Y * 2.62, function(q) return (q % 2 == 0) and a or b end, b)
      end
      for k = 0, 2 do
        local p = on(at(1.3 + k * 0.72, 0, -hw - 0.42 - (k % 2) * 0.1))
        column(mono(build, WOOD), p.x, p.z, p.y - 0.1, p.y + 0.85, 0.3, 0.3, 8, WOOD)
        column(mono(build, DARKWOOD), p.x, p.z, p.y + 0.2, p.y + 0.27, 0.315, 0.315, 8, DARKWOOD)
        column(mono(build, DARKWOOD), p.x, p.z, p.y + 0.6, p.y + 0.67, 0.315, 0.315, 8, DARKWOOD)
      end
      local p = on(at(-hu - 0.2, 0, -hw - 3.9))
      cbox(build, DARKWOOD, p + Y * 1.9, u * 0.07, Y * 2.0, w * 0.07)
      cbox(build, DARKWOOD, p + Y * 3.7 + u * 0.55, u * 0.62, Y * 0.04, w * 0.04)
      cbox(build, col(0.05, 0.2, 0.1), p + Y * 3.05 + u * 0.62, u * 0.42, Y * 0.5, w * 0.035)
      for sg = -1, 1, 2 do
        disc(build, GOLD, p + Y * 3.12 + u * 0.62 + w * (sg * 0.04), w, u, 0.26, 0.012, 8)
        cbox(build, RED, p + Y * 2.72 + u * 0.62 + w * (sg * 0.04), u * 0.3, Y * 0.06, w * 0.012)
      end
    end

    -- The shop: two wide windows, a striped awning over them, its name board, crates of fruit and a bench outside;
    -- a pillar box and a telephone box beside it.
    local function shop(S)
      local at, u, w, hu, hw, fl = S.fr.at, S.u, S.w, S.hu, S.hw, S.fl
      local nF = w * -1
      local GREEN = col(0.06, 0.25, 0.1)
      for sg = -1, 1, 2 do
        local pc = at(sg * 2.6, fl + 1.4, -hw)
        window(pc, u, nF, 1.45, 0.85, true, PAINT_W, S.tones[3])
        for q = -1, 1, 2 do cbox(build, PAINT_W, pc + u * (q * 0.5) + nF * 0.047, u * 0.03, Y * 0.85, nF * 0.04) end
        cbox(build, GREEN, pc - Y * 1.12 + nF * 0.025, u * 1.5, Y * 0.2, nF * 0.03)
        -- a crate or two under the window: fruit in three colours
        for q = 0, 1 do
          local p = on(at(sg * (1.9 + q * 0.95), 0, -hw - 0.75))
          cbox(build, WOOD, p + Y * 0.22, u * 0.4, Y * 0.24, w * 0.3)
          cbox(build, ({col(0.95, 0.45, 0.05), col(0.75, 0.08, 0.05), col(0.3, 0.6, 0.1), col(0.9, 0.8, 0.1)})[(q + sg + 3) % 4 + 1], p + Y * 0.5, u * 0.34, Y * 0.06, w * 0.24)
        end
      end
      paving(on(at(-hu - 0.5, 0, -hw - 1.6)), on(at(hu + 0.5, 0, -hw - 1.6)), 1.5, LANE, 2.2)
      -- the awning: stripes, sloping out over the pavement
      local n = 10
      for k = 0, n - 1 do
        local a0, a1 = -hu * 0.92 + 2 * hu * 0.92 * (k + 0.01) / n, -hu * 0.92 + 2 * hu * 0.92 * (k + 0.99) / n
        local q = mono(build, (k % 2 == 0) and GREEN or PAINT_W)
        hex(q, at(a0, fl + 2.52, -hw - 0.01), at(a1, fl + 2.52, -hw - 0.01), at(a1, fl + 2.12, -hw - 1.3), at(a0, fl + 2.12, -hw - 1.3),
          at(a0, fl + 2.58, -hw - 0.01), at(a1, fl + 2.58, -hw - 0.01), at(a1, fl + 2.18, -hw - 1.3), at(a0, fl + 2.18, -hw - 1.3))
        box(q, at((a0 + a1) / 2, fl + 2.05, -hw - 1.31), u * ((a1 - a0) / 2), Y * 0.09, w * 0.015)
      end
      cbox(build, col(0.45, 0.07, 0.05), at(0, fl + 3.0, -hw) + nF * 0.03, u * (hu * 0.9), Y * 0.25, nF * 0.035)
      cbox(build, col(0.9, 0.85, 0.65), at(0, fl + 3.0, -hw) + nF * 0.05, u * (hu * 0.55), Y * 0.09, nF * 0.03)
      -- the pillar box
      local p = on(at(hu + 1.2, 0, -hw - 1.2))
      column(mono(build, PAINT_K), p.x, p.z, p.y - 0.2, p.y + 0.18, 0.24, 0.24, 8, PAINT_K)
      column(mono(build, RED), p.x, p.z, p.y + 0.18, p.y + 1.35, 0.22, 0.22, 8, RED)
      column(mono(build, RED), p.x, p.z, p.y + 1.35, p.y + 1.5, 0.26, 0.1, 8, RED)
      cbox(build, PAINT_K, p + Y * 1.08 + nF * 0.215, u * 0.1, Y * 0.02, nF * 0.012)
      -- the telephone box
      p = on(at(-hu - 1.5, 0, -hw + 0.4))
      cbox(build, RED, p + Y * 1.1, u * 0.45, Y * 1.2, w * 0.45)
      cbox(build, RED, p + Y * 2.37, u * 0.4, Y * 0.07, w * 0.4)
      for _, f in ipairs({{u, w}, {u * -1, w}, {w * -1, u}}) do
        cbox(build, GLASS[1], p + Y * 1.15 + f[1] * 0.455, f[2] * 0.33, Y * 0.8, f[1] * 0.01)
        cbox(build, PAINT_W, p + Y * 2.13 + f[1] * 0.455, f[2] * 0.3, Y * 0.07, f[1] * 0.012)
      end
    end

    -- The church: a nave under a steep slate roof, lancet windows between buttresses, a porch, and a square tower at
    -- its west end -- string courses, louvred belfry lights, a clock, battlements, pinnacles, a lead cap, St George's
    -- flag -- in a walled churchyard of leaning headstones and two yews.
    local function church(S)
      local c, u, w, hu, hw, id = S.c, S.u, S.w, S.hu, S.hw, S.id
      local fr = frame(c, u, w)
      local at = fr.at
      local lo, front = footing(c, u, w, hu + 4.5, hw)
      local fl = front + 0.15
      local eave, rise = fl + 5.2, hw * 1.3
      local tones = STONE[2]
      local nF = w * -1
      local STAINED = {col(0.08, 0.12, 0.42), col(0.45, 0.05, 0.08), col(0.75, 0.5, 0.05)}
      local DARK = col(0.07, 0.06, 0.05)
      banded(at, 0, 0, hu, hw, heights(lo, fl, eave, 0.85), tones, id)
      slate_roof(fr, hu, hw, eave, rise, ROOFS[2], id, tones)
      local pa = hu * 0.6                          -- the porch, along the front
      for sg = -1, 1, 2 do
        local n = w * sg
        for k = -2, 2 do
          -- a buttress in two stages
          cbox(build, tones[2], at(k * hu * 0.4, (lo - 0.5 + fl + 3.9) / 2, sg * (hw + 0.28)), u * 0.3, Y * ((fl + 3.9 - lo + 0.5) / 2), w * 0.3)
          cbox(build, tones[3], at(k * hu * 0.4, fl + 4.3, sg * (hw + 0.16)), u * 0.24, Y * 0.42, w * 0.17)
        end
        for k = -3, 3, 2 do
          if not (sg < 0 and k == 3) then
            lancet(at(k * hu * 0.2, fl + 2.5, sg * hw), u, n, 0.36, 1.25, STAINED[(k + 3) / 2 % 3 + 1], tones[3])
          end
        end
      end
      -- the porch
      cbox(build, tones[1], at(pa, (lo - 0.5 + fl + 2.5) / 2, -hw - 0.9), u * 1.1, Y * ((fl + 2.5 - lo + 0.5) / 2), w * 0.95)
      local function psec(b) return {at(pa - 1.35, fl + 2.42, b), at(pa, fl + 3.55, b), at(pa + 1.35, fl + 2.42, b)} end
      prism(mono(build, ROOFS[2][2]), {psec(-hw + 0.1), psec(-hw - 2.05)}, flat(ROOFS[2][2]), ROOFS[2][2], ROOFS[2][2])
      lancet(at(pa, fl + 0.95, -hw - 1.85), u, nF, 0.5, 0.95, DARKWOOD, tones[3])
      -- the east window: three lights
      for k = -1, 1 do
        lancet(at(hu, fl + ((k == 0) and 3.0 or 2.7), k * 1.15), w, u, 0.38, (k == 0) and 1.5 or 1.15, STAINED[k + 2], tones[3])
      end
      -- the tower
      local th = 2.2
      local ca = -(hu + th - 0.2)
      local top = fl + 12.5
      banded(at, ca, 0, th, th, heights(lo, fl, top, 1.0), tones, id + 50)
      for _, y in ipairs({fl + 4.7, fl + 8.7, top - 0.1}) do
        cbox(build, tones[3], at(ca, y, 0), u * (th + 0.09), Y * 0.09, w * (th + 0.09))
      end
      local yaw = math.atan(u.z, u.x)
      for _, f in ipairs({{u, w}, {u * -1, w}, {w, u}, {w * -1, u}}) do
        local n, ta = f[1], f[2]
        local pc = at(ca, 0, 0) + n * th
        lancet(pc + Y * (fl + 10.2), ta, n, 0.42, 0.8, DARK, tones[3])
        -- battlements: a low wall, three merlons
        cbox(build, tones[1], pc + Y * (top + 0.13) - n * 0.16, ta * (th - 0.33), Y * 0.2, n * 0.14)
        for k = -1, 1 do cbox(build, tones[2], pc + Y * (top + 0.5) - n * 0.17 + ta * (k * 1.08), ta * 0.3, Y * 0.3, n * 0.15) end
      end
      for _, q in ipairs(CORNERS) do
        local p = at(ca + q[1] * (th - 0.18), 0, q[2] * (th - 0.18))
        column(mono(build, tones[3]), p.x, p.z, top - 0.05, top + 1.7, 0.3, 0.04, 4, tones[3], yaw + math.pi / 4)
      end
      local tc = at(ca, 0, 0)
      column(mono(build, LEAD), tc.x, tc.z, top + 0.02, top + 1.4, (th - 0.5) * 1.414, 0.08, 4, LEAD, yaw + math.pi / 4)
      column(mono(build, PAINT_W), tc.x, tc.z, top + 1.3, top + 4.4, 0.05, 0.04, 5, PAINT_W)
      local fc = tc + Y * (top + 3.9) + u * 0.78
      cbox(build, PAINT_W, fc, u * 0.72, Y * 0.44, w * 0.012)
      cbox(build, RED, fc, u * 0.72, Y * 0.09, w * 0.016)
      cbox(build, RED, fc, u * 0.09, Y * 0.44, w * 0.018)
      -- the clock, toward the road and up it; the west door and the window over it
      for _, f in ipairs({{nF, u}, {u * -1, w}}) do
        local n, ta = f[1], f[2]
        local pc = tc + n * th + Y * (fl + 7.2)
        disc(build, col(0.05, 0.1, 0.3), pc + n * 0.03, n, ta, 0.9, 0.04, 12)
        disc(build, PAINT_W, pc + n * 0.06, n, ta, 0.74, 0.04, 12)
        cbox(build, PAINT_K, pc + n * 0.11 + Y * 0.26, ta * 0.035, Y * 0.3, n * 0.012)
        cbox(build, PAINT_K, pc + n * 0.11 + ta * 0.2, ta * 0.22, Y * 0.035, n * 0.014)
      end
      lancet(tc - u * th + Y * (fl + 1.15), w, u * -1, 0.65, 1.15, DARKWOOD, tones[3])
      lancet(tc - u * th + Y * (fl + 4.0), w, u * -1, 0.4, 0.9, STAINED[1], tones[3])
      -- the churchyard: its wall, a gap in it toward the lane; headstones; yews
      local G = V.yard
      local function gp(a, b) return v3(G.c.x + G.u.x * a + G.w.x * b, 0, G.c.z + G.u.z * a + G.w.z * b) end
      local gu, gw = G.hu, G.hw
      stone_wall(build, gp(-gu, -gw), gp(gu, -gw), 1.0, 0.45, 901, true)
      stone_wall(build, gp(-gu, gw), gp(gu, gw), 1.0, 0.45, 902, true)
      stone_wall(build, gp(-gu, -gw + 0.3), gp(-gu, gw - 0.3), 1.0, 0.45, 903, true)
      stone_wall(build, gp(gu, -gw + 0.3), gp(gu, -gw + 3.4), 1.0, 0.45, 904, true)
      stone_wall(build, gp(gu, -gw + 5.4), gp(gu, gw - 0.3), 1.0, 0.45, 905, true)
      pier(gp(gu, -gw + 3.5), 1.5)
      pier(gp(gu, -gw + 5.3), 1.5)
      paving(gp(gu + 1.05, -gw + 4.4), gp(gu - 4, -gw + 4.4), 0.9, LANE, 1.5)
      local GRAVE = {col(0.45, 0.45, 0.43), col(0.36, 0.37, 0.35), col(0.55, 0.53, 0.48)}
      for row = 0, 2 do
        local a = -hu - 3.6 + row * 0.5
        local k = 0
        while a < hu + 3.5 do
          k = k + 1
          local b = -hw - 1.7 - row * 1.5
          if not (math.abs(a - pa) < 2.3 and row < 2) and hash(a, row) < 0.8 then
            local p = on(at(a, 0, b + (hash(k, row) - 0.5) * 0.5))
            local leanv = u * ((hash(k, row + 5) - 0.5) * 0.14)
            local grey = pickh(GRAVE, k, row)
            if hash(k, row + 9) < 0.2 then
              cbox(build, grey, p + Y * 0.45, u * 0.06, Y * 0.65 + leanv, w * 0.05)
              cbox(build, grey, p + Y * 0.75 + leanv * 0.4, u * 0.26, Y * 0.06, w * 0.052)
            else
              cbox(build, grey, p + Y * 0.3, u * (0.24 + hash(k, row + 3) * 0.08), Y * (0.5 + hash(k, row + 4) * 0.15) + leanv, w * 0.06)
            end
          end
          a = a + 1.3 + hash(k, row + 7) * 0.7
        end
      end
      for _, q in ipairs({{hu + 2.2, -hw - 3.8}, {-hu - 1.5, hw + 3.4}, {hu * 0.4, hw + 3.8}}) do
        local p = at(q[1], 0, q[2])
        X.tree(p.x, p.z, 1.0 + hash(q[1], 3) * 0.3, "yew")
      end
    end

    -- All of it, in order.
    for _, S in ipairs(V.sites) do
      if S.kind == "church" then church(S) else
        house(S)
        garden(S)
        if S.kind == "pub" then pub(S) elseif S.kind == "shop" then shop(S) end
      end
    end
    for _, l in ipairs(V.lanes) do
      for k = 1, #l.pts - 1 do paving(l.pts[k], l.pts[k + 1], l.hw, LANE) end
    end
    -- A fingerpost where each spur leaves the road.
    for _, e in ipairs({{27, -1}, {12.7, 1}, {28, 1}}) do
      local c, u, w = V.at(e[1] + 0.6, e[2], 3.2)
      local p = on(c)
      cbox(build, PAINT_W, p + Y * 1.2, u * 0.05, Y * 1.4, w * 0.05)
      cbox(build, PAINT_W, p + Y * 2.4 + w * 0.5, u * 0.02, Y * 0.09, w * 0.55)
      cbox(build, PAINT_W, p + Y * 2.15 - u * 0.45, u * 0.5, Y * 0.09, w * 0.02)
    end

    -- The fete on the green: the cake stall, the tea tent, the hay cart, the maypole, straw bales to sit on, balloons;
    -- the village oak.
    local function balloons(p, key)
      for k = 0, 2 do
        local colour = BRIGHT[(key + k * 3) % #BRIGHT + 1]
        local q = p + v3((k - 1) * 0.3, 1.0 + k * 0.28, (hash(key, k) - 0.5) * 0.5)
        ball(mono(flags, colour), q, 0.2, 0.25, 0.2, 6, 4, one, function() return colour end)
        beam(flags, PAINT_W, p, q - Y * 0.24, 0.006)
      end
    end
    do
      -- the cake stall: a cloth to the ground, cakes on it, a striped awning on four posts
      local c, u, w = V.at(20.6, 1, 8.7)
      local p = on(c)
      local PINK = col(0.95, 0.55, 0.65)
      cbox(build, PAINT_W, p + Y * 0.45, u * 1.4, Y * 0.45, w * 0.5)
      for k = 0, 7 do
        cbox(build, (k % 2 == 0) and RED or PAINT_W, p + Y * 0.45 + u * (-1.4 + 0.35 * k + 0.175) - w * 0.505, u * 0.17, Y * 0.44, w * 0.008)
      end
      local CAKES = {PINK, col(0.3, 0.16, 0.08), col(0.95, 0.9, 0.7), col(0.95, 0.8, 0.2), col(0.85, 0.3, 0.3)}
      for k = 0, 4 do
        local q = p + u * (-1.05 + k * 0.52) - w * 0.1
        column(mono(build, PAINT_W), q.x, q.z, p.y + 0.9, p.y + 0.93, 0.2, 0.2, 8, PAINT_W)
        column(mono(build, CAKES[k + 1]), q.x, q.z, p.y + 0.93, p.y + 1.07, 0.16, 0.16, 8, CAKES[k + 1])
        if k == 2 then
          column(mono(build, CAKES[k + 1]), q.x, q.z, p.y + 1.07, p.y + 1.19, 0.115, 0.115, 8, CAKES[k + 1])
          column(mono(build, PINK), q.x, q.z, p.y + 1.19, p.y + 1.29, 0.07, 0.07, 8, PINK)
        else
          cbox(build, RED, v3(q.x, p.y + 1.09, q.z), v3(0.03, 0, 0), Y * 0.03, v3(0, 0, 0.03))
        end
      end
      for _, q in ipairs(CORNERS) do
        cbox(build, PAINT_W, p + u * (q[1] * 1.5) + w * (q[2] * 0.75) + Y * 1.15, u * 0.03, Y * 1.25, w * 0.03)
      end
      for k = 0, 7 do
        local a0, a1 = -1.65 + 3.3 * (k + 0.01) / 8, -1.65 + 3.3 * (k + 0.99) / 8
        local q = mono(build, (k % 2 == 0) and PINK or PAINT_W)
        hex(q, p + u * a0 - w * 0.95 + Y * 2.2, p + u * a1 - w * 0.95 + Y * 2.2, p + u * a1 + w * 0.9 + Y * 2.5, p + u * a0 + w * 0.9 + Y * 2.5,
          p + u * a0 - w * 0.95 + Y * 2.25, p + u * a1 - w * 0.95 + Y * 2.25, p + u * a1 + w * 0.9 + Y * 2.55, p + u * a0 + w * 0.9 + Y * 2.55)
        box(q, p + u * ((a0 + a1) / 2) - w * 0.96 + Y * 2.1, u * ((a1 - a0) / 2), Y * 0.1, w * 0.012)
      end
      balloons(p + u * 1.5 - w * 0.75 + Y * 2.4, 1)
      balloons(p - u * 1.5 - w * 0.75 + Y * 2.4, 4)

      -- the tea tent: a striped pyramid on four posts, a valance round it, two tables under it
      c, u, w = V.at(24.2, 1, 11.2)
      p = on(c)
      local BLUE = BRIGHT[2]
      for _, q in ipairs(CORNERS) do
        cbox(build, PAINT_W, p + u * (q[1] * 2.1) + w * (q[2] * 2.1) + Y * 1.2, u * 0.04, Y * 1.4, w * 0.04)
      end
      local pts = {}
      for q = 1, 4 do
        local a, b = CORNERS[q], CORNERS[q % 4 + 1]
        for k = 0, 3 do
          local t = k / 4
          pts[#pts + 1] = p + u * ((a[1] + (b[1] - a[1]) * t) * 2.3) + w * ((a[2] + (b[2] - a[2]) * t) * 2.3) + Y * 2.55
        end
      end
      cone(X.sub(build, BLUE), pts, p + Y * 2.7, p + Y * 4.3, function(k) return (k % 2 == 0) and BLUE or PAINT_W end, PAINT_W)
      for q = 1, 4 do
        local a, b = CORNERS[q], CORNERS[q % 4 + 1]
        for k = 0, 3 do
          local m0 = p + u * ((a[1] + (b[1] - a[1]) * (k + 0.02) / 4) * 2.3) + w * ((a[2] + (b[2] - a[2]) * (k + 0.02) / 4) * 2.3)
          local m1 = p + u * ((a[1] + (b[1] - a[1]) * (k + 0.98) / 4) * 2.3) + w * ((a[2] + (b[2] - a[2]) * (k + 0.98) / 4) * 2.3)
          beam(build, ((q * 4 + k) % 2 == 0) and PAINT_W or BLUE, m0 + Y * 2.42, m1 + Y * 2.42, 0.012, 0.12)
        end
      end
      for sg = -1, 1, 2 do
        local q = p + u * (sg * 0.95) + w * (sg * 0.4)
        column(mono(build, DARKWOOD), q.x, q.z, p.y - 0.1, p.y + 0.72, 0.05, 0.05, 5, DARKWOOD)
        column(mono(build, PAINT_W), q.x, q.z, p.y + 0.72, p.y + 0.76, 0.55, 0.55, 10, PAINT_W)
        column(mono(build, POT), q.x, q.z, p.y + 0.76, p.y + 0.9, 0.09, 0.07, 6, POT)
      end
      balloons(p + u * 2.1 - w * 2.1 + Y * 2.5, 2)
      balloons(p - u * 2.1 - w * 2.1 + Y * 2.5, 6)

      -- the hay cart: a blue farm wagon on red wheels, loaded with bales, its shafts down
      c, u, w = V.at(26.2, 1, 8.6)
      p = on(c)
      local CART, WHEEL = col(0.1, 0.25, 0.5), col(0.7, 0.08, 0.05)
      cbox(build, WOOD, p + Y * 1.0, u * 1.6, Y * 0.06, w * 0.8)
      for sg = -1, 1, 2 do
        cbox(build, CART, p + Y * 1.3 + w * (sg * 0.82), u * 1.65, Y * 0.26, w * 0.035)
        cbox(build, CART, p + Y * 1.3 + u * (sg * 1.62), u * 0.035, Y * 0.26, w * 0.78)
        cbox(build, DARKWOOD, p + Y * 0.72 + u * (sg * 1.05), u * 0.05, Y * 0.05, w * 0.95)
        for e = -1, 1, 2 do
          local wc = p + Y * 0.7 + u * (sg * 1.05) + w * (e * 0.98)
          disc(build, WHEEL, wc, w, u, 0.68, 0.05, 12)
          disc(build, GOLD, wc + w * (e * 0.06), w, u, 0.14, 0.03, 8)
        end
        beam(build, DARKWOOD, p + Y * 0.95 - u * 1.6 + w * (sg * 0.5), on(p - u * 3.6 + w * (sg * 0.5), 0.08), 0.04, 0.04)
      end
      for k = -1, 1 do cbox(build, STRAW[k + 2], p + Y * 1.36 + u * (k * 1.05), u * 0.5, Y * 0.3, w * 0.72) end
      for k = 0, 1 do cbox(build, STRAW[k + 4], p + Y * 1.97 + u * (k * 1.1 - 0.55), u * 0.52, Y * 0.3, w * 0.6) end
      cbox(build, STRAW[1], p + Y * 2.55 + u * 0.1, u * 0.5 + w * 0.12, Y * 0.28, w * 0.45 - u * 0.1)

      -- the maypole: striped, a crown of flowers, ribbons out to the ground
      c, u, w = V.at(22.4, 1, 14.6)
      p = on(c)
      local rings_ = {}
      for k = 0, 12 do rings_[k + 1] = ring(v3(p.x, p.y - 0.4 + k * 0.55, p.z), 0.09, 0.09, 6, 0) end
      prism(X.sub(build, "maypole"), rings_, function(j, _) return (j % 2 == 0) and RED or PAINT_W end, RED, RED)
      local topm = p + Y * 6.2
      ball(mono(bushes, FLOWERS[3]), topm + Y * 0.1, 0.42, 0.16, 0.42, 8, 3, one, function() return FLOWERS[3] end)
      for k = 0, 7 do
        local a = k / 8 * 6.2832 + 0.3
        beam(flags, BRIGHT[k % #BRIGHT + 1], topm, on(p + v3(cos(a) * 3.6, 0, sin(a) * 3.6), 0.9), 0.05, 0.006)
      end
      -- bales to sit on round the green, and the village oak
      for k = 0, 6 do
        local c2, u2, w2 = V.at(19.4 + k * 1.15, 1, 16.6 + (k % 2) * 0.8)
        cbox(build, STRAW[k % #STRAW + 1], on(c2, 0.28), u2 * 0.6 + w2 * ((k % 3 - 1) * 0.2), Y * 0.3, w2 * 0.45 - u2 * ((k % 3 - 1) * 0.15))
      end
      c = V.at(19.9, 1, 13.2)
      X.tree(c.x, c.z, 1.9, "oak")
    end

    -- Bunting over the village street: a pole either side every few samples, pennants strung across the road between
    -- each pair and on down each side to the next.
    local function pennants(a, b, sag, n, key)
      local dir = normalize(b - a)
      local hz = normalize(v3(dir.z, 0, -dir.x)) * 0.008
      local function at_(t) return lerp(a, b, t) + v3(0, -sag * 4 * t * (1 - t), 0) end
      for k = 0, 4 do beam(flags, PAINT_W, at_((k + 0.01) / 5), at_((k + 0.99) / 5), 0.008, 0.008) end
      for q = 0, n - 1 do
        local p0, p1 = at_((q + 0.14) / n) - v3(0, 0.014, 0), at_((q + 0.86) / n) - v3(0, 0.014, 0)
        local tip = lerp(p0, p1, 0.5) + v3(0, -0.42, 0)
        local fb = mono(flags, BRIGHT[(q + key) % #BRIGHT + 1])
        local i1, i2, i3 = vert(fb, p0 + hz), vert(fb, p1 + hz), vert(fb, tip + hz)
        local j1, j2, j3 = vert(fb, p0 - hz), vert(fb, p1 - hz), vert(fb, tip - hz)
        tri(fb, i1, i2, i3, hz)
        tri(fb, j1, j2, j3, hz * -1)
        local mid = (p0 + p1 + tip) * (1 / 3)
        quad(fb, i1, i2, j2, j1, (p0 + p1) * 0.5 - mid)
        quad(fb, i2, i3, j3, j2, (p1 + tip) * 0.5 - mid)
        quad(fb, i3, i1, j1, j3, (tip + p0) * 0.5 - mid)
      end
    end
    do
      local last
      for s = 15, 47, 4 do
        local tops_ = {}
        for side = -1, 1, 2 do
          local base = pos[s] + right[s] * (side * (W[s] + WALL_T + 0.6))
          column(mono(flags, PAINT_W), base.x, base.z, base.y - 0.6, base.y + 6.3, 0.06, 0.045, 6, PAINT_W)
          ball(mono(flags, BRIGHT[3]), base + v3(0, 6.36, 0), 0.09, 0.09, 0.09, 6, 4, one, function() return BRIGHT[3] end)
          tops_[side] = base + v3(0, 6.2, 0)
        end
        pennants(tops_[-1], tops_[1], 0.8, 13, s)
        if last then
          for side = -1, 1, 2 do pennants(last[side], tops_[side], 1.1, 15, s + side) end
        end
        last = tops_
      end
    end

    -- The fields' boundaries, along the grid's edges where two fields meet: a dry stone wall (coped near the road), a
    -- hedge with a tree in it now and then, or nothing. None within a few metres of the road, nor through the village.
    local hts, dist_ = X.hts, X.dist
    local function boundary(c0, r0, c1, r1, idA, idB)
      local a, b = r0 * cols + c0 + 1, r1 * cols + c1 + 1
      local dmin = min(dist_[a], dist_[b])
      if dmin < HW + 9.5 then return end
      local p0, p1 = v3(X0 + c0 * STEP, 0, Z0 - r0 * STEP), v3(X0 + c1 * STEP, 0, Z0 - r1 * STEP)
      if X.taken(p0.x, p0.z, 5) or X.taken(p1.x, p1.z, 5) or X.taken((p0.x + p1.x) / 2, (p0.z + p1.z) / 2, 5) then return end
      local h = hash(min(idA, idB) * 1.37, max(idA, idB) * 0.71)
      local key = c0 * 131 + r0 * 17 + (c1 - c0)
      if h < 0.6 then
        local near = dmin < HW + 50
        local n = near and 3 or 2
        local dir = normalize(p1 - p0)
        local sd = v3(dir.z, 0, -dir.x)
        local ya, yb = hts[a], hts[b]
        for k = 0, n - 1 do
          local t0, t1 = (k + 0.004) / n, (k + 0.996) / n
          local A, B = lerp(p0, p1, t0) + v3(0, ya + (yb - ya) * t0, 0), lerp(p0, p1, t1) + v3(0, ya + (yb - ya) * t1, 0)
          local hh = 1.1 + (hash(k, key) - 0.5) * 0.16
          local t = sd * (0.27 + (hash(k, key + 1) - 0.5) * 0.05)
          local dn, up = v3(0, -0.45, 0), v3(0, hh, 0)
          hex(mono(rocks, pickh(WALLS, k, key + 2)), A - t + dn, B - t + dn, B + t + dn, A + t + dn, A - t + up, B - t + up, B + t + up, A + t + up)
          if near then
            local c0_, c1_, t2 = lerp(A, B, 0.03), lerp(A, B, 0.97), t * 0.72
            local u0, u1 = v3(0, hh - 0.03, 0), v3(0, hh + 0.12 + hash(k, key + 3) * 0.06, 0)
            hex(mono(rocks, COPE), c0_ - t2 + u0, c1_ - t2 + u0, c1_ + t2 + u0, c0_ + t2 + u0, c0_ - t2 + u1, c1_ - t2 + u1, c1_ + t2 + u1, c0_ + t2 + u1)
          end
        end
      elseif h < 0.88 then
        hedge(p0, p1, 1.7, 1.3, key)
        if hash(key, 7) < 0.17 then
          X.tree((p0.x + p1.x) / 2 + 0.01, (p0.z + p1.z) / 2, 1.0 + hash(key, 9) * 0.6, (hash(key, 11) < 0.25) and "poplar" or "oak")
        end
      end
    end
    for r = 0, rows - 2 do
      for c = 0, cols - 2 do
        local id = F.id(c, r)
        if c > 0 then
          local o = F.id(c - 1, r)
          if o ~= id then boundary(c, r, c, r + 1, id, o) end
        end
        if r > 0 then
          local o = F.id(c, r - 1)
          if o ~= id then boundary(c, r, c + 1, r, id, o) end
        end
      end
    end

    -- The orchard: rows of small trees in blossom behind a low wall.
    do
      local G = V.orchard
      local function gp(a, b) return v3(G.c.x + G.u.x * a + G.w.x * b, 0, G.c.z + G.u.z * a + G.w.z * b) end
      for i = -1, 1 do
        for j = -1, 1 do
          local p = gp(i * 4.1 + (hash(i, j) - 0.5) * 0.8, j * 4.2 + (hash(j, i + 5) - 0.5) * 0.8)
          X.tree(p.x, p.z, 0.8 + hash(i + 2, j + 2) * 0.25, "blossom")
        end
      end
      stone_wall(build, gp(-G.hu, -G.hw), gp(G.hu, -G.hw), 0.9, 0.42, 951, true)
      stone_wall(build, gp(-G.hu, -G.hw + 0.3), gp(-G.hu, G.hw), 0.9, 0.42, 952, true)
      stone_wall(build, gp(G.hu, -G.hw + 0.3), gp(G.hu, G.hw), 0.9, 0.42, 953, true)
      stone_wall(build, gp(-G.hu + 0.3, G.hw), gp(G.hu - 0.3, G.hw), 0.9, 0.42, 954, true)
    end

    -- Sheep in the pastures, rolled hay in the cut fields: a few of each, where a spot falls in such a field.
    local flocks, rolls = 0, 0
    for _ = 1, 600 do
      if flocks >= 9 and rolls >= 8 then break end
      local x, z = spot(13)
      if x and nearest(x, z) < HW + 55 then
        local kind = F.kind(F.id(max(0, min(cols - 2, floor((x - X0) / STEP))), max(0, min(rows - 2, floor((Z0 - z) / STEP)))))
        if kind == 1 and flocks < 9 then
          flocks = flocks + 1
          for k = 1, 4 do
            local sx, sz = x + g:range(-4.5, 4.5), z + g:range(-4.5, 4.5)
            if nearest(sx, sz) > HW + 11 and not X.taken(sx, sz, 4) then
              local yaw = g:range(0, 6.28)
              local d = v3(cos(yaw), 0, sin(yaw))
              local sdv = v3(-d.z, 0, d.x)
              local p = v3(sx, gh(sx, sz), sz)
              ball(mono(bushes, WOOL), p + Y * 0.62, 0.44, 0.34, 0.44, 6, 4, function() return g:range(0.9, 1.1) end, function() return WOOL end)
              cbox(bushes, PAINT_K, p + d * 0.5 + Y * 0.7, d * 0.14, Y * 0.11, sdv * 0.1)
              for e = -1, 1, 2 do
                for f = -1, 1, 2 do cbox(bushes, PAINT_K, p + d * (e * 0.22) + sdv * (f * 0.15) + Y * 0.17, d * 0.04, Y * 0.2, sdv * 0.04) end
              end
            end
          end
        elseif kind == 7 and rolls < 8 then
          rolls = rolls + 1
          for k = 1, 3 do
            local sx, sz = x + g:range(-7, 7), z + g:range(-7, 7)
            if nearest(sx, sz) > HW + 11 and not X.taken(sx, sz, 4) then
              local yaw = g:range(0, 3.14)
              disc(bushes, STRAW[k], v3(sx, gh(sx, sz) + 0.62, sz), v3(cos(yaw), 0, sin(yaw)), Y, 0.72, 0.6, 10)
            end
          end
        end
      end
    end
  end)() end
  local placed, tries = 0, 0
  -- (The first course: more trees, bushes and flowers than its script asks, each tree X.tree's.)
  X.nt = P.trees * (X.bare and 1.4 or 1) * (X.T and (X.T.trees or 1) or 1)
  while placed < X.nt and tries < X.nt * 20 do
    tries = tries + 1
    local x, z = spot(9)
    if x then
      placed = placed + 1
      if X.bare then
        local k = g:range(0, 1)
        X.tree(x, z, g:range(0.85, 1.6), (k < 0.13) and "pine" or ((k < 0.24) and "poplar" or ((k < 0.31) and "blossom" or "oak")))
      else
      local y = ground(x, z) - 0.4
      local s = g:range(0.8, 1.6)
      local turn = g:range(0, 1.5)
      local kind = g:range(0, 1)
      if kind < 0.5 then
        -- A pine: a trunk and four ragged tiers, each narrower, turned against the one below.
        local green = pick(PINES)
        column(trunks, x, z, y - 0.3, y + 2.6*s, 0.24*s, 0.16*s, 6, pick(BARK), turn)
        for tier = 0, 3 do
          local base = y + (1.5 + tier*1.15)*s
          local rad = (2.5 - tier*0.52)*s
          local pts = {}
          for k = 0, 11 do
            local a = turn + tier*0.5 + k / 12 * math.pi * 2
            local rr = rad * ((k % 2 == 0) and 1 or 0.78)
            pts[#pts + 1] = v3(x + math.cos(a)*rr, base - ((k % 2 == 0) and 0.18*s or 0), z + math.sin(a)*rr)
          end
          local shade = (tier % 2 == 0) and green or tint(green, 1.15)
          if SNOW and tier == 3 then shade = FROST end
          local under = tint(green, 0.6)
          cone(pines, pts, v3(x, base + 0.35*s, z), v3(x, base + (2.3 - tier*0.2)*s, z),
            function(k) return (SNOW and k % 3 == 0) and FROST or shade end, under)
        end
      else
        -- A leafy tree: a trunk, and a crown of three lumpy balls; one in four in its autumn colours.
        local birch = kind > 0.93
        local fall = g:range(0, 1) < 0.25 and not SNOW
        local base = fall and pick(AUTUMN) or pick(LEAFY)
        local crown = fall and autumn or leafy
        if birch then base = mix(pick(LEAFY), AUTUMN[3], 0.35) end
        column(trunks, x, z, y - 0.3, y + 2.8*s, 0.22*s, 0.15*s, 7, birch and BIRCH or pick(BARK), turn)
        local function lump() return g:range(0.88, 1.12) end
        local ch = y + 3.6*s
        ball(crown, v3(x, ch, z), 1.9*s, 1.55*s, 1.9*s, 9, 6, lump, shaded(base))
        local base2 = fall and pick(AUTUMN) or pick(LEAFY)
        for k = 0, 1 do
          local a = turn + k * 2.6
          ball(crown, v3(x + math.cos(a)*1.1*s, ch + (0.55 - k*0.9)*s, z + math.sin(a)*1.1*s), 1.25*s, 1.05*s, 1.25*s, 7, 5, lump, shaded(base2))
        end
      end
      end
    end
  end
  done(trunks, "trunks")
  done(pines, "pines")
  done(leafy, "leafy trees")
  done(autumn, "autumn trees")
  -- Bushes: low lumpy mounds in the greens, some with berries or blossom; flowers in clumps.
  local nb, nf = 0, 0
  local BLOOMS = {col(0.95, 0.85, 0.1), col(0.95, 0.95, 0.92), col(0.9, 0.2, 0.45), col(0.55, 0.25, 0.85), col(0.95, 0.4, 0.05), col(0.85, 0.05, 0.05)}
  local STEM = col(0.1, 0.32, 0.05)
  for _ = 1, X.nt * 6 do
    if nb >= math.floor(X.nt * 0.8) then break end
    local x, z = spot(4)
    if x then
      nb = nb + 1
      local s = g:range(0.6, 1.3)
      local y = ground(x, z) - 0.25
      local base = pick(LEAFY)
      local dots = (not SNOW and g:range(0, 1) < 0.35) and pick(BLOOMS) or nil
      local sh = shaded(base)
      local k = 0
      ball(X.sub(bushes, dots and (tostring(base) .. tostring(dots)) or base), v3(x, y + 0.45*s, z), 1.1*s, 0.85*s, 1.0*s, 8, 5, function() return g:range(0.85, 1.15) end,
        function(w) k = k + 1; if dots and k % 4 == 0 and w.y > 0 then return dots end return sh(w) end)
    end
  end
  if not SNOW then
    for _ = 1, X.nt * 6 do
      if nf >= math.floor(X.nt * 0.6) then break end
      local x, z = spot(4)
      if x then
        nf = nf + 1
        local bloom = pick(BLOOMS)
        local centre = (bloom == BLOOMS[2]) and BLOOMS[1] or col(0.95, 0.9, 0.5)
        for _ = 1, 3 do
          local fx, fz = x + g:range(-1.2, 1.2), z + g:range(-1.2, 1.2)
          local fy = ground(fx, fz)
          local hgt = g:range(0.35, 0.6)
          column(X.sub(bushes, bloom), fx, fz, fy - 0.3, fy + hgt, 0.025, 0.02, 3, STEM)
          -- The head: five petals round a centre, a flattened ball.
          local k = 0
          ball(X.sub(bushes, bloom), v3(fx, fy + hgt + 0.04, fz), 0.16, 0.06, 0.16, 5, 3, function() return 1 end,
            function(w) k = k + 1; return (w.y > 0.03 and k <= 5) and centre or bloom end)
        end
      end
    end
  end
  done(bushes, "bushes")
  -- Rocks: lumpy faceted boulders half sunk, in a few greys, mossy on top here and there.
  local STONE = {col(0.32, 0.31, 0.3), col(0.4, 0.38, 0.35), col(0.26, 0.26, 0.28), col(0.45, 0.42, 0.38)}
  local MOSS = SNOW and FROST or col(0.12, 0.3, 0.06)
  local stones = 0
  -- (A themed course's kit keeps T.rocks of them: 1 if it says nothing.)
  for _ = 1, P.trees * 4 * (X.T and (X.T.rocks or 1) or 1) do
    if stones >= math.floor(P.trees * 0.4) then break end
    local x, z = spot(3)
    if x then
      stones = stones + 1
      local y = ground(x, z)
      local s = g:range(0.5, 1.6)
      local grey = pick(STONE)
      local hi, lo = tint(grey, 1.15), tint(grey, 0.8)
      local mossy = g:range(0, 1) < 0.4
      ball(rocks, v3(x, y - 0.1, z), s * g:range(0.9, 1.5), s * g:range(0.55, 0.9), s * g:range(0.8, 1.3), 7, 4,
        function() return g:range(0.78, 1.18) end,
        function(w) local ny = w.y / math.max(1e-6, length(w)); if ny > 0.75 and mossy then return MOSS elseif ny > 0.2 then return hi elseif ny > -0.4 then return grey end return lo end)
    end
  end
  done(rocks, "rocks")

  -- The crowd is the game's own (src/game/systems/course.ts lays the spectators, the drivers' figure, all the way
  -- down): none built in here.
  local fans = 0
  local fin = sample_of(FINISH_POINT)

  -- Flags down the final stretch: a pole each side every few samples, a two-colour flag on each, and bunting
  -- of bright pennants strung between them.
  local flags = X.flags or builder()
  local tops = {[-1] = {}, [1] = {}}
  for s = math.max(2, fin - 40), fin - 4, 6 do
    for side = -1, 1, 2 do
      local p, r, t = pos[s], right[s], along(s)
      local base = p + r*(side*(W[s] + WALL_T + 0.35))
      column(flags, base.x, base.z, base.y - 0.6, base.y + 3.4, 0.05, 0.04, 6, PAINT_W)
      flags.ink = BRIGHT[3]
      ball(flags, base + v3(0, 3.45, 0), 0.08, 0.08, 0.08, 6, 4, function() return 1 end, function() return BRIGHT[3] end)
      local a, b2 = BRIGHT[(s + side + 8) % #BRIGHT + 1], BRIGHT[(s + side + 11) % #BRIGHT + 1]
      flags.ink = a
      road_box(flags, base + v3(0, 3.1, 0) - t*0.45, r, t, 0.03, 0.3, 0.8)
      flags.ink = b2
      road_box(flags, base + v3(0, 2.79, 0) - t*0.45, r, t, 0.03, 0.3, 0.8)
      tops[side][#tops[side] + 1] = base + v3(0, 3.3, 0)
    end
  end
  for side = -1, 1, 2 do
    local ts = tops[side]
    for k = 1, #ts - 1 do
      local a, b2 = ts[k], ts[k + 1]
      local n = 9
      local dir = normalize(b2 - a)
      local hz = normalize(v3(dir.z, 0, -dir.x)) * 0.006
      for q = 0, n - 1 do
        local u0, u1 = (q + 0.1) / n, (q + 0.9) / n
        local sag = function(u) return v3(0, -1.0 * 4 * u * (1 - u), 0) end
        local p0, p1 = lerp(a, b2, u0) + sag(u0), lerp(a, b2, u1) + sag(u1)
        local tip = lerp(p0, p1, 0.5) + v3(0, -0.4, 0)
        flags.ink = BRIGHT[(q + k + side) % #BRIGHT + 1]
        -- A pennant: a thin wedge, its top edge along the string.
        local s0, s1 = p0 + v3(0, 0.006, 0), p1 + v3(0, 0.006, 0)
        hexa(flags, s0 - hz, s1 - hz, s1 + hz, s0 + hz, s0 - hz + v3(0, 0.02, 0), s1 - hz + v3(0, 0.02, 0), s1 + hz + v3(0, 0.02, 0), s0 + hz + v3(0, 0.02, 0))
        local i1, i2, i3 = vert(flags, p0 + hz), vert(flags, p1 + hz), vert(flags, tip + hz)
        local j1, j2, j3 = vert(flags, p0 - hz), vert(flags, p1 - hz), vert(flags, tip - hz)
        local out = cross(p1 - p0, tip - p0)
        tri(flags, i1, i2, i3, out); tri(flags, j1, j2, j3, out * -1)
        local mid = (p0 + p1 + tip) * (1 / 3)
        quad(flags, i1, i2, j2, j1, (p0 + p1) * 0.5 - mid)
        quad(flags, i2, i3, j3, j2, (p1 + tip) * 0.5 - mid)
        quad(flags, i3, i1, j1, j3, (tip + p0) * 0.5 - mid)
      end
    end
  end
  done(flags, "flags", SHINY)

  -- The buildings: striped marquees and stacked hay behind the crowd at the finish, wooden fences along the
  -- slopes, and a farmhouse with a red barn far from the road.
  local build = X.build or builder()
  -- A hut: a rectangular footprint (centre c, axes u, w, half-sizes hu, hw), walls from y0 to y1 cut into strips
  -- of about `strip` metres coloured stripe(k), and a roof: a gable along u or a pyramid.
  local function hut(c, u, w, hu, hw, y0, y1, stripe, roof, gable, rise, over)
    local function perim(y, ex)
      local pts = {}
      local corners = {{1, 1}, {-1, 1}, {-1, -1}, {1, -1}}
      for q = 1, 4 do
        local a, b2 = corners[q], corners[q % 4 + 1]
        local pa = c + u*(a[1]*(hu + ex)) + w*(a[2]*(hw + ex)) + v3(0, y - c.y, 0)
        local pb = c + u*(b2[1]*(hu + ex)) + w*(b2[2]*(hw + ex)) + v3(0, y - c.y, 0)
        local len = length(pb - pa)
        local n = math.max(1, math.floor(len / 0.8 + 0.5))
        for k = 0, n - 1 do pts[#pts + 1] = lerp(pa, pb, k / n) end
      end
      return pts
    end
    prism(build, {perim(y0, 0), perim(y1 + 0.1, 0)}, function(_, k) return stripe(k) end, stripe(1), stripe(1))
    if gable then
      local function sec(sgn)
        local e = c + u*(sgn*(hu + over)) + v3(0, y1 - c.y, 0)
        return {e - w*(hw + over), e + v3(0, rise, 0), e + w*(hw + over), e + w*(hw + over) + v3(0, -0.15, 0), e - w*(hw + over) + v3(0, -0.15, 0)}
      end
      prism(build, {sec(-1), sec(1)}, function(_, k) return (k == 3 or k == 5) and tint(roof, 0.7) or roof end, roof, roof)
    else
      local pts = perim(y1, over)
      local cc = c + v3(0, y1 - c.y + 0.02, 0)
      cone(build, pts, cc, c + v3(0, y1 + rise - c.y, 0), function(k) return stripe(k) end, PAINT_W)
    end
  end
  local function lowest(c, u, w, hu, hw)
    local y = math.huge
    for _, a in ipairs({{1, 1}, {-1, 1}, {-1, -1}, {1, -1}, {0, 0}}) do
      local p = c + u*(a[1]*hu) + w*(a[2]*hw)
      y = math.min(y, ground(p.x, p.z))
    end
    return y
  end
  local function bales(c, u, w, n, colour)
    -- A stack: n bales along the bottom, one fewer each course up.
    for level = 0, n - 1 do
      for k = 0, n - 1 - level do
        local off = (k - (n - 1 - level) / 2) * 1.25
        local bc = c + u*off + v3(0, level * 0.62 + 0.3, 0)
        build.ink = STRAW[math.floor(hash(k, level) * #STRAW) + 1]
        local function v(x, y, z) return bc + u*(x*0.6) + v3(0, y*0.3, 0) + w*(z*0.45) end
        hexa(build, v(-1,-1,-1), v(1,-1,-1), v(1,-1,1), v(-1,-1,1), v(-1,1,-1), v(1,1,-1), v(1,1,1), v(-1,1,1))
      end
    end
  end
  -- Marquees: one each side of the finish, behind the crowd, red and white and blue and white. (None on a themed course.)
  for side = -1, X.T and -3 or 1, 2 do
    local s = math.max(2, math.min(N - 1, fin - 10 + side * 3))
    local r, t = right[s], along(s)
    local c = pos[s] + r*(side*(W[s] + WALL_T + 8.5))
    local y0 = lowest(c, t, r, 3, 2.2) - 0.6
    local stripe_a = (side < 0) and RED or BRIGHT[2]
    local top_ = math.max(y0 + 0.6, pos[s].y) + 2.3
    hut(v3(c.x, y0, c.z), t, r, 3, 2.2, y0, top_, function(k) return (k % 2 == 0) and PAINT_W or stripe_a end, stripe_a, false, 1.7, 0.35)
    local hc = pos[s] + r*(side*(W[s] + WALL_T + 8.5)) + t*5.5
    bales(v3(hc.x, lowest(hc, t, r, 1.8, 0.5) - 0.1, hc.z), t, r, 3, HAY)
  end
  -- Fences: post and two rails along some stretches, a few metres behind the walls on one side.
  local FENCE = (hash(C.seed, 1) < 0.5) and col(0.38, 0.25, 0.14) or col(0.85, 0.85, 0.8)
  for st = 1, N - 1, 30 do
    if not X.urban and not X.T and hash(st, C.seed) < 0.6 and math.abs(st - s_start) > 20 and math.abs(st + 10 - fin) > 30 then
      local side = (hash(st, 5) < 0.5) and -1 or 1
      local prev
      for s = st, math.min(N, st + 20), 2 do
        local b0 = pos[s] + right[s]*(side*(W[s] + WALL_T + 4.5))
        local gy = ground(b0.x, b0.z)
        local base = v3(b0.x, gy, b0.z)
        column(build, base.x, base.z, gy - 0.5, gy + 1.15, 0.07, 0.065, 6, FENCE)
        if prev then
          for _, hgt in ipairs({0.5, 0.95}) do
            local a, b2 = prev + v3(0, hgt, 0), base + v3(0, hgt, 0)
            local dir = normalize(b2 - a)
            local sd = normalize(v3(dir.z, 0, -dir.x)) * 0.035
            local a2, b3 = a + dir * 0.09, b2 - dir * 0.09
            local hy = v3(0, 0.06, 0)
            build.ink = FENCE
            hexa(build, a2 - sd - hy, b3 - sd - hy, b3 + sd - hy, a2 + sd - hy, a2 - sd + hy, b3 - sd + hy, b3 + sd + hy, a2 + sd + hy)
          end
        end
        prev = base
      end
    end
  end
  -- A farm: a cream house with a red roof and a chimney, a red barn with white trim, hay by the barn -- set on
  -- the first flattish spots well away from the road.
  local farms = 0
  local CREAM, ROOF_RED, BARN, SLATE = col(0.85, 0.78, 0.6), col(0.55, 0.08, 0.04), col(0.55, 0.07, 0.04), col(0.2, 0.22, 0.26)
  local WINDOW, DOOR = col(0.1, 0.18, 0.3), col(0.3, 0.17, 0.08)
  -- (The first course has its village, X.V's, for farms.)
  if X.V then farms = #X.V.sites end
  for _ = 1, (X.urban or X.bare or X.T) and 0 or 400 do
    if farms >= 2 then break end
    local x = g:range(X0 + 25, X1 - 25)
    local z = g:range(Z1 + 25, Z0 - 25)
    if nearest(x, z) > HW + 32 then
      local yaw = g:range(0, math.pi)
      local u, w = v3(math.cos(yaw), 0, math.sin(yaw)), v3(-math.sin(yaw), 0, math.cos(yaw))
      local barn = farms == 1
      local hu, hw = barn and 4.5 or 3.6, barn and 3.2 or 2.6
      local c = v3(x, 0, z)
      local y0 = lowest(c, u, w, hu, hw)
      local hi = -math.huge
      for _, a in ipairs({{1, 1}, {-1, 1}, {-1, -1}, {1, -1}}) do
        local p = c + u*(a[1]*hu) + w*(a[2]*hw)
        hi = math.max(hi, ground(p.x, p.z))
      end
      if hi - y0 < 2.5 then
        farms = farms + 1
        local wall = barn and BARN or CREAM
        local eave = hi + (barn and 4.2 or 3.0)
        local cc = v3(x, y0 - 0.8, z)
        hut(cc, u, w, hu, hw, y0 - 0.8, eave, function() return wall end, barn and SLATE or ROOF_RED, true, barn and 2.6 or 2.0, 0.4)
        -- Windows and a door: panels a few centimetres proud of the long walls.
        for sgn = -1, 1, 2 do
          local face_c = cc + w*(sgn*(hw + 0.04))
          if barn then
            build.ink = PAINT_W
            local dc = face_c + v3(0, hi + 1.4 - cc.y, 0)
            hexa(build, dc - u*1.3 - v3(0, 1.4, 0) - w*0.03, dc + u*1.3 - v3(0, 1.4, 0) - w*0.03, dc + u*1.3 - v3(0, 1.4, 0) + w*0.03, dc - u*1.3 - v3(0, 1.4, 0) + w*0.03,
              dc - u*1.3 + v3(0, 1.4, 0) - w*0.03, dc + u*1.3 + v3(0, 1.4, 0) - w*0.03, dc + u*1.3 + v3(0, 1.4, 0) + w*0.03, dc - u*1.3 + v3(0, 1.4, 0) + w*0.03)
            build.ink = tint(BARN, 0.7)
            local dc2 = dc + w*(sgn*0.04)
            hexa(build, dc2 - u*1.1 - v3(0, 1.25, 0) - w*0.03, dc2 + u*1.1 - v3(0, 1.25, 0) - w*0.03, dc2 + u*1.1 - v3(0, 1.25, 0) + w*0.03, dc2 - u*1.1 - v3(0, 1.25, 0) + w*0.03,
              dc2 - u*1.1 + v3(0, 1.25, 0) - w*0.03, dc2 + u*1.1 + v3(0, 1.25, 0) - w*0.03, dc2 + u*1.1 + v3(0, 1.25, 0) + w*0.03, dc2 - u*1.1 + v3(0, 1.25, 0) + w*0.03)
          else
            for q = -1, 1 do
              local pc = face_c + u*(q*2.1) + v3(0, hi + ((q == 0 and sgn > 0) and 1.0 or 1.6) - cc.y, 0)
              local hx, hy = (q == 0 and sgn > 0) and 0.5 or 0.45, (q == 0 and sgn > 0) and 1.0 or 0.45
              build.ink = (q == 0 and sgn > 0) and DOOR or WINDOW
              hexa(build, pc - u*hx - v3(0, hy, 0) - w*0.03, pc + u*hx - v3(0, hy, 0) - w*0.03, pc + u*hx - v3(0, hy, 0) + w*0.03, pc - u*hx - v3(0, hy, 0) + w*0.03,
                pc - u*hx + v3(0, hy, 0) - w*0.03, pc + u*hx + v3(0, hy, 0) - w*0.03, pc + u*hx + v3(0, hy, 0) + w*0.03, pc - u*hx + v3(0, hy, 0) + w*0.03)
            end
          end
        end
        if barn then
          local hc = cc + u*(hu + 3.5)
          bales(v3(hc.x, lowest(hc, w, u, 2, 0.6) - 0.1, hc.z), w, u, 3, HAY)
        else
          local ch = cc + u*(hu*0.55) + w*(hw*0.4)
          column(build, ch.x, ch.z, eave - 0.5, eave + 2.4, 0.32, 0.32, 4, col(0.45, 0.2, 0.12), yaw + math.pi / 4)
        end
      end
    end
  end
  -- The start ramp's trestles: a post under each edge of the deck every few samples, down to the ground fallen
  -- away beneath it, braced across.
  if X.ramp then
    for i = 1, X.ramp_end - 1, 3 do
      local dropped = X.drop(i)
      if dropped > 0.3 then
        for side = -1, 1, 2 do
          local b0 = pos[i] + right[i]*(side*(W[i] - 0.3))
          column(build, b0.x, b0.z, pos[i].y - 0.5 - dropped - 0.4, pos[i].y - 0.5, 0.16, 0.16, 4, X.timber, 0.3)
        end
        local a0, a1 = pos[i] - right[i]*(W[i] - 0.3), pos[i] + right[i]*(W[i] - 0.3)
        local mid = pos[i].y - 0.5 - dropped * 0.5
        build.ink = X.timber
        local t = along(i) * 0.06
        local lo, hi = v3(0, mid - pos[i].y - 0.1, 0), v3(0, mid - pos[i].y + 0.1, 0)
        a0 = v3(a0.x, pos[i].y, a0.z); a1 = v3(a1.x, pos[i].y, a1.z)
        hexa(build, a0 + lo - t, a1 + lo - t, a1 + lo + t, a0 + lo + t, a0 + hi - t, a1 + hi - t, a1 + hi + t, a0 + hi + t)
      end
    end
  end

  -- The city: terraced houses shoulder to shoulder along both sides behind the pavement, two to four storeys, each its
  -- own colour with a slate or tiled roof, windows on every floor and a front door; lamp posts along the kerb.
  -- (Its own function: its locals over the limit otherwise.)
  if X.urban then (function()
    local FRONTS = {col(0.85, 0.78, 0.62), col(0.75, 0.42, 0.32), col(0.55, 0.7, 0.8), col(0.92, 0.85, 0.45), col(0.62, 0.78, 0.55),
      col(0.9, 0.62, 0.62), col(0.8, 0.8, 0.78), col(0.55, 0.32, 0.22), col(0.95, 0.68, 0.38), col(0.6, 0.55, 0.75)}
    local ROOFS = {col(0.2, 0.22, 0.26), col(0.5, 0.18, 0.1), col(0.28, 0.26, 0.25)}
    local GLASS, FRAME = col(0.12, 0.2, 0.32), col(0.92, 0.92, 0.9)
    local DOORS = {col(0.55, 0.06, 0.05), col(0.05, 0.2, 0.5), col(0.06, 0.3, 0.12), col(0.1, 0.1, 0.1)}
    local LAMP, BULB = col(0.12, 0.13, 0.14), col(1, 0.85, 0.45)
    local SET_BACK = HW + WALL_T + 4.5
    local centres = {}
    local function clear_of(c, r)
      for _, q in ipairs(centres) do if (q.x - c.x)^2 + (q.z - c.z)^2 < r * r then return false end end
      return true
    end
    -- How far apart the houses' middles go along the road: their frontage.
    local run_ = 0
    for i = 2, N - 1 do
      run_ = run_ + length(pos[i] - pos[i - 1])
      if run_ >= 7.5 and math.abs(i - fin) > 14 then
        run_ = 0
        for side = -1, 1, 2 do
          local wid = 3.2 + hash(i, side + 31) * 1.0
          local deep = 4.5
          local r, t = right[i] * side, along(i)
          local c = pos[i] + r * (SET_BACK + W[i] - HW + deep)
          -- Clear of the road all round (a bend's inside crowds it) and of the houses already built.
          local ok = clear_of(c, 7)
          for _, q in ipairs({{1, 1}, {-1, 1}, {1, -1}, {-1, -1}}) do
            local k = c + t * (q[1] * wid) + r * (q[2] * deep)
            if nearest(k.x, k.z) < SET_BACK - 0.5 then ok = false end
          end
          if ok then
            centres[#centres + 1] = c
            X.houses = X.houses + 1
            local y0 = lowest(c, t, r, wid, deep) - 0.6
            local hi = -math.huge
            for _, q in ipairs({{1, 1}, {-1, 1}, {1, -1}, {-1, -1}}) do
              local k = c + t * (q[1] * wid) + r * (q[2] * deep)
              hi = math.max(hi, ground(k.x, k.z))
            end
            local floors = 2 + math.floor(hash(i, side + 41) * 3)
            local eave = hi + floors * 3
            local front = FRONTS[math.floor(hash(i, side + 37) * #FRONTS) + 1]
            local roof = ROOFS[math.floor(hash(i, side + 43) * #ROOFS) + 1]
            hut(v3(c.x, y0, c.z), t, r, wid, deep, y0, eave, function() return front end, roof, true, 1.6 + floors * 0.2, 0.3)
            -- Windows on each floor of the front facing the road, the door on the ground floor.
            local face_c = c - r * (deep + 0.04)
            local cols_ = math.max(1, math.floor(wid * 2 / 2.2))
            for fl = 0, floors - 1 do
              for q = 0, cols_ - 1 do
                local off = (q - (cols_ - 1) / 2) * (2 * wid / cols_)
                local door = fl == 0 and q == 0
                local pc = face_c + t * off + v3(0, hi + fl * 3 + (door and 1.05 or 1.7) - face_c.y, 0)
                local hx, hy = door and 0.5 or 0.55, door and 1.05 or 0.7
                -- (One panel each, no frame: the longest courses' budget.)
                for layer = 1, 1 do
                  local ex = layer == 0 and 0.1 or 0
                  build.ink = layer == 0 and FRAME or (door and DOORS[math.floor(hash(i, side + 47) * #DOORS) + 1] or GLASS)
                  local dz = r * (layer == 0 and 0.03 or 0.06)
                  local a_, b_ = t * (hx + ex), v3(0, hy + ex, 0)
                  hexa(build, pc - a_ - b_ - dz, pc + a_ - b_ - dz, pc + a_ - b_ + r * 0.0, pc - a_ - b_ + r * 0.0,
                    pc - a_ + b_ - dz, pc + a_ + b_ - dz, pc + a_ + b_ + r * 0.0, pc - a_ + b_ + r * 0.0)
                end
              end
            end
          end
        end
      end
    end
    -- Lamp posts on the pavement, every few samples, side to side.
    local lamp_run, lamp_side = 0, 1
    for i = 2, N - 1 do
      lamp_run = lamp_run + length(pos[i] - pos[i - 1])
      if lamp_run >= 22 then
        lamp_run = 0
        lamp_side = -lamp_side
        local r = right[i] * lamp_side
        local b0 = pos[i] + r * (W[i] + WALL_T + 1.4)
        local gy = ground(b0.x, b0.z)
        column(build, b0.x, b0.z, gy - 0.4, gy + 5.2, 0.09, 0.07, 6, LAMP)
        local arm0 = v3(b0.x, gy + 5.1, b0.z)
        local arm1 = arm0 - r * 1.3
        local sd = along(i) * 0.05
        build.ink = LAMP
        hexa(build, arm0 - sd, arm1 - sd, arm1 + sd, arm0 + sd, arm0 - sd + v3(0, 0.1, 0), arm1 - sd + v3(0, 0.1, 0), arm1 + sd + v3(0, 0.1, 0), arm0 + sd + v3(0, 0.1, 0))
        build.ink = BULB
        local lc = arm1 - v3(0, 0.12, 0)
        local lt, lr = along(i) * 0.22, r * 0.3
        hexa(build, lc - lt - lr, lc + lt - lr, lc + lt + lr, lc - lt + lr, lc - lt - lr + v3(0, 0.14, 0), lc + lt - lr + v3(0, 0.14, 0), lc + lt + lr + v3(0, 0.14, 0), lc - lt + lr + v3(0, 0.14, 0))
      end
    end
  end)() end
  -- The shortcut: its own road (a hair under the main road where they overlap), red and white barriers along both
  -- sides clear of the main road, a gap over the duck pond; the pond's water; bunting over it; and the signs at the
  -- split -- a yellow board with a black chevron toward the shortcut and a duck on it, a green one toward the road
  -- round.
  if X.cut then (function()
    local c = X.cut
    local cut = builder()
    local DUCK, BILL, WATER_C = col(1, 0.82, 0.08), col(1, 0.42, 0.05), col(0.12, 0.42, 0.62)
    local rt = v3(-c.uz, 0, c.ux)        -- the shortcut's right
    local dir = v3(c.ux, 0, c.uz)
    local function at_u(u) return v3(c.a.x + c.ux * c.len * u, c.a.y + (c.b.y - c.a.y) * u - 0.015, c.a.z + c.uz * c.len * u) end
    local STEPS = 60
    local function main_off(q) local dd = nearest(q.x, q.z); return dd end
    -- Its road, level across: its middle (`m`, on its straight slope) eased into the main road's surface (carried on
    -- past its edge) over CUT_BLEND metres off the main road's edge, and a corner over the main road never above it
    -- (a hair under) -- no step where the two meet at an angle. As the race measures it (track.ts' cutSurface).
    local CUT_BLEND = 6
    -- The main road against (x, z): its surface there, between the two nearest samples as it is built (no steps),
    -- and how far off its edge (x, z) is.
    local function main_at(q)
      local _, i = nearest(q.x, q.z)
      i = math.min(i, N)   -- (the main road's own samples: never the road on past its ends)
      local ti = v3(right[i].z, 0, -right[i].x)
      local along = dot(q - pos[i], ti)
      local j = math.max(1, math.min(N, along >= 0 and i + 1 or i - 1))
      local seg = math.sqrt((pos[j].x - pos[i].x)^2 + (pos[j].z - pos[i].z)^2)
      local f = (j == i or seg < 1e-6) and 0 or math.min(1, math.abs(along) / seg)
      local across = dot(q - pos[i], right[i]) * (1 - f) + dot(q - pos[j], right[j]) * f
      -- (Each sample its own width: the road narrows and widens, as track.ts' liftAt has it.)
      local wf = W[i] * (1 - f) + W[j] * f
      local held = math.max(-wf, math.min(wf, across))
      local si = (math.max(-1, math.min(1, held / W[i])) + 1) / 2
      local sj = (math.max(-1, math.min(1, held / W[j])) + 1) / 2
      local yi = pos[i].y + lift(i, -1) * (1 - si) + lift(i, 1) * si
      local yj = pos[j].y + lift(j, -1) * (1 - sj) + lift(j, 1) * sj
      return yi * (1 - f) + yj * f, math.abs(across) - wf
    end
    local function level_at(m)
      local edge, out = main_at(m)
      local w = math.max(0, math.min(1, 1 - out / CUT_BLEND))
      local e = w * w * (3 - 2 * w)
      return edge * e + m.y * (1 - e)
    end
    local function under_main(q, y)
      local main, out = main_at(q)
      if out <= 0 then y = math.min(y, main) end
      return v3(q.x, y - 0.015, q.z)
    end
    for k = 0, STEPS - 1 do
      local u0, u1 = k / STEPS, (k + 1) / STEPS
      local gap = u1 > c.pond_from and u0 < c.pond_to
      if not gap then
        -- A hair short at both ends: neighbouring slabs never share a corner.
        local p0, p1 = at_u(u0 + 0.0004), at_u(u1 - 0.0004)
        local y0, y1 = level_at(p0 + v3(0, 0.015, 0)), level_at(p1 + v3(0, 0.015, 0))
        local l0, r0_, l1, r1_ = under_main(p0 - rt * c.hw, y0), under_main(p0 + rt * c.hw, y0), under_main(p1 - rt * c.hw, y1), under_main(p1 + rt * c.hw, y1)
        local dn = v3(0, -0.5, 0)
        cut.ink = (k % 2 == 0) and tint(ROAD, 0.95) or tint(ROAD, 1.04)
        hexa(cut, l0 + dn, r0_ + dn, r1_ + dn, l1 + dn, l0, r0_, r1_, l1)
        -- The barriers either side, where they stand clear of the main road.
        for side = -1, 1, 2 do
          local w0 = p0 + rt * (side * (c.hw + 0.25))
          if main_off(w0) > HW + WALL_T + 0.6 then
            local w1 = p1 + rt * (side * (c.hw + 0.25))
            local o = rt * (side * 0.25)
            local up = v3(0, 0.75, 0)
            local sink = v3(0, -0.6, 0)
            cut.ink = (k % 2 == 0) and RED or PAINT_W
            hexa(cut, w0 - o + sink, w0 + o + sink, w1 + o + sink, w1 - o + sink, w0 - o + up, w0 + o + up, w1 + o + up, w1 - o + up)
          end
        end
      end
    end
    -- The pond's banks of the gap: two timber faces where the road stops, so its ends are not open slabs.
    for _, u in ipairs({c.pond_from, c.pond_to}) do
      local q = at_u(u)
      cut.ink = X.timber
      local t = dir * 0.15
      hexa(cut, q - rt * c.hw - t + v3(0, -3, 0), q + rt * c.hw - t + v3(0, -3, 0), q + rt * c.hw + t + v3(0, -3, 0), q - rt * c.hw + t + v3(0, -3, 0),
        q - rt * c.hw - t, q + rt * c.hw - t, q + rt * c.hw + t, q - rt * c.hw + t)
    end
    done(cut, "shortcut")

    -- The water: an ellipse of flat blue in the basin.
    local water = builder()
    local wy = c.a.y + (c.b.y - c.a.y) * X.pond.u - 2.6
    local centre = v3(c.a.x + c.ux * c.len * X.pond.u, wy, c.a.z + c.uz * c.len * X.pond.u)
    local ring = {}
    for k = 0, 31 do
      local an = k / 32 * math.pi * 2
      ring[#ring + 1] = vert(water, centre + dir * (math.cos(an) * (X.pond.ra + 1)) + rt * (math.sin(an) * (X.pond.rd + 1)))
    end
    local mid = vert(water, centre)
    water.ink = WATER_C
    for k = 1, 32 do tri(water, mid, ring[k], ring[k % 32 + 1], UP) end
    -- A floor under it, so the part is closed.
    local under = {}
    for k = 1, 32 do
      local q = water.vs[ring[k]]
      under[k] = vert(water, q + v3(0, -0.05, 0))
    end
    local umid = vert(water, centre + v3(0, -0.05, 0))
    for k = 1, 32 do tri(water, umid, under[k % 32 + 1], under[k], UP * -1) end
    for k = 1, 32 do quad(water, ring[k], ring[k % 32 + 1], under[k % 32 + 1], under[k], water.vs[ring[k]] - centre) end
    done(water, "pond", material{name="Water", base_color=v3(1, 1, 1), roughness=0.08, metallic=0.1})

    -- Bunting across the pond: two poles each side of the gap, strings of pennants between them over the water.
    local flags = builder()
    for _, off in ipairs({-0.6, 0.6}) do
      local pa = centre + dir * (off * X.pond.ra) + rt * (X.pond.rd + 2)
      local pb = centre + dir * (off * X.pond.ra) - rt * (X.pond.rd + 2)
      for _, q in ipairs({pa, pb}) do column(flags, q.x, q.z, wy - 0.5, wy + 7.5, 0.1, 0.08, 6, X.timber) end
      local n = 18
      for k = 0, n - 1 do
        local t0, t1 = k / n, (k + 0.6) / n
        local sag = function(t) return 7.2 - math.sin(t * math.pi) * 1.4 end
        local q0 = lerp(pa, pb, t0); q0 = v3(q0.x, wy + sag(t0), q0.z)
        local q1 = lerp(pa, pb, t1); q1 = v3(q1.x, wy + sag(t1), q1.z)
        local tip = lerp(q0, q1, 0.5) + v3(0, -0.55, 0)
        flags.ink = BRIGHT[k % #BRIGHT + 1]
        local i0, i1, i2 = vert(flags, q0), vert(flags, q1), vert(flags, tip)
        local j0, j1, j2 = vert(flags, q0 + dir * 0.02), vert(flags, q1 + dir * 0.02), vert(flags, tip + dir * 0.02)
        tri(flags, i0, i1, i2, dir * -1)
        tri(flags, j0, j1, j2, dir)
        local m3 = (q0 + q1 + tip) * (1 / 3)
        quad(flags, i0, i1, j1, j0, (q0 + q1) * 0.5 - m3)
        quad(flags, i1, i2, j2, j1, (q1 + tip) * 0.5 - m3)
        quad(flags, i2, i0, j0, j2, (tip + q0) * 0.5 - m3)
      end
    end
    done(flags, "fete bunting", SHINY)

    -- The signs at the split, a few samples before it: a board on posts each side of the road. Toward the shortcut,
    -- yellow with black chevrons and a duck; toward the road round, green with white chevrons.
    local signs = builder()
    local si = math.max(2, C.shortcut.from + 1 - 14)
    local bend = dot(pos[math.min(N, C.shortcut.from + 13)] - pos[C.shortcut.from + 1], right[C.shortcut.from + 1])
    local cut_side = bend > 0 and -1 or 1      -- the main road bends to one side; the shortcut goes on, to the other
    for side = -1, 1, 2 do
      local r = right[si] * side
      local t = along(si)
      local base = pos[si] + r * (W[si] + WALL_T + 1.6)
      local gy = ground(base.x, base.z)
      local isCut = side == cut_side
      for _, o in ipairs({-1.3, 1.3}) do
        local q = base + t * o
        column(signs, q.x, q.z, gy - 0.4, gy + 3.6, 0.09, 0.09, 6, X.timber)
      end
      -- The board: facing up the road (toward -t), 3.2 wide, 1.6 high.
      local bc = base + v3(0, gy + 2.8 - base.y, 0)
      local function slab(c0, w, h, depth, colour)
        signs.ink = colour
        local a_, b_, d_ = r * (w / 2), v3(0, h / 2, 0), t * (depth / 2)
        hexa(signs, c0 - a_ - b_ - d_, c0 + a_ - b_ - d_, c0 + a_ - b_ + d_, c0 - a_ - b_ + d_, c0 - a_ + b_ - d_, c0 + a_ + b_ - d_, c0 + a_ + b_ + d_, c0 - a_ + b_ + d_)
      end
      slab(bc, 3.4, 1.7, 0.1, isCut and DUCK or col(0.05, 0.45, 0.12))
      -- Chevrons pointing the way: toward the shortcut's side, or the road round's.
      local way = isCut and cut_side or -cut_side
      for k = 0, 2 do
        local cc = bc - t * 0.07 + r * ((k - 1) * 0.75 * way * side) 
        local ink = isCut and PAINT_K or PAINT_W
        signs.ink = ink
        local tipp = cc + r * (0.28 * way * side)
        local function bar(p0, p1)
          local dd = normalize(p1 - p0)
          local nn = cross(dd, t) * 0.09
          local d2 = t * 0.03
          hexa(signs, p0 - nn - d2, p1 - nn - d2, p1 + nn - d2, p0 + nn - d2, p0 - nn + d2, p1 - nn + d2, p1 + nn + d2, p0 + nn + d2)
        end
        bar(cc + v3(0, 0.5, 0), tipp)
        bar(tipp, cc + v3(0, -0.5, 0))
      end
      if isCut then
        -- A duck over the chevrons: a round yellow body and head, an orange bill, on a blue disc.
        local dc = bc + v3(0, 1.4, 0) - t * 0.05
        slab(dc, 1.3, 1.0, 0.08, WATER_C)
        ball(signs, dc - t * 0.1 + v3(0, -0.12, 0), 0.42, 0.26, 0.12, 10, 5, function() return 1 end, function() return DUCK end)
        ball(signs, dc - t * 0.12 + r * 0.25 + v3(0, 0.18, 0), 0.18, 0.18, 0.1, 8, 5, function() return 1 end, function() return DUCK end)
        ball(signs, dc - t * 0.14 + r * 0.45 + v3(0, 0.15, 0), 0.12, 0.05, 0.06, 6, 3, function() return 1 end, function() return BILL end)
      end
    end
    done(signs, "split signs")
  end)() end
  -- THEME KITS: a themed course's own scenery. Its kit's build(K) gets the course and the library's tools in K:
  --   K.C, K.P            the design and the params; K.N samples, K.SUB a segment's, K.HW the designed half width
  --   K.pos[i], K.right[i], K.W[i]   each sample's centre (road top), flat right-hand direction and half width
  --   K.along(i), K.lift(i, side)    down the road there; a berm's build-up at that edge (metres)
  --   K.start, K.fin      the start line's and the finish line's samples; K.WALL_T the walls' thickness (behind W[i])
  --   K.X0, K.X1, K.Z0, K.Z1   the valley's extent (x from X0 to X1, z from Z1 to Z0)
  --   K.ground(x, z)      the valley's height there; K.ground_d(x, z) that and the distance off the road's middle
  --   K.spot(clear)       a random point on the slopes at least clear metres off the road (x, z), or nil
  --   K.g:range(lo, hi), K.pick(list), K.hash(a, b)   the course's own chance, the same every build
  --   K.col(r, g, b), K.tint(c, f), K.mix(a, b, t)    colours (linear); K.GRASS, K.ROAD, K.HAY, K.WHITE_C, K.BLACK
  --   K.builder()         a new builder; K.sub(b, key) a piece of b for colour key (keeps a big part in budget)
  --   K.hexa, K.prism, K.ring, K.column, K.cone, K.ball, K.road_box, K.hut, K.lowest, K.flat, K.shaded, K.slab
  --                       the library's shapes, as their comments above say (each into a builder, colour by ink)
  --   K.solid             a builder of things a kart hits (the "buildings" part: the game collides with it)
  --   K.deco              a builder of things it does not (the "theme" part: drawn, never collided with)
  --   K.done(b, name)     emit another builder as its own part (never collided with)
  -- T.rocks, like T.trees, is the share of the library's boulders kept (1 if left out).
  -- A kit may also give T.paint(x, z, off, ink, TK) -- a valley cell's colour, off metres past the road's edge (nil keeps
  -- ink; TK has col, tint, mix, hash) -- and T.shape(x, z, off, y, road_y, TK): the ground's height there (nil keeps y;
  -- leave it be within 8 m of the road's edge, where the game's crowd and walls stand).
  -- Nothing a kit builds stands on the road or within WALL_T + 1 of its edge, and nothing on the road's line overhead
  -- lower than 6 m: the game's road, walls and crowd are its own.
  if X.T then
    local deco = builder()
    X.T.build({C = C, P = P, N = N, SUB = SUB, HW = HW, pos = pos, right = right, W = W, along = along, lift = lift,
      start = s_start, fin = fin, WALL_T = WALL_T, X0 = X0, X1 = X1, Z0 = Z0, Z1 = Z1,
      ground = ground, ground_d = ground_d, spot = spot, g = g, pick = pick, hash = hash,
      col = col, tint = tint, mix = mix, GRASS = GRASS, ROAD = ROAD, HAY = HAY, WHITE_C = PAINT_W, BLACK = PAINT_K,
      builder = builder, sub = X.sub, hexa = hexa, prism = prism, ring = ring, column = column, cone = cone, ball = ball,
      road_box = road_box, hut = hut, lowest = lowest, flat = flat, shaded = shaded, slab = slab,
      solid = build, deco = deco, done = done})
    done(deco, "theme")
  end
  done(build, "buildings")

  info(string.format("%d road samples, %d trees, %d fans, %d farm buildings, %d houses", N, placed, fans, farms, X.houses))
end

return M
