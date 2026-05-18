# Google Play — Complete Publishing Guide (miniLight)

This is the full, do-this-in-order checklist to get **miniLight** live on
Google Play. The CI pipeline already builds and uploads a signed
`.aab`; what's left is the account, the keystore, the secrets, and the
one-time Console setup.

- Package name (permanent): **`com.minilight.minilight`**
- App name: **miniLight**
- Category: **Photography**
- Price: **Free**

Legend: 👤 = only you can do it · 🤖 = already automated in this repo.

---

## Step 1 — Create the Google Play developer account 👤

1. Go to <https://play.google.com/console>.
2. Sign in with the Google account you want to own the app.
3. Choose account type **Personal** (or Organization if you have a
   D-U-N-S number).
4. Pay the **one-time US$25** registration fee.
5. Complete identity verification (Google may ask for ID; can take a few
   hours to a couple of days). **You cannot publish until this clears.**

---

## Step 2 — Generate the upload keystore 👤

Do this once on any machine with a JDK (`java -version` to check). Keep
the resulting file and passwords **safe and backed up** — losing them
means you can never update the app again under this key.

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

It will ask for:
- a **keystore password** (remember it),
- name/org fields (any sensible values),
- a **key password** (you can press Enter to reuse the keystore one).

You now have `upload-keystore.jks`.

> The repo is set up for **Play App Signing**: Google holds the real app
> signing key; this `upload-keystore.jks` is only your *upload* key. If it
> is ever compromised you can ask Google to reset it.

---

## Step 3 — Add the GitHub Secrets 👤

Repo → **Settings → Secrets and variables → Actions → New repository
secret**. Add these four (names must match exactly):

| Secret name | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | base64 of the `.jks` (command below) |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password from Step 2 |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the key password from Step 2 |

Produce the base64 string:

```bash
# macOS / Linux
base64 -i upload-keystore.jks | tr -d '\n' > keystore.b64.txt
# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) > keystore.b64.txt
```

Paste the contents of `keystore.b64.txt` as `ANDROID_KEYSTORE_BASE64`.

🤖 With these present, every push builds a **signed** `app-release.aab`.

---

## Step 4 — Create the app in Play Console 👤

1. Play Console → **Create app**.
2. App name **miniLight**, default language, app type **App**, **Free**.
3. Accept the declarations.
4. Left menu → work through **Dashboard → "Set up your app"**:
   - **App access**: All functionality available without restrictions.
   - **Ads**: No ads.
   - **Content rating**: fill the questionnaire — it's a utility/photo
     app, no objectionable content → expect **Everyone / PEGI 3**.
   - **Target audience**: 13+ (not designed for children).
   - **News app**: No.
   - **Data safety**: see Step 6.
   - **Government app**: No.

---

## Step 5 — Store listing 👤 (copy/paste ready)

Play Console → **Main store listing**.

**App name:** `miniLight`

**Short description (≤80 chars):**
```
Free film camera light meter — reflective, incident & sensor metering.
```

**Full description (paste as-is):**
```
miniLight turns your phone into a precise light meter for film
photography — completely free, no ads, no accounts, no tracking.

METERING
• Reflective metering through the camera (spot, center-weighted, average)
• Tap anywhere on the preview to meter that exact spot
• Incident-style metering using the ambient-light sensor
• "Real" mode reads the camera's own exposure data for a
  calibration-free absolute EV

EXPOSURE CONTROL
• Aperture- or shutter-priority, full / half / third stops
• Camera body profiles that snap to your camera's real shutter speeds
• Push/pull processing, filter-factor and bellows compensation
• Exposure-compensation dial and Zone System placement
• Film stock presets with reciprocity-failure correction
• Add your own custom film stocks

WORKFLOW
• Shot log: organise rolls, log every frame with optional GPS
• Export any roll to CSV
• Reading hold/lock, highlight/shadow clipping warning
• English and Simplified Chinese

Everything runs on your device. No data is uploaded.
```

**App icon:** auto-generated from the app build (no manual upload).

**Feature graphic (required, 1024×500 PNG):** use
`assets/store/play-feature-graphic.png` from this repo (placeholder —
replace with real artwork anytime).

