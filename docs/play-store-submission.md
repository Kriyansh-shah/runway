# Putting Runway 1.0 on Google Play

A step-by-step guide for the Android release, written to be followed in
order. Everything you type into Google's forms is here, ready to copy.

**What Android 1.0 is:** the same app as the App Store 1.0 (Home, Savings,
Quick Add, Coach, reminders, the app lock, optional Sign in with Google or
Apple with encrypted budget sync, and **Friends**), plus two Android extras:

- **Gemini Nano** writes the Coach's answers and the weekly recap, and reads
  what you say into the Quick Add mic, on phones that have it (Pixel 9 and
  newer, Galaxy S24 and newer, some others). Everything stays on the phone.
  Other phones use the built-in rules.
- **Log from anywhere:** a "Log expense" Quick Settings tile and a "Log by
  voice" home-screen icon, both opening Quick Add listening.

Squads are hidden, as on iPhone. The code is on the **`release-1.0`**
branch.

**How long it takes:** a new personal Play account must run a **closed test
with at least 12 testers for 14 days in a row** before it can publish. Plan
on about **three weeks** from creating the account to going live.

---

## Contents

1. [Create your Google Play developer account](#1-create-your-google-play-developer-account)
2. [Create your upload key](#2-create-your-upload-key)
3. [Keep Google sign-in working on Play builds](#3-keep-google-sign-in-working-on-play-builds)
4. [Build the app bundle](#4-build-the-app-bundle)
5. [Create the app in Play Console](#5-create-the-app-in-play-console)
6. [App content forms](#6-app-content-forms)
7. [Data safety form](#7-data-safety-form)
8. [Store listing](#8-store-listing-copy-and-paste)
9. [Closed test: 12 testers, 14 days](#9-closed-test-12-testers-14-days)
10. [Apply for production and release](#10-apply-for-production-and-release)
11. [Phones that already have Runway](#11-phones-that-already-have-runway)
12. [What's already done in the code](#12-whats-already-done-in-the-code)
13. [Judgement calls to confirm](#13-judgement-calls-to-confirm)
14. [Checklist](#14-checklist)

---

## 1. Create your Google Play developer account

1. Go to <https://play.google.com/console/signup> and sign in with the
   Google account you want to own the app. (Use one you'll keep for years.)
2. Choose **Yourself** (a personal account). An organization account skips
   the 12-tester rule, but needs a registered business with a D-U-N-S number.
3. Pay the one-time **$25** fee.
4. Verify your identity (a government ID) and your phone number. Google may
   also ask you to verify that you own an Android phone, through the **Play
   Console** app. Verification can take a few days, so do this first.
5. Your **developer name** is shown on the store. Your **email address** is
   shown publicly on the store listing too; consider a separate address such
   as `runway.app.help@gmail.com`.

---

## 2. Create your upload key

Every app on Play is signed. You keep an **upload key**; Google keeps the
real app-signing key (Play App Signing, on by default) and re-signs what you
upload. If you lose the upload key, Google can reset it, but it takes days,
so **back it up**.

1. In Terminal, run this once (it asks for a password; pick a strong one and
   save it in your password manager):

   ```sh
   keytool -genkeypair -v -keystore ~/runway-upload.jks -alias upload \
     -keyalg RSA -keysize 2048 -validity 10000
   ```

   Answer the questions (your name is enough; the rest can be blank).
2. Create the file `android/key.properties` in the project (it's in
   `.gitignore`, so it's never committed):

   ```properties
   storePassword=the password you picked
   keyPassword=the password you picked
   keyAlias=upload
   storeFile=/Users/kri1504/runway-upload.jks
   ```

3. Back up `~/runway-upload.jks` and the password somewhere safe (a password
   manager that holds files, or an encrypted USB stick). **Never** put it in
   the git repository, iCloud Desktop or a public place.

With `key.properties` in place, release builds are signed with the upload
key. Without it they fall back to the debug key, which is fine for testing
on your own phone but Google Play rejects.

---

## 3. Keep Google sign-in working on Play builds

Google sign-in on Android only works for app signatures Google Cloud knows
about. Today only this Mac's **debug** key is registered, so a Play build
would fail to sign in with Google until you add two more fingerprints.

1. **Upload key SHA-1:**
   `keytool -list -v -keystore ~/runway-upload.jks -alias upload` → copy the
   `SHA1:` line.
2. **Play's app-signing key SHA-1:** after the first upload (step 9), Play
   Console → your app → **Test and release → App integrity → App signing**
   → copy **SHA-1 certificate fingerprint** under "App signing key
   certificate".
3. For **each** of the two: [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
   (the project with Runway's sign-in) → **Create credentials → OAuth client
   ID → Android**, package name `com.kriyanshshah.runway`, paste the SHA-1,
   **Create**. Keep the existing debug one.

No code change is needed: the app uses the web client ID for the sign-in
token, and Google matches the Android app by package name and signature.
Test it on the closed-test build (step 9) before anything else.

---

## 4. Build the app bundle

Play takes an **app bundle** (`.aab`), not an APK.

1. Raise the build number in `pubspec.yaml` for every upload: `version:
   1.0.0+1` → `1.0.0+2` → … (Play refuses a number it has seen.)
2. From the `runway` folder, on `release-1.0`, with `android/key.properties`
   in place:

   ```sh
   flutter clean
   flutter build appbundle --release
   ```

3. The file is `build/app/outputs/bundle/release/app-release.aab`. Check it's
   signed with your upload key (the SHA1 should match step 3.1):

   ```sh
   keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
   ```

Squads stay off; Friends is on.

---

## 5. Create the app in Play Console

Play Console → **Create app**:

| Field | Answer |
| --- | --- |
| App name | `Runway: Student Budget` |
| Default language | English (United States) – en-US |
| App or game | App |
| Free or paid | Free |
| Declarations | Tick the Developer Program Policies and US export laws boxes |

---

## 6. App content forms

Play Console → your app → **Policy and programs → App content**. Answer each:

- **Privacy policy:** `https://kriyansh-shah.github.io/runway/privacy.html`
  (it must be live first: merge `release-1.0` into `main` and push, as in
  step 4 of the App Store guide).
- **App access:** *All or some functionality is restricted.* Add
  instructions:

  ```
  Runway works without an account: type a first name, tap Get started and set up a budget. Only the Friends tab needs sign-in (Google or Apple). To test Friends, sign in with this test Google account: <test account email> / <password>. It already has a friend ("Sam") and a split bill. Split a bill → Someone else also adds a person by name with no second account.
  ```

  Create a **separate Gmail account** just for reviewers (no 2-step
  verification), sign into Runway with it once, add a friend from your own
  account and split a bill, so the reviewer sees Friends working. The same
  account can be given to Apple's reviewer too, instead of a video.
- **Ads:** No, the app doesn't contain ads.
- **Content rating:** start the questionnaire, category **"All other app
  types"** (not a game). Answer **No** to violence, sexuality, language,
  drugs, gambling. For **"Does the app allow users to interact or exchange
  content?"** answer **Yes**: friends see the description of a bill they
  split (for example "Groceries"). It doesn't share location, and there's no
  chat. Expected rating: Everyone or Teen, with an "Users Interact" note.
- **Target audience and content:** **18 and over** only. Runway is for
  college students, and choosing under-18 ages brings the Families policy.
  "Could your app unintentionally appeal to children?" → No.
- **News app:** No.
- **Data safety:** see [section 7](#7-data-safety-form).
- **Government apps:** No.
- **Financial features:** **"My app doesn't provide any financial
  features."** Runway doesn't lend, bank, insure, trade, report credit or
  move money; it's a budget you type in yourself. See
  [judgement call 2](#13-judgement-calls-to-confirm).
- **Health apps:** No health features.
- **Advertising ID:** No (the app doesn't use it; the manifest doesn't ask
  for it).
- **Account deletion:** the URL is
  `https://kriyansh-shah.github.io/runway/delete-account.html` (live once
  merged to `main`). It explains deleting in the app and, without the app,
  in the web app.

---

## 7. Data safety form

Play Console → **App content → Data safety**. These answers match the code
and the privacy policy.

**Does your app collect or share any of the required user data types?** →
**Yes.**
**Is all of the user data collected by your app encrypted in transit?** →
**Yes** (HTTPS only).
**Do you provide a way for users to request that their data is deleted?** →
**Yes** (in the app, and the delete-account page).

**Collected** (none of it is **shared**: Supabase runs the server for
Runway, which Google counts as a service provider, not sharing):

| Data type | Collected | Optional? | Purpose | Processed ephemerally? |
| --- | --- | --- | --- | --- |
| Personal info → **Name** | Yes | Optional (only with sign-in) | App functionality, Account management | No |
| Personal info → **Email address** | Yes | Optional | App functionality, Account management | No |
| Personal info → **User IDs** | Yes | Optional | App functionality, Account management | No |
| Financial info → **Other financial info** | Yes | Optional (only with Friends) | App functionality | No |
| App activity → **Other user-generated content** | Yes | Optional (only with Friends) | App functionality | No |

Not collected:

- **The budget itself** stays on the phone. Budget sync uploads it only
  end-to-end encrypted with the person's passphrase, so Runway can't read
  it; Google's guidance treats end-to-end encrypted data the developer can't
  access as not collected.
- **Audio:** the mic uses the phone's speech recognition; Runway only gets
  the text, on the phone.
- **Coach questions and Gemini Nano:** on the phone only.
- **Location, contacts, photos, device IDs, crash logs, analytics:** none.

---

## 8. Store listing (copy and paste)

Play Console → **Grow users → Store presence → Main store listing**.

**App name** (30 max; this is 22):

```
Runway: Student Budget
```

**Short description** (80 max; this is 72):

```
Know what's safe to spend today, so your money lasts the whole semester.
```

**Full description** (4,000 max):

```
Student money comes all at once: a loan, a scholarship, help from family, savings from a summer job. It has to last the whole semester, and it rarely does. Runway turns it into one number: what's safe to spend today.

HOW IT WORKS
• Tell Runway how much you have and when your semester (or month) ends.
• It sets aside your big costs, monthly bills and savings goal first.
• It spreads the rest over the days left and shows what's safe to spend today.
• Spend less today and tomorrow's number goes up. Spend more and it adjusts, so you always know where you stand.

LOG IN SECONDS
• Quick Add: two taps for most purchases.
• Say it: tap the mic and say "12 dollars at Chipotle".
• Log from anywhere: add the "Log expense" Quick Settings tile, or a "Log by voice" icon on your home screen.
• A calendar of every day, so you can fix or delete anything later.

PLAN AHEAD
• Big costs and monthly bills are reserved before they're due.
• Money coming in (paychecks, scholarships) counts only on the day it arrives.
• A savings goal that's set aside on day one, plus "Saving for" jars for bigger things.
• See when your money runs out at your current pace, and how many days short you'd be.

ASK BEFORE YOU BUY
Ask the Coach "Can I afford concert tickets for $60?" and get a straight answer: yes, yes if you trade for it, or not this semester, with a plan to save for it. On phones with Gemini Nano, answers are written on your phone.

SPLIT BILLS WITH FRIENDS
• Add friends with a code and split a bill: equally, by exact amounts, percentages or shares.
• Your part counts as spending in your budget automatically; friends see what they owe in their app.
• Settle up with a tap. Friends only ever see your first name and the bills you split, never your budget.

PRIVATE BY DESIGN
• No bank linking. You log what you spend.
• Your budget is stored encrypted on your phone.
• Optional fingerprint or face lock.
• Optional sign-in with Google or Apple, to sync your budget to your other devices. It's end-to-end encrypted with a passphrase only you know, so nobody else can read it, not even us.
• No ads, no tracking, no analytics.

GENTLE REMINDERS
Optional reminders the day before a bill is due, an evening check-in if you haven't logged anything, and a weekly recap.

Made by a student, for students.
```

**Graphics:**

| Asset | Size | Where |
| --- | --- | --- |
| App icon | 512 × 512 PNG | `docs/play/icon-512.png` (ready) |
| Feature graphic | 1024 × 500 PNG or JPG | Make one: the icon and "Know what you can spend today" on Runway's dark background |
| Phone screenshots | 2 to 8, 9:16, at least 1080 px wide | Same screens as the App Store list, plus Friends and the Quick Settings tile |
| Tablet screenshots | Optional | Skip for 1.0 |

Take screenshots on your phone (power + volume down) with realistic data,
and don't show squads.

**Store settings:** category **Finance**; contact email (shown publicly);
website `https://kriyansh-shah.github.io/runway/`.

---

## 9. Closed test: 12 testers, 14 days

1. Play Console → **Test and release → Testing → Closed testing → Create
   track** (or use the default "Closed testing - Alpha").
2. **Testers:** create an email list with **15 or more** people (a margin
   over 12, in case someone drops out). Their emails must be the Google
   accounts they use on their Android phones. Classmates are ideal.
3. **Create release → upload the `.aab`** from step 4. Release name `1.0.0
   (1)`; release notes "First test of Runway."
4. **Countries:** pick the United States (and anywhere your testers are).
5. Send it for review (a few hours to a few days).
6. When it's approved, copy the **opt-in link** from the track and send it to
   your testers. Each must open the link, tap **Become a tester**, then
   install Runway from the Play Store link on that page.
7. **Keep at least 12 opted in for 14 days in a row.** If someone leaves
   and you drop below 12, the count starts over. Ask testers to actually use
   it a few times; Google asks about it at the end.
8. Use the time well: check Google sign-in (step 3), Friends with two
   phones, the Quick Settings tile, and Gemini Nano if anyone has a Pixel 9+
   or Galaxy S24+. Push fixes as new builds to the same track; testers stay
   opted in.

Play Console → **Dashboard** shows the tester count and the days left.

---

## 10. Apply for production and release

1. After 14 days, **Dashboard → Apply for production**. Google asks:
   - **How did you recruit testers?** "Classmates and friends at my
     university, invited by email."
   - **How easy was it to recruit?** Answer honestly.
   - **How did testers use the app, and what feedback did you get?** Name
     real things: what they logged, the bugs you fixed, what you changed.
   - **Who is the app for, and what does it offer?** "College students
     budgeting a semester's money: a daily safe-to-spend number, quick
     logging, a coach and bill splitting with friends."
   - **What changed based on the test?** List the fixes.
   - **Is the app ready?** Yes.
2. Google reviews the application (usually up to 7 days).
3. Then **Production → Create release** → add the latest `.aab` →
   **Countries** (United States to start) → review → **Start rollout**.
   A **staged rollout** (for example 20%, then 100%) lets you catch problems
   early.

---

## 11. Phones that already have Runway

The Runway on your phone and your professor's was installed from an APK
signed with this Mac's **debug key**. The Play version is signed by Google,
so Android won't install it over the old one: **uninstall first**, which
erases the budget on that phone.

To keep it: turn on **Budget sync** in the old version (Settings → Account),
install the Play version, sign in with the same account and enter the sync
passphrase. Or set the budget up again.

---

## 12. What's already done in the code

- **Target API 36** (Android 16) and **minimum Android 7** (API 24): meets
  Play's 2026 requirement for new apps.
- **16 KB memory pages:** every native library in the build is 16 KB-aligned
  and the APK passes `zipalign -c -P 16` (required for Android 15+ devices).
- **Release signing** reads `android/key.properties` (step 2), never
  committed; without it the build falls back to the debug key.
- **Permissions**, each only when used: internet; microphone (only when you
  tap the mic); notifications (only when you turn on reminders); restarting
  reminders after a reboot; fingerprint/face for the app lock; vibration;
  network state (added by a plugin); AICore (Gemini Nano). No location, no
  contacts, no exact alarms, no advertising ID.
- **Account deletion** in the app (Settings → Account → Delete account) and
  on the website (`docs/delete-account.md`, built into the site by
  `scripts/build_site.sh`).
- **Privacy policy** covers Android: Gemini Nano on the phone, the Keystore,
  speech recognition, Friends.
- **Backups:** Android cloud backup is off for Runway (`allowBackup=false`),
  so the encrypted database and its key don't leave the phone that way.
- **Store icon:** `docs/play/icon-512.png`.

---

## 13. Judgement calls to confirm

1. **Reporting AI answers.** Google requires apps with *generative AI
   chatbots* to let people report offensive AI output from inside the app.
   Runway's Coach uses Gemini Nano only to word answers the rules already
   decided, checks every amount, and can only talk about the person's own
   budget, which is closer to the exempt "productivity" kind.
   **Decided (November 12, 2026): ship without a report button.** Adding
   one would send the reported answer (which includes budget numbers) to
   Runway's server, which the privacy policy says never happens. If Google
   asks for it, add a "Report this answer" option then (a small new server
   table and a privacy policy line).
2. **Financial features: none.** A budget you type in yourself isn't
   banking, lending, insurance, trading or credit reporting. Coach's "can I
   afford it" answers are about your own budget, not investment advice.
   If Google disagrees, change the declaration to "Other".
3. **Target audience 18+.** Keeps the app out of the Families program. Most
   college students are 18 or older; if you want 17-year-old freshmen, pick
   "16–17" too and expect a few extra questions.
4. **Content rating "users interact": Yes**, because friends see split
   descriptions. Answering No would be inaccurate.
5. **Public contact email.** Play shows it on the listing. Use one you're
   happy to publish.

---

## 14. Checklist

Accounts and setup

- [ ] Play developer account created, identity verified
- [ ] Upload key created, `android/key.properties` written, key and password backed up
- [ ] Upload-key SHA-1 added to Google Cloud as an Android OAuth client
- [ ] `release-1.0` merged into `main` and pushed (privacy policy and delete-account page live)
- [ ] Reviewer test Google account created, with a friend and a split

Play Console

- [ ] App created
- [ ] App content: privacy policy, app access, ads, content rating, target audience, news, data safety, government, financial features, health, advertising ID, account deletion URL
- [ ] Store listing: name, short and full description, icon, feature graphic, phone screenshots, category, contact email
- [x] Judgement call 1 (reporting AI answers): ship without; add if Google asks

Testing

- [ ] Build number raised; `flutter build appbundle --release`; signed with the upload key
- [ ] Closed track created, 15+ testers, `.aab` uploaded and approved
- [ ] Play's app-signing SHA-1 added to Google Cloud; Google sign-in works on the Play build
- [ ] 12+ testers opted in for 14 days in a row

Production

- [ ] Applied for production; approved
- [ ] Production release rolled out (staged)
- [ ] Your phone and your professor's moved to the Play version (section 11)

Sources for Google's rules:
[target API level](https://support.google.com/googleplay/android-developer/answer/11926878),
[testing requirements for new personal accounts](https://support.google.com/googleplay/android-developer/answer/14151465),
[financial features declaration](https://support.google.com/googleplay/android-developer/answer/13849271),
[AI-generated content](https://support.google.com/googleplay/android-developer/answer/13985936),
[16 KB page sizes](https://android-developers.googleblog.com/2025/05/prepare-play-apps-for-devices-with-16kb-page-size.html).
