-- Starbound MMO Market UI
-- Handles player identity, market listings, and purchases

-- Fallback static listings if cache can't be read
local STATIC_LISTINGS = {
  { id = "static-1", itemName = "Refined Aegisalt", itemCount = 50, totalPrice = 1250, seller = { displayName = "SpaceCaptain" } },
  { id = "static-2", itemName = "Diamond", itemCount = 10, totalPrice = 5000, seller = { displayName = "SpaceCaptain" } },
  { id = "static-3", itemName = "Fuel Cell", itemCount = 100, totalPrice = 1500, seller = { displayName = "StarTrader" } },
  { id = "static-4", itemName = "Titanium Bar", itemCount = 200, totalPrice = 1600, seller = { displayName = "StarTrader" } },
  { id = "static-5", itemName = "Solarium Star", itemCount = 5, totalPrice = 5000, seller = { displayName = "NovaMiner" } },
  { id = "static-6", itemName = "Core Fragment", itemCount = 25, totalPrice = 1000, seller = { displayName = "NovaMiner" } }
}

-- State
local listings = {}
local playerState = nil
local starboundId = nil
local playerName = nil
local dataSource = "static"
local playerStateLoaded = false
local terminalEntityId = nil

-- Generate a simple unique ID
local function generateId()
  return tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
end

-- Send command via the terminal object that opened this pane
local function sendViaTerminal(command)
  -- Get the terminal entity that opened this ScriptPane
  if not terminalEntityId then
    terminalEntityId = pane.sourceEntity()
    if terminalEntityId then
      sb.logInfo("[MMO Market] Connected to terminal: " .. tostring(terminalEntityId))
    end
  end

  if not terminalEntityId then
    sb.logWarn("[MMO Market] No terminal entity found")
    return false
  end

  local result = world.sendEntityMessage(terminalEntityId, "mmo_command", command)
  if result:finished() then
    if result:succeeded() then
      sb.logInfo("[MMO Market] Command sent via terminal: " .. command.type)
      return true
    else
      sb.logWarn("[MMO Market] Terminal rejected command")
      return false
    end
  end

  -- Message is pending, assume it will work
  sb.logInfo("[MMO Market] Command sent (async): " .. command.type)
  return true
end

