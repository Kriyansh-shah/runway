# Next update: bringing Squad back

Squads are fully built but held back from the first App Store release
(1.0). **Friends ships in 1.0** (friends, Split a bill, settle up, block and
report, as the Friends tab); what's held back is the squad part: shared
squads with invite codes, the streak leaderboard and the no-delivery
challenge. This is everything needed to ship it in the
next update.

---

## 1. Turn it on

Squad is behind one switch, `Features.squad` in `lib/app/features.dart`. It's
off unless the app is built with `--dart-define=SQUAD=true`.

- **Try it on your phone or the Simulator:**
  `flutter run --dart-define=SQUAD=true`
- **For the App Store update**, either build with
  `flutter build ipa --release --dart-define=SQUAD=true`,
  or, once Squad is staying for good, change the default in
  `lib/app/features.dart` to `true` (or delete the switch and its `if`s).
- **The website's web app** already has Squad: `scripts/build_site.sh` builds
  it with `--dart-define=SQUAD=true`.
- **Tests** run with Squad on (`test/flutter_test_config.dart`). The launch
  suite `test/launch_without_squad_test.dart` checks the build with Squad
  off; delete or flip it when Squad ships.

What `Features.squad = false` changes (Friends stays on, `Features.friends`):

| Where | What |
| --- | --- |
| `lib/screens/shell.dart` | Tab 3 is labelled **Friends** instead of Squad |
| `lib/screens/squad_screen.dart` | No pet card, squad switcher, squad header, start/join, challenge, leaderboard or "To settle" card; the title is Friends |
| `lib/screens/home_screen.dart` | Mochi's pet card shows at the bottom of Home instead |
| `lib/app/app_state.dart` | Squad debts aren't simplified (each debt stays between the two people), and no streak or challenge days are published to your profile |
| `lib/screens/split_bill_sheet.dart` | No "In a squad?" picker |
| `lib/screens/friends_sheets.dart`, `safety_sheets.dart` | No squad names or squad wording |
| `lib/screens/settings_screen.dart` | "For splitting bills with friends…" wording |

To ship squads: build with `--dart-define=SQUAD=true` (or flip the
default). `--dart-define=FRIENDS=false` hides the Friends tab as well.

--- | --- |
| `lib/screens/shell.dart` | The Squad tab (tab 3) and its nav button |
| `lib/main.dart` | `SupabaseSquad` and loading squads at launch |
| `lib/app/app_state.dart` | Loading squads after signing in |
| `lib/screens/settings_screen.dart` | Settings → Account → Blocked people, and the "For Squad and…" wording |

Split a bill, friends, block and report are only reachable from the Squad
tab, so hiding the tab hides them too.

---

## 2. What Squad includes

