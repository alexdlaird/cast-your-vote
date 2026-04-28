.PHONY: all install clean test build-web deploy firebase-config setup-admin start

SHELL := /usr/bin/env bash

PROJECT_ID ?= $(shell python3 -c "import json; print(json.load(open('.firebaserc'))['projects']['default'])")
STORAGE_BUCKET ?= $(PROJECT_ID).firebasestorage.app

all: build-web

install:
	flutter pub get

clean:
	flutter clean

test: install
	flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
	flutter test --no-pub

setup-admin:
	@read -p "Enter admin email: " email; \
		curl -s -X PATCH "http://localhost:8080/v1/projects/$(PROJECT_ID)/databases/(default)/documents/config/admins" \
			-H "Content-Type: application/json" \
			-H "Authorization: Bearer owner" \
			-d "{\"fields\": {\"emails\": {\"arrayValue\": {\"values\": [{\"stringValue\": \"$$email\"}]}}}}" > /dev/null && \
		echo "Admin whitelist set to: $$email"

firebase-config:
	dart pub global activate flutterfire_cli
	flutterfire configure --project=$(PROJECT_ID) --yes

build-web: install
	flutter build web --release --source-maps --no-tree-shake-icons
	rm -f build/web/.last_build_id

start: install
	@trap 'kill 0' EXIT; \
		firebase emulators:start --import=.emulator-data --export-on-exit=.emulator-data & \
		sleep 3 && flutter run -d chrome --web-port=5050; \
		wait

deploy: build-web
	firebase deploy --project=$(PROJECT_ID)
	gsutil cors set cors.json gs://$(STORAGE_BUCKET)