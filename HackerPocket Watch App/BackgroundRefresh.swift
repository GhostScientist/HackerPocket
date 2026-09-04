//
//  BackgroundRefresh.swift
//  HackerPocket Watch App
//
//  Keeps the cache (and the complication) warm between launches.
//

import Foundation
import WatchKit
import WidgetKit

// MARK: - Refresh

enum BackgroundRefresh {

    /// watchOS budgets background refreshes to a handful an hour and quietly
    /// stretches anything more eager, so ask for what we can actually get.
    private static let interval: TimeInterval = 30 * 60

    private static let pageSize = 20

    static func schedule() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(interval),
            userInfo: nil
        ) { _ in }
    }

    /// Refreshes whichever feed the user last selected into the cache.
    ///
    /// Deliberately non-throwing: the caller is a background task that *must*
    /// be completed either way, and an error path that can skip the completion
    /// is how an app gets throttled out of background refresh entirely.
    static func refreshSelectedFeed(
        service: HNService = .shared,
        cache: StoryCache = .shared
    ) async -> Bool {
        let feed = selectedFeed()
        do {
            let ids = try await service.storyIDs(for: feed)
            let window = Array(ids.prefix(pageSize))
            let stories = try await service.stories(ids: window)
            await cache.store(
                feed: feed,
                rankedIDs: ids,
                stories: stories,
                loadedIDCount: window.count
            )
            return true
        } catch {
            return false
        }
    }

    /// Mirrors `ContentView`'s `@AppStorage("selectedFeed")`, which stores the
    /// raw value as a plain string.
    private static func selectedFeed() -> Feed {
        guard let raw = UserDefaults.standard.string(forKey: "selectedFeed"),
              let feed = Feed(rawValue: raw) else { return .top }
        return feed
    }
}

// MARK: - Complication

@MainActor
enum ComplicationUpdater {

    private static var lastReload: Date = .distantPast

    /// WidgetKit budgets timeline reloads per day. A user tapping the refresh
    /// button repeatedly should not spend that allowance in a minute, so
    /// foreground refreshes coalesce; background refreshes force through
    /// because they already only happen twice an hour.
    private static let minimumInterval: TimeInterval = 5 * 60

    static func reload(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastReload) >= minimumInterval else { return }
        lastReload = now
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Delegate

/// The app had no delegate before this; background tasks are only delivered
/// through one, so `HackerPocketApp` now installs it via
/// `@WKApplicationDelegateAdaptor`.
final class HackerPocketAppDelegate: NSObject, WKApplicationDelegate {

    func applicationDidFinishLaunching() {
        BackgroundRefresh.schedule()
    }

    func applicationDidEnterBackground() {
        BackgroundRefresh.schedule()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            guard let refresh = task as? WKApplicationRefreshBackgroundTask else {
                // Snapshot, URL-session and connectivity tasks still have to be
                // completed even though we do nothing with them.
                task.setTaskCompletedWithSnapshot(false)
                continue
            }

            // Reschedule before doing any work. If the refresh fails, or the
            // system expires the task out from under us, we still get a turn.
            BackgroundRefresh.schedule()

            Task { @MainActor in
                let refreshed = await BackgroundRefresh.refreshSelectedFeed()
                if refreshed {
                    ComplicationUpdater.reload(force: true)
                }
                refresh.setTaskCompletedWithSnapshot(refreshed)
            }
        }
    }
}
