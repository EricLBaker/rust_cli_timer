use clap::Parser;
use chrono::{Local, TimeZone};
use humantime::{parse_duration};
use rodio::{Decoder, OutputStream, Sink, Source};
use rusqlite::{params, Connection, Result};
use std::thread::sleep;
use std::time::Duration;
use std::process;
use std::io::{Write, Cursor, BufRead};
use std::process::Command;
#[cfg(windows)]
use std::os::windows::process::CommandExt;
use eframe::{egui, App};
use egui::{Color32, FontId, TextFormat, WidgetText};
use egui::text::LayoutJob;

/// Cross-platform process termination
fn kill_process(pid: i32) {
    #[cfg(unix)]
    {
        unsafe {
            libc::kill(pid, libc::SIGTERM);
        }
    }
    #[cfg(windows)]
    {
        unsafe {
            let handle = windows_sys::Win32::System::Threading::OpenProcess(
                windows_sys::Win32::System::Threading::PROCESS_TERMINATE,
                0,
                pid as u32,
            );
            if handle != 0 {
                windows_sys::Win32::System::Threading::TerminateProcess(handle, 1);
                windows_sys::Win32::Foundation::CloseHandle(handle);
            }
        }
    }
}

fn styled_button_label(shortcut: &str, color: Color32, label: &str) -> WidgetText {
    let mut job = LayoutJob::default();

    // Style the shortcut portion, e.g. "[ z ]"
    job.append(
        shortcut,
        0.0,
        TextFormat {
            font_id: FontId::proportional(16.0),
            color,
            ..Default::default()
        },
    );

    // Style the rest of the label normally
    job.append(
        label,
        0.0,
        TextFormat {
            font_id: FontId::proportional(16.0),
            color: Color32::WHITE,
            ..Default::default()
        },
    );

    WidgetText::from(job)
}

/// Returns the snooze duration and the original string from the SNOOZE_TIME environment variable.
/// If SNOOZE_TIME is not set or cannot be parsed, it defaults to 5 minutes ("5m").
fn get_snooze_duration_and_str() -> (Duration, String) {
    if let Ok(s) = std::env::var("SNOOZE_TIME") {
        if let Ok(dur) = parse_duration(&s) {
            (dur, s)
        } else {
            let default = Duration::from_secs_f64(5.0 * 60.0);
            (default, "5m".to_string())
        }
    } else {
        let default = Duration::from_secs_f64(5.0 * 60.0);
        (default, "5m".to_string())
    }
}

/// CLI timer that can either run a timer, show history, or a live view of active timers.
///
/// Run a timer with:
///   timer_cli [--fg] <duration> [message]
///
/// Show history with:
///   timer_cli --history [COUNT] or timer_cli -h [COUNT]
///
/// Show live view with:
///   timer_cli --view or timer_cli -v
#[derive(Parser)]
#[command(author, version, about)]
struct Args {
    /// Show the last N timer entries from history if provided (defaults to 10)
    #[arg(short='h', long, value_name = "HISTORY", num_args = 0..=1, default_missing_value = "10")]
    history: Option<usize>,

    /// Show a live view of active timers.
    #[arg(short='v', long)]
    view: bool,

    /// Duration string (e.g., "2s", "1min 30s", "90m"). Required if not using --history or --view.
    duration: Option<String>,

    /// Optional message to include in the alarm popup.
    message: Option<String>,

    /// Run timer in foreground.
    #[arg(short, long, default_value_t = false)]
    fg: bool,

    /// Internal flag: indicates this process was spawned as a background child (hidden from help).
    #[arg(long, hide = true, default_value_t = false)]
    background_child: bool,
}

/// Returns the path to the SQLite database.
fn db_path() -> String {
    if cfg!(windows) {
        let temp = std::env::var("TEMP")
            .or_else(|_| std::env::var("TMP"))
            .unwrap_or_else(|_| ".".to_string());
        format!("{}\\timer_cli.db", temp)
    } else {
        "/tmp/timer_cli.db".to_string()
    }
}

