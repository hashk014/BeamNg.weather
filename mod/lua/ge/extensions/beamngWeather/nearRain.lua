-- A bounded, collision-free render mesh fills the native rain's cabin guard.
local M = {}
local g=require("ge/extensions/beamngWeather/surfaceMath")
local drops,columns={},{}
local time=0
local limits={low=300,medium=650,high=1100,ultra=1600}
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
function M.clear() drops,columns,time={},{},0 end
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
  -- Cover motion until the next mesh refresh, so the car cannot drive into an
  -- old batch of world-space drops between graphics frames.
  local motion=g.localVector(g.mul(velocity or g.v(),0.06),frame)
  local swept={lo=g.v(),hi=g.v()}
  for _,k in ipairs({"x","y","z"}) do
    swept.lo[k]=bounds.lo[k]+math.min(0,motion[k])-0.25
    swept.hi[k]=bounds.hi[k]+math.max(0,motion[k])+0.25
  end
  for i=1,target do
    local d=drops[i]
    if not d or g.length(g.sub(d.p,camera))>radius+1 then
      d={p=g.v(camera.x+(math.random()*2-1)*radius,camera.y+(math.random()*2-1)*radius,camera.z+(math.random()*2-1)*radius),speed=7+math.random()*4,tile=math.random(0,15)}
      drops[i]=d
    end
    d.p.z=d.p.z-d.speed*config.fallSpeed*dt
    if wind then d.p.x=d.p.x+wind.x*dt/1.8;d.p.y=d.p.y+wind.y*dt/1.8 end
    local relative=g.sub(d.p,camera)
    if relative.z < -radius then d.p.z=camera.z+radius end
    local roof=column(d.p.x,d.p.y,camera,budget)
    local localPos=g.localVector(g.sub(d.p,vehiclePos),frame)
    local inside=g.contains(localPos,swept)
    local distance=g.length(g.sub(d.p,camera))
    if roof and d.p.z>roof+0.03 and not inside and distance<radius+0.15 and distance>0.10 then
      local r=0.042*config.dropScale
      g.quad(part,g.sub(d.p,vehiclePos),g.mul(right,r),g.mul(direction,r*1.9),g.unit(g.sub(camera,d.p)),d.tile)
      visible=visible+1
    end
  end
  if time>2 then for key,c in pairs(columns) do if time-c.time>1 then columns[key]=nil end end end
  return part,visible,target
end
return M
