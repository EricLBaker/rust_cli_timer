use std::env;
use std::time::Duration;
use std::thread::sleep;
use humantime::parse_duration;

/// Minimal CLI tool to start a timer based on a human-readable duration string.
///
/// # Usage
/// ```bash
/// cargo run -- "1min"
/// ```
///
/// This will parse the duration (e.g., "1min", "1 minute", "1hr 2 min, 40 seconds")
/// and start a timer for the specified duration.
fn main() {
    // Collect command-line arguments.
    let args: Vec<String> = env::args().collect();

    // Ensure exactly one argument is provided (besides the executable name).
    if args.len() != 2 {
        eprintln!("Usage: {} <duration>", args[0]);
        eprintln!("Example: {} \"1min\"", args[0]);
        std::process::exit(1);
    }

    let input = &args[1];

    // Attempt to parse the input duration string.
    match parse_duration(input) {
        Ok(duration) => {
            println!("Parsed duration: {:?}", duration);
            println!("Starting timer for {} seconds...", duration.as_secs());

            // Start the timer.
            sleep(duration);

            println!("Time's up!");
        },
        Err(e) => {
            eprintln!("Error parsing duration: {}", e);
            std::process::exit(1);
        },
    }
}
