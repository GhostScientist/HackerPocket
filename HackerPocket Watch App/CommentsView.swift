//
//  CommentsView.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/23/24.
//

import SwiftUI

struct CustomTipView: View {
    var body: some View {
        HStack {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
            Text("Tap on a comment to expand it.")
                .font(.caption)
        }
        .padding(8)
        .background(Color(.lightGray))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}

struct CommentsView: View {
    let commentIds: [Int]
    @State private var comments: [Comment] = []
    @State private var isLoading = true
    @State private var showTip = false
    
    @AppStorage("commentsTipShown") private var commentsTipShown = false
    
    var body: some View {
        List(comments) { comment in
            CommentRow(comment: comment)
        }
        .navigationTitle("Comments")
        .onAppear {
            fetchComments()
        }
        .onChange(of: isLoading) { oldValue, newValue in
            if !newValue && !showTip && !commentsTipShown {
                showTip = true
                commentsTipShown = true
            }
        }
        .overlay(
            VStack {
                if showTip {
                    CustomTipView()
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .onTapGesture {
                            withAnimation {
                                showTip = false
                            }
                        }
                }
                Spacer()
            }
        )
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
