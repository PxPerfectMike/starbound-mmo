-- Starbound MMO Market UI - WoW Auction House Style
-- Handles player identity, market listings, purchases, and listing creation

-- Constants
local LISTINGS_PER_PAGE = 8
local MY_LISTINGS_PER_PAGE = 6
local CACHE_REFRESH_INTERVAL = 2.0

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

-- Send command via the terminal object
local function sendViaTerminal(command)
  if not terminalEntityId then
    terminalEntityId = pane.sourceEntity()
  end

  if not terminalEntityId then
    sb.logWarn("[MMO Market] No terminal entity found")
    return false
  end

  local result = world.sendEntityMessage(terminalEntityId, "mmo_command", command)
  if result:finished() and result:succeeded() then
    return true
  end
  return true -- Assume async will work
end

function init()
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
    else
      sendPlayerJoinCommand()
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
    playerId = starboundId,
    timestamp = os.time(),
    data = {
      starboundId = starboundId,
      displayName = playerName
    }
  }

  sendViaTerminal(command)
end

function updateCurrencyDisplay()
  if playerState and playerState.currency then
    widget.setText("currencyLabel", "^#b89040;Balance:^reset; ^orange;" .. tostring(playerState.currency) .. "^reset; ^#b89040;CR^reset;")
  else
    widget.setText("currencyLabel", "^#b89040;Balance:^reset; ^orange;---^reset; ^#b89040;CR^reset;")
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
  if not playerState or not playerState.id then return end

  for _, listing in ipairs(allListings) do
    local sellerId = listing.sellerId or listing.seller_id
    if sellerId == playerState.id then
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
      widget.setText("myPrice" .. i, "^orange;" .. totalPrice .. " CR^reset;")
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
    widget.setText("totalPriceLabel", "Total: ^orange;" .. total .. " CR^reset;")
  else
    widget.setText("totalPriceLabel", "")
  end
end

function onPriceChanged()
  updateTotalPrice()
end

function createListing()
  if not playerState or not playerState.id then
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

  local durationOption = DURATION_OPTIONS[selectedDuration]

  local command = {
    id = generateId(),
    type = "market_create",
    playerId = playerState.id,
    timestamp = os.time(),
    data = {
      item = {
        name = selectedItem.name,
        count = selectedItem.count or 1,
        parameters = selectedItem.parameters or {}
      },
      pricePerUnit = pricePerUnit,
      durationSeconds = durationOption.seconds
    }
  }

  if sendViaTerminal(command) then
    -- Clear the swap slot and item slot
    player.setSwapSlotItem(nil)
    -- itemSlot removed
    widget.setText("createStatus", "^green;Auction created!^reset;")
    selectedItem = nil
    updateSelectedItemDisplay()
  else
    widget.setText("createStatus", "^red;Failed to create auction^reset;")
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
    playerId = playerState.id,
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

  if playerState and playerState.currency then
    local price = listing.totalPrice or listing.total_price or 0
    if playerState.currency < price then
      widget.setText("statusLabel", "^red;Insufficient funds!^reset;")
      return
    end
  end

  local command = {
    id = generateId(),
    type = "market_purchase",
    playerId = playerState.id,
    timestamp = os.time(),
    data = {
      listingId = listingId
    }
  }

  if sendViaTerminal(command) then
    widget.setText("statusLabel", "^yellow;Purchasing...^reset;")
    -- Optimistically remove from display
    removeFromAllListings(listingId)
    displayBrowseListings()
  else
    widget.setText("statusLabel", "^red;Not registered!^reset;")
  end
end

-- Close panel
function closePanel()
  pane.dismiss()
end
