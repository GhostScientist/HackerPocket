# Releasing HackerPocket

This is the complete, repeatable process for shipping a release of HackerPocket (App Store name: **HackerWatch: Hacker News**, App ID 6479969061). Follow it top to bottom. Every step is a checkbox so a release can be tracked in the release PR or issue.

The release unit is a **git tag on `main`** that points at the exact commit that was archived and uploaded to App Store Connect. The GitHub Release and the App Store version are both derived from that tag.

---

## 0. Versioning policy

| Field | Where | Meaning |
|---|---|---|
| `MARKETING_VERSION` | `project.pbxproj`, every target | The user-facing version (`3.0`, `3.0.1`, `3.1`). Shown on the App Store. |
| `CURRENT_PROJECT_VERSION` | `project.pbxproj`, every target | The build number. A monotonically increasing integer. Never reused, never reset. |
| Git tag | `v<MARKETING_VERSION>` (e.g. `v3.0`) | Annotated tag on the archived commit. |

Rules:

- **All three targets** (`HackerPocket`, `HackerPocket Watch App`, `HackerPocketWidgetExtension`) must carry identical `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in both Debug and Release. App Store Connect rejects uploads where an embedded extension's version differs from its container, and Xcode warns about it at build time.
- Bump `MARKETING_VERSION` using semantic intent: **major** for a reworked experience or removed capability, **minor** for new features, **patch** for fixes only.
- Bump `CURRENT_PROJECT_VERSION` by at least one on **every** upload to App Store Connect, including TestFlight-only builds and resubmissions after a rejected review.
- Never move or delete a tag that has been pushed. If a tagged build is bad, ship a new patch version.

## 1. Pre-flight (do before touching versions)

- [ ] You are on `main`, it is up to date with `origin/main`, and the working tree is clean:
  ```sh
  git checkout main && git pull --ff-only && git status --short
  ```
- [ ] Every PR intended for this release is merged. Anything not merged waits for the next release; do not cherry-pick.
- [ ] Triage open issues. Close any the release fixes (reference the PR) and label anything that must ship as a blocker.
- [ ] The tree builds with zero errors and zero new warnings on the simulator without signing:
  ```sh
  xcodebuild -project HackerPocket.xcodeproj -scheme "HackerPocket Watch App" \
    -destination 'generic/platform=watchOS Simulator' -configuration Release \
    CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "warning:|error:|BUILD"
  ```
- [ ] Manual smoke test on a **physical Apple Watch** (the simulator cannot exercise background refresh, Handoff, haptics, or the complication reliably). Cover, at minimum:
  - Cold launch with airplane mode on (cached content renders, no crash, error state has retry).
  - Cold launch online, then switch through all six feeds.
  - Search: run a query, open a result, confirm "No results" state.
  - Open a story with 100+ comments, Load More, expand and collapse, leave and return (reading bookmark restored).
  - Log in, upvote a story and a comment, post a reply, log out (vote state hides while logged out).
  - Save a story, open the Saved list offline.
  - Read a story, confirm it dims, clear history.
  - Add the complication in each family; tap the rectangular one and confirm it deep-links to the story.
  - Handoff an article to iPhone.
  - Check the smallest supported case size (40/41mm) for text wrapping and chrome overlap.
- [ ] Accessibility pass: VoiceOver reads story rows, comment actions, and the More screen sensibly; Larger Text does not break layouts.
- [ ] Confirm `WATCHOS_DEPLOYMENT_TARGET` is intentional. It is currently `26.0`; raising it drops users.

## 2. Version bump

- [ ] Decide the version per the policy in section 0.
- [ ] Update every target in `HackerPocket.xcodeproj/project.pbxproj`. Do it with `sed` so nothing is missed:
  ```sh
  OLD_V=3.0 NEW_V=3.1 OLD_B=4 NEW_B=5
  sed -i '' -e "s/MARKETING_VERSION = ${OLD_V};/MARKETING_VERSION = ${NEW_V};/g" \
            -e "s/CURRENT_PROJECT_VERSION = ${OLD_B};/CURRENT_PROJECT_VERSION = ${NEW_B};/g" \
            HackerPocket.xcodeproj/project.pbxproj
  plutil -lint HackerPocket.xcodeproj/project.pbxproj
  ```
- [ ] Verify exactly six `MARKETING_VERSION` and six `CURRENT_PROJECT_VERSION` lines all show the new values:
  ```sh
  grep -nE "MARKETING_VERSION|CURRENT_PROJECT_VERSION" HackerPocket.xcodeproj/project.pbxproj
  ```

## 3. Release notes

Two audiences, two documents. Write both **before** archiving so the notes describe what was actually built.

- [ ] **`CHANGELOG.md`** (developer audience, GitHub). Move everything under `## [Unreleased]` into a new `## [<version>] (build <n>) - <YYYY-MM-DD>` section with `Added` / `Changed` / `Fixed` / `Internal` subsections. Add the compare link at the bottom. Leave `[Unreleased]` in place, empty.
  - Source material: `gh pr list --state merged --search "merged:>YYYY-MM-DD"` and each PR body.
  - Write for the reader of the release, not the author of the PR: user-visible behaviour first, implementation detail only when it explains a behaviour change.
- [ ] **App Store "What's New"** (end-user audience, 4000 character limit, no markdown). Save it as `docs/release-notes/<version>-app-store.md` so it is reviewable and versioned. Plain sentences, short list, lead with the headline feature. Refer to the app as HackerWatch there.

## 4. Release commit

