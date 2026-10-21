-- Read the player's current GPU mesh. No vehicle assets are copied or changed.
local M = {}
local g = require("ge/extensions/beamngWeather/surfaceMath")
local ffi = require("ffi")
if not pcall(ffi.typeof,"gpuPrimitive_t") then
  ffi.cdef("typedef struct {uint32_t startIndex;uint32_t indexCount;uint32_t materialId;} gpuPrimitive_t;")
end
local pending, requestedID, requestAge
function M.cancel()
  if pending then pcall(function() pending:free() end) end
  pending,requestedID,requestAge=nil,nil,0
end
local function decode(mesh,vehicle,data)
  local frame=g.frame(vehicle:getDirectionVector(),vehicle:getDirectionVectorUp())
  local count=tonumber(mesh.verticesCount)
  local icount=tonumber(mesh.indicesCount)
  if count<=0 or count>2000000 or icount>6000000 then error("Vehicle mesh exceeds the glass scan limit") end
  local vertices=ffi.new("float[?]",count*3)
  local indices=ffi.new("unsigned int[?]",icount)
  assert(mesh:verticesGet(vertices) and mesh:indicesGet(indices),"Cannot read vehicle geometry")
  local names={}
  for _,body in pairs(data.vdata.flexbodies or {}) do names[body.mesh]=body end
  local triangles,points,panels={}, {}, {}
  local lookup={}
  local function vertex(index)
    if index>=count then error("Invalid glass vertex index") end
    if not lookup[index] then lookup[index]=g.localVector(g.v(vertices[index*3],vertices[index*3+1],vertices[index*3+2]),frame) end
    return lookup[index]
  end
  for i=0,tonumber(mesh.flexmeshesCount)-1 do
    local flex=mesh:flexmeshes(i)
    local name=tostring(flex.meshName)
    local body=names[name] or {}
    if g.glassName(name,body.deformMaterialBase) then
      local primitives=ffi.new("gpuPrimitive_t[?]",flex.primitivesCount)
      assert(flex:primitivesGet(primitives),"Cannot read glass triangles")
      local panel={name=name,triangles={},credit=0,exposed=false}
      for p=0,tonumber(flex.primitivesCount)-1 do
        local primitive=primitives[p]
        local finish=math.min(icount,tonumber(primitive.startIndex+primitive.indexCount))
        for k=tonumber(primitive.startIndex),finish-3,3 do
          local a,b,c=vertex(tonumber(indices[k])),vertex(tonumber(indices[k+1])),vertex(tonumber(indices[k+2]))
          local t=g.triangle(a,b,c,#panels+1)
          if t then
            triangles[#triangles+1]=t;panel.triangles[#panel.triangles+1]=#triangles
            points[#points+1]=a;points[#points+1]=b;points[#points+1]=c
          end
          if #triangles>30000 then error("Too many glass triangles") end
        end
      end
      if #panel.triangles>0 then panels[#panels+1]=panel end
    end
  end
  if #triangles==0 then return nil,"No supported exterior window meshes were detected on this vehicle." end
  local bounds=g.bounds(points)
  local center=g.mul(g.add(bounds.lo,bounds.hi),0.5)
  for _,t in ipairs(triangles) do
    local mid=g.mul(g.add(g.add(t.a,t.b),t.c),1/3)
    if g.dot(t.n,g.sub(mid,center))<0 then t.n=g.mul(t.n,-1) end
  end
  -- A conservative cabin envelope; no physical collider is created.
  bounds.lo.z=bounds.lo.z-0.65
  return {triangles=triangles,panels=panels,bounds=bounds}
end
function M.poll(vehicle,data,dt)
  local id=vehicle:getID()
  if requestedID~=id then M.cancel();requestedID=id end
  if not pending then pending=GPUMesh.bng_getGPUMesh(id);requestAge=0 end
  if not pending then return nil,"The game could not provide the vehicle mesh." end
  requestAge=requestAge+(dt or 0)
  if not pending.dataIsReady then
    if requestAge>5 then M.cancel();return nil,"Timed out while reading vehicle glass." end
    return nil,"Detecting vehicle glass…"
  end
  local ok,result,warning=pcall(decode,pending,vehicle,data)
  M.cancel()
  if not ok then return nil,"Glass scan failed: "..tostring(result) end
  return result,warning
end
return M
