use clap::Parser;
use chrono::{Local, TimeZone};
use daemonize::Daemonize;
use humantime::parse_duration;
use native_dialog::MessageDialog;
use rodio::{Decoder, OutputStream, Sink, Source};
use std::fs::{OpenOptions, File};
use std::io::{Write, BufRead, BufReader, Cursor, Read};
use std::thread::sleep;
use std::time::Duration;
use std::process;
use libc;

/// CLI timer that can either run a timer or show history or a live view of active timers.
///
/// Run a timer with:
///   timer_cli [--fg] <duration> [message]
///
/// Show history with:
///   timer_cli --history [COUNT]
///
/// Show live view with:
///   timer_cli --live
#[derive(Parser)]
#[command(author, version, about)]
struct Args {
    /// Show the last N timer entries from history if N provided, else defaults to last 10.
    /// If provided, no timer is run.
    #[arg(long, value_name = "HISTORY", num_args = 0..=1, default_missing_value = "10")]
    history: Option<usize>,

    /// Show a live view of active timers.
    #[arg(long)]
    live: bool,

    /// Duration string (e.g., "2s", "1min 30 seconds"). Required if not using --history or --live.
    duration: Option<String>,

    /// Optional message to include in the alarm popup.
    message: Option<String>,

    /// Run timer in foreground.
    #[arg(short, long, default_value_t = false)]
    fg: bool,
}

/// Returns the path to the history log file.
/// This example uses a file in /tmp.
fn history_log_path() -> String {
    "/tmp/timer_cli_history.log".to_string()
}

/// Append a log entry for timer creation.
/// The log format is:
/// YYYY-MM-DD HH:MM:SS | CREATED | Duration: <duration> | Message: <message> | Foreground: <true/false>
fn log_timer_creation(duration: &str, message: &str, fg: bool) {
    let timestamp = Local::now().format("%Y-%m-%d %H:%M:%S").to_string();
    let new_line = format!("{} | {:<10} | {:<20} | {}\n", timestamp, duration, message, fg);
    let log_path = history_log_path();

    // Read existing content (if any)
    let mut old_content = String::new();
    if let Ok(mut file) = File::open(&log_path) {
        file.read_to_string(&mut old_content).ok();
    }

    // Write new log entry followed by old content
    let mut file = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(&log_path)
        .expect("Failed to open log file for writing");
    file.write_all(new_line.as_bytes())
        .expect("Failed to write new log line");
    file.write_all(old_content.as_bytes())
        .expect("Failed to write old log lines");
}

/// Reads the history log file and prints the last `count` entries in a table.
fn show_history(count: usize) {
    let log_path = history_log_path();
    let file = File::open(&log_path).unwrap_or_else(|_| {
        eprintln!("No history file found.");
        process::exit(1);
    });
    let reader = BufReader::new(file);
    let lines: Vec<_> = reader.lines().filter_map(|line| line.ok()).collect();

    println!(
        "{:<20} | {:<12} | {:<20} | {}",
        "Timestamp", "Duration", "Message", "Foreground"
    );
    println!("{}", "-".repeat(70));
    for line in lines.iter().take(count) {
        println!("{}", line);
    }
}

/// Registers an active timer by creating a file in /tmp/timer_cli_active.
fn register_active_timer(duration_str: &str, message: &str) -> std::io::Result<String> {
    let active_dir = "/tmp/timer_cli_active";
    std::fs::create_dir_all(active_dir)?;
    let pid = std::process::id();
    let now = Local::now().format("%Y-%m-%d %H:%M:%S").to_string();
    // Create an entry with timer details.
    let entry = format!("PID: {} | Started: {} | Duration: {} | Message: {}\n", pid, now, duration_str, message);
    let file_path = format!("{}/{}.timer", active_dir, pid);
    std::fs::write(&file_path, entry)?;
    Ok(file_path)
}

/// Unregisters an active timer by deleting its file.
fn unregister_active_timer(file_path: &str) {
    let _ = std::fs::remove_file(file_path);
}

