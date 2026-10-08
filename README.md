# Sumbee

Sumbee is a free, offline Android app for daily arithmetic practice, for kids aged 5–12. You pick how big the numbers go, which operations to practise and how many cards, then tap Start. The child answers each card on a big on-screen keypad, and at the end sees their score and time. That is the whole app.

The name is "sum" plus "spelling bee": a math bee. The icon is a bee with a plus on its back.

## The idea

Sumbee was built for one child: a 2nd grader whose school asks for math practice every day. If the child keeps using it (at least 5 days a week for 3 weeks, without being pushed), it ships free to everyone on Google Play.

Two rules come before everything else:

- **Speed.** Kids get the cheapest phones and tablets, full of preinstalled software. Sumbee has to feel instant on a 2 GB Android Go-class phone. Slowness is a bug.
- **Simplicity.** One screen with three states (Setup, Cards, Results). No menus, no settings screen, no dialogs. Settings are remembered, so a daily session is: open the app, tap Start.

A third rule follows from the audience: **gentle, not punishing.** A wrong answer gets "Are you sure?" and a second try, not a buzzer.

## Features

- **Setup on one screen.** An optional name, "Numbers up to N" (10–100), any mix of + − × ÷, and 25, 50, 75 or 100 cards. All of it is remembered on the device.
- **A smart deck.** Cards feel varied: no card twice in a session (`3 + 5` and `5 + 3` count as the same), no near-repeats like `6 + 4` right after `6 + 5`, operations balanced and mixed, and throwaway cards like `×1` or `+0` kept rare.
- **Kid-safe math.** No negative answers, no remainders, never ÷0.
- **A big keypad.** 0–9, ⌫ and ✓, with keys of at least 64 dp. The system keyboard never appears.
- **A second chance.** After a wrong first answer the child can check and fix it. A correct second answer still counts. After a second miss, the right answer shows calmly before the next card.
- **Progress and time.** A "7 / 25" counter and a running timer, which pauses when the app goes to the background.
- **Results.** "Jenny's score: 21 / 25" and "Time 2:34". **Play again** starts a fresh deck with the same settings in one tap. Back goes to Setup to change them.
- **No accidental exits.** During a session, Back once shows "Press Back again to stop", and only a second Back leaves.

## What it is not

Sumbee has no lessons, no accounts, no history across sessions, no streaks or badges, no sound, no ads, no in-app purchases, no analytics and no network access. It requests no permissions at all. The only data it keeps is the child's name and the last-used settings, and they never leave the device, not even through Android backup.

It is free by decision: ads would cost the speed, and a paid unlock would split the app and need a parental gate.

## Status

Milestone 1, the family build, is version 0.1 and is installed straight onto the device, not through Play. Next is M2, 2–3 weeks of everyday use by the first child, then a decision whether to publish to Google Play's Designed for Families program (M3).

## Documentation

| Document | What it covers |
| :-- | :-- |
| [`docs/VISION.md`](docs/VISION.md) | Why the app exists, its principles, what it is not, the roadmap and the publish decision |
| [`docs/SPEC.md`](docs/SPEC.md) | What it does: every requirement (FR-1 to FR-9), deck rules and performance budgets |
| [`docs/IMPLEMENTATION.md`](docs/IMPLEMENTATION.md) | How it is built: stack, project layout, the deck algorithm, state, tests and release |

## Tech

Kotlin and Jetpack Compose, a single Activity, minSdk 24 (Android 7.0), targetSdk 37. Dependencies are kept to a minimum: Compose foundation and Material 3, activity, lifecycle, DataStore Preferences and the splash screen library. The deck generator in `model/DeckGenerator.kt` is pure Kotlin and covered by unit tests. The release APK is about 1.7 MB.

## Build and run

Requires JDK 17+ and the Android SDK (platform 37).

```sh
./gradlew testDebugUnitTest     # unit tests
./gradlew installDebug          # debug build onto a connected device or emulator
./gradlew assembleRelease       # shrunk release APK: app/build/outputs/apk/release/
./gradlew bundleRelease         # signed AAB for Google Play: app/build/outputs/bundle/release/
```

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

The master is `design/icon/sumbee-foreground.svg`. Rebuild every launcher size, the themed icon, the Play Store icon and the Play feature graphic with `python3 design/icon/build_icons.py` (needs `rsvg-convert`).

## Licences

Code: MIT ([`LICENSE`](LICENSE)).

Fonts: Baloo 2 and Nunito, SIL Open Font License 1.1 (`licenses/`).
