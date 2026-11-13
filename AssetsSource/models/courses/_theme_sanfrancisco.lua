local T = {keep = true}
function T.build(K)
  info(string.format("EXT X %s %s Z0 %s Z1 %s N %d start %d fin %d HW %s WALL %s", K.X0, K.X1, K.Z0, K.Z1, K.N, K.start, K.fin, K.HW, K.WALL_T))
  for i = 1, K.N, 20 do local p = K.pos[i]; info(string.format("S %d %.1f %.1f %.1f r %.2f %.2f", i, p.x, p.y, p.z, K.right[i].x, K.right[i].z)) end
  for z = K.Z0, K.Z1, -20 do
    local s = ""
    for x = K.X0, K.X1, 20 do local y, d = K.ground_d(x, z); s = s .. string.format("%4d", math.min(999, math.floor(d))) end
    info("D " .. string.format("%5d", z) .. s)
  end
end
return T
