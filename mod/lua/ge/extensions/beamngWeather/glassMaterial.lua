-- Original custom surface material using the native back-buffer binding.
local M={}
local prefix="beamngWeather_hashk014_"
local strength
local failedStrength,failureWarning
local function ensure(name,class,setup)
  local obj=scenetree.findObject(prefix..name)
  if obj and simObjectExists(obj) then return obj end
  obj=createObject(class);obj.canSave=false
  local ok,err=pcall(function() setup(obj);obj:registerObject(prefix..name) end)
  if not ok then obj:delete();error(err) end
  return obj
end
local function refractive(config)
  ensure("glassLensShader","ShaderData",function(s)
    s.DXVertexShaderFile="shaders/beamng_weather_hashk014/glassRefraction.hlsl"
    s.DXPixelShaderFile=s.DXVertexShaderFile
    local modern=not Engine or not Engine.Render or Engine.Render.getAdapterType()~="Direct3D11"
    s.pixVersion=modern and 6 or 5
    if modern then s:setField("defines",0,"BNG_HLSL_MODEL=6") end
    s:setField("samplerNames",0,"$sceneColor")
  end)
  ensure("glassLensState","GFXStateBlockData",function(s)
    s.blendDefined=true;s.blendEnable=true
    s:setField("blendSrc",0,"GFXBlendSrcAlpha");s:setField("blendDest",0,"GFXBlendInvSrcAlpha")
    s.zDefined=true;s.zEnable=true;s.zWriteEnable=false
    s.cullDefined=true;s:setField("cullMode",0,"GFXCullNone")
    s.samplersDefined=true;s:setField("samplerStates",0,"SamplerClampLinear")
  end)
  local material=ensure("glassLens","CustomMaterial",function(m)
    m:setField("shader",0,prefix.."glassLensShader")
    m:setField("stateBlock",0,prefix.."glassLensState")
    m:setField("sampler","sceneColor","$backbuff")
    m:setField("refractionStrength",0,tostring(config.glassDistortion))
    m:setField("refract",0,"1")
    m:setField("fallback",0,prefix.."glassDrops")
    m.version=5
    m.translucent=true;m:setField("translucentBlendOp",0,"LerpAlpha");m.translucentZWrite=false
    m.doubleSided=true;m.castShadows=false
    strength=config.glassDistortion
  end)
  if strength~=config.glassDistortion then
    material:setField("refractionStrength",0,tostring(config.glassDistortion))
    if material.reload then material:reload() end
    strength=config.glassDistortion
  end
  return prefix.."glassLens"
end
function M.get(config)
  if config.glassDistortion<=0 then
    failedStrength,failureWarning=nil,nil
    return prefix.."glassDrops"
  end
  if failedStrength~=config.glassDistortion then
    local ok,result=pcall(refractive,config)
    if ok then failedStrength,failureWarning=nil,nil;return result end
    failedStrength=config.glassDistortion
    failureWarning="Refraction unavailable; using normal-mapped beads. Change refraction strength to retry. "..tostring(result)
    if type(log)=="function" then log("W","beamngWeather_glass",failureWarning) end
  end
  return prefix.."glassDrops",failureWarning
end
return M
