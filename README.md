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

This starts the necessary Firebase emulators and runs the Flutter web app at
[http://localhost:5050](http://localhost:5050).

- **Emulator UI:** [http://localhost:4000](http://localhost:4000) (view/edit Firestore & Storage data)
- **App:** [http://localhost:5050](http://localhost:5050)

### Admin Setup (Local)

Navigate to `/admin` to access the admin area. Provision the admin whitelist with:

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

Click the button above to create your own copy, then run:

```sh
make firebase-config
```

### 3. Set Up Google OAuth

The admin panel uses Google Sign-In for authentication and exports ballot results to Google Sheets.

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

### 4. Configure CI/CD

The GitHub Actions workflow auto-deploys anytime you push to `main`, or you can manually trigger it via the
"Deploy to Firebase" workflow.

1. In your Firebase project, go to **Settings > Service accounts**
2. Click **Generate new private key** to download a JSON key file
3. In your GitHub repo, go to **Settings > Secrets and variables > Actions**
4. Add a secret named `FIREBASE_SERVICE_ACCOUNT` with the contents of the JSON key file

### 5. Deploy

Push to `main` and the workflow will automatically deploy the project to your newly configured Firebase project.

### 6. Set Up Admin Whitelist

In Firebase Console, go to Firestore and create a document at `/config/admins` with an `emails` field (array of
strings) containing the email addresses of your admin users. Then you'll be able to access the admin area from your
live Firebase site by navigating to `/admin`.
