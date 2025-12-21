-- MMO Command Relay Stagehand
-- Receives commands from clients and logs them for the bridge to process

function init()
  sb.logInfo("[MMO Relay] Command relay initialized at position: " .. sb.printJson(entity.position()))

  -- Register message handlers
  message.setHandler("mmo_command", handleCommand)
  message.setHandler("mmo_ping", handlePing)
end

function handlePing(_, _, data)
  sb.logInfo("[MMO Relay] Ping received from player")
  return { status = "ok", relayId = entity.uniqueId() }
end

function handleCommand(_, _, command)
  if not command or type(command) ~= "table" then
    sb.logWarn("[MMO Relay] Invalid command received")
    return { success = false, error = "Invalid command" }
  end

  local commandType = command.type or "unknown"
  local commandId = command.id or "no-id"
  local playerId = command.playerId or "unknown"

  sb.logInfo("[MMO Relay] Received command: " .. commandType .. " from " .. playerId)

  -- Log the command in a structured format that the bridge can parse
  -- Format: [MMO_CMD] followed by JSON
  local commandJson = sb.printJson(command)
  sb.logInfo("[MMO_CMD]" .. commandJson)

  return { success = true, commandId = commandId }
end

function update(dt)
  -- Keep alive, nothing to do here
end

function uninit()
  sb.logInfo("[MMO Relay] Command relay shutting down")
end
