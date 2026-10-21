-- Native cloud coverage only. Keep per-object snapshots for reliable rollback.
local M = {}
local model = require("ge/extensions/beamngWeather/model")
local snapshots = {}
local mission
local state = {available = false, count = 0}
local function currentMission() return getMissionFilename() or "" end
local function alive(entry)
  return simObjectExists(entry.object) and scenetree.findObjectById(entry.id) ~= nil
end
local function differs(a, b) return a == nil or b == nil or math.abs(a - b) > 0.0001 end
function M.release()
  if mission == currentMission() then
    for _, entry in pairs(snapshots) do
      if alive(entry) then
        pcall(function()
          local current = tonumber(core_environment.getCloudCoverByID(entry.id))
          -- Preserve native edits made since our last write.
          if not differs(current, entry.applied) then core_environment.setCloudCoverByID(entry.id, entry.original) end
        end)
      end
    end
  end
  snapshots, mission = {}, nil
  state = {available = false, count = 0}
end
function M.update(config)
  local target = model.cloudTarget(config)
  if target == nil then M.release(); return end
  if mission ~= currentMission() then
    -- A previous scene may already be gone. Never restore its values into a new map.
    snapshots, mission = {}, currentMission()
  end
  if core_environment.canChange and not core_environment.canChange() then
    M.release()
    state.warning = "Cloud changes are locked by the current game mode."
    return
  end
  state = {available = false, count = 0, coverage = target}
  for _, name in ipairs(scenetree.findClassObjects("CloudLayer") or {}) do
    local object = scenetree.findObject(name)
    if object and simObjectExists(object) then
      local id = object:getID()
      local ok = pcall(function()
        local current = tonumber(core_environment.getCloudCoverByID(id))
        if not current then return end
        local entry = snapshots[id]
        if not entry or not simObjectExists(entry.object) then
          entry = {id = id, object = object, original = current}
          snapshots[id] = entry
        elseif entry.applied and differs(current, entry.applied) then
          entry.original = current
        end
        if differs(current, target) then core_environment.setCloudCoverByID(id, target) end
        entry.applied = tonumber(core_environment.getCloudCoverByID(id))
        state.count = state.count + 1
      end)
      if not ok then state.warning = "A cloud layer could not be updated. Rain remains available." end
    end
  end
  state.available = state.count > 0
  if not state.available and not state.warning then state.warning = "This map has no supported native cloud layer." end
end
function M.getState() return model.copy(state) end
return M
