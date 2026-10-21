-- BeamNg.weather: original visual-only rain controller for BeamNG.drive 0.40.
local M = {}
M.dependencies = {"ui_pause_actions", "core_environment"}
local model = require("ge/extensions/beamngWeather/model")
local clouds = require("ge/extensions/beamngWeather/clouds")
local tag = "beamngWeather_hashk014"
local groupName = tag .. "_runtime"
local configPath = "settings/beamngWeather_hashk014.json"
local dataPath = "art/beamng_weather_hashk014/rain.datablocks.json"
local config, personal = model.defaults(), {}
local group, layers
local status, lastError = "waiting", nil
local suspended = false
local healthTimer, visualTimer, clock = 0, 0, 0
local currentIntensity, activeDrops = 0, 0
local definitions = {
  {id = "fine", width = 12, height = 10, size = 0.12, minSpeed = 0.16, maxSpeed = 0.23, mass = 1.2, fade = 4, fadeEnd = 8},
  {id = "body", width = 26, height = 18, size = 0.24, minSpeed = 0.23, maxSpeed = 0.34, mass = 2.4, fade = 9, fadeEnd = 17},
  {id = "distant", width = 48, height = 26, size = 0.2, minSpeed = 0.2, maxSpeed = 0.3, mass = 1.8, fade = 17, fadeEnd = 29}
}
local function live(obj) return obj and simObjectExists(obj) end
local function cleanup()
  if live(group) then group:delete() end
  group, layers, activeDrops = nil, nil, 0
end
local function inMission()
  return not suspended and (getMissionFilename() or "") ~= "" and scenetree.MissionGroup ~= nil
end
local function save()
  local data = model.copy(config)
  data.personalPresets = personal
  jsonWriteFile(configPath, data, true)
end
local function getState()
  local data = model.copy(config)
  data.version, data.status, data.error = model.version, status, lastError
  data.maxDrops, data.activeDrops = model.budgets[config.quality], activeDrops
  data.presets, data.personalPresets = model.presets, {}
  data.clouds = clouds.getState()
  for i = 1, 3 do data.personalPresets[i] = {slot = i, saved = personal[tostring(i)] ~= nil} end
  return data
end
local function requestState() guihooks.trigger("BeamngWeatherHashk014State", getState()) end

local function setLayerParameters(obj, spec)
  obj.boxWidth, obj.boxHeight = spec.width * config.volume, spec.height * config.volume
  obj.dropSize = spec.size * config.dropScale
  obj.minSpeed, obj.maxSpeed = spec.minSpeed * config.fallSpeed, spec.maxSpeed * config.fallSpeed
  obj.minMass, obj.maxMass = spec.mass, spec.mass * 1.45
  obj.fadeDist, obj.fadeDistEnd = spec.fade * config.volume, spec.fadeEnd * config.volume
  obj.useWind, obj.useLighting = config.wind, config.lighting
  obj.useTurbulence = config.turbulence > 0
  obj.maxTurbulence, obj.turbulenceSpeed = 0.15 * config.turbulence, 0.12 + 0.18 * config.turbulence
  obj.doCollision, obj.hitVehicles, obj.hitPlayers = config.collisions, true, true
  obj.animateSplashes, obj.splashSize, obj.splashMS = false, 0.01, 1
  obj.followCam, obj.rotateWithCamVel = true, true
  obj.useTrueBillboards, obj.reflect = false, false
  obj.dropAnimateMS = 0 -- Pick a random atlas cell per drop; no frame flicker.
  local brightness = tostring(config.contrast)
  obj:setField("glowIntensity", 0, brightness .. " " .. brightness .. " " .. brightness .. " 1")
end
local function createLayer(spec)
  local obj = createObject("Precipitation")
  if not obj then error("Cannot create precipitation") end
  local ok, err = pcall(function()
    obj:setField("dataBlock", 0, tag .. "_" .. spec.id .. "Data")
    obj.canSave, obj.numDrops = false, 0
    setLayerParameters(obj, spec)
    obj:setPosition(core_camera.getPosition())
    obj:registerObject(tag .. "_" .. spec.id)
    if not live(obj) then error("Cannot register rain layer " .. spec.id) end
    group:addObject(obj)
  end)
  if not ok then pcall(function() obj:delete() end); error(err) end
  return obj
