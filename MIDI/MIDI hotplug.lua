-- @description MIDI hotplug: reset MIDI devices when one is plugged in or unplugged
-- @author Luciano Iam
-- @version 1.0.0
-- @changelog First release.
-- @about
--   # MIDI hotplug
--
--   REAPER does not notice MIDI devices plugged in or unplugged while it runs: a new device stays unavailable, and
--   an unplugged one stays dead, until Options > Reset all MIDI devices. This script runs in the background and does
--   that reset for you a couple of seconds after the set of MIDI devices changes.
--
--   - **MIDI hotplug**: start or stop the watcher (on/off, works as a toolbar button). The first run asks whether
--     to start it with REAPER.
--   - **MIDI hotplug - Start with REAPER**: switch starting with REAPER on or off.
--
--   Windows 10 2004+ and Linux (ALSA or PipeWire/JACK audio). Not needed on macOS, where REAPER reconnects MIDI
--   devices by itself.

-- Layout: lib/core.lua is the platform-independent watcher; lib/platform/<os>.lua tells it which MIDI devices
-- exist (interface in lib/platform/README.md); lib/startup.lua manages the start-with-REAPER line.

local dir = debug.getinfo(1, "S").source:match("^@?(.*[/\\])") or ""
package.path = dir .. "lib/?.lua;" .. package.path

local NAME = "MIDI hotplug"
local _, script, section, cmd = reaper.get_action_context()

local function platform_name()
  local os = reaper.GetOS()                      -- "Win32", "Win64", "OSX64", "macOS-arm64", "linux-x86_64", …
  if os:match("^Win") then return "windows" end
  if os:match("^OSX") or os:match("^macOS") then return nil end
  return "linux"
end

local name = platform_name()
if not name then
  reaper.ShowMessageBox("REAPER on macOS reconnects MIDI devices by itself, so this script is not needed there.",
    NAME, 0)
  return
end

local ok, platform = pcall(require, "platform." .. name)
if not ok then
  reaper.ShowMessageBox(tostring(platform), NAME, 0)
  return
end

-- Action on/off state; running the action again stops the script (REAPER 7.03+; older versions ask instead).
if reaper.set_action_options then reaper.set_action_options(1) end
local function set_state(on)
  reaper.SetToggleCommandState(section, cmd, on and 1 or 0)
  reaper.RefreshToolbar2(section, cmd)
end
set_state(true)
reaper.atexit(function() set_state(false) end)

-- First run: offer to start with REAPER (asked once).
local startup = require("startup")
if not startup.enabled() and reaper.GetExtState("reaper-midi-hotplug", "asked") ~= "1" then
  reaper.SetExtState("reaper-midi-hotplug", "asked", "1", true)
  local answer = reaper.ShowMessageBox("Start MIDI hotplug automatically every time REAPER starts?\n\n" ..
    "You can change this later with the action \"MIDI hotplug - Start with REAPER\".", NAME, 4)
  if answer == 6 then startup.set(true, script) end   -- 6 = Yes
end

require("core").run(platform)
