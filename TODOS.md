# ✅ Outstanding Tasks

---

## ⚙️ Features
- [ ] Add killall command so users don't have to stop a bunch of timers individually
  - [ ] Optionally: When killing tasks, keep their number assigned instead of shifting
    - e.g. when killing task 1 currently, task 2 then becomes 1. So if you kill 1 then 2, 2 is not found
    - ideal behavior: kill 1, then kill 2 
- [ ] Add user config yaml somewhere in system that can be updated via a settings command
- [ ] Add timer restart button (and including time that it will be restarted for) 
- [ ] Add timer snooze button (with drop-down if possible? Or set default in config)
- [ ] Config-based features
  - [ ] disable pop up on timer end
  - [ ] don't loop timer
  - [ ] change default timer message when left empty


## 🐞 Bugs
- [ ] ...


## 🏎️ Performance Improvements
- [ ] More graceful exit from `tt --live`.
  - 💭 Currently, takes multiple `ctrl + C` calls to exit and it's slow/clunky.
- [ ] Live view prints out status every second instead of replacing text in-place.
  - 💭 Foreground timer already updates in-place, should use similar approach if possible.
  - 💭 What about entering a temporary file like the interface for nano or vi so it doesn't clutter the terminal window with repeated logs?


## 🔮 Roadmap
- [ ] Create automated testing suite, so I don't have to manually test everything each time. 
- [ ] Refactor, clean up code, modularize into separate files.
- [ ] Create brew package / installation.
- [ ] Release to GitHub to allow open-source contributions.
- [ ] Add to `scrapple.io`
- [ ]
