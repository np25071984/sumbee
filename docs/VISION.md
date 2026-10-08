# Vision: Sumbee

## 1. Executive Summary

Sumbee is a **free, offline Android app for daily arithmetic practice, for kids aged 5–12.** The child (or a parent, once) picks how big the numbers go, which operations to practise and how many cards, then taps Start. The child answers each card on a big on-screen keypad and at the end sees their score and time. That is the whole product.

The name, chosen 2026-10-08, is "sum" plus "spelling bee": a math bee. The icon is a bee with a plus on its back. A Google Play search that day found no math app with the name, only an unrelated "Sumbee.mn". A trademark search is still to do before M3.

It started for one child: a 2nd grader whose school asks for math practice every day. **If it works for them, it ships free to everyone on Google Play** (§5.4). That decision is what this project exists to make.

Its wedge:

1. **Instant on cheap devices.** Kids get the cheapest phones and tablets on the market, loaded with preinstalled software. The app has to feel instant on those anyway (§2.3).
2. **One tap to start.** Settings are remembered, so a daily session is: open the app, tap Start.
3. **A smart deck.** Cards feel varied. The child never gets `6 + 5` right after `6 + 4`, never sees the same card twice, and rarely gets a throwaway like `×1` (`SPEC.md` FR-2).
4. **Kid-safe math.** No negative answers, no remainders, never ÷0.
5. **Nothing collected.** No accounts, no network, no ads.

### 1.1 What Sumbee is not

* **Not a learning platform.** It has no lessons, explanations or curriculum. It is drill, and the teaching happens at school.
* **No accounts and no history.** Each session stands alone, and Play again throws it away. The only things remembered are the last-used settings and the child's name, both on the device.
* **No reward economy.** No coins, streaks, badges or leaderboards. The score and the time are the reward.
* **No ads, no in-app purchases, no analytics, no network access.**
* **Not adaptive.** It does not track which facts a child gets wrong, because that would need history. See §7.

What is left is small on purpose. A small app can be fast on a bad phone and simple enough for a six-year-old to run alone.

---

## 2. Mission & Principles

### 2.1 Mission
Make daily math practice something a kid can start on their own in one tap and finish in five minutes.

### 2.2 Value proposition
* **Zero friction:** open the app, tap Start, and practice is under way.
* **Feels fresh every day:** the smart deck avoids repeats and near-repeats.
* **Personal:** the child types their name once, and every session ends with "Jenny's score:".
* **Safe:** nothing to sign up for, nothing sent anywhere, nothing to buy.
* **Works on the phone the kid actually has.**

### 2.3 Design principles

These two override everything else. A feature that conflicts with either one doesn't ship.

1. **Speed.** The reference device is a low-end Android Go-class phone with 2 GB of RAM (`SPEC.md` FR-7). On it, cold start, every keypad tap and every card change must feel instant. Slowness is a bug, not polish.
2. **Simplicity.** No menus, no settings screen, no multi-step navigation, no dialogs. One screen with three states: Setup, Cards, Results. Everything is a tap or a swipe. A feature that needs a new screen or a menu doesn't ship.

A third rule follows from the audience: **gentle, not punishing.** A wrong answer gets an "Are you sure?" and a second chance, not a buzzer.

### 2.4 Free, by decision
**Sumbee is free: no price, no in-app purchases, no ads, no tips** (decided 2026-10-08). The options were weighed and rejected:
* **Ads** pay little in kids apps and would cost the speed promised in §2.3.
* **A one-time unlock** would split the app into free and paid halves and need a parental gate.
* **A paid download** would sell poorly in a category full of free apps.
* **School licensing** would need accounts and history (§1.1).

Staying free keeps the product's edge (instant, simple, nothing collected) intact and keeps the publish decision (§5.4) about whether kids use it, not about whether it earns. Reopen this only if the app's running costs stop being zero, which by design (§6) they are.

---

## 3. Audience

### 3.1 The first user
A 2nd grader who must practise math daily. This child is the validation (§5).

### 3.2 Kids 5–12
The public audience. Younger kids use small ranges (N = 5 for "sums up to 10", + and −). Older kids use larger ranges with × and ÷. The same app covers both because the range and operations are chosen per session.

### 3.3 Parents and teachers
They set it up once, or not at all. They are the ones who find it on Play, so the store listing speaks to them: free, offline, no ads, no data collected.

---

## 4. Product

### 4.1 The loop

```
Setup ──Start──▶ Cards ──last card──▶ Results ──Play again──▶ Cards
                                         └──Back──▶ Setup
```

### 4.2 Features
* **Setup** (`SPEC.md` FR-1): name, "numbers up to N" (N = 5…100), operations (+ − × ÷, any mix) and number of cards.
* **Smart deck** (FR-2): kid-safe, balanced across operations, no repeats, no near-neighbours, rare trivial cards.
* **Cards** (FR-3): a big problem, a big keypad, progress "7 / 25", a running timer and an "Are you sure?" nudge on a wrong answer.
* **Results** (FR-4): "Jenny's score: 21 / 25" and "Time 2:34".
* **Play again** (FR-5): a new deck straight away, same settings. Back goes to Setup to change them.

### 4.3 Why the deck is "smart"
A random generator is technically correct and feels wrong. `6 + 4` followed by `6 + 5` is practically the same question, and a kid notices. The deck is built so that each card feels like a new question. That is the difference between "practice" and "the same thing again".

---

## 5. Roadmap & the Decision

### 5.1 M1: Family build
The complete app as `SPEC.md` describes it, sideloaded onto the child's device as a debug build.

### 5.2 M2: Validation (2–3 weeks)
The child uses it for the daily school practice. There are no analytics (§1.1), so the evidence is a parent's observation, written down weekly:
* Days used per week.
* Whether the child starts it themselves.
* Complaints, verbatim.
* Anything slow or confusing.

### 5.3 M3: Public release
Free on Google Play, enrolled in the Designed for Families program. Before submitting:
* the performance budgets (FR-7) are met on the reference device;
* the privacy policy is published;
* the Families declarations are complete (§6).

### 5.4 The decision gate (end of M2)
* **Go (publish):** used on at least 5 days a week for 3 consecutive weeks, without being pushed toward it, and with no recurring complaint left unfixed.
* **Iterate:** used, but with one specific recurring complaint. Fix it, then run one more week of M2.
* **Stop:** avoided even after a fix. The app stays a family app and isn't published.

---

## 6. Privacy & Compliance

* **Nothing is collected.** The child's name and the last-used settings are stored only on the device (local preferences) and never leave it.
* **No network permission.** The app is technically unable to send anything anywhere.
* **No ads and no third-party SDKs.** No analytics or crash reporting either, so there's nothing to disclose under COPPA beyond "we collect nothing".
* **Google Play Families policy.** The target audience is declared as 5–12, the Data Safety form says "no data collected or shared", and a privacy policy URL is required even when the app collects nothing.

---

## 7. Open Questions & Future Ideas (not committed)

* **Weak-fact practice** ("give me more of the ones I missed") would need history, which §1.1 rules out. Revisit only if M2 shows a real need, and keep it on-device if so.
* **Localization.** Strings are resources from day one (`IMPLEMENTATION.md` §4.6). Translations come after launch.
* **iOS.** Not planned.
