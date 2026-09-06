//
//  ViewModels.swift
//  HackerPocket Watch App
//
//  Loading state + pagination for the story and comment screens.
//

import Foundation

// MARK: - Stories

@MainActor
final class StoriesViewModel: ObservableObject {

    @Published private(set) var stories: [StoryRow] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: HNError?
    @Published private(set) var feed: Feed = .top

    /// When the rows on screen were fetched. Non-nil from the moment cached
    /// content is restored, which is what lets the UI say how old it is.
    @Published private(set) var lastUpdated: Date?

    /// A network refresh running behind content that is already on screen.
    /// Distinct from `isLoading`, which means "there is nothing to show yet".
    @Published private(set) var isRevalidating = false

    private let service: HNService
    private let cache: StoryCache
    private let pageSize = 20

    private var rankedIDs: [Int] = []

    /// Rows are held by ID and the visible list is derived from
    /// `rankedIDs.prefix(loadedIDCount)`. Revalidation then updates rows in
    /// place instead of assigning a whole new array, so a user who has paged
    /// three deep doesn't get snapped back to twenty rows when a refresh lands.
    private var rowsByID: [Int: StoryRow] = [:]

    private var loadedIDCount = 0
    private var activeTask: Task<Void, Never>?

    /// Bumped every time the feed changes or a refresh starts. A task that
    /// finishes holding a stale generation throws its results away.
    ///
    /// Cancellation alone is not a guarantee here: a request can complete on
    /// the wire before `cancel()` lands, and we'd rather drop the old feed's
    /// stories than briefly render them under the new feed's title.
    private var generation = 0

    init(service: HNService = .shared, cache: StoryCache = .shared) {
        self.service = service
        self.cache = cache
    }

    var canLoadMore: Bool {
        loadedIDCount < rankedIDs.count
    }

    var hasContent: Bool {
        !stories.isEmpty
    }

    func loadIfNeeded(feed: Feed) {
        guard stories.isEmpty, !isLoading else { return }
        self.feed = feed
        refresh(haptic: false)
    }

    func select(_ feed: Feed) {
        guard feed != self.feed else { return }
        self.feed = feed
        rankedIDs = []
        rowsByID = [:]
        loadedIDCount = 0
        stories = []
        lastUpdated = nil
        refresh(haptic: false)
    }

    func refresh() {
        refresh(haptic: true)
    }

    private func refresh(haptic: Bool) {
        activeTask?.cancel()
        generation &+= 1
        let generation = generation
        let feed = feed
        // Set synchronously: the task body doesn't run until the next main-actor
        // hop, and one frame of "no stories" before the spinner looks like a bug.
        isLoading = !hasContent
        isRevalidating = hasContent
        activeTask = Task { [weak self] in
            await self?.performRefresh(feed: feed, generation: generation, haptic: haptic)
        }
    }

    func loadMore() {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        let generation = generation
        activeTask = Task { [weak self] in
            await self?.performLoadMore(generation: generation)
        }
    }

    private func performRefresh(feed: Feed, generation: Int, haptic: Bool) async {
        // A refresh cancels any in-flight pagination, so clear its spinner too —
        // the cancelled task bails out before it can reset this itself.
        isLoadingMore = false
        error = nil

        // Cached content first. On a cold launch this lands an actor hop in,
        // long before the network answers, and it is the whole reason the app
        // no longer opens on a spinner every single time.
        if !hasContent, let snapshot = await cache.feed(feed) {
            guard generation == self.generation else { return }
            apply(snapshot)
            isLoading = false
            isRevalidating = true
        }

        do {
            let ids = try await service.storyIDs(for: feed)
            try Task.checkCancellation()
            guard generation == self.generation else { return }

            // Revalidate as much as the user currently has, never less than a
            // page, so a refresh doesn't truncate a list they scrolled into.
            let target = min(max(loadedIDCount, pageSize), ids.count)
            let window = Array(ids.prefix(target))

            // The first page is always refetched so scores and comment counts
            // stay honest. Deeper entries are only fetched where the cache (or
            // a change in ranking) left a hole, which keeps a warm launch at
            // roughly twenty requests instead of sixty.
            let needed = window.enumerated()
                .filter { $0.offset < pageSize || rowsByID[$0.element] == nil }
                .map(\.element)

            let fetched = try await service.stories(ids: needed)
            try Task.checkCancellation()
            guard generation == self.generation else { return }

            for row in fetched { rowsByID[row.id] = row }
            rankedIDs = ids
            loadedIDCount = target
            publishStories()
            lastUpdated = Date()
            error = nil
            if haptic {
                WatchHaptics.success()
            }

            // Arguments are evaluated before the suspension, so a feed switch
            // landing mid-write can't file this feed's rows under another key.
            await cache.store(feed: feed, rankedIDs: ids, stories: stories, loadedIDCount: target)
            ComplicationUpdater.reload()
        } catch is CancellationError {
            // A newer request superseded this one; leave state to the winner.
            return
        } catch {
            guard generation == self.generation else { return }
            // Keep whatever is already on screen and report alongside it.
            self.error = HNError.from(error)
            if haptic {
                WatchHaptics.failure()
            }
        }

        isLoading = false
        isRevalidating = false
    }