**Phone screenshots (required, 2–8, PNG/JPEG):** you must capture these on
a device/emulator. Install the APK from the GitHub Release, then screenshot:
1. the live meter screen with a reading,
2. the Compensations screen,
3. the Shot log / rolls screen,
4. Settings (film + camera body).
Recommended size: 1080×1920 (portrait).

**Privacy policy URL:** after this branch is merged to `main` and Pages is
enabled (repo Settings → Pages → Source: GitHub Actions):
`https://baidongli.github.io/minilight/privacy-policy.html`

---

## Step 6 — Data safety form 👤 (exact answers for this app)

Play Console → **Data safety**:

- Does your app collect or share any user data? → **No**.
  - The camera and ambient-light sensor are used only for on-device
    metering; nothing is stored or transmitted.
  - Location is used only if the user attaches GPS to a shot-log entry;
    it is stored locally and never sent off the device, so it is **not
    "collected"** in Play's sense (no transmission off device). If the
    form's wording makes you prefer to disclose it: choose **Location →
    used, not shared, processed on-device only**.
- Is all data encrypted in transit? → N/A (no data leaves the device).
- Can users request deletion? → Data is local; uninstalling removes it.

---

## Step 7 — First upload (one-time manual) 👤

Google requires the **very first** bundle of a brand-new app to be
uploaded by hand; CI takes over afterwards.

1. Make sure the four secrets (Step 3) are set.
2. Trigger a build (push to the branch, or **Actions → Build apps → Run
   workflow**). Wait for it to go green.
3. Open the **GitHub Release** it created → download
   `minilight-*-<n>.aab`.
4. Play Console → **Testing → Internal testing → Create new release**.
5. Upload the `.aab`. If prompted about app signing, **accept "Use Google-
   generated key" / let Google manage the app signing key**.
6. Add release notes (e.g. "Initial release"), Save → Review → **Start
   rollout to Internal testing**.
7. Add yourself as an internal tester (Internal testing → Testers → create
   an email list with your Google account), open the opt-in link on your
   phone, install from Play.

---

## Step 8 — Automated uploads from then on 🤖 (one extra secret 👤)

To let CI push every build straight to the **internal** track:

1. Play Console → **Setup → API access** → create/link a Google Cloud
   project → **Create service account** → grant it (in Play Console →
   Users & permissions) the **Release to testing tracks** permission.
2. Download the service account **JSON key**.
3. Add it as GitHub Secret **`PLAY_SERVICE_ACCOUNT_JSON`** (paste the whole
   JSON).

🤖 Now each push: builds signed `.aab` → uploads to **Internal testing**
automatically. (The action only runs once the app already exists in the
Console, i.e. after Step 7.)

---

## Step 9 — Promote to production 👤

When a build is tested and good:

1. Play Console → **Production → Create new release**.
2. Either upload the same `.aab` from the Release, or **Promote** the
   internal release to Production.
3. Fill release notes, Save → **Review release** → **Start rollout to
   Production** (you can choose a staged % rollout).
4. First production submission goes through Google review — usually hours
   to a couple of days.

---

## Updating later (the routine) 🤖+👤

1. 👤 Edit `version:` in `pubspec.yaml` (e.g. `0.0.1` → `0.0.2`). The
   build number is set automatically.
2. 👤 Commit and merge to `main`. The version-bump guard fails the build
   on `main` if you forgot to change it.
3. 🤖 CI builds the signed `.aab` and uploads it to Internal testing.
4. 👤 In Play Console, promote that release to Production when ready.

That's the whole loop — for most updates you only touch one line in
`pubspec.yaml`.

---

## Troubleshooting

- **"Version code already used"** → you didn't bump `version:`; the guard
  should have caught it on `main`. Bump and re-push.
- **"Upload key mismatch"** → the keystore in `ANDROID_KEYSTORE_BASE64`
  isn't the one registered with Play. Use the original `upload-keystore.jks`.
- **CI build is debug-signed** → the four Android secrets aren't set (or a
  name is misspelled); the log prints `no keystore secret`.
- **Service-account upload fails with 403** → the service account lacks
  the release permission in Play Console → Users & permissions.
- **Gradle/AGP error after a Flutter upgrade** → the signing template in
  `scripts/configure_android_signing.sh` may need a small tweak; the CI
  log points at the exact line.
