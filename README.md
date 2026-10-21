<div align="center">

# 🛫 Runway

**Make your money last the whole semester.**

A budgeting app built for college students: it plans by **semester**, not by month,
and tells you how much you can safely spend **today**.


**[Website](https://kriyansh-shah.github.io/runway/) · [Try it in your browser](https://kriyansh-shah.github.io/runway/app/) · [Privacy](https://kriyansh-shah.github.io/runway/privacy.html)**

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
as it can be: two taps for most purchases. Your money data stays on your phone unless you turn on sync, which is end-to-end encrypted.

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
  are **reserved ahead of time** so they can't be spent by accident. Tap one to
  mark it paid (your daily budget doesn't move), edit it, or delete it. Overdue costs stay
  reserved until you do.
- **Monthly bills:** tick **Every month** when adding a cost (rent, phone,
  subscriptions). Every month of it due before the term ends is reserved, each
  paid on its own; a monthly budget reserves it again each new month. Skip
  just one month, or stop the bill. A new name or amount applies from the
  month you edit on; months already paid stay as they were.
- **Money in:** paychecks (weekly, every 2 weeks, monthly), allowance or a
  one-off payment like a scholarship. Each payment counts **on the day it
  arrives, never before**, and shows what's coming next. Repeating pay can be
  edited, stopped (past paydays still count) or deleted. A new amount never
  changes money already received: it starts at the next payday.
- **This week:** a need vs want split bar, plus your recent expenses. Tap an
  expense to **edit** it (amount, note, category, need/want) or **delete** it,
  with an **Undo** bar. **See all** lists every expense this term by day.
- **Personal greeting** with your 🔥 streak chip and account avatar.

### 🐷 Savings: saving built into the budget
- Setup asks **how much you want to save** this month or semester (10% or 20%
  suggested, $0 is fine). The goal comes **off the top on day one**, like a
  reserved cost, so your daily number already leaves room for it.
- Change it anytime and see the effect first ("$18.20 → $16.40 a day").
  Spending into it is allowed, but shown honestly ("You're dipping into your
  savings").
- **Savings tab:** a ring with a forecast ("On track for $150 by Dec 11", or
  "Spend $2.10/day less to keep it all"), a countdown, your total saved
  overall and a streak of goals hit.
- When a month or semester ends, only the planned goal counts as saved;
  leftover money carries into next month's spending. The recap asks
  "Save $150 again?"

### 🏷️ Custom categories
- Make your own category once (name + icon) and pick it in one tap from
  Quick Add next time. Hold one to rename or delete it.

### 🗓️ Semester or monthly
- Setup asks **how you want to budget**. A **semester** runs between dates you
  pick. A **monthly** budget runs to the end of this month, with no name or end
  date to fill in.
- When a month ends, the next one **starts by itself**: money left over carries
  into it, along with unpaid costs and pay that repeats. The old month's
  expenses stay with that month. If you spent more than you had, the gap is
  reserved as an "Overspent in October" cost on day one.

### ⚙️ Settings
- Tap your avatar. Edit the term's name, dates and starting money (with
  validation), add or manage big costs, start a new semester, or **erase
  everything on this phone** (the database file is rewritten so deleted data
  doesn't linger).

### 🕘 History
- **Settings → History** lists every finished month and semester, newest
  first: what you started with, money that came in, what you spent, what was
  left (or how much you went over), and your top three categories.
- Tap one to see its expenses by day, read-only.
- **Recap:** when a month or semester ends, Home shows "That's a wrap on
  October" once: Mochi, what was left (or how much you went over), spent,
  money in, needs vs wants, the biggest spend, and one comparison with the
  one before ("30% less on 📦 Delivery than in September 🎉"). Compared per
  day, and only moves of 10% or more in categories with $10+ before.

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
- **Real squads** (signed in): start one, then **Invite friends** shares a
  6-character code through the share sheet. Up to 8 people; codes expire
  after 7 days. Friends see your **first name, emoji, streak and challenge
  dots, never money**. Leave anytime; an empty squad is deleted.
- **No-delivery week challenge** with 7-day progress dots per friend.
- **Streak leaderboard:** streaks only, **never dollar amounts**.
- Without sign-in (macOS preview, tests) Squad shows sample friends.
- **Friends & split bills (Splitwise-style):** friends are your squadmates plus
  anyone you add with a friend code. **Split a bill** with any of them,
  optionally inside a squad: pick **who paid** (you or a friend) and split it
  **equally, by exact amounts, percentages or shares**. It shows up in their
  app too, and **your part counts as spending** in your budget either way.
- **One balance per friend** ("Priya owes you $18"), netted across every split;
  tap a friend to **settle up** (full or partial) or see your history.
- **Simplify debts** per squad: the squad's IOUs are redrawn as the fewest
  payments ("Ann → Cat $10").
- **Several squads** with a switcher (roommates, a trip, a study group).
- Someone not on Runway? Add them by name; that IOU stays on your phone, with
  an animated *Settle up*.

### 🎬 Launch intro: "Mochi's Takeoff"
A ~4-second intro on launch, in the spirit of Pixar's lamp:
1. A lime runway draws itself and landing lights blink on.
2. Mochi hops in with squash & stretch; each letter of **r·u·n·w·a·y** pops up to catch it.
3. Mochi flattens the **y**, looks at you, blinks, and hops it back up.
4. The lights race, Mochi zooms off, and the word glides up into the logo.
5. Mochi lands on the logo's **y**, and the welcome card rises underneath.

Tap anywhere to skip. Signed-in users go straight from the intro into Home
through a circle that opens from Mochi. With **Reduce Motion** on, it's skipped.
It's drawn in code (one `CustomPainter`, no video), with haptic ticks on the
lights and landings.

### 🔐 Welcome & privacy
- **Encrypted on your phone.** On iPhone and Android, `runway.sqlite` is
  encrypted with a random 256-bit key kept in the Keychain / Keystore
  (SQLite3MultipleCiphers). Data from before encryption is encrypted in place
  on the first launch of this version.
- **No account needed.** The first screen asks only for your first name (it
  shakes if you leave it empty), or **Continue with Google**. The button
  morphs to ✓, then Home is revealed through a **circle that grows out of
  the button**.
- **App lock:** optional Face ID / Touch ID / passcode (fingerprint or PIN on
  Android). Offered during setup, changeable in Settings (both ways need Face ID
  first). Asks on launch and after a minute away; a phone with no passcode is
  never locked out.
- **App-switcher cover:** the app hides behind the Runway logo whenever it
  leaves the screen, so balances don't show in the app switcher.

### ☁️ Accounts, sync & the website
- **Continue with Google** (optional) via Supabase Auth: native account
  picker on iPhone and Android, a redirect on the web. Settings → Account has
  **Sign out** and **Delete account** (deletes everything on the server).
- **Budget sync, end-to-end encrypted** (optional): pick a sync passphrase
  and the whole budget is encrypted on the device (PBKDF2-HMAC-SHA256,
  600k rounds → AES-256-GCM) before upload. The server only stores
  ciphertext, so nobody else can read it, including us. Sign in on another
  device, type the passphrase once, and the same budget is there; a fresh
  device offers it before setup. Changes upload a few seconds later and the
  most recent change wins. Forgot it? Start over with a new passphrase.
- **Website** at [kriyansh-shah.github.io/runway](https://kriyansh-shah.github.io/runway/):
  landing page, privacy policy, support page and the **web app** at `/app/`,
  rebuilt and deployed by GitHub Actions on every push to `main`.

---

## How the numbers work

All of the maths lives in [`lib/app/budget_math.dart`](lib/app/budget_math.dart). It's pure
Dart and fully unit-tested.

```text
received         = every payday from term start to today (never future pay)
balance          = starting balance + received − everything spent so far
reserved         = sum of upcoming costs not yet paid (overdue ones too)
available        = balance − reserved
daily allowance  = (available + spentToday) / daysLeftInTerm      (today counts)
safe to spend    = daily allowance − spentToday
burn rate        = everyday spent / days elapsed                   (today counts)
runway date      = today + available / burn rate
days short       = term end − runway date   (0 = covered)
```

Spending today moves money from *available* to *spentToday*, so your daily
allowance stays the same all day and safe-to-spend drops by exactly what you spent.

Marking an upcoming cost **paid** logs a *planned* expense: it leaves the balance
and the reservation at the same time, so *available* doesn't change, and it's
left out of *spentToday* and the burn rate (it was budgeted for, not everyday
spending).

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
│   ├── auth.dart             # UserProfile, AccountService interface, name validation
│   ├── supabase_accounts.dart # Google sign-in via Supabase (phones + web)
│   ├── squad.dart            # Squad models + SquadService interface
│   ├── supabase_squad.dart   # squads, friends, splits and settle-ups on Supabase
│   ├── split_math.dart       # uneven splits, balances, simplify debts, settle up (pure)
│   ├── budget_sync.dart      # end-to-end encrypted budget sync (cipher + controller)
│   ├── supabase_budget_backups.dart # encrypted copy on Supabase + key in Keychain
│   ├── device_auth.dart      # Face ID / passcode behind DeviceAuth (local_auth)
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
    ├── launch_intro.dart     welcome_screen.dart  lock_gate.dart  shell.dart (tabs + nav)
    ├── home_screen.dart      setup_screen.dart    settings_screen.dart  all_expenses_screen.dart
    ├── coach_screen.dart     squad_screen.dart    quick_add_sheet.dart  add_income_sheet.dart
    ├── split_bill_sheet.dart money_actions.dart  savings_screen.dart  savings_goal_sheet.dart
    ├── history_screen.dart   recap_sheet.dart     category_sheet.dart  sync_sheets.dart
    ├── friends_sheets.dart   # add friend, a friend's balance / settle up / history
supabase/
├── migrations/               # Squad + budget_backups tables, row-level security on all
└── functions/delete-account/ # Edge Function behind "Delete account"
site/                         # landing page; scripts/build_site.sh builds the website
test/
├── budget_math_test.dart     # runway maths, streaks, splits, mock data
├── coach_test.dart           # verdicts, boundaries, amount parsing
├── drift_repository_test.dart # real SQLite file: save → close → reopen, snapshots
├── budget_sync_test.dart     # encryption, two devices, conflicts, offline, start over
├── split_math_test.dart      # equal/exact/%/shares, balances, simplify debts, settle up
└── app_test.dart             # app state + widget flows (welcome, app lock, quick add, settings…)
```

**Key decisions**
- **Few dependencies.** Plain Flutter, [`drift`](https://pub.dev/packages/drift) for the
  on-device database, `supabase_flutter` + `google_sign_in` for accounts and Squad,
  `cryptography` for sync encryption, and `device_preview` for development. No
  state-management package: a single `ChangeNotifier` passed down the widget tree with
  `InheritedNotifier`.
- **Backend: Supabase**, with row-level security on every table. It holds
  accounts, squads and the encrypted budget copy; never readable money data.
- **Saved on the device.** Every change updates the screen instantly, then saves to
  `runway.sqlite` in the background. Money is stored as whole cents, deletes and
  settle-ups are kept as history (soft delete), and a split bill is saved all-or-nothing.
- **Everything swappable sits behind an interface:**
  - `BudgetRepository`: SQLite via drift (in-memory mock for tests)
  - `AccountService`, `SquadService`, `BudgetBackupStore`: Supabase (fakes in tests,
    sample friends where sign-in isn't set up)
  - `DeviceAuth`: Face ID / passcode via `local_auth` (faked in tests)
  - `AffordabilityCoach`: local rules today, Gemini later
- **Pure maths with an injectable clock**, so every number is testable without Flutter.
- **Instant screens, honest saves:** changes show immediately and save in the
  background. If a save fails, the app waits for any other saves to finish,
  reloads everything from the database, and tells you the change was undone,
  so the screen never shows data that isn't stored.

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

Type any first name to start. Google sign-in, Squad and sync aren't set up
in the macOS preview (it shows sample friends); use a phone or the web app
for those.

| Key | Action |
|---|---|
| `r` | Hot reload |
| `R` | Hot restart |
| `q` | Quit |

### Other platforms
```sh
flutter run -d ios        # needs Xcode + a simulator or device
flutter run -d android    # needs the Android SDK
flutter run -d chrome     # the web app
```

### Website
```sh
BASE_HREF=/app/ scripts/build_site.sh && python3 -m http.server -d _site
```
Pushing to `main` builds and deploys it to GitHub Pages (`.github/workflows/website.yml`).

---

## Testing

```sh
flutter analyze   # static analysis, currently clean
flutter test      # 191 tests
```

After changing a table in `lib/app/database.dart`, regenerate the drift code:

```sh
dart run build_runner build
```

| Suite | Covers |
|---|---|
| `budget_math_test.dart` | Every runway formula, days short, no-spend and overspend cases, last day of term, streaks, pet levels, weekly split, even splits, mock data calibration, starting the next month (leftover, skipped months, stopped pay, overspending), history summaries, recap comparisons (per day, 10% and $10 floors) |
| `budget_sync_test.dart` | The server only gets ciphertext, wrong passphrase refused, a copy can't be opened under another account, changes flow both ways between two devices, most recent change wins, offline changes upload later, start over, deleting the copy stops sync everywhere |
| `drift_repository_test.dart` | Real SQLite file, closed and reopened: whole-budget snapshots move to another database (device-only settings stay put, newer snapshots refused), demo data seeds once, expenses/splits/session/term survive relaunch, exact cents, dates stay on the right day, a failed split saves nothing, schema upgrades, a new month carrying costs and pay over, monthly bills (reserve, pay, skip, stop, longer term, new month, new semester), history (never the demo, newest first, deleted expenses left out), editing costs, bills from a month on, and pay (a raise keeps past paydays), recaps (once per ended month, never for the demo or for terms from before recaps) |
| `device_database_test.dart` | Encryption with the real SQLite3MultipleCiphers build: an old plain file is encrypted in place, app data is unreadable on disk without the key, a file the key can't open is moved aside (never deleted), the key is made once |
| `coach_test.dart` | All three verdicts, the inclusive 12% boundary, minimum trade, goal suggestion, amount parsing (`$1,299.99`, phrasing, no amount) |
| `intro_test.dart` | Intro maths (Mochi lands on each letter, the y beat, logo hand-off is pixel-exact), first launch → welcome, tap to skip, signed-in → Home, Reduce Motion |
| `app_test.dart` | Logging updates state, splitting bills, booting, tab switching (no ghost tabs), coach chip → verdict, Quick Add with note + category, Split a bill sheet, welcome (name only), app lock (launch, time away, switcher cover, no-passcode fallback, Settings and setup toggles), small-screen (iPhone SE) layout, History (cards, read-only past month, empty state), editing a cost and pay from Home, the recap sheet, savings goal and forecast, Google sign-in (welcome, settings, sign out, delete account), real Squad (sign in, start, join by code, leave, errors), budget sync (turn on, unlock on a fresh device, start fresh) |

---

## Current limitations

This is an early prototype:

- **Money coming in belongs to one term.** Starting a new semester starts
  with no paychecks; add them again in the new term.
- **Google is the only sign-in.** Sign in with Apple (required by the App
  Store alongside Google) and email codes are still to do.
- **Sync is a whole-budget snapshot.** The most recent change wins, so edits
  made on two devices at the same time don't merge. A forgotten sync
  passphrase can't be recovered (the budget on each device is unaffected).
- **On-device encryption is phones only.** The macOS build (for development)
  and the web app store the database unencrypted (the synced copy is always
  encrypted). An encrypted Android backup restored without its Keystore key
  can't be read: Runway keeps the file aside and starts fresh.
- **Monthly budgets follow the calendar month** (1st to last day). A cycle that
  starts on payday (say the 25th) isn't supported yet.
- **Starting a new semester stops monthly bills.** Add them again during setup.
- **The coach is rule-based.** It uses no AI and no API keys, and makes no network calls.
- **Joins by code only.** Invite links, QR codes, remove/block/report and
  push notifications ("Priya settled up") are still to do. Splits can't be
  edited yet (delete and add again), and everything is in dollars.

---

## Future plans

The full roadmap, with details for each item, is in **[ROADMAP.md](ROADMAP.md)**.

| # | Plan | Status |
|---|---|---|
| 1 | **Local database (drift / SQLite):** save expenses, splits, streaks and session | ✅ Done |
| 2 | **Onboarding & setup:** term dates, starting balance, upcoming costs, money coming in, settings | ✅ Done |
| 3 | **History by semester:** past terms and months ✅, undo delete ✅, recap ✅, encrypted sync ✅ | ✅ Mostly done |
| 4 | **Real accounts:** Google ✅, account deletion ✅, encrypted budget sync ✅; Sign in with Apple + email codes next | 🚧 In progress |
| 5 | **Squad backend (Supabase):** squads + invite codes ✅, friends + synced splits + settle up + simplify debts ✅; invite links, QR codes, block/report | 🚧 In progress |
| 6 | **Gemini coach:** AI replies grounded in your real numbers, via a server proxy | 📋 Planned |
| 7 | **Polish:** notifications, home-screen widget, ~~recurring costs~~ ✅, app icon | 💡 Ideas |

### ✅ Decided: money coming in during the term

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

**Decided: A for now** (October 9, 2026): money counts only once it arrives, so
Runway never lets you spend money you don't have yet. The question is in
`~/Developer/Professor Questions.docx` (outside the repo) to revisit. If we
switch to B later, use two safeguards: use the student's *lowest usual* paycheck
(shift work varies; they correct it when it lands), and warn about gaps between
paydays ("Tight until Friday's paycheck"), since the semester can add up while a
single week doesn't.

---

## Privacy

The full policy is in [docs/privacy.md](docs/privacy.md); the App Store checklist is in [docs/app-store.md](docs/app-store.md).

- No bank linking, ever. No ads, no analytics, no tracking.
- Expenses, balances and history stay **on your device**, encrypted on phones,
  unless you turn on sync, and the synced copy is **end-to-end encrypted**
  with a passphrase only you know.
- Signing in is optional; the server stores your name, email and account ID.
- Friends see your **first name, emoji, streak and challenge progress**. A bill
  you split is seen only by the people in it (with its amounts); nobody sees
  your budget.
- When the AI coach arrives, it will receive only summary numbers (available,
  daily allowance, days left), never your expense list, and the API key will stay on a server.

---

<div align="center">

Made with Flutter by **Kriyansh Shah**

</div>
