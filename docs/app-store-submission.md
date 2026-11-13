# Submitting Runway 1.0 to the App Store

A step-by-step guide for putting **Runway 1.0** on the App Store, written to
be followed in order. Everything you have to type into Apple's websites is
here, ready to copy.

**What 1.0 is:** the budgeting app with Home, Savings, Quick Add, Coach,
Siri, reminders, the app lock, optional Sign in with Apple or Google with
encrypted budget sync, and **Friends**: add friends with a code, split bills,
settle up, block and report. **Squads are not in 1.0** (shared squads, the
streak leaderboard, the no-delivery challenge). They're behind a switch and
come in a later update; see [next-update-squad.md](next-update-squad.md).

The code is on the git branch **`release-1.0`**, which has everything
from `app-store-1.0` plus Friends and the Android work. It isn't on `main`
yet, so the live website hasn't changed.

> This file replaces the old `docs/app-store.md` checklist; everything that
> was in it is here, updated for 1.0.

---

## Contents

1. [Join the Apple Developer Program](#1-join-the-apple-developer-program)
2. [Turn on Sign in with Apple](#2-turn-on-sign-in-with-apple)
3. [Set up Apple sign-in on the server (Supabase)](#3-set-up-apple-sign-in-on-the-server-supabase)
4. [Publish the 1.0 privacy policy and support page](#4-publish-the-10-privacy-policy-and-support-page)
5. [Create the app in App Store Connect](#5-create-the-app-in-app-store-connect)
6. [App Store text (copy and paste)](#6-app-store-text-copy-and-paste)
7. [Age rating](#7-age-rating)
8. [App Privacy (the "nutrition label")](#8-app-privacy-the-nutrition-label)
9. [Export compliance (the encryption question)](#9-export-compliance-the-encryption-question)
10. [Screenshots](#10-screenshots)
11. [Build and upload](#11-build-and-upload)
12. [Test with TestFlight](#12-test-with-testflight)
13. [Notes for App Review, and submitting](#13-notes-for-app-review-and-submitting)
14. [Why apps get rejected, and how Runway avoids it](#14-why-apps-get-rejected-and-how-runway-avoids-it)
15. [What's already done in the code](#15-whats-already-done-in-the-code)
16. [Judgement calls to confirm](#16-judgement-calls-to-confirm)
17. [Pre-submission checklist](#17-pre-submission-checklist)

---

## 1. Join the Apple Developer Program

You can't upload to the App Store or use Sign in with Apple without it.

1. Go to <https://developer.apple.com/programs/enroll/> and sign in with the
   Apple ID you want to own the app. It needs two-factor authentication on.
2. Enroll as an **Individual**. Your legal name is shown on the App Store as
   the seller. (An organization needs a D-U-N-S number and takes longer.)
3. Pay **$99 a year**. Approval usually takes from a few hours to two days;
   you'll get an email.
4. When it's approved, open <https://developer.apple.com/account> →
   **Membership details** and write down your **Team ID** (10 characters,
   like `AB12CD34EF`). You need it in steps 2 and 3.

---

## 2. Turn on Sign in with Apple

The app already has the code and a ready-made settings file
(`ios/Runner/Runner.entitlements`). It isn't switched on yet, because the
free Apple account can't sign it and turning it on would break installing on
your phone. Once you've joined:

1. Check out the launch branch: `git checkout app-store-1.0`.
2. Open `ios/Runner.xcodeproj` in Xcode.
3. **Xcode → Settings → Accounts:** add your Apple ID if it isn't there, and
   check the paid team appears (it's named after you, with "(Individual)",
   not "Personal Team").
4. In the left sidebar click **Runner** (the blue project icon), then the
   **Runner** target, then **Signing & Capabilities**:
   - **Team:** choose the paid team (not "Personal Team").
   - **Bundle Identifier:** `com.kriyanshshah.runway` (leave it).
   - Keep **Automatically manage signing** ticked. Xcode registers the App ID
     with Apple for you.
5. Click **+ Capability** (top left of that tab) → **Sign in with Apple**.
   Xcode uses the existing `Runner/Runner.entitlements` file. Check that
   **Build Settings → Code Signing Entitlements** now says
   `Runner/Runner.entitlements` for Debug, Release and Profile.
6. Close Xcode. In Terminal, check the change: `git diff ios/` should show
   `DEVELOPMENT_TEAM` changed to your new Team ID and
   `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` added. Commit it.

Until this step is done, tapping **Continue with Apple** shows "Sign in with
Apple isn't available on this device right now…" instead of crashing.

---

## 3. Set up Apple sign-in on the server (Supabase)

Runway's accounts run on Supabase (project `slvwntpzgjpqzmojzdus`).

### 3a. Let Supabase accept Apple sign-ins

1. Open <https://supabase.com/dashboard/project/slvwntpzgjpqzmojzdus> →
   **Authentication → Sign In / Providers → Apple**.
2. Turn **Enable Sign in with Apple** on.
3. **Client IDs:** `com.kriyanshshah.runway` (the app's bundle ID). That's
   all the iPhone app needs.
4. Leave **Secret Key (for OAuth)** empty. It's only for signing in with Apple
   on a website, which Runway doesn't do.
5. Save.

### 3b. Revoking Apple access when someone deletes their account

Apple requires that when someone deletes an account they made with Sign in
with Apple, the app also revokes its access to their Apple ID. The code does
this (the `delete-account` server function), but it needs a key from Apple:

1. <https://developer.apple.com/account/resources/authkeys/list> → **+**.
2. Name it "Runway Sign in with Apple", tick **Sign in with Apple** →
   **Configure** → Primary App ID **com.kriyanshshah.runway** → Save →
   Continue → Register.
3. **Download** the `.p8` file. Apple lets you download it **only once**;
   keep it somewhere safe (not in the git repo). Write down the **Key ID**.
4. Install the Supabase command-line tool if you don't have it:
   `brew install supabase/tap/supabase`, then `supabase login`.
5. From the `runway` folder, store the four secrets (replace the values):

   ```sh
   supabase secrets set --project-ref slvwntpzgjpqzmojzdus \
     APPLE_TEAM_ID=AB12CD34EF \
     APPLE_KEY_ID=XYZ123ABCD \
     APPLE_CLIENT_ID=com.kriyanshshah.runway \
     APPLE_PRIVATE_KEY="$(cat ~/Downloads/AuthKey_XYZ123ABCD.p8)"
   ```

6. Deploy the updated function (it checks the sign-in itself, so JWT
   verification stays off, as before):

   ```sh
   supabase functions deploy delete-account \
     --project-ref slvwntpzgjpqzmojzdus --no-verify-jwt
   ```

If the secrets are missing or Apple can't be reached, the account is still
deleted; the revoke failure is only logged (Supabase dashboard → Edge
Functions → delete-account → Logs). Check the logs once after testing.

### 3c. Keep Supabase awake (free plan)

The free plan **pauses a project after about a week with no activity**, and
then sign-in and sync stop working until it's restored. Runway stays on the
free plan for now, so a scheduled GitHub Action,
`.github/workflows/supabase-keepalive.yml`, makes one tiny database request
every Monday and Thursday. It reads nothing (row-level security returns an
empty list); it only counts as activity.

- **It's live:** the workflow was pushed to `main` on November 12, 2026 and
  its first run passed. (GitHub only runs schedules from the default branch.)
- To check it: GitHub → the repo → **Actions → Keep Supabase awake → Run
  workflow**. A green tick means Supabase answered.
- If a run fails, GitHub emails you. Open the
  [Supabase dashboard](https://supabase.com/dashboard/project/slvwntpzgjpqzmojzdus)
  and click **Restore** if the project is paused.
- GitHub turns schedules off in a repository with no commits for 60 days. It
  emails a warning first; one click turns it back on.
- **During App Review**, still glance at the dashboard every couple of days.
  A paused project would make Sign in with Apple fail for the reviewer.

**Supabase Pro ($25/month)** is optional, but Friends puts real people's
splits on the server in 1.0, so it's worth it soon after launch: it never
pauses and adds daily backups.

---

## 4. Publish the 1.0 privacy policy and support page

The App Store links to the privacy policy and support pages on your website,
and the website is built from the **`main`** branch. On `release-1.0`,
`docs/privacy.md` and `docs/support.md` are updated for 1.0 (Sign in with
Apple, reminders, Friends and split bills, squads marked as "web app only,
for now"). They must be live
**before you submit**, because the reviewer reads them.

The simplest way is to merge the branch once you've tested it:

```sh
git checkout main
git merge release-1.0
git push
```

That's safe for the website: the web app is built with Squad switched on
(`scripts/build_site.sh` passes `--dart-define=SQUAD=true`), and the Apple
button only appears in the iPhone and iPad app. After the push, check
<https://kriyansh-shah.github.io/runway/privacy.html> shows "Last updated:
November 12, 2026".

**Contact email:** the policy and support page point to GitHub issues. Apple
accepts that, but an email address is friendlier for people who aren't on
GitHub. If you add one, add it to both pages.

---

## 5. Create the app in App Store Connect

<https://appstoreconnect.apple.com> → **Apps → + → New App**:

| Field | What to enter |
| --- | --- |
| Platforms | **iOS** |
| Name | **Runway** (30 characters max). If it's taken, use **Runway: Student Budget** |
| Primary language | English (U.S.) |
| Bundle ID | **com.kriyanshshah.runway** (it appears after step 2) |
| SKU | `runway-ios` (anything; never shown) |
| User access | Full access |

Then, on the app's pages:

- **App Information:**
  - Category: **Finance** (primary), **Productivity** (secondary, optional)
  - Content rights: "No, it does not contain, show, or access third-party
    content"
- **Pricing and Availability:**
  - Price: **Free (USD 0)**
  - Availability: see [judgement call 4](#16-judgement-calls-to-confirm). The
    suggestion is the **United States** to start, because amounts are shown
    in dollars and the app is in English.
- **App Privacy:**
  - Privacy Policy URL: <https://kriyansh-shah.github.io/runway/privacy.html>
  - The questions are in [section 8](#8-app-privacy-the-nutrition-label).

---

## 6. App Store text (copy and paste)

On the version page ("1.0 Prepare for Submission").

**Subtitle** (30 max; this is 29):

```
Know what you can spend today
```

**Promotional text** (170 max; can be changed any time without review):

```
One number every morning: what's safe to spend today, so your money lasts until the end of the semester. No bank linking. Your money stays on your phone.
```

**Description** (4,000 max):

```
Student money comes all at once: a loan, a scholarship, help from family, savings from a summer job. It has to last the whole semester, and it rarely does. Runway turns it into one number: what's safe to spend today.

HOW IT WORKS
• Tell Runway how much you have and when your semester (or month) ends.
• It sets aside your big costs, monthly bills and savings goal first.
• It spreads the rest over the days left and shows what's safe to spend today.
• Spend less today and tomorrow's number goes up. Spend more and it adjusts, so you always know where you stand.

LOG IN SECONDS
• Quick Add: two taps for most purchases.
• Say it: tap the mic, or tell Siri "Log an expense in Runway".
• A calendar of every day, so you can fix or delete anything later.

PLAN AHEAD
• Big costs and monthly bills are reserved before they're due.
• Money coming in (paychecks, scholarships) counts only on the day it arrives.
• A savings goal that's set aside on day one, plus "Saving for" jars for bigger things.
• See when your money runs out at your current pace, and how many days short you'd be.

ASK BEFORE YOU BUY
Ask the Coach "Can I afford concert tickets for $60?" and get a straight answer: yes, yes if you trade for it, or not this semester, with a plan to save for it. On iPhones with Apple Intelligence, answers are written on your device.

PRIVATE BY DESIGN
• No bank linking. You log what you spend.
• Your budget is stored encrypted on your phone.
• Optional Face ID lock.
• Optional Sign in with Apple or Google, to sync your budget to your other devices. It's end-to-end encrypted with a passphrase only you know, so nobody else can read it, not even us.
• No ads, no tracking, no analytics.

SPLIT BILLS WITH FRIENDS
• Add friends with a code and split a bill: equally, by exact amounts, percentages or shares.
• Your part counts as spending in your budget automatically; friends see what they owe in their app.
• Settle up with a tap. Friends only ever see your first name and the bills you split, never your budget.

GENTLE REMINDERS
Optional reminders the day before a bill is due, an evening check-in if you haven't logged anything, and a weekly recap.

Made by a student, for students.
```

**Keywords** (100 max, commas, no spaces; this is 99):

```
budget,student,college,semester,money,spending,daily,allowance,expense,tracker,savings,siri,planner
```

**Support URL:** `https://kriyansh-shah.github.io/runway/support.html`

**Marketing URL** (optional): `https://kriyansh-shah.github.io/runway/`. That
page also describes the web app's Squad; see
[judgement call 5](#16-judgement-calls-to-confirm).

**Copyright:** `2026 Kriyansh Shah`

**Version:** `1.0` (it must match the build; `pubspec.yaml` says `1.0.0+1`).

---

## 7. Age rating

App Information → **Age Rating → Edit**. Answer **None / No** to everything:
no violence, sexual content, profanity, horror, drugs, alcohol or tobacco,
gambling, contests, medical information or mature themes; no unrestricted web
access (the privacy policy opens Runway's own page); no chat or messaging;
no advertising; no parental controls or age checks.

**User-generated content: Yes.** With Friends, the description of a split
bill ("Groceries") is shown to the friends in that split. It's only seen by
people who added each other with a code, and there's remove, block and
report on every friend. If Apple's questionnaire raises the rating because
of this, accept it: Runway is for college students. See
[judgement call 8](#16-judgement-calls-to-confirm).

Coach only answers questions about your own budget.

---

## 8. App Privacy (the "nutrition label")

App Store Connect → **App Privacy → Get Started**. These answers match the
code, `ios/Runner/PrivacyInfo.xcprivacy` and the privacy policy.

**Do you or your third-party partners collect data from this app?** → **Yes**
(only from people who choose to sign in).

Select exactly these five data types:

| Category → Data type | Linked to the user? | Used for tracking? | Purposes |
| --- | --- | --- | --- |
| Contact Info → **Name** | Yes | No | App Functionality |
| Contact Info → **Email Address** | Yes | No | App Functionality |
| Identifiers → **User ID** | Yes | No | App Functionality |
| Financial Info → **Other Financial Info** | Yes | No | App Functionality |
| User Content → **Other User Content** | Yes | No | App Functionality |

The last two are Friends: bills split with friends (what it was, the total,
who paid, each person's part) and settle-ups are stored on the server so
both friends see them.

Everything else: **not collected**. In particular:

- **The budget itself** (expenses, balances, bills) isn't collected. It stays
  on the phone; with Budget sync on, it's encrypted on the phone with the
  person's passphrase before upload, so Runway can't read it.
- **Audio Data:** not collected. Voice logging uses Apple's speech
  recognition; Runway only gets the text, on the phone, and never stores
  audio. (Data handled by Apple's own services isn't the developer's to
  declare.)
- **Usage Data, Diagnostics, Location, Contacts:** not collected. No
  analytics or crash reporting is built in. (Squads' streak sharing would be
  Usage Data; squads aren't in 1.0, and Friends doesn't share streaks.)

---

## 9. Export compliance (the encryption question)

Runway uses encryption only to protect the person's own data: HTTPS to the
server, the encrypted database on the phone (SQLite3MultipleCiphers), and the
end-to-end encrypted budget backup (standard AES-256-GCM). Encryption isn't
what the app is *for*; it's a budgeting app.

Under US export rules, that kind of use is exempt, so the code already
declares **`ITSAppUsesNonExemptEncryption` = NO** in `ios/Runner/Info.plist`.
App Store Connect then won't ask the encryption question for each build.

This is a legal declaration you're making as the publisher
([judgement call 3](#16-judgement-calls-to-confirm)). Read Apple's page
[Complying with encryption export regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations).
If you decide differently, change that line before you upload, and answer
Apple's questions when they appear.

---

## 10. Screenshots

Because Runway runs on iPad too, you need both sets. Upload them on the
version page under **Previews and Screenshots**.

| Device | Size (portrait) | How many |
| --- | --- | --- |
| iPhone 6.9" | **1320 × 2868** (1290 × 2796 also accepted) | 3 to 10 |
| iPad 13" | **2064 × 2752** (2048 × 2732 also accepted) | 3 to 10 |

**Easiest way:** run the app in the Simulator and press **⌘S** to save a
screenshot to your Desktop.

1. Open a 6.9" iPhone Simulator (for example iPhone 16 Pro Max) and a 13"
   iPad Simulator (for example iPad Pro 13-inch).
2. Give it a clean status bar:
   `xcrun simctl status_bar booted override --time 9:41 --batteryLevel 100 --batteryState charged --cellularBars 4 --wifiBars 3`
3. Run Runway (`flutter run -d <simulator>`), set up a realistic semester, and
   log a week of believable spending first.

**Screens to capture, in order:**

1. **Home:** the ring with "Safe to spend today".
2. **Quick Add:** a purchase about to be logged.
3. **Coach:** a "Can I afford…?" answer with its verdict.
4. **Runway card:** "Money lasts until…" and the timeline.
5. **Savings:** a goal and a "Saving for" jar.
6. **Calendar:** a month with daily amounts.
7. **Friends:** a couple of friends with balances, or the Split a bill sheet.
8. Optional: **Settings** showing Face ID lock and Budget sync (privacy).

Don't show squads, the leaderboard or the no-delivery challenge anywhere.
Screenshots must match 1.0. You may add short captions on top (like "Know what you can spend
today"), but don't show iPhone frames with fake content.

---

## 11. Build and upload

Do this after steps 2 to 4.

1. Make sure the **build number** is new. It's the number after `+` in
   `pubspec.yaml` (`version: 1.0.0+1`). Every upload needs a higher one:
   `1.0.0+2`, `1.0.0+3`…
2. In Terminal, from the `runway` folder on the `release-1.0` branch:

   ```sh
   flutter clean
   flutter build ipa --release
   ```

   Squads stay off (only on with `--dart-define=SQUAD=true`); Friends is on.
   The upload file ends up in `build/ios/ipa/`.
3. Upload it with Apple's free **Transporter** app (Mac App Store): sign in,
   drag the `.ipa` in, click **Deliver**.
   *Or* in Xcode: **Product → Archive**, then in the Organizer window
   **Distribute App → App Store Connect → Upload**.
4. After 10 to 30 minutes the build appears in App Store Connect under
   **TestFlight** (you'll get an email when it's processed).

---

## 12. Test with TestFlight

Test the exact build Apple will review, on a real iPhone, before submitting.

1. App Store Connect → **TestFlight → Internal Testing → +**, make a group,
   add yourself. Internal testing doesn't need Apple's review.
2. Install the **TestFlight** app on your iPhone and accept the invite.
3. Check, on that build:
   - [ ] Fresh install → welcome → **Continue with Apple** works (try "Hide My
         Email" too) and greets you by name.
   - [ ] **Continue with Google** works.
   - [ ] Settings → Account → **Delete account** with an Apple account: Apple
         asks you to confirm, the account is deleted, and the Supabase logs
         show no revoke error.
   - [ ] Budget sync on two devices (or delete and reinstall).
   - [ ] The fourth tab says **Friends**; nothing about squads, streak
         leaderboards or the no-delivery challenge.
   - [ ] With a second account (a friend's phone, or Google on a second
         device): add each other with a code, split a bill both ways, check
         each phone shows the right amount, settle up, delete a split.
   - [ ] Block and report a friend; unblock in Settings → Account → Blocked
         people.
   - [ ] Delete account on the second phone: the friend and their splits
         disappear from the first phone after a refresh.
   - [ ] Siri: "Log an expense in Runway" → "8 bucks on coffee" → open the
         app, it's there.
   - [ ] Mic in Quick Add; Face ID lock; reminders.
   - [ ] Settings → **Privacy policy** and **Help & support** open.
   - [ ] Airplane mode: the app opens and works; signing in fails politely.
   - [ ] On an iPad, in portrait and landscape.

TestFlight builds expire after 90 days, which is fine.

---

## 13. Notes for App Review, and submitting

On the version page, **App Review Information**:

- **Sign-in required:** **untick** it. Runway works without an account.
  Friends needs one, and Runway only has Apple and Google sign-in, so you
  can't hand Apple a username and password. Instead, **attach a short screen
  recording** (App Review Information → Attachment) of two phones adding
  each other and splitting a bill. Apple accepts a video when a feature
  needs a second person.
- **Contact information:** your first name, last name, phone number and
  email. Apple only uses them if they have a question.
- **Notes** (copy and paste):

```
Runway needs no account. On the first screen, type any first name and tap Get started, then set up a budget: pick any end date and enter an amount (for example $3,000). Home then shows what's safe to spend today.

Things to try:
• Tap + to log an expense (Quick Add). The mic lets you say it, e.g. "12 dollars at Chipotle".
• Siri: say "Log an expense in Runway", then e.g. "8 bucks on coffee". It's added the next time Runway opens. This needs the iPhone unlocked.
• Coach tab: ask "Can I afford headphones for $80?". The yes/no answer comes from the app's own rules, so it works on every device; on devices with Apple Intelligence the wording is written on-device by Apple's model.
• Sign in with Apple or Google is optional (Settings → Account). It's only used to sync the budget, end-to-end encrypted with a passphrase the person chooses. Delete account is in the same place; for Apple accounts it revokes the app's Apple ID access.
• The Face ID app lock and reminders are optional (Settings).
• Friends tab (needs sign-in): Add friend shows your friend code to share; Split a bill splits a cost with friends, and each friend sees what they owe in their own app. To try it alone, use Split a bill → Someone else to add a person by name (that IOU stays on the device). The attached video shows two accounts splitting a bill. Every friend has Remove, Block and Report; blocked people are listed in Settings → Account.

No ads, no tracking, no in-app purchases. Privacy policy and support are linked in Settings → About.
```

**Version release:** choose **Manually release this version**, so you decide
when it goes live after approval.

Then: under **Build**, pick the build you tested → **Add for Review** →
**Submit to App Review**. Reviews usually take one to two days. If Apple has
a question or rejects something, you'll get a message in App Store Connect's
**Resolution Center**; you can reply and resubmit.

---

## 14. Why apps get rejected, and how Runway avoids it

| Guideline | What Apple checks | Runway 1.0 |
| --- | --- | --- |
| 4.8 Login services | Apps with Google sign-in must also offer Sign in with Apple (or similar) | Apple button above Google on the welcome screen and in Settings. **Step 2 must be done**, or the button won't work for the reviewer |
| 5.1.1(v) Account deletion | People can delete their account in the app | Settings → Account → Delete account; it revokes Apple access (step 3b) |
| 5.1.1(i) Privacy policy | Linked in App Store Connect and easy to find in the app | Settings → About → Privacy policy |
| 2.1 App completeness | No crashes, broken buttons or placeholder content; everything shown works | Squads are fully hidden; Friends is shown in the attached video. Supabase must be awake (step 3c, the keep-awake job) or sign-in and Friends fail |
| 1.2 User-generated content | Apps where people share content need a way to block and report, and act on reports | Every friend has Remove, Block and Report; blocked people in Settings. Reports land in the `reports` table: check it now and then |
| 2.3 Accurate metadata | Screenshots and text match the app | Text above describes Friends, not squads; take screenshots without squads |
| 5.1.2 Data use | The privacy label and policy match what the app does | Section 8 matches the code and the policy |
| 2.5.1 / 5.1.1 Permissions | Each permission is explained and asked for when needed | Microphone and speech only when you tap the mic; Face ID only when you turn on the lock; notifications only when you turn on reminders |
| 4 Design (iPad) | iPad apps must work well on iPad and in landscape | Tested on 13" iPad, portrait and landscape |
| 3.1.1 Payments | Digital goods use in-app purchase | Runway has nothing to buy |
| Privacy manifest | Apps must declare required-reason APIs | `ios/Runner/PrivacyInfo.xcprivacy` is in the app |

---

## 15. What's already done in the code

On the `app-store-1.0` branch:

- **Squads hidden** behind `Features.squad` (`lib/app/features.dart`): the
  fourth tab is **Friends** (friends and balances, Split a bill, settle up,
  remove, block, report), with no squad switcher, invite codes, leaderboard,
  challenge or squad wording. Debts stay between the two people who split,
  and friends get only your first name and emoji (no streak). Mochi's card
  moves to the bottom of Home. Squads come back with `--dart-define=SQUAD=true`.
- **Sign in with Apple** (`sign_in_with_apple` + Supabase ID-token sign-in,
  with a hashed nonce), above Google on the welcome screen, in Settings, and
  on the Friends tab's sign-in prompt. It takes the name Apple shares the
  first time and saves it to the account. Cancelling does nothing; errors are
  shown in plain words.
- **Apple-aware account deletion:** the app gets a fresh code from Apple, and
  `supabase/functions/delete-account` swaps it for a token and revokes it.
- **Privacy manifest** (`ios/Runner/PrivacyInfo.xcprivacy`) in the app target,
  declaring the Friends data and the encrypted database's file-timestamp and
  disk-space checks (without those two, the upload is rejected with
  ITMS-91053).
- **Export compliance** key in `Info.plist`.
- **Privacy policy and Help & support** links in Settings → About.
- **Permission messages:** microphone, speech recognition and Face ID each
  say exactly why.
- **App icon** 1024×1024 with no transparency; dark launch screen (no white
  flash).
- **Version** 1.0.0 (1); minimum iOS 15. Apple Intelligence (iOS 26) and Siri
  shortcuts (iOS 17) switch themselves off on older iOS, and the app works
  without them.
- **Works offline and without an account:** sign-in gives up after 8 seconds
  and the app opens name-only.
- **Debug-only tools** (the device frame on the Mac) are off in release.
- **Tests:** the whole suite passes, including a launch suite
  (`test/launch_without_squad_test.dart`) that checks the fourth tab is
  Friends with no squads anywhere, Sign in with Apple, and iPad portrait and
  landscape layouts, plus "Friends tab" tests in `test/app_test.dart`.

---

## 16. Judgement calls to confirm

1. **Squads in the policy.** The website's web app still has squads, and the
   website and app share one privacy policy. So the policy keeps the Squad
   sections, headed "web app only, for now". If you'd rather take Squad out
   of the web app too, remove `--dart-define=SQUAD=true` from
   `scripts/build_site.sh` and those sections from `docs/privacy.md` and
   `docs/support.md`.
2. **Financial Info in the privacy label:** ticked, because split bills are
   stored readable on the server so friends can see them (section 8).
3. **Export compliance:** declared exempt (section 9). It's your legal
   declaration as the publisher.
4. **Countries:** suggested US only at first, because money is shown in
   dollars and the app is in English. You can add countries later without a
   new build.
5. **Marketing URL:** the landing page describes Squad as part of the web
   app. That's fine as a website, but if you want zero risk of a reviewer
   asking "where's Squad?", leave the Marketing URL blank in App Store Connect
   or update the landing page to say Squad is web-only for now.
6. **Voice dictation** uses Apple's speech recognition, which may process
   audio on Apple's servers on some devices. The policy says so. Forcing
   on-device-only would break the mic on phones that can't do it.
7. **Siri and the coach** use the name "Apple Intelligence" in a small tag on
   AI-written answers. That's a factual description, which Apple allows;
   don't use it in the app name, icon or subtitle.
8. **Age rating with Friends:** answered "user-generated content: yes"
   (section 7), which may lift the rating above 4+. Fine for college
   students; answering "no" would be inaccurate.

---

## 17. Pre-submission checklist

Accounts and setup

- [ ] Joined the Apple Developer Program; Team ID written down
- [ ] Two-factor login turned on for Supabase, GitHub, Google (Cloud and Play Console) and the Apple developer account
- [ ] Xcode: paid team selected, **Sign in with Apple** capability added, change committed
- [ ] Supabase: Apple provider enabled with client ID `com.kriyanshshah.runway`
- [ ] Apple key created; four `APPLE_*` secrets set; `delete-account` deployed
- [x] Supabase keep-awake job on `main`, first run passed (November 12, 2026)
- [ ] The project isn't paused (Pro recommended soon after launch)
- [ ] `release-1.0` merged into `main` and pushed; privacy page shows November 12, 2026

App Store Connect

- [ ] App created (name, bundle ID, SKU)
- [ ] Category Finance; price Free; countries chosen
- [ ] Subtitle, promotional text, description, keywords, support URL, copyright
- [ ] Age rating answered (4+)
- [ ] App Privacy answered as in section 8; privacy policy URL set
- [ ] iPhone 6.9" and iPad 13" screenshots, Friends allowed, no squads
- [ ] App Review notes and contact details; "Sign-in required" unticked; Friends video attached
- [ ] Manual release selected

Build

- [ ] Build number raised; `flutter build ipa --release`; uploaded
- [ ] TestFlight checks in section 12 all pass on a real iPhone (and an iPad if you have one)
- [ ] Build selected on the version page → **Submit to App Review**

After approval

- [ ] Release it from App Store Connect
- [ ] Check Supabase logs and the support page now and then
- [ ] Start the Squad update: [next-update-squad.md](next-update-squad.md)
