# Cast Your Vote!

A voting app for a round-based competition where the audience (and an optional panel of judges) can cast their votes
from their phones.

## Prerequisites

- Dart & Flutter
- Firebase

## Getting Started

To run a development version of the app for `web`:

```sh
make start
```

The app automatically connects to the local emulators in debug mode.

- **Emulator UI:** http://localhost:4000 (view/edit Firestore & Storage data)

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
