//
//  CommentsView.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/23/24.
//

import SwiftUI

struct CommentsView: View {
    let commentIds: [Int]
    @State private var comments: [Comment] = []

    var body: some View {
        List(comments) { comment in
            VStack(alignment: .leading, spacing: 5) {
                Text(comment.by)
                    .font(.headline)
                Text(comment.textWithoutTags.unescape().decodingUnicodeCharacters)
                    .font(.footnote)
                    .lineLimit(4)
                    .truncationMode(.tail)
                Text(comment.postedTime)
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
                            print(comment)
                            comments.append(comment)
                        }
                    }
                }
            }.resume()
        }
    }
}

extension String {
    var decodingUnicodeCharacters: String { applyingTransform(.init("Hex-Any"), reverse: false) ?? "" }
}

extension String {
    func unescape() -> String {
        let characters = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'"
        ]
        var str = self
        for (escaped, unescaped) in characters {
            str = str.replacingOccurrences(of: escaped, with: unescaped, options: NSString.CompareOptions.literal, range: nil)
        }
        return str
    }
}

