//
//  StoryRow.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/24/24.
//

import SwiftUI

struct StoryRowView: View {
    var story: StoryRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(story.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(3)
                .truncationMode(.tail)

            HStack(spacing: 12) {
                Label("\(story.score)", systemImage: "arrow.up")
                    .font(.caption2)
                    .foregroundStyle(.orange)

                Label("\(story.kids.count)", systemImage: "bubble.left.and.bubble.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    StoryRowView(story: StoryRow(id: 1, title: "Show HN: A really interesting project that does something cool", score: 123, kids: [2, 3, 4, 5]))
}
