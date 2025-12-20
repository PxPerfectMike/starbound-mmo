require "/scripts/mmo/bridge.lua"

function init()
  object.setInteractive(true)
end

function update(dt)
  -- Terminal animation handled by .animation file
end

function onInteraction(args)
  -- The ScriptPane handles all UI logic
  return nil
end
