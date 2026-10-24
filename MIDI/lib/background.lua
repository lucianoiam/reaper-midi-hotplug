-- Run a system command without blocking Reaper: the command is started detached, writes its output to a file, and
-- a later poll reads the finished file. Used by backends whose device list needs an external program (Windows
-- pnputil), which would stall Reaper's UI if run synchronously every poll.
--
-- How the command is started is the backend's business: start(cmd, out) must run cmd detached, writing its output
-- to out.part and renaming it to out when done, so a half-written file is never read.

local background = {}

local RESTART_AFTER = 30   -- seconds: a run that never produced output is assumed dead and started again

-- new(name, cmd, start): returns poll(), which starts a run if none is going and returns the newest finished
-- output (nil until the first run has finished). Output goes to <resource path>/<name>.out.
function background.new(name, cmd, start)
  local out = reaper.GetResourcePath() .. "/" .. name .. ".out"
  os.remove(out)
  local last, started_at = nil, nil
  return function()
    local f = io.open(out, "r")
    if f then
      last = f:read("a"); f:close(); os.remove(out); started_at = nil
    end
    local now = reaper.time_precise()
    if not started_at or now - started_at > RESTART_AFTER then
      start(cmd, out); started_at = now
    end
    return last
  end
end

return background
