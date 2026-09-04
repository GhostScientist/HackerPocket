//
//  StoryCache.swift
//  HackerPocket Watch App
//
//  On-disk cache so a cold launch renders before the network answers.
//

import Foundation

// MARK: - Snapshots

/// One feed's ranked IDs plus the rows we had actually loaded when we wrote it.
///
/// `loadedIDCount` is stored rather than inferred from `stories.count` because
/// the two disagree whenever an item in the window was deleted: the ID stays in
/// the ranking, the row does not exist.
struct FeedSnapshot: Codable {
    let feed: String
    let rankedIDs: [Int]
    let stories: [StoryRow]
    let loadedIDCount: Int
    let fetchedAt: Date
}

struct CommentSnapshot: Codable {
    let parentID: Int
    let rankedIDs: [Int]
    let comments: [Comment]
    let loadedIDCount: Int
    let fetchedAt: Date
}

struct StorySnapshot: Codable {
    let story: Story
    let fetchedAt: Date
}

// MARK: - Cache

/// JSON-on-disk cache for feeds, story details and comment threads.
///
/// An `actor` rather than a serial queue or a lock: every caller is already in
/// an async context, and this keeps encoding and file I/O in an isolation
/// domain that is definitively not the main actor. Nothing here is reachable
/// from two threads at once, which is the same property the async data layer
/// bought for networking.
///
/// Everything degrades to `nil` on failure. A cache that throws — or worse,
/// traps — on a truncated file is strictly worse than no cache, because the
/// failure mode is a crash loop on every launch rather than one slow fetch.
actor StoryCache {

    static let shared = StoryCache()

    /// Three pages. Enough that a relaunch restores a list the user had
    /// scrolled into, small enough that the whole feed decodes in one hop.
    static let maxStoriesPerFeed = 60

    /// Threads get deep, but nobody scrolls 200 comments on a watch.
    static let maxCommentsPerThread = 60

    /// HN's front page turns over several times a day, so anything older than
    /// this is not worth showing even offline.
    private static let maxAge: TimeInterval = 60 * 60 * 24 * 3

    /// Total on-disk budget. watchOS will purge the caches directory under
    /// storage pressure, but only once things are already bad, so we stay small
    /// on our own terms first.
    private static let byteBudget = 384 * 1024

    private let root: URL
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// `parent` exists so a test harness can point at a scratch directory
    /// instead of the real container.
    init(directoryName: String = "HNCache", parent: URL? = nil) {
        let base = parent
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        root = base.appendingPathComponent(directoryName, isDirectory: true)
    }

    // MARK: Feeds

    func feed(_ feed: Feed) -> FeedSnapshot? {
        let url = feedURL(feed)
        guard let snapshot = read(FeedSnapshot.self, at: url) else { return nil }

        // A snapshot whose payload disagrees with its filename is corrupt in a
        // way Codable cannot catch, and rendering New under the Top title is a
        // worse bug than a cache miss.
        guard snapshot.feed == feed.rawValue, isFresh(snapshot.fetchedAt) else {
            discard(url)
            return nil
        }
        return snapshot
    }

    func store(feed: Feed, rankedIDs: [Int], stories: [StoryRow], loadedIDCount: Int) {
        let cap = min(loadedIDCount, Self.maxStoriesPerFeed)
        let snapshot = FeedSnapshot(
            feed: feed.rawValue,
            rankedIDs: rankedIDs,
            stories: Array(stories.prefix(Self.maxStoriesPerFeed)),
            loadedIDCount: max(cap, 0),
            fetchedAt: Date()
        )
        write(snapshot, to: feedURL(feed))
    }

    // MARK: Story details

    func story(id: Int) -> Story? {
        let url = storyURL(id)
        guard let snapshot = read(StorySnapshot.self, at: url) else { return nil }
        guard snapshot.story.id == id, isFresh(snapshot.fetchedAt) else {
            discard(url)
            return nil
        }
        return snapshot.story
    }

    func store(story: Story) {
        write(StorySnapshot(story: story, fetchedAt: Date()), to: storyURL(story.id))
    }

    // MARK: Comments

    func comments(parentID: Int) -> CommentSnapshot? {
        let url = commentsURL(parentID)
        guard let snapshot = read(CommentSnapshot.self, at: url) else { return nil }
        guard snapshot.parentID == parentID, isFresh(snapshot.fetchedAt) else {
            discard(url)
            return nil
        }
        return snapshot
    }

    func store(parentID: Int, rankedIDs: [Int], comments: [Comment], loadedIDCount: Int) {
        let snapshot = CommentSnapshot(
            parentID: parentID,
            rankedIDs: rankedIDs,
            comments: Array(comments.prefix(Self.maxCommentsPerThread)),
            loadedIDCount: max(min(loadedIDCount, Self.maxCommentsPerThread), 0),
            fetchedAt: Date()
        )
        write(snapshot, to: commentsURL(parentID))
    }

    // MARK: Maintenance

    /// Drops expired entries, then evicts oldest-first until the cache fits the
    /// byte budget. Runs after every write, which is cheap because the eviction
    /// keeps the file count in the dozens.
    func prune() {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: Array(keys)) else {
            return
        }

        var entries: [(url: URL, modified: Date, size: Int)] = []
        var total = 0
        let cutoff = Date().addingTimeInterval(-Self.maxAge)

        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }

            let modified = values.contentModificationDate ?? .distantPast
            guard modified >= cutoff else {
                discard(url)
                continue
            }

            let size = values.fileSize ?? 0
            entries.append((url, modified, size))
            total += size
        }

        guard total > Self.byteBudget else { return }

        for entry in entries.sorted(by: { $0.modified < $1.modified }) {
            discard(entry.url)
            total -= entry.size
            if total <= Self.byteBudget { break }
        }
    }

    func removeAll() {
        try? fileManager.removeItem(at: root)
    }

    /// Bytes currently on disk. Only used to assert the budget holds.
    func currentSize() -> Int {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else { return 0 }

        var total = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += values.fileSize ?? 0
        }
        return total
    }

    // MARK: Internals

    private func feedURL(_ feed: Feed) -> URL {
        root.appendingPathComponent("feeds", isDirectory: true)
            .appendingPathComponent("\(feed.rawValue).json")
    }

    private func storyURL(_ id: Int) -> URL {
        root.appendingPathComponent("items", isDirectory: true)
            .appendingPathComponent("\(id).json")
    }

    private func commentsURL(_ parentID: Int) -> URL {
        root.appendingPathComponent("comments", isDirectory: true)
            .appendingPathComponent("\(parentID).json")
    }

    private func isFresh(_ date: Date) -> Bool {
        // A timestamp in the future means the clock moved, not that the entry
        // is eternally valid.
        let age = Date().timeIntervalSince(date)
        return age >= 0 && age < Self.maxAge
    }

    private func read<T: Decodable>(_ type: T.Type, at url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let value = try? decoder.decode(type, from: data) else {
            // Truncated, half-written, or written by an older schema. Delete it
            // so we stop paying for a guaranteed failure on every launch.
            discard(url)
            return nil
        }
        return value
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        do {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(value)
            // Atomic: being terminated mid-write should leave the previous
            // snapshot readable rather than a truncated file.
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
        prune()
    }

    private func discard(_ url: URL) {
        try? fileManager.removeItem(at: url)
    }
}
