# Sumbee: Implementation

> **Scope note.** This document covers how the app is built: stack, structure, the deck algorithm, state and timing, persistence, tests and release. What the app does is in `SPEC.md`, and why is in `VISION.md`. Section references like FR-2.6 point to `SPEC.md`.

---

## 1. Stack

* **Kotlin + Jetpack Compose**, single Activity, minSdk 24, targetSdk the current Play requirement.
* **Build:** AGP 9.4 with its built-in Kotlin (2.2.10) and the matching Compose compiler plugin, Gradle 9.7 through the wrapper, JDK 17 bytecode. Versions live in `gradle/libs.versions.toml`.
* **Dependencies, deliberately minimal (FR-7):** Compose BOM (`foundation` and `material3` only), `activity-compose`, `lifecycle-viewmodel-compose`, `lifecycle-runtime-compose`, `datastore-preferences` and `core-splashscreen`. Tests add JUnit 4 and `kotlinx-coroutines-test`.
* **Fonts:** Baloo 2 (numbers, headings) and Nunito (everything else), both variable fonts bundled in `res/font` under the SIL Open Font License (`licenses/`). They are bundled rather than downloadable because downloadable fonts need Google Play services and a first-run fetch.
* **Icons:** the six stroke icons are `ImageVector`s built in `ui/Icons.kt`, so there is no icon library.
* **App icon:** `design/icon/sumbee-foreground.svg` is the master: the bee on a 108-unit adaptive canvas, inside the 66-unit safe circle. `python3 design/icon/build_icons.py` (needs `rsvg-convert`) regenerates the whole set:
  * the vector foreground, which is also the splash icon on a navy disc;
  * the themed-icon monochrome silhouette;
  * the legacy PNGs for API 24–25 (square and round);
  * the 512 px Play Store icon.
  The background is the navy `ic_launcher_background` color.
* **Not used:** Navigation (one screen, FR-6.1), a DI framework, Room, Firebase, analytics, image or animation libraries.
* **Release build:** R8 with `isShrinkResources` (release APK ≈ 1.7 MB). It is signed with the Play upload key, read from `~/.gradle/gradle.properties` and kept outside the repo, or with the debug key on a machine without it (§7). *Not built yet:* the `:baselineprofile` module (§5), so there is no app-specific Baseline Profile so far, only the ones the AndroidX libraries ship.
* **applicationId:** `dev.sumbee`. Confirm it before M3, because it can't change once published.
* **No backup:** `allowBackup="false"` and data-extraction rules that exclude everything. Without them, Android's auto-backup would copy the child's name to the parent's Google Drive, against `VISION.md` §6.

## 2. Project Layout

```
android/app/src/main/kotlin/dev/sumbee/
  MainActivity.kt          // splash, edge-to-edge, lifecycle → clock, setContent { App(vm) }
  model/
    Operation.kt           // enum PLUS, MINUS, TIMES, DIVIDE + symbol, limit, maxAnswer
    Card.kt                // data class Card(op, a, b): answer, isTrivial, canonical, isNearTo
    SessionConfig.kt       // name, maxNumber, ops, cardCount; limits, sanitizing, name filter
    DeckGenerator.kt       // pure Kotlin, FR-2 (no Android imports)
  ui/
    SessionViewModel.kt    // UiState, events, clock, Back guard, SavedStateHandle (FR-3–FR-5)
    App.kt                 // when (uiState) { Setup / Cards / Results } + BackHandler
    SetupContent.kt
    CardContent.kt
    ResultsContent.kt
    Keypad.kt
    Components.kt          // ChunkyButton: the raised key/button that sinks on press
    Theme.kt               // palette, fonts, MaterialTheme
    Icons.kt               // the stroke icons
  data/
    SettingsRepository.kt  // SettingsStore interface + DataStore<Preferences> (FR-1.6)
android/app/src/test/kotlin/...         // DeckGeneratorTest, SessionViewModelTest
android/app/src/androidTest/...         // not yet: Compose happy-path test (§5)
android/baselineprofile/                // not yet: Baseline Profile + startup/frame benchmarks (§5)
```

## 3. State

