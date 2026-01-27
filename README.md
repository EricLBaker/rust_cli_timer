# Timer CLI

Timer CLI is a lightweight command-line tool written in Rust that lets you set timers with custom durations and messages. When a timer finishes, a pop-up notification appears with your message and a looping sound is played. Timer events are logged to a history file for later review.

## Features

- **Custom Duration:** Specify durations (e.g., `2s`, `1min 30s`) for your timers.
- **Custom Message:** Include an optional message to display in the pop-up when the timer finishes.
- **Foreground/Background Mode:** Run timers in the foreground or as a daemon (background) so your terminal remains free.
- **History Logging:** Timer events are logged (timestamp, duration, message, background flag) to a history file.
- **View History:** Display the last _N_ timer events using the `--history` flag (defaults to 20 if omitted).
- **Custom Notification Image:** *Note:* Timer CLI currently uses `native_dialog` for its pop-up notifications, which does not support changing the image at the top of the dialog. To display a custom image, consider using a more advanced GUI library (e.g., GTK or egui) and updating the code accordingly.

## Installation

### Prerequisites

- [Rust](https://rustup.rs/) (Cargo)

### Build the Project

Clone the repository and navigate into the project folder:

```bash
git clone <repository_url>
cd timer_cli
```

Build the project in release mode:

```bash
cargo build --release
```

The binary is generated at `target/release/timer_cli`.

### Global Installation Options

#### Option 1: Copy the Binary to Your PATH

Copy the binary into a directory in your PATH (e.g., `/usr/local/bin`):

```bash
sudo cp target/release/timer_cli /usr/local/bin/
```

Now you can run `timer_cli` from anywhere.

#### Option 2: Use Cargo Install

Alternatively, install the tool globally with Cargo:

```bash
cargo install --path .
```

Ensure that your Cargo bin directory is in your PATH. If it’s not, add the following line to your `~/.zshrc`:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
```

Then reload your shell:

```bash
source ~/.zshrc
```

## Usage

### Starting a Timer

Run a timer with a duration and an optional message:

```bash
# Run a 4-second timer with the message "Test Timer"
timer_cli 4s "Test Timer"
```

Run a timer in foreground mode:

```bash
# Run a 4-second timer in foreground mode
timer_cli 4s "Test Timer" --fg
```

You can run multiple timers concurrently (in background mode they daemonize):

```bash
timer_cli 4s "Eat2" --fg && timer_cli 7s "Eat3" --fg && timer_cli 10s "Eat1" --fg
```

### Viewing Timer History

View the last 20 timer events (default):

```bash
timer_cli --history
```

Or view a different number of entries (e.g., last 5):

```bash
timer_cli --history 5
```

## Logging

Timer events are logged to `/tmp/timer_cli_history.log`. Each log entry contains:

```
YYYY-MM-DD HH:MM:SS | Duration: <duration> | Message: <message> | Background: <true/false>
```

## Custom Notification Image

*Note:* Timer CLI currently uses `native_dialog` for its pop-up notifications, which does not support changing the image at the top of the dialog.

## License

This project is licensed under the MIT License.
