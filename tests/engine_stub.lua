-- Engine boundary only: this harness does not render rain or run BeamNG.
registry = {}
events = {}
logs = {}
savedConfig = nil
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
scenetree = {findObject = function(name) return registry[name] end}
function createObject(class)
  local obj = {class = class, children = {}}
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
end
function rainObjectCount()
  local count = 0
  for _, obj in pairs(registry) do if obj.class == "Precipitation" then count = count + 1 end end
  return count
end
startScene()