### 3.1 UiState (FR-6.1)
```kotlin
sealed interface UiState {
  data class Setup(val config: SessionConfig) : UiState
  data class Cards(
    val deck: List<Card>, val index: Int,
    val input: String, val attempt: Int,          // 1 or 2
    val feedback: Feedback,                       // None, Correct, Nudge, Reveal
    val correct: Int, val name: String, val maxDigits: Int,
    val exitArmed: Boolean = false) : UiState    // FR-3.6 double-Back guard
  data class Results(val name: String, val correct: Int,
                     val total: Int, val elapsedMs: Long) : UiState
}
```
`App.kt` renders a `when (state)`, so there is no navigation library. System Back is a `BackHandler` in the Cards and Results states. On Results it goes straight to `Setup` (FR-5.1). On Cards it is guarded (FR-3.6): the first press sets `Cards.exitArmed` and shows the hint, and a press while armed goes to `Setup`. A `viewModelScope` job clears `exitArmed` after 2000 ms. Because the `BackHandler` always consumes the press, the predictive-back gesture never previews leaving the app mid-session.

### 3.2 Keystroke cost (FR-7)
The answer string is the only state a keystroke changes. `Keypad` takes no answer state, only callbacks and a `submitEnabled` flag, so Compose skips it on a digit tap; only the answer box redraws. Key presses don't recompose anything: `ChunkyButton` reads its pressed state inside `graphicsLayer`, so a press only redraws that one key. All UI state classes are immutable, and the callbacks are ViewModel method references.

### 3.2a Fitting short screens (FR-6.3)
Baloo 2's built-in line spacing is very tall, so the problem and the answer trim their line height to the glyphs (`LineHeightStyle.Trim.Both`). The problem text auto-sizes (96 → 40 sp) and is the one element of the card area that shrinks when height runs out. The answer box, the nudge and the reveal keep their full size. A first build that skipped this squeezed the nudge pill until its text was clipped.

### 3.3 Answer flow (FR-3.3, FR-3.4)
```
submit():
  if input == card.answer:
      correct++ ; feedback = Correct ; after 300 ms → next()
  else if attempt == 1:
      attempt = 2 ; feedback = Nudge            // input kept, keypad live
  else:
      feedback = Reveal ; after 1500 ms → next()
next(): index++, attempt = 1, input = "", feedback = None; if done → Results
```
The delays run as `viewModelScope` coroutines. Input is ignored while `feedback` is Correct or Reveal.

### 3.4 Timing (FR-3.5)
`SystemClock.elapsedRealtime()`, which is monotonic and unaffected by clock changes. The ViewModel stores `accumulatedMs` plus `runningSince`. It pauses on `ON_STOP` and resumes on `ON_START`, through a `LifecycleEventObserver` in `MainActivity`. The on-screen clock ticks once a second from a coroutine, and only the timer `Text` reads it.

### 3.5 Screen stays on (FR-3.7)
`CardContent` sets `LocalView.current.keepScreenOn` in a `DisposableEffect` and clears it on dispose, so the flag lives exactly as long as the Cards state. It is the window's `FLAG_KEEP_SCREEN_ON`, not a `WakeLock`, so the manifest needs no `WAKE_LOCK` permission.

### 3.6 Surviving process death (FR-3.6)
`SavedStateHandle` holds the config, the RNG seed, index, correct count, attempt and accumulated time. The deck is regenerated from the seed, so it is never serialized. If restoring fails, the app falls back to Setup.

## 4. Core Workflows

### 4.1 Deck generation (FR-2)

`DeckGenerator.generate(config, random: Random): List<Card>` is pure and deterministic for a given seed.

1. **Pools.** For each selected op, enumerate every valid card under FR-2.1–2.3, deduplicated by canonical form: for + and ×, `(min(a,b), max(a,b))`. At N = 100 that is about 5.1k cards for + and −. × and ÷ stop at the 12 times table (`Operation.limit`, FR-2.1), so from N = 12 up they are 91 and 156 cards. All of it takes under 1 ms. Display order for + and × is randomised per draw, so `4 + 6` and `6 + 4` both appear over time.
2. **Op sequence (FR-2.4).** Fill C slots round-robin (⌊C/k⌋ or ⌈C/k⌉ each) and shuffle. Then repair any run of more than 2 of the same op by swapping with the nearest different op later in the sequence.
3. **Fill slots.** For slot i with op o, shuffle o's pool lazily: draw random indices and track the ones tried. Accept the first candidate that passes all of:
   * not already used (FR-2.5, canonical form);
   * not a near neighbour of any of the last `w` cards (FR-2.6, `w = 3`);
   * if trivial, under budget and the previous card wasn't trivial (FR-2.7).
