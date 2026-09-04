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

            // Expand indicator when collapsed
            if !isExpanded {
                Text("Tap to expand")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            // Action buttons when expanded
            if isExpanded {
                HStack(spacing: 12) {
                    if let kids = comment.kids, !kids.isEmpty {
                        Button {
                            onViewReplies?()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "text.bubble")
                                Text(kids.count == 1 ? "1 reply" : "\(kids.count) replies")
                            }
                            .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.teal)
                    }

                    if let onReply = onReply {
                        Button {
                            onReply()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrowshape.turn.up.left.fill")
                                Text("Reply")
                            }
                            .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }

                    if authManager.isLoggedIn && !storyState.hasVoted(comment.id) {
                        Button {
                            upvote()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up")
                                Text("Upvote")
                            }
                            .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.orange)
                        .disabled(voteInFlight)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
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

    private func upvote() {
        guard authManager.isLoggedIn, !storyState.hasVoted(comment.id), !voteInFlight else { return }
        voteInFlight = true
        storyState.markVoted(comment.id)
        Task {
            do {
                try await authManager.upvote(itemID: comment.id)
            } catch {
                storyState.unmarkVoted(comment.id)
                voteError = error.localizedDescription
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
