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
        refresh()
    }

    func select(_ feed: Feed) {
        guard feed != self.feed else { return }
        self.feed = feed
        rankedIDs = []
        rowsByID = [:]
        loadedIDCount = 0
        stories = []
        lastUpdated = nil
        refresh()
    }

    func refresh() {
        activeTask?.cancel()
        generation &+= 1
        let generation = generation
        let feed = feed
        // Set synchronously: the task body doesn't run until the next main-actor
        // hop, and one frame of "no stories" before the spinner looks like a bug.
        isLoading = !hasContent
        isRevalidating = hasContent
        activeTask = Task { [weak self] in
            await self?.performRefresh(feed: feed, generation: generation)
        }
    }

    func loadMore() {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        let generation = generation
        activeTask = Task { [weak self] in
            await self?.performLoadMore(generation: generation)
        }
    }

    private func performRefresh(feed: Feed, generation: Int) async {
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

    func loadIfNeeded(id: Int) {
        guard story == nil, !isLoading else { return }
        load(id: id)
    }

    func load(id: Int) {
        activeTask?.cancel()
        isLoading = story == nil
        activeTask = Task { [weak self] in
            await self?.performLoad(id: id)
        }
    }

    private func performLoad(id: Int) async {
        error = nil

        if story == nil, let cached = await cache.story(id: id) {
            story = cached
            isLoading = false
        }

        do {
            let fresh = try await service.story(id: id)
            try Task.checkCancellation()
            story = fresh
            await cache.store(story: fresh)
        } catch is CancellationError {
            return
        } catch {
            // A cached copy beats an error screen; only surface the failure
            // when there is genuinely nothing to show.
            if story == nil {
                self.error = HNError.from(error)
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

    /// The story or comment these replies hang off. Used as the cache key —
    /// `CommentsView` recurses for threads, so `storyId` alone would make every
    /// depth collide.
    private var parentID = 0

    private var activeTask: Task<Void, Never>?

    init(service: HNService = .shared, cache: StoryCache = .shared) {
        self.service = service
        self.cache = cache
    }

    var canLoadMore: Bool {
        loadedIDCount < rankedIDs.count
    }

    var remainingCount: Int {
        max(rankedIDs.count - loadedIDCount, 0)
    }

    func loadIfNeeded(ids: [Int], parentID: Int) {
        guard rankedIDs.isEmpty, !isLoading else { return }
        load(ids: ids, parentID: parentID)
    }

    func load(ids: [Int], parentID: Int) {
        activeTask?.cancel()
        rankedIDs = ids
        commentsByID = [:]
        loadedIDCount = 0
        comments = []
        self.parentID = parentID
        activeTask = Task { [weak self] in
            await self?.performInitialLoad()
        }
    }

    func loadMore() {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        activeTask = Task { [weak self] in
            await self?.performLoadPage(isInitial: false)
        }
    }

    private func performInitialLoad() async {
        isLoading = true
        isLoadingMore = false
        error = nil

        // Unlike stories, a cached thread is not revalidated. Comment text is
        // immutable once posted; what changes is the `kids` array, and that
        // arrives fresh with the story, so a matching `rankedIDs` means the
        // cached page is still exactly right.
        if let snapshot = await cache.comments(parentID: parentID),
           snapshot.rankedIDs == rankedIDs,
           snapshot.loadedIDCount > 0 {
            commentsByID = Dictionary(
                snapshot.comments.map { ($0.id, $0) },
                uniquingKeysWith: { _, latest in latest }
            )
            loadedIDCount = min(snapshot.loadedIDCount, rankedIDs.count)
            publishComments()
            isLoading = false
            return
        }

        await performLoadPage(isInitial: true)
    }

    private func performLoadPage(isInitial: Bool) async {
        if isInitial {
            isLoading = true
            isLoadingMore = false
            error = nil
        } else {
            isLoadingMore = true
        }

        let upperBound = min(loadedIDCount + pageSize, rankedIDs.count)
        let nextPage = Array(rankedIDs[loadedIDCount..<upperBound])

        do {
            let page = try await service.comments(ids: nextPage)
            try Task.checkCancellation()

            for comment in page { commentsByID[comment.id] = comment }
            loadedIDCount = upperBound
            publishComments()
            error = nil

            await cache.store(
                parentID: parentID,
                rankedIDs: rankedIDs,
                comments: comments,
                loadedIDCount: loadedIDCount
            )
        } catch is CancellationError {
            return
        } catch {
            self.error = HNError.from(error)
        }

        isLoading = false
        isLoadingMore = false
    }

    private func publishComments() {
        let window = rankedIDs.prefix(loadedIDCount)
        comments = window.compactMap { commentsByID[$0] }
    }
}
