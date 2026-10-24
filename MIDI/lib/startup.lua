-- Start-with-REAPER switch: one tagged line in Scripts/__startup.lua, which REAPER runs at every start. Only that
-- line is ever added or removed; anything else in the file is left as it is. The line runs the "MIDI hotplug"
-- action by its command ID, so the action's on/off state (toolbar button, menu checkmark) stays right.

local startup = {}

local TAG = "-- reaper-midi-hotplug: added by the 'MIDI hotplug - Start with REAPER' action"

local function path() return reaper.GetResourcePath() .. "/Scripts/__startup.lua" end

local function read()
  local f = io.open(path(), "r")
  if not f then return "" end
  local text = f:read("a"); f:close()
  return text
end

function startup.enabled()
  return read():find(TAG, 1, true) ~= nil
end

-- The "MIDI hotplug" action's command ID, registering the script first if needed (returns the existing ID when
-- it is already in the action list).
function startup.command_id(main_script)
  return reaper.AddRemoveReaScript(true, 0, main_script, true)
end

function startup.set(on, main_script)
  local lines = {}
  for line in (read() .. "\n"):gmatch("(.-)\n") do
    if not line:find(TAG, 1, true) then lines[#lines + 1] = line end
  end
  while #lines > 0 and lines[#lines] == "" do lines[#lines] = nil end
  if on then
    local name = reaper.ReverseNamedCommandLookup(startup.command_id(main_script))
    lines[#lines + 1] = ('reaper.Main_OnCommand(reaper.NamedCommandLookup("_%s"), 0) %s'):format(name, TAG)
  end
  local f = assert(io.open(path(), "w"))
  f:write(table.concat(lines, "\n"), #lines > 0 and "\n" or "")
  f:close()
end

return startup
