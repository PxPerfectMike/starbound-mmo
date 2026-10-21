-- Starbound MMO Market UI - WoW Auction House Style
-- Handles player identity, market listings, purchases, and listing creation

-- Constants
local LISTINGS_PER_PAGE = 8
local MY_LISTINGS_PER_PAGE = 6
local CACHE_REFRESH_INTERVAL = 2.0
local LISTING_FEE_PERCENT = 5  -- must match packages/shared/src/constants.ts

local DURATION_OPTIONS = {
  { label = "12h", seconds = 43200 },
  { label = "24h", seconds = 86400 },
  { label = "48h", seconds = 172800 },
  { label = "7d", seconds = 604800 }
}

-- State
local allListings = {}
local filteredListings = {}
local myListings = {}
local playerState = nil
local starboundId = nil
local playerName = nil
local dataSource = "static"
local playerStateLoaded = false
local terminalEntityId = nil

-- UI State
local currentTab = "browse"
local currentPage = 1
local searchQuery = ""
local selectedItem = nil
local selectedDuration = 2  -- Default to 24h
local cacheRefreshTimer = 0

-- Generate a simple unique ID
local function generateId()
  return tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
end

-- Helper to remove a listing from allListings by ID
local function removeFromAllListings(listingId)
  for i = #allListings, 1, -1 do
    if allListings[i].id == listingId then
      table.remove(allListings, i)
      break
    end
  end
  applySearchFilter()
end

-- In-flight entity messages. Each entry: { promise, onSuccess, onFailure }.
-- world.sendEntityMessage is asynchronous: the RpcPromise resolves on a later tick,
-- so results are checked in update() rather than immediately.
local pendingRpcs = {}

-- Send command via the terminal object. Returns true if the message was dispatched;
-- onSuccess / onFailure run once the terminal object acknowledges (or the RPC fails).
local function sendViaTerminal(command, onSuccess, onFailure)
  if not terminalEntityId then
    terminalEntityId = pane.sourceEntity()
  end

  if not terminalEntityId then
    sb.logWarn("[MMO Market] No terminal entity found")
    return false
  end

  local promise = world.sendEntityMessage(terminalEntityId, "mmo_command", command)
  table.insert(pendingRpcs, { promise = promise, onSuccess = onSuccess, onFailure = onFailure })
  return true
end

local function processPendingRpcs()
  for i = #pendingRpcs, 1, -1 do
    local entry = pendingRpcs[i]
    if entry.promise:finished() then
      table.remove(pendingRpcs, i)
      local result = entry.promise:succeeded() and entry.promise:result() or nil
      if entry.promise:succeeded() and type(result) == "table" and result.success then
        if entry.onSuccess then entry.onSuccess(result) end
      else
        local err = entry.promise:succeeded() and (result and result.error) or entry.promise:error()
        sb.logWarn("[MMO Market] Command failed: " .. tostring(err))
        if entry.onFailure then entry.onFailure(err) end
      end
    end
  end
end

function init()
  -- Admin guard: block all MMO features if admin mode is active
  if player.isAdmin() then
    sb.logWarn("[MMO Market] Admin mode detected - blocking access")
    widget.setText("statusLabel", "^red;Admin mode detected. Disable admin (/admin) to use the market.^reset;")
    return
  end

  local success, err = pcall(function()
    sb.logInfo("[MMO Market] Initializing...")

    starboundId = player.uniqueId()
    local playerId = player.id()
    playerName = world.entityName(playerId) or "Unknown"

    allListings = loadMarketCache()
    filteredListings = allListings

    playerState = loadPlayerState()
    if playerState then
      playerStateLoaded = true
    end

    switchToBrowse()
    updateCurrencyDisplay()
  end)

  if not success then
    sb.logError("[MMO Market] Init failed: " .. tostring(err))
    allListings = {}
    filteredListings = {}
    pcall(switchToBrowse)
  end
end

