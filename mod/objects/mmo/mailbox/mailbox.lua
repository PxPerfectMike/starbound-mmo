-- MMO Mailbox - Server-side script
-- Handles command relay for item claiming

function init()
  sb.logInfo("[MMO Mailbox] Mailbox initialized at " .. sb.printJson(entity.position()))

  -- Register message handlers
  message.setHandler("mmo_command", handleCommand)
  message.setHandler("mmo_ping", handlePing)
end

function handlePing(_, _, data)
  sb.logInfo("[MMO Mailbox] Ping received")
  return { status = "ok", mailboxId = entity.uniqueId() }
end

function handleCommand(_, _, command)
  if not command or type(command) ~= "table" then
    sb.logWarn("[MMO Mailbox] Invalid command received")
    return { success = false, error = "Invalid command" }
  end

  local commandType = command.type or "unknown"
  local commandId = command.id or "no-id"
  local playerId = command.playerId or "unknown"

  sb.logInfo("[MMO Mailbox] Received command: " .. commandType .. " from " .. playerId)

  -- Log the command in a structured format that the bridge can parse
  local commandJson = sb.printJson(command)
  sb.logInfo("[MMO_CMD]" .. commandJson)

  return { success = true, commandId = commandId }
end

function update(dt)
  -- Nothing to do here
end

function uninit()
  sb.logInfo("[MMO Mailbox] Mailbox shutting down")
end
