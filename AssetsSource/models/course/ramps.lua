-- The course's kicker ramps in their themes, one part each. Every one stands on the same footprint as
-- course/props.lua's plain `ramp` -- 4 m wide, 18 m long, at most 0.45 m high, its feet a hair above the road -- its
-- top in the same fine strips (no facet for a wheel to catch), but each its own shape and its own paint:
--
--   ramp_waves     three rolling waves, the middle one tallest: a dark deck between yellow-and-black edges, red
--                  skirts, and a red fin curling up beside each crest
--   ramp_candy     one big hump in pink and white stripes, mint sides
--   ramp_racing    two humps of grey track, a dashed centre line, red-and-white kerbs
--   ramp_piano     one hump: a piano's keyboard, black and white, black lacquered sides
--   ramp_table     a tabletop: up, a long flat top, down -- yellow with red polka dots, blue sides
--   ramp_barn      two humps of weathered grey boards, barn-red sides with white posts
--
-- Each is collided as it is drawn (its own MeshCollider): the kart rides what it sees. The fins stand beside the
-- deck, never on it; like the rest of a ramp, a knock on one does the kart no harm.
local PAINT = material{name="Paint", base_color=v3(1,1,1), roughness=0.75, metallic=0}

local function all(m) return faces_where(m, function(_) return true end) end
local function paint(m, c) return paint_faces(m, {faces=all(m), color=c}) end
local function paint_where(m, c, fn)
  local sel = faces_where(m, function(f) return fn(f.center, f.normal) == true end)
  if set_count(sel) == 0 then return m end
  return paint_faces(m, {faces=sel, color=c})
end
local function C(r, g, b) return v3(r, g, b) end
local function frac(v) return v - math.floor(v) end

local W, L, H = 4, 18, 0.45
local HW, Z0 = W / 2, -L / 2
local STRIPS = 120
local RAIL = 0.06

-- The profiles: the height along it, a share of H, for s from 0 (the near foot) to 1 (the far one) -- each starting
-- and ending flat on the road, with no corner anywhere.
local function hump(s) return (1 - math.cos(2 * math.pi * s)) / 2 end
local function humps(n) return function(s) return (1 - math.cos(2 * math.pi * n * s)) / 2 end end
local function waves(s)
  -- Three waves, the middle one the tallest.
  -- Taller than the others: 0.6 m at its middle crest.
  local w = (1 - math.cos(6 * math.pi * s)) / 2
  return 1.35 * w * (0.62 + 0.38 * math.sin(math.pi * s))
end
local function smooth(t) t = math.max(0, math.min(1, t)); return t * t * (3 - 2 * t) end
local function table_top(s)
  -- Up over its first quarter, flat over its middle half, down over its last quarter.
  if s < 0.3 then return smooth(s / 0.3) end
  if s > 0.7 then return smooth((1 - s) / 0.3) end
  return 1
end

