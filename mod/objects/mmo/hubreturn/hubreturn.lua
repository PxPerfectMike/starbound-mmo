-- MMO Hub Return Portal - Returns player to their ship

function init()
  sb.logInfo("[MMO Hub Return] Initialized at " .. sb.printJson(entity.position()))
end

function onInteraction(args)
  -- Return OpenTeleportDialog with ship as destination
  return {
    "OpenTeleportDialog",
    {
      canBookmark = false,
      includePlayerBookmarks = false,
      destinations = {
        {
          name = "Return to Ship",
          planetName = "Your Personal Vessel",
          icon = "default",
          warpAction = "OwnShip"
        }
      }
    }
  }
end

function update(dt)
  -- Nothing needed
end

function uninit()
  sb.logInfo("[MMO Hub Return] Shutting down")
end
