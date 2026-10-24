-- Windows: connected devices of the MEDIA class ("Sound, video and game controllers"), where USB MIDI devices are
-- listed. Needs pnputil with /enum-devices (Windows 10 2004 or later). Runs in the background (lib/background.lua):
-- pnputil takes a noticeable fraction of a second.
--
-- The class holds audio devices as well, so a hot-pluggable audio device appearing or disappearing also triggers a
-- reset. That is one reset nothing was waiting for, against never missing a MIDI device: the class is the one
-- enumeration that covers every MIDI interface.
--
-- pnputil can list a device as connected before its class driver has finished registering it with the MIDI
-- subsystem Reaper asks, so retry (lib/core.lua) resets a second time a few seconds after the first.

local background = require("background")

local M = { settle = 2.0, poll = 2.0, retry = 4.0 }

-- Detached start (contract in lib/background.lua). ExecProcess with timeout -1 returns at once but gives the
-- process a console, so cmd.exe run directly shows a window on every poll. The chain is started through
-- wscript.exe instead, a GUI-subsystem host with no console of its own, running the VBScript below, which starts
-- cmd.exe with its window hidden (window style 0) and doesn't wait for it. The redirect and rename live in the
-- script, which is written next to the output file the first time it is needed.
--
-- Paths go over with backslashes only: Lua and the > redirect take either separator, cmd's move does not take a
-- mix of the two.
local VBS = [[
Option Explicit
Dim shell, command, out, line
If WScript.Arguments.Count < 2 Then WScript.Quit 1
Set shell = CreateObject("WScript.Shell")
command = WScript.Arguments(0)
out = WScript.Arguments(1)
line = "cmd /S /C """ & command & " > """ & out & ".part"" 2>nul && move /y """ & out & ".part"" """ & out & """ >nul"""
shell.Run line, 0, False
]]

local function backslashes(p) return (p:gsub("/", "\\")) end

local vbs_written = false

local function start(cmd, out)
  local vbs = out:gsub("%.out$", "") .. ".vbs"
  if not vbs_written then
    local f = assert(io.open(vbs, "w")); f:write(VBS); f:close()
    vbs_written = true
  end
  reaper.ExecProcess(('wscript.exe //nologo //B "%s" "%s" "%s"'):format(backslashes(vbs), cmd, backslashes(out)), -1)
end

M.start = start   -- for tests

local run = background.new("reaper-midi-hotplug", "pnputil /enum-devices /class MEDIA /connected", start)

local function parse(text)
  local list = {}
  for id in text:gmatch("Instance ID:%s*([^\r\n]+)") do list[#list + 1] = id end
  table.sort(list)
  return table.concat(list, "\n")
end

M.parse = parse   -- for tests

function M.devices()
  local text = run()
  return text and parse(text)
end

return M