4. **Relax (FR-2.8).** If o's pool is exhausted without a pass, step the relaxation level (w = 1 → no near-neighbour check → allow repeats except back-to-back → no trivial budget) and retry this slot. The level never goes back down within a deck.
5. **Near-neighbour test:**
   ```kotlin
   fun close(x: Int, y: Int) = abs(x - y) <= 2
   fun near(p: Card, q: Card): Boolean = p.op == q.op && when (p.op) {
     PLUS, TIMES -> (close(p.a,q.a) && close(p.b,q.b)) || (close(p.a,q.b) && close(p.b,q.a))
     MINUS       -> close(p.a,q.a) && close(p.b,q.b)
     DIVIDE      -> close(p.divisor,q.divisor) && close(p.quotient,q.quotient)
   }
   ```
6. **Trivial test:** `a == 0 || b == 0 || a == 1 || b == 1` for × and +, adapted per op as in the `SPEC.md` §1.4 definition.

The worst case is bounded: at most |pool| draws per slot per relaxation level, 4 levels and 100 slots. That is far below the 50 ms budget.

### 4.2 Keypad digit limit (FR-3.2)
`maxDigits = max over selected ops of digits(maxAnswer(op, N))`, where maxAnswer is 2N for +, N for −, T² for × and T for ÷, with T = min(N, 12).

### 4.3 Settings persistence (FR-1.6)
`SettingsRepository` wraps `DataStore<Preferences>` with keys `name`, `n`, `ops` (a string set) and `count`. Reads are a `Flow` collected in the ViewModel. `UiState.Setup` starts with the defaults and updates when the first value arrives, so nothing blocks the first frame. Values are written on Start.

### 4.4 Name input (FR-1.1)
A `TextField` with an input filter: `Character.isLetter`, space, `-`, `'`, and at most 20 characters. `KeyboardOptions(capitalization = Words, imeAction = Done)`.

### 4.5 Startup path (FR-7)
* `installSplashScreen()` with no keep-on-screen condition.
* No work in `Application.onCreate`, no content providers beyond the AndroidX defaults, and no reflection or JSON.
* The Baseline Profile covers launch → Setup → Start → 5 answers → Results.

### 4.6 Strings
All text lives in `strings.xml`, with placeholders such as `results_title_named = "%1$s's score:"`, `results_title = "Your score:"` and `greeting = "Ready, %1$s?"`. That makes localization a pure translation task (`VISION.md` §7).

**Languages: English and Spanish.** The app follows the system language and falls back to English for any other, with no picker of its own.
* **Android:** translations are `values-<lang>/strings.xml`. `Sumbee` and the `7 / 25` progress counter are `translatable="false"`. `generateLocaleConfig` lists the languages for Android 13+'s per-app language setting, and `res/resources.properties` names English as the fallback. `TranslationsTest` fails if a language lacks a string or changes its placeholders.
* **iOS:** `Sumbee/Resources/Localizable.xcstrings`, a String Catalog keyed by the English text, with `es` in `knownRegions`. Strings that read the same in every language are marked `shouldTranslate: false`, so Xcode shows the catalog as fully translated and flags any new string as untranslated. `LANGUAGE=es` (`TEST_RUNNER_LANGUAGE`) runs the UI test in Spanish.
* **Writing a translation:** use informal "tú"-style address for the child, and no word that takes the child's gender, since the app doesn't know it. So Spanish has "¡Vamos, Jenny!", not "¿Lista?". Each language writes the whole score title itself ("Puntos de Jenny:"), never the English possessive. Baloo 2 covers only Latin scripts (and Devanagari), so a Cyrillic, Greek or CJK language needs a second heading font first. A right-to-left language needs the layout mirrored and checked.

## 5. Testing

*Status (2026-10-08):* `DeckGeneratorTest` (8 tests, about 2,500 decks) and `SessionViewModelTest` (16 tests) are written and pass: `./gradlew testDebugUnitTest`. The Compose UI test and the benchmarks are not written yet. In their place, the release build was driven end to end on an API 36 emulator: a full 25-card session, the nudge, the reveal, the double Back, Results, and the settings surviving a force-stop. A warm-process-killed cold start measured about 0.5 s there. That is not the FR-7 reference device.

