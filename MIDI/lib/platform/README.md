# Platform backends

One file per OS, loaded by `MIDI hotplug.lua` from `reaper.GetOS()`: `windows.lua`, `linux.lua`.
A backend is a Lua module returning a table:

| Field | Type | Meaning |
|---|---|---|
| `devices()` | function → string | The MIDI devices present right now, as one string that is equal whenever the set of devices is equal (sort the names, then join them). Called every `poll` seconds, so keep it cheap; may return nil while the list isn't ready yet (that poll is skipped). |
| `poll` | number, seconds (optional, default 1) | How often `devices()` is called. |
| `settle` | number, seconds (optional, default 2) | How long the list must stay unchanged before Reaper's MIDI devices are reset. Cover the time the OS or audio server needs to make the device usable after it appears. |
| `retry` | number, seconds (optional, default none) | Reset a second time this long after the first. For an OS that lists a device before its driver has finished making it usable, so that a reset issued in that window finds nothing new. |

A backend that can't run on this machine raises an error when loaded (`error("…", 0)`); the message is shown in a
message box and the script stops.
