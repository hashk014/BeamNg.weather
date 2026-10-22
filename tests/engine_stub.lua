-- Engine boundary only: this harness does not render rain or run BeamNG.
registry = {}
events = {}
logs = {}
savedConfig = nil
pauseButtons = {}
ui_pause_actions = {
  registerModButton = function(button) pauseButtons[button.id] = button; return {success=true} end,
  unregisterModButton = function(id) pauseButtons[id] = nil; return {success=true} end
}
mission = "levels/gridmap_v2/main.level.json"
failLayer = nil
failDatablocks = false
cameraPosition = {x = 15, y = 20, z = 3}
function log(level, tag, message) table.insert(logs, {level, tag, message}) end
function setExtensionUnloadMode() end
function getMissionFilename() return mission end
function simObjectExists(obj) return obj and obj.registered and not obj.deleted end
function jsonReadFile() return savedConfig end
function loadJsonMaterialsFile(path)
  assert(path == "art/beamng_weather_hashk014/rain.datablocks.json")
  if failDatablocks then return end
  for name, data in pairs(testDatablocks) do registry[name] = data end
end
function jsonWriteFile(path, data)
  savedConfig = {}
  for k, v in pairs(data) do savedConfig[k] = v end
  return true
end
guihooks = {trigger = function(name, data) table.insert(events, {name, data}) end}
core_camera = {getPosition = function() return cameraPosition end}
extensions = {unload = function(name) unloaded = name; extension.onExtensionUnloaded() end}
local nextID = 0
scenetree = {
  findObject = function(name) return registry[name] end,
  findObjectById = function(id)
    for _, object in pairs(registry) do if object.id == id then return object end end
  end,
  findClassObjects = function(class)
    local names = {}
    for name, object in pairs(registry) do if object.class == class then table.insert(names, name) end end
    return names
  end
}
cloudChangesAllowed = true
core_environment = {
  canChange = function() return cloudChangesAllowed end,
  getCloudCoverByID = function(id) return scenetree.findObjectById(id).coverage end,
  setCloudCoverByID = function(id, value)
    local object = scenetree.findObjectById(id)
    object.coverage = value
    object:postApply()
  end
}
function createObject(class)
  nextID = nextID + 1
  local obj = {class = class, children = {}, id = nextID}
  if class == "Precipitation" then
    local fadeFields={}
    setmetatable(obj,{
      __index=function(_,key) return fadeFields[key] end,
      __newindex=function(t,key,value)
        if key=="fadeDist" or key=="fadeDistEnd" then fadeFields[key]=math.max(0,value)
        else rawset(t,key,value) end
      end
    })
  end
  function obj:getID() return self.id end
  function obj:getClassName() return self.class end
  function obj:setHidden(value) self.hidden = value end
  function obj:postApply() self.applies = (self.applies or 0) + 1 end
  function obj:setField(key, index, value) self[key] = value end
  function obj:registerObject(name)
    if self.class == "Precipitation" then
      assert(registry[self.dataBlock], "Datablock required before registration")
      assert(registry[registry[self.dataBlock].dropShader], "Shader required before precipitation")
    end
    if failLayer and name:find(failLayer, 1, true) then error("Injected registration failure") end
    assert(not registry[name], "Duplicate scene name")
    self.name = name
    self.registered = true
    registry[name] = self
  end
  function obj:addObject(child) table.insert(self.children, child) end
  function obj:setPosition(position) self.position = position end
  function obj:delete()
    for _, child in ipairs(self.children) do child:delete() end
    if self.name then registry[self.name] = nil end
    self.deleted = true
  end
  return obj
end
function startScene()
  scenetree.MissionGroup = createObject("SimGroup")
  scenetree.MissionGroup:registerObject("MissionGroup")
  registry.rain_drop = {class = "PrecipitationData"}
  registry.rain_medium = {class = "PrecipitationData"}
  registry.mapRain = {numDrops = 7}
  local cloud = createObject("CloudLayer")
  cloud.coverage, cloud.windSpeed = 0.2, 4
  cloud:registerObject("mapClouds")
end
function rainObjectCount()
  local count = 0
  for _, obj in pairs(registry) do if obj.class == "Precipitation" then count = count + 1 end end
  return count
end
startScene()
