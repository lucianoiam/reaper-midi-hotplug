-- Linux: ALSA and PipeWire modes.
--  - ALSA: Reaper opens the ALSA MIDI devices directly.
--  - PipeWire (JACK): PipeWire's Midi-Bridge publishes each ALSA MIDI device as ports ("Midi-Bridge:HAPAX: MIDI 1
--    (capture)"), a moment after the kernel creates the device; settle gives it that moment.
-- Either way the kernel's raw MIDI node /dev/snd/midiC<card>D<device> appears or goes away first, so watch those.

local DIR = "/dev/snd/"

local M = { settle = 2.0, poll = 1.0 }

function M.devices()
  reaper.EnumerateFiles(DIR, -1)                 -- -1: drop Reaper's cached listing, rescan the directory
  local list, i = {}, 0
  while true do
    local f = reaper.EnumerateFiles(DIR, i)
    if not f then break end
    if f:match("^midiC%d+D%d+$") then list[#list + 1] = f end
    i = i + 1
  end
  table.sort(list)
  return table.concat(list, " ")
end

return M
