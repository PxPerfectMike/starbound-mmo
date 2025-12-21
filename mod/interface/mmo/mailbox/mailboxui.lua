-- Starbound MMO Mailbox UI
-- Displays pending items and allows claiming them

-- State
local pendingItems = {}
local playerState = nil
local starboundId = nil
local mailboxEntityId = nil

-- Generate a simple unique ID
local function generateId()
  return tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
end

-- Send command via the mailbox object
local function sendViaMailbox(command)
  if not mailboxEntityId then
    mailboxEntityId = pane.sourceEntity()
    if mailboxEntityId then
      sb.logInfo("[MMO Mailbox] Connected to mailbox: " .. tostring(mailboxEntityId))
    end
  end

  if not mailboxEntityId then
    sb.logWarn("[MMO Mailbox] No mailbox entity found")
    return false
  end

  local result = world.sendEntityMessage(mailboxEntityId, "mmo_command", command)
  if result:finished() then
    if result:succeeded() then
      sb.logInfo("[MMO Mailbox] Command sent: " .. command.type)
      return true
    end
  end

  sb.logInfo("[MMO Mailbox] Command sent (async): " .. command.type)
  return true
end

function init()
  local success, err = pcall(function()
    sb.logInfo("[MMO Mailbox] Initializing...")

    -- Get player info
    starboundId = player.uniqueId()
    sb.logInfo("[MMO Mailbox] Player: " .. starboundId)

    -- Load player state (which contains pending items)
    playerState = loadPlayerState()

    if playerState then
      pendingItems = playerState.pendingItems or {}
      sb.logInfo("[MMO Mailbox] Loaded " .. tostring(#pendingItems) .. " pending items")
    else
      pendingItems = {}
      sb.logInfo("[MMO Mailbox] No player state found")
    end

    displayItems()
  end)

  if not success then
    sb.logError("[MMO Mailbox] Init failed: " .. tostring(err))
    widget.setText("statusLabel", "^red;Error loading mailbox^reset;")
  end
end

function loadPlayerState()
  if not starboundId then return nil end

  local success, data = pcall(function()
    return root.assetJson("/cache/player_" .. starboundId .. ".json")
  end)

  if success and data and type(data) == "table" then
    return data
  end

  return nil
end

function displayItems()
  local count = #pendingItems

  if count == 0 then
    widget.setText("statusLabel", "^green;No items to claim^reset;")
  else
    widget.setText("statusLabel", "^yellow;" .. tostring(count) .. " items waiting^reset;")
  end

  -- Display each pending item
  for i = 1, 6 do
    local labelName = "item" .. i
    local buttonName = "claim" .. i

    if i <= #pendingItems then
      local item = pendingItems[i]
      local itemName = item.itemName or "Unknown"
      local itemCount = item.itemCount or 1
      local source = item.source or "unknown"

      local sourceLabel = ""
      if source == "market_purchase" then
        sourceLabel = "^cyan;[Purchase]^reset;"
      elseif source == "market_return" then
        sourceLabel = "^yellow;[Returned]^reset;"
      elseif source == "event_reward" then
        sourceLabel = "^green;[Reward]^reset;"
      end

      local text = string.format("%s x%d %s", itemName, itemCount, sourceLabel)
      widget.setText(labelName, text)
      widget.setVisible(buttonName, true)
    else
      widget.setText(labelName, "")
      widget.setVisible(buttonName, false)
    end
  end

  -- Show/hide claim all button
  widget.setVisible("claimAllBtn", count > 0)
end

function claimItem(index)
  if index > #pendingItems then
    sb.logWarn("[MMO Mailbox] Invalid item index: " .. tostring(index))
    return
  end

  local item = pendingItems[index]

  sb.logInfo("[MMO Mailbox] Claiming item: " .. item.itemName .. " x" .. tostring(item.itemCount))

  -- Give the item to the player immediately
  local itemDescriptor = {
    name = item.itemName,
    count = item.itemCount,
    parameters = item.itemParams or {}
  }

  local success = pcall(function()
    player.giveItem(itemDescriptor)
  end)

  if success then
    sb.logInfo("[MMO Mailbox] Item given to player: " .. item.itemName)

    -- Send claim command to bridge to remove from database
    sendClaimCommand(item.id)

    -- Remove from local list and update display
    table.remove(pendingItems, index)
    displayItems()

    widget.setText("statusLabel", "^green;Claimed " .. item.itemName .. "!^reset;")
  else
    sb.logError("[MMO Mailbox] Failed to give item: " .. item.itemName)
    widget.setText("statusLabel", "^red;Failed to claim item^reset;")
  end
end

function sendClaimCommand(pendingItemId)
  if not playerState or not playerState.id then
    sb.logWarn("[MMO Mailbox] Cannot send claim: player not registered")
    return false
  end

  local command = {
    id = generateId(),
    type = "claim_item",
    playerId = playerState.id,
    timestamp = os.time(),
    data = {
      pendingItemId = pendingItemId
    }
  }

  return sendViaMailbox(command)
end

-- Claim button callbacks
function claimItem1() claimItem(1) end
function claimItem2() claimItem(2) end
function claimItem3() claimItem(3) end
function claimItem4() claimItem(4) end
function claimItem5() claimItem(5) end
function claimItem6() claimItem(6) end

function claimAll()
  sb.logInfo("[MMO Mailbox] Claiming all items...")

  -- Claim items from last to first to avoid index shifting issues
  local claimed = 0
  while #pendingItems > 0 do
    local item = pendingItems[1]

    local itemDescriptor = {
      name = item.itemName,
      count = item.itemCount,
      parameters = item.itemParams or {}
    }

    local success = pcall(function()
      player.giveItem(itemDescriptor)
    end)

    if success then
      sendClaimCommand(item.id)
      table.remove(pendingItems, 1)
      claimed = claimed + 1
    else
      sb.logError("[MMO Mailbox] Failed to give item: " .. item.itemName)
      break
    end
  end

  displayItems()

  if claimed > 0 then
    widget.setText("statusLabel", "^green;Claimed " .. tostring(claimed) .. " items!^reset;")
  end
end

function update(dt)
  -- Could poll for updates here if needed
end