/// Initialize the database and create tables if they do not exist.
///
/// The active_timers table uses an autoincrement primary key (id)
/// and stores the process id (pid) separately.
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
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pid INTEGER,
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
    use textwrap::{fill, Options};

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

    // Set maximum column widths
    let timestamp_width = 20;
    let duration_width = 12;
    let message_width = 40;

    println!(
        "{:<timestamp_width$} | {:<duration_width$} | {:<message_width$} | {}",
        "Timestamp",
        "Duration",
        "Message",
        "Foreground",
        timestamp_width = timestamp_width,
        duration_width = duration_width,
        message_width = message_width
    );
    println!("{}", "-".repeat(timestamp_width + duration_width + message_width + 20));

    for entry in history_iter {
        let (timestamp, duration, message, fg) = entry?;
        // Wrap the duration and message to the desired widths
        let wrapped_duration = fill(&duration, Options::new(duration_width));
        let wrapped_message = fill(&message, Options::new(message_width));

        // Split wrapped text into lines so we can print multiple lines if needed.
        let duration_lines: Vec<&str> = wrapped_duration.lines().collect();
        let message_lines: Vec<&str> = wrapped_message.lines().collect();
        let num_lines = duration_lines.len().max(message_lines.len()).max(1);

        // Print first line with timestamp and foreground flag
        println!(
            "{:<timestamp_width$} | {:<duration_width$} | {:<message_width$} | {}",
            timestamp,
            duration_lines.get(0).unwrap_or(&""),
            message_lines.get(0).unwrap_or(&""),
            fg,
            timestamp_width = timestamp_width,
            duration_width = duration_width,
            message_width = message_width,
        );

        // For additional wrapped lines, print empty strings for timestamp and foreground columns.
        for i in 1..num_lines {
            println!(
                "{:<timestamp_width$} | {:<duration_width$} | {:<message_width$} | {}",
                "",
                duration_lines.get(i).unwrap_or(&""),
                message_lines.get(i).unwrap_or(&""),
                "",
                timestamp_width = timestamp_width,
                duration_width = duration_width,
                message_width = message_width,
            );
        }
    }
    Ok(())
}

/// Inserts a new active timer record into active_timers.
/// Returns the newly inserted record’s id.
fn register_active_timer_db(conn: &Connection, duration_str: &str, message: &str) -> Result<i64> {
    let pid = process::id() as i32;
    let started = Local::now().format("%Y-%m-%d %H:%M:%S").to_string();
    conn.execute(
        "INSERT INTO active_timers (pid, started, duration, message) VALUES (?1, ?2, ?3, ?4)",
        params![pid, started, duration_str, message],
    )?;
    Ok(conn.last_insert_rowid())
}

/// Unregister an active timer by deleting it from the active_timers table, given its record id.
fn unregister_active_timer_db(conn: &Connection, active_id: i64) -> Result<()> {
    conn.execute("DELETE FROM active_timers WHERE id = ?1", params![active_id])?;
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
        "gray"    => 250,
        _ => 15,
    };
    format!("\x1B[38;5;{}m{}\x1B[0m", code, text)
}

/// Signal handler for SIGINT to exit immediately.
#[cfg(unix)]
extern "C" fn handle_sigint(_sig: i32) {
    process::exit(0);
}

/// Windows console control handler for Ctrl+C
#[cfg(windows)]
unsafe extern "system" fn handle_ctrl_c(ctrl_type: u32) -> i32 {
    if ctrl_type == windows_sys::Win32::System::Console::CTRL_C_EVENT {
        process::exit(0);
    }
    0
}

