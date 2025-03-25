use clap::Parser;
use chrono::{Local, TimeZone};
use daemonize::Daemonize;
use humantime::parse_duration;
use native_dialog::MessageDialog;
use rodio::{Decoder, OutputStream, Sink, Source};
use rusqlite::{params, Connection, Result};
use std::thread::sleep;
use std::time::Duration;
use std::process;
use libc;
use std::io::{Write, Cursor};
use std::io::BufRead;

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

/// Returns the path to the SQLite database.
fn db_path() -> String {
    "/tmp/timer_cli.db".to_string()
}

/// Initialize the database and create tables if they do not exist.
fn init_db() -> Result<Connection> {
    let conn = Connection::open(db_path())?;
    conn.execute(
        "CREATE TABLE IF NOT EXISTS timer_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            duration TEXT NOT NULL,
            message TEXT,
            fg BOOLEAN NOT NULL
         )",
         [],
    )?;
    conn.execute(
        "CREATE TABLE IF NOT EXISTS active_timers (
            pid INTEGER PRIMARY KEY,
            started TEXT NOT NULL,
            duration TEXT NOT NULL,
            message TEXT
         )",
         [],
    )?;
    Ok(conn)
}

/// Log a timer creation into the timer_history table.
fn log_timer_creation_db(conn: &Connection, duration: &str, message: &str, fg: bool) -> Result<()> {
    let timestamp = Local::now().format("%Y-%m-%d %H:%M:%S").to_string();
    conn.execute(
        "INSERT INTO timer_history (timestamp, duration, message, fg) VALUES (?1, ?2, ?3, ?4)",
        params![timestamp, duration, message, fg],
    )?;
    Ok(())
}

/// Display the last `count` entries from the timer_history table.
fn show_history_db(count: usize) -> Result<()> {
    let conn = init_db()?;
    let mut stmt = conn.prepare(
        "SELECT timestamp, duration, message, fg FROM timer_history ORDER BY id DESC LIMIT ?1"
    )?;
    let history_iter = stmt.query_map(params![count as i64], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, String>(2)?,
            row.get::<_, bool>(3)?,
        ))
    })?;

    println!("{:<20} | {:<12} | {:<20} | {}", "Timestamp", "Duration", "Message", "Foreground");
    println!("{}", "-".repeat(70));
    for entry in history_iter {
        let (timestamp, duration, message, fg) = entry?;
        println!("{:<20} | {:<12} | {:<20} | {}", timestamp, duration, message, fg);
    }
    Ok(())
}

/// Register an active timer in the active_timers table.
fn register_active_timer_db(conn: &Connection, duration_str: &str, message: &str) -> Result<i32> {
    let pid = std::process::id() as i32;
    let started = Local::now().format("%Y-%m-%d %H:%M:%S").to_string();
    conn.execute(
        "INSERT OR REPLACE INTO active_timers (pid, started, duration, message) VALUES (?1, ?2, ?3, ?4)",
        params![pid, started, duration_str, message],
    )?;
    Ok(pid)
}

/// Unregister an active timer by deleting it from the active_timers table.
fn unregister_active_timer_db(conn: &Connection, pid: i32) -> Result<()> {
    conn.execute("DELETE FROM active_timers WHERE pid = ?1", params![pid])?;
    Ok(())
}

fn color(text: &str, name: &str) -> String {
    let code = match name.to_lowercase().as_str() {
        "red"     => 210,
        "green"   => 151,
        "yellow"  => 229,
        "blue"    => 153,
        "magenta" => 219,
        "cyan"    => 159,
        "orange"  => 215,
        "purple"  => 183,
        "pink"    => 218,
        "gray"           => 250,
        _ => 15, // default white
    };
    format!("\x1B[38;5;{}m{}\x1B[0m", code, text)
}

/// Signal handler for SIGINT to exit immediately.
extern "C" fn handle_sigint(_sig: i32) {
    process::exit(0);
}

