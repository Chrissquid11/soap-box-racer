-- The Grand Canyon's scenery kit (a stand-in until its own): a few red rock stacks on the slopes.
local T = {trees = 0.3}

function T.build(K)
  local ROCK = K.col(0.62, 0.3, 0.16)
  for _ = 1, 30 do
    local x, z = K.spot(14)
    if x then
      local y = K.ground(x, z)
      K.solid.ink = ROCK
      K.column(K.solid, x, z, y - 1, y + 6 + K.g:range(0, 10), 3, 2, 7, ROCK)
    end
  end
end

return T
