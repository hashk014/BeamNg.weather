-- Bounded surface particles on detected exterior glass and a dry cabin envelope.
local M={}
local g=require("ge/extensions/beamngWeather/surfaceMath")
local near=require("ge/extensions/beamngWeather/nearRain")
local glassMaterial=require("ge/extensions/beamngWeather/glassMaterial")
local geometry,vehicleID,vehicleData,adapter
local glassMesh,airMesh,group
local glassOrientation
local droplets={}
local state={available=false,glassDrops=0,nearDrops=0,guardRadius=0,reservedDrops=0}
local scanTimer,tick,exposureTimer,credit=0,0,0,0
local retryDelay=0
local failureTimer=0
local lastFailure
local function live(o) return o and simObjectExists(o) end
local function freeMeshes()
  if live(group) then group:delete() end
  group,glassMesh,airMesh=nil,nil,nil
  glassOrientation=nil
end
function M.clear()
  freeMeshes();near.clear()
  if adapter then adapter.cancel() end
  geometry,vehicleID,vehicleData=nil,nil,nil
  droplets={};scanTimer,tick,exposureTimer,credit,retryDelay=0,0,0,0,0
  state={available=false,glassDrops=0,nearDrops=0,guardRadius=0,reservedDrops=0}
end
function M.invalidate(id) if not id or id==vehicleID then M.clear() end end
function M.getState() local result={};for k,v in pairs(state) do result[k]=v end;return result end
local function makeMeshes()
  if live(group) and live(glassMesh) and live(airMesh) then return end
  freeMeshes()
  loadJsonMaterialsFile("art/beamng_weather_hashk014/surfaces.materials.json")
  for _,name in ipairs({"beamngWeather_hashk014_glassDrops","beamngWeather_hashk014_nearRain"}) do
    local material=scenetree.findObject(name)
    if not live(material) or material:getClassName()~="Material" then
      error("Rain material unavailable: "..name..". Restart with the complete mod ZIP.")
    end
  end
  group=createObject("SimGroup");group.canSave=false;group:registerObject("beamngWeather_hashk014_surfaces")
  scenetree.MissionGroup:addObject(group)
  local function create(name)
    local mesh=createObject("ProceduralMesh")
    mesh.canSave=false;mesh:setField("collisionType",0,"None")
    -- Materials and scene objects share one native namespace.
    mesh:registerObject("beamngWeather_hashk014_"..name.."Mesh")
    group:addObject(mesh)
    return mesh
  end
  glassMesh=create("glassDrops");airMesh=create("nearDrops")
end
local function edgeKey(a,b)
  local function key(v) return string.format("%.3f,%.3f,%.3f",v.x,v.y,v.z) end
  local x,y=key(a),key(b);if x>y then x,y=y,x end
  return x.."/"..y
end
local function prepare(data)
  local edges={}
  for i,t in ipairs(data.triangles) do
    t.neighbors={}
    for e,pair in ipairs({{t.b,t.c},{t.c,t.a},{t.a,t.b}}) do
      local key=t.panel..":"..edgeKey(pair[1],pair[2])
      local found=edges[key]
      if found then t.neighbors[e]=found[1];data.triangles[found[1]].neighbors[found[2]]=i else edges[key]={i,e} end
    end
  end
  geometry=data
end
local function walk(drop,delta)
  local target=g.add(g.point(geometry.triangles[drop.tri],drop.bary),delta)
  for _=1,5 do
    local t=geometry.triangles[drop.tri]
    local b=g.barycentric(target,t)
    if not b then return false end
    local edge=1;for i=2,3 do if b[i]<b[edge] then edge=i end end
    if b[edge]>=0 then drop.bary=b;return true end
    if not t.neighbors[edge] then return false end
    drop.tri=t.neighbors[edge]
  end
  return false
end
local function sheltered(world,incoming)
  if type(castRayStatic)~="function" then return true end
  local direction=g.unit(g.mul(incoming,-1))
  return castRayStatic(vec3(world.x,world.y,world.z),vec3(direction.x,direction.y,direction.z),120)<119.9
