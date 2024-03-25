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
        HStack {
            Text(String(story.title))
                .font(.footnote)
                .lineLimit(3)
                .truncationMode(.tail)
            Spacer()
            VStack(alignment: .trailing) {
                HStack {
                    Text(String(story.score)).font(.footnote).lineLimit(1).truncationMode(.tail)
                    Image(systemName: "arrow.up").fontWeight(.bold)
                }
                HStack {
                    Text(String(story.kids.count)).font(.footnote).lineLimit(1).truncationMode(.tail).imageScale(.small)
                    Image(systemName: "bubble.left.and.bubble.right").fontWeight(.bold).imageScale(.small)
                }
            }
            
        }
    }
}

#Preview {
    StoryRowView(story: StoryRow(id: 1, title: "Test Story", score: 123, kids: [2, 3]))
}
