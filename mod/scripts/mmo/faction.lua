-- Starbound MMO Faction System
-- Handles faction-related operations

require "/scripts/mmo/bridge.lua"

local faction = {}

-- Create a new faction
function faction.create(name, tag)
  local playerId = player.uniqueId()

  -- Validate name
  if #name < 3 or #name > 32 then
    return false, "Faction name must be 3-32 characters"
  end

  -- Validate tag
  if #tag < 2 or #tag > 5 then
    return false, "Faction tag must be 2-5 characters"
  end

  -- Check if uppercase alphanumeric
  if not string.match(tag, "^[A-Z0-9]+$") then
    return false, "Faction tag must be uppercase letters and numbers only"
  end

  -- Check if already in a faction
  local currentFaction = bridge.getFaction()
  if currentFaction.id then
    return false, "You must leave your current faction first"
  end

  -- Check creation cost (5000 credits)
  local creationCost = 5000
  local currency = bridge.getCurrency()
  if currency < creationCost then
    return false, string.format("Insufficient funds. Need %d Credits", creationCost)
  end

  -- Send command to bridge
  local commandId = bridge.sendCommand("faction_create", playerId, {
    name = name,
    tag = tag
  })

  sb.logInfo("[MMO Faction] Creating faction: %s [%s]", name, tag)

  return true, "Faction creation initiated"
end

-- Join a faction
function faction.join(factionId)
  local playerId = player.uniqueId()

  -- Check if already in a faction
  local currentFaction = bridge.getFaction()
  if currentFaction.id then
    return false, "You must leave your current faction first"
  end

  -- Send command to bridge
  local commandId = bridge.sendCommand("faction_join", playerId, {
    factionId = factionId
  })

  sb.logInfo("[MMO Faction] Requesting to join faction: %s", factionId)

  return true, "Join request sent"
end

-- Leave current faction
function faction.leave()
  local playerId = player.uniqueId()

  -- Check if in a faction
  local currentFaction = bridge.getFaction()
  if not currentFaction.id then
    return false, "You are not in a faction"
  end

  -- Send command to bridge
  local commandId = bridge.sendCommand("faction_leave", playerId, {})

  sb.logInfo("[MMO Faction] Leaving faction")

  return true, "Left faction"
end

-- Deposit currency to faction bank
function faction.deposit(amount)
  local playerId = player.uniqueId()

  -- Check if in a faction
  local currentFaction = bridge.getFaction()
  if not currentFaction.id then
    return false, "You are not in a faction"
  end

  -- Validate amount
  if amount <= 0 then
    return false, "Amount must be greater than 0"
  end

  -- Check if player has enough
  local currency = bridge.getCurrency()
  if currency < amount then
    return false, "Insufficient funds"
  end

  -- Send command to bridge
  local commandId = bridge.sendCommand("faction_deposit", playerId, {
    amount = amount
  })

  sb.logInfo("[MMO Faction] Depositing %d credits to faction bank", amount)

  return true, "Deposit initiated"
end

-- Get current faction info
function faction.getInfo()
  return bridge.getFaction()
end

-- Check if player is in a faction
function faction.hasFaction()
  local info = faction.getInfo()
  return info.id ~= nil
end

return faction
