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

# Whitelist an admin Google account. Prompts for the target (local emulator or the deployed
# project) and the email, then PATCHes /config/admins. Locally the emulator's `owner` bearer
# bypasses rules; for deployed it uses your Firebase CLI access token (admin), which bypasses
# rules on live Firestore. Sets the doc to the single address provided.
setup-admin:
	@read -p "Target [local/deployed]: " target; \
		read -p "Enter admin email: " email; \
		if [ "$$target" = "deployed" ]; then \
			host="https://firestore.googleapis.com"; \
			firebase projects:list >/dev/null 2>&1; \
			token=$$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.config/configstore/firebase-tools.json')))['tokens']['access_token'])"); \
		else \
			host="http://localhost:8080"; token="owner"; \
		fi; \
		curl -s -o /dev/null -w "HTTP %{http_code}\n" -X PATCH "$$host/v1/projects/$(PROJECT_ID)/databases/(default)/documents/config/admins" \
			-H "Content-Type: application/json" -H "Authorization: Bearer $$token" \
			-d "{\"fields\": {\"emails\": {\"arrayValue\": {\"values\": [{\"stringValue\": \"$$email\"}]}}}}" && \
		echo "Admin whitelist set to: $$email ($$target)"

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