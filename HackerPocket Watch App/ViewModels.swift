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

    private let service: HNService
    private let pageSize = 20

    private var rankedIDs: [Int] = []
    private var loadedIDCount = 0
    private var activeTask: Task<Void, Never>?

    init(service: HNService = .shared) {
        self.service = service
    }

    var canLoadMore: Bool {
        loadedIDCount < rankedIDs.count
    }

    var hasContent: Bool {
        !stories.isEmpty
    }

    func loadIfNeeded() {
        guard stories.isEmpty, !isLoading else { return }
        refresh()
    }

    func refresh() {
        activeTask?.cancel()
        activeTask = Task { [weak self] in
            await self?.performRefresh()
        }
    }

    func loadMore() {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        activeTask = Task { [weak self] in
            await self?.performLoadMore()
        }
    }

    private func performRefresh() async {
        isLoading = true
        // A refresh cancels any in-flight pagination, so clear its spinner too —
        // the cancelled task bails out before it can reset this itself.
        isLoadingMore = false
        error = nil

        do {
            let ids = try await service.topStoryIDs()
            try Task.checkCancellation()

            let firstPage = Array(ids.prefix(pageSize))
            let page = try await service.stories(ids: firstPage)
            try Task.checkCancellation()

            rankedIDs = ids
            loadedIDCount = firstPage.count
            stories = page
            error = nil
        } catch is CancellationError {
            // A newer request superseded this one; leave state to the winner.
            return
        } catch {
            // Keep whatever is already on screen and report alongside it.
            self.error = HNError.from(error)
        }

        isLoading = false
    }

    private func performLoadMore() async {
        isLoadingMore = true

        let upperBound = min(loadedIDCount + pageSize, rankedIDs.count)
        let nextPage = Array(rankedIDs[loadedIDCount..<upperBound])

        do {
            let page = try await service.stories(ids: nextPage)
            try Task.checkCancellation()

            loadedIDCount = upperBound
            stories.append(contentsOf: page)
            error = nil
        } catch is CancellationError {
            return
        } catch {
            self.error = HNError.from(error)
        }

        isLoadingMore = false
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
