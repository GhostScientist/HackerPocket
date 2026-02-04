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

    @EnvironmentObject var authManager: HNAuthManager

    @State private var comments: [Comment] = []
    @State private var isLoading = true
    @State private var replyTarget: Comment?

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
                List(comments) { comment in
                    CommentRow(comment: comment) {
                        replyTarget = comment
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                }
            }
        }
        .navigationTitle("Comments")
        .toolbar {
            if authManager.isLoggedIn {
                ToolbarItem(placement: .bottomBar) {
                    NavigationLink {
                        ComposeCommentView(parentId: storyId, parentAuthor: nil)
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
