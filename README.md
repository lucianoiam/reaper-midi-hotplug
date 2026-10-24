# MIDI hotplug for REAPER

REAPER on Windows and Linux does not notice MIDI devices that are plugged in or unplugged while it runs: a new
device stays unavailable, and an unplugged one stays dead, until you run **Options › Reset all MIDI devices**.
This script runs in the background and does that reset for you, a couple of seconds after the set of MIDI devices
changes.

macOS doesn't need it: REAPER reconnects MIDI devices there by itself as soon as they become available.

## Install
Copy the `MIDI` folder into `Scripts` in your REAPER resource path (Options › Show REAPER resource path…), then
load `MIDI hotplug.lua` and `MIDI hotplug - Start with REAPER.lua` with Actions › Show action list › New action ›
Load ReaScript. Run the action **MIDI hotplug** once. It asks whether to start automatically with REAPER; answer
Yes and you're done.

With [ReaPack](https://reapack.com), which also keeps the script updated:
1. Extensions › ReaPack › Import repositories…, paste
   `https://github.com/lucianoiam/reaper-midi-hotplug/raw/master/index.xml`.
2. Extensions › ReaPack › Browse packages, find **MIDI hotplug**, install.
3. Run the action **MIDI hotplug** once and answer Yes as above.

## Actions
- **MIDI hotplug**: start or stop the watcher. It's an on/off action, so it can sit on a toolbar as a button that
  lights up while it runs.
- **MIDI hotplug - Start with REAPER**: switch automatic start on or off. It adds or removes a single tagged line
  in `Scripts/__startup.lua` and never touches anything else in that file.

## How devices are detected
| Platform | Detects |
|---|---|
| Windows 10 2004+ | connected devices of the MEDIA class (`pnputil /enum-devices`), which holds audio devices as well, so a hot-pluggable one of those also causes a reset |
| Linux, ALSA or PipeWire (JACK) audio | ALSA raw MIDI devices (`/dev/snd/midiC*D*`), which appear before PipeWire publishes its MIDI bridge ports |

The reset comes up to 6 s after the change on Windows and up to 3 s on Linux. On Windows it is done a second time
4 s later, because `pnputil` can report a device as connected before its class driver has finished registering it
and a reset issued in that window finds nothing new.

## Layout
- `MIDI/MIDI hotplug.lua`: the main action; its header carries the script's description, version and changelog.
- `MIDI/MIDI hotplug - Start with REAPER.lua`: the start-with-REAPER switch.
- `MIDI/lib/core.lua`: platform-independent watcher (poll, settle, reset).
- `MIDI/lib/platform/{windows,linux}.lua`: one backend per OS; interface in `MIDI/lib/platform/README.md`.
- `MIDI/lib/background.lua`: runs a system command without blocking REAPER.
- `MIDI/lib/startup.lua`: the tagged `__startup.lua` line.
- `tests/run.lua`: tests with a fake `reaper` API: `lua5.4 tests/run.lua` from the repository root.
- `index.xml`: the ReaPack index.

## Credits
Designed by [lucianoiam](https://github.com/lucianoiam), written by
[Claude](https://claude.com/claude-code) (Anthropic's AI coding assistant).

## License
MIT, see `LICENSE`.
