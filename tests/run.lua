-- Tests without Reaper: `lua5.4 tests/run.lua` from the repository root. A fake `reaper` table stands in for the API.

package.path = "MIDI/lib/?.lua;" .. package.path
local failed, passed = 0, 0
local function check(name, got, want)
  if got == want then passed = passed + 1
  else failed = failed + 1; print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want))) end
end

-- fake Reaper -------------------------------------------------------------------------------------------------
local clock, files, resets, deferred = 0, {}, 0, nil
reaper = {
  time_precise = function() return clock end,
  EnumerateFiles = function(_, i) if i < 0 then return nil end return files[i + 1] end,
  midi_reinit = function() resets = resets + 1 end,
  defer = function(f) deferred = f end,
  GetResourcePath = function() return os.getenv("TMPDIR") or "/tmp" end,
  GetOS = function() return "linux-x86_64" end,
  ShowConsoleMsg = function() end,
  ExecProcess = function() end,
}

-- core watcher -------------------------------------------------------------------------------------------------
local core = require("core")
local step = core.new_watcher(2)
check("not ready yet", step(0, nil), false)
check("first list is the baseline", step(1, "a"), false)
check("unchanged", step(2, "a"), false)
check("change seen", step(3, "a b"), false)
check("not settled", step(4, "a b"), false)
check("settled: reset", step(5, "a b"), true)
check("after reset, unchanged", step(6, "a b"), false)
check("unplug seen", step(7, "a"), false)
check("plugged back before settling", step(8, "a b"), false)
check("plugged back: resets anyway, Reaper lost it meanwhile", step(11, "a b"), true)
check("change during a change restarts settling", step(12, "a"), false)
check("", step(13, "a c"), false)
check("", step(14, "a c"), false)
check("settled on the last list", step(15, "a c"), true)

-- linux backend -------------------------------------------------------------------------------------------------
local linux = require("platform.linux")
files = { "controlC1", "midiC1D0", "pcmC1D0p", "seq", "midiC2D0", "timer" }
check("linux: only raw MIDI nodes, sorted", linux.devices(), "midiC1D0 midiC2D0")

-- the loop end to end, with the linux backend
files = { "midiC1D0" }; clock = 0; resets = 0
core.run(linux)
local function tick(t) clock = t; deferred() end
tick(0.5); tick(1.0)
files = { "midiC1D0", "midiC2D0" }               -- Hapax plugged in
tick(2.0); tick(3.0); tick(4.0)
check("loop: plug in resets once", resets, 1)
files = { "midiC1D0" }                           -- unplugged
tick(5.0); tick(6.0); tick(7.0)
check("loop: unplug resets again", resets, 2)

-- platform.retry: a backend whose OS reports a device before it is playable (Windows) resets a second time, so a
-- driver that finishes registering after the first reset is still picked up.
local list = "a"
local retrying = { settle = 2.0, poll = 1.0, retry = 3.0, devices = function() return list end }
clock = 0; resets = 0
core.run(retrying)
tick(1.0)
list = "a b"
tick(2.0); tick(3.0); tick(4.0)                  -- change seen at 2, settles at 4: first reset
check("retry: first reset on settle", resets, 1)
tick(5.0); tick(6.0)
check("retry: nothing before the delay", resets, 1)
tick(7.0)                                        -- 4 + 3: second reset
check("retry: second reset after the delay", resets, 2)
tick(8.0); tick(9.0); tick(12.0)
check("retry: and only one extra", resets, 2)

-- Windows parser (pnputil /enum-devices output)
local win = require("platform.windows")
local pnputil = "Microsoft PnP Utility\r\n\r\nInstance ID:                USB\\VID_0483&PID_5731\\6&1\r\n" ..
  "Device Description:         HAPAX\r\nClass Name:                 MEDIA\r\n\r\n" ..
  "Instance ID:                HDAUDIO\\FUNC_01&VEN_10EC\\4&2\r\nDevice Description:         Realtek\r\n"
check("windows: instance IDs, sorted", win.parse(pnputil),
  "HDAUDIO\\FUNC_01&VEN_10EC\\4&2\nUSB\\VID_0483&PID_5731\\6&1")

-- Windows starter: writes its VBScript beside the output file once, then runs it through wscript
local tmp = os.tmpname(); os.remove(tmp); os.execute('mkdir -p "' .. tmp .. '/sub"')
local execs = {}
reaper.ExecProcess = function(line) execs[#execs + 1] = line end
win.start("pnputil /x", tmp .. "/sub/name.out")
win.start("pnputil /x", tmp .. "/sub/name.out")
local vbs = io.open(tmp .. "/sub/name.vbs"); local script = vbs and vbs:read("a"); if vbs then vbs:close() end
check("windows start: script written", script and script:match("WScript%.Shell") ~= nil, true)
check("windows start: runs it hidden through wscript",
  execs[1]:match('^wscript%.exe //nologo //B ".-\\sub\\name%.vbs" "pnputil /x" ".-\\sub\\name%.out"$') ~= nil, true)
check("windows start: one start per call", #execs, 2)
os.execute('rm -rf "' .. tmp .. '"')

-- start-with-REAPER line in Scripts/__startup.lua --------------------------------------------------------------
local res = os.tmpname(); os.remove(res); os.execute('mkdir -p "' .. res .. '/Scripts"')
reaper.GetResourcePath = function() return res end
reaper.AddRemoveReaScript = function() return 54321 end
reaper.ReverseNamedCommandLookup = function() return "RS0123abcd" end
local function startup_file()
  local f = io.open(res .. "/Scripts/__startup.lua"); if not f then return nil end
  local t = f:read("a"); f:close(); return t
end
local startup = require("startup")
check("startup: off with no file", startup.enabled(), false)
startup.set(true, "x")
check("startup: on", startup.enabled(), true)
check("startup: line runs the action by ID", startup_file():match('NamedCommandLookup%("_RS0123abcd"%)') ~= nil, true)
local f = io.open(res .. "/Scripts/__startup.lua", "w"); f:write("-- user's own line\n" .. startup_file()); f:close()
startup.set(true, "x")
check("startup: on twice keeps one line", select(2, startup_file():gsub("reaper%-midi%-hotplug", "")), 1)
startup.set(false, "x")
check("startup: off removes only its line", startup_file(), "-- user's own line\n")
check("startup: off", startup.enabled(), false)
os.execute('rm -rf "' .. res .. '"')

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
