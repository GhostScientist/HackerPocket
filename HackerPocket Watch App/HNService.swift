//
//  HNService.swift
//  HackerPocket Watch App
//
//  Async networking layer for the Hacker News Firebase API.
//

import Foundation

// MARK: - Errors

enum HNError: Error, LocalizedError, Equatable {
    case offline
    case timedOut
    case badStatus(Int)
    case decodingFailed
    case notFound
    case transport(String)

    /// Full sentence, used where there is room to breathe.
    var errorDescription: String? {
        switch self {
        case .offline:
            return "No internet connection."
        case .timedOut:
            return "The request timed out."
        case .badStatus(let code):
            return "Hacker News returned an error (\(code))."
        case .decodingFailed:
            return "Couldn't read the response from Hacker News."
        case .notFound:
            return "This item is no longer available."
        case .transport(let message):
            return message
        }
    }

    /// Terse variant that fits a 41mm screen without wrapping four times.
    var shortDescription: String {
        switch self {
        case .offline: return "Offline"
        case .timedOut: return "Timed out"
        case .badStatus: return "Server error"
        case .decodingFailed: return "Bad response"
        case .notFound: return "Not found"
        case .transport: return "Connection failed"
        }
    }

    var symbolName: String {
        switch self {
        case .offline: return "wifi.slash"
        case .timedOut: return "clock.badge.exclamationmark"
        case .notFound: return "questionmark.circle"
        default: return "exclamationmark.triangle"
        }
    }

    /// Retrying a missing item will never succeed; everything else might.
    var isRetryable: Bool {
        self != .notFound
    }

    /// Normalizes anything thrown by URLSession or JSONDecoder into an `HNError`.
    /// Cancellation is deliberately *not* handled here — callers must let it propagate.
    static func from(_ error: Error) -> HNError {
        if let hnError = error as? HNError {
            return hnError
        }
        if error is DecodingError {
            return .decodingFailed
        }
        guard let urlError = error as? URLError else {
            return .transport(error.localizedDescription)
        }
        switch urlError.code {
        case .notConnectedToInternet, .dataNotAllowed, .networkConnectionLost, .cannotConnectToHost:
            return .offline
        case .timedOut:
            return .timedOut
        default:
            return .transport(urlError.localizedDescription)
        }
    }
}

// MARK: - Service

/// Stateless wrapper around the HN Firebase API.
///
/// Every batch operation preserves the order of the IDs it was given. HN's
/// `topstories` and `kids` arrays *are* the ranking, so returning results in
/// completion order (as the previous implementation did) silently scrambled it.
final class HNService {

    static let shared = HNService()

    private static let baseURL = URL(string: "https://hacker-news.firebaseio.com/v0/")!

    /// The watch radio does not enjoy 30 simultaneous connections. Batch
    /// requests run through a sliding window instead of all at once.
    private static let maxConcurrentRequests = 6

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 30
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }
    }

    // MARK: Public API

    /// Ranked IDs for a feed. Lengths vary wildly — `top` returns up to 500,
    /// `jobs` often fewer than 30 — so callers must not assume a count.
    func storyIDs(for feed: Feed) async throws -> [Int] {
        try await fetch([Int].self, path: feed.path) ?? []
    }

    func story(id: Int) async throws -> Story {
        guard let story = try await fetch(Story.self, path: "item/\(id).json") else {
            throw HNError.notFound
        }
        return story
    }

    /// List rows for the given IDs, in the same order as `ids`.
    /// Individual items that are deleted or fail to load are skipped rather
    /// than failing the whole batch.
    func stories(ids: [Int]) async throws -> [StoryRow] {
        try await orderedFetch(ids) { [weak self] id in
            try await self?.fetch(StoryRow.self, path: "item/\(id).json")
        }
    }

    /// Comments for the given IDs, in the same order as `ids` — which for HN
    /// `kids` arrays is the site's own ranking. Deleted and dead comments are
    /// filtered out.
    func comments(ids: [Int]) async throws -> [Comment] {
        let fetched: [Comment] = try await orderedFetch(ids) { [weak self] id in
            try await self?.fetch(Comment.self, path: "item/\(id).json")
        }
        return fetched.filter { !$0.isHidden }
    }

    // MARK: Internals

    private func fetch<T: Decodable>(_ type: T.Type, path: String) async throws -> T? {
        let url = Self.baseURL.appendingPathComponent(path)
        do {
            let (data, response) = try await session.data(from: url)

            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw HNError.badStatus(http.statusCode)
            }

            // Firebase answers with a literal `null` for deleted or unknown IDs.
            guard !Self.isJSONNull(data) else { return nil }

            return try JSONDecoder().decode(T.self, from: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw HNError.from(error)
        }
    }

    private static func isJSONNull(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8) else { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines) == "null"
    }

    /// Runs `load` across `ids` with bounded concurrency and reassembles the
    /// results in the original ID order.
    ///
    /// Per-item failures are tolerated. If *every* item failed with an error,
    /// the first error is rethrown so the caller can show a real error state
    /// instead of an empty list.
    private func orderedFetch<T>(
        _ ids: [Int],
        _ load: @escaping (Int) async throws -> T?
    ) async throws -> [T] {
        guard !ids.isEmpty else { return [] }

        var values: [Int: T] = [:]
        values.reserveCapacity(ids.count)
        var firstError: HNError?
        var failureCount = 0

        try await withThrowingTaskGroup(of: (Int, Result<T?, HNError>).self) { group in
            var nextIndex = 0

            func addTask(at index: Int) {
                let id = ids[index]
                group.addTask {
                    do {
                        return (index, .success(try await load(id)))
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        return (index, .failure(HNError.from(error)))
                    }
                }
            }

            while nextIndex < min(Self.maxConcurrentRequests, ids.count) {
                addTask(at: nextIndex)
                nextIndex += 1
            }

            while let (index, result) = try await group.next() {
                switch result {
                case .success(let value):
                    if let value { values[index] = value }
                case .failure(let error):
                    failureCount += 1
                    if firstError == nil { firstError = error }
                }

                if nextIndex < ids.count {
                    addTask(at: nextIndex)
                    nextIndex += 1
                }
            }
        }

        try Task.checkCancellation()

        if values.isEmpty, failureCount == ids.count, let firstError {
            throw firstError
        }

        return ids.indices.compactMap { values[$0] }
    }
}
