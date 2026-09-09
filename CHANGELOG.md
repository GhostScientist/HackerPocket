# Changelog

All notable changes to HackerPocket (sold on the App Store as **HackerWatch: Hacker News**) are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions match `MARKETING_VERSION` in the Xcode project and the App Store; each version's git tag is `v<version>` (for example `v3.0`). The build number (`CURRENT_PROJECT_VERSION`) is noted in parentheses.

## [Unreleased]

Nothing yet.

## [3.0] (build 4) - 2026-09-08

A ground-up rework of the watch experience. The app is now built for short, purposeful wrist interactions: readable content first, familiar watchOS navigation, offline support, and a clear stopping point.

### Added
- **Six feeds.** Switch between Top, New, Best, Ask HN, Show HN, and Jobs. The selected feed is remembered between launches.
- **Search.** Full-text story search backed by the Algolia HN API, with dictation and Scribble input and the last five searches remembered.
- **Offline cache.** Feeds, story details, and comment threads persist on disk. Launch renders the cached content instantly and revalidates behind it, merging updates in place rather than resetting your scroll position.
- **Background refresh.** Stories refresh roughly every 30 minutes in the background, and the complication is reloaded when new content arrives.
- **Upvoting.** Upvote stories and comments while logged in, with optimistic UI and rollback on failure.
- **Saved stories.** Save stories for later; the Saved list works fully offline.
- **Read history.** Read stories are dimmed in lists; a history screen lets you review or clear them.
- **Pocket briefing.** An optional, finite briefing of up to five stories in HN order, ending with a clear "Browse More" stopping point.
- **Reading bookmarks.** Long comment threads remember where you left off, including across pagination and offline retries.
- **Handoff.** Continue reading an article on your iPhone via Handoff; the in-watch web view remains available.
- **Widget deep links.** Tapping the rectangular complication opens the story it shows via the `hackerpocket://` URL scheme.
- **Haptics.** Restrained, watch-native haptic feedback on refresh, comment posting, and voting.
- **Load More** paging for stories and comments (20 at a time) with inline "Updating…" and retryable error states.
- Dismissible contextual guidance replaces the blocking first-launch onboarding.

### Changed
- Content-first layouts throughout: headlines lead and utilities move out of the feed.
- The floating bottom-bar buttons on the story list are gone. A More button in the top-left corner opens Briefing, Saved Stories, Search, Read History, Account, and Refresh; the feed picker stays top-right. The list, including the "Updated" row, is no longer covered by chrome.
- Story detail: the source domain is a grey subheadline under the title, post text comes before actions, Comments is the single orange primary action, Read Article is a neutral readable button, Save is a bookmark toggle in the top-right corner, and Handoff, Share, and View on HN live under More Actions.
- Comment rows align author and timestamp on one baseline and use accessible icon controls instead of wrapping text labels.
- Larger, more readable typography with source domain and age metadata and explicit read/saved indicators.
- The complication prioritises the headline, shows fetch age, and distinguishes unavailable content from empty content.
- Story and comment lists no longer overlap watchOS navigation chrome; comment threads have top scroll clearance.
- Networking is now an async, cancellation-aware data layer with bounded concurrency (at most six in-flight requests) instead of unbounded fan-out.

### Fixed
- Stories rendered in completion order instead of HN rank order; the front page was effectively shuffled on every load.
- Comment threads were sorted newest-first, discarding HN's ranking.
- Job posts never finished loading because required fields were missing from the API response.
- A failed fetch showed a blank list with no explanation and no way to retry; there is now an error state with retry, and a failed refresh keeps what you were reading.
- Opening a large thread fired hundreds of simultaneous requests at the watch radio.
- Deleted and dead comments are filtered explicitly rather than by accidental decode failure.
- HTML entities (quotes, slashes, numeric escapes) in comments and post text now render correctly (#1).
- Secondary buttons on the story screen (Read Article, Handoff, More Actions) rendered in near-invisible dark grey on the black background.
- The widget extension's version and build number now match the app, clearing the build-time `CFBundleVersion` warning.

### Internal
- Added `.gitignore`; Xcode per-user state is no longer tracked.
- Added `RELEASING.md` and this changelog.

## [2.0] (build 3) - 2026-02-08

### Added
- Log into Hacker News and reply to posts and comments from the watch.
- Improved comments view with better UX for viewing comment trees.
- Improved comment formatting.
- A new "HN" complication for the watch face that jumps into the top stories.

## [1.1] (build 2) - 2024-04-01

- Minor fixes and polish.

## [1.0] (build 1) - 2024-03-26

- Initial App Store release: browse top stories, read comments, view original articles, and share from the wrist.

[Unreleased]: https://github.com/GhostScientist/HackerPocket/compare/v3.0...HEAD
[3.0]: https://github.com/GhostScientist/HackerPocket/compare/a5fb1c1...v3.0
[2.0]: https://github.com/GhostScientist/HackerPocket/compare/b67ca9c...a5fb1c1
[1.1]: https://github.com/GhostScientist/HackerPocket/compare/20389a8...b67ca9c
[1.0]: https://github.com/GhostScientist/HackerPocket/commits/20389a8
