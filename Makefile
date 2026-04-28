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
	@read -p "Enter Firebase project ID: " project_id; \
		python3 -c "import json; f='.firebaserc'; d=json.load(open(f)); d['projects']['default']='$$project_id'; json.dump(d,open(f,'w'),indent=2)" && \
		python3 -c "import json; f='cors.json'; d=json.load(open(f)); d[0]['origin']=['https://$$project_id.web.app','https://$$project_id.firebaseapp.com']; json.dump(d,open(f,'w'),indent=2)" && \
		dart pub global activate flutterfire_cli && \
		flutterfire configure --project=$$project_id --yes && \
		echo "Configured for project: $$project_id"

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