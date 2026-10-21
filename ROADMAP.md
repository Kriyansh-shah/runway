# 🗺️ Runway Roadmap

Next plans for Runway, in the order we intend to build them. Each item says
**why** it matters, **what** it includes, and how we'll know it's **done**.

**Status key:** ✅ Done · 🔜 Next · 📋 Planned · 💡 Idea

---

## ✅ Shipped

- [x] Semester runway maths: daily allowance, safe-to-spend, burn rate, runway date, days short
- [x] Home: hero ring, runway timeline, coming up, need vs want, recent expenses
- [x] Quick Add: keypad + haptics, presets, note field, 13 categories, need/want toggle
- [x] Coach "Can I afford it?": local rules, verdict cards, typing indicator
- [x] Squad: Mochi pet, no-delivery challenge, streak leaderboard, roommate splits
- [x] Split a bill: even split, IOUs for roommates, only your share counts as spending
- [x] Login UI with circular reveal transition (on-device stand-in auth)
- [x] First design system (dark neon), motion tokens, smooth tab switching
- [x] Local database (drift / SQLite): everything survives closing the app — see #1
- [x] Lime & Lilac palette, Phosphor icons, two-tone category icons
- [x] "Mochi's Takeoff" launch intro (tap to skip, Reduce Motion aware)
- [x] Motion upgrades: coin into the ring, sliding nav pill, collapsing header,
      spring physics on presses, 120 fps, Reduce Motion support
- [x] Money coming in (paychecks, allowance, one-off payments), counted on the day it arrives
- [x] Settings: edit term, manage big costs, new semester, erase everything, sign out
- [x] Edit and delete expenses, with Undo; "See all" expenses by day
- [x] Failed saves are undone and reported instead of failing silently
- [x] Name-only welcome (no fake password login), Face ID / passcode app lock, app-switcher cover
- [x] Encrypted on-device database (SQLite3MultipleCiphers, key in Keychain / Keystore)
- [x] Semester or monthly budgets; monthly bills; history, recaps
- [x] Custom categories; savings goal + Savings tab with forecast and countdown
- [x] App icon, dark launch screen, privacy policy, App Store checklist
- [x] Continue with Google (Supabase Auth) on phones and the web; sign out, delete account
- [x] Real Squad: start a squad, invite codes, up to 8 people, never money
- [x] End-to-end encrypted budget sync across signed-in devices
- [x] Website + web app on GitHub Pages, deployed on every push
- [x] Friends + several squads, synced split bills (equal / exact / % / shares,
      who paid), one balance per friend, settle up, simplify debts
- [x] 191 tests (maths, coach, intro, motion, widget flows, save → reopen, migrations, encryption, sync between two devices)

---

## 1. ✅ Local database (drift / SQLite)

**Shipped.** Everything is saved in `runway.sqlite` on the device.

**Why:** Before this, everything lived in memory, so closing the app wiped your
expenses, splits, streak and login.

