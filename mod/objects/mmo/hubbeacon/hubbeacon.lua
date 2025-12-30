-- MMO Hub Beacon - Teleports player to the hub instance world

function init()
  sb.logInfo("[MMO Hub Beacon] Initialized at " .. sb.printJson(entity.position()))
end

function onInteraction(args)
  -- Return OpenTeleportDialog with hub as destination
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
  -- Nothing needed
end

function uninit()
  sb.logInfo("[MMO Hub Beacon] Shutting down")
end
