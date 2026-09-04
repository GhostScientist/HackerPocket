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

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.comments.isEmpty {
                LoadingStateView(message: "Loading comments...")
            } else if let error = viewModel.error, viewModel.comments.isEmpty {
                ErrorStateView(error: error) {
                    viewModel.load(ids: commentIds, parentID: cacheKey)
                }
            } else if viewModel.comments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("No comments yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                commentList
            }
        }
        .navigationTitle(parentComment != nil ? "Thread" : "Comments")
        .navigationDestination(item: $threadTarget) { comment in
            CommentsView(commentIds: comment.kids ?? [], storyId: storyId, parentComment: comment)
        }
        .toolbar {
            if authManager.isLoggedIn {
                ToolbarItem(placement: .bottomBar) {
                    NavigationLink {
                        ComposeCommentView(parentId: parentComment?.id ?? storyId, parentAuthor: parentComment?.by)
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .sheet(item: $replyTarget) { comment in
            NavigationStack {
                ComposeCommentView(parentId: comment.id, parentAuthor: comment.by)
            }
        }
        .onAppear {
            viewModel.loadIfNeeded(ids: commentIds, parentID: cacheKey)
        }
    }

    /// Threads recurse through this same view, so the cache has to be keyed on
    /// the item the replies actually hang off rather than the root story.
    private var cacheKey: Int {
        parentComment?.id ?? storyId
    }

    private var commentList: some View {
        List {
            if let parent = parentComment {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(parent.by)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        Spacer()
                        Text(parent.postedTime)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(parent.formattedText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .listRowBackground(Color.orange.opacity(0.1))
                .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
            }

            if let error = viewModel.error {
                InlineErrorView(error: error) {
                    viewModel.loadMore()
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
            }

            ForEach(viewModel.comments) { comment in
                CommentRow(comment: comment, onReply: {
                    replyTarget = comment
                }, onViewReplies: {
                    threadTarget = comment
                })
                .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
            }

            if viewModel.canLoadMore && viewModel.error == nil {
                LoadMoreRow(
                    title: "Load \(min(viewModel.remainingCount, 20)) More",
                    isLoading: viewModel.isLoadingMore
                ) {
                    viewModel.loadMore()
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
            }
        }
    }
}
