-- BeamNg.weather: original runtime rain controller for BeamNG.drive 0.40.
local M = {}
local tag = "beamngWeather_hashk014"
local groupName = "beamngWeather_hashk014_runtime"
local configPath = "settings/beamngWeather_hashk014.json"
local budgets = {low = 1200, medium = 2800, high = 5000}
local config = {enabled = true, intensity = 0.65, quality = "medium", collisions = true}
local group, drops, coverage
local timer = 0
local status = "waiting"
local lastError
local suspended = false

local function normalize(data)
  if type(data) ~= "table" then return end
  if type(data.enabled) == "boolean" then config.enabled = data.enabled end
  if type(data.collisions) == "boolean" then config.collisions = data.collisions end
  local intensity = tonumber(data.intensity)
  if intensity and intensity == intensity and intensity ~= math.huge and intensity ~= -math.huge then
    config.intensity = math.max(0, math.min(1, intensity))
  end
  if budgets[data.quality] then config.quality = data.quality end
end

local function live(obj)
  return obj and simObjectExists(obj)
end

local function cleanup()
  -- Children are owned by our transient group; no map rain objects are touched.
  if live(group) then group:delete() end
  group, drops, coverage = nil, nil, nil
end

local function inMission()
  return not suspended and getMissionFilename() ~= "" and scenetree.MissionGroup ~= nil
end

local function getState()
  return {
    version = "0.1.0", enabled = config.enabled, intensity = config.intensity,
    quality = config.quality, collisions = config.collisions, status = status,
    maxDrops = budgets[config.quality],
    activeDrops = status == "raining" and math.floor(budgets[config.quality] * config.intensity) or 0,
    error = lastError
  }
end

local function requestState()
  guihooks.trigger("BeamngWeatherHashk014State", getState())
end

local function makeRain(name, datablock, fraction)
  local obj = createObject("Precipitation")
  if not obj then error("Cannot create Precipitation") end
  local ok, err = pcall(function()
    -- Precipitation needs its datablock before registration with the engine.
    obj:setField("dataBlock", 0, datablock)
    obj.canSave = false
    obj:registerObject(name)
    if not live(obj) then error("Cannot register " .. name) end
    group:addObject(obj)
  end)
  if not ok then
    pcall(function() obj:delete() end)
    error(err)
  end
  obj.boxWidth = fraction == 1 and 20 or 26
  obj.boxHeight = 12
  obj.dropSize = fraction == 1 and 0.08 or 1
  obj.minSpeed = 0.4
  obj.maxSpeed = 0.55
  obj.minMass = 4
  obj.maxMass = 5
  obj.fadeDist = 7
  obj.fadeDistEnd = 13
  obj.splashMS = 80
  obj.splashSize = 0.25
  obj.useTurbulence = true
  obj.useWind = true
  obj.numDrops = 0
  return obj
end

local function createRain()
  -- The native datablocks/textures are referenced, never copied into this mod.
  if not scenetree.findObject("rain_drop") or not scenetree.findObject("rain_medium") then
    error("Native rain datablocks unavailable; try an official Freeroam map")
  end
  if scenetree.findObject(groupName) then
    error("Runtime group already exists; reload game Lua with Ctrl+L")
  end
  group = createObject("SimGroup")
  if not group then error("Cannot create rain group") end
  group.canSave = false
  group:registerObject(groupName)
  if not live(group) then error("Cannot register rain group") end
  scenetree.MissionGroup:addObject(group)
  drops = makeRain(tag .. "_drops", "rain_drop", 1)
  coverage = makeRain(tag .. "_coverage", "rain_medium", 0.2)
end

local function reconcile()
  if not inMission() then
    cleanup()
    status, lastError = "waiting", nil
    return
  end
  if not config.enabled or config.intensity == 0 then
    cleanup()
    status, lastError = "stopped", nil
    return
  end
  local ok, err = pcall(function()
    if not live(group) or not live(drops) or not live(coverage) then
      cleanup()
      createRain()
    end
    local total = math.floor(budgets[config.quality] * config.intensity)
    local near = math.floor(total * 0.8)
    drops.numDrops = near
    coverage.numDrops = total - near
    drops.doCollision = config.collisions
    coverage.doCollision = config.collisions
  end)
  if ok then
    status, lastError = "raining", nil
  else
    cleanup()
    status = "unavailable"
    if lastError ~= tostring(err) then log("E", tag, tostring(err)) end
    lastError = tostring(err)
  end
end

local function configure(data)
  normalize(data)
  jsonWriteFile(configPath, config, true)
  reconcile()
  requestState()
end

local function onUpdate(dtReal)
  timer = timer + (dtReal or 0)
  if timer < 1 then return end
  timer = 0
  reconcile()
  requestState()
end

local function onPreRender()
  if status ~= "raining" or not live(drops) or not live(coverage) then return end
  local position = core_camera.getPosition()
  drops:setPosition(position)
  coverage:setPosition(position)
end

local function onExtensionLoaded()
  setExtensionUnloadMode(M, "manual")
  normalize(jsonReadFile(configPath))
  log("I", tag, "BeamNg.weather 0.1.0 loaded; rain enabled: " .. tostring(config.enabled))
end

local function onClientStartMission()
  suspended = false
  timer = 0 -- onUpdate retries until the map and its datablocks are ready.
end

local function onClientEndMission()
  suspended = true
  cleanup()
  status, lastError = "waiting", nil
  requestState()
end

local function onExtensionUnloaded()
  cleanup()
end

local function onSerialize()
  -- Game Lua reload retains the scene. Remove our group before replacing Lua.
  cleanup()
  return {config = config}
end

local function onDeserialized(data)
  if type(data) == "table" then normalize(data.config) end
  suspended = false
  timer = 0
end

local function onModDeactivated(mod)
  -- A manually loaded extension must unload when its ZIP is disabled.
  if type(mod) == "table" and mod.modname == "beamng_weather_hashk014" then
    extensions.unload(tag)
  end
end

M.getState = getState
M.requestState = requestState
M.configure = configure
M.setEnabled = function(enabled) configure({enabled = enabled}) end
M.setIntensity = function(intensity) configure({intensity = intensity}) end
M.onUpdate = onUpdate
M.onPreRender = onPreRender
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized
M.onModDeactivated = onModDeactivated
return M
