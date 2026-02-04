//
//  ComposeCommentView.swift
//  HackerPocket Watch App
//

import SwiftUI

struct ComposeCommentView: View {
    let parentId: Int
    let parentAuthor: String?

    @EnvironmentObject var authManager: HNAuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var commentText = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didPost = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let author = parentAuthor {
                    Text("Replying to \(author)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                TextField("Write a comment...", text: $commentText, axis: .vertical)
                    .lineLimit(3...8)
                    .font(.caption)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                Button {
                    postComment()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .frame(height: 16)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Post")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                    .font(.caption)
                }
                .tint(.orange)
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Reply")
    }

    private func postComment() {
        isSubmitting = true
        errorMessage = nil

        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        authManager.submitComment(parentId: parentId, text: trimmed) { success, error in
            isSubmitting = false
            if success {
                didPost = true
                dismiss()
            } else {
                errorMessage = error ?? "Failed to post comment."
            }
        }
    }
}

#Preview {
    ComposeCommentView(parentId: 12345, parentAuthor: "dang")
        .environmentObject(HNAuthManager())
}
