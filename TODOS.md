# ✅ Outstanding Tasks

---

## ⚙️ Features

- [x] Add --active (live view) for active timers
- [x] Add --logs view for previous timers
- [x] Add kill option to live view to stop timers
- [x] Add timer restart button (and including time that it will be restarted for)
- [x] Add timer snooze button (with drop-down if possible? Or set default in config)
- [x] Optionally: When killing tasks, keep their number assigned instead of shifting
  - e.g. when killing task 1 currently, task 2 then becomes 1. So if you kill 1 then 2, 2 is not found
  - ideal behavior: kill 1, then kill 2
- [x] Add killall command so users don't have to stop a bunch of timers individually
- [x] Add shortcuts to buttons for quick restart, snooze, stop (Z, R, X)
- [ ] Add local (system time) parsing (e.g. 4:30pm)
- [ ] Add support for timezone datetime parsing (e.g. 4:30pm EST, PST, etc.)
- [ ] Add user config yaml somewhere in system that can be updated via a settings command

### Environment Variable Config

- [x] `TT_KEY_RESTART` - Key for restart (default: "r")
- [x] `TT_KEY_SNOOZE` - Key for snooze (default: "z")
- [x] `TT_KEY_STOP` - Key for stop (default: "s")
- [x] `TT_SNOOZE_TIME` - Snooze duration (default: "5m")
- [x] `TT_DEFAULT_DURATION` - Default timer if none specified
- [ ] `TT_SOUND_ENABLED` - Enable/disable sound (default: "1")
- [ ] `TT_SOUND_FILE` - Custom sound file path
- [ ] `TT_SOUND_VOLUME` - Volume 0-100 (default: "100")
- [ ] `TT_POPUP_ENABLED` - Enable/disable popup window (default: "1")
- [ ] `TT_THEME` - "dark" or "light" (default: "dark")
- [ ] `TT_BACKGROUND` - Run in background by default (default: "1")
- [x] `TT_COLOR_HEADER` - Color for timer header/duration (default: "green")
- [x] `TT_COLOR_MESSAGE` - Color for message text (default: "purple")
- [x] `TT_COLOR_TIME` - Color for time range (default: "gray")

## 🐞 Bugs

- [x] Starting 2 timers at once currently

## 🏆 Nice-to-haves

- [x] Clean up the design of the pop-up window, buttons, etc.
- [x] Live view prints out status every second instead of replacing text in-place.
  - 💭 Foreground timer already updates in-place, should use similar approach if possible.
  - 💭 What about entering a temporary file like the interface for nano or vi so it doesn't clutter the terminal window with repeated logs?
- [x] Improve formatting of `--history` for consistent col width
- [x] Make shortcuts less verbose and add color (e.g. [r] Restart)
- [x] Shorthand versions of each command (e.g. -a for active view, -h for history)
- [x] Improve formatting of `--active` for consistent col width
- [x] Make output more minimal and concise

## 🚀 Performance Improvements

- [x] More graceful exit from `tt --active`.
  - 💭 Currently, takes multiple `ctrl + C` calls to exit and it's slow/clunky.
- [x] Use local SqLite DB instead of parsing and storing history in txt file
- [ ] Quicker update to live view when killing 1 or more tasks. Currently, takes 1-2 seconds before they disappear.

## 🔮 Roadmap

- [ ] Create automated testing suite, so I don't have to manually test everything each time.
- [ ] Refactor, clean up code, modularize into separate files.
- [x] Create brew package / installation.
- [x] Release to GitHub to allow open-source contributions.
