//
//  StoryRow.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/24/24.
//

import SwiftUI

struct StoryRowView: View {
    var story: StoryRow

    @EnvironmentObject var authManager: HNAuthManager
    @EnvironmentObject var storyState: StoryStateModel
    @State private var displayedScore: Int
    @State private var voteError: String?
    @State private var voteInFlight = false

    init(story: StoryRow) {
        self.story = story
        _displayedScore = State(initialValue: story.score)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(story.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(3)
                .truncationMode(.tail)

            HStack(spacing: 8) {
                storyMetric(
                    value: displayedScore,
                    systemImage: "arrow.up",
                    color: .orange
                )

                // Jobs posts have no comments; an always-visible "0" bubble
                // just reads as a broken row.
                if story.descendants > 0 || !story.kids.isEmpty {
                    Spacer(minLength: 4)
                    storyMetric(
                        value: max(story.descendants, story.kids.count),
                        systemImage: "bubble.left.and.bubble.right",
                        color: .secondary
                    )
                }

                Spacer()
            }
        }
        .padding(.vertical, 2)
        .opacity(storyState.isRead(story.id) ? 0.55 : 1)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                if storyState.isSaved(story.id) {
                    storyState.unsave(story.id)
                } else {
                    storyState.save(story)
                }
            } label: {
                Label(
                    storyState.isSaved(story.id) ? "Unsave" : "Save",
                    systemImage: storyState.isSaved(story.id) ? "bookmark.slash" : "bookmark"
                )
            }
            .tint(.blue)
            .accessibilityLabel(storyState.isSaved(story.id) ? "Unsave Story" : "Save Story")
            .accessibilityHint(
                storyState.isSaved(story.id)
                    ? "Remove this story from saved stories."
                    : "Save this story for later."
            )

            if authManager.isLoggedIn && !storyState.hasVoted(story.id) {
                Button {
                    upvote()
                } label: {
                    Label("Upvote", systemImage: "arrow.up")
                }
                .tint(.orange)
                .disabled(voteInFlight)
                .accessibilityLabel("Upvote Story")
                .accessibilityHint("Upvote this story.")
            }
        }
        .onChange(of: story.score) { _, newScore in
            if !voteInFlight {
                displayedScore = newScore
            }
        }
        .alert(
            "Upvote failed",
            isPresented: Binding(
                get: { voteError != nil },
                set: { if !$0 { voteError = nil } }
            )
        ) {
            Button("OK") { voteError = nil }
        } message: {
            Text(voteError ?? "The vote was not submitted.")
        }
    }

    private func storyMetric(value: Int, systemImage: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .imageScale(.small)

            Text(value, format: .number)
                .monospacedDigit()
        }
        .font(.caption2)
        .foregroundStyle(color)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func upvote() {
        guard authManager.isLoggedIn, !storyState.hasVoted(story.id), !voteInFlight else { return }
        displayedScore += 1
        voteInFlight = true
        storyState.markVoted(story.id)

        Task {
            do {
                try await authManager.upvote(itemID: story.id)
                WatchHaptics.upvote()
            } catch {
                displayedScore = max(displayedScore - 1, 0)
                storyState.unmarkVoted(story.id)
                voteError = error.localizedDescription
                WatchHaptics.failure()
            }
            voteInFlight = false
        }
    }
}

#Preview {
    StoryRowView(story: StoryRow(id: 1, title: "Show HN: A really interesting project that does something cool", score: 123, kids: [2, 3, 4, 5], descendants: 42))
        .environmentObject(HNAuthManager())
        .environmentObject(StoryStateModel())
}
