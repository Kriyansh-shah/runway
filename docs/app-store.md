# App Store checklist

Where Runway stands before its first App Store submission, and what's left.

## ✅ Ready in the code

- **App icon:** 1024×1024 with no transparency (Apple rejects transparent icons).
- **Launch screen:** dark (`#0D0D10`) like the app, so there's no white flash
  on launch. The Android launch screen matches.
- **Face ID message:** "Runway uses Face ID so only you can open your budget."
- **Version:** 1.0.0, build 1 (`version:` in `pubspec.yaml`; raise the build
  number for every upload).
- **No sign-in, so no account deletion is needed.** Apple only requires in-app
  account deletion for apps that have accounts.
- **Privacy policy:** written in [`privacy.md`](privacy.md). It still needs a
  contact email and a public web address (see below).

## App Privacy label (App Store Connect)

**Answer: "No, we do not collect data from this app."**

Apple counts data as "collected" only when it's sent off the device. Runway
has no servers, analytics, ads or tracking, and nothing leaves the phone. Face
ID results come from iOS and aren't stored. If Squad ever syncs real friends,
this answer has to change before that update ships.

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
> Get started, then enter any dates and an amount to set up a budget. The app
> lock (Face ID) is optional. Squad currently shows sample friends to preview
> the feature; nothing is shared. Runway makes no network requests: all data
> stays on the device, encrypted.

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
