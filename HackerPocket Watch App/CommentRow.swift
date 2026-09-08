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
    var showsActions = true

    @EnvironmentObject var authManager: HNAuthManager
    @EnvironmentObject var storyState: StoryStateModel
    @State private var isExpanded: Bool = false
    @State private var voteError: String?
    @State private var voteInFlight = false
    @State private var collapsedTextHeight: CGFloat = 0
    @State private var fullTextHeight: CGFloat = 0

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

            commentText(lineLimit: isExpanded ? nil : 4)
                .background(alignment: .topLeading) {
                    // Background copies share the rendered width and font,
                    // without adding layout space or accessibility elements.
                    ZStack(alignment: .topLeading) {
                        commentText(lineLimit: 4)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                                collapsedTextHeight = $0
                            }
                        commentText(lineLimit: nil)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                                fullTextHeight = $0
                            }
                    }
                    .hidden()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                }

            if isExpanded || (collapsedTextHeight > 0 && fullTextHeight > collapsedTextHeight + 0.5) {
                Button {
                    isExpanded.toggle()
                } label: {
                    Label(isExpanded ? "Less" : "More",
                          systemImage: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
                .accessibilityLabel(isExpanded ? "Show less comment text" : "Show full comment")
            }

            if showsActions {
                VStack(alignment: .leading, spacing: 2) {
                    if let kids = comment.kids, !kids.isEmpty, let onViewReplies {
                        Button(action: onViewReplies) {
                            Label(kids.count == 1 ? "1 reply" : "\(kids.count) replies",
                                  systemImage: "text.bubble")
                                .font(.caption)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.orange)
                        .accessibilityHint("Open this comment's replies.")
                    }

                    HStack(spacing: 8) {
                        if let onReply {
                            Button(action: onReply) {
                                Image(systemName: "arrowshape.turn.up.left.fill")
                                    .font(.body)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Reply")
                            .accessibilityHint("Reply to this comment.")
                        }

                        if authManager.isLoggedIn && !storyState.hasVoted(comment.id) {
                            Button {
                                upvote()
                            } label: {
                                Image(systemName: "arrow.up")
                                    .font(.body)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .disabled(voteInFlight)
                            .accessibilityLabel("Upvote")
                            .accessibilityHint("Upvote this comment.")
                        }
                    }
                }
            }
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

    private func commentText(lineLimit: Int?) -> some View {
        Text(comment.formattedText)
            .font(.body)
            .lineLimit(lineLimit)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
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
