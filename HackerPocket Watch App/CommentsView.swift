//
//  CommentsView.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/23/24.
//

import SwiftUI

struct Comment: Codable, Identifiable {
    let id: Int
    let by: String
    let text: String
    let time: Int
    let type: String
}

struct CommentsView: View {
    let commentIds: [Int]
    @State private var comments: [Comment] = []

    var body: some View {
        List(comments) { comment in
            VStack(alignment: .leading, spacing: 5) {
                Text(comment.by)
                    .font(.headline)
                Text(comment.text)
                    .font(.subheadline)
                Text("Posted: \(comment.time)")
                    .font(.caption)
            }
        }
        .navigationTitle("Comments")
        .onAppear {
            fetchComments()
        }
    }

    func fetchComments() {
        for commentId in commentIds {
            let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(commentId).json")!
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data {
                    if let comment = try? JSONDecoder().decode(Comment.self, from: data) {
                        DispatchQueue.main.async {
                            comments.append(comment)
                        }
                    }
                }
            }.resume()
        }
    }
}