    private func performLoadMore(generation: Int) async {
        isLoadingMore = true

        let upperBound = min(loadedIDCount + pageSize, rankedIDs.count)
        let nextPage = Array(rankedIDs[loadedIDCount..<upperBound])
        let feed = feed

        do {
            let page = try await service.stories(ids: nextPage)
            try Task.checkCancellation()
            guard generation == self.generation else { return }

            for row in page { rowsByID[row.id] = row }
            loadedIDCount = upperBound
            publishStories()
            error = nil

            await cache.store(
                feed: feed,
                rankedIDs: rankedIDs,
                stories: stories,
                loadedIDCount: upperBound
            )
        } catch is CancellationError {
            return
        } catch {
            guard generation == self.generation else { return }
            self.error = HNError.from(error)
        }

        isLoadingMore = false
    }

    private func apply(_ snapshot: FeedSnapshot) {
        rankedIDs = snapshot.rankedIDs
        rowsByID = Dictionary(snapshot.stories.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        loadedIDCount = min(snapshot.loadedIDCount, snapshot.rankedIDs.count)
        lastUpdated = snapshot.fetchedAt
        publishStories()
    }

    private func publishStories() {
        let window = rankedIDs.prefix(loadedIDCount)
        stories = window.compactMap { rowsByID[$0] }

        // Re-ranking pushes IDs out of the loaded window; drop their rows so the
        // map doesn't accumulate a day's worth of front page behind the list.
        let live = Set(window)
        rowsByID = rowsByID.filter { live.contains($0.key) }
    }
}

// MARK: - Search

@MainActor
final class SearchViewModel: ObservableObject {

    @Published private(set) var results: [StoryRow] = []
    @Published private(set) var isSearching = false
    @Published private(set) var error: HNError?
    @Published private(set) var recentSearches: [String] = []

    /// The query behind whatever is currently on screen. `nil` until the first
    /// search completes, which is what separates "no results" from "not asked yet".
    @Published private(set) var completedQuery: String?

    private let service: HNSearchService
    private var activeTask: Task<Void, Never>?

    private static let recentSearchesKey = "recentSearches"
    private static let maxRecentSearches = 5

    init(service: HNSearchService = .shared) {
        self.service = service
        recentSearches = UserDefaults.standard.stringArray(forKey: Self.recentSearchesKey) ?? []
    }

    func search(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        activeTask?.cancel()
        isSearching = true
        activeTask = Task { [weak self] in
            await self?.performSearch(trimmed)
        }
    }

    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: Self.recentSearchesKey)
    }

    private func performSearch(_ query: String) async {
        isSearching = true
        error = nil

        do {
            let hits = try await service.stories(matching: query)
            try Task.checkCancellation()

            results = hits
            completedQuery = query
            error = nil
            rememberSearch(query)
        } catch is CancellationError {
            return
        } catch {
            results = []
            completedQuery = query
            self.error = HNError.from(error)
        }

        isSearching = false
    }

    /// Typing on a watch is expensive, so successful queries are kept for reuse.
    private func rememberSearch(_ query: String) {
        var updated = recentSearches.filter { $0.caseInsensitiveCompare(query) != .orderedSame }
        updated.insert(query, at: 0)
        recentSearches = Array(updated.prefix(Self.maxRecentSearches))
        UserDefaults.standard.set(recentSearches, forKey: Self.recentSearchesKey)
    }
}

