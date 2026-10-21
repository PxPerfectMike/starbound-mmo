-- MMO Player Monitor
-- Runs as a genericScriptContext on every player.
-- Handles: MMO registration prompt, admin mode detection & lockout, login sync.

require "/scripts/util.lua"

local CHECK_INTERVAL = 0.5  -- Check admin every 0.5 seconds
local CINEMATIC_INTERVAL = 4.0  -- Re-trigger cinematic every 4 seconds while admin is on
local EFFECT_REAPPLY = 3.0  -- Re-apply movement block every 3 seconds
local ADMIN_BLOCK_CINEMATIC = "/cinematics/mmo/adminblock.cinematic"

local checkTimer = 0
local cinematicTimer = 0
local effectTimer = 0
local registrationShown = false
local registrationPending = nil

function init()
  sb.logInfo("[MMO Player] Monitor script initialized")

  -- Message handler so objects can query MMO status
  message.setHandler("mmo_isRegistered", function(_, _)
    return player.getProperty("mmo_character") == true
  end)

  message.setHandler("mmo_isAdminFlagged", function(_, _)
    return player.getProperty("mmo_admin_flagged") == true
  end)

  -- Clear stale admin flag from previous session
  -- Admin mode resets on relog, so clear the flag if admin is off
  if player.getProperty("mmo_admin_flagged") then
    if not player.isAdmin() then
      player.setProperty("mmo_admin_flagged", false)
      sb.logInfo("[MMO Player] Cleared stale admin flag from previous session")
    end
  end

  -- Recover escrowed items from failed market listing creation
  local escrowedItem = player.getProperty("mmo_escrowed_item")
  if escrowedItem then
    player.giveItem(escrowedItem)
    player.setProperty("mmo_escrowed_item", nil)
    sb.logInfo("[MMO Player] Recovered escrowed item: " .. tostring(escrowedItem.name))
    player.radioMessage({
      messageId = "mmo_item_recovered",
      unique = false,
      text = "^yellow;Recovered item:^reset; " .. tostring(escrowedItem.name) .. " ^gray;(market listing may not have been created)^reset;"
    })
  end

  -- MMO login sync: only for registered MMO characters
  if player.getProperty("mmo_character") then
    syncFromServerCache()
    sendPlayerJoinCommand()
  end
end

-- Read server cache from previous session and sync properties
function syncFromServerCache()
  local uniqueId = player.uniqueId()
  local cachePath = "/cache/player_" .. uniqueId .. ".json"

  local success, data = pcall(function()
    return root.assetJson(cachePath)
  end)

  if success and data and type(data) == "table" then
    sb.logInfo("[MMO Player] Found server cache - syncing state")

    -- Sync currency if server has a value
    if data.currency ~= nil then
      local localCurrency = player.getProperty("mmo_currency") or 0
      if data.currency ~= localCurrency then
        sb.logInfo("[MMO Player] Syncing currency: local=" .. tostring(localCurrency) .. " server=" .. tostring(data.currency))
        player.setProperty("mmo_currency", data.currency)
      end
    end

    -- Sync pending items if server has them
    if data.pendingItems ~= nil then
      local localPending = player.getProperty("mmo_pending_items") or {}
      if #data.pendingItems ~= #localPending then
        sb.logInfo("[MMO Player] Syncing pending items: local=" .. tostring(#localPending) .. " server=" .. tostring(#data.pendingItems))
        player.setProperty("mmo_pending_items", data.pendingItems)
      end
    end
  else
    sb.logInfo("[MMO Player] No server cache found (first login or cache not yet written)")
  end
end

-- Send player_join command via Starbound log so bridge picks it up
function sendPlayerJoinCommand()
  local uniqueId = player.uniqueId()
  local playerId = player.id()
  local displayName = world.entityName(playerId) or "Unknown"

  local command = {
    id = tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999)),
    type = "player_join",
    playerId = uniqueId,
    timestamp = os.time(),
    data = {
      displayName = displayName
    }
  }

  -- Encode as JSON and log so the bridge log watcher can pick it up
  local json = sb.printJson(command)
  sb.logInfo("[MMO_CMD]" .. json)
  sb.logInfo("[MMO Player] Sent player_join command for " .. displayName)
end

