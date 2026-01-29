# Terminal Timer (tt) CLI

A fast, cross-platform command-line timer with notifications and sound alerts.

```bash
tt 5m "Take a break"
```

<img src="https://github.com/EricLBaker/rust_cli_timer/raw/main/assets/terminal_timer_output.png" width="350" alt="Timer started output">

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

| Key | Action  | Description                                                   |
| --- | ------- | ------------------------------------------------------------- |
| `z` | Snooze  | Snooze for 5 minutes (configurable via `SNOOZE_TIME` env var) |
| `r` | Restart | Restart the timer with the original duration                  |
| `s` | Stop    | Dismiss the timer and stop the alarm                          |

> [!TIP]
> Set a custom snooze duration with the `SNOOZE_TIME` environment variable:
>
> ```bash
> export SNOOZE_TIME="10m"  # Snooze for 10 minutes instead of 5
> ```

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

### View History

```bash
# Show all timer history
tt -h                       # Short flag
tt --history                # Long flag

# Show last N timers
tt -h 5                     # Last 5 timers
tt --history 10             # Last 10 timers
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
