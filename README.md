# Terminal Timer (tt) CLI

A fast, cross-platform command-line timer with notifications and sound alerts.

```bash
tt 25m "Pomodoro"
```

<img src="https://github.com/EricLBaker/rust_cli_timer/raw/main/assets/tt_output_pomodoro.png" width="350" alt="Timer started output">

<br>

## Install

**macOS / Linux / WSL:**

```bash
curl -fsSL https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/install.sh | bash
```

**Windows (PowerShell):**

```powershell
iwr -useb https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/install.ps1 | iex
```

**Using Cargo**

```shell
cargo install --git https://github.com/EricLBaker/rust_cli_timer
```

The installer automatically:

- Downloads the binary (or builds from source if needed)
- Adds it to your PATH
- Creates the `tt` alias

<details>
<summary>Install a specific version</summary>

**macOS / Linux / WSL:**

```bash
curl -fsSL https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/install.sh | bash -s -- --version v1.0.8
```

**Windows (PowerShell):**

```powershell
# Download and run with version parameter
$script = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/install.ps1" -UseBasicParsing
& ([scriptblock]::Create($script.Content)) -Version v1.0.8
```

</details>

<details>
<summary>Uninstall</summary>

**macOS / Linux / WSL:**

```bash
curl -fsSL https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/uninstall.sh | bash
```

**Windows (PowerShell):**

```powershell
iwr -useb https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/uninstall.ps1 | iex
```

</details>

<details>
<summary>Build from source</summary>

Requires [Rust](https://rustup.rs/):

```bash
cargo install --git https://github.com/EricLBaker/rust_cli_timer.git
```

</details>

<br>

## Platforms

| Platform                         | Status       |
| -------------------------------- | ------------ |
| 🍎 macOS (Intel & Apple Silicon) | ✅ Supported |
| 🪟 Windows                       | ✅ Supported |
| 🐧 Linux                         | ✅ Supported |

<br>

## Features

| Feature               | Description                      |
| --------------------- | -------------------------------- |
| ⏱️ Flexible durations | `30s`, `5m`, `1h30m`, `2h15m30s` |
| 💬 Custom messages    | Optional notification text       |
| 🔔 Sound alerts       | Looping alarm until dismissed    |
| 📋 History log        | Look back through your timers    |
| 🖥️ Background mode    | Default - doesn't block terminal |
| 👁️ Foreground mode    | Shows live countdown             |
| 🔄 Update check       | Check for new versions with `-u` |

<br>

## Timer Popup

When a timer finishes, a popup window appears with your message and a looping sound alert:

<img src="https://github.com/EricLBaker/rust_cli_timer/raw/main/assets/popup.png" width="400" alt="Timer popup window">

### Keyboard Shortcuts

| Key | Action  | Description                          |
| --- | ------- | ------------------------------------ |
| `z` | Snooze  | Snooze (default 5 min, configurable) |
| `r` | Restart | Restart with the original duration   |
| `s` | Stop    | Dismiss the timer and stop the alarm |

> [!TIP]
> All keys and durations are configurable via environment variables. See [Environment Variables](#environment-variables) below.

<br>

## Usage

### Start a Timer

```bash
# Basic timer
tt 30s                      # 30 seconds
tt 5m                       # 5 minutes
tt 1h30m                    # 1 hour 30 minutes

# With a message
tt 25m "Focus time"         # Shows message in notification

# Foreground mode (blocks terminal, shows countdown)
tt 10s -f                   # Short flag
tt 10s --fg                 # Long flag
```

### View Logs

```bash
# Show previous timer logs
tt -l                       # Short flag
tt --logs                   # Long flag

# Show last N timers
tt -l 5                     # Last 5 timers
tt --logs 10                # Last 10 timers
```

### Other Commands

```bash
# Show version
tt -v                       # Short flag
tt --version                # Long flag

# Check for updates
tt -u                       # Short flag
tt --update                 # Long flag

# View and manage active timers
tt -a                       # Short flag
tt --active                 # Long flag
# In active view: type timer ID to kill it, 'all' to kill all, Ctrl+C to exit
```

### Examples

```bash
# Pomodoro technique (foreground mode so they run sequentially)
tt 25m "Work session" -f && tt 5m "Break time" -f

# Cooking timers
tt 3m "Check branch deploy" -f
tt 45m "Check if pipeline finished"

# Quick reminder
tt 1h "Stand up and stretch"
```

<br>

> [!TIP]
> Custom Aliases
>
> Add these to your `~/.zshrc` or `~/.bashrc` for quick shortcuts:
>
> ```bash
> # Pomodoro technique - 25min work, 5min break
> alias pom='tt 25m "Work session" -f && tt 5m "Break time" -f'
>
> # Long pomodoro - 50min work, 10min break
> alias lpom='tt 50m "Deep work" -f && tt 10m "Long break" -f'
>
> # Quick breaks
> alias stretch='tt 1h "Stand up and stretch"'
> ```

<br>

## Environment Variables

Customize timer behavior by setting these environment variables in your shell configuration (`~/.zshrc`, `~/.bashrc`, etc.):

| Variable              | Default  | Description                             |
| --------------------- | -------- | --------------------------------------- |
| `TT_SNOOZE_TIME`      | `5m`     | Duration for snooze (e.g., `10m`, `1h`) |
| `TT_DEFAULT_DURATION` | —        | Default timer if no duration specified  |
| `TT_KEY_SNOOZE`       | `z`      | Key to trigger snooze action            |
| `TT_KEY_RESTART`      | `r`      | Key to restart the timer                |
| `TT_KEY_STOP`         | `s`      | Key to stop/dismiss the timer           |
| `TT_COLOR_HEADER`     | `green`  | Color for timer icon & duration         |
| `TT_COLOR_MESSAGE`    | `purple` | Color for message text                  |
| `TT_COLOR_TIME`       | `gray`   | Color for time range display            |

Available colors: `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `orange`, `purple`, `pink`, `gray`, `white`

### Examples

```bash
# Add to ~/.zshrc or ~/.bashrc

# Set snooze to 10 minutes instead of 5
export TT_SNOOZE_TIME="10m"

# Default to 25-minute pomodoro if no duration given
export TT_DEFAULT_DURATION="25m"

# Use vim-style keys: j=snooze, k=restart, l=stop
export TT_KEY_SNOOZE="j"
export TT_KEY_RESTART="k"
export TT_KEY_STOP="l"

# Custom color scheme
export TT_COLOR_HEADER="pink"
export TT_COLOR_MESSAGE="blue"
export TT_COLOR_TIME="purple"
```

<br>

## Updating

Check if a new version is available:

```bash
tt -u
```

<br>

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, build instructions, and release process.

<br>

## License

MIT