* **`DeckGeneratorTest`** (JUnit, pure JVM): seeded loops of thousands of decks across N ∈ {5, 10, 15, 20, 50, 100}, every non-empty op subset, and C ∈ {25, 50, 75, 100}. It asserts:
  * size == C;
  * the FR-2.1–2.3 bounds;
  * the FR-2.4 balance and runs ≤ 2;
  * no repeats and no near neighbours whenever relaxation wasn't needed (the generator reports its final relaxation level);
  * the trivial budget;
  * generation time.
* **`SessionViewModelTest`:** correct → next; wrong → nudge → correct counts correct; wrong → wrong → reveal counts wrong; timer pause and resume using a fake clock; one Back on Cards → hint, session kept; two Backs within 2 s → Setup; two Backs 3 s apart → still in Cards; one Back on Results → Setup; restore from `SavedStateHandle`.
* **Compose UI test:** Setup → Start → answer all cards → Results shows the name and score → Play again → a new first card → Back → Setup with settings kept.
* **Benchmarks** (`:baselineprofile`): `StartupBenchmark` (cold) and an answering-loop `FrameTimingMetric`, run on a low-end emulator profile (2 GB RAM, API 28) against the FR-7 budgets.

## 6. Engineering Risks & Mitigations

| Risk | Mitigation |
| :-- | :-- |
| Compose cold start too slow on low-end devices | Baseline Profile, R8 full mode, and a near-empty startup path. If FR-7 still fails on the reference device, port the three states to plain Views. The model and ViewModel are UI-agnostic, so only `ui/` changes. |
| Generator stalls on tiny pools | Relaxation levels with bounded draws (§4.1). The test matrix includes the smallest pools (N = 5, each op alone, 100 cards). |
| Lost session on process death | `SavedStateHandle` plus a seed-based deck (§3.6). |
| Keypad lag under background load | Leaf-level recomposition (§3.2), no animations on keystroke, and frame timing measured in benchmarks. |
| Tablet layouts look stretched | Max content width, and `App` scales the whole layout by raising `LocalDensity`: min(width / 480 dp, height / 860 dp), held between 1 and 1.5 (FR-6.3). Every dp and sp grows, so screens lay out again, sharp, with no per-screen code. The window is measured inside the system bars but not the keyboard, so typing a name doesn't rescale it. On tablets Android 16 ignores `screenOrientation`, and landscape fits at 1×. |

## 7. Build & Release

* **M1:** a `debug` APK installed by `adb install` on the child's device.
* **Signing:** `bundleRelease` signs the AAB with the upload key (`SUMBEE_UPLOAD_*` properties, see README). Play App Signing holds the app signing key, so builds installed from Play carry Google's certificate, not the upload key's.
* **M3:** a signed release AAB with Play App Signing, and Families program enrollment:
  * target age 5–12;
  * Data Safety: no data collected or shared;
  * no ads declared;
  * a privacy policy URL, which can be a static page stating that nothing is collected.

## 8. iOS

A native SwiftUI port in `ios/`, kept behaviour for behaviour with the Android app. Nothing is shared between the two at build time. Change one, then change the other.

```
ios/
  SumbeeCore/              // Swift package, no UIKit or SwiftUI: `swift test` runs it on the Mac
    MathOperation.swift    // Operation.kt (renamed: Foundation already has an Operation)
    Card.swift, SessionConfig.swift, DeckGenerator.swift   // line-for-line ports of model/
    SeededRandom.swift     // SplitMix64: Swift's own generator can't be seeded
    SessionModel.swift     // SessionViewModel.kt as an @Observable, plus SessionSnapshot
    Scheduler.swift        // the clock and delays, injected so tests move time by hand
    SettingsStore.swift    // a JSON file kept out of backups, in place of DataStore
  Sumbee/                  // the app: SwiftUI views, fonts, asset catalog, privacy manifest
  SumbeeUITests/           // XCUITest: a full session through the keypad, with screenshots
  Sumbee.xcodeproj         // folder-synchronized groups: new files need no project edits
```

