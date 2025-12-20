function init()
  object.setInteractive(true)
  storage.active = storage.active or false
end

function update(dt)
  -- Could add idle animations or state checks here
end

function onInteraction(args)
  -- Open the market terminal UI
  return {"ScriptPane", "/interface/mmo/market/market.config"}
end