/// Displays a live view of active timers by reading files from /tmp/timer_cli_active.
/// The view clears the screen completely on each refresh so that duplicate printing is avoided.
/// Expired timers are removed, and each active timer shows the remaining time (colored red).
fn show_active_live() {
    use std::sync::mpsc;
    use std::io::{self, BufRead, stdout};
    use std::thread;
    use std::time::Duration;

    let active_dir = "/tmp/timer_cli_active";

    // Spawn a thread to listen for user input without blocking the main loop.
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || {
        let stdin = io::stdin();
        for line in stdin.lock().lines() {
            if let Ok(input) = line {
                let trimmed = input.trim().to_string();
                if !trimmed.is_empty() {
                    // Send input to main thread.
                    let _ = tx.send(trimmed);
                }
            }
        }
    });

    loop {
        // Clear the screen and move cursor to the top.
        print!("\x1B[2J\x1B[H");
        println!("Active Timers:");
        println!("{}", "-".repeat(70));

        // Gather active timer files and sort them for consistent numbering.
        let mut active_files = Vec::new();
        if let Ok(entries) = std::fs::read_dir(active_dir) {
            for entry in entries.flatten() {
                active_files.push(entry.path());
            }
        }
        active_files.sort();

        // Display active timers with numbering.
        for (index, path) in active_files.iter().enumerate() {
            if let Ok(content) = std::fs::read_to_string(&path) {
                // Expected format:
                // PID: <pid> | Started: <YYYY-MM-DD HH:MM:SS> | Duration: <duration> | Message: <msg>
                let parts: Vec<&str> = content.split(" | ").collect();
                if parts.len() < 4 {
                    println!("{}: {}", index + 1, content.trim());
                    continue;
                }
                let pid_part = parts[0].trim();
                let started_part = parts[1].trim();
                let duration_part = parts[2].trim();
                let message_part = parts[3].trim();
                let start_str = started_part.strip_prefix("Started: ").unwrap_or("");
                let duration_str = duration_part.strip_prefix("Duration: ").unwrap_or("");
                let message = message_part.strip_prefix("Message: ").unwrap_or("");
                if let Ok(start_time) =
                    chrono::NaiveDateTime::parse_from_str(start_str, "%Y-%m-%d %H:%M:%S")
                {
                    let start_time: chrono::DateTime<chrono::Local> =
                        chrono::Local.from_local_datetime(&start_time).unwrap();
                    if let Ok(dur) = humantime::parse_duration(duration_str) {
                        let end_time = start_time + chrono::Duration::from_std(dur).unwrap();
                        let now = chrono::Local::now();
                        let time_left = end_time - now;
                        if time_left.num_seconds() <= 0 {
                            // Remove expired timer file.
                            let _ = std::fs::remove_file(&path);
                            continue;
                        }
                        let secs = time_left.num_seconds();
                        let hours = secs / 3600;
                        let minutes = (secs % 3600) / 60;
                        let seconds = secs % 60;
                        // Color the "Time Left" in red.
                        let time_left_str = format!(
                            "\x1B[31m{:02}:{:02}:{:02}\x1B[0m",
                            hours, minutes, seconds
                        );
                        println!(
                            "{}: {} | Started: {} | Duration: {} | Message: {} | Time Left: {}",
                            index + 1,
                            pid_part,
                            start_str,
                            duration_str,
                            message,
                            time_left_str
                        );
                    } else {
                        println!("{}: {}", index + 1, content.trim());
                    }
                } else {
                    println!("{}: {}", index + 1, content.trim());
                }
            }
        }

        // Prompt the user to enter a number to kill a timer.
        println!("\nEnter number to kill and press enter (or Ctrl+C to exit): ");
        stdout().flush().unwrap();

        // Check if there is user input available (non-blocking).
        if let Ok(input) = rx.try_recv() {
            if let Ok(num) = input.parse::<usize>() {
                if num > 0 && num <= active_files.len() {
                    let path = &active_files[num - 1];
                    // Read the file to get the PID.
                    if let Ok(content) = std::fs::read_to_string(&path) {
                        let parts: Vec<&str> = content.split(" | ").collect();
                        if !parts.is_empty() {
                            if let Some(pid_str) = parts[0].strip_prefix("PID: ") {
                                if let Ok(pid) = pid_str.trim().parse::<i32>() {
                                    // Send SIGTERM to the process.
                                    unsafe {
                                        libc::kill(pid, libc::SIGTERM);
                                    }
                                    println!("Killed timer with PID {}", pid);
                                }
                            }
                        }
                    }
                    // Remove the timer file.
                    let _ = std::fs::remove_file(&path);
                    // Pause briefly so the message is visible.
                    thread::sleep(Duration::from_secs(2));
                } else {
                    println!("Invalid selection.");
                    thread::sleep(Duration::from_secs(2));
                }
            } else {
                println!("Invalid input.");
                thread::sleep(Duration::from_secs(2));
            }
        }
        // Refresh the view every second.
        thread::sleep(Duration::from_secs(1));
    }
}

