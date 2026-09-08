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
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let sourceDetails = story.sourceDetails {
                Text(sourceDetails)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    metrics
                    Spacer(minLength: 0)
                    stateMarkers
                }
                VStack(alignment: .leading, spacing: 6) {
                    metrics
                    stateMarkers
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowBackground(Color.white.opacity(0.06))
        .accessibilityElement(children: .combine)
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
            .tint(.orange)
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

    private var metrics: some View {
        HStack(spacing: 10) {
            storyMetric(
                value: displayedScore,
                systemImage: "arrow.up",
                color: .orange
            )
            .accessibilityLabel("\(displayedScore) points")

            if story.descendants > 0 || !story.kids.isEmpty {
                storyMetric(
                    value: max(story.descendants, story.kids.count),
                    systemImage: "bubble.left.and.bubble.right",
                    color: .secondary
                )
                .accessibilityLabel("\(max(story.descendants, story.kids.count)) comments")
            }
        }
    }

    private var stateMarkers: some View {
        HStack(spacing: 6) {
            if storyState.isSaved(story.id) {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Saved")
            }
            if storyState.isRead(story.id) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Read")
            }
        }
        .font(.caption2)
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
    List {
        StoryRowView(story: StoryRow(
            id: 1,
            title: "Show HN: A tiny computer that helps you understand how the internet works",
            score: 123, kids: [2, 3, 4, 5], descendants: 42,
            url: "https://example.com/project",
            time: Int(Date().timeIntervalSince1970) - 7200
        ))
        StoryRowView(story: StoryRow(
            id: 2, title: "Ask HN: What are you building this weekend?",
            score: 18, kids: [], descendants: 0
        ))
    }
    .environmentObject(HNAuthManager())
    .environmentObject(StoryStateModel())
}
