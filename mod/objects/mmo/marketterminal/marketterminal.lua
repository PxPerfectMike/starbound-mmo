-- MMO Market Terminal - Server-side script
-- Handles command relay from client ScriptPane to server log

function init()
  sb.logInfo("[MMO Terminal] Market terminal initialized at " .. sb.printJson(entity.position()))

  -- Register message handlers
  message.setHandler("mmo_command", handleCommand)
  message.setHandler("mmo_ping", handlePing)
end

function handlePing(_, _, data)
  sb.logInfo("[MMO Terminal] Ping received")
  return { status = "ok", terminalId = entity.uniqueId() }
end

function handleCommand(_, _, command)
  if not command or type(command) ~= "table" then
    sb.logWarn("[MMO Terminal] Invalid command received")
    return { success = false, error = "Invalid command" }
  end

  local commandType = command.type or "unknown"
  local commandId = command.id or "no-id"
  local playerId = command.playerId or "unknown"

  sb.logInfo("[MMO Terminal] Received command: " .. commandType .. " from " .. playerId)

  -- Log the command in a structured format that the bridge can parse
  -- Format: [MMO_CMD] followed by JSON
  local commandJson = sb.printJson(command)
  sb.logInfo("[MMO_CMD]" .. commandJson)

  return { success = true, commandId = commandId }
end

function update(dt)
  -- Nothing to do here - terminal just waits for messages
end

function uninit()
  sb.logInfo("[MMO Terminal] Market terminal shutting down")
end
