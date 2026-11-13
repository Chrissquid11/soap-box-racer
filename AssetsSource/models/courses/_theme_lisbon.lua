local T = {keep = true}
function T.build(K)
  info(string.format("EXT %d %d %d %d N %d start %d fin %d HW %.2f", K.X0, K.X1, K.Z0, K.Z1, K.N, K.start, K.fin, K.HW))
  for z = K.Z0, K.Z1, -10 do
    local s = ""
    for x = K.X0, K.X1, 10 do
      local y, d = K.ground_d(x, z)
      local ch = "."
      if d < K.HW + 2 then ch = "#" elseif d < 20 then ch = "+" elseif d > 60 then ch = " " end
      s = s .. ch
    end
    info(string.format("MAP %5d %s", z, s))
  end
  for i = 1, K.N, 10 do info(string.format("S %d %.1f %.1f %.1f", i, K.pos[i].x, K.pos[i].y, K.pos[i].z)) end
end
return T