/// Displays a live view of active timers using the active_timers table.
/// Rows are keyed by an autoincrement id.
fn show_active_timer_db() -> Result<()> {
    #[cfg(unix)]
    unsafe {
        libc::signal(libc::SIGINT, handle_sigint as usize);
    }
    #[cfg(windows)]
    unsafe {
        windows_sys::Win32::System::Console::SetConsoleCtrlHandler(Some(handle_ctrl_c), 1);
    }
    let conn = init_db()?;
    use std::sync::mpsc;
    use std::io::{self, stdout};
    use std::thread;
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
            print!("\x1B[{}A", last_lines);
            for _ in 0..last_lines {
                print!("\x1B[2K\r\n");
            }
            print!("\x1B[{}A", last_lines);
        }
        first_iteration = false;
        let mut printed_lines = 0;
        println!("{}", color("Active Timers:", "gray"));
        printed_lines += 1;
        println!("{}", "-".repeat(100));
        printed_lines += 1;

        // Query active timers from the DB.
        let mut stmt = conn.prepare("SELECT id, pid, started, duration, message FROM active_timers ORDER BY id")?;
        let active_iter = stmt.query_map([], |row| {
            Ok((
                row.get::<_, i64>(0)?,
                row.get::<_, i32>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, String>(3)?,
                row.get::<_, String>(4)?,
            ))
        })?;
        let mut active_timers = Vec::new();
        for timer in active_iter {
            active_timers.push(timer?);
        }

        // Display each active timer and compute remaining time.
        for (id, pid, started, duration_str, message) in active_timers.iter() {
            if let Ok(start_time) = chrono::NaiveDateTime::parse_from_str(&started, "%Y-%m-%d %H:%M:%S") {
                let start_time: chrono::DateTime<chrono::Local> =
                    chrono::Local.from_local_datetime(&start_time).unwrap();
                if let Ok(dur) = parse_duration(&duration_str) {
                    let end_time = start_time + chrono::Duration::from_std(dur).unwrap();
                    let now = chrono::Local::now();
                    let time_left = end_time - now;
                    if time_left.num_seconds() <= 0 {
                        let _ = conn.execute("DELETE FROM active_timers WHERE id = ?1", params![id]);
                        continue;
                    }
                    let secs = time_left.num_seconds();
                    let hours = secs / 3600;
                    let minutes = (secs % 3600) / 60;
                    let seconds = secs % 60;
                    let time_left_str = format!("\x1B[32m{:02}:{:02}:{:02} \x1B[0m", hours, minutes, seconds);
                    println!(
                        "ID: {} [PID: {}] | Started: {} | Duration: {} | Message: {} | Time Left: {}",
                        color(&id.to_string(), "red"),
                        pid,
                        color(started, "blue"),
                        color(duration_str, "pink"),
                        color(message, "purple"),
                        time_left_str
                    );
                    printed_lines += 1;
                }
            }
        }
        println!();
        printed_lines += 1;
        println!("{} {}", color("Type an ID to kill, or 'all'", "gray"), color("[ Ctrl+C to exit ]", "gray"));
        printed_lines += 1;

        stdout().flush().unwrap();

        // Process user input.
        if let Ok(input) = rx.try_recv() {
            if input.eq_ignore_ascii_case("all") {
                let mut stmt = conn.prepare("SELECT pid FROM active_timers")?;
                let mut rows = stmt.query([])?;
                while let Some(row) = rows.next()? {
                    let pid: i32 = row.get(0)?;
                    kill_process(pid);
                }
                conn.execute("DELETE FROM active_timers", [])?;
                println!("Killed all active timers.");
                printed_lines += 2;
                sleep(Duration::from_secs(2));
            }
            else if let Ok(active_id) = input.parse::<i64>() {
                let mut stmt = conn.prepare("SELECT pid FROM active_timers WHERE id = ?1")?;
                let mut rows = stmt.query(params![active_id])?;
                if let Some(row) = rows.next()? {
                    let pid: i32 = row.get(0)?;
                    kill_process(pid);
                    println!("Killed timer with PID {}", pid);
                    printed_lines += 2;
                    let _ = conn.execute("DELETE FROM active_timers WHERE id = ?1", params![active_id]);
                    sleep(Duration::from_secs(2));
                } else {
                    println!("No active timer with that ID.");
                    printed_lines += 2;
                    sleep(Duration::from_secs(2));
                }
            } else {
                println!("Invalid input.");
                printed_lines += 2;
                sleep(Duration::from_secs(2));
            }
        }
        last_lines = printed_lines;
        sleep(Duration::from_secs(1));
    }
}

/// Plays a looping sound and returns both the OutputStream and Sink.
fn play_sound_loop() -> (OutputStream, Sink) {
    let audio_data: &[u8] = include_bytes!("../sounds/calm-loop-80576.mp3");
    let cursor = Cursor::new(audio_data);
    let (stream, stream_handle) = OutputStream::try_default().expect("No audio output device");
    let sink = Sink::try_new(&stream_handle).expect("Failed to create sink");
    let source = Decoder::new(cursor).expect("Failed to decode").repeat_infinite();
    sink.append(source);
    (stream, sink)
}

