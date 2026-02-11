-- MMO Admin Block status effect
-- Suppresses all movement while active
-- Self-expires after 6 seconds - the monitor script re-applies every 3s while admin is on
-- This prevents stale long-duration effects from persisting across sessions

local elapsed = 0

function init()
  script.setUpdateDelta(1)
end

function update(dt)
  elapsed = elapsed + dt
  if elapsed > 6 then
    effect.expire()
    return
  end
  mcontroller.controlModifiers({
    facingSuppressed = true,
    movementSuppressed = true
  })
  mcontroller.setVelocity({0, 0})
end

function uninit()
end
