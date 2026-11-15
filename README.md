# Ayesha AI — Flutter starter

A Bengali AI companion starter app with a Flutter client and a small Node.js backend.
The app is a supportive conversational companion, not a replacement for real people or relationships.

## Project layout

- `flutter_app/` — Android-ready Flutter app source
- `backend/` — Node.js + Express API proxy for OpenAI Responses API

## Requirements

- Flutter SDK (stable)
- Node.js 20+
- An OpenAI API key and API project with API billing configured

## 1. Run the backend

```bash
cd backend
npm install
cp .env.example .env
```

Edit `.env` and set `OPENAI_API_KEY`. Keep this key only on the server.
Then:

```bash
npm start
```

The server listens on `http://localhost:3000`.

For a physical Android phone, `localhost` points to the phone itself. Set
`API_BASE_URL` in `flutter_app/lib/config.dart` to your computer's LAN IP
(e.g. `http://192.168.1.10:3000`) while both devices are on the same Wi-Fi.
For production, deploy the backend over HTTPS and use that HTTPS URL.

## 2. Run Flutter

```bash
cd flutter_app
flutter pub get
flutter run
```

Update `lib/config.dart` before running on a physical device.

## 3. Build APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Important security notes

- Never put the OpenAI API key in Flutter, assets, Git, or an APK.
- The included backend is a development starter. Before public release, add user
  authentication, per-user rate limits, request size limits, abuse monitoring,
  HTTPS, and a proper database.
- This starter stores chat history locally on the device using SharedPreferences.
  It is not encrypted cloud backup. Avoid storing highly sensitive information.
- API usage may incur charges. Set usage limits/alerts in your API project.