/// Enum for the timer actions.
#[derive(PartialEq)]
pub enum TimerAction {
    Snooze,
    Restart,
    Stop,
}

/// Struct for the GUI popup.
pub struct TimerPopup {
    pub sender: Option<std::sync::mpsc::Sender<TimerAction>>,
    pub message: String,
}

/// Implement the eframe App for TimerPopup with custom styling.
/// This version centers the window and buttons and auto-sizes to its content.
/// The window title is set to an empty string so that the custom message is shown at the top.
impl App for TimerPopup {
    fn update(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) {
        if ctx.input(|i| i.key_pressed(egui::Key::Z)) {
            if let Some(s) = self.sender.take() {
                let _ = s.send(TimerAction::Snooze);
            }
            frame.close();
        } else if ctx.input(|i| i.key_pressed(egui::Key::R)) {
            if let Some(s) = self.sender.take() {
                let _ = s.send(TimerAction::Restart);
            }
            frame.close();
        } else if ctx.input(|i| i.key_pressed(egui::Key::X)) {
            if let Some(s) = self.sender.take() {
                let _ = s.send(TimerAction::Stop);
            }
            frame.close();
        }

    egui::Window::new("Time's Up!")
        .collapsible(false)
        .resizable(true)
        .anchor(egui::Align2::CENTER_CENTER, egui::Vec2::ZERO)
        .show(ctx, |ui| {
            // Full width
            ui.set_min_width(ui.available_width());

            ui.vertical_centered(|ui| {
                if self.message.len() > 0 {
                    ui.add_space(25.0);
                }
                ui.colored_label(egui::Color32::LIGHT_GREEN, &self.message);
                ui.add_space(20.0);

                let (_snooze_duration, snooze_str) = get_snooze_duration_and_str();
                let buttons = [
                    (
                        styled_button_label("[ z ] ", Color32::from_rgb(128, 128, 255), &format!("Snooze ({})", snooze_str)),
                        TimerAction::Snooze,
                    ),
                    (
                        styled_button_label("[ r ] ", Color32::from_rgb(0, 255, 128), "Restart"),
                        TimerAction::Restart,
                    ),
                    (
                        styled_button_label("[ x ] ", Color32::from_rgb(255, 0, 0), "Stop"),
                        TimerAction::Stop,
                    ),
                ];

                for (label, action) in buttons {
                    if ui.add_sized(egui::vec2(150.0, 40.0), egui::Button::new(label)).clicked() {
                        if let Some(s) = self.sender.take() {
                            let _ = s.send(action);
                        }
                        frame.close();
                    }
                    ui.add_space(25.0);
                }
            });
        });
    }
}

/// In popup mode, run the GUI popup and print the action to stdout.
fn run_popup() {
    let args: Vec<String> = std::env::args().collect();
    let message = if let Some(pos) = args.iter().position(|a| a == "--message") {
        if pos + 1 < args.len() {
            args[pos + 1].clone()
        } else {
            "".to_string()
        }
    } else {
        "".to_string()
    };
    let (tx, rx) = std::sync::mpsc::channel();
    let app = TimerPopup { sender: Some(tx), message };
    let native_options = eframe::NativeOptions {
        initial_window_size: Some(egui::vec2(400.0, 350.0)),
        resizable: true,
        ..Default::default()
    };
    // Use a fixed window title "Terminal Timer"
    let _ = eframe::run_native("Terminal Timer",
        native_options,
        Box::new(move |_cc| Box::new(app))
    );
    let action = rx.recv().unwrap_or(TimerAction::Stop);
    match action {
        TimerAction::Snooze => println!("snooze"),
        TimerAction::Restart => println!("restart"),
        TimerAction::Stop => println!("stop"),
    }
}

/// Spawns a separate process to show the popup and returns the chosen action.
/// This sets the environment variable "POPUP_MODE" so the child runs popup mode.
fn spawn_popup(popup_message: &str) -> TimerAction {
    let current_exe = std::env::current_exe().expect("Failed to get current executable");
    let output = Command::new(current_exe)
        .env("POPUP_MODE", "1")
        .arg("--message")
        .arg(popup_message)
        .output()
        .expect("Failed to spawn popup process");
    let stdout = String::from_utf8_lossy(&output.stdout);
    match stdout.trim() {
        "snooze" => TimerAction::Snooze,
        "restart" => TimerAction::Restart,
        _ => TimerAction::Stop,
    }
}