function init()
  local success, err = pcall(function()
    sb.logInfo("[MMO Market] Initializing...")

    -- Get player info
    starboundId = player.uniqueId()
    -- player.name() doesn't exist in ScriptPane, use world.entityName instead
    local playerId = player.id()
    playerName = world.entityName(playerId) or "Unknown"
    sb.logInfo("[MMO Market] Player: " .. playerName .. " (" .. starboundId .. ")")

    -- Load market listings
    listings = loadMarketCache()

    -- Try to load existing player state
    playerState = loadPlayerState()
    if playerState then
      playerStateLoaded = true
      sb.logInfo("[MMO Market] Loaded player state, currency: " .. tostring(playerState.currency))
    else
      -- Send player_join command to register/fetch player
      sendPlayerJoinCommand()
      sb.logInfo("[MMO Market] Sent player_join command")
    end

    -- Display UI
    displayListings()
    updateCurrencyDisplay()

    sb.logInfo("[MMO Market] Initialized with " .. tostring(#listings) .. " listings")
  end)

  if not success then
    sb.logError("[MMO Market] Init failed: " .. tostring(err))
    listings = STATIC_LISTINGS
    dataSource = "static"
    pcall(displayListings)
  end
end

function update(dt)
  -- Poll for player state updates if not yet loaded
  if not playerStateLoaded then
    local state = loadPlayerState()
    if state then
      playerState = state
      playerStateLoaded = true
      updateCurrencyDisplay()
      sb.logInfo("[MMO Market] Player state loaded via polling")
    end
  end
end

function loadMarketCache()
  local success, data = pcall(function()
    return root.assetJson("/cache/market.json")
  end)

  if success and data and type(data) == "table" and data.listings and #data.listings > 0 then
    dataSource = "cache"
    sb.logInfo("[MMO Market] Loaded " .. tostring(#data.listings) .. " listings from cache")
    return data.listings
  end

  sb.logInfo("[MMO Market] Using static listings")
  dataSource = "static"
  return STATIC_LISTINGS
end

function loadPlayerState()
  if not starboundId then return nil end

  local success, data = pcall(function()
    return root.assetJson("/cache/player_" .. starboundId .. ".json")
  end)

  if success and data and type(data) == "table" and data.currency then
    return data
  end

  return nil
end

function sendPlayerJoinCommand()
  if not starboundId or not playerName then return end

  local command = {
    id = generateId(),
    type = "player_join",
    playerId = starboundId,  -- Use starboundId as initial playerId
    timestamp = os.time(),
    data = {
      starboundId = starboundId,
      displayName = playerName
    }
  }

  writeCommand(command)
end

function sendPurchaseCommand(listingId)
  if not playerState or not playerState.id then
    sb.logWarn("[MMO Market] Cannot purchase: player not registered")
    return false
  end

  local command = {
    id = generateId(),
    type = "market_purchase",
    playerId = playerState.id,  -- Use database player ID
    timestamp = os.time(),
    data = {
      listingId = listingId
    }
  }

  writeCommand(command)
  return true
end

function writeCommand(command)
  sb.logInfo("[MMO Market] Sending command: " .. command.type)

  -- Send via the terminal object
  if sendViaTerminal(command) then
    sb.logInfo("[MMO Market] Command sent via terminal: " .. command.type .. " (id: " .. command.id .. ")")
    return true
  end

  -- Fallback: store in player properties (for future retry)
  sb.logWarn("[MMO Market] Terminal not available, queuing command locally")
  local pendingCommands = player.getProperty("mmo_pending_commands") or {}
  table.insert(pendingCommands, command)
  player.setProperty("mmo_pending_commands", pendingCommands)

  return false
end

function updateCurrencyDisplay()
  if playerState and playerState.currency then
    widget.setText("currencyLabel", "Balance: ^orange;" .. tostring(playerState.currency) .. " CR^reset;")
  else
    widget.setText("currencyLabel", "Balance: ^orange;---^reset;")
  end
end

function displayListings()
  -- Update status based on data source
  if dataSource == "cache" then
    widget.setText("statusLabel", "^green;" .. tostring(#listings) .. " listings^reset;")
  elseif dataSource == "static" then
    widget.setText("statusLabel", "^yellow;Offline mode^reset;")
  else
    widget.setText("statusLabel", "^red;No data^reset;")
  end

  -- Display each listing
  for i = 1, 6 do
    local labelName = "listing" .. i
    local buttonName = "buy" .. i

    if i <= #listings then
      local listing = listings[i]

      local itemName = listing.itemName or listing.item_name or "Unknown"
      local itemCount = listing.itemCount or listing.item_count or 1
      local totalPrice = listing.totalPrice or listing.total_price or 0
      local sellerName = "Unknown"

      if listing.seller then
        if type(listing.seller) == "table" then
          sellerName = listing.seller.displayName or listing.seller.display_name or "Unknown"
        else
          sellerName = tostring(listing.seller)
        end
      end

      local text = string.format("%s x%d - ^orange;%d CR^reset; (%s)",
        itemName, itemCount, totalPrice, sellerName)

      widget.setText(labelName, text)
      widget.setVisible(buttonName, true)
    else
      widget.setText(labelName, "")
      widget.setVisible(buttonName, false)
    end
  end
end

-- Buy button callbacks
function buyListing1() buyListing(1) end
function buyListing2() buyListing(2) end
function buyListing3() buyListing(3) end
function buyListing4() buyListing(4) end
function buyListing5() buyListing(5) end
function buyListing6() buyListing(6) end

function buyListing(index)
  sb.logInfo("[MMO Market] Buy button clicked for listing " .. tostring(index))

  if index > #listings then
    sb.logWarn("[MMO Market] Invalid listing index")
    return
  end

  local listing = listings[index]
  local listingId = listing.id

  if not listingId then
    sb.logWarn("[MMO Market] Listing has no ID")
    return
  end

  -- Check if player can afford it
  if playerState and playerState.currency then
    local price = listing.totalPrice or listing.total_price or 0
    if playerState.currency < price then
      sb.logInfo("[MMO Market] Insufficient funds: have " .. tostring(playerState.currency) .. ", need " .. tostring(price))
      widget.setText("statusLabel", "^red;Insufficient funds!^reset;")
      return
    end
  end

  -- Send purchase command
  if sendPurchaseCommand(listingId) then
    widget.setText("statusLabel", "^yellow;Purchasing...^reset;")
    sb.logInfo("[MMO Market] Purchase command sent for listing: " .. listingId)
  else
    widget.setText("statusLabel", "^red;Not registered!^reset;")
  end
end
