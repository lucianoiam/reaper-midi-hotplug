-- @noindex
-- Switch: start "MIDI hotplug" with REAPER, on or off. Turning it on also starts the watcher if it isn't running.

local dir = debug.getinfo(1, "S").source:match("^@?(.*[/\\])") or ""
package.path = dir .. "lib/?.lua;" .. package.path

local NAME = "MIDI hotplug"
local startup = require("startup")
local main = dir .. "MIDI hotplug.lua"
local _, _, section, cmd = reaper.get_action_context()

local on = not startup.enabled()
startup.set(on, main)
reaper.SetToggleCommandState(section, cmd, on and 1 or 0)
reaper.RefreshToolbar2(section, cmd)

local id = startup.command_id(main)
if on and reaper.GetToggleCommandState(id) ~= 1 then reaper.Main_OnCommand(id, 0) end

reaper.ShowMessageBox(on and "MIDI hotplug will start every time REAPER starts." or
  "MIDI hotplug will no longer start with REAPER. (It keeps running until REAPER quits or you stop it.)", NAME, 0)