function update(dt)
  checkTimer = checkTimer + dt

  -- Handle pending registration dialog
  if registrationPending then
    if registrationPending:finished() then
      local accepted = registrationPending:result()
      registrationPending = nil

      if accepted then
        player.setProperty("mmo_character", true)
        player.setProperty("mmo_registered", true)
        player.setProperty("mmo_registered_at", os.time())
        player.setProperty("mmo_currency", 1000)
        player.setProperty("mmo_pending_items", {})
        sb.logInfo("[MMO Player] Character registered as MMO")
        player.radioMessage({
          messageId = "mmo_registered",
          unique = false,
          text = "^green;MMO character registered!^reset; Welcome to the MMO. Admin mode is now restricted on this character."
        })

        -- Send player_join immediately after registration
        sendPlayerJoinCommand()
      else
        player.setProperty("mmo_character", false)
        player.setProperty("mmo_registered", true)
        sb.logInfo("[MMO Player] Character declined MMO registration")
      end
    end
    return
  end

  -- Show registration prompt once per character (on first load)
  if not registrationShown then
    registrationShown = true
    local registered = player.getProperty("mmo_registered")
    if not registered then
      checkTimer = -2.0  -- Give 2 seconds before showing
    end
  end

  -- Show registration dialog after initial delay
  if not player.getProperty("mmo_registered") and checkTimer >= 0 and not registrationPending then
    showRegistrationDialog()
    return
  end

  -- Only monitor admin for MMO characters
  if not player.getProperty("mmo_character") then
    return
  end

  if checkTimer >= CHECK_INTERVAL then
    checkTimer = 0
    checkAdminMode()
  end

  -- While admin is flagged AND still on, maintain the lockdown
  if player.getProperty("mmo_admin_flagged") and player.isAdmin() then
    cinematicTimer = cinematicTimer + dt
    if cinematicTimer >= CINEMATIC_INTERVAL then
      cinematicTimer = 0
      player.playCinematic(ADMIN_BLOCK_CINEMATIC, true)
    end

    effectTimer = effectTimer + dt
    if effectTimer >= EFFECT_REAPPLY then
      effectTimer = 0
      applyAdminBlock()
    end
  end
end

function showRegistrationDialog()
  sb.logInfo("[MMO Player] Showing registration dialog")
  registrationPending = player.confirm({
    paneLayout = "/interface/windowconfig/simpleconfirmation.config:paneLayout",
    message = "^orange;=== Starbound MMO ===^reset;\n\nRegister this character for MMO mode?\n\n^cyan;MMO characters:^reset;\n- Access the MMO Hub, Market, and Mailbox\n- Cannot use admin mode (/admin)\n- Have a server-tracked pixel balance\n- Start with 1000 pixels\n\n^gray;This choice is permanent for this character.\nNon-MMO characters cannot access MMO features.^reset;",
    okCaption = "Register as MMO",
    cancelCaption = "No Thanks"
  })
end

function applyAdminBlock()
  -- Apply via the vanilla applyStatusEffect message handler in player_primary.lua
  -- Short duration (5 seconds) - we keep re-applying while admin is on
  -- When admin turns off, it naturally expires within 5 seconds
  world.sendEntityMessage(player.id(), "applyStatusEffect", "mmo_adminblock", 5)
end

function checkAdminMode()
  local isAdmin = player.isAdmin()
  local wasFlagged = player.getProperty("mmo_admin_flagged")

  if isAdmin and not wasFlagged then
    -- Admin just turned on - LOCK THEM DOWN
    sb.logInfo("[MMO Player] ADMIN MODE DETECTED on MMO character! Locking down.")
    player.setProperty("mmo_admin_flagged", true)
    player.setProperty("mmo_admin_flagged_at", os.time())

    -- 1) Play black screen cinematic
    player.playCinematic(ADMIN_BLOCK_CINEMATIC, true)
    cinematicTimer = 0

    -- 2) Warp to ship
    player.warp("ownship")

    -- 3) Apply movement suppression (5 second duration, re-applied every 3s)
    applyAdminBlock()
    effectTimer = 0

  elseif not isAdmin and wasFlagged then
    -- Admin turned off - unlock them
    sb.logInfo("[MMO Player] Admin mode disabled. Unlocking MMO character.")
    player.setProperty("mmo_admin_flagged", false)
    -- The status effect will naturally expire within 5 seconds

    player.radioMessage({
      messageId = "mmo_admin_cleared",
      unique = false,
      text = "^green;Admin mode disabled.^reset; MMO features restored."
    })
  end
end

function uninit()
end
