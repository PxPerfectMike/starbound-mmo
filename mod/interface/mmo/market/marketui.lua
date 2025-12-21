-- Starbound MMO Market UI
-- Simplified version for testing UI rendering

local currentTab = 0
local testListings = {}

function init()
  sb.logInfo("[MMO Market] UI initializing...")

  -- Create test data
  testListings = {
    {
      id = "test1",
      itemName = "ironbar",
      itemCount = 10,
      totalPrice = 500,
      seller = "TestPlayer1"
    },
    {
      id = "test2",
      itemName = "goldbar",
      itemCount = 5,
      totalPrice = 1000,
      seller = "TestPlayer2"
    },
    {
      id = "test3",
      itemName = "diamond",
      itemCount = 2,
      totalPrice = 2500,
      seller = "GalacticTrader"
    }
  }

  sb.logInfo("[MMO Market] Created %d test listings", #testListings)

  -- Update currency display
  widget.setText("currencyLabel", "Balance: ^orange;1000 CR^reset;")

  -- Load initial browse tab
  showBrowseTab()

  sb.logInfo("[MMO Market] UI initialized successfully")
end

function update(dt)
  -- Nothing needed for basic test
end

function showBrowseTab()
  currentTab = 0
  sb.logInfo("[MMO Market] Showing browse tab")

  -- Clear the list first
  widget.clearListItems("listingsScrollArea.listingsList")

  -- Add each listing to the list
  for i, listing in ipairs(testListings) do
    sb.logInfo("[MMO Market] Adding listing %d: %s", i, listing.itemName)

    -- Add a new list item and get its widget path
    local itemIndex = widget.addListItem("listingsScrollArea.listingsList")
    local itemPath = "listingsScrollArea.listingsList." .. itemIndex

    sb.logInfo("[MMO Market] Item path: %s", itemPath)

    -- Set the text fields
    widget.setText(itemPath .. ".itemName", listing.itemName)
    widget.setText(itemPath .. ".itemCount", "x" .. tostring(listing.itemCount))
    widget.setText(itemPath .. ".price", "^orange;" .. tostring(listing.totalPrice) .. " CR^reset;")
    widget.setText(itemPath .. ".seller", listing.seller)

    -- Try to set the item icon
    local success, err = pcall(function()
      widget.setItemSlotItem(itemPath .. ".itemIcon", {
        name = listing.itemName,
        count = listing.itemCount
      })
    end)

    if not success then
      sb.logWarn("[MMO Market] Failed to set item icon: %s", tostring(err))
    end

    -- Store data for later use
    widget.setData(itemPath, {
      listingId = listing.id,
      listing = listing
    })
  end

  widget.setText("statusLabel", "^green;" .. #testListings .. " listings^reset;")
  sb.logInfo("[MMO Market] Browse tab loaded with %d items", #testListings)
end

-- Tab button callbacks
function onTabBrowse()
  sb.logInfo("[MMO Market] Browse tab clicked")
  showBrowseTab()
end

function onTabSell()
  sb.logInfo("[MMO Market] Sell tab clicked")
  currentTab = 1
  widget.clearListItems("listingsScrollArea.listingsList")
  widget.setText("statusLabel", "^yellow;Select item to sell^reset;")
end

function onTabMy()
  sb.logInfo("[MMO Market] My Listings tab clicked")
  currentTab = 2
  widget.clearListItems("listingsScrollArea.listingsList")
  widget.setText("statusLabel", "^gray;No active listings^reset;")
end

function onTabPending()
  sb.logInfo("[MMO Market] Pending tab clicked")
  currentTab = 3
  widget.clearListItems("listingsScrollArea.listingsList")
  widget.setText("statusLabel", "^gray;No pending items^reset;")
end

-- Buy button callback
function onBuy(widgetName, widgetData)
  sb.logInfo("[MMO Market] Buy button clicked: %s", tostring(widgetName))

  -- Get the parent list item path
  local parentPath = string.gsub(widgetName, "%.buyButton$", "")
  sb.logInfo("[MMO Market] Parent path: %s", parentPath)

  local data = widget.getData(parentPath)
  if data and data.listing then
    widget.setText("statusLabel", "^green;Bought " .. data.listing.itemName .. "!^reset;")
    sb.logInfo("[MMO Market] Purchase: %s for %d CR", data.listing.itemName, data.listing.totalPrice)
  else
    widget.setText("statusLabel", "^red;Purchase failed^reset;")
    sb.logWarn("[MMO Market] No data found for widget")
  end
end

function onCancel(widgetName, widgetData)
  sb.logInfo("[MMO Market] Cancel clicked")
  widget.setText("statusLabel", "^yellow;Cancelled^reset;")
end

function onClaim(widgetName, widgetData)
  sb.logInfo("[MMO Market] Claim clicked")
  widget.setText("statusLabel", "^green;Item claimed!^reset;")
end
