-- Starbound MMO Bridge Utilities
-- Handles file-based communication with the external bridge service
-- Note: File I/O only works in universe server scripts

local bridge = {}

-- Configuration - path relative to Starbound storage directory
-- On Windows: C:\Program Files (x86)\Steam\steamapps\common\Starbound\storage\mmo_bridge
-- On Linux: ~/.steam/steam/steamapps/common/Starbound/storage/mmo_bridge
bridge.bridgeDir = "mmo_bridge"

-- Try to get storage path from root if available
bridge.storagePath = nil
if root and root.assetSourcePath then
  -- Get the Starbound storage directory
  local assetPath = root.assetSourcePath()
  if assetPath then
    bridge.storagePath = assetPath:gsub("/assets", "/storage")
  end
end

-- Fallback paths for different OS
bridge.fallbackPaths = {
  "C:/Program Files (x86)/Steam/steamapps/common/Starbound/storage/mmo_bridge",
  "C:/Program Files/Steam/steamapps/common/Starbound/storage/mmo_bridge",
  "/home/" .. (os.getenv("USER") or "user") .. "/.steam/steam/steamapps/common/Starbound/storage/mmo_bridge",
  "../storage/mmo_bridge",
  "storage/mmo_bridge"
}

-- Generate a unique ID for commands
function bridge.generateId()
  if sb and sb.makeUuid then
    return sb.makeUuid()
  end
  -- Fallback UUID generation
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)
end

-- Get the current timestamp
function bridge.timestamp()
  return os.time()
end

-- Find the bridge directory path
function bridge.getBridgePath()
  if bridge.storagePath then
    return bridge.storagePath .. "/" .. bridge.bridgeDir
  end

  -- Try fallback paths
  for _, path in ipairs(bridge.fallbackPaths) do
    local testFile = io.open(path .. "/commands/.keep", "r")
    if testFile then
      testFile:close()
      return path
    end
  end

  -- Return first fallback as default
  return bridge.fallbackPaths[1]
end

-- Write a command file for the bridge service to process
function bridge.sendCommand(commandType, playerId, data)
  local command = {
    id = bridge.generateId(),
    type = commandType,
    playerId = playerId,
    timestamp = bridge.timestamp(),
    data = data or {}
  }

  local basePath = bridge.getBridgePath()
  local filename = string.format("%s/commands/%s_%s.json",
    basePath,
    commandType,
    command.id
  )

  local json
  if sb and sb.printJson then
    json = sb.printJson(command, 0)
  else
    -- Simple JSON serialization fallback
    json = bridge.toJson(command)
  end

  -- Try to write file using io library
  local file, err = io.open(filename, "w")
  if file then
    file:write(json)
    file:close()
    if sb then sb.logInfo("[MMO Bridge] Wrote command: %s", commandType) end
    return command.id
  else
    if sb then sb.logError("[MMO Bridge] Failed to write command: %s", err or "unknown error") end
    return nil
  end
end

-- Simple JSON serialization (fallback when sb.printJson not available)
function bridge.toJson(obj, indent)
  indent = indent or 0
  local t = type(obj)

  if t == "nil" then
    return "null"
  elseif t == "boolean" then
    return tostring(obj)
  elseif t == "number" then
    return tostring(obj)
  elseif t == "string" then
    return string.format('"%s"', obj:gsub('"', '\\"'):gsub('\n', '\\n'))
  elseif t == "table" then
    -- Check if array
    local isArray = #obj > 0 or next(obj) == nil
    for k, _ in pairs(obj) do
      if type(k) ~= "number" then
        isArray = false
        break
      end
    end

    local parts = {}
    if isArray then
      for _, v in ipairs(obj) do
        table.insert(parts, bridge.toJson(v, indent))
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      for k, v in pairs(obj) do
        table.insert(parts, string.format('"%s":%s', k, bridge.toJson(v, indent)))
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end

  return "null"
end