**What:**
- Add [`drift`](https://pub.dev/packages/drift), a typed SQLite library for Flutter with
  reactive queries and built-in schema migrations.
- Implement `DriftBudgetRepository` behind the existing `BudgetRepository`
  interface, so no screen code changes.
- Seed demo data **only on first launch**, then use real entries.
- Remember the signed-in user so the app opens straight to Home.

**Schema (version 1):**

| Table | Columns |
|---|---|
| `terms` | id, name, start, end, starting_balance, archived_at |
| `expenses` | id, term_id, amount_cents, category, is_need, note, created_at, deleted_at |
| `upcoming_costs` | id, term_id, emoji, name, amount_cents, due_date, paid_at |
| `bill_splits` | id, person, amount_cents, note, they_owe_you, created_at, settled_at |
| `friends` | id, position, name, emoji, streak, no_delivery_days |
| `sessions` | id, name, email, signed_in_at |
| `meta` | key, value (seeded_at, challenge_start) |

*`income_lumps` (loan / scholarship / parents / job) moves to #2 with the setup flow.*

Notes:
- Store money as **integer cents** to avoid floating-point rounding errors.
- Use `deleted_at` / `settled_at` (soft delete) so undo and history work.

**Done when:** you log expenses, split a bill, close the app, reopen it, and
everything is still there, with tests that simulate closing and reopening.

---

## 2. ✅ Onboarding & setup

**Shipped.** First-run setup, money coming in (Option A: counts on the day it
arrives), mark-paid / delete for upcoming costs, and a Settings screen (edit
term, new semester, erase everything, sign out). Database schema version 2
adds the `incomes` table and `expenses.is_planned`.

**Semester or monthly** (schema version 3 adds `terms.period`): setup offers
both, and a monthly budget starts the next month by itself, carrying over the
leftover money, unpaid costs and repeating pay.

✅ Costs, monthly bills and money coming in can be edited in place (a new
pay amount starts at the next payday; money already received never changes).

Still open: custom dates (asked in Professor Questions, #2); payday-based monthly cycles.

**Why:** Term dates, starting balance and upcoming costs are currently hard-coded demo data.

**What:**
- First-run flow: term name and dates, then starting balance, then upcoming big costs.
- **Money lumps:** add a loan, scholarship, parent transfer or paycheck mid-term,
  and the runway updates.
- Edit and delete upcoming costs; mark them as paid, which turns them into an expense.
- Settings screen: edit the term, reset demo data, sign out.

**Done when:** a brand-new user can set up their own semester without any demo data.

---

## 3. ✅ History by semester

**Why:** The best insight is comparing semesters ("I spent 30% less on delivery
than last fall"). Expense data is tiny, so we keep everything.

**What:**
- ✅ ~~**History screen**~~ (shipped, Settings → History): every finished
  month and semester with what you started with, money in, spent, left or
  over, and top categories; tap one for its expenses, read-only.
- ✅ ~~**Recap moment** when a term ends~~ (shipped): shown once on Home, with
  needs vs wants, the biggest spend and one comparison with the term before.
- ✅ ~~**Undo** toast after deleting an expense~~ (shipped). Still to do: permanently
  remove soft-deleted expenses after 30 days.
- Search and filter expenses by category, note and date.
- ✅ ~~Optional **encrypted backup**~~: shipped as end-to-end encrypted budget
  sync (#4), which doubles as a backup.

**Retention policy:** keep all history on the device indefinitely; the user
can delete a term or everything at any time.

---

## 4. 🚧 Real accounts & security

**Shipped (2026-10-19/20):** Continue with Google through Supabase Auth on
iPhone, Android and the web; Settings → Account with sign out and in-app
**account deletion** (`delete-account` Edge Function); end-to-end encrypted
**budget sync** (below). The name-only option stays. **Next:** Sign in with
Apple (needed for the App Store) and maybe email codes.

**Why:** Real accounts only matter once there's sync or Squad, so this ships
together with #5.

**What:**
- **"Continue with Google"** and **"Continue with Apple"** buttons on the
  welcome screen (keeping the circular reveal). Google opens its own secure sign-in
  sheet / account picker and returns to the app with a signed token.
- If Google login is offered, the App Store requires a privacy-focused option
  too, and Sign in with Apple qualifies, so the two ship together. Email codes
  (no passwords) are the third option.
- In-app **account deletion** (App Store requirement) and a privacy policy.
- Setup: Google Cloud OAuth client IDs (iOS, Android, macOS), URL scheme in
  `Info.plist`, Android signing SHA-1, `google_sign_in` + Apple sign-in packages.
- Tokens are verified by Supabase Auth (see #5), so no custom auth server.
- ✅ ~~Optional **Face ID / Touch ID / passcode lock**~~ (shipped, with an
  app-switcher cover).
- ✅ ~~Encrypt `runway.sqlite`, key in Keychain / Keystore~~ (shipped with
  SQLite3MultipleCiphers, which can encrypt an existing file in place).
- ✅ ~~Add a real `AuthService` (Supabase) next to the name-only profile~~
  (`AccountService` / `SupabaseAccounts`).

### Budget sync (✅ shipped 2026-10-20)

Opt-in, **end-to-end encrypted**: the person picks a sync passphrase; the
device turns it into a key (PBKDF2-HMAC-SHA256, 600k rounds) and seals the
whole budget (AES-256-GCM, account ID as associated data) before upload.
Supabase stores only ciphertext in `budget_backups` (one row per account,
owner-only row-level security, deleted with the account).

- Whole-budget snapshot, not a row-by-row merge: uploads a few seconds after
  a change, checks on launch, resume and sign-in; when two devices both
  changed, the most recent change wins (server-set timestamps, version as an
  optimistic lock).
- A fresh signed-in device offers "Welcome back" before setup; a device
  with its own budget asks before replacing it.
- Forgotten passphrase: nobody can open the copy; "start over" deletes it and
  syncs this device's budget under a new passphrase.
- Not synced: the name on each device and the app lock.
- Later, maybe: a real merge so edits on two devices at once both survive.

### Security plan

**Phase 1: protect the data on the phone (✅ shipped)**
- Replaced the stand-in email/password login (it accepted anything and
  protected nothing) with a **name-only welcome screen**. No passwords are
  asked for or stored.
- Optional **Face ID / Touch ID / passcode app lock**: offered in setup, toggled
  in Settings (both ways need Face ID), asks on launch and after 1 minute away,
  falls back to the passcode, never locks out a phone with no passcode.
- **App-switcher cover** so balances don't show in the app switcher.
- **Encrypted database** (✅ shipped): `runway.sqlite` is encrypted with a
  random 256-bit key in the Keychain / Keystore. Existing data is encrypted in
  place on first launch. On iOS the key moves with encrypted backups, so a new
  iPhone keeps the data.
- Still to decide: Android backups (the Keystore key doesn't move with them;
  either exclude the file from backups or accept a fresh start on restore).

**Phase 2: real accounts (with the Squad backend, #5)**

*Owner to-do (needs your accounts, payments or decisions):*
- [ ] Apple Developer Program ($99/yr): needed for Sign in with Apple and the App Store.
- [x] Supabase project (free tier): share the project URL + anon key. Never share
      the service role key.
- [x] Google Cloud project: OAuth consent screen (name + email only), iOS client
      ID and web client ID.
- [ ] Google Play Console ($25 once), only if shipping Android; app signing SHA-1.
- [ ] Turn on "Sign in with Apple" for `com.kriyanshshah.runway`; enable Apple,
      Google and Email providers in Supabase.
- [ ] Email sending service (Resend / Postmark free tier), ideally with your own domain.
- [x] Privacy policy at a public URL: https://kriyansh-shah.github.io/runway/privacy.html
- [ ] App Store privacy label and Play Data safety form (draft in
      `docs/app-store.md`; decide whether E2E-encrypted sync counts as
      Financial Info).
- [x] Google sign-in published to production (2026-10-20), so anyone can sign in.
- [x] Decide what syncs (2026-10-20): Squad, plus the budget as an opt-in,
      end-to-end encrypted copy (sync passphrase; the server can't read it).
- [ ] Decide: sign-in options (recommended: Apple + Google + email codes, no
      passwords), and what happens to the money data when a different person
      signs in on the same phone.

*Build (once the keys exist):*
- [x] `supabase_flutter` behind a real `AccountService`; sessions in Keychain / Keystore.
- [ ] Apple, Google and email-code buttons on the welcome screen (Google ✅ 2026-10-19; Apple and email codes to do).
- [x] Squad tables with row-level security on every table (2026-10-19: invite codes, up to 8 per squad; links/QR, remove/block/report and synced IOUs still to do).
- [x] In-app account deletion (needs a small Edge Function).
- [x] End-to-end encrypted budget sync, with tests for two devices.
- [ ] URL scheme / universal link so email links open the app; tests.

---

## 5. 🚧 Squad backend (Supabase)

**Shipped (2026-10-19):** squads of up to 8 with 6-character invite codes
(7-day expiry, rate-limited guesses), shared through the share sheet; friends
see first name, emoji, streak and no-delivery dots; leave a squad (empty
squads are deleted). Requires Google sign-in rather than anonymous accounts.
**Shipped (2026-10-21):** Splitwise-style friends (squadmates + friend codes),
several squads with a switcher, synced split bills between friends (who
paid; equal, exact, percentages or shares; optionally inside a squad), one
balance per friend, settle up (full or partial), and "simplify debts" per
squad. Only the people in a split can read it; your part is added to your
budget on every phone in it.
**Next:** invite links + QR codes (need a domain), remove / block / report
(Apple expects these), push notifications, editing a split, currencies.

**Why:** Friends, challenges and shared bills need a server. Personal money data does not.

### How friends connect: invites, not search

No username search and no friend requests. You connect by handing someone a
private invite, and accepting it *is* the consent, so nobody waits for approval.

- **Invite link (main way):** "Invite friends" makes a link like
  `runway.app/join/K7M2QX` to share in iMessage, WhatsApp, Instagram or a group
  chat. It opens the app straight to "Alex invited you to their squad. Join?",
  or the App Store first if Runway isn't installed (then shows the invite).
- **QR code (in person):** the same invite as a QR code; the normal iPhone
  camera opens it, no in-app scanner needed.
- **Short code (backup):** e.g. `MOCHI-7K2`, to read out or type.
- **Invite safety:** expires after 7 days, can be revoked, limited uses, rate
  limited, so a link posted publicly can't flood a squad.
- **Why no search:** anyone could find and pester you; wrong default for a
  student money app. Can be added later if people ask.

### Squads, not one big friends list

- A **squad** is a small group (up to ~8): roommates, a friend group, a study
  group. You can be in a few.
- Challenges ("no delivery this week") and leaderboards are per squad; an
  invite link is for one squad.

### What friends see

- **Can see:** first name, Mochi, streak, challenge progress.
- **Never see:** balances, expenses, safe-to-spend or any amounts.
- **Controls:** remove someone, leave a squad, block and report (Apple expects
  block/report when users can interact).

### Bill splits

- Roommates **don't need the app**: IOUs keep working on your phone as today.
- If a roommate is in your squad, the IOU syncs to them and "Settle up" notifies
  you. Only the IOU between you two is shared, never your budget.

### Under the hood

- [Supabase](https://supabase.com): Postgres with **row-level security on every
  table** (you can only read squads you're in).
- ~~Anonymous accounts first~~: decided against for now; Squad needs Google
  sign-in (simpler, and the account survives a new phone).
- Squad shares **only** squad membership, names, emoji, streaks and challenge
  dots (IOUs and settle-ups later). Balances and expenses only travel inside
  the end-to-end encrypted budget sync (#4), never readable.
- Universal links (iOS) / app links (Android) on the domain, so invite links
  open the app; deferred deep link so the invite survives an App Store install.
- Push notification when a roommate settles up, someone joins your squad, or a
  friend breaks a challenge.

### Open decision

- [ ] **Domain** for invite links (e.g. runway.app, ~$10–15/yr). Also sends
      email (#4). The website and privacy policy already live on GitHub Pages
      (kriyansh-shah.github.io/runway).

**Done when:** two phones join the same squad from a link or QR code, see the
same challenge and IOUs in real time, and neither can see the other's money.

---

## 6. 📋 Gemini coach

**Why:** Natural-language advice ("Should I get the concert ticket or save for
spring break?") on top of the existing rules.

**What:**
- Model: `gemini-2.5-flash` via REST.
- **The API key never ships in the app.** A key built into the app with `--dart-define`
  can be pulled out by anyone. Instead, call a small proxy (Cloudflare Worker /
  Supabase Edge Function) that holds the key.
- Send only `CoachGrounding.toJson()`: available, safe-to-spend, daily allowance,
  days left, burn rate, days short. Never the expense list.
- Keep `LocalCoach` as the fallback when offline or on error; the verdict card
  still comes from the rules, so numbers are never made up.
- Rate limiting and cost cap on the proxy.

---

## 7. 💡 Polish & ideas backlog

- [ ] Daily reminder notification to log expenses (keeps the streak alive)
- [ ] Home-screen widget showing "Safe to spend today"
- [x] Recurring costs (phone bill, subscriptions) that auto-reserve
- [ ] Savings goals from "Not this term" coach verdicts (a semester savings goal ✅ shipped)
- [x] Custom categories (custom quick picks still to do)
- [x] Uneven bill splits and "they paid, I owe"
- [ ] Multi-currency for international students
- [x] App icon + native launch screen in Lime & Lilac (App Store screenshots still to do)
- [ ] Accessibility pass: reduce motion, larger text, screen reader labels
- [ ] Light theme (maybe)
- [x] Set up iOS signing + Android SDK for real-device testing
- [ ] Supabase Pro ($25/mo) before launch: backups, no pausing, higher limits

---

*Have an idea? Add it to the backlog above with a 💡.*