/// Plays an embedded audio file in a loop while displaying a pop-up dialog.
/// The sound continues until you dismiss the dialog.
///
/// NOTE: The current dialog uses native_dialog, which does not support custom images.
/// To change the image at the top of the timer's pop-up, consider using a different GUI library.
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
        .set_title(popup_title)
        .set_text("⌛")
        .show_alert()
        .unwrap();

    // Stop the audio when the dialog is dismissed.
    sink.stop();
}

/// Runs the timer, optionally with a live countdown (if `live` is true).
/// Logs the timer event immediately when the timer completes (before the popup).
/// Runs the timer, optionally with a live countdown (if `live` is true).
fn run_timer(duration: Duration, popup_message: String, live: bool) {
    if live {
        let spinner_chars = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
        // Convert duration to milliseconds.
        let total_millis = duration.as_secs() * 1000;
        // Update every 100ms.
        let update_interval = 100;
        let total_ticks = total_millis / update_interval;
        for tick in (0..=total_ticks).rev() {
            let remaining_millis = tick * update_interval;
            let seconds_remaining = remaining_millis / 1000;
            let hours = seconds_remaining / 3600;
            let minutes = (seconds_remaining % 3600) / 60;
            let seconds = seconds_remaining % 60;
            let spinner = spinner_chars[(tick as usize) % spinner_chars.len()];
            print!("\r\x1B[32mTime remaining: {:02}:{:02}:{:02} {} \x1B[0m", hours, minutes, seconds, spinner);
            std::io::stdout().flush().unwrap();
            sleep(Duration::from_millis(update_interval));
        }
        println!();
    } else {
        sleep(duration);
    }

    println!("Time's up!");
    play_sound_with_dialog(&popup_message);
}

fn main() {
    let args = Args::parse();

    // If history flag is provided, show history and exit.
    if let Some(count) = args.history {
        show_history(count);
        return;
    }

    // If live flag is provided, show the active timers live view and exit.
    if args.live {
        show_active_live();
        return;
    }

    // Otherwise, we expect a duration.
    let duration_str = args.duration.unwrap_or_else(|| {
        eprintln!("Duration string required unless using --history or --live");
        process::exit(1);
    });

    let duration = match parse_duration(&duration_str) {
        Ok(d) => d,
        Err(e) => {
            eprintln!("Error parsing duration: {}", e);
            process::exit(1);
        }
    };

    // Prepare the popup message.
    let popup_message = match &args.message {
        Some(m) => m.clone(),
        None => "Time's up!".to_string(),
    };

    println!("Starting timer for {} seconds...", duration.as_secs());

    // For foreground mode, log creation and run the timer normally.
    if args.fg {
        // Log timer creation only once upon submission.
        log_timer_creation(&duration_str, &popup_message, true);
        run_timer(duration, popup_message.clone(), true);
    } else {
        let daemonize = Daemonize::new()
            .working_directory(".")
            .umask(0o027);
        match daemonize.start() {
            Ok(_) => {
                let active_file = match register_active_timer(&duration_str, &popup_message) {
                    Ok(path) => path,
                    Err(e) => {
                        eprintln!("Error registering active timer: {}", e);
                        process::exit(1);
                    }
                };

                // Log timer creation for background timers.
                log_timer_creation(&duration_str, &popup_message, false);

                run_timer(duration, popup_message.clone(), false);
                unregister_active_timer(&active_file);
            }
            Err(e) => {
                eprintln!("Error daemonizing: {}", e);
                process::exit(1);
            }
        }
    }
}
