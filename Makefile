.PHONY: all install clean test build-web start

SHELL := /usr/bin/env bash

all: build-web

install:
	flutter pub get

clean:
	flutter clean

test: install
	flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
	flutter test --no-pub

build-web: install
	flutter build web --release --source-maps --no-tree-shake-icons
	rm -f build/web/.last_build_id

start: install
	@trap 'kill 0' EXIT; \
		firebase emulators:start --import=.emulator-data --export-on-exit=.emulator-data & \
		sleep 3 && flutter run -d chrome --web-port=5050; \
		wait
