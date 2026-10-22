-- Read the player's current GPU mesh. No vehicle assets are copied or changed.
local M = {}
local g = require("ge/extensions/beamngWeather/surfaceMath")
local ffi = require("ffi")
if not pcall(ffi.typeof,"gpuPrimitive_t") then
  ffi.cdef("typedef struct {uint32_t startIndex;uint32_t indexCount;uint32_t materialId;} gpuPrimitive_t;")
end
local pending, requestedID, requestAge
local lastWarning
local triangleBudget=30000
local function diagnostic(level,message)
  if type(log)=="function" then log(level,"beamngWeather_glass",message) end
end
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
  -- Same material-ID mapping as the game's util/export.lua. JBeam's
  -- deformMaterialBase is an inherited option, not proof that a whole mesh
  -- consists of glass. A single flexmesh can contain several materials.
  local materials=vehicle.getMaterialNames and vehicle:getMaterialNames() or {}
  local candidates,seenRanges={},{}
  local candidateCount,duplicateRanges,rejectedPrimitives=0,0,0
  for i=0,tonumber(mesh.flexmeshesCount)-1 do
    local flex=mesh:flexmeshes(i)
    local name=tostring(flex.meshName)
    local body=names[name] or {}
    if not g.excludedGlass(name) then
      local primitiveCount=tonumber(flex.primitivesCount)
      if primitiveCount>100000 then error("Invalid primitive count for "..name) end
      local primitives=ffi.new("gpuPrimitive_t[?]",primitiveCount)
      assert(flex:primitivesGet(primitives),"Cannot read triangles for "..name)
      local panel={name=name,ranges={},count=0}
      for p=0,primitiveCount-1 do
        local primitive=primitives[p]
        local material=materials[tonumber(primitive.materialId)+1]
        local accepted
        if type(material)=="string" and material~="" then
          accepted=g.glassName(material)
        else
          accepted=g.glassName(name,body.deformMaterialBase)
        end
        if accepted then
          local first,length=tonumber(primitive.startIndex),tonumber(primitive.indexCount)
          if first+length>icount or length%3~=0 then error("Invalid triangle range for "..name) end
          local key=first..":"..length
          if not seenRanges[key] and length>0 then
            seenRanges[key]=true
            panel.ranges[#panel.ranges+1]={first=first,count=length/3}
            panel.count=panel.count+length/3
          else duplicateRanges=duplicateRanges+1 end
        else rejectedPrimitives=rejectedPrimitives+1 end
      end
      if panel.count>0 then
        candidates[#candidates+1]=panel
        candidateCount=candidateCount+panel.count
      end
    end
  end
  if #candidates>256 then error("Vehicle has more than 256 exterior glass meshes") end
  local triangles,points,panels={}, {}, {}
  local lookup,seenTriangles={},{}
  local function vertex(index)
    if index>=count then error("Invalid glass vertex index") end
    if not lookup[index] then
      lookup[index]=g.localVector(g.fromGpuVertex(vertices[index*3],vertices[index*3+1],vertices[index*3+2]),frame)
    end
    return lookup[index]
  end
  local duplicateTriangles=0
  for _,candidate in ipairs(candidates) do
    local panel={name=candidate.name,triangles={},credit=0,exposed=false}
    -- Keep every pane represented if a custom vehicle exceeds the CPU
    -- budget. Sample across its ranges instead of aborting all window rain.
    local quota=candidate.count
    if candidateCount>triangleBudget then
      quota=1+math.floor((triangleBudget-#candidates)*candidate.count/candidateCount)
      quota=math.min(quota,candidate.count)
    end
    local rangeIndex,rangeOffset=1,0
    for sample=0,quota-1 do
      local target=math.floor((sample+0.5)*candidate.count/quota)
      while target>=rangeOffset+candidate.ranges[rangeIndex].count do
        rangeOffset=rangeOffset+candidate.ranges[rangeIndex].count;rangeIndex=rangeIndex+1
      end
      local k=candidate.ranges[rangeIndex].first+(target-rangeOffset)*3
      local ia,ib,ic=tonumber(indices[k]),tonumber(indices[k+1]),tonumber(indices[k+2])
      local sorted={ia,ib,ic};table.sort(sorted)
      local key=table.concat(sorted,":")
      if not seenTriangles[key] then
        seenTriangles[key]=true
        local a,b,c=vertex(ia),vertex(ib),vertex(ic)
        local t=g.triangle(a,b,c,#panels+1)
        if t then
          triangles[#triangles+1]=t;panel.triangles[#panel.triangles+1]=#triangles
          points[#points+1]=a;points[#points+1]=b;points[#points+1]=c
        end
      else duplicateTriangles=duplicateTriangles+1 end
    end
    if #panel.triangles>0 then panels[#panels+1]=panel end
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
  local sampled=candidateCount>triangleBudget
  diagnostic("I",string.format("Vehicle %s: %d glass meshes, %d/%d triangles, %d duplicate ranges, %d duplicate triangles, %d non-window primitives rejected, sampled=%s",
    tostring(vehicle:getID()),#panels,#triangles,candidateCount,duplicateRanges,duplicateTriangles,rejectedPrimitives,tostring(sampled)))
  diagnostic("I",string.format("Z-up cabin bounds: (%.3f, %.3f, %.3f) to (%.3f, %.3f, %.3f)",
    bounds.lo.x,bounds.lo.y,bounds.lo.z,bounds.hi.x,bounds.hi.y,bounds.hi.z))
  return {triangles=triangles,panels=panels,bounds=bounds,sampled=sampled,sourceTriangles=candidateCount}
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
  if not ok then warning="Glass scan failed: "..tostring(result);result=nil end
  if warning and warning~=lastWarning then diagnostic("W",warning) end
  lastWarning=warning
  return result,warning
end
return M
