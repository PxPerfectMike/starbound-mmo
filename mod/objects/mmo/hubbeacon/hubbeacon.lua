-- MMO Hub Beacon - Teleports player to the hub instance world
-- Only allows MMO-registered characters who are not in admin mode

function init()
  sb.logInfo("[MMO Hub Beacon] Initialized at " .. sb.printJson(entity.position()))
end

function onInteraction(args)
  local sourceId = args.sourceId

  -- Check if player is an MMO character
  local mmoCheck = world.sendEntityMessage(sourceId, "mmo_isRegistered")
  if mmoCheck:finished() and mmoCheck:succeeded() then
    if not mmoCheck:result() then
      return {"ShowPopup", {message = "^red;MMO character required.^reset;\nOnly MMO-registered characters can enter the hub."}}
    end
  end

  -- Check if player is admin-flagged
  local adminCheck = world.sendEntityMessage(sourceId, "mmo_isAdminFlagged")
  if adminCheck:finished() and adminCheck:succeeded() then
    if adminCheck:result() then
      return {"ShowPopup", {message = "^red;Admin mode detected.^reset;\nDisable admin mode to use MMO features."}}
    end
  end

  return {
    "OpenTeleportDialog",
    {
      canBookmark = false,
      includePlayerBookmarks = false,
      destinations = {
        {
          name = "MMO Hub Station",
          planetName = "Central Trading Hub",
          icon = "default",
          warpAction = "InstanceWorld:mmo_hub"
        }
      }
    }
  }
end

function update(dt)
end

function uninit()
  sb.logInfo("[MMO Hub Beacon] Shutting down")
end
