<div align="center">

# 🛫 Runway

**Make your money last the whole semester.**

A budgeting app built for college students: it plans by **semester**, not by month,
and tells you how much you can safely spend **today**.

![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20Android%20%7C%20macOS-8B6CFF)
![Tests](https://img.shields.io/badge/tests-63%20passing-C6FF3D)
![Status](https://img.shields.io/badge/status-prototype-FFB547)

</div>

---

## Contents

- [Why Runway?](#why-runway)
- [Features](#features)
- [How the numbers work](#how-the-numbers-work)
- [Design system](#design-system)
- [Architecture](#architecture)
- [Getting started](#getting-started)
- [Testing](#testing)
- [Current limitations](#current-limitations)
- [Future plans](#future-plans)
- [Privacy](#privacy)

---

## Why Runway?

Students don't get paid every month. Money arrives in **lumps**: a loan
disbursement, a scholarship, help from parents, a few shifts at a part-time job.
That one lump has to last until the end of term, and monthly budgeting apps don't fit that.

Runway answers two questions every day:

1. **How much can I spend today without running out before the term ends?**
2. **If I keep spending like this, when does my money run out?**

There's **no bank linking**. You log expenses by hand, and Runway makes that as quick
as it can be: two taps for most purchases. Your money data never leaves your phone.

---

## Features

### 🏠 Home: your runway at a glance
- **Safe to spend today:** a big glowing ring shows how much of today's allowance
  you've used, with the remaining amount rolling up in the centre.
- **Runway timeline:** a bar from term start to term end with markers for
  *today*, *money runs out*, and pins for upcoming big costs.
- **Status pill:** "Money lasts until Nov 27 · Term ends Dec 11", with
  `14 days short` (coral) or `Covered ✓` (mint).
- **Coming up:** big known costs (flight home, formal ticket, phone bill) that
  are **reserved ahead of time** so they can't be spent by accident.
- **This week:** a need vs want split bar, plus your recent expenses.
- **Personal greeting** with your 🔥 streak chip and account avatar.

### ➕ Quick Add: log an expense in two taps
- Big amount display with a **custom keypad and haptics**.
- **Quick picks:** ☕ Coffee $4.50 · 🛒 Groceries $38 · 🚇 Transit $2.90 ·
  🍕 Late-night food $14 · 📦 Delivery $22 · 📚 Supplies $12.
- **Note field** ("Uber to airport") and **13 categories**, including
  🚕 Uber / ride, ✈️ Travel, 🍔 Eating out, 🛍️ Shopping, 🎉 Fun, 🧾 Bills.
- **Need / Want** toggle with a sliding pill.
- Logging updates Home instantly and extends your daily streak.

### 🤖 Coach: "Can I afford it?"
- Chat screen with quick chips ("Concert ticket $60", "AirPods $129", …) or
  type your own question with any amount.
- Replies with a **verdict card** after a short typing indicator:

| Verdict | When | Example |
|---|---|---|
| ✅ **Yes** (mint) | amount ≤ safe-to-spend today | "You'll still have $12.50 left today." |
| 🔁 **Yes, if you trade for it** (amber) | amount ≤ 12% of available money | "Skip 3 delivery orders." |
| ⏳ **Not this term** (coral) | anything bigger | "Put $35/week aside and you'll have it in 4 weeks." |

- Every card shows your **daily number before → after** and **runway days lost**.

### 👯 Squad: friends without sharing amounts
- **Mochi, your money pet:** a hand-drawn blob that breathes and blinks.
  Mood follows your budget health (*thriving / chill / worried*), and it levels up with your streak.
- **No-delivery week challenge** with 7-day progress dots per friend.
- **Streak leaderboard:** streaks only, **never dollar amounts**.
- **Roommate splits:** "Aarav owes you $12.40 · Pizza night" with an animated *Settle up*.
- **Split a bill:** enter what it was and what you paid, pick roommates, and it
  splits evenly. They get IOUs; only **your share** counts as spending.

### 🎬 Launch intro: "Mochi's Takeoff"
A ~4-second intro on launch, in the spirit of Pixar's lamp:
1. A lime runway draws itself and landing lights blink on.
2. Mochi hops in with squash & stretch; each letter of **r·u·n·w·a·y** pops up to catch it.
3. Mochi flattens the **y**, looks at you, blinks, and hops it back up.
4. The lights race, Mochi zooms off, and the word glides up into the logo.
5. Mochi lands on the logo's **y**, and the login card rises underneath.

Tap anywhere to skip. Signed-in users go straight from the intro into Home
through a circle that opens from Mochi. With **Reduce Motion** on, it's skipped.
It's drawn in code (one `CustomPainter`, no video), with haptic ticks on the
lights and landings.

### 🔐 Login
- Sign in / Create account with a sliding toggle, inline validation and a shake on errors.
- The button morphs from label to spinner to ✓, then Home is revealed through a
  **circle that grows out of the button**, with a lime ring on its edge.
- Login is remembered on the device; the avatar on Home opens an account sheet with sign out.

---

## How the numbers work

All of the maths lives in [`lib/app/budget_math.dart`](lib/app/budget_math.dart). It's pure
Dart and fully unit-tested.

```text
balance          = starting balance − everything spent so far
reserved         = sum of upcoming costs not yet due
available        = balance − reserved
daily allowance  = (available + spentToday) / daysLeftInTerm      (today counts)
safe to spend    = daily allowance − spentToday
burn rate        = total spent / days elapsed                      (today counts)
runway date      = today + available / burn rate
days short       = term end − runway date   (0 = covered)
```

Spending today moves money from *available* to *spentToday*, so your daily
allowance stays the same all day and safe-to-spend drops by exactly what you spent.

**Coach verdicts** ([`lib/app/coach.dart`](lib/app/coach.dart)):

```text
yes    if amount ≤ safe to spend today
trade  if amount ≤ 12% of available      → skip ⌈amount / $22⌉ delivery orders
no     otherwise                         → suggest saving for it as a goal
```

**Bill splits:** the total is split evenly between you and the roommates you pick,
rounded to the cent; any leftover cent goes to you.

---

## Design system

**Lime & Lilac**: warm charcoal, one electric lime for action, lilac for
personality, and glow only where it matters (main button, ring, nav pill).
Tokens live in [`lib/app/theme.dart`](lib/app/theme.dart).

| Token | Value | Use |
|---|---|---|
| Background | `#0D0D10` | App background |
| Surface | `#18181D` | Sheets, nav bar |
| Glass | white 5.5–9% + 10% hairline | Cards |
| Text / Muted | `#F4F4F1` / `#8E8E99` | Typography |
| **Lime** | `#C6FF3D` | Main accent: buttons, ring, active tab, good states (dark `#0D0D10` text on it) |
| **Lilac** | `#B9A4FF` | Second accent: Mochi, category icons, highlights |
| Butter | `#FFD66B` | Caution / "trade for it" |
| Red | `#FF6B6B` | Short / over budget |
| Sky | `#8FD3FF` | **Need** |
| Pink | `#FF9BD6` | **Want** |

**Type:** system font (SF Pro on Apple) for the UI, with tabular figures for money;
[Bricolage Grotesque](https://github.com/ateliertriay/bricolage) (OFL) for the
`runway` wordmark.

**Icons:** [Phosphor](https://phosphoricons.com) (MIT), bundled as fonts in
`assets/fonts/phosphor` and listed in `lib/widgets/ph_icons.dart`. Nav icons morph
from outline to filled when selected; categories use two-tone icons, which look
identical on every platform (unlike emoji).

**Motion tokens:** `fast 180ms` · `med 320ms` · `slow 650ms` · curves `easeOutCubic`,
`easeOutBack`, `easeOutExpo` (rolling numbers) · `pressSpring` (real spring physics).

**Smoothness rules:**
- Press feedback on every tappable: dips to ≈0.95 with a light haptic, then
  springs back with real physics (interruptible, so fast taps never stutter).
- **Log an expense** and a coin arcs from the Log button into the Home ring, which springs and glows.
- A lime **pill glides between nav tabs** while icons morph outline → filled.
- **Collapsing header:** the big greeting fades away as you scroll and a frosted
  mini bar slides in with your safe-to-spend.
- Staggered fade/slide entrances on each screen; numbers roll to new values.
- Tabs cross-fade and slide while keeping each tab's scroll position.
- The aurora background is painted with radial gradients rather than blur, so it's cheap to animate.
- Real frosted blur (`BackdropFilter`) is used only on the nav bar, sheets and the mini header.
- `RepaintBoundary` around every animated painter, and bouncing scroll physics everywhere.
- 120 fps on ProMotion iPhones (`CADisableMinimumFrameDurationOnPhone`).
- **Reduce Motion** is respected: the intro, entrances, rolling numbers, aurora,
  pet and coin all hold still or jump straight to the end.

---

## Architecture

```text
lib/
├── main.dart                 # startup, device preview, theme, scroll behaviour
├── app/                      # no UI here: logic, state, data
│   ├── theme.dart            # colours, gradients, text styles, motion tokens
│   ├── models.dart           # Expense, Term, UpcomingCost, BillSplit, Friend…
│   ├── budget_math.dart      # runway maths, streaks, pet level, splits (pure)
│   ├── coach.dart            # AffordabilityCoach interface + LocalCoach rules
│   ├── auth.dart             # AuthService interface + on-device stand-in
│   ├── repository.dart       # BudgetRepository interface + in-memory mock + demo seed
│   ├── database.dart         # drift tables (SQLite schema) + migrations
│   ├── database.g.dart       # generated by drift — don't edit
│   ├── drift_repository.dart # saves everything to runway.sqlite on the device
│   └── app_state.dart        # ChangeNotifier AppState + AppScope (InheritedNotifier)
├── widgets/                  # shared UI
│   ├── aurora_background.dart  glass.dart  pressable.dart  motion.dart
│   ├── gradient_button.dart    mochi.dart  expense_inputs.dart  transitions.dart
│   ├── mochi_takeoff.dart      # launch intro + LogoMark
│   ├── celebrations.dart       # coin → ring, ring pulse
│   ├── ph_icons.dart  category_icon.dart
└── screens/
    ├── launch_intro.dart     login_screen.dart   shell.dart (tabs + nav)   home_screen.dart
    ├── coach_screen.dart     squad_screen.dart         quick_add_sheet.dart
    ├── split_bill_sheet.dart account_sheet.dart
test/
├── budget_math_test.dart     # runway maths, streaks, splits, mock data
├── coach_test.dart           # verdicts, boundaries, amount parsing
├── drift_repository_test.dart # real SQLite file: save → close → reopen
└── app_test.dart             # app state + widget flows (login, quick add, coach, squad)
```

**Key decisions**
- **Minimal dependencies.** Plain Flutter, [`drift`](https://pub.dev/packages/drift) for the
  on-device database, and `device_preview` for development. No state-management package:
  a single `ChangeNotifier` passed down the widget tree with `InheritedNotifier`.
- **Saved on the device.** Every change updates the screen instantly, then saves to
  `runway.sqlite` in the background. Money is stored as whole cents, deletes and
  settle-ups are kept as history (soft delete), and a split bill is saved all-or-nothing.
- **Everything swappable sits behind an interface:**
  - `BudgetRepository`: SQLite via drift (in-memory mock for tests)
  - `AuthService`: on-device stand-in today, real accounts later
  - `AffordabilityCoach`: local rules today, Gemini later
- **Pure maths with an injectable clock**, so every number is testable without Flutter.

---

## Getting started

### Prerequisites
- Flutter **3.47+** (Dart **3.13+**)
- macOS with Xcode for macOS/iOS builds

> ⚠️ Keep the project **outside iCloud-synced folders** (Desktop / Documents).
> iCloud adds file attributes that break iOS code signing. `~/Developer/` works well.

### Run it

```sh
git clone <your-repo-url> runway
cd runway
flutter pub get
flutter run -d macos
```

In **debug builds on macOS**, the app runs inside an **iPhone 16 Pro Max frame**
via [`device_preview`](https://pub.dev/packages/device_preview), so you don't need an iOS Simulator or the Android SDK.
Mouse and trackpad dragging scroll just like a finger.

Log in with any valid-looking email and a password of 6+ characters (see
[limitations](#current-limitations)).

| Key | Action |
|---|---|
| `r` | Hot reload |
| `R` | Hot restart |
| `q` | Quit |

### Other platforms
```sh
flutter run -d ios        # needs Xcode + a simulator or device
flutter run -d android    # needs the Android SDK
```

---

## Testing

```sh
flutter analyze   # static analysis, currently clean
flutter test      # 63 tests
```

After changing a table in `lib/app/database.dart`, regenerate the drift code:

```sh
dart run build_runner build
```

| Suite | Covers |
|---|---|
| `budget_math_test.dart` | Every runway formula, days short, no-spend and overspend cases, last day of term, streaks, pet levels, weekly split, even splits, mock data calibration |
| `drift_repository_test.dart` | Real SQLite file, closed and reopened: demo data seeds once, expenses/splits/session/term survive relaunch, exact cents, dates stay on the right day, a failed split saves nothing |
| `coach_test.dart` | All three verdicts, the inclusive 12% boundary, minimum trade, goal suggestion, amount parsing (`$1,299.99`, phrasing, no amount) |
| `intro_test.dart` | Intro maths (Mochi lands on each letter, the y beat, logo hand-off is pixel-exact), first launch → login, tap to skip, signed-in → Home, Reduce Motion |
| `app_test.dart` | Logging updates state, splitting bills, booting, tab switching (no ghost tabs), coach chip → verdict, Quick Add with note + category, Split a bill sheet, login/sign-up/sign-out, small-screen (iPhone SE) layout |

---

## Current limitations

This is an early prototype:

- **Setup covers the basics only.** A first-run screen sets the term, starting
  balance and upcoming costs, but there's no settings screen to edit them later,
  no "reset", and no way to add money mid-term (see the next question below).
- **Login is a stand-in.** Any well-formed email and password is accepted; there's no server.
- **The coach is rule-based.** It uses no AI and no API keys, and makes no network calls.
- **Squad friends are mock data.** There's no real friend sync yet.

---

## Future plans

The full roadmap, with details for each item, is in **[ROADMAP.md](ROADMAP.md)**.

| # | Plan | Status |
|---|---|---|
| 1 | **Local database (drift / SQLite):** save expenses, splits, streaks and session | ✅ Done |
| 2 | **Onboarding & setup:** term dates, starting balance, upcoming costs, money lumps | 🔜 Next |
| 3 | **History by semester:** term recaps, undo delete, CSV export, encrypted backup | 📋 Planned |
| 4 | **Real accounts:** Continue with Google / Apple + email, biometric app lock | 📋 Planned |
| 5 | **Squad backend (Supabase):** real friends, challenges and IOUs; never amounts | 📋 Planned |
| 6 | **Gemini coach:** AI replies grounded in your real numbers, via a server proxy | 📋 Planned |
| 7 | **Polish:** notifications, home-screen widget, recurring costs, app icon | 💡 Ideas |

### ❓ Next question: money coming in during the term

Students don't only get one lump at the start. Many have a job paid **weekly or
every two weeks**, an **allowance** from parents, or one-off money like a
**project payment** or scholarship. How should Runway count it?

- **One-time money** (project payment, scholarship, gift): name, amount, date.
- **Recurring money** (paycheck, allowance): name, amount, how often
  (weekly / every 2 weeks / monthly), next pay date.

**The open decision: when does future income count?**

- **Option A: only once it arrives.** Safe, but strict: today's budget ignores
  money the student will definitely get, and jumps up on every payday.
- **Option B: count expected paychecks ahead of time** (the mirror of how big
  costs are reserved ahead of time). Today's budget reflects the real semester
  and stays steady.

Leaning towards **B**, with two safeguards: use the student's *lowest usual*
paycheck (shift work varies; they correct it when it lands), and warn about
gaps between paydays ("Tight until Friday's paycheck"), since the semester can
add up while a single week doesn't.

---

## Privacy

- No bank linking, ever.
- Expenses, balances and history stay **on your device**.
- Friends only ever see **streaks and challenge progress**, never amounts.
- When the AI coach arrives, it will receive only summary numbers (available,
  daily allowance, days left), never your expense list, and the API key will stay on a server.

---

<div align="center">

Made with Flutter by **Kriyansh Shah**

</div>
