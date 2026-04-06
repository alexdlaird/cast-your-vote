# Cast Your Vote!

A voting app for a round-based singing competition, with audience & judge ballot generation, Google Sheets results
export, and event-based eliminations.

## Prerequisites

- Dart & Flutter
- Firebase project (Firestore)

## Getting Started

To run a development version of the app for `web`:

```sh
# Terminal 1: Start the Firebase emulators
firebase emulators:start

# Terminal 2: Run the app
flutter run -d chrome
```

The app automatically connects to the local Firestore emulator in debug mode.

- **Emulator UI:** http://localhost:4000 (view/edit Firestore data)
- **Firestore:** localhost:8080

## Deployment

The app auto-deploys to Firebase Hosting on commits to `main`.

## Admin Access

Navigate to `/admin` to log in and manage events. Authentication uses Google OAuth, and only whitelisted users can
access the admin area.

In production, the whitelist can be managed in Firebase Console, under the Firestore. Create a `/config/admins`
document, with an `emails` array, and populate with allowed addresses.

When running on the local emulator, provision the whitelist with (update with your email):

```sh
curl -X PATCH "http://localhost:8080/v1/projects/cast-your-vote-d3898/databases/(default)/documents/config/admins" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer owner" \
  -d '{"fields": {"emails": {"arrayValue": {"values": [{"stringValue": "your-email@gmail.com"}]}}}}'
```
