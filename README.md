# Theatre 121

A voting app for Theatre 121's "Come Out Singin'" karaoke competition. Audience members and judges submit ballots via QR codes, and admins can manage events and export results.

## Prerequisites

- Dart & Flutter
- Firebase project (Firestore)

## Getting Started

To run a development version of the app for `web`:

```sh
flutter run -d chrome --web-port=5050
```

## Deployment

The app auto-deploys to Firebase Hosting on commits to `main`.

## Admin Access

Navigate to `/admin` to log in and manage events. Authentication uses Google OAuth, and only whitelisted users can
access the admin area. The whitelist is managed in Firebase Console under the Firestore `/config/admins` document's
`emails` array.
