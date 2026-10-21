function init()
  local pos = stagehand.position()
  
  -- Spawn objects relative to stagehand position
  world.placeObject("mmo_hubreturn", {pos[1] - 40, pos[2]}, 1)
  world.placeObject("mmo_marketterminal", {pos[1], pos[2]}, 1)
  world.placeObject("mmo_mailbox", {pos[1] + 48, pos[2]}, 1)
  
  -- Self-destruct after spawning
  stagehand.die()
end
