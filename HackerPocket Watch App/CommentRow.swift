//
//  CommentRow.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/24/24.
//

import SwiftUI

struct CommentRow: View {
    var comment: Comment
    var onReply: (() -> Void)?
    var onViewReplies: (() -> Void)?

    @EnvironmentObject var authManager: HNAuthManager
    @EnvironmentObject var storyState: StoryStateModel
    @State private var isExpanded: Bool = false
    @State private var voteError: String?
    @State private var voteInFlight = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(comment.by)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                Text(comment.postedTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Text(comment.formattedText)
                .font(.caption2)
                .lineLimit(isExpanded ? nil : 4)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: isExpanded)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
                .accessibilityHint("Double tap to expand or collapse.")

            HStack(spacing: 8) {
                if let kids = comment.kids, !kids.isEmpty, let onViewReplies {
                    Button {
                        onViewReplies()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "text.bubble")
                            Text(kids.count, format: .number)
                                .monospacedDigit()
                        }
                        .font(.caption2)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.teal)
                    .accessibilityLabel(kids.count == 1 ? "View 1 Reply" : "View \(kids.count) Replies")
                    .accessibilityHint("Open this comment's replies.")
                }

                Spacer(minLength: 4)

                if let onReply {
                    Button {
                        onReply()
                    } label: {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.caption)
                            .frame(minWidth: 28, minHeight: 28)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .accessibilityLabel("Reply")
                    .accessibilityHint("Reply to this comment.")
                }

                if authManager.isLoggedIn && !storyState.hasVoted(comment.id) {
                    Button {
                        upvote()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.caption)
                            .frame(minWidth: 28, minHeight: 28)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.orange)
                    .disabled(voteInFlight)
                    .accessibilityLabel("Upvote")
                    .accessibilityHint("Upvote this comment.")
                }
            }
            .frame(minHeight: 28)
        }
        .padding(.vertical, 4)
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

    private func upvote() {
        guard authManager.isLoggedIn, !storyState.hasVoted(comment.id), !voteInFlight else { return }
        voteInFlight = true
        storyState.markVoted(comment.id)
        Task {
            do {
                try await authManager.upvote(itemID: comment.id)
                WatchHaptics.upvote()
            } catch {
                storyState.unmarkVoted(comment.id)
                voteError = error.localizedDescription
                WatchHaptics.failure()
            }
            voteInFlight = false
        }
    }
}

#Preview {
    CommentRow(
        comment: Comment(
            id: 1,
            by: "pg",
            text: "This is a <i>test</i> comment with <p>multiple paragraphs</p> and some &amp; entities. It&#x27;s also got a <a href=\"https://example.com\">link</a> in it.",
            time: Int(Date().timeIntervalSince1970) - 3600,
            type: "comment"
        ),
        onReply: {},
        onViewReplies: {}
    )
    .environmentObject(HNAuthManager())
    .environmentObject(StoryStateModel())
}
