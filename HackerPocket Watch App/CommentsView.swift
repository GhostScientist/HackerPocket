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

    @State private var comments: [Comment] = []
    @State private var isLoading = true
    @State private var replyTarget: Comment?
    @State private var threadTarget: Comment?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading comments...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if comments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("No comments yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
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

                    ForEach(comments) { comment in
                        CommentRow(comment: comment, onReply: {
                            replyTarget = comment
                        }, onViewReplies: {
                            threadTarget = comment
                        })
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                    }
                }
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
            fetchComments()
        }
    }

    func fetchComments() {
        isLoading = true
        var fetchedComments: [Comment] = []

        let group = DispatchGroup()
        for commentId in commentIds {
            group.enter()
            let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(commentId).json")!
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data {
                    if let comment = try? JSONDecoder().decode(Comment.self, from: data) {
                        fetchedComments.append(comment)
                    }
                }
                group.leave()
            }.resume()
        }

        group.notify(queue: .main) {
            comments = fetchedComments.sorted { $0.time > $1.time }
            isLoading = false
        }
    }
}
