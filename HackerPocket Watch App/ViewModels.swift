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

    private let service: HNService
    private let pageSize = 20

    private var rankedIDs: [Int] = []
    private var loadedIDCount = 0
    private var activeTask: Task<Void, Never>?

    /// Bumped every time the feed changes or a refresh starts. A task that
    /// finishes holding a stale generation throws its results away.
    ///
    /// Cancellation alone is not a guarantee here: a request can complete on
    /// the wire before `cancel()` lands, and we'd rather drop the old feed's
    /// stories than briefly render them under the new feed's title.
    private var generation = 0

    init(service: HNService = .shared) {
        self.service = service
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
        loadedIDCount = 0
        stories = []
        refresh()
    }

    func refresh() {
        activeTask?.cancel()
        generation &+= 1
        let generation = generation
        let feed = feed
        // Set synchronously: the task body doesn't run until the next main-actor
        // hop, and one frame of "no stories" before the spinner looks like a bug.
        isLoading = true
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
        isLoading = true
        // A refresh cancels any in-flight pagination, so clear its spinner too —
        // the cancelled task bails out before it can reset this itself.
        isLoadingMore = false
        error = nil

        do {
            let ids = try await service.storyIDs(for: feed)
            try Task.checkCancellation()
            guard generation == self.generation else { return }

            let firstPage = Array(ids.prefix(pageSize))
            let page = try await service.stories(ids: firstPage)
            try Task.checkCancellation()
            guard generation == self.generation else { return }

            rankedIDs = ids
            loadedIDCount = firstPage.count
            stories = page
            error = nil
        } catch is CancellationError {
            // A newer request superseded this one; leave state to the winner.
            return
        } catch {
            guard generation == self.generation else { return }
            // Keep whatever is already on screen and report alongside it.
            self.error = HNError.from(error)
        }

        isLoading = false
    }

    private func performLoadMore(generation: Int) async {
        isLoadingMore = true

        let upperBound = min(loadedIDCount + pageSize, rankedIDs.count)
        let nextPage = Array(rankedIDs[loadedIDCount..<upperBound])

        do {
            let page = try await service.stories(ids: nextPage)
            try Task.checkCancellation()
            guard generation == self.generation else { return }

            loadedIDCount = upperBound
            stories.append(contentsOf: page)
            error = nil
        } catch is CancellationError {
            return
        } catch {
            guard generation == self.generation else { return }
            self.error = HNError.from(error)
        }

        isLoadingMore = false
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
    private var activeTask: Task<Void, Never>?

    init(service: HNService = .shared) {
        self.service = service
    }

    func loadIfNeeded(id: Int) {
        guard story == nil, !isLoading else { return }
        load(id: id)
    }

    func load(id: Int) {
        activeTask?.cancel()
        activeTask = Task { [weak self] in
            await self?.performLoad(id: id)
        }
    }

    private func performLoad(id: Int) async {
        isLoading = true
        error = nil

        do {
            story = try await service.story(id: id)
        } catch is CancellationError {
            return
        } catch {
            self.error = HNError.from(error)
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
    private let pageSize = 20

    /// HN's `kids` array is already ranked, so this order is the order we render.
    private var rankedIDs: [Int] = []
    private var loadedIDCount = 0
    private var activeTask: Task<Void, Never>?

    init(service: HNService = .shared) {
        self.service = service
    }

    var canLoadMore: Bool {
        loadedIDCount < rankedIDs.count
    }

    var remainingCount: Int {
        max(rankedIDs.count - loadedIDCount, 0)
    }

    func loadIfNeeded(ids: [Int]) {
        guard rankedIDs.isEmpty, !isLoading else { return }
        load(ids: ids)
    }

    func load(ids: [Int]) {
        activeTask?.cancel()
        rankedIDs = ids
        loadedIDCount = 0
        comments = []
        activeTask = Task { [weak self] in
            await self?.performLoadPage(isInitial: true)
        }
    }

    func loadMore() {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        activeTask = Task { [weak self] in
            await self?.performLoadPage(isInitial: false)
        }
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

            loadedIDCount = upperBound
            comments.append(contentsOf: page)
            error = nil
        } catch is CancellationError {
            return
        } catch {
            self.error = HNError.from(error)
        }

        isLoading = false
        isLoadingMore = false
    }
}
