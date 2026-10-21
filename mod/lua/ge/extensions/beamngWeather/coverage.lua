-- Use the F11 map rain_coverage volume as a read-only native profile. The mod
-- renders its own temporary layer so source objects, counts and assets stay intact.
local M={}
local state={available=false,source="Mod fallback"}
local function bounded(value,lo,hi)
  value=tonumber(value)
  if value and value==value and value>=lo and value<=hi then return value end
end
function M.profile(fallback)
  local result={};for k,v in pairs(fallback) do result[k]=v end
  state={available=false,source="Mod fallback"}
  for _,name in ipairs({"rain_coverage","WCA_rain"}) do
    local object=scenetree.findObject(name)
    if object and simObjectExists(object) and object:getClassName()=="Precipitation" then
      local width,height=bounded(object.boxWidth,2,1000),bounded(object.boxHeight,2,1000)
      if width and height then
        result.width,result.height=width,height
        local start=bounded(object.fadeDist,0,1000)
        local finish=bounded(object.fadeDistEnd,0.1,2000)
        if start and finish and finish>start then result.fade,result.fadeEnd=start,finish end
        state={available=true,source=name,width=width,height=height,fade=result.fade,fadeEnd=result.fadeEnd}
        break
      end
    end
  end
  return result
end
function M.getState() local result={};for k,v in pairs(state) do result[k]=v end;return result end
function M.clear() state={available=false,source="Mod fallback"} end
return M
