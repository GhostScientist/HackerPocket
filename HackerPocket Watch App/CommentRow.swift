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
            // Author and time header
            HStack {
                Text(comment.by)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                Spacer()
                Text(comment.postedTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Comment body with proper formatting
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
                        Label(kids.count == 1 ? "1 Reply" : "\(kids.count) Replies", systemImage: "text.bubble")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.teal)
                    .accessibilityLabel("View Replies")
                    .accessibilityHint("Open this comment's replies.")
                }

                if let onReply {
                    Button {
                        onReply()
                    } label: {
                        Label("Reply", systemImage: "arrowshape.turn.up.left.fill")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .accessibilityHint("Reply to this comment.")
                }

                if authManager.isLoggedIn && !storyState.hasVoted(comment.id) {
                    Button {
                        upvote()
                    } label: {
                        Label("Upvote", systemImage: "arrow.up")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.orange)
                    .disabled(voteInFlight)
                    .accessibilityHint("Upvote this comment.")
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: 24)
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
