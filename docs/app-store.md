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
- **Privacy policy:** written in [`privacy.md`](privacy.md). It still needs a
  contact email and a public web address (see below).

## App Privacy label (App Store Connect)

**Answer: "Yes, we collect data"**, only for people who sign in with Google:

| Data type | Linked to the user | Used for tracking | Purpose |
| --- | --- | --- | --- |
| Contact Info → Name | Yes | No | App Functionality |
| Contact Info → Email Address | Yes | No | App Functionality |
| Identifiers → User ID | Yes | No | App Functionality |
| Usage Data → Product Interaction (Squad streak, challenge days) | Yes | No | App Functionality |
| User Content → Other User Content (squad names) | Yes | No | App Functionality |

Money data (balances, expenses, budgets) never leaves the phone, so no
Financial Info is collected. Face ID results come from iOS and aren't stored.
Squad shares first name, emoji, streak and no-delivery days with squad
members only (see privacy.md).

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
> names, streaks and challenge days. Money data stays on the device,
> encrypted, and is never sent to a server.

## Owner to-do (needs your accounts or decisions)

- [ ] **Apple Developer Program** ($99/yr). Needed to upload at all, and for
      TestFlight.
- [ ] **App record** in App Store Connect: name "Runway" (it may be taken, so
      have a backup such as "Runway: Student Budget"), bundle ID
      `com.kriyanshshah.runway`, category **Finance**, age rating questionnaire
      (expected 4+).
- [ ] **Contact email** for the privacy policy and the support page.
- [ ] **Publish the privacy policy** at a public URL. The repo is private, so
      free GitHub Pages won't work from it. Options: a small public repo just
      for the page, or any free page host.
- [ ] **Support URL** (it can be the same page with a contact section).
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
