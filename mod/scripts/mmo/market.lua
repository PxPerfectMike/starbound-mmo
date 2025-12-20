-- Starbound MMO Market System
-- Handles market terminal interactions

require "/scripts/mmo/bridge.lua"

local market = {}

-- Create a new market listing
function market.createListing(itemDescriptor, pricePerUnit)
  local playerId = player.uniqueId()

  -- Validate item exists in inventory
  if not player.hasItem(itemDescriptor) then
    return false, "You don't have this item"
  end

  -- Validate price
  if pricePerUnit <= 0 then
    return false, "Price must be greater than 0"
  end

  -- Calculate listing fee (5%)
  local totalPrice = pricePerUnit * itemDescriptor.count
  local listingFee = math.floor(totalPrice * 0.05)

  -- Check if player can afford fee
  local currency = bridge.getCurrency()
  if currency < listingFee then
    return false, string.format("Insufficient funds for listing fee (%d Credits)", listingFee)
  end

  -- Remove item from inventory
  if not player.consumeItem(itemDescriptor, true) then
    return false, "Failed to remove item from inventory"
  end

  -- Send command to bridge
  local commandId = bridge.sendCommand("market_create", playerId, {
    item = {
      name = itemDescriptor.name,
      count = itemDescriptor.count,
      parameters = itemDescriptor.parameters or {}
    },
    pricePerUnit = pricePerUnit
  })

  sb.logInfo("[MMO Market] Created listing for %s x%d at %d each",
    itemDescriptor.name,
    itemDescriptor.count,
    pricePerUnit
  )

  return true, "Listing created successfully"
end

-- Purchase a listing
function market.purchaseListing(listingId, listing)
  local playerId = player.uniqueId()

  -- Check if player can afford
  local currency = bridge.getCurrency()
  if currency < listing.totalPrice then
    return false, "Insufficient funds"
  end

  -- Can't buy your own listing
  if listing.sellerId == playerId then
    return false, "Cannot purchase your own listing"
  end

  -- Send command to bridge
  local commandId = bridge.sendCommand("market_purchase", playerId, {
    listingId = listingId
  })

  sb.logInfo("[MMO Market] Purchasing listing %s", listingId)

  return true, "Purchase initiated"
end

-- Cancel a listing
function market.cancelListing(listingId)
  local playerId = player.uniqueId()

  -- Send command to bridge
  local commandId = bridge.sendCommand("market_cancel", playerId, {
    listingId = listingId
  })

  sb.logInfo("[MMO Market] Cancelling listing %s", listingId)

  return true, "Cancellation initiated"
end

-- Get cached market listings
function market.getListings()
  local cache = bridge.readMarketCache()
  return cache.listings or {}
end

-- Filter listings by item name
function market.searchListings(query)
  local listings = market.getListings()
  local results = {}

  query = string.lower(query)

  for _, listing in ipairs(listings) do
    if string.find(string.lower(listing.itemName), query) then
      table.insert(results, listing)
    end
  end

  return results
end

-- Get player's own listings
function market.getMyListings()
  local playerId = player.uniqueId()
  local listings = market.getListings()
  local myListings = {}

  for _, listing in ipairs(listings) do
    if listing.sellerId == playerId then
      table.insert(myListings, listing)
    end
  end

  return myListings
end

return market