- [ ] Commit the bump and notes together on `main` (or via a short-lived `release/<version>` branch and PR if you want review):
  ```sh
  git add HackerPocket.xcodeproj/project.pbxproj CHANGELOG.md docs/release-notes/
  git commit -m "Release <version> (build <n>)"
  git push origin main
  ```
- [ ] Confirm CI (if configured) is green on that commit before archiving.

## 5. Archive and upload

Archive from the **exact commit** you will tag. Do not make further changes between archive and tag.

- [ ] In Xcode: select the `HackerPocket Watch App` scheme, destination **Any watchOS Device (arm64)**, then **Product → Archive**. Or from the CLI:
  ```sh
  xcodebuild -project HackerPocket.xcodeproj -scheme "HackerPocket Watch App" \
    -destination 'generic/platform=watchOS' -configuration Release \
    -archivePath "build/HackerPocket-<version>.xcarchive" archive
  ```
- [ ] In the Organizer, confirm the archive's version and build match the bump, then **Distribute App → App Store Connect → Upload**. Keep "Upload your app's symbols" checked so crash logs symbolicate.
- [ ] Wait for App Store Connect to finish processing (email arrives, typically 5–20 minutes). Fix any "Missing Compliance" prompt: this app uses only HTTPS, so answer **No** to non-exempt encryption (or add `ITSAppUsesNonExemptEncryption = NO` to the Info.plist to stop the prompt).
- [ ] Record the archive's git SHA:
  ```sh
  git rev-parse HEAD
  ```

## 6. Tag

Tag only after the upload succeeds, so the tag is guaranteed to match a build that exists in App Store Connect.

- [ ] Create an **annotated** tag on the release commit and push it:
  ```sh
  git tag -a v<version> -m "HackerPocket <version> (build <n>)"
  git push origin v<version>
  ```
- [ ] Verify: `git describe --tags` prints `v<version>` and the tag is visible at `https://github.com/GhostScientist/HackerPocket/tags`.

## 7. GitHub Release

Create it as a **draft** now, publish it when the App Store version goes live, so the GitHub release date matches the real availability date.

- [ ] Create the draft from the tag, using the changelog section as the body:
  ```sh
  gh release create v<version> --draft --title "HackerPocket <version>" \
    --notes-file <(awk '/^## \[<version>\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md)
  ```
- [ ] Attach the `.xcarchive` dSYMs so crashes reported outside App Store Connect can be symbolicated:
  ```sh
  (cd "build/HackerPocket-<version>.xcarchive/dSYMs" && zip -r "../../HackerPocket-<version>-dSYMs.zip" .)
  gh release upload v<version> "build/HackerPocket-<version>-dSYMs.zip"
  ```
- [ ] Set **"Set as the latest release"**. Do not mark it a pre-release unless it is a TestFlight-only build.

## 8. TestFlight

- [ ] Add the processed build to the internal TestFlight group and install it on a real watch.
- [ ] Repeat the critical subset of the smoke test from section 1 on the TestFlight build (login, upvote, offline launch, complication).
- [ ] If anything fails: fix on `main`, bump the **build number only** (or the patch version if the fix is user-visible), and restart from section 4. Do not reuse the tag; the failed build's tag stays as a record and the new tag supersedes it.

## 9. Submit for review

- [ ] In App Store Connect, create the new version under the HackerWatch app (or use the auto-created one), select the processed build, and paste the "What's New" text from `docs/release-notes/<version>-app-store.md`.
- [ ] Update screenshots if the UI changed materially (3.0 did). Required sizes: Apple Watch Series 10/11 46mm, Ultra 49mm, and 41/42mm.
- [ ] Review the privacy answers. The app makes no third-party calls beyond `hacker-news.firebaseio.com`, `hn.algolia.com`, and `news.ycombinator.com`; "Data Not Collected" remains accurate as long as that holds.
- [ ] Set the release option. Recommended: **Manually release this version**, so the GitHub release and App Store release can be published together.
- [ ] Submit for review. Add a note for the reviewer with a throwaway HN account if login flows should be tested.

## 10. Go live

- [ ] When review approves, press **Release This Version** in App Store Connect.
- [ ] Publish the GitHub draft release:
  ```sh
  gh release edit v<version> --draft=false
  ```
- [ ] Close any issues fixed by the release that are still open, with a comment linking the release.
- [ ] Verify the App Store listing shows the new version and notes (can lag by a few hours).

## 11. Post-release

- [ ] Watch App Store Connect crash reports and TestFlight feedback for 48 hours.
- [ ] Leave `MARKETING_VERSION` as is; the next feature PR to merge bumps it under `## [Unreleased]` in the changelog, not in the project file. The version is only bumped in the project during a release.
- [ ] If a hotfix is needed: branch from the tag (`git checkout -b hotfix/<version>.1 v<version>`), fix, merge to `main`, and run this document again with a patch version.

---

## Hotfix quick path

For a patch release with only bug fixes: sections 1 (build + targeted smoke test), 2, 3, 4, 5, 6, 7, 9, 10. Skip TestFlight only if the fix is trivial and was verified on-device from a local build.

## Known gaps to close in a future release (not blockers)

- No shared Xcode scheme is committed (`xcshareddata/xcschemes` is absent), so CI or a second machine cannot build without recreating one. Share the `HackerPocket Watch App` scheme from Xcode (Product → Scheme → Manage Schemes → Shared) and commit it.
- No CI. A GitHub Actions workflow running the section-1 `xcodebuild` on every PR would catch build breaks before release day.
- The widget performs its own network fetch because there is no App Group entitlement. Adding one requires the Developer account and would let the widget read the app's cache.
- The App Store name (HackerWatch) and the repo/product name (HackerPocket) differ. Decide whether to align them; until then, notes for each audience use the name that audience sees.