end
local function updateExposure(pos,frame,incoming)
  for _,panel in ipairs(geometry.panels) do
    local mid=g.v()
    for _,index in ipairs(panel.triangles) do local t=geometry.triangles[index];mid=g.add(mid,g.mul(g.add(g.add(t.a,t.b),t.c),1/3)) end
    mid=g.mul(mid,1/#panel.triangles)
    panel.exposed=not sheltered(g.add(pos,g.worldVector(mid,frame)),incoming)
  end
end
local function glass(config,dt,pos,frame,incoming,intensity)
  local relative=g.localVector(incoming,frame)
  local gravity=g.localVector(g.v(0,0,-9.81),frame)
  local weighted,total={},0
  for i,t in ipairs(geometry.triangles) do
    local weight=geometry.panels[t.panel].exposed and t.area*(0.12+g.flux(t.n,relative)/9) or 0
    total=total+weight;weighted[i]=total
  end
  local cap=({low=1200,medium=2400,high=4000,ultra=6000})[config.quality]
  credit=math.min(180,credit+total*450*intensity*config.glassAmount*dt)
  if #droplets==0 and total>0 and config.glassAmount>0 then
    credit=credit+math.min(300,cap*0.2)*math.min(1,intensity*config.glassAmount)
  end
  while credit>=1 and #droplets<cap do
    local wanted=math.random()*total
    local lo,hi=1,#weighted
    while lo<hi do local mid=math.floor((lo+hi)/2);if weighted[mid]<wanted then lo=mid+1 else hi=mid end end
    if total<=0 then break end
    local u=math.sqrt(math.random());local v=math.random()
    droplets[#droplets+1]={tri=lo,bary={1-u,u*(1-v),u*v},age=0,life=10+math.random()*12,size=0.002+math.random()^2*0.005}
    credit=credit-1
  end
  local material,materialWarning=glassMaterial.get(config)
  state.refraction=material=="beamngWeather_hashk014_glassLens"
  if materialWarning then state.warning=materialWarning end
  local part=g.part(material)
  local remaining,wetPanels={},{}
  for _,drop in ipairs(droplets) do
    drop.age=drop.age+dt
    local t=geometry.triangles[drop.tri]
    local flow=g.flow(t.n,gravity,relative,drop.size)
    if drop.age<drop.life and walk(drop,g.mul(flow,dt)) and #remaining<cap then
      remaining[#remaining+1]=drop
      t=geometry.triangles[drop.tri]
      local name=geometry.panels[t.panel].name
      wetPanels[name]=(wetPanels[name] or 0)+1
      local point=g.add(g.point(t,drop.bary),g.mul(t.n,0.0018))
      local tangent=g.project(gravity,t.n)
      if g.length(tangent)<0.001 then tangent=g.cross(t.n,g.v(1,0,0)) end
      local along=g.length(flow)>0.001 and g.unit(flow) or g.unit(tangent)
      local across=g.unit(g.cross(along,t.n))
      local size=drop.size*config.glassScale
      local up=g.mul(along,size*(1+math.min(3,g.length(flow)*10)))
      local age=math.min(15,math.floor(drop.age/drop.life*16))
      g.quad(part,g.worldVector(point,frame),g.worldVector(g.mul(across,size),frame),g.worldVector(up,frame),g.worldVector(t.n,frame),age)
    end
  end
  droplets=remaining
  return part,#droplets,wetPanels
end
local function update(config,dt,intensity)
  if not config.enabled or config.intensity<=0 or not getMissionFilename or getMissionFilename()=="" then M.clear();return end
  if not config.cabinProtection and not config.glassDrops then M.clear();return end
  if type(getPlayerVehicle)~="function" or not GPUMesh or not core_vehicle_manager then
    state.warning="Vehicle geometry APIs are unavailable. Native airborne rain remains enabled."
    return
  end
  local vehicle=getPlayerVehicle(0)
  if not vehicle then M.clear();return end
  local id=vehicle:getID()
  local data=core_vehicle_manager.getVehicleData(id)
  if not data or not data.vdata then M.clear();return end
  if vehicleID~=id or vehicleData~=data then M.clear();vehicleID=id;vehicleData=data end
  state.vehicleID=id
  local pos=vehicle:getPosition()
  local camera=core_camera.getPosition()
  if g.length(g.sub(camera,pos))>40 then
    state.guardRadius,state.reservedDrops,state.airBackend=0,0,"native"
    state.glassDrops,state.nearDrops=0,0;droplets={};exposureTimer=1
    freeMeshes();near.clear();return
  end
  if not geometry then
    retryDelay=retryDelay-dt
    if retryDelay>0 then return end
    if not adapter then adapter=require("ge/extensions/beamngWeather/glassGeometry") end
    local result,warning=adapter.poll(vehicle,data,dt)
    state.warning=warning
    if not result then if warning~="Detecting vehicle glass…" then retryDelay=3 end;return end
    prepare(result)
    state.available,state.panels,state.warning=true,#geometry.panels,nil
    state.glassTriangles=#geometry.triangles
    state.sampled=geometry.sampled
    exposureTimer=1
  end
  local frame=g.frame(vehicle:getDirectionVector(),vehicle:getDirectionVectorUp())
  local velocity=vehicle:getVelocity()
  local wind=g.v()
  if config.wind and core_environment.getGroundWind then wind=core_environment.getGroundWind() or wind end
  local incoming=g.sub(g.add(wind,g.v(0,0,-9)),velocity)
  local localCamera=g.localVector(g.sub(camera,pos),frame)
  local radius=g.guardRadius(localCamera,geometry.bounds)
  state.warning=config.cabinProtection and radius>12 and "Move the camera closer for cabin protection (12 m guard limit)."
    or geometry.sampled and "High-detail glass: using a bounded surface sample. Sliding across unsampled triangles may be shorter." or nil
  radius=config.cabinProtection and radius<=12 and radius or 0
  -- The replacement mesh must succeed before the native guard is enabled.
  makeMeshes()
  if glassOrientation then
    local delta=quat(vehicle:getRefNodeRotation())*glassOrientation:inversed()
    glassMesh:setPosRot(pos.x,pos.y,pos.z,delta.x,delta.y,delta.z,delta.w)
  else glassMesh:setPosition(pos) end
  exposureTimer=exposureTimer+dt
  if exposureTimer>=0.35 then updateExposure(pos,frame,incoming);exposureTimer=0 end
  tick=tick+dt
  if tick<1/30 then return end
  local step=math.min(0.08,tick);tick=0
  local glassPart,count,wetPanels
  if config.glassDrops then glassPart,count,wetPanels=glass(config,step,pos,frame,incoming,intensity) else droplets={};glassPart,count=g.part("beamngWeather_hashk014_glassDrops"),0 end
  if #glassPart.faces>0 then
    glassMesh:createMesh({{glassPart}});glassMesh:setHidden(false)
    glassOrientation=quat(vehicle:getRefNodeRotation())
    glassMesh:setPosRot(pos.x,pos.y,pos.z,0,0,0,1)
  else glassMesh:setHidden(true) end
  state.glassDrops=count
  state.wetPanels=wetPanels
  if radius>0 then
    airMesh:setPosition(pos)
    local part,visible,reserved=near.update(config,step,camera,math.max(radius,18*config.volume),pos,frame,geometry.bounds,intensity,velocity,wind)
    if #part.faces>0 then airMesh:createMesh({{part}});airMesh:setHidden(false) else airMesh:setHidden(true) end
    state.nearDrops,state.reservedDrops=visible,reserved
  else airMesh:setHidden(true);near.clear();state.nearDrops,state.reservedDrops=0,0 end
  state.guardRadius=radius
  state.airBackend=radius>0 and "mesh" or "native"
  if not config.glassDrops then state.refraction=false end
end
function M.update(config,dt,intensity)
  if failureTimer>0 then failureTimer=math.max(0,failureTimer-dt);return end
  local ok,err=xpcall(function() update(config,dt,intensity) end,debug.traceback)
  if not ok then
    M.clear()
    state.warning="Vehicle rain unavailable: "..tostring(err)
    if type(log)=="function" and state.warning~=lastFailure then log("W","beamngWeather_glass",state.warning) end
    lastFailure=state.warning
    failureTimer=3
  end
end
return M