// MARK: - Story detail

@MainActor
final class StoryDetailViewModel: ObservableObject {

    @Published private(set) var story: Story?
    @Published private(set) var isLoading = false
    @Published private(set) var error: HNError?

    private let service: HNService
    private let cache: StoryCache
    private var activeTask: Task<Void, Never>?

    init(service: HNService = .shared, cache: StoryCache = .shared) {
        self.service = service
        self.cache = cache
    }

    func loadIfNeeded(id: Int, fallback: Story? = nil) {
        guard story == nil, !isLoading else { return }
        load(id: id, fallback: fallback, haptic: false)
    }

    func load(id: Int, fallback: Story? = nil, haptic: Bool = true) {
        activeTask?.cancel()
        isLoading = story == nil
        activeTask = Task { [weak self] in
            await self?.performLoad(id: id, fallback: fallback, haptic: haptic)
        }
    }

    private func performLoad(id: Int, fallback: Story?, haptic: Bool) async {
        error = nil

        if story == nil {
            story = await cache.story(id: id) ?? fallback
            isLoading = false
        }

        do {
            let fresh = try await service.story(id: id)
            try Task.checkCancellation()
            story = fresh
            await cache.store(story: fresh)
            if haptic {
                WatchHaptics.success()
            }
        } catch is CancellationError {
            return
        } catch {
            // A cached copy beats an error screen; only surface the failure
            // when there is genuinely nothing to show.
            if story == nil {
                self.error = HNError.from(error)
            }
            if haptic {
                WatchHaptics.failure()
            }
        }

        isLoading = false
    }
}

// MARK: - Comments

@MainActor
final class CommentsViewModel: ObservableObject {

    @Published private(set) var comments: [Comment] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: HNError?
    @Published private(set) var scrollID: Int?
    @Published private(set) var positionMessage: String?
    @Published private(set) var needsPositionRetry = false

    private let service: HNService
    private let cache: StoryCache
    private let pageSize = 20

    /// HN's `kids` array is already ranked, so this order is the order we render.
    private var rankedIDs: [Int] = []

    /// Same derived-list trick as `StoriesViewModel`: hold comments by ID and
    /// project the visible list through `rankedIDs`, so deleted and dead items
    /// simply drop out of the window instead of shifting everything under them.
    private var commentsByID: [Int: Comment] = [:]

    private var loadedIDCount = 0
    private var firstLoadedIndex = 0

    /// The story or comment these replies hang off. Used as the cache key —
    /// `CommentsView` recurses for threads, so `storyId` alone would make every
    /// depth collide.
    private var parentID = 0

    private var activeTask: Task<Void, Never>?
    private var generation = 0
    private var hasLoaded = false
    private var retryEarlier = false
    private var initialLoadFailed = false

    private struct ReadingPosition: Codable {
        let commentID: Int
        let index: Int
        let updatedAt: Date
    }

    private static let positionsKey = "discussionReadingPositions"
    private let defaults: UserDefaults
    private var savedPosition: ReadingPosition?

    init(service: HNService = .shared, cache: StoryCache = .shared, defaults: UserDefaults = .standard) {
        self.service = service
        self.cache = cache
        self.defaults = defaults
    }

    var canLoadMore: Bool {
        loadedIDCount < rankedIDs.count
    }

    var remainingCount: Int {
        max(rankedIDs.count - loadedIDCount, 0)
    }

    var canLoadEarlier: Bool { firstLoadedIndex > 0 }

    func loadIfNeeded(ids: [Int], parentID: Int) {
        guard !hasLoaded, !isLoading else { return }
        load(ids: ids, parentID: parentID)
    }

    func load(ids: [Int], parentID: Int) {
        activeTask?.cancel()
        generation &+= 1
        let generation = generation
        rankedIDs = ids
        commentsByID = [:]
        loadedIDCount = 0
        firstLoadedIndex = 0
        comments = []
        self.parentID = parentID
        savedPosition = positions()[String(parentID)]
        scrollID = nil
        positionMessage = nil
        needsPositionRetry = false
        initialLoadFailed = false
        error = nil
        isLoading = true
        isLoadingMore = false
        hasLoaded = true
        activeTask = Task { [weak self] in
            await self?.performInitialLoad(generation: generation)
        }
    }

