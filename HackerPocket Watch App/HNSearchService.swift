//
//  HNSearchService.swift
//  HackerPocket Watch App
//
//  Search, via Algolia. The Firebase API has no search endpoint at all.
//

import Foundation

/// A single Algolia hit.
///
/// This is a different API from Firebase with a different shape — most
/// importantly `objectID` is a *string*, and `title`/`url` are genuinely
/// nullable — so it decodes into its own type and is then mapped onto the
/// shared `StoryRow` used by the rest of the app.
private struct AlgoliaHit: Decodable {
    let objectID: String
    let title: String?
    let storyTitle: String?
    let points: Int?
    let numComments: Int?
    let url: String?
    let createdAt: Int?
    let author: String?
    let storyText: String?

    enum CodingKeys: String, CodingKey {
        case objectID
        case title
        case storyTitle = "story_title"
        case points
        case numComments = "num_comments"
        case url
        case createdAt = "created_at_i"
        case author
        case storyText = "story_text"
    }

    /// `nil` for hits we cannot render: an ID that isn't an HN item number, or
    /// no usable title. Skipping beats crashing or showing "(untitled)" rows.
    var storyRow: StoryRow? {
        guard let id = Int(objectID) else { return nil }
        let resolvedTitle = [title, storyTitle]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let resolvedTitle else { return nil }

        return StoryRow(
            id: id,
            title: resolvedTitle,
            score: points ?? 0,
            kids: [],
            descendants: numComments ?? 0,
            url: url,
            time: createdAt,
            by: author,
            text: storyText,
            type: "story"
        )
    }
}

private struct AlgoliaSearchResponse: Decodable {
    let hits: [AlgoliaHit]
}

/// Stateless wrapper around the Algolia HN search API.
final class HNSearchService {

    static let shared = HNSearchService()

    private static let searchURL = URL(string: "https://hn.algolia.com/api/v1/search")!

    /// One screenful is plenty on a watch, and Algolia relevance falls off a
    /// cliff well before this.
    private static let hitsPerPage = 30

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

    /// Story hits for `query`, in Algolia's relevance order. An empty or
    /// whitespace-only query returns no results rather than hitting the network.
    func stories(matching query: String) async throws -> [StoryRow] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(url: Self.searchURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "tags", value: "story"),
            URLQueryItem(name: "hitsPerPage", value: String(Self.hitsPerPage)),
        ]

        guard let url = components.url else { throw HNError.decodingFailed }

        do {
            let (data, response) = try await session.data(from: url)

            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw HNError.badStatus(http.statusCode)
            }

            let decoded = try JSONDecoder().decode(AlgoliaSearchResponse.self, from: data)
            return decoded.hits.compactMap(\.storyRow)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw HNError.from(error)
        }
    }
}
