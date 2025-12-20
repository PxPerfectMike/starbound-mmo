-- Starbound MMO Initialization Script
-- Runs when a player joins the server

require "/scripts/mmo/bridge.lua"

local mmoInit = {}

function mmoInit.init()
  -- Check if this is first join
  local initialized = player.getProperty("mmo_initialized")

  if not initialized then
    mmoInit.firstTimeSetup()
  else
    mmoInit.returningPlayer()
  end

  -- Set up periodic state sync
  mmoInit.startStateSync()
end

function mmoInit.firstTimeSetup()
  sb.logInfo("[MMO] First time player setup")

  local playerId = player.uniqueId()
  local displayName = world.entityName(player.id()) or "Traveler"

  -- Send join command to bridge
  bridge.sendCommand("player_join", playerId, {
    starboundId = playerId,
    displayName = displayName
  })

  -- Mark as initialized
  player.setProperty("mmo_initialized", true)
  player.setProperty("mmo_first_join", os.time())

  -- Show welcome message
  player.radioMessage({
    messageId = "mmo_welcome",
    unique = true,
    text = {
      "Welcome to Starbound MMO!",
      "Visit the Hub Station to access the market, factions, and more."
    }
  })
end

function mmoInit.returningPlayer()
  sb.logInfo("[MMO] Returning player detected")

  local playerId = player.uniqueId()
  local displayName = world.entityName(player.id()) or "Traveler"

  -- Send join command to bridge
  bridge.sendCommand("player_join", playerId, {
    starboundId = playerId,
    displayName = displayName
  })

  -- Check for pending items
  local pending = bridge.getPendingItems()
  if #pending > 0 then
    player.radioMessage({
      messageId = "mmo_pending_items",
      unique = true,
      text = string.format("You have %d item(s) waiting to be claimed at a Market Terminal!", #pending)
    })
  end

  -- Check for notifications
  local notifications = bridge.getNotifications()
  if #notifications > 0 then
    player.radioMessage({
      messageId = "mmo_notifications",
      unique = true,
      text = string.format("You have %d new notification(s)!", #notifications)
    })
  end
end

function mmoInit.startStateSync()
  -- Poll for state updates periodically
  -- In practice, this would be done via a tech or status effect
  sb.logInfo("[MMO] State sync started")
end

function mmoInit.onDisconnect()
  local playerId = player.uniqueId()

  -- Send leave command
  bridge.sendCommand("player_leave", playerId, {})
end

return mmoInit