    func loadMore() {
        loadPage(earlier: false)
    }

    func loadEarlier() {
        loadPage(earlier: true)
    }

    func retry() {
        if initialLoadFailed || needsPositionRetry || comments.isEmpty && loadedIDCount == 0 {
            load(ids: rankedIDs, parentID: parentID)
        } else {
            loadPage(earlier: retryEarlier)
        }
    }

    func updatePosition(_ id: Int?) {
        guard !isLoading, let id,
              id == parentID || comments.contains(where: { $0.id == id }) else { return }
        scrollID = id
        // An offline fallback must not erase the deep bookmark being retried.
        guard !needsPositionRetry else { return }
        let index = rankedIDs.firstIndex(of: id) ?? -1
        guard savedPosition?.commentID != id || savedPosition?.index != index else { return }
        savedPosition = ReadingPosition(commentID: id, index: index, updatedAt: Date())
        var stored = positions()
        stored[String(parentID)] = savedPosition
        let recent = stored.sorted { $0.value.updatedAt > $1.value.updatedAt }.prefix(40)
        if let data = try? JSONEncoder().encode(Dictionary(uniqueKeysWithValues: recent.map { ($0.key, $0.value) })) {
            defaults.set(data, forKey: Self.positionsKey)
        }
    }

    func readFromHere() {
        needsPositionRetry = false
        initialLoadFailed = false
        positionMessage = nil
        error = nil
        updatePosition(scrollID ?? comments.first?.id)
    }

    private func positions() -> [String: ReadingPosition] {
        guard let data = defaults.data(forKey: Self.positionsKey),
              let stored = try? JSONDecoder().decode([String: ReadingPosition].self, from: data) else { return [:] }
        return stored
    }

    private func loadPage(earlier: Bool) {
        guard (earlier ? canLoadEarlier : canLoadMore),
              !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        retryEarlier = earlier
        let generation = generation
        let lower = earlier ? max(firstLoadedIndex - pageSize, 0) : loadedIDCount
        let upper = earlier ? firstLoadedIndex : min(loadedIDCount + pageSize, rankedIDs.count)
        activeTask = Task { [weak self] in
            await self?.performLoadPage(lower: lower, upper: upper, generation: generation)
        }
    }

