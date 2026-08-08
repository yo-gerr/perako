# PeraKo — Firebase Setup Guide (Android)

> **Target:** Android only. Adds **Cloud Firestore** as an *additive* sync/backup
> layer on top of the local SQLite (drift) database, which remains the source of
> truth. No auth, no other Firebase services for now.

## 0. Prerequisites installed on your machine

Confirm each with the version check before continuing:

```powershell
npm --version          # Node.js package manager
firebase --version     # Firebase CLI
flutterfire --version  # FlutterFire CLI
```

If any are missing:

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
# Ensure the pub global "bin" folder is on your PATH;
# re-open your terminal afterwards so `flutterfire` is found.
```

## 2. Create a Firebase project (Firebase console)

1. Go to <https://console.firebase.google.com/> and **Add project**. Name it
   e.g. `perako`. You can keep Google Analytics off for now.
2. From the project overview, **Add app → Android**.
3. Package name must match the app's `applicationId`: **`com.example.perako`**
   (defined in `android/app/build.gradle.kts`).
4. Download the generated **`google-services.json`** and place it at exactly:
   `android/app/google-services.json`.
   (This file is git-ignored. It contains the same non-secret client config as
   `lib/firebase_options.dart`, but it is excluded because the Android build
   reads it from disk — so anyone cloning the repo must add it locally before
   building Android.)

## 3. Log in and generate Flutter config

```bash
firebase login                 # opens browser; sign in
flutterfire configure          # interactive
```

When prompted:
- Select the `perako` project.
- **Only select the `android` platform** (deselect any others).
- The tool will apply the Google services Gradle plugin to your `android/app`
  `build.gradle.kts` and write a generated file at **`lib/firebase_options.dart`**.

This `flutterfire configure` step is what wires Firebase permanently — it:
- adds the `com.google.gms.google-services` plugin to your Gradle build,
- places/verifies `google-services.json`,
- generates `lib/firebase_options.dart` containing `DefaultFirebaseOptions`.

## 4. Add the Flutter Firebase packages

From the project root:

```bash
flutter pub add firebase_core cloud_firestore
```

This is **you** doing this; the code that consumes them comes when we build the
sync layer together.

### Minimum SDK check (already satisfied)

Firestore requires `minSdk >= 23`. Flutter's default is `24`
(`C:\flutter\packages\flutter_tools\gradle\FlutterExtension.kt`), so **no
`android/app/build.gradle.kts` change is needed**.

## 5. Verify Firebase is wired

```bash
flutter analyze
flutter build apk --debug
```

The APK should build without errors. Android native Firestore gives real-time
`snapshots()` + offline persistence for free — no Windows workarounds needed.

---

## Not doing now (out of scope)

- Firebase **Authentication** — deferred entirely.
- Web/Windows/Linux Firebase config — the app is Android-only for now.
- The **sync layer** (collections mirroring drift tables, LWW conflicts, dedup)
  is the next engineering step after this setup.

---

## Notes / pitfalls

- Commit `lib/firebase_options.dart` (it's safe, non-secret), but **never** commit
  `android/app/google-services.json`; add it locally to build Android.
- If `flutterfire configure` complains the Android app isn't found, double-check
  the package name matches `com.example.perako` exactly.
- The local drift database is unaffected by Firebase and works fully offline.