use clap::Parser;
use chrono::Local;
use daemonize::Daemonize;
use humantime::parse_duration;
use native_dialog::MessageDialog;
use rodio::{Decoder, OutputStream, Sink, Source};
use std::fs::{OpenOptions, File};
use std::io::{stdout, Write, BufRead, BufReader, Cursor};
use std::thread::sleep;
use std::time::Duration;

/// CLI timer that can either run a timer or show history.
///
/// Run a timer with:
///   timer_cli [--fg] <duration> [message]
///
/// Show history with:
///   timer_cli --history [COUNT]
#[derive(Parser)]
#[command(author, version, about)]
struct Args {
    /// Show the last N timer entries from history if N provided, else defaults to last 20.
    /// If provided, no timer is run.
    #[arg(long, value_name = "HISTORY", num_args = 0..=1, default_missing_value = "20")]
    history: Option<usize>,

    /// Duration string (e.g., "2s", "1min 30 seconds"). Required if not showing history.
    duration: Option<String>,

    /// Optional message to include in the alarm popup.
    message: Option<String>,

    /// Run timer in foreground
    #[arg(short, long, default_value_t = false)]
    fg: bool,
}

/// Returns the path to the history log file.
/// This example uses a file in /tmp.
fn history_log_path() -> String {
    "/tmp/timer_cli_history.log".to_string()
}

/// Append a log entry to the history log file.
/// The log format is:
/// YYYY-MM-DD HH:MM:SS | Duration: <duration> | Message: <message> | Background: <true/false>
fn log_timer_event(duration: &str, message: &str, bg: bool) {
    let timestamp = Local::now().format("%Y-%m-%d %H:%M:%S").to_string();
    let log_line = format!(
        "{} | {:<10} | {:<20} | {}\n",
        timestamp, duration, message, bg
    );
    let log_path = history_log_path();
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(log_path)
        .expect("Failed to open log file");
    file.write_all(log_line.as_bytes())
        .expect("Failed to write to log file");
}

/// Reads the history log file and prints the last `count` entries in a table.
fn show_history(count: usize) {
    let log_path = history_log_path();
    let file = File::open(&log_path).unwrap_or_else(|_| {
        eprintln!("No history file found.");
        std::process::exit(1);
    });
    let reader = BufReader::new(file);
    let lines: Vec<_> = reader.lines().filter_map(Result::ok).collect();
    let total = lines.len();
    let start = if total > count { total - count } else { 0 };

    println!(
        "{:<20} | {:<12} | {:<20} | {}",
        "Timestamp", "Duration", "Message", "Background"
    );
    println!("{}", "-".repeat(70));
    for line in &lines[start..] {
        // Each line is already formatted as our log entry.
        println!("{}", line);
    }
}

/// Plays an embedded audio file in a loop while displaying a pop-up dialog.
/// The sound continues until you dismiss the dialog.
///
/// # Arguments
/// * `popup_title` - The title of the popup (e.g. the message).
fn play_sound_with_dialog(popup_title: &str) {
    // Include the sound file at compile time.
    let audio_data: &[u8] = include_bytes!("../sounds/calm-loop-80576.mp3");
    let cursor = Cursor::new(audio_data);

    // Initialize the audio output.
    let (_stream, stream_handle) =
        OutputStream::try_default().expect("No audio output device available");
    let sink = Sink::try_new(&stream_handle).expect("Failed to create audio sink");

    // Create a source that repeats indefinitely.
    let source = Decoder::new(cursor)
        .expect("Failed to decode audio")
        .repeat_infinite();

    // Append the looping source to the sink.
    sink.append(source);

    // Show a pop-up dialog.
    MessageDialog::new()
        .
        .set_title(popup_title)
        .set_text("⌛")
        .show_alert()
        .unwrap();

    // Stop the audio when the dialog is dismissed.
    sink.stop();
}

/// Runs the timer, optionally with a live countdown (if `live` is true).
/// Logs the timer event immediately when the timer completes (before the popup).
fn run_timer(duration: Duration, duration_str: &str, popup_message: String, live: bool, bg: bool) {
    if live {
        // Live countdown loop.
        for remaining in (0..=duration.as_secs()).rev() {
            let hours = remaining / 3600;
            let minutes = (remaining % 3600) / 60;
            let seconds = remaining % 60;
            print!("\rTime remaining: {:02}:{:02}:{:02}", hours, minutes, seconds);
            stdout().flush().unwrap();
            sleep(Duration::from_secs(1));
        }
        println!();
    } else {
        // Background mode: simply sleep for the full duration.
        sleep(duration);
    }

    println!("Time's up!");
    // Log the event immediately when the timer completes.
    log_timer_event(duration_str, &popup_message, bg);
    play_sound_with_dialog(&popup_message);
}

fn main() {
    let args = Args::parse();

    // If the history flag is provided, show history and exit.
    if let Some(count) = args.history {
        show_history(count);
        return;
    }

    // Otherwise, we expect a duration.
    let duration_str = args.duration.unwrap_or_else(|| {
        eprintln!("Duration string required unless using --history");
        std::process::exit(1);
    });

    let duration = match parse_duration(&duration_str) {
        Ok(d) => d,
        Err(e) => {
            eprintln!("Error parsing duration: {}", e);
            std::process::exit(1);
        }
    };

    // Prepare the popup message.
    let popup_message = match &args.message {
        Some(m) => format!("{}", m),
        None => "Time's up!".to_string(),
    };

    println!("Starting timer for {} seconds...", duration.as_secs());

    // Decide whether to run in foreground or background.
    if args.fg {
        run_timer(duration, &duration_str, popup_message.clone(), true, false);
    } else {
        // Daemonize without locking a pid file so multiple timers can run concurrently.
        let daemonize = Daemonize::new()
            .working_directory(".")
            .umask(0o027);
        match daemonize.start() {
            Ok(_) => {
                run_timer(duration, &duration_str, popup_message.clone(), false, true);
            }
            Err(e) => {
                eprintln!("Error daemonizing: {}", e);
                std::process::exit(1);
            }
        }
    }
}
