//
//  StoryState.swift
//  HackerPocket Watch App
//
//  Actor-isolated persistence for local story actions.
//

import Foundation

struct SavedStory: Codable, Hashable, Identifiable {
    let row: StoryRow
    let savedAt: Date

    var id: Int { row.id }
}

struct StoryStateSnapshot: Codable {
    var votedIDs: Set<Int>
    var savedStories: [SavedStory]
    var readIDs: [Int]
}

actor LocalStoryState {

    static let shared = LocalStoryState()

    static let maxReadIDs = 500

    private let fileURL: URL
    private var snapshot: StoryStateSnapshot

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        self.snapshot = Self.load(from: self.fileURL)
    }

    func hasVoted(_ id: Int) -> Bool {
        snapshot.votedIDs.contains(id)
    }

    func markVoted(_ id: Int) {
        snapshot.votedIDs.insert(id)
        persist()
    }

    func unmarkVoted(_ id: Int) {
        snapshot.votedIDs.remove(id)
        persist()
    }

    func isSaved(_ id: Int) -> Bool {
        snapshot.savedStories.contains { $0.id == id }
    }

    func save(_ row: StoryRow) {
        snapshot.savedStories.removeAll { $0.id == row.id }
        snapshot.savedStories.insert(SavedStory(row: row, savedAt: Date()), at: 0)
        persist()
    }

    func unsave(_ id: Int) {
        snapshot.savedStories.removeAll { $0.id == id }
        persist()
    }

    func savedStories() -> [SavedStory] {
        snapshot.savedStories
    }

    func markRead(_ id: Int) {
        snapshot.readIDs.removeAll { $0 == id }
        snapshot.readIDs.append(id)
        if snapshot.readIDs.count > Self.maxReadIDs {
            snapshot.readIDs.removeFirst(snapshot.readIDs.count - Self.maxReadIDs)
        }
        persist()
    }

    func isRead(_ id: Int) -> Bool {
        snapshot.readIDs.contains(id)
    }

    func clearReadHistory() {
        snapshot.readIDs = []
        persist()
    }

    func readCount() -> Int {
        snapshot.readIDs.count
    }

    func readIDs() -> [Int] {
        snapshot.readIDs
    }

    func votedIDs() -> Set<Int> {
        snapshot.votedIDs
    }

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return
        }
    }

    private static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("StoryState.json")
    }

    private static func load(from url: URL) -> StoryStateSnapshot {
        guard let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(StoryStateSnapshot.self, from: data) else {
            return StoryStateSnapshot(votedIDs: [], savedStories: [], readIDs: [])
        }
        return value
    }
}

@MainActor
final class StoryStateModel: ObservableObject {

    @Published private(set) var savedStories: [SavedStory] = []
    @Published private(set) var readIDs: Set<Int> = []
    @Published private(set) var votedIDs: Set<Int> = []

    private let state: LocalStoryState
    private var loaded = false

    init(state: LocalStoryState = .shared) {
        self.state = state
    }

    func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        Task {
            await reload()
        }
    }

    func reload() async {
        let saved = await state.savedStories()
        let read = await readSet()
        let voted = await state.votedIDs()
        savedStories = saved
        readIDs = read
        votedIDs = voted
    }

    func isSaved(_ id: Int) -> Bool {
        savedStories.contains { $0.id == id }
    }

    func isRead(_ id: Int) -> Bool {
        readIDs.contains(id)
    }

    func hasVoted(_ id: Int) -> Bool {
        votedIDs.contains(id)
    }

    func save(_ row: StoryRow) {
        savedStories.removeAll { $0.id == row.id }
        savedStories.insert(SavedStory(row: row, savedAt: Date()), at: 0)
        Task {
            await state.save(row)
        }
    }

    func unsave(_ id: Int) {
        savedStories.removeAll { $0.id == id }
        Task {
            await state.unsave(id)
        }
    }

    func markRead(_ id: Int) {
        readIDs.insert(id)
        Task {
            await state.markRead(id)
            await reload()
        }
    }

    func markVoted(_ id: Int) {
        votedIDs.insert(id)
        Task {
            await state.markVoted(id)
        }
    }

    func unmarkVoted(_ id: Int) {
        votedIDs.remove(id)
        Task {
            await state.unmarkVoted(id)
        }
    }

    func clearReadHistory() {
        readIDs = []
        Task {
            await state.clearReadHistory()
        }
    }

    private func readSet() async -> Set<Int> {
        Set(await state.readIDs())
    }
}
