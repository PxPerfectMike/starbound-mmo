-- Starbound MMO Bridge Utilities
-- Handles file-based communication with the external bridge service

local bridge = {}

-- Configuration
bridge.bridgeDir = "/mmo_bridge"
bridge.commandsDir = bridge.bridgeDir .. "/commands"
bridge.stateDir = bridge.bridgeDir .. "/state"
bridge.cacheDir = bridge.bridgeDir .. "/cache"

-- Generate a unique ID for commands
function bridge.generateId()
  return sb.makeUuid()
end

-- Get the current timestamp
function bridge.timestamp()
  return os.time()
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

  local filename = string.format("%s/%s_%s.json",
    bridge.commandsDir,
    commandType,
    command.id
  )

  local json = sb.printJson(command, 0)

  -- Write using root namespace (server-side)
  if root then
    -- Note: Starbound doesn't have native file write from Lua
    -- This would need to be handled via a custom interface or workaround
    sb.logInfo("[MMO Bridge] Would write command: %s", json)
  end

  return command.id
end

-- Read the player's state file
function bridge.readPlayerState(playerId)
  local filename = string.format("%s/player_%s.json", bridge.stateDir, playerId)

  -- In practice, we'd use player.getProperty or world.getProperty
  -- to store/retrieve state since direct file access isn't available
  local state = player.getProperty("mmo_state")

  if state then
    return state
  end

  return {
    id = playerId,
    displayName = world.entityName(player.id()) or "Unknown",
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
  -- Would read from cache file or player property
  return player.getProperty("mmo_market_cache") or {
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