function update(dt)
  -- Admin guard: close pane if admin is toggled on while market is open
  if player.isAdmin() then
    sb.logWarn("[MMO Market] Admin mode toggled while market open - closing")
    pane.dismiss()
    return
  end

  processPendingRpcs()

  -- Check for player state if not loaded
  if not playerStateLoaded then
    local state = loadPlayerState()
    if state then
      playerState = state
      playerStateLoaded = true
      updateCurrencyDisplay()
      updateMyListings()
    end
  end

  -- Periodic cache refresh
  cacheRefreshTimer = cacheRefreshTimer + dt
  if cacheRefreshTimer >= CACHE_REFRESH_INTERVAL then
    cacheRefreshTimer = 0
    refreshMarketCache()
  end


end

function refreshMarketCache()
  local newListings = loadMarketCache()

  -- Check if listings changed (simple length check + content check)
  local changed = (#newListings ~= #allListings)

  if not changed and #newListings > 0 then
    -- Quick check: compare first and last listing IDs
    if newListings[1].id ~= allListings[1].id or
       newListings[#newListings].id ~= allListings[#allListings].id then
      changed = true
    end
  end

  if changed then
    allListings = newListings
    applySearchFilter()
    updateMyListings()

    if currentTab == "browse" then
      displayBrowseListings()
    elseif currentTab == "mylistings" then
      displayMyListings()
    end
  end
end

function loadMarketCache()
  -- root.assetJson() reads from the asset tree loaded at startup.
  -- Files written by the bridge at runtime won't be visible until restart.
  -- Market listings are maintained in-memory during the session and updated optimistically.
  local success, data = pcall(function()
    return root.assetJson("/cache/market.json")
  end)

  if success and data and type(data) == "table" and data.listings and #data.listings > 0 then
    dataSource = "cache"
    return data.listings
  end

  dataSource = "empty"
  return {}
end

function loadPlayerState()
  if not player.getProperty("mmo_character") then return nil end

  return {
    id = starboundId or player.uniqueId(),
    currency = player.getProperty("mmo_currency") or 0,
    displayName = playerName or "Unknown"
  }
end

function updateCurrencyDisplay()
  if playerState and playerState.currency then
    widget.setText("currencyLabel", "^#b89040;Balance:^reset; ^orange;" .. tostring(playerState.currency) .. "^reset; ^#b89040;Pixels^reset;")
  else
    widget.setText("currencyLabel", "^#b89040;Balance:^reset; ^orange;---^reset; ^#b89040;Pixels^reset;")
  end
end

-- Tab Switching
function switchToBrowse()
  currentTab = "browse"
  currentPage = 1

  showBrowsePanel(true)
  showMyListingsPanel(false)
  showCreatePanel(false)

  applySearchFilter()
  displayBrowseListings()
end

function switchToMyListings()
  currentTab = "mylistings"

  showBrowsePanel(false)
  showMyListingsPanel(true)
  showCreatePanel(false)

  updateMyListings()
  displayMyListings()
end

function switchToCreate()
  currentTab = "create"
  selectedItem = nil

  showBrowsePanel(false)
  showMyListingsPanel(false)
  showCreatePanel(true)

  updateSelectedItemDisplay()
  updateDurationDisplay()
end

function showBrowsePanel(visible)
  for i = 1, LISTINGS_PER_PAGE do
    widget.setVisible("listing" .. i, visible)
    widget.setVisible("seller" .. i, visible)
    widget.setVisible("price" .. i, visible)
    widget.setVisible("buy" .. i, visible)
  end
  widget.setVisible("colHeaderBg", visible)
  widget.setVisible("colItem", visible)
  widget.setVisible("colSeller", visible)
  widget.setVisible("colPrice", visible)
  widget.setVisible("searchLabel", visible)
  widget.setVisible("searchBg", visible)
  widget.setVisible("searchBox", visible)
  widget.setVisible("searchButton", visible)
  widget.setVisible("resetButton", visible)
  widget.setVisible("prevPage", visible)
  widget.setVisible("nextPage", visible)
  widget.setVisible("pageLabel", visible)
  widget.setVisible("statusLabel", visible)
end

function showMyListingsPanel(visible)
  for i = 1, MY_LISTINGS_PER_PAGE do
    widget.setVisible("myListing" .. i, visible)
    widget.setVisible("myPrice" .. i, visible)
    widget.setVisible("cancel" .. i, visible)
  end
  widget.setVisible("noListingsLabel", visible and #myListings == 0)
end

function showCreatePanel(visible)
  widget.setVisible("createInfoLabel", visible)
  widget.setVisible("selectedItemLabel", visible)
  widget.setVisible("priceLabel", visible)
  widget.setVisible("priceBg", visible)
  widget.setVisible("priceInput", visible)
  widget.setVisible("totalPriceLabel", visible)
  widget.setVisible("selectItemButton", visible)
  widget.setVisible("createButton", visible)
  widget.setVisible("createStatus", visible)
  widget.setVisible("durationLabel", visible)
  widget.setVisible("durationButton", visible)
  -- itemSlot removed
end

-- Search
function onSearchChanged()
  searchQuery = widget.getText("searchBox") or ""
  currentPage = 1
  applySearchFilter()
  displayBrowseListings()
end

function resetSearch()
  searchQuery = ""
  widget.setText("searchBox", "")
  currentPage = 1
  applySearchFilter()
  displayBrowseListings()
end

function applySearchFilter()
  if searchQuery == "" then
    filteredListings = allListings
  else
    filteredListings = {}
    local query = string.lower(searchQuery)
    for _, listing in ipairs(allListings) do
      local itemName = string.lower(listing.itemName or listing.item_name or "")
      if string.find(itemName, query, 1, true) then
        table.insert(filteredListings, listing)
      end
    end
  end
end

-- Browse Display
function displayBrowseListings()
  local totalPages = math.max(1, math.ceil(#filteredListings / LISTINGS_PER_PAGE))
  currentPage = math.min(currentPage, totalPages)

  widget.setText("pageLabel", "Page " .. currentPage .. "/" .. totalPages)

  if dataSource == "cache" then
    widget.setText("statusLabel", "^green;" .. tostring(#filteredListings) .. " listings^reset;")
  else
    widget.setText("statusLabel", "^yellow;No listings^reset;")
  end

  local startIndex = (currentPage - 1) * LISTINGS_PER_PAGE + 1

  for i = 1, LISTINGS_PER_PAGE do
    local listingIndex = startIndex + i - 1

    if listingIndex <= #filteredListings then
      local listing = filteredListings[listingIndex]
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

      -- Item column: name x count
      widget.setText("listing" .. i, itemName .. " ^gray;x" .. itemCount .. "^reset;")
      -- Seller column
      widget.setText("seller" .. i, "^cyan;" .. sellerName .. "^reset;")
      -- Price column
      widget.setText("price" .. i, "^orange;" .. totalPrice .. "^reset;")
      widget.setVisible("buy" .. i, true)
    else
      widget.setText("listing" .. i, "")
      widget.setText("seller" .. i, "")
      widget.setText("price" .. i, "")
      widget.setVisible("buy" .. i, false)
    end
  end
end

function prevPage()
  if currentPage > 1 then
    currentPage = currentPage - 1
    displayBrowseListings()
  end
end

function nextPage()
  local totalPages = math.max(1, math.ceil(#filteredListings / LISTINGS_PER_PAGE))
  if currentPage < totalPages then
    currentPage = currentPage + 1
    displayBrowseListings()
  end
end

-- My Listings
function updateMyListings()
  myListings = {}
  if not starboundId then return end

  -- listing.sellerId is the database UUID; the character UUID lives on seller.starboundId
  for _, listing in ipairs(allListings) do
    local sellerStarboundId = listing.sellerStarboundId
    if not sellerStarboundId and type(listing.seller) == "table" then
      sellerStarboundId = listing.seller.starboundId or listing.seller.starbound_id
    end
    if sellerStarboundId == starboundId then
      table.insert(myListings, listing)
    end
  end
end

function displayMyListings()
  widget.setVisible("noListingsLabel", #myListings == 0)

  for i = 1, MY_LISTINGS_PER_PAGE do
    if i <= #myListings then
      local listing = myListings[i]
      local itemName = listing.itemName or listing.item_name or "Unknown"
      local itemCount = listing.itemCount or listing.item_count or 1
      local totalPrice = listing.totalPrice or listing.total_price or 0

      widget.setText("myListing" .. i, itemName .. " ^gray;x" .. itemCount .. "^reset;")
      widget.setText("myPrice" .. i, "^orange;" .. totalPrice .. " Pixels^reset;")
      widget.setVisible("myListing" .. i, true)
      widget.setVisible("myPrice" .. i, true)
      widget.setVisible("cancel" .. i, true)
    else
      widget.setText("myListing" .. i, "")
      widget.setText("myPrice" .. i, "")
      widget.setVisible("myListing" .. i, false)
      widget.setVisible("myPrice" .. i, false)
      widget.setVisible("cancel" .. i, false)
    end
  end
end

-- Duration Selection
function cycleDuration()
  selectedDuration = selectedDuration + 1
  if selectedDuration > #DURATION_OPTIONS then
    selectedDuration = 1
  end
  updateDurationDisplay()
end

function updateDurationDisplay()
  local option = DURATION_OPTIONS[selectedDuration]
  widget.setText("durationButton", option.label)
end

-- Item Slot Changed (drag-drop)
function onItemSlotChanged()
  local slotItem = widget.itemSlotItem("itemSlot")
  if slotItem then
    selectedItem = slotItem
  else
    selectedItem = nil
  end
  updateSelectedItemDisplay()
end

-- Create Listing
function selectHeldItem()
  local swapItem = player.swapSlotItem()

  if swapItem then
    selectedItem = swapItem
    -- Also put it in the item slot visually
    -- itemSlot removed
    updateSelectedItemDisplay()
    widget.setText("createStatus", "")
  else
    widget.setText("createStatus", "^red;Hold an item first!^reset;")
  end
end

function updateSelectedItemDisplay()
  if selectedItem then
    local itemName = selectedItem.name or "Unknown"
    local itemCount = selectedItem.count or 1

    local displayName = itemName
    local success, config = pcall(function()
      return root.itemConfig(itemName)
    end)
    if success and config and config.config and config.config.shortdescription then
      displayName = config.config.shortdescription
    end

    widget.setText("selectedItemLabel", "Item: ^cyan;" .. displayName .. "^reset; ^gray;x" .. itemCount .. "^reset;")
  else
    widget.setText("selectedItemLabel", "Item: ^gray;None selected^reset;")
  end

  updateTotalPrice()
end

function updateTotalPrice()
  local priceText = widget.getText("priceInput") or ""
  local pricePerUnit = tonumber(priceText) or 0

  if selectedItem and pricePerUnit > 0 then
    local count = selectedItem.count or 1
    local total = pricePerUnit * count
    widget.setText("totalPriceLabel", "Total: ^orange;" .. total .. " Pixels^reset;")
  else
    widget.setText("totalPriceLabel", "")
  end
end

function onPriceChanged()
  updateTotalPrice()
end

function createListing()
  if not playerState then
    widget.setText("createStatus", "^red;Not registered!^reset;")
    return
  end

  if not selectedItem then
    widget.setText("createStatus", "^red;Select an item first!^reset;")
    return
  end

  local priceText = widget.getText("priceInput") or ""
  local pricePerUnit = tonumber(priceText)

  if not pricePerUnit or pricePerUnit <= 0 then
    widget.setText("createStatus", "^red;Enter a valid price!^reset;")
    return
  end

  -- Listing fee is charged server-side (LISTING_FEE_PERCENT in packages/shared).
  -- Pre-check locally so we never consume an item the server will reject.
  local totalPrice = pricePerUnit * (selectedItem.count or 1)
  local listingFee = math.floor(totalPrice * LISTING_FEE_PERCENT / 100)
  local balance = player.getProperty("mmo_currency") or 0
  if balance < listingFee then
    widget.setText("createStatus", "^red;Need " .. listingFee .. " pixels for the listing fee^reset;")
    return
  end

  local durationOption = DURATION_OPTIONS[selectedDuration]
  local itemDescriptor = {
    name = selectedItem.name,
    count = selectedItem.count or 1,
    parameters = selectedItem.parameters or {}
  }

  local command = {
    id = generateId(),
    type = "market_create",
    playerId = starboundId,
    timestamp = os.time(),
    data = {
      item = itemDescriptor,
      pricePerUnit = pricePerUnit,
      durationSeconds = durationOption.seconds,
      sellerName = playerName
    }
  }

  -- Escrow: save item to player properties before consuming. The property stays set
  -- until the terminal acknowledges the command. If the game crashes or the RPC fails,
  -- the item is restored (mmo_player.lua recovers it on next login after a crash).
  player.setProperty("mmo_escrowed_item", itemDescriptor)
  player.setSwapSlotItem(nil)

  local function restoreItem(reason)
    player.giveItem(itemDescriptor)
    player.setProperty("mmo_escrowed_item", nil)
    widget.setText("createStatus", "^red;Failed to create auction^reset; ^gray;(item returned)^reset;")
    sb.logWarn("[MMO Market] Listing not created, item returned: " .. tostring(reason))
  end

  local dispatched = sendViaTerminal(command,
    function()
      player.setProperty("mmo_escrowed_item", nil)
      widget.setText("createStatus", "^green;Auction created!^reset;")
    end,
    restoreItem)

  if dispatched then
    widget.setText("createStatus", "^yellow;Creating auction...^reset;")
    selectedItem = nil
    updateSelectedItemDisplay()
  else
    restoreItem("no terminal entity")
  end
end

-- Cancel Listing
function cancelListing1() cancelListing(1) end
function cancelListing2() cancelListing(2) end
function cancelListing3() cancelListing(3) end
function cancelListing4() cancelListing(4) end
function cancelListing5() cancelListing(5) end
function cancelListing6() cancelListing(6) end

function cancelListing(index)
  if index > #myListings then return end

  local listing = myListings[index]
  if not listing or not listing.id then return end

  local listingId = listing.id

  local command = {
    id = generateId(),
    type = "market_cancel",
    playerId = starboundId,
    timestamp = os.time(),
    data = {
      listingId = listingId
    }
  }

  if sendViaTerminal(command) then
    widget.setText("statusLabel", "^yellow;Cancelling...^reset;")
    -- Remove from myListings
    table.remove(myListings, index)
    -- Also remove from allListings so Browse tab updates
    removeFromAllListings(listingId)
    displayMyListings()
  end
end

-- Buy Listing
function buyListing1() buyListing(1) end
function buyListing2() buyListing(2) end
function buyListing3() buyListing(3) end
function buyListing4() buyListing(4) end
function buyListing5() buyListing(5) end
function buyListing6() buyListing(6) end
function buyListing7() buyListing(7) end
function buyListing8() buyListing(8) end

function buyListing(displayIndex)
  local startIndex = (currentPage - 1) * LISTINGS_PER_PAGE + 1
  local listingIndex = startIndex + displayIndex - 1

  if listingIndex > #filteredListings then return end

  local listing = filteredListings[listingIndex]
  local listingId = listing.id

  if not listingId then return end

  local price = listing.totalPrice or listing.total_price or 0
  local currentBalance = player.getProperty("mmo_currency") or 0

  if currentBalance < price then
    widget.setText("statusLabel", "^red;Insufficient funds!^reset;")
    return
  end

  local command = {
    id = generateId(),
    type = "market_purchase",
    playerId = starboundId,
    timestamp = os.time(),
    data = {
      listingId = listingId,
      buyerName = playerName
    }
  }

  local function refund(reason)
    -- Undo the optimistic deduction and put the listing back
    local balance = (player.getProperty("mmo_currency") or 0) + price
    player.setProperty("mmo_currency", balance)
    if playerState then playerState.currency = balance end
    updateCurrencyDisplay()
    table.insert(allListings, 1, listing)
    applySearchFilter()
    displayBrowseListings()
    widget.setText("statusLabel", "^red;Purchase failed^reset; ^gray;(pixels refunded)^reset;")
    sb.logWarn("[MMO Market] Purchase not sent, refunded: " .. tostring(reason))
  end

  local dispatched = sendViaTerminal(command,
    function()
      widget.setText("statusLabel", "^green;Purchase sent.^reset; ^gray;Item reaches your mailbox after the next game launch.^reset;")
    end,
    refund)

  if dispatched then
    -- Deduct currency optimistically; refunded if the terminal rejects the command
    local newBalance = currentBalance - price
    player.setProperty("mmo_currency", newBalance)
    if playerState then playerState.currency = newBalance end
    updateCurrencyDisplay()

    widget.setText("statusLabel", "^yellow;Purchasing...^reset;")
    removeFromAllListings(listingId)
    displayBrowseListings()
  else
    widget.setText("statusLabel", "^red;Failed to purchase!^reset;")
  end
end

-- Close panel
function closePanel()
  pane.dismiss()
end
