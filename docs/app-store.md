# App Store checklist

Where Runway stands before its first App Store submission, and what's left.

## ✅ Ready in the code

- **App icon:** 1024×1024 with no transparency (Apple rejects transparent icons).
- **Launch screen:** dark (`#0D0D10`) like the app, so there's no white flash
  on launch. The Android launch screen matches.
- **Face ID message:** "Runway uses Face ID so only you can open your budget."
- **Version:** 1.0.0, build 1 (`version:` in `pubspec.yaml`; raise the build
  number for every upload).
- **Account deletion in the app** (Settings → Account → Delete account), as
  Apple requires for apps with sign-in. It calls the `delete-account` Edge
  Function (`supabase/functions/delete-account`).
- ⚠️ **Squad has Leave but no Remove member, Block or Report yet.** Apple
  expects these when users can interact (Guideline 1.2). Squads are
  invite-only and show only names and streaks, but add them before
  submitting.
- ⚠️ **Sign in with Apple is still missing.** Because Runway offers Google
  sign-in, App Review Guideline 4.8 requires an equivalent privacy-focused
  option. Add Sign in with Apple (needs the paid developer account) before
  the first submission.
- **Privacy policy:** [`privacy.md`](privacy.md), published on the website.
  Contact is a GitHub issue link for now; a contact email is friendlier.

## App Privacy label (App Store Connect)

**Answer: "Yes, we collect data"**, only for people who sign in with Google:

| Data type | Linked to the user | Used for tracking | Purpose |
| --- | --- | --- | --- |
| Contact Info → Name | Yes | No | App Functionality |
| Contact Info → Email Address | Yes | No | App Functionality |
| Identifiers → User ID | Yes | No | App Functionality |
| Usage Data → Product Interaction (Squad streak, challenge days) | Yes | No | App Functionality |
| User Content → Other User Content (squad names) | Yes | No | App Functionality |
| Financial Info → Other Financial Info (split bills: amounts, who paid, settle-ups) | Yes | No | App Functionality |

Money data (balances, expenses, budgets) leaves the phone only with Budget
sync on, and then end-to-end encrypted with the person's passphrase, so
Runway can't read it. Apple defines "collect" as sending data off the device
in a way the developer can access; end-to-end encrypted data Runway can't
open arguably isn't collected, so Financial Info is left off. This is the
owner's call: if unsure, add Financial Info → Other Financial Info (linked,
not tracking, App Functionality). Face ID results come from iOS and aren't stored.
Squad shares first name, emoji, streak and no-delivery days with squad
members only. Split bills with friends are stored readable (amounts, who
paid, settle-ups), visible only to the people in each split, so Financial
Info → Other Financial Info is declared for those (see privacy.md).

## Export compliance (encryption question)

App Store Connect asks whether the app uses encryption. **Runway does:** it
encrypts its own database on the phone with standard encryption
(SQLite3MultipleCiphers), only to protect the user's own data.

Apps like this usually qualify for an exemption, but the answer is the
owner's legal declaration. Read Apple's
[export compliance guide](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)
before answering. Once decided, add `ITSAppUsesNonExemptEncryption` to
`ios/Runner/Info.plist` so the question isn't asked on every upload.

## Notes for App Review (draft)

> Runway needs no account. On the first screen, type any first name and tap
> Get started, then enter any dates and an amount to set up a budget. Signing
> in with Google is optional and can be tested from Settings → Account, which
> also has Delete account. The app lock (Face ID) is optional. Squad needs
> sign-in: start a squad, then share its invite code; friends see only first
> names, streaks and challenge days. Budget sync (Settings → Account) is
> optional and end-to-end encrypted with a passphrase the person chooses.

## Owner to-do (needs your accounts or decisions)

- [ ] **Apple Developer Program** ($99/yr). Needed to upload at all, and for
      TestFlight.
- [ ] **App record** in App Store Connect: name "Runway" (it may be taken, so
      have a backup such as "Runway: Student Budget"), bundle ID
      `com.kriyanshshah.runway`, category **Finance**, age rating questionnaire
      (expected 4+).
- [ ] **Contact email** for the privacy policy and the support page.
- [x] **Privacy policy URL:** https://kriyansh-shah.github.io/runway/privacy.html
      (built from `docs/privacy.md` by `.github/workflows/website.yml`).
- [x] **Support URL:** https://kriyansh-shah.github.io/runway/support.html
      (from `docs/support.md`). **Marketing URL:** https://kriyansh-shah.github.io/runway/
- [ ] **Screenshots:** 6.9" iPhone (1320 × 2868). iPad screenshots too if the
      iPad stays supported (see below).
- [ ] **Description, subtitle and keywords.**

## Decisions before submitting

1. **Squad's sample friends.** Apple can reject apps that show placeholder or
   unfinished features (guideline 2.1, App Completeness). Options: label Squad
   clearly as a preview, or hide the tab until real friends work.
2. **iPad.** The app is currently set to support iPad, which means iPad
   screenshots, all four orientations on iPad, and an iPad layout reviewers
   will look at. Making it iPhone-only is simpler; it still runs on iPads, in
   iPhone mode. Related: on iPhone, the app currently rotates to landscape,
   which it wasn't designed for. Locking it to portrait is the usual choice.
3. **Export compliance** (above).
