require "/scripts/mmo/bridge.lua"
require "/scripts/mmo/market.lua"

local currentTab = 0
local listings = {}
local myListings = {}
local pendingItems = {}
local selectedListing = nil
local refreshTimer = 0
local REFRESH_INTERVAL = 5 -- seconds

function init()
  -- Update currency display
  updateCurrencyDisplay()

  -- Load initial data
  refreshData()

  -- Set initial tab
  switchTab(0)
end

function update(dt)
  refreshTimer = refreshTimer + dt

  if refreshTimer >= REFRESH_INTERVAL then
    refreshTimer = 0
    refreshData()
  end
end

function refreshData()
  -- Get listings from cache
  listings = market.getListings()
  myListings = market.getMyListings()
  pendingItems = bridge.getPendingItems()

  -- Update display based on current tab
  switchTab(currentTab)
  updateCurrencyDisplay()
end

function updateCurrencyDisplay()
  local currency = bridge.getCurrency()
  widget.setText("currencyLabel", string.format("Balance: ^orange;%d CR^reset;", currency))
end

function switchTab(tabId)
  currentTab = tabId

  widget.clearListItems("listingsScrollArea.listingsList")

  if tabId == 0 then
    -- Browse tab
    displayListings(listings, true)
    widget.setText("statusLabel", string.format("%d listings available", #listings))
  elseif tabId == 1 then
    -- Sell tab (create listing)
    displaySellInterface()
    widget.setText("statusLabel", "Select an item to sell")
  elseif tabId == 2 then
    -- My Listings tab
    displayListings(myListings, false)
    widget.setText("statusLabel", string.format("%d active listings", #myListings))
  elseif tabId == 3 then
    -- Pending Items tab
    displayPendingItems()
    widget.setText("statusLabel", string.format("%d items to claim", #pendingItems))
  end
end

function displayListings(listingsToShow, showBuyButton)
  widget.clearListItems("listingsScrollArea.listingsList")

  for i, listing in ipairs(listingsToShow) do
    local listItem = "listingsScrollArea.listingsList." .. widget.addListItem("listingsScrollArea.listingsList")

    widget.setText(listItem .. ".itemName", listing.itemName)
    widget.setText(listItem .. ".itemCount", string.format("x%d", listing.itemCount))
    widget.setText(listItem .. ".price", string.format("^orange;%d CR^reset;", listing.totalPrice))
    widget.setText(listItem .. ".seller", listing.seller and listing.seller.displayName or "Unknown")

    -- Set item icon
    widget.setItemSlotItem(listItem .. ".itemIcon", {
      name = listing.itemName,
      count = listing.itemCount
    })

    -- Store listing ID in widget data
    widget.setData(listItem, { listingId = listing.id, listing = listing })

    if showBuyButton then
      widget.setVisible(listItem .. ".buyButton", true)
    else
      widget.setVisible(listItem .. ".buyButton", false)
    end
  end
end

function displaySellInterface()
  -- This would show a grid of player's inventory items
  -- For now, just show a message
  widget.setText("statusLabel", "Sell functionality - interact with inventory")
end

function displayPendingItems()
  widget.clearListItems("listingsScrollArea.listingsList")

  for i, item in ipairs(pendingItems) do
    local listItem = "listingsScrollArea.listingsList." .. widget.addListItem("listingsScrollArea.listingsList")

    widget.setText(listItem .. ".itemName", item.itemName)
    widget.setText(listItem .. ".itemCount", string.format("x%d", item.itemCount))
    widget.setText(listItem .. ".price", "")
    widget.setText(listItem .. ".seller", item.source)

    widget.setItemSlotItem(listItem .. ".itemIcon", {
      name = item.itemName,
      count = item.itemCount
    })

    widget.setData(listItem, { itemId = item.id })
  end
end

function onSearch()
  local query = widget.getText("searchBox")

  if query and #query > 0 then
    local filtered = market.searchListings(query)
    displayListings(filtered, true)
    widget.setText("statusLabel", string.format("%d results for '%s'", #filtered, query))
  else
    displayListings(listings, true)
    widget.setText("statusLabel", string.format("%d listings available", #listings))
  end
end

function onBuy(widgetName, widgetData)
  local data = widget.getData(widget.getParent(widgetName))
  if data and data.listingId then
    local success, message = market.purchaseListing(data.listingId, data.listing)

    if success then
      widget.setText("statusLabel", "^green;Purchase initiated!^reset;")
    else
      widget.setText("statusLabel", "^red;" .. message .. "^reset;")
    end

    -- Refresh after short delay
    refreshTimer = REFRESH_INTERVAL - 1
  end
end

function onCancel(widgetName, widgetData)
  local data = widget.getData(widget.getParent(widgetName))
  if data and data.listingId then
    local success, message = market.cancelListing(data.listingId)

    if success then
      widget.setText("statusLabel", "^green;Listing cancelled!^reset;")
    else
      widget.setText("statusLabel", "^red;" .. message .. "^reset;")
    end

    refreshTimer = REFRESH_INTERVAL - 1
  end
end

function onClaim(widgetName, widgetData)
  local data = widget.getData(widget.getParent(widgetName))
  if data and data.itemId then
    local success = bridge.claimPendingItem(data.itemId)

    if success then
      widget.setText("statusLabel", "^green;Item claimed!^reset;")
      refreshData()
    else
      widget.setText("statusLabel", "^red;Failed to claim item^reset;")
    end
  end
end

function onCreateListing()
  -- Would open a sub-dialog for creating listings
  widget.setText("statusLabel", "Select item from inventory to list")
end

-- Handle tab changes via radio group
function widgetUpdate()
  local newTab = widget.getSelectedOption("tabGroup")
  if newTab ~= currentTab then
    switchTab(newTab)
  end
end
