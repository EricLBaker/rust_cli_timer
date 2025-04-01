# ✅ Outstanding Tasks

---

## ⚙️ Features
- [X] Add --live view for active timers
- [X] Add --log view for previous timers
- [X] Add kill option to live view to stop timers
- [X] Add timer restart button (and including time that it will be restarted for) 
- [X] Add timer snooze button (with drop-down if possible? Or set default in config)
- [X] Optionally: When killing tasks, keep their number assigned instead of shifting
  - e.g. when killing task 1 currently, task 2 then becomes 1. So if you kill 1 then 2, 2 is not found
  - ideal behavior: kill 1, then kill 2
- [X] Add killall command so users don't have to stop a bunch of timers individually
- [X] Add shortcuts to buttons for quick restart, snooze, stop (Z, R, X)
- [ ] Add local (system time) parsing (e.g. 4:30pm)
- [ ] Add support for timezone datetime parsing (e.g. 4:30pm EST, PST, etc.)
- [ ] Add user config yaml somewhere in system that can be updated via a settings command
- [ ] Config-based features
  - [ ] disable pop up on timer end
  - [ ] don't loop timer endlessly (set timer ring length, e.g. stop after 10s)
  - [ ] change default timer message when left empty


## 🐞 Bugs
- [X] Starting 2 timers at once currently


## 🏆 Nice-to-haves
- [X] Clean up the design of the pop-up window, buttons, etc.
- [X] Live view prints out status every second instead of replacing text in-place.
  - 💭 Foreground timer already updates in-place, should use similar approach if possible.
  - 💭 What about entering a temporary file like the interface for nano or vi so it doesn't clutter the terminal window with repeated logs?
- [X] Improve formatting of `--log` for consistent col width
- [X] Make shortcuts less verbose and add color (e.g. [r] Restart)
- [ ] Improve formatting of `--live` for consistent col width


## 🚀 Performance Improvements
- [X] More graceful exit from `tt --live`.
  - 💭 Currently, takes multiple `ctrl + C` calls to exit and it's slow/clunky.
- [X] Use local SqLite DB instead of parsing and storing history in txt file
- [ ] Quicker update to live view when killing 1 or more tasks. Currently, takes 1-2 seconds before they disappear.

## 🔮 Roadmap
- [ ] Create automated testing suite, so I don't have to manually test everything each time. 
- [ ] Refactor, clean up code, modularize into separate files.
- [ ] Create brew package / installation.
- [ ] Release to GitHub to allow open-source contributions.
- [ ] Add to `scrapple.io`