/// Displays a live view of active timers with in-place updates using the active_timers table.
fn show_active_live_db() -> Result<()> {
    unsafe {
        libc::signal(libc::SIGINT, handle_sigint as usize);
    }

    let conn = init_db()?;

    use std::sync::mpsc;
    use std::io::{self, stdout};
    use std::thread;

    // Spawn a thread to read user input.
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || {
        let stdin = io::stdin();
        for line in stdin.lock().lines().flatten() {
            let trimmed = line.trim().to_string();
            if !trimmed.is_empty() {
                let _ = tx.send(trimmed);
            }
        }
    });

    let mut first_iteration = true;
    let mut last_lines = 0;

    loop {
        if !first_iteration {
            // Move cursor up and clear previous output.
            print!("\x1B[{}A", last_lines);
            for _ in 0..last_lines {
                print!("\x1B[2K\r\n");
            }
            print!("\x1B[{}A", last_lines);
        }
        first_iteration = false;
        let mut printed_lines = 0;

        println!("Active Timers:");
        printed_lines += 1;
        println!("{}", "-".repeat(70));
        printed_lines += 1;

        // Query active timers from the DB.
        let mut stmt = conn.prepare("SELECT pid, started, duration, message FROM active_timers ORDER BY pid")?;
        let active_iter = stmt.query_map([], |row| {
            Ok((
                row.get::<_, i32>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, String>(3)?,
            ))
        })?;

        let mut active_timers = Vec::new();
        for timer in active_iter {
            active_timers.push(timer?);
        }

        // Display each active timer and compute remaining time.
        for (index, (pid, started, duration_str, message)) in active_timers.iter().enumerate() {
            if let Ok(start_time) = chrono::NaiveDateTime::parse_from_str(&started, "%Y-%m-%d %H:%M:%S") {
                let start_time: chrono::DateTime<chrono::Local> =
                    chrono::Local.from_local_datetime(&start_time).unwrap();
                if let Ok(dur) = parse_duration(&duration_str) {
                    let end_time = start_time + chrono::Duration::from_std(dur).unwrap();
                    let now = chrono::Local::now();
                    let time_left = end_time - now;
                    if time_left.num_seconds() <= 0 {
                        let _ = conn.execute("DELETE FROM active_timers WHERE pid = ?1", params![pid]);
                        continue;
                    }
                    let secs = time_left.num_seconds();
                    let hours = secs / 3600;
                    let minutes = (secs % 3600) / 60;
                    let seconds = secs % 60;
                    let time_left_str = format!("\x1B[32m{:02}:{:02}:{:02} \x1B[0m", hours, minutes, seconds);
                    println!(
                        "{}: PID: {} | Started: {} | Duration: {} | Message: {} | Time Left: {}",
                        index + 1, color(&pid.to_string(), "red"), color(started, "purple"), color(duration_str, "blue"), color(message, "green"), time_left_str
                    );
                    printed_lines += 1;
                }
            }
        }

        println!();
        printed_lines += 1;
        println!("Enter number to kill and press enter (or Ctrl+C to exit): ");
        printed_lines += 1;

        stdout().flush().unwrap();

        // Process user input.
        if let Ok(input) = rx.try_recv() {
            if let Ok(num) = input.parse::<usize>() {
                if num > 0 && num <= active_timers.len() {
                    // Borrow the tuple so we don't move it.
                    let (pid, _started, _duration_str, _message) = &active_timers[num - 1];
                    unsafe {
                        libc::kill(*pid, libc::SIGTERM);
                    }
                    println!("Killed timer with PID {}", pid);
                    printed_lines += 1;
                    let _ = conn.execute("DELETE FROM active_timers WHERE pid = ?1", params![pid]);
                    sleep(Duration::from_secs(2));
                } else {
                    println!("Invalid selection.");
                    printed_lines += 1;
                    sleep(Duration::from_secs(2));
                }
            } else {
                println!("Invalid input.");
                printed_lines += 1;
                sleep(Duration::from_secs(2));
            }
        }

        last_lines = printed_lines;
        sleep(Duration::from_secs(1));
    }
}

/// Plays an embedded audio file in a loop while showing a pop-up dialog.
fn play_sound_with_dialog(popup_title: &str) {
    let audio_data: &[u8] = include_bytes!("../sounds/calm-loop-80576.mp3");
    let cursor = Cursor::new(audio_data);
    let (_stream, stream_handle) =
        OutputStream::try_default().expect("No audio output device available");
    let sink = Sink::try_new(&stream_handle).expect("Failed to create audio sink");
    let source = Decoder::new(cursor)
        .expect("Failed to decode audio")
        .repeat_infinite();
    sink.append(source);
    MessageDialog::new()
        .set_title(popup_title)
        .set_text("⌛")
        .show_alert()
        .unwrap();
    sink.stop();
}

/// Runs the timer, optionally with a live countdown (if live is true).
fn run_timer(duration: Duration, popup_message: String, live: bool) {
    if live {
        let spinner_chars = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
        let total_millis = duration.as_secs() * 1000;
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

    // Process history or live flags first.
    if let Some(count) = args.history {
        show_history_db(count).unwrap();
        return;
    }
    if args.live {
        show_active_live_db().unwrap();
        return;
    }

    // Timer mode: duration is required.
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

    let popup_message = match &args.message {
        Some(m) => m.clone(),
        None => "Time's up!".to_string(),
    };

    println!("Starting timer for {} seconds...", duration.as_secs());

    // If running in foreground, use the existing connection.
    if args.fg {
        let conn = init_db().expect("Failed to initialize database");
        log_timer_creation_db(&conn, &duration_str, &popup_message, true).unwrap();
        run_timer(duration, popup_message.clone(), true);
    } else {
        // Background mode: daemonize first and then open a new DB connection.
        let daemonize = Daemonize::new().working_directory(".").umask(0o027);
        match daemonize.start() {
            Ok(_) => {
                let conn = init_db().expect("Failed to initialize database after daemonizing");
                let pid = register_active_timer_db(&conn, &duration_str, &popup_message).unwrap();
                log_timer_creation_db(&conn, &duration_str, &popup_message, false).unwrap();
                run_timer(duration, popup_message.clone(), false);
                unregister_active_timer_db(&conn, pid).unwrap();
            }
            Err(e) => {
                eprintln!("Error daemonizing: {}", e);
                process::exit(1);
            }
        }
    }
}