* **Stack:** SwiftUI, iOS 17+, iPhone (portrait) and iPad (any orientation, SPEC FR-6.3), no dependencies. Bundle id `dev.sumbee`, the same version numbers as Android.
* **Decks** follow the same rules and pass the same tests, but they don't match Android's for a given seed. They don't need to, since nothing crosses platforms.
* **Back (FR-3.6):** iOS has no system Back. On Cards, an ✕ in the header calls `back()`: one tap shows "Tap ✕ again to stop" for 2 s, and a second tap leaves. On Results, a **Change settings** link goes to Setup.
* **Lifecycle and timing (§3.4):** `scenePhase` `.active` and `.background` call `onVisible()` and `onHidden()`.
* **Restoration (§3.6):** `SessionSnapshot` holds the same fields `SavedStateHandle` does, with the same rule that a decided card is saved as the next one. It is stored with `@SceneStorage` on every change and on backgrounding. That is iOS's own state restoration, so a session comes back after iOS ends the app in the background, but not after the user swipes it away.
* **Screen on (§3.5):** `isIdleTimerDisabled` while `CardView` is on screen.
* **Layout:** the same sizes in pt as Android's dp, including the 396 pt card chrome that decides key height (§3.2a) and `digitsOnly` for Baloo's tall line box.
* **Fonts** are copied from `android/app/src/main/res/font` and listed in `UIAppFonts`.
* **Icons:** the stroke icons are SwiftUI `Path`s on the same 24-unit grid. `build_icons.py` writes the 1024 px app icon and the header bee into the asset catalog.
* **Settings and backups (§4.3, `VISION.md` §6):** the settings are `Application Support/Sumbee/settings.json`, not `UserDefaults`, which iOS copies to iCloud and computer backups. The folder is marked `isExcludedFromBackup`, the counterpart of Android's `allowBackup="false"`. The mark is on the folder because an atomic write replaces the file and would drop a mark set on it. The restoration snapshot leaves the name out and takes it back from the settings, since scene state isn't covered by that mark.
* **Privacy:** `PrivacyInfo.xcprivacy` declares no tracking and no collected data, plus the system-uptime API (reason 35F9.1) for the session clock. The app makes no network calls, but iOS has no network permission to leave out, so this rests on the code alone. `ITSAppUsesNonExemptEncryption` is false, so uploads skip the export-compliance question.
* **iPad:** the same views, scaled. `AppView` works out `layoutScale` = min(width / 480, height / 860), held between 1 and 1.5, and passes it down as the `uiScale` environment value. Every view multiplies its own sizes by it: fonts, padding, frames, corner radii and the 396 pt card chrome. The column is 480 × scale wide and centred. Phones are never 480 pt wide, so they always get 1 and are unchanged, and a short window such as the iPad mini in landscape gets 1 too. A 13″ iPad Pro in portrait gets 1.5. The window is measured without the keyboard, so the layout doesn't rescale while a name is typed. Stretching the finished drawing with `scaleEffect` was tried first and dropped, because it left text soft. `ORIENTATION=landscape` (`TEST_RUNNER_ORIENTATION` from xcodebuild) runs the UI test in landscape. The iPad mini in landscape is the shortest window an iPad gives the app, and everything fits there.
* **Store screenshots:** `design/store/ios/`: `iphone-*` at 1320×2868 (6.9″) and `ipad-*` at 2064×2752 (13″), next to Android's in `design/store/android/`. They come from `SumbeeUITests` on the iPhone 18 Pro Max and iPad Pro 13-inch simulators, with `xcrun simctl status_bar … override --time 9:41` and `TEST_RUNNER_SCREENSHOT_DIR` set. The test launches the app with `-uiTesting -seed 16` (the seed is honoured only with `-uiTesting`), so every run deals the same cards: 7 × 9, then 6 × 6 for the nudge, then 10 + 4.
* **Tests:**
  * `SumbeeCoreTests` (Swift Testing, 34 tests) ports `DeckGeneratorTest` and `SessionViewModelTest`. It adds checks for a stopped clock, restoring a decided card, bad snapshots, the settings file and its backup exclusion, and the name staying out of the snapshot. Run it with `swift test`.
  * `SumbeeUITests` plays a full 25-card session (right answer, nudge, reveal, Results, Play again, the ✕ exit), then checks that one ✕ tap doesn't leave.
  * *Not covered by a test:* restoration after iOS ends the app, which XCUITest can't trigger. Check it from Xcode by sending the app home and stopping it, then running again.
