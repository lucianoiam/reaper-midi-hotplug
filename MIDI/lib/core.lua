-- Platform-independent watcher: polls platform.devices() and calls reaper.midi_reinit() once the device list has
-- changed and then stayed the same for platform.settle seconds. The first list seen is what Reaper started with and
-- never triggers a reset. A backend may return nil while its list is not ready yet (background command still
-- running): that poll is skipped.
--
-- Any departure from the list Reaper was last reset to counts, including one that ends back at that same list: a
-- device unplugged and plugged straight back in is dead in Reaper until a reset, however unchanged the list looks
-- afterwards.
--
-- platform.retry, when set, resets once more that many seconds after the first reset, for an OS that lists a device
-- before its driver has finished making it usable. A reset issued in that window finds nothing new; the second one
-- picks the device up, without every reset having to wait for the slowest driver.

local core = {}

-- Pure state machine, separate from Reaper's timer so it can be tested without Reaper.
-- step(now, list) returns true when a reset is due: the list has moved away from known and then held still for
-- settle seconds, at whatever value.
function core.new_watcher(settle)
  local known, pending, changed = nil, nil, 0
  return function(now, list)
    if list == nil then return false end
    if known == nil then known = list; return false end
    if pending == nil then
      if list == known then return false end
      pending, changed = list, now; return false
    end
    if list ~= pending then pending, changed = list, now; return false end
    if now - changed < settle then return false end
    known, pending = list, nil
    return true
  end
end

function core.run(platform)
  local step = core.new_watcher(platform.settle or 2.0)
  local poll = platform.poll or 1.0
  local retry = platform.retry                    -- nil: reset once
  local next_poll, retry_at = 0, nil
  local function loop()
    local now = reaper.time_precise()
    if now >= next_poll then
      next_poll = now + poll
      if step(now, platform.devices()) then
        reaper.midi_reinit()
        retry_at = retry and now + retry or nil
      elseif retry_at and now >= retry_at then
        reaper.midi_reinit()
        retry_at = nil
      end
    end
    reaper.defer(loop)
  end
  loop()
end

return core