- **Squads:** start one or join with an invite code; several squads with a
  switcher; the owner can remove people (who can't rejoin with the old code).
- **Streaks and challenges:** a streak leaderboard (days in a row logged) and
  the no-delivery week. Squad members see first names, a squad emoji, streaks
  and challenge days, **never** money.
- **Mochi's pet card:** Mochi's mood and level, from your logging streak.
- **Friends:** add with a friend code; people in your squads are friends too.
- **Split bills** (Splitwise-style): equal, exact amounts, percentages or
  shares; who paid; synced IOUs; settle up; anyone in a split can delete
  it. Every squad settles in the fewest payments automatically (no switch
  since 2026-11-12; the server's `simplify_debts` column is ignored). Someone not on Runway can be
  added by name, and that IOU stays on the phone.
- **Safety:** remove, block and report; blocked people in Settings.

## 3. Files involved

| Part | Files |
| --- | --- |
| Models and maths | `lib/app/squad.dart`, `lib/app/split_math.dart` |
| Server (Supabase) | `lib/app/supabase_squad.dart` |
| State | the squad/friends/splits sections of `lib/app/app_state.dart` |
| Screens | `lib/screens/squad_screen.dart`, `split_bill_sheet.dart`, `friends_sheets.dart`, `safety_sheets.dart` |
| Tests | `test/split_math_test.dart`, `test/supabase_squad_test.dart`, the "squad" and "real squad" groups in `test/app_test.dart` |

## 4. The server side is already live

These migrations are applied to the live Supabase project
(`slvwntpzgjpqzmojzdus`), with row-level security on every table:

| Migration | What it adds |
| --- | --- |
| `20261019000000_squad.sql` | `profiles`, `squads`, `squad_members`, `squad_invites`, `join_attempts`, and the create/invite/join functions |
| `20261019000100_squad_private_helpers.sql` | Helper functions in a private schema |
| `20261020000000_budget_backups.sql` | `budget_backups` (budget sync; used by 1.0 too) |
| `20261021000000_friends_and_splits.sql` | `friendships`, `friend_invites`, `shared_expenses`, `expense_shares`, `settlements` |
| `20261022000000_split_safety.sql` | Split safety checks |
| `20261028000000_remove_block_report.sql` | `squad_removals`, `blocks`, `reports` |

Nothing needs migrating to turn Squad on. Before shipping, run Supabase's
**Advisors** (security and performance) once more.

## 5. Privacy policy and App Store privacy label

**Privacy policy:** `docs/privacy.md` already describes Squad, under "Squad
(web app only, for now)". When Squad ships on iPhone:

- Rename that heading to "Squad", and remove the sentence saying the iPhone
  app doesn't have it yet, plus "(web app)" in the blocking paragraph and
  "from the web app" under Deleting your data.
- Do the same in `docs/support.md` (the "(web app)" Squad questions and the
  "Squad is in the web app for now" line).
- Update "Last updated", and publish (merge to `main`) **before** submitting.

**App Store privacy label:** add these to the three 1.0 data types (Name,
Email Address, User ID):

| Category → Data type | Linked | Tracking | Purpose | Why |
| --- | --- | --- | --- | --- |
| Usage Data → Product Interaction | Yes | No | App Functionality | Streaks and no-delivery days shared with squads |
| User Content → Other User Content | Yes | No | App Functionality | Squad names, what a split was for, reports someone sends |
| Financial Info → Other Financial Info | Yes | No | App Functionality | Split bills are stored readable for the people in them: amounts, who paid, settle-ups |

**Privacy manifest:** add the same three types to
`ios/Runner/PrivacyInfo.xcprivacy`
(`NSPrivacyCollectedDataTypeProductInteraction`,
`NSPrivacyCollectedDataTypeOtherUserContent`,
`NSPrivacyCollectedDataTypeOtherFinancialInfo`; linked, not tracking, App
Functionality).

**Age rating:** Squad adds user-generated content (squad names, people's
names) and people interacting. Answer the questionnaire's user-generated
content questions **Yes**; the rating may go up.

## 6. Guideline 1.2 (apps where people interact)

Apple requires, for apps with user-generated content or people interacting:

- [x] A way to **report** offensive content or people: report a person from
      the leaderboard or a friend's sheet; report a squad's name from its ⋯
      menu.
- [x] A way to **block** people: block from the same places; blocked people
      in Settings → Account → Blocked people.
- [x] A way to **remove** someone: the squad owner can remove people.
- [ ] **Act on reports within 24 hours.** Reports land in the `reports` table
      (Supabase dashboard only; there's no email alert). Check it daily, or
      add an email alert before launch.
- [ ] Contact information in the app (Help & support is in Settings → About).
- [ ] ⚠️ **Remove, block and report have never been tried on real phones.**
      Test them with two real accounts on two devices before submitting.

## 7. Notes for App Review (Squad update)

Squad needs two signed-in people, so give the reviewer **two demo
accounts**. Sign in with Apple can't be shared, so make two **Google**
accounts just for review (for example runway.review1@gmail.com and
runway.review2@gmail.com), sign each into Runway once, start a squad with
one, join it with the other, and add a split. Put both email addresses and
passwords in App Review Information, and explain:

```
Squad needs two people, so we've set up two demo Google accounts (below). They're already in a squad together called "Review" with a shared split.

To try it: Settings → Account → Continue with Google, sign in with demo account 1, and open the Squad tab. Squad members only see first names, an emoji, logging streaks and challenge days, never budgets. Split a bill: Squad → Split a bill.

Safety: tap a person on the streak leaderboard to remove (owner only), block or report them; report a squad's name from the squad's ⋯ menu; blocked people are in Settings → Account → Blocked people. Reports are reviewed within 24 hours.
```

Then tick **Sign-in required** for that version and enter demo account 1.

## 8. Open Squad ideas (not built yet)

- **Invite links and QR codes** (instead of typing codes). Needs a domain or
  universal links.
- **Push notifications** (a friend split a bill, someone settled up). Needs
  the paid developer account (now joined) and APNs set up in Supabase or a
  push service.
- **Editing a split** after it's made (today you delete and redo it).
- **Currencies** other than dollars for splits.

## 9. Ship checklist

- [ ] Squad tried with `--dart-define=SQUAD=true` on two real phones,
      including remove, block and report
- [ ] Squad's sign-in prompt shows **Continue with Apple** above Google
      (already in the code)
- [ ] Privacy policy, support page, privacy label and manifest updated (section 5)
- [ ] Age rating re-answered
- [ ] Reports checked daily, or an alert added
- [ ] Two demo accounts set up, and the review notes added
- [ ] New screenshots that include Squad
- [ ] Build with Squad on, raise the build number, upload, TestFlight, submit
