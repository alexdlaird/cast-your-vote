# Cast Your Vote!

A voting app for a round-based competition where the audience (and an optional panel of judges) can cast their votes
from their phones.

Features include configurable scoring, optional judge panels, exporting results to Google Sheets, donation bonuses
(if you're running a fundraiser), and round-based eliminations.

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (version in `.flutter-version`)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- A [Firebase project](https://console.firebase.google.com/) (for deployment)

## Getting Started

Install dependencies and start the app locally with Firebase emulators:

```sh
make start
```

This starts the Firebase emulators (Firestore + Storage) and runs the Flutter web app on
[http://localhost:5050](http://localhost:5050). Emulator data persists across restarts in `.emulator-data/`.

- **Emulator UI:** [http://localhost:4000](http://localhost:4000) (view/edit Firestore & Storage data)
- **App:** [http://localhost:5050](http://localhost:5050)

### Admin Setup (Local)

Navigate to `/admin` to access the admin area. With the emulators running, provision the admin whitelist:

```sh
make setup-admin
```

## Deploy Your Own

This app is entirely self-contained within Firebase (Hosting, Firestore, Storage, Auth). To deploy your own instance:

### 1. Create a Firebase Project

- Go to [Firebase Console](https://console.firebase.google.com/) and create a new project
- Enable **Authentication** (Google sign-in provider)
- Enable **Cloud Firestore** (start in production mode)
- Enable **Firebase Storage**

### 2. Create Your Repo and Configure

[![Use this template](https://img.shields.io/badge/Use%20this%20template-238636?style=for-the-badge&logo=github)](https://github.com/alexdlaird/cast-your-vote/generate)

Click the button above to fork your own copy, then update `.firebaserc` with your project ID and generate the
Firebase configuration:

```sh
make firebase-config
```

This regenerates `lib/firebase_options.dart` with your project's keys.

### 3. Set Up Google OAuth

The admin panel uses Google Sign-In for authentication and Google Sheets API for results export.

1. Go to [Google Cloud Console > Credentials](https://console.cloud.google.com/apis/credentials) for your project
2. Create an **OAuth 2.0 Client ID** (Web application type)
3. Add authorized JavaScript origins:
   - `https://YOUR_PROJECT_ID.web.app`
   - `https://YOUR_PROJECT_ID.firebaseapp.com`
   - `http://localhost:5050`
4. Copy the Client ID and update `web/index.html`:
   ```html
   <meta name="google-signin-client_id" content="YOUR_CLIENT_ID_HERE">
   ```
5. Enable the **Google Sheets API** and **Google Drive API** in
   [Google Cloud Console > APIs & Services](https://console.cloud.google.com/apis/library)

### 4. Update Project References

Replace the original project ID in these files:

| File | What to change |
|------|---------------|
| `.firebaserc` | `"default"` project ID |
| `cors.json` | Origin URLs to your Firebase Hosting domains |

The Makefile reads the project ID from `.firebaserc` automatically.

### 5. Configure CI/CD

The GitHub Actions workflow auto-deploys on pushes to `main`.

1. In your Firebase project, go to **Settings > Service accounts**
2. Click **Generate new private key** to download a JSON key file
3. In your GitHub repo, go to **Settings > Secrets and variables > Actions**
4. Add a secret named `FIREBASE_SERVICE_ACCOUNT` with the contents of the JSON key file

### 6. Deploy

Push to `main` and the workflow will automatically run `make test`, `make build-web`, and `make deploy`.

Or deploy manually:

```sh
make deploy
```

### 7. Set Up Admin Whitelist

In Firebase Console, go to Firestore and create a document at `/config/admins` with an `emails` field (array of
strings) containing the email addresses of your admin users.

## Admin Access

Navigate to `/admin` to log in and manage events. Authentication uses Google OAuth, and only whitelisted email
addresses can access the admin area.

From the admin dashboard you can:
- Create and manage competition events
- Configure judges, scoring categories, and scoring formulas
- Generate ballot codes for audience and judges
- Track donations and bonus points
- Export results to Google Sheets
- View rankings and manage eliminations
