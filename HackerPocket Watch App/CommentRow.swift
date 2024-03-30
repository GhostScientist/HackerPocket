//
//  CommentRow.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/24/24.
//

import SwiftUI

struct CommentRow: View {
    var comment: Comment
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            
            VStack(alignment: .leading, spacing: 5) {
                Text(comment.by)
                    .font(.headline)
                Text(comment.textWithoutTags)
                    .font(.footnote)
                    .lineLimit(isExpanded ? nil : 2)
                    .truncationMode(.tail)
                Text(.init(comment.postedTime))
                    .font(.footnote)
            }
        }
        .onTapGesture {
            isExpanded.toggle()        }
    }
}


#Preview {
    CommentRow(comment: Comment(id: 1, by: "Zt", text: "This is a test comment! This is a test comment! This is a test comment! This is a test comment! This is a test comment! This is a test comment! This is a test comment! This is a test comment! This is a test comment! This is a test comment! This is a test comment! This is a test comment! This is a test comment! This is a test comment! This is a test comment! This is a test comment! This is a test comment!", time: Int(Date.timeIntervalSinceReferenceDate.magnitude), type: "story"))
}