-- Parse JSON string to table
function bridge.parseJson(str)
  if sb and sb.parseJson then
    return sb.parseJson(str)
  end
  -- Fallback: use load (unsafe but works for trusted input)
  local jsonToLua = str:gsub('null', 'nil'):gsub('%[', '{'):gsub('%]', '}'):gsub('"([^"]+)":', '["%1"]=')
  local fn, err = load("return " .. jsonToLua)
  if fn then return fn() end
  return nil
end

-- Read the player's state file
function bridge.readPlayerState(playerId)
  local basePath = bridge.getBridgePath()
  local filename = string.format("%s/state/player_%s.json", basePath, playerId)

  -- Try to read from file first (works in universe scripts)
  local file = io.open(filename, "r")
  if file then
    local content = file:read("*all")
    file:close()
    local state = bridge.parseJson(content)
    if state then
      -- Also cache in player property for faster access
      if player and player.setProperty then
        player.setProperty("mmo_state", state)
      end
      return state
    end
  end

  -- Fallback to player property (works in client scripts)
  if player and player.getProperty then
    local state = player.getProperty("mmo_state")
    if state then return state end
  end

  -- Default state
  local displayName = "Unknown"
  if world and player then
    displayName = world.entityName(player.id()) or "Unknown"
  end

  return {
    id = playerId,
    displayName = displayName,
    currency = 0,
    factionId = nil,
    factionTag = nil,
    pendingItems = {},
    notifications = {}
  }
end

-- Save player state to property (will be synced by bridge)
function bridge.savePlayerState(state)
  player.setProperty("mmo_state", state)
end

-- Read cached market listings
function bridge.readMarketCache()
  local basePath = bridge.getBridgePath()
  local filename = basePath .. "/cache/market.json"

  -- Try to read from file
  local file = io.open(filename, "r")
  if file then
    local content = file:read("*all")
    file:close()
    local cache = bridge.parseJson(content)
    if cache then
      -- Cache in player property
      if player and player.setProperty then
        player.setProperty("mmo_market_cache", cache)
      end
      return cache
    end
  end

  -- Fallback to player property
  if player and player.getProperty then
    local cache = player.getProperty("mmo_market_cache")
    if cache then return cache end
  end

  return {
    updatedAt = nil,
    listings = {}
  }
end

-- Get player's MMO currency
function bridge.getCurrency()
  local state = bridge.readPlayerState(player.id())
  return state.currency or 0
end

-- Get player's faction info
function bridge.getFaction()
  local state = bridge.readPlayerState(player.id())
  return {
    id = state.factionId,
    tag = state.factionTag
  }
end

-- Get pending items (items waiting to be claimed)
function bridge.getPendingItems()
  local state = bridge.readPlayerState(player.id())
  return state.pendingItems or {}
end

-- Get notifications
function bridge.getNotifications()
  local state = bridge.readPlayerState(player.id())
  return state.notifications or {}
end

-- Clear a notification
function bridge.clearNotification(notificationId)
  local state = bridge.readPlayerState(player.id())
  local newNotifications = {}

  for _, notif in ipairs(state.notifications or {}) do
    if notif.id ~= notificationId then
      table.insert(newNotifications, notif)
    end
  end

  state.notifications = newNotifications
  bridge.savePlayerState(state)
end

-- Claim a pending item
function bridge.claimPendingItem(itemId)
  local state = bridge.readPlayerState(player.id())
  local newPending = {}
  local claimedItem = nil

  for _, item in ipairs(state.pendingItems or {}) do
    if item.id == itemId then
      claimedItem = item
    else
      table.insert(newPending, item)
    end
  end

  if claimedItem then
    -- Give item to player
    player.giveItem({
      name = claimedItem.itemName,
      count = claimedItem.itemCount,
      parameters = claimedItem.itemParams or {}
    })

    state.pendingItems = newPending
    bridge.savePlayerState(state)

    return true
  end

  return false
end

return bridge
