# Sumbee: Spec

| | |
| :-- | :-- |
| **Version** | 0.1 |
| **Status** | Draft. Describes Milestone 1 (Family build) as intended, before implementation |
| **Last updated** | 2026-10-08 |
| **Related documents** | `VISION.md` (why the app exists, its principles, and the publish decision; the authority on *what ships and why*); `IMPLEMENTATION.md` (structure, algorithms and the build; the authority on *how it's built*) |

## 1. Introduction

### 1.1 Purpose
This document specifies what Sumbee does, from the point of view of the child and parent using it. It does not cover why (`VISION.md`) or how it is built (`IMPLEMENTATION.md`). Each functional requirement (FR) is written to be independently testable.

### 1.2 Scope
**In scope:** the Setup screen (FR-1), deck generation (FR-2), answering cards (FR-3), results (FR-4), Play again (FR-5), screen behavior (FR-6), performance budgets (FR-7) and the other non-functional requirements (FR-8).
**Out of scope:** everything `VISION.md` §1.1 rules out. FR-9 lists the deliberate limits.

### 1.3 Intended audience
Whoever implements, tests or changes the app.

### 1.4 Definitions

| Term | Meaning |
| :-- | :-- |
| **N** | The range limit chosen on Setup, 5–100. Every operand (or, for ÷, divisor and quotient) is in 0..N. |
| **Operation** | One of +, −, ×, ÷. |
| **Card** | One problem, such as `6 + 4`, with exactly one whole-number answer ≥ 0. |
| **Deck** | The ordered list of cards generated for one session (FR-2). |
| **Session** | One run through a deck, from Start to Results. |
| **Attempt** | One Submit on a card. A card allows at most two (FR-3.4). |
| **Nudge** | The "Are you sure?" prompt after a wrong first attempt. |
| **Trivial card** | ×0, 0×, ×1, 1×, +0, 0+, −0, a−a, ÷1, a÷a, 0÷b. |
| **Near neighbour** | Two cards of the same operation whose operands each differ by ≤ 2 (FR-2.6). |
| **Reference device** | A low-end Android Go-class phone or emulator with 2 GB RAM, API 27–29 (FR-7). |

## 2. Actors

| Actor | Description |
| :-- | :-- |
| **Child** | Answers the cards. May also do Setup alone. Assumed able to read numbers but not necessarily instructions. |
| **Parent** | Usually does Setup the first time. Setup is remembered, so later sessions need no parent. |

There are no accounts, no server and no other actors.

## 3. FR-1: Setup

The app opens on Setup. Everything fits on one screen without scrolling on a 5" phone in portrait (FR-6).

### FR-1.1 Player name
**Description:** An optional name used to personalise the session.
**Inputs:** A text field labelled "What's your name?".
**Behavior:**
1. The name is trimmed. At most 20 characters are accepted, and further typing is ignored.
2. Letters of any script, spaces, hyphens and apostrophes are allowed ("Zoë", "Аня", "Mary-Kate", "O'Neil"). Other characters are not accepted.
3. The keyboard closes on Done and on any tap outside the field.

**Outputs:** The name is used by FR-3.1 and FR-4.1. Left empty, the generic wording applies.

### FR-1.2 Number range
**Description:** How big the numbers go.
**Inputs:** One slider labelled "Numbers up to **N**", N = 5…100 in steps of 5, default 20. N = 5 is for the youngest kids: + at N = 5 is "sums up to 10".
**Behavior:** The current value of N shows live while sliding. There is no minimum field: the range is always 0..N.

### FR-1.3 Operations
**Description:** Which operations the deck uses.
**Inputs:** Four large toggle chips: + − × ÷. Default: + only.
**Behavior:**
1. Any combination may be selected.
2. Deselecting the last selected operation is refused, and that chip stays on. At least one operation is always selected.

### FR-1.4 Number of cards
**Inputs:** A slider with four stops (25, 50, 75 and 100 cards), labelled under the track, default 25. The chosen count shows live while sliding, like FR-1.2.

### FR-1.5 Start
**Behavior:** One big Start button. Tapping it generates the deck (FR-2) and shows the first card (FR-3). It is always enabled, because FR-1.3 guarantees a valid setup.

### FR-1.6 Remembered settings
**Behavior:**
1. Name, N, operations and card count are saved on the device whenever Start is tapped, and survive closing the app, restarting the phone and app updates. They are lost only when the app is uninstalled or its data is cleared.
2. On launch, Setup shows the saved values. Until they load, which should take milliseconds, it shows the defaults, and loading never delays the first frame.
3. Nothing else is saved. There are no scores and no history.

## 4. FR-2: Deck Generation

Generation is deterministic for a given random seed, which is how it is tested. It always returns exactly the requested number of cards and never fails or hangs.

### FR-2.1 Operand bounds
* **+ and ×:** a, b ∈ 0..N.
* **−:** a, b ∈ 0..N with a ≥ b.
* **÷:** the card is `a ÷ b = q`, with divisor b ∈ 1..N, quotient q ∈ 0..N and a = b·q. Division mirrors multiplication, so at N = 10 it covers exactly the inverse of the ×10 table.

### FR-2.2 No negatives
Every answer is ≥ 0.

### FR-2.3 Whole division, never ÷0
Every ÷ card divides exactly, and its divisor is ≥ 1.

### FR-2.4 Operation balance
With k operations selected and C cards, each operation appears ⌊C/k⌋ or ⌈C/k⌉ times. When k ≥ 2, no operation appears more than 2 times in a row.

### FR-2.5 No repeats
No card appears twice in a session. `a + b` and `b + a` count as the same card, and likewise for ×.

### FR-2.6 No near neighbours
A card must not be a near neighbour of any of the previous 3 cards. Two cards are near neighbours when they use the same operation and:
* **+ and ×:** under some pairing of their operands, both differences are ≤ 2.
* **−:** |a−a′| ≤ 2 and |b−b′| ≤ 2.
* **÷:** |b−b′| ≤ 2 and |q−q′| ≤ 2, comparing divisor with divisor and quotient with quotient.

Examples at N = 20:
* `6+4` → `6+5` ✗
* `6+4` → `7+3` ✗
* `6+4` → `5+7` ✗ (pairs as 4~5 and 6~7)
* `6+4` → `13+7` ✓
* `6+4` → `6×5` ✓ (a different operation)

### FR-2.7 Trivial cards are rare
At most max(1, ⌊C/10⌋) trivial cards per session, and never two in a row.

### FR-2.8 Graceful relaxation
When the pool can't satisfy the rules (e.g. N = 10, + only, 100 cards: only 66 distinct cards exist), the rules are relaxed one step at a time, in this order, only as far as needed:
1. Shrink the FR-2.6 look-back from 3 cards to 1.
2. Drop FR-2.6.
3. Allow repeats (FR-2.5), but never the same card twice in a row.
4. Lift the FR-2.7 budget.

FR-2.1–2.3 are never relaxed.

## 5. FR-3: Answering

### FR-3.1 Card display
**Behavior:**
1. The problem shows in very large type, e.g. `6 + 4 = ?`, with progress `7 / 25` and the running time.
2. Operators display as + − × ÷, never `*` or `/`.
3. With a name, the first card shows a one-line greeting under the answer box until it is first answered: "Ready, Jenny?"
4. The greeting, the feedback (FR-3.3, FR-3.4) and the Back hint (FR-3.6) share one message slot under the answer box. The problem takes the height that is left and shrinks to fit it, so it stays readable on a 5" phone.

### FR-3.2 Keypad
**Inputs:** An on-screen keypad with 0–9, ⌫ and ✓ (Submit). The system keyboard never appears.
**Behavior:**
1. Digits append to the answer, and ⌫ removes the last digit.
2. Input stops at the digit count of the largest possible answer for the selected ops and N. For example, + at N = 20 allows 2 digits; × at N = 100 allows 5.
3. Leading zeros collapse: "0" then "7" gives "7".
4. ✓ is disabled while the answer is empty.
5. Each key is at least 64 dp and gives immediate visual feedback on press. Keys are up to 76 dp tall and give up height, down to 64 dp, on a short screen.

### FR-3.3 Correct answer
On a correct submission the card is scored correct, gets a brief green confirmation (≤ 300 ms), and the next card appears automatically. After the last card, the app goes to Results (FR-4).

### FR-3.4 Wrong answer: the nudge
**Behavior:**
1. On a wrong **first** attempt, the answer stays on screen, a gentle "Are you sure? 🤔" appears, and the keypad stays live. There is no sound, no red flash and no buzzer.
2. The child may edit the answer, or leave it, and tap ✓ again. This second attempt is final.
3. A correct second attempt scores the card **correct** (rewarding self-checking) and continues as FR-3.3.
4. A wrong second attempt scores the card **wrong**. The card shows the right answer calmly, e.g. `6 + 4 = 10`, for 1.5 s, then the next card appears.

### FR-3.5 Timer
**Behavior:**
1. The timer starts when the first card appears and stops on the final attempt of the last card.
2. It shows as m:ss.
3. It pauses while the app isn't visible (backgrounded or screen off) and resumes when the app returns.

### FR-3.6 Leaving a session
**Behavior:**
1. **Accidental exits are guarded by a double Back, not a dialog** (dialogs are ruled out by `VISION.md` §2.3). The first system Back (button or edge-swipe gesture) during Cards does not leave. It shows an inline hint above the keypad, "Press Back again to stop", for 2 s, and the card, the answer being typed and the timer carry on untouched. A second Back within those 2 s returns to Setup and discards the session. After 2 s the hint fades and the next Back counts as a first press again.
2. Rotation or a configuration change keeps the session as it was.
3. If the system kills the process in the background, the session is restored where possible. Otherwise the app reopens on Setup.

## 6. FR-4: Results

### FR-4.1 Results screen
**Outputs:**
* A heading: "**Jenny's score:**", or "**Your score:**" without a name.
* The score in large type: `21 / 25`.
* The time: `Time 2:34`.
* One button: **Play again** (FR-5).

## 7. FR-5: Play again

### FR-5.1 Play again
**Behavior:** Discards the finished session and starts a new one straight away, with the same settings and a freshly generated deck (FR-2). The first card shows, the score is 0 and the clock starts from 0:00. One tap, with no stop at Setup. It was called "Reset" and returned to Setup until 2026-10-08. A child-facing label and one tap fewer for the daily repeat won out.

### FR-5.2 Changing settings
System Back on Results returns to Setup with all remembered settings (FR-1.6), with a single press, because the session is already over and nothing can be lost.

## 8. FR-6: Screen & Navigation

### FR-6.1 One screen, three states
Setup, Cards and Results are three states of a single screen. There is no navigation stack, no app bar, no menu, no settings screen and no dialogs.

### FR-6.2 Interaction
Every action is a tap, or a swipe on a slider. Nothing is hidden behind a long-press, a hamburger menu or an overflow menu.

### FR-6.3 Layout
* Portrait only.
* Works from 4.5" phones to 10" tablets. On large screens the content is centred with a max width, and the keypad scales up.
* Setup never scrolls on a 5" phone.
* Respects system font scale up to 1.3× without clipping.

## 9. FR-7: Performance Budgets

These are measured on the reference device (§1.4), release build, with Macrobenchmark.

| Metric | Budget |
| :-- | :-- |
| Cold start → Setup interactive | < 1.0 s |
| Keypad tap → digit shown | < 50 ms, no dropped frames during answering |
| Card → next card | < 100 ms after the confirmation |
| Deck generation, N = 100, 100 cards, all ops | < 50 ms |
| APK download size | < 5 MB |
| Memory (PSS) during a session | < 60 MB |

A missed budget blocks release (`VISION.md` §5.3).

## 10. FR-8: Other Non-functional Requirements

* Fully offline. No permissions requested, INTERNET included.
* minSdk 24 (Android 7.0).
* Light theme with high contrast, and colors that never carry meaning alone. "Are you sure?" is text, not just a color.
* All user-visible text in string resources.

## 11. FR-9: Deliberate Limits

The app has no accounts, no history, no stats across sessions, no sound, no ads, no purchases, no analytics, no sharing and no multiple profiles. See `VISION.md` §1.1.