-- A roller of the given profile: a closed solid, its top in STRIPS strips along it and 0.25 m columns across, its
-- sides cut along their foot for the rail.
local function roller(rise)
  local cols = math.ceil(W / 0.25)
  local per = 2 + cols + 1
  local verts, faces = {}, {}
  for i = 0, STRIPS do
    local s = i / STRIPS
    local z = Z0 + s * L
    local y = math.max(0.004, H * rise(s))
    verts[#verts + 1] = v3(-HW, 0, z)
    verts[#verts + 1] = v3(HW, 0, z)
    for j = 0, cols do verts[#verts + 1] = v3(-HW + W * j / cols, y, z) end
  end
  local n = STRIPS + 1
  local function b(i, k) return (i - 1) * per + k end
  local function t(i, j) return (i - 1) * per + 3 + j end
  for i = 1, n - 1 do
    faces[#faces + 1] = {b(i, 1), b(i, 2), b(i + 1, 2), b(i + 1, 1)}
    for j = 0, cols - 1 do faces[#faces + 1] = {t(i, j), t(i + 1, j), t(i + 1, j + 1), t(i, j + 1)} end
    faces[#faces + 1] = {b(i, 2), t(i, cols), t(i + 1, cols), b(i + 1, 2)}
    faces[#faces + 1] = {b(i, 1), b(i + 1, 1), t(i + 1, 0), t(i, 0)}
  end
  local foot, far = {b(1, 1)}, {b(n, 1), b(n, 2)}
  for j = 0, cols do foot[#foot + 1] = t(1, j) end
  foot[#foot + 1] = b(1, 2)
  for j = cols, 0, -1 do far[#far + 1] = t(n, j) end
  faces[#faces + 1] = foot
  faces[#faces + 1] = far
  local m = polyhedron{vertices=verts, faces=faces}
  return knife(m, {normal=axis_y(), point=v3(0, RAIL, 0), faces=faces_where(m, function(f) return math.abs(f.normal.x) > 0.9 end)})
end

local function along(c) return (c.z - Z0) / L end
local function top(nn) return nn.y > 0.2 and math.abs(nn.x) < 0.5 end
local function side(nn) return math.abs(nn.x) > 0.9 end
local function rail(c, nn) return side(nn) and c.y < RAIL end
local function edge(c, nn, w) return top(nn) and math.abs(c.x) > HW - w end

-- A theme: its profile, the deck's colour, the sides', the rail's, then { colour, where(c, nn) } painted over in
-- order, and any pieces besides (already painted).
local function theme(name, rise, deck, sides, rails, over, extra)
  local m = paint(roller(rise), deck)
  m = paint_where(m, sides, function(c, nn) return side(nn) end)
  m = paint_where(m, rails, rail)
  for _, o in ipairs(over) do m = paint_where(m, o[1], o[2]) end
  m = smooth_normals(m, {angle=35})
  if extra and #extra > 0 then
    local parts = {{mesh=m, material=PAINT}}
    for _, e in ipairs(extra) do parts[#parts + 1] = {mesh=smooth_normals(e, {angle=40}), material=PAINT} end
    m = merge({parts=parts})[1].mesh
  end
  emit(m, {name=name, material=PAINT})
end

local black = C(0.05, 0.05, 0.06)
local yellow = C(1.0, 0.78, 0.04)
local red = C(0.86, 0.08, 0.05)
local white = C(0.95, 0.95, 0.93)

-- Waves: as the picture -- a near-black deck, a yellow band down each edge with black dashes across it, red skirts,
-- and a red fin beside each crest, curling up and back like a wave breaking.
do
  local fins = {}
  -- A fin's outline in (along, up), a unit high and 1.8 long: a curling blade like a breaking wave -- its front a
  -- full curve up to a tip leaning back over its foot, its back a hollow sweep down to the ground behind.
  local function bez(a, c, b, t) local u = 1 - t; return v2(u * u * a.x + 2 * u * t * c.x + t * t * b.x, u * u * a.y + 2 * u * t * c.y + t * t * b.y) end
  local A, T, D = v2(-0.9, 0), v2(0.35, 1.0), v2(0.9, 0)
  local outline = {}
  local N = 8
  for i = 0, N do outline[#outline + 1] = bez(A, v2(-0.75, 0.95), T, i / N) end
  for i = 1, N - 1 do outline[#outline + 1] = bez(T, v2(0.3, 0.3), D, i / N) end
  outline[#outline + 1] = D
  local area = 0
  for i = 1, #outline do
    local a, b = outline[i], outline[i % #outline + 1]
    area = area + a.x * b.y - b.x * a.y
  end
  if area < 0 then
    local r = {}
    for i = #outline, 1, -1 do r[#r + 1] = outline[i] end
    outline = r
  end
  local blade = extrude(poly{points=outline}, {distance=0.16})
  -- Extruded up y from the xz plane: stood up (the outline's y to height, x to along), its thickness across.
  blade = rotate(blade, {angle=90, axis=axis_x(), pivot=origin()})
  blade = rotate(blade, {angle=-90, axis=axis_y(), pivot=origin()})
  blade = bevel(blade, {edges=sharp_edges(blade, {angle=40}), width=0.03, segments=1})
  local bb = bbox(blade)
  blade = translate(blade, v3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2))
  for k = 0, 2 do
    local s = (k + 0.5) / 3
    local z = Z0 + s * L
    -- Rooted on the ground beside the deck, standing half a metre over its crest.
    local tall = H * waves(s) + 0.5
    for _, sx in ipairs({-1, 1}) do
      local f = scale(blade, {factor=v3(1, tall, 1), pivot=origin()})
      fins[#fins + 1] = paint(translate(f, v3(sx * (HW + 0.1), 0, z)), red)
    end
  end
  theme("ramp_waves", waves, C(0.13, 0.13, 0.14), red, black, {
    {yellow, function(c, nn) return edge(c, nn, 0.42) end},
    {black, function(c, nn) return edge(c, nn, 0.36) and math.abs(c.x) < HW - 0.07 and frac(along(c) * 30) < 0.45 end},
    {yellow, function(c, nn) return side(nn) and c.y > H * waves(along(c)) - 0.05 end},
  }, fins)
end

-- Candy: pink and white stripes across one big hump, a mint skirt on a pink rail, white candy-cane posts.
theme("ramp_candy", hump, C(0.98, 0.96, 0.95), C(0.45, 0.9, 0.72), C(1.0, 0.42, 0.68), {
  {C(1.0, 0.42, 0.68), function(c, nn) return top(nn) and math.floor(along(c) * 30) % 2 == 0 end},
  {C(0.98, 0.96, 0.95), function(c, nn) return side(nn) and c.y >= RAIL and frac(along(c) * 8) < 0.06 end},
})

-- Racing: two humps of grey tarmac, a dashed white line down the middle, red-and-white kerbs along the edges.
theme("ramp_racing", humps(2), C(0.22, 0.22, 0.24), red, white, {
  {white, function(c, nn) return top(nn) and math.abs(c.x) < 0.09 and math.floor(along(c) * 18) % 2 == 0 end},
  {red, function(c, nn) return edge(c, nn, 0.4) and math.floor(along(c) * 40) % 2 == 0 end},
  {white, function(c, nn) return edge(c, nn, 0.4) and math.floor(along(c) * 40) % 2 == 1 end},
  {white, function(c, nn) return side(nn) and c.y >= RAIL and c.y < RAIL + 0.04 end},
})

-- Piano: the keys laid across one hump, white with a dark gap between, the black keys over one end of them in the
-- keyboard's twos and threes; glossy black sides on a brass rail.
local KEYS = 42
local ivory, ebony = C(0.96, 0.95, 0.9), C(0.04, 0.04, 0.05)
local function black_key(i) return i == 0 or i == 1 or i == 3 or i == 4 or i == 5 end
theme("ramp_piano", hump, ivory, ebony, C(0.7, 0.55, 0.2), {
  {C(0.3, 0.3, 0.3), function(c, nn) return top(nn) and frac(along(c) * KEYS) < 0.05 end},
  {ebony, function(c, nn)
    if not top(nn) or c.x < -0.2 then return false end
    local k = along(c) * KEYS
    local f = frac(k)
    -- A black key over the gap after a white key: the last of this one's length, the first of the next's.
    if f > 0.72 then return black_key(math.floor(k) % 7) end
    if f < 0.28 then return black_key((math.floor(k) - 1) % 7) end
    return false
  end},
})

-- Tabletop: yellow with red polka dots, every other row of them a half over; a blue skirt with yellow spots.
local function spotted(x, z, pitch, r)
  local row = math.floor(z / pitch + 0.5)
  local gz = z / pitch - row
  local gx = x / pitch + (row % 2) * 0.5
  gx = gx - math.floor(gx + 0.5)
  return (gx * gx + gz * gz) * pitch * pitch < r * r
end
theme("ramp_table", table_top, C(1.0, 0.85, 0.12), C(0.12, 0.35, 0.9), red, {
  {red, function(c, nn) return top(nn) and spotted(c.x, c.z, 0.7, 0.2) end},
  {C(1.0, 0.85, 0.12), function(c, nn) return side(nn) and c.y >= RAIL and spotted(c.z, c.y * 3, 0.5, 0.11) end},
})

-- Barn: two humps of weathered grey boards across, darker between them and streaked; barn-red sides, white posts.
theme("ramp_barn", humps(2), C(0.58, 0.55, 0.5), C(0.62, 0.1, 0.07), C(0.25, 0.18, 0.12), {
  {C(0.5, 0.47, 0.42), function(c, nn) return top(nn) and math.floor(along(c) * 72) % 3 == 1 end},
  {C(0.66, 0.63, 0.57), function(c, nn) return top(nn) and math.floor(along(c) * 72) % 5 == 3 end},
  {C(0.3, 0.27, 0.24), function(c, nn) return top(nn) and frac(along(c) * 72) < 0.1 end},
  {C(0.95, 0.93, 0.88), function(c, nn) return side(nn) and c.y >= RAIL and frac(along(c) * 6 + 0.5) < 0.05 end},
})
