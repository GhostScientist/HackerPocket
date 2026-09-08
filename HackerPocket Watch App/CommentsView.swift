//
//  CommentsView.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/23/24.
//

import SwiftUI

struct CommentsView: View {
    let commentIds: [Int]
    let storyId: Int
    var parentComment: Comment? = nil

    @EnvironmentObject var authManager: HNAuthManager
    @StateObject private var viewModel = CommentsViewModel()

    @State private var replyTarget: Comment?
    @State private var threadTarget: Comment?
    @State private var isComposing = false
    @State private var isReading = false

    var body: some View {
        commentList
        .tint(.orange)
        .navigationTitle(parentComment != nil ? "Thread" : "Comments")
        .navigationDestination(item: $threadTarget) { comment in
            CommentsView(commentIds: comment.kids ?? [], storyId: storyId, parentComment: comment)
        }
        .navigationDestination(isPresented: $isComposing) {
            ComposeCommentView(parentId: cacheKey, parentAuthor: parentComment?.by)
        }
        .toolbar {
            if authManager.isLoggedIn {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        preservePosition()
                        isComposing = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Compose Comment")
                    .accessibilityHint("Write a new comment.")
                }
            }
        }
        .sheet(item: $replyTarget, onDismiss: { isReading = true }) { comment in
            NavigationStack {
                ComposeCommentView(parentId: comment.id, parentAuthor: comment.by)
            }
            .tint(.orange)
        }
        .onAppear {
            viewModel.loadIfNeeded(ids: commentIds, parentID: cacheKey)
            isReading = true
        }
        .onDisappear { isReading = false }
    }

    /// Threads recurse through this same view, so the cache has to be keyed on
    /// the item the replies actually hang off rather than the root story.
    private var cacheKey: Int {
        parentComment?.id ?? storyId
    }

    private var commentList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let parent = parentComment {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Replying to")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        CommentRow(comment: parent, showsActions: false)
                    }
                    .padding(8)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .id(parent.id)
                }

                if viewModel.isLoading {
                    LoadingStateView(message: "Loading comments...")
                }

                if let message = viewModel.positionMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if viewModel.needsPositionRetry {
                    discussionButton("Retry saved position") { viewModel.retry() }
                    discussionButton("Read from here") { viewModel.readFromHere() }
                }

                if let error = viewModel.error, !viewModel.needsPositionRetry {
                    Text(error.errorDescription ?? error.shortDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if error.isRetryable {
                        discussionButton("Retry") { viewModel.retry() }
                    }
                }

                if viewModel.canLoadEarlier {
                    discussionButton("Earlier comments") {
                        viewModel.loadEarlier()
                    }
                }

                if !viewModel.isLoading && viewModel.comments.isEmpty && viewModel.error == nil {
                    Text(commentIds.isEmpty ? "No comments yet" : "No available comments in this page")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                ForEach(viewModel.comments) { comment in
                    CommentRow(comment: comment, onReply: {
                        preservePosition(fallback: comment.id)
                        replyTarget = comment
                    }, onViewReplies: {
                        preservePosition(fallback: comment.id)
                        threadTarget = comment
                    })
                    .padding(.horizontal, 4)
                    .id(comment.id)
                }

                if viewModel.canLoadMore && viewModel.error == nil && !viewModel.isLoading {
                    discussionButton("Load \(min(viewModel.remainingCount, 20)) More") {
                        viewModel.loadMore()
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView("Loading comments...")
                        .font(.callout)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 8)
        }
        .scrollPosition(id: Binding(
            get: { viewModel.scrollID },
            set: { if isReading { viewModel.updatePosition($0) } }
        ), anchor: .top)
        .contentMargins(.top, 18, for: .scrollContent)
    }

    private func preservePosition(fallback: Int? = nil) {
        viewModel.updatePosition(viewModel.scrollID ?? fallback)
        // Navigation transitions can emit a different scroll target as the
        // source shrinks. Freeze the bookmark before starting the transition.
        isReading = false
    }

    private func discussionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.isLoading || viewModel.isLoadingMore)
    }
}
