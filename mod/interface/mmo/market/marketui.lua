-- Starbound MMO Market UI
-- Loads dynamic data from bridge cache via Starbound's asset system

-- Fallback static listings if cache can't be read
local STATIC_LISTINGS = {
  { itemName = "Refined Aegisalt", itemCount = 50, totalPrice = 1250, seller = "SpaceCaptain" },
  { itemName = "Diamond", itemCount = 10, totalPrice = 5000, seller = "SpaceCaptain" },
  { itemName = "Fuel Cell", itemCount = 100, totalPrice = 1500, seller = "StarTrader" },
  { itemName = "Titanium Bar", itemCount = 200, totalPrice = 1600, seller = "StarTrader" },
  { itemName = "Solarium Star", itemCount = 5, totalPrice = 5000, seller = "NovaMiner" },
  { itemName = "Core Fragment", itemCount = 25, totalPrice = 1000, seller = "NovaMiner" }
}

local listings = {}
local dataSource = "static"

function init()
  -- Wrap everything in pcall to prevent crashes
  local success, err = pcall(function()
    sb.logInfo("[MMO Market] Initializing...")

    -- Try to load from cache, fall back to static
    listings = loadFromCache()

    -- Display the listings
    displayListings()

    sb.logInfo("[MMO Market] Initialized with " .. tostring(#listings) .. " listings from " .. dataSource)
  end)

  if not success then
    sb.logError("[MMO Market] Init failed: %s", tostring(err))
    -- Emergency fallback - just show static data
    listings = STATIC_LISTINGS
    dataSource = "static"
    pcall(displayListings)
  end
end

function update(dt)
  -- Could add periodic refresh here
end

function loadFromCache()
  -- Check if root.assetJson is available
  if not root or not root.assetJson then
    sb.logInfo("[MMO Market] root.assetJson not available, using static data")
    dataSource = "static"
    return STATIC_LISTINGS
  end

  -- Try multiple possible cache paths
  local cachePaths = {
    "/cache/market.json",
    "/interface/mmo/market/cache/market.json"
  }

  for _, path in ipairs(cachePaths) do
    local success, data = pcall(function()
      return root.assetJson(path)
    end)

    if success and data and type(data) == "table" and data.listings and #data.listings > 0 then
      dataSource = "cache"
      sb.logInfo("[MMO Market] Loaded " .. tostring(#data.listings) .. " listings from: " .. path)
      return data.listings
    else
      sb.logInfo("[MMO Market] Path " .. path .. " failed: success=" .. tostring(success) .. ", data=" .. tostring(data))
    end
  end

  -- Fall back to static data
  sb.logInfo("[MMO Market] No cache found, using static data")
  dataSource = "static"
  return STATIC_LISTINGS
end

function displayListings()
  -- Update status based on data source
  if dataSource == "cache" then
    widget.setText("statusLabel", "^green;" .. #listings .. " listings^reset;")
  elseif dataSource == "static" then
    widget.setText("statusLabel", "^yellow;Offline mode^reset;")
  else
    widget.setText("statusLabel", "^red;No data^reset;")
  end

  -- Display each listing in the label widgets
  for i = 1, 6 do
    local labelName = "listing" .. i

    if i <= #listings then
      local listing = listings[i]

      -- Handle different field name formats (camelCase vs snake_case)
      local itemName = listing.itemName or listing.item_name or "Unknown"
      local itemCount = listing.itemCount or listing.item_count or 1
      local totalPrice = listing.totalPrice or listing.total_price or 0
      local sellerName = "Unknown"

      if listing.seller then
        sellerName = listing.seller.displayName or listing.seller.display_name or listing.seller
      elseif type(listing.seller) == "string" then
        sellerName = listing.seller
      end

      -- Format the listing text
      local text = string.format("%s x%d - ^orange;%d CR^reset; (%s)",
        itemName, itemCount, totalPrice, sellerName)

      widget.setText(labelName, text)
    else
      -- Clear unused labels
      widget.setText(labelName, "")
    end
  end
end
