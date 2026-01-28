build:
	cargo build --release

install:
	cargo install --path .

clean:
	rm /tmp/timer_cli_history.log
