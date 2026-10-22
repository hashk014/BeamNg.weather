-- Visual settings only; this module never changes vehicle or world physics.
local M = {}
M.version = "0.5.3"
-- BeamNG 0.40's native environment panel uses 0..3, not 0..1.
M.cloudCoverageMax = 3
M.budgets = {low = 2400, medium = 6000, high = 12000, ultra = 20000}
M.ranges = {
  intensity = {0, 1, 0.65}, dropScale = {0.5, 2, 1}, fallSpeed = {0.4, 1.8, 1},
  turbulence = {0, 1, 0.12}, variability = {0, 0.6, 0.16},
  volume = {0.65, 1.6, 1}, contrast = {0.35, 1.5, 0.9}, transition = {0, 5, 1.5},
  cloudCoverage = {0, 1, 0.85}, glassAmount = {0, 2, 1}, glassScale = {0.5, 2, 1}
}
local booleans = {enabled = true, collisions = true, wind = true, lighting = true, cabinProtection = true, glassDrops = true}
local profileFields = {"intensity", "dropScale", "fallSpeed", "turbulence", "variability", "volume", "contrast", "wind", "lighting", "cloudMode", "cloudCoverage", "glassAmount", "glassScale", "glassDrops", "cabinProtection"}
M.presets = {
  {id = "drizzle", name = "Drizzle", description = "Fine droplets with a gentle fall", intensity = 0.26, dropScale = 0.65, fallSpeed = 0.65, turbulence = 0.08, variability = 0.09, contrast = 0.65, volume = 0.85, wind = true, lighting = true},
  {id = "gentle", name = "Light rain", description = "Steady, subtle rainfall", intensity = 0.46, dropScale = 0.85, fallSpeed = 0.85, turbulence = 0.08, variability = 0.12, contrast = 0.8, volume = 1, wind = true, lighting = true},
  {id = "shower", name = "Shower", description = "Defined droplets with changing density", intensity = 0.72, dropScale = 1, fallSpeed = 1.05, turbulence = 0.15, variability = 0.2, contrast = 0.95, volume = 1, wind = true, lighting = true},
  {id = "downpour", name = "Downpour", description = "Dense, sustained rainfall", intensity = 1, dropScale = 1.22, fallSpeed = 1.2, turbulence = 0.2, variability = 0.13, contrast = 1, volume = 1.1, wind = true, lighting = true},
  {id = "squall", name = "Squall", description = "An uneven, turbulent rain shower", intensity = 0.85, dropScale = 1.1, fallSpeed = 1.15, turbulence = 0.52, variability = 0.42, contrast = 0.9, volume = 1.15, wind = true, lighting = true}
}
function M.copy(data)
  local result = {}
  for k, v in pairs(data) do result[k] = v end
  return result
end
function M.defaults()
  local result = {schemaVersion = 4, quality = "medium", preset = "custom", cloudMode = "auto"}
  for k, spec in pairs(M.ranges) do result[k] = spec[3] end
  for k, v in pairs(booleans) do result[k] = v end
  return result
end
function M.normalize(config, data)
  if type(data) ~= "table" then return end
  for k, spec in pairs(M.ranges) do
    local value = tonumber(data[k])
    if value and value == value and value ~= math.huge and value ~= -math.huge then
      config[k] = math.max(spec[1], math.min(spec[2], value))
    end
  end
  for k in pairs(booleans) do if type(data[k]) == "boolean" then config[k] = data[k] end end
  if M.budgets[data.quality] then config.quality = data.quality end
  if data.cloudMode == "auto" or data.cloudMode == "manual" or data.cloudMode == "map" then config.cloudMode = data.cloudMode end
end
function M.profile(config)
  local result = {}
  for _, k in ipairs(profileFields) do result[k] = config[k] end
  return result
end
function M.findPreset(id)
  for _, profile in ipairs(M.presets) do if profile.id == id then return profile end end
end
function M.validSlot(slot)
  return type(slot) == "number" and slot == math.floor(slot) and slot >= 1 and slot <= 3
end
function M.modulation(time, amount)
  local wave = 0.55 * math.sin(time * 0.31) + 0.3 * math.sin(time * 0.73 + 1.1) + 0.15 * math.sin(time * 1.37 + 2.4)
  return 1 + amount * wave
end
function M.counts(config, intensity, time)
  local total = math.floor(M.budgets[config.quality] * math.max(0, math.min(1, intensity * M.modulation(time, config.variability))))
  local fine, body = math.floor(total * 0.3), math.floor(total * 0.5)
  return {fine, body, total - fine - body}, total
end
function M.cloudTarget(config)
  if not config.enabled or config.intensity <= 0 or config.cloudMode == "map" then return nil end
  if config.cloudMode == "manual" then return config.cloudCoverage * M.cloudCoverageMax end
  return (0.8 + 0.2 * config.intensity) * M.cloudCoverageMax
end
return M