    private func performInitialLoad(generation: Int) async {
        let snapshot = await cache.comments(parentID: parentID)
        guard generation == self.generation, !Task.isCancelled else { return }
        if let snapshot {
            // Reuse cached rows even if replies were added or reordered. Only a
            // contiguous, known prefix counts as loaded for subsequent paging.
            let live = Set(rankedIDs)
            commentsByID = Dictionary(
                snapshot.comments.filter { live.contains($0.id) && !$0.isHidden }.map { ($0.id, $0) },
                uniquingKeysWith: { _, latest in latest }
            )
            if snapshot.rankedIDs == rankedIDs {
                loadedIDCount = max(0, min(snapshot.loadedIDCount, rankedIDs.count))
            } else {
                loadedIDCount = rankedIDs.prefix(while: { commentsByID[$0] != nil }).count
            }
        }

        let targetIndex: Int
        if let savedPosition, savedPosition.commentID != parentID, !rankedIDs.isEmpty {
            targetIndex = rankedIDs.firstIndex(of: savedPosition.commentID)
                ?? min(max(savedPosition.index, 0), rankedIDs.count - 1)
        } else {
            targetIndex = 0
        }

        var fetchedPage = false
        let missingSavedComment = savedPosition.map {
            $0.commentID != parentID && rankedIDs.contains($0.commentID)
                && commentsByID[$0.commentID] == nil
        } ?? false
        // Jump directly to ONE page near the bookmark, never fetch every page
        // between the capped disk cache and a deeply nested reading position.
        if loadedIDCount == 0 || targetIndex >= loadedIDCount || missingSavedComment {
            let lower = targetIndex / pageSize * pageSize
            let upper = min(lower + pageSize, rankedIDs.count)
            do {
                var page = try await service.comments(ids: Array(rankedIDs[lower..<upper]))
                try Task.checkCancellation()
                guard generation == self.generation else { return }
                if let savedPosition,
                   rankedIDs[lower..<upper].contains(savedPosition.commentID),
                   !page.contains(where: { $0.id == savedPosition.commentID }) {
                    // Batches tolerate individual failures. A single-item
                    // request distinguishes transport errors from hidden/null.
                    page += try await service.comments(ids: [savedPosition.commentID])
                }
                try Task.checkCancellation()
                guard generation == self.generation else { return }
                for id in rankedIDs[lower..<upper] { commentsByID[id] = nil }
                for comment in page { commentsByID[comment.id] = comment }
                firstLoadedIndex = lower
                loadedIDCount = upper
                fetchedPage = true
            } catch {
                guard generation == self.generation, !Task.isCancelled else { return }
                initialLoadFailed = true
                self.error = HNError.from(error)
                needsPositionRetry = savedPosition != nil
                if needsPositionRetry {
                    positionMessage = "Saved position unavailable. Retry when online, or read from here."
                }
                // A reordered thread may have a cached bookmark outside its
                // known prefix. Prefer its contiguous window while offline.
                if let savedPosition, commentsByID[savedPosition.commentID] != nil,
                   let index = rankedIDs.firstIndex(of: savedPosition.commentID) {
                    firstLoadedIndex = index
                    while firstLoadedIndex > 0 && commentsByID[rankedIDs[firstLoadedIndex - 1]] != nil {
                        firstLoadedIndex -= 1
                    }
                    loadedIDCount = index + 1
                    while loadedIDCount < rankedIDs.count && commentsByID[rankedIDs[loadedIDCount]] != nil {
                        loadedIDCount += 1
                    }
                    positionMessage = "Showing cached saved comment. Retry when online, or read from here."
                } else if loadedIDCount == 0,
                   let first = rankedIDs.firstIndex(where: { commentsByID[$0] != nil }) {
                    firstLoadedIndex = first
                    loadedIDCount = first + rankedIDs[first...].prefix(while: { commentsByID[$0] != nil }).count
                }
            }
        }
        publishComments()
        if savedPosition?.commentID == parentID {
            scrollID = parentID
        } else if let savedPosition {
            scrollID = comments.first(where: { $0.id == savedPosition.commentID })?.id
                ?? (firstLoadedIndex..<loadedIDCount)
                    .filter { commentsByID[rankedIDs[$0]] != nil }
                    .min(by: { abs($0 - targetIndex) < abs($1 - targetIndex) })
                    .map { rankedIDs[$0] }
            if scrollID != savedPosition.commentID && !needsPositionRetry {
                positionMessage = comments.isEmpty
                    ? "Saved comment unavailable. No readable comments here."
                    : "Saved comment unavailable. Showing nearby comments."
            }
        }
        isLoading = false
        if fetchedPage {
            await storeLoadedPrefix()
        }
    }

    private func performLoadPage(lower: Int, upper: Int, generation: Int) async {
        do {
            let page = try await service.comments(ids: Array(rankedIDs[lower..<upper]))
            try Task.checkCancellation()
            guard generation == self.generation else { return }
            for id in rankedIDs[lower..<upper] { commentsByID[id] = nil }
            for comment in page { commentsByID[comment.id] = comment }
            firstLoadedIndex = min(firstLoadedIndex, lower)
            loadedIDCount = max(loadedIDCount, upper)
            publishComments()
            error = nil
            initialLoadFailed = false
            await storeLoadedPrefix()
        } catch is CancellationError {
            return
        } catch {
            guard generation == self.generation else { return }
            self.error = HNError.from(error)
            WatchHaptics.failure()
        }
        guard generation == self.generation else { return }
        isLoadingMore = false
    }

    private func storeLoadedPrefix() async {
        // StoryCache's format describes a prefix, not a window. Never mark an
        // unfetched gap as loaded, or overwrite useful offline data with it.
        guard firstLoadedIndex == 0, loadedIDCount > 0 else { return }
        await cache.store(parentID: parentID, rankedIDs: rankedIDs,
                          comments: comments, loadedIDCount: loadedIDCount)
    }

    private func publishComments() {
        let window = rankedIDs[firstLoadedIndex..<loadedIDCount]
        comments = window.compactMap { commentsByID[$0] }
    }
}
