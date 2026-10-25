# Sumbee

Sumbee is a free, offline app for Android and iPhone for daily arithmetic practice, for kids aged 5–12. You pick how big the numbers go, which operations to practice and how many cards, then tap Start. The child answers each card on a big on-screen keypad, and at the end sees their score and time. That is the whole app.

The Android app lives in `android/` and the iPhone app in `ios/`. They have the same features.

The name is "sum" plus "spelling bee": a math bee. The icon is a bee with a plus on its back.

## The idea

Sumbee was built for one child: a 2nd grader whose school asks for math practice every day. If the child keeps using it (at least 5 days a week for 3 weeks, without being pushed), it ships free to everyone. It did, so Sumbee is going to Google Play and the App Store.

Two rules come before everything else:

- **Speed.** Kids get the cheapest phones and tablets, full of preinstalled software. Sumbee has to feel instant on a 2 GB Android Go-class phone. Slowness is a bug.
- **Simplicity.** One screen with three states (Setup, Cards, Results). No menus, no settings screen, no dialogs. Settings are remembered, so a daily session is: open the app, tap Start.

A third rule follows from the audience: **gentle, not punishing.** A wrong answer gets "Are you sure?" and a second try, not a buzzer.

## Features

- **Setup on one screen.** An optional name, "Numbers up to N" (5–100), any mix of + − × ÷, and 25, 50, 75 or 100 cards. All of it is remembered on the device.
- **A smart deck.** Cards feel varied: no card twice in a session (`3 + 5` and `5 + 3` count as the same), no near-repeats like `6 + 4` right after `6 + 5`, operations balanced and mixed, and throwaway cards like `×1` or `+0` kept rare.
- **Kid-safe math.** No negative answers, no remainders, never ÷0. × and ÷ stay within the times tables (up to 12 × 12), whatever the range.
- **A big keypad.** 0–9, ⌫ and ✓, with keys of at least 64 dp. The system keyboard never appears.
- **A second chance.** After a wrong first answer the child can check and fix it. A correct second answer still counts. After a second miss, the right answer shows calmly before the next card.
- **Progress and time.** A "7 / 25" counter and a running timer, which pauses when the app goes to the background.
- **Results.** "Jenny's score: 21 / 25" and "Time 2:34". **Play again** starts a fresh deck with the same settings in one tap. Back goes to Setup to change them (on iPhone, **Change settings**).
- **No accidental exits.** During a session, Back once shows "Press Back again to stop", and only a second Back leaves. iPhones have no Back button, so there the card screen has an ✕ that works the same way: tap it twice.

## What it is not

Sumbee has no lessons, no accounts, no history across sessions, no streaks or badges, no sound, no ads, no in-app purchases, no analytics and no network access. It requests no permissions at all. The only data it keeps is the child's name and the last-used settings, and they never leave the device, not even through Android backup.

It is free by decision: ads would cost the speed, and a paid unlock would split the app and need a parental gate.

## Status

Version 0.3. The family build (M1) and the validation weeks (M2) are done, and the decision was to publish (M3).

- **Google Play:** in closed testing since 0.1 (October 2026). Production access was applied for on 2026-10-25 and is under review.
- **App Store:** being submitted for review, built from the same version.

## Documentation

| Document | What it covers |
| :-- | :-- |
| [`docs/VISION.md`](docs/VISION.md) | Why the app exists, its principles, what it is not, the roadmap and the publish decision |
| [`docs/SPEC.md`](docs/SPEC.md) | What it does: every requirement (FR-1 to FR-9), deck rules and performance budgets |
| [`docs/IMPLEMENTATION.md`](docs/IMPLEMENTATION.md) | How it is built: stack, project layout, the deck algorithm, state, tests and release |

## Tech

Kotlin and Jetpack Compose, a single Activity, minSdk 24 (Android 7.0), targetSdk 37. Dependencies are kept to a minimum: Compose foundation and Material 3, activity, lifecycle, DataStore Preferences and the splash screen library. The deck generator in `model/DeckGenerator.kt` is pure Kotlin and covered by unit tests. The release APK is about 1.7 MB.

## Build and run

### Android

Requires JDK 17+ and the Android SDK (platform 37). The Gradle project lives in `android/`.

```sh
cd android
./gradlew testDebugUnitTest     # unit tests
./gradlew installDebug          # debug build onto a connected device or emulator
./gradlew assembleRelease       # shrunk release APK: android/app/build/outputs/apk/release/
./gradlew bundleRelease         # signed AAB for Google Play: android/app/build/outputs/bundle/release/
```

### iOS

Requires Xcode 16+ with an iOS simulator runtime. The app is SwiftUI, iOS 17+, iPhone only. Its logic is the Swift package `ios/SumbeeCore`, a port of `model/` and `SessionViewModel`, so it can be tested on the Mac without a simulator.

```sh
cd ios
swift test --package-path SumbeeCore    # deck and session tests, no simulator
open Sumbee.xcodeproj                   # run from Xcode, or:
xcodebuild test -project Sumbee.xcodeproj -scheme Sumbee \
  -destination 'platform=iOS Simulator,name=iPhone 17'   # UI test: plays a full session
```

Set `TEST_RUNNER_SCREENSHOT_DIR=<folder>` on the `xcodebuild test` line to save a screenshot of each screen. To run on your own iPhone, pick it as the destination in Xcode and sign with your Apple ID. Publishing needs an Apple Developer account.

## Release signing

Release builds are signed with the Play upload key, which never goes in the repo. Gradle reads it from `~/.gradle/gradle.properties`:

```properties
SUMBEE_UPLOAD_STORE_FILE=/Users/<you>/.keystores/sumbee-upload.jks
SUMBEE_UPLOAD_STORE_PASSWORD=...
SUMBEE_UPLOAD_KEY_ALIAS=upload
SUMBEE_UPLOAD_KEY_PASSWORD=...
```

Without those properties, release builds fall back to the debug key: they still install with `adb install`, but Play rejects them. Google holds the app signing key (Play App Signing), so a lost upload key can be reset through Play Console support, but keep a backup of the keystore and its password anyway.

## Icon

The master is `design/icon/sumbee-foreground.svg`. Rebuild every launcher size, the themed icon, the Play Store icon, the Play feature graphic, the iOS app icon and the bee in Setup's header with `python3 design/icon/build_icons.py` (needs `rsvg-convert`).

## Licences

Code: MIT ([`LICENSE`](LICENSE)).

Fonts: Baloo 2 and Nunito, SIL Open Font License 1.1 (`licenses/`).