end
local function createRain()
  -- Without a precipitation shader, the native fallback ignores lighting and
  -- distance fading. Use original standalone shaders without legacy macros.
  if not scenetree.findObject(tag .. "_shader_v2") then
    local shader = createObject("ShaderData")
    if not shader then error("Cannot create rain shader") end
    shader.canSave = false
    shader.DXVertexShaderFile = "shaders/beamng_weather_hashk014/rainV.hlsl"
    shader.DXPixelShaderFile = "shaders/beamng_weather_hashk014/rainP.hlsl"
    shader.pixVersion = 5
    shader:setField("samplerNames", 0, "$diffuseMap")
    shader:registerObject(tag .. "_shader_v2")
    if not live(shader) then error("Cannot register rain shader") end
  end
  local missing = false
  for _, spec in ipairs(definitions) do
    if not scenetree.findObject(tag .. "_" .. spec.id .. "Data") then missing = true end
  end
  if missing then loadJsonMaterialsFile(dataPath) end
  for _, spec in ipairs(definitions) do
    if not scenetree.findObject(tag .. "_" .. spec.id .. "Data") then
      error("Rain datablock missing: " .. spec.id .. "; restart with the complete mod ZIP")
    end
  end
  if scenetree.findObject(groupName) then error("Runtime group already exists; press Ctrl+L") end
  group = createObject("SimGroup")
  if not group then error("Cannot create rain group") end
  group.canSave = false
  group:registerObject(groupName)
  if not live(group) then error("Cannot register rain group") end
  scenetree.MissionGroup:addObject(group)
  layers = {}
  for _, spec in ipairs(definitions) do layers[#layers + 1] = createLayer(spec) end
end
local function updateCounts()
  local counts, total = model.counts(config, currentIntensity, clock)
  for i, obj in ipairs(layers) do if obj.numDrops ~= counts[i] then obj.numDrops = counts[i] end end
  activeDrops = total
end
local function reconcile(updateParameters)
  if not inMission() then
    clouds.release()
    cleanup(); currentIntensity, status, lastError = 0, "waiting", nil
    return
  end
  if not config.enabled or config.intensity == 0 then
    clouds.release()
    cleanup(); currentIntensity, status, lastError = 0, "stopped", nil
    return
  end
  local ok, err = pcall(function()
    local complete = live(group) and layers and #layers == #definitions
    if complete then for _, obj in ipairs(layers) do if not live(obj) then complete = false end end end
    if not complete then cleanup(); createRain() end
    if updateParameters then for i, obj in ipairs(layers) do setLayerParameters(obj, definitions[i]) end end
    if config.transition == 0 then currentIntensity = config.intensity end
    updateCounts()
    clouds.update(config)
  end)
  if ok then status, lastError = "raining", nil else
    clouds.release()
    cleanup(); status = "unavailable"
    if lastError ~= tostring(err) then log("E", tag, tostring(err)) end
    lastError = tostring(err)
  end
end
local function configure(data)
  local before = model.profile(config)
  model.normalize(config, data)
  for k, v in pairs(before) do if config[k] ~= v then config.preset = "custom" end end
  save(); reconcile(true); requestState()
end
local function applyPreset(id)
  local preset = model.findPreset(id)
  if not preset then return false end
  model.normalize(config, preset)
  config.preset, config.enabled = id, true
  save(); reconcile(true); requestState()
  return true
end
local function savePersonalPreset(slot)
  if not model.validSlot(slot) then return false end
  personal[tostring(slot)] = model.profile(config)
  save(); requestState()
  return true
end
local function loadPersonalPreset(slot)
  if not model.validSlot(slot) or not personal[tostring(slot)] then return false end
  model.normalize(config, personal[tostring(slot)])
  config.preset, config.enabled = "personal" .. slot, true
  save(); reconcile(true); requestState()
  return true
end
local function deletePersonalPreset(slot)
  if not model.validSlot(slot) then return false end
  personal[tostring(slot)] = nil
  if config.preset == "personal" .. slot then config.preset = "custom" end
  save(); requestState()
  return true
end
local function onUpdate(dtReal, dtSim)
  local real = math.max(0, dtReal or 0)
  local dt = math.max(0, dtSim == nil and real or dtSim)
  clock, healthTimer, visualTimer = clock + dt, healthTimer + real, visualTimer + dt
  if healthTimer >= 1 then healthTimer = 0; reconcile(false); requestState() end
  if status ~= "raining" or not layers then return end
  if config.transition == 0 then currentIntensity = config.intensity else
    currentIntensity = currentIntensity + (config.intensity - currentIntensity) * (1 - math.exp(-dt * 3 / config.transition))
    if math.abs(config.intensity - currentIntensity) < 0.0005 then currentIntensity = config.intensity end
  end
  if visualTimer >= 0.1 then visualTimer = 0; reconcile(false) end
end
local function onExtensionLoaded()
  setExtensionUnloadMode(M, "manual")
  ui_pause_actions.registerModButton({
    id = tag,
    tabId = "mods",
    label = "BeamNg.weather",
    icon = "wrench",
    componentName = "/ui/ui-vue/mods/beamng_weather_hashk014/RainSettings.vue"
  })
  local data = jsonReadFile(configPath)
  model.normalize(config, data)
  if type(data) == "table" then
    if model.findPreset(data.preset) then config.preset = data.preset end
    if type(data.personalPresets) == "table" then
      for i = 1, 3 do
        local profile = data.personalPresets[tostring(i)]
        if type(profile) == "table" then
          local validated = model.defaults()
          model.normalize(validated, profile)
          personal[tostring(i)] = model.profile(validated)
          if data.preset == "personal" .. i then config.preset = data.preset end
        end
      end
    end
  end
  log("I", tag, "BeamNg.weather " .. model.version .. " loaded")
end
local function onClientEndMission()
  suspended = true
  clouds.release()
  cleanup(); currentIntensity, status, lastError = 0, "waiting", nil
  requestState()
end
M.getState, M.requestState, M.configure = getState, requestState, configure
M.applyPreset = applyPreset
M.savePersonalPreset, M.loadPersonalPreset, M.deletePersonalPreset = savePersonalPreset, loadPersonalPreset, deletePersonalPreset
M.setEnabled = function(value) configure({enabled = value}) end
M.setIntensity = function(value) configure({intensity = value}) end
M.onUpdate, M.onExtensionLoaded = onUpdate, onExtensionLoaded
M.onExtensionUnloaded = function()
  clouds.release()
  cleanup()
  ui_pause_actions.unregisterModButton(tag)
end
M.onClientStartMission = function() suspended = false; healthTimer = 0 end
M.onClientEndMission = onClientEndMission
M.onSerialize = function() clouds.release(); cleanup(); return {config = model.copy(config), personalPresets = personal} end
M.onDeserialized = function(data)
  if type(data) == "table" then
    model.normalize(config, data.config)
    if type(data.config) == "table" and type(data.config.preset) == "string" then config.preset = data.config.preset end
    if type(data.personalPresets) == "table" then personal = data.personalPresets end
  end
  suspended, healthTimer = false, 0
end
M.onModDeactivated = function(mod)
  if type(mod) == "table" and mod.modname == "beamng_weather_hashk014" then extensions.unload(tag) end
end
-- The Vue Lua signature registry contains only built-in game functions. The
-- page calls this explicit endpoint with the bridge's generic run() helper.
local uiCommands = {
  getState = getState, configure = configure, applyPreset = applyPreset,
  setEnabled = M.setEnabled, setIntensity = M.setIntensity,
  savePersonalPreset = savePersonalPreset, loadPersonalPreset = loadPersonalPreset,
  deletePersonalPreset = deletePersonalPreset
}
M.uiRequest = function(method, payload)
  local command = uiCommands[method]
  if not command then return {ok = false, error = "Unsupported rain controller command."} end
  local ok, result = pcall(command, payload)
  if not ok then
    log("E", tag, "UI request failed: " .. tostring(result))
    return {ok = false, error = "Rain controller error: " .. tostring(result)}
  end
  if result == false then return {ok = false, error = "The requested preset is unavailable."} end
  return {ok = true, state = getState()}
end
return M
