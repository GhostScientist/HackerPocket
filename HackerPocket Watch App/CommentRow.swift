//
//  CommentRow.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/24/24.
//

import SwiftUI

struct CommentRow: View {
    var comment: Comment
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(comment.by)
                .font(.headline)
            Text(comment.textWithoutTags)
                .font(.footnote)
                .lineLimit(4)
                .truncationMode(.tail)
            Text(.init(comment.postedTime))
                .font(.footnote)
        }
    }
}

#Preview {
    CommentRow(comment: Comment(id: 1, by: "TestComment", text: "This is a test comment!", time: Int(Date.timeIntervalSinceReferenceDate.magnitude), type: "story"))
}
