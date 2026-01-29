build:
	cargo build --release

install:
	cargo install --path .

clean:
	rm /tmp/timer_cli_history.log

release:
	git checkout main
	git pull origin main
	git tag v$(v)
	git push origin v$(v)