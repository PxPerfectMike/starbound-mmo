-- MMO Player Monitor
-- Runs as a genericScriptContext on every player.
-- Handles: MMO registration prompt, admin mode detection & lockout.

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
        sb.logInfo("[MMO Player] Character registered as MMO")
        player.radioMessage({
          messageId = "mmo_registered",
          unique = false,
          text = "^green;MMO character registered!^reset; Welcome to the MMO. Admin mode is now restricted on this character."
        })
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
