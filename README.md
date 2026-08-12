# TruFit Bodamma

TruFit Bodamma is a private, local-first personal fitness tracking application built with Flutter. It prioritizes data ownership and privacy by keeping all your workouts, meals, body stats, and health metrics directly on your device.

## Core Principles

1. **Local-First by Default:** All data is stored in a local Hive NoSQL database on your device.
2. **Optional Cloud Sync:** If you choose to sign in with Google, your text data (workouts, meals, habits) syncs securely to your personal Firestore database. **Photos and media are NEVER synced to the cloud** to ensure maximum privacy.
3. **AI Features:** You can optionally provide a Gemini API key (or use the built-in Vertex integration) for smart meal logging and coaching. 
4. **Data Ownership:** You can export all your data (including photos) as a single encrypted ZIP file and restore it at any time.

### What Leaves Your Phone?

| Feature | Data Sent | Destination | Opt-In Required? |
|---------|-----------|-------------|------------------|
| **Core App** | Nothing | Nowhere | - |
| **Cloud Sync** | Workouts, meals, habits, body stats (No photos) | Google Firestore (Private) | Yes (Google Sign-In) |
| **AI Food Scan** | Cropped meal photo, food name prompt | Gemini/Vertex AI | Yes (Manual scan) |
| **AI Coach** | Weekly workout adherence stats | Gemini/Vertex AI | Yes (Manual refresh) |
| **Exercise Demos** | Video ID | YouTube | No (View only) |

## Project Architecture

The app is built using a modern Riverpod architecture:
- **Models:** Simple Dart classes representing data entities (e.g., `WorkoutPlan`, `DailyLog`).
- **Repositories:** Classes responsible for reading/writing models to the local Hive database.
- **Providers:** Riverpod providers connect the repositories to the UI, ensuring the app is always reactive.
- **Services:** External integrations, such as `HealthConnectService` and `GeminiFoodService`.
- **UI:** The app is divided into three main tabs: Home, Progress, and Profile.

## Data Source of Truth Rules

To prevent state desyncs across the app, follow these data rules:
- **Exercise / section completion:** `ExerciseLog` is the source of truth. A section is complete when every exercise in it has a log for that date. Do NOT store completion booleans on `WorkoutPlan` models.
- **Day-level Finish flag:** `DailyLog.workoutCompleted` is set when the user taps Finish (full or early), and is auto-set when all sections are fully logged. Use it together with logs for "day done" (e.g. finish-early).
- **Rest days:** Planned rest (Sunday or empty sections) counts as complete for scoring and day-done checks via `WorkoutCompletion` helpers in `lib/utils/workout_completion.dart`.

## Local CI/CD (Building and Deploying)

Because this app will never be pushed to a public or private repository, all CI/CD is handled locally via PowerShell scripts located in the `scripts/` directory.

### Building and Installing
To build the app and install it on your Android device:
1. Connect your Android device via USB and ensure **USB Debugging** is enabled.
2. Open PowerShell in the project root.
3. Run: `.\scripts\build_and_install.ps1`

### App Signing (Optional)
If you want to generate a signed release APK:
1. Run `.\scripts\generate_keystore.ps1` and follow the prompts.
2. Create an `android/key.properties` file with the generated details.
3. Modify `build_and_install.ps1` to use `flutter build apk --release` instead of `--profile`.

## App Icons

App icons are generated using `flutter_launcher_icons`. If you change the icon in `assets/icon/app_icon.png`, you can regenerate the Android launcher icons by running:
`dart run flutter_launcher_icons`