/// Runs the timer. When time's up, it plays the sound and spawns a separate popup process.
/// Depending on the chosen action, it deletes the old active timer record and inserts a new one.
/// Durations are stored using the original formatting string.
fn run_timer(mut duration: Duration, original_duration_str: String, popup_message: String, view: bool) {
    let conn = init_db().expect("Failed to initialize DB");
    // Insert the initial active timer record using the original duration string.
    let mut active_timer_id = register_active_timer_db(&conn, &original_duration_str, &popup_message)
        .expect("Failed to register active timer");

    loop {
        if view {
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
        let (_stream, sink) = play_sound_loop();
        let action = spawn_popup(&popup_message);
        sink.stop();
        match action {
            TimerAction::Snooze => {
                let (snooze_duration, snooze_str) = get_snooze_duration_and_str();
                let new_message = format!("(Snoozed) {}", popup_message);
                unregister_active_timer_db(&conn, active_timer_id).unwrap();
                active_timer_id = register_active_timer_db(&conn, &snooze_str, &new_message)
                    .expect("Failed to register snoozed timer");
                log_timer_creation_db(&conn, &snooze_str, &new_message, false).unwrap();
                println!("Snoozing for {}...", snooze_str);
                duration = snooze_duration;
                continue;
            },
            TimerAction::Restart => {
                let new_message = format!("(Restarted) {}", popup_message);
                unregister_active_timer_db(&conn, active_timer_id).unwrap();
                active_timer_id = register_active_timer_db(&conn, &original_duration_str, &new_message)
                    .expect("Failed to register restarted timer");
                log_timer_creation_db(&conn, &original_duration_str, &new_message, false).unwrap();
                println!("Restarting timer...");
                duration = parse_duration(&original_duration_str).unwrap();
                continue;
            },
            TimerAction::Stop => {
                println!("Stopping timer.");
                unregister_active_timer_db(&conn, active_timer_id).unwrap();
                break;
            },
        }
    }
}

fn main() {
    // If the environment variable POPUP_MODE is set, run popup mode.
    if std::env::var("POPUP_MODE").unwrap_or_default() == "1" {
        run_popup();
        return;
    }
    let args = Args::parse();
    if let Some(count) = args.history {
        show_history_db(count).unwrap();
        return;
    }
    if args.view {
        show_active_timer_db().unwrap();
        return;
    }
    let duration_str = args.duration.unwrap_or_else(|| {
        eprintln!("Duration string required unless using --history or --view");
        process::exit(1);
    });
    let duration = match parse_duration(&duration_str) {
        Ok(d) => d,
        Err(e) => {
            eprintln!("Error parsing duration: {}", e);
            process::exit(1);
        }
    };
    let popup_message = args.message.unwrap_or_else(|| "".to_string());
    println!("Starting timer for {}...", duration_str);

    // If running in foreground, use the existing connection.
    if args.fg || args.background_child {
        let conn = init_db().expect("Failed to initialize database");
        log_timer_creation_db(&conn, &duration_str, &popup_message, args.fg).unwrap();
        run_timer(duration, duration_str, popup_message.clone(), args.fg);
    } else {
        // Background mode: spawn a detached child process (cross-platform)
        let exe = std::env::current_exe().expect("Failed to get current executable path");
        let mut cmd = Command::new(exe);
        cmd.arg(&duration_str)
           .arg("--background-child");
        
        if !popup_message.is_empty() {
            cmd.arg(&popup_message);
        }

        // On Windows, hide the console window
        #[cfg(windows)]
        let cmd = {
            const DETACHED_PROCESS: u32 = 0x00000008;
            const CREATE_NO_WINDOW: u32 = 0x08000000;
            cmd.creation_flags(DETACHED_PROCESS | CREATE_NO_WINDOW)
        };

        match cmd.spawn() {
            Ok(_) => {
                println!("Timer started in background.");
            }
            Err(e) => {
                eprintln!("Error spawning background process: {}", e);
                process::exit(1);
            }
        }
    }
}
