# Parakeet

Parakeet is a Flutter app for generating and practicing AI-powered language-learning dialogues. It uses Cloud Functions (Python) to call LLMs and synthesize audio via Google Cloud Text-to-Speech, OpenAI TTS, and ElevenLabs.

## Highlights

- AI-generated dialogues with adjustable topic, level, and length
- Multi-provider TTS: Google, OpenAI, ElevenLabs
- Firebase-backed storage for generated content and audio
- Mobile-first Flutter app with web support

## Repository structure

- `lib/` – Flutter application code (screens, services, widgets, utils)
- `functions/` – Cloud Functions (Python) for lesson generation and audio
- `functions_plot_twist/` – Separate Cloud Functions (Python) codebase
- `payment_verification_backend/` – Node/TypeScript backend for purchase verification
- `assets/`, `narrator_audio/` – Static assets and pre-generated audio
- `third_party/vosk_flutter/` – Vosk speech components (vendor code)
- `data_analytics/` – Optional analytics utilities and scripts

## Prerequisites

- Flutter SDK and a recent Dart toolchain
- Firebase CLI (`firebase-tools`) and a Firebase project
- Python 3.10+ for Python Cloud Functions
- Node.js 18+ for `payment_verification_backend`
- Google Cloud project with Text-to-Speech API enabled

## Environment configuration

Some backends expect secrets via environment variables. Create a `.env` in each Python functions codebase or export env vars in your shell/session.

Required variables (by feature):

- OpenAI (used in `functions/`):
  - `OPEN_AI_API_KEY`
- ElevenLabs (used in `functions/`):
  - `ELEVENLABS_API_KEY`
- Google Cloud Text-to-Speech (used in `functions/`):
  - `GOOGLE_APPLICATION_CREDENTIALS` pointing to a service account JSON with TTS access
- Plot Twist function (used in `functions_plot_twist/`):
  - `KOFI_TOKEN` (optional if you use Ko‑fi webhook verification)

## Flutter app – run and build

Install dependencies and run:

```bash
flutter pub get
flutter run
```

Release builds:

```bash
# Android APK
flutter build apk --release

# Android App Bundle (recommended for Play Store)
flutter build appbundle --obfuscate --split-debug-info=build/app/outputs/symbols

# iOS IPA (upload via Transporter)
flutter build ipa --obfuscate --split-debug-info=build/app/outputs/symbols

# Web
flutter build web
```

Troubleshooting:

```bash
flutter clean
```

## Cloud Functions (Python)

This repo contains two Python Cloud Functions codebases: the main `functions/` and `functions_plot_twist/` (declared in `firebase.json` as codebase `plot_twist`).

Install dependencies (example for `functions/`):

```bash
cd functions
pip install -r requirements.txt
```

Key HTTP functions in `functions/main.py`:

- `first_API_calls` – creates a dialogue plan and reserves credits
- `second_API_calls` – generates detailed lesson content and audio
- `delete_audio_file` – deletes generated audio for a lesson/document
- `generate_nickname_audio` – creates a nickname audio file for a user
- `generate_lesson_topic` – suggests a lesson topic given category/words
- `translate_keywords` – translates keywords into target language
- `suggest_custom_lesson` – suggests custom lesson ideas

Deploy all Python functions for the default codebase:

```bash
firebase deploy --only functions
```

Deploy specific functions:

```bash
firebase deploy --only functions:first_API_calls,functions:second_API_calls
```

Run one function locally for testing (requires functions-framework):

```bash
functions-framework --target second_API_calls --debug
```

### Plot Twist functions

The secondary codebase `functions_plot_twist/` can be deployed via Firebase (see `firebase.json`) or directly with gcloud. Example with gcloud:

```bash
gcloud functions deploy handle_kofi_donation \
  --region=europe-west1 \
  --gen2 \
  --set-env-vars KOFI_TOKEN=your_kofi_token_here \
  --source functions_plot_twist/
```

## Payment verification backend (Node/TypeScript)

The `payment_verification_backend/` directory contains a separate backend. Common workflow:

```bash
cd payment_verification_backend
npm install
npm run build # if applicable
npm run deploy # runs: firebase deploy --only functions
```

## Development tips

- Useful commands live in `dev-cheatsheet.md` (deploys, bundling, SHA-1, etc.)
- Ensure your Firebase project is set: `firebase use <your-project>`
- For Google TTS, enable the API and provide credentials via `GOOGLE_APPLICATION_CREDENTIALS`

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License

This repository does not currently include a license. All rights reserved.
