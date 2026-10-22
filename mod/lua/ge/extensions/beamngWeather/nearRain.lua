-- Bounded airborne renderer used instead of native emitters near the cabin.
local M = {}
local g=require("ge/extensions/beamngWeather/surfaceMath")
local drops,columns={},{}
local time=0
local limits={low=600,medium=900,high=1400,ultra=2000}
local pathStart,pathEnd
local function distanceSquared(p,a,b)
  local x,y,z=b.x-a.x,b.y-a.y,b.z-a.z
  local px,py,pz=p.x-a.x,p.y-a.y,p.z-a.z
  local length=x*x+y*y+z*z
  local t=length>1e-8 and math.max(0,math.min(1,(px*x+py*y+pz*z)/length)) or 0
  x,y,z=px-t*x,py-t*y,pz-t*z
  return x*x+y*y+z*z
end
function M.isSafe(pos)
  return pathStart and distanceSquared(pos,pathStart,pathEnd)<=0.3*0.3
end
local function column(x,y,camera,budget)
  local key=math.floor(x)..":"..math.floor(y)
  local saved=columns[key]
  if saved and time-saved.time<0.4 and math.abs(saved.top-camera.z)<0.8 then return saved.z end
  if budget.left<=0 then return nil end
  budget.left=budget.left-1
  local top=camera.z+20
  local dist=castRayStatic(vec3(math.floor(x)+0.5,math.floor(y)+0.5,top),vec3(0,0,-1),60)
  saved={time=time,top=camera.z,z=top-dist}
  columns[key]=saved
  return saved.z
end
function M.clear() drops,columns,time={},{},0;pathStart,pathEnd=nil,nil end
function M.update(config,dt,camera,radius,vehiclePos,frame,bounds,intensity,velocity,wind)
  time=time+dt
  local target=math.floor(math.min(limits[config.quality],config.maxDrops or 20000)*intensity)
  while #drops>target do drops[#drops]=nil end
  local budget={left=24}
  local part=g.part("beamngWeather_hashk014_nearRain")
  local visible=0
  local direction=g.v(0,0,-1)
  local camRotation=core_camera.getQuat()
  local cameraRight=camRotation*vec3(1,0,0)
  local right=g.unit(cameraRight)
  -- A capsule contains every rotation of the cabin, not just its last orientation.
  -- Include the footwell, full particle extent and 30 cm of unpredicted movement.
  local cabinRadius=0
  for _,x in ipairs({bounds.lo.x,bounds.hi.x}) do
    for _,y in ipairs({bounds.lo.y,bounds.hi.y}) do
      for _,z in ipairs({bounds.lo.z-0.8,bounds.hi.z}) do
        cabinRadius=math.max(cabinRadius,math.sqrt(x*x+y*y+z*z))
      end
    end
  end
  local quadRadius=0.042*config.dropScale*math.sqrt(1+1.9*1.9)
  local exclusion=cabinRadius+quadRadius+0.35
  pathStart=g.v(vehiclePos.x,vehiclePos.y,vehiclePos.z)
  pathEnd=g.add(pathStart,g.mul(velocity or g.v(),math.max(0.15,dt*2)))
  for i=1,target do
    local d=drops[i]
    if not d or g.length(g.sub(d.p,camera))>radius+1 then
      local spawnRadius=math.random()<0.75 and math.min(radius,6) or radius
      d={p=g.v(camera.x+(math.random()*2-1)*spawnRadius,camera.y+(math.random()*2-1)*spawnRadius,camera.z+(math.random()*2-1)*spawnRadius),speed=7+math.random()*4,tile=math.random(0,15)}
      drops[i]=d
    end
    d.p.z=d.p.z-d.speed*config.fallSpeed*dt
    if wind then d.p.x=d.p.x+wind.x*dt/1.8;d.p.y=d.p.y+wind.y*dt/1.8 end
    local relative=g.sub(d.p,camera)
    if relative.z < -radius then d.p.z=camera.z+radius end
    local roof=column(d.p.x,d.p.y,camera,budget)
    local inside=distanceSquared(d.p,pathStart,pathEnd)<=exclusion*exclusion
    local distance=g.length(g.sub(d.p,camera))
    if roof and d.p.z>roof+0.03 and not inside and distance<radius+0.15 and distance>0.8 then
      local r=0.042*config.dropScale
      g.quad(part,g.sub(d.p,vehiclePos),g.mul(right,r),g.mul(direction,r*1.9),g.unit(g.sub(camera,d.p)),d.tile)
      visible=visible+1
    end
  end
  if time>2 then for key,c in pairs(columns) do if time-c.time>1 then columns[key]=nil end end end
  return part,visible,target
end
return M
