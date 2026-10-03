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
- [x] 63 tests (maths, coach, intro, motion, widget flows, small-screen layout, save → reopen)

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

## 2. 🔜 Onboarding & setup

**Why:** Term dates, starting balance and upcoming costs are currently hard-coded demo data.

**What:**
- First-run flow: term name and dates, then starting balance, then upcoming big costs.
- **Money lumps:** add a loan, scholarship, parent transfer or paycheck mid-term,
  and the runway updates.
- Edit and delete upcoming costs; mark them as paid, which turns them into an expense.
- Settings screen: edit the term, reset demo data, sign out.

**Done when:** a brand-new user can set up their own semester without any demo data.

---

## 3. 📋 History by semester

**Why:** The best insight is comparing semesters ("I spent 30% less on delivery
than last fall"). Expense data is tiny, so we keep everything.

**What:**
- **Term recap** when a term ends: total spent, need vs want, top categories,
  best streak, and whether the money lasted.
- Past terms become read-only and browsable.
- **Undo** toast after deleting an expense (soft delete, permanently removed after 30 days).
- Search and filter expenses by category, note and date.
- **Export CSV** for any term.
- Optional **encrypted backup** to iCloud Drive / Google Drive.

**Retention policy:** keep all history on the device indefinitely; the user
can delete a term or everything at any time.

---

## 4. 📋 Real accounts & security

**Why:** Today's login accepts any valid-looking email. Real accounts only matter once
there's sync or Squad, so this ships together with #5.

**What:**
- **"Continue with Google"** and **"Continue with Apple"** buttons on the existing
  login screen (keeping the circular reveal). Google opens its own secure sign-in
  sheet / account picker and returns to the app with a signed token.
- Apple's App Store rules require Sign in with Apple whenever Google login is offered
  on iOS, so the two ship together. Email login stays as a third option.
- Setup: Google Cloud OAuth client IDs (iOS, Android, macOS), URL scheme in
  `Info.plist`, Android signing SHA-1, `google_sign_in` + Apple sign-in packages.
- Tokens are verified by Supabase Auth (see #5), so no custom auth server.
- Optional **Face ID / Touch ID / passcode lock** for the app, which works even with no account.
- Swap `LocalAuthService` for a real `AuthService` implementation (no UI changes).

---

## 5. 📋 Squad backend (Supabase)

**Why:** Friends, challenges and shared bills need a server. Personal money data does not.

**What:**
- [Supabase](https://supabase.com) for auth plus a Postgres database with row-level security.
- Invite friends and roommates by link or code.
- Sync **only**: streaks, challenge dots, bill split IOUs and settle-ups.
- **Never sync** balances, expenses or runway numbers.
- Push notification when a roommate settles up or a friend breaks a challenge.

**Done when:** two phones see the same challenge and IOUs in real time.

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
- [ ] Recurring costs (phone bill, subscriptions) that auto-reserve
- [ ] Savings goals from "Not this term" coach verdicts
- [ ] Custom categories and custom quick picks
- [ ] Uneven bill splits and "they paid, I owe"
- [ ] Multi-currency for international students
- [ ] App icon + native launch screen in Lime & Lilac, App Store screenshots
- [ ] Accessibility pass: reduce motion, larger text, screen reader labels
- [ ] Light theme (maybe)
- [ ] Set up iOS signing + Android SDK for real-device testing

---

*Have an idea? Add it to the backlog above with a 💡.*
