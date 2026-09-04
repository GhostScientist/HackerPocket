//
//  SavedStoriesView.swift
//  HackerPocket Watch App
//

import SwiftUI

struct SavedStoriesView: View {
    @EnvironmentObject var storyState: StoryStateModel

    var body: some View {
        Group {
            if storyState.savedStories.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("No saved stories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    ForEach(storyState.savedStories) { saved in
                        NavigationLink {
                            DetailView(number: saved.id, fallback: saved.row.asStory)
                        } label: {
                            StoryRowView(story: saved.row)
                        }
                    }
                }
            }
        }
        .navigationTitle("Saved")
        .onAppear {
            storyState.loadIfNeeded()
        }
    }
}

#Preview {
    NavigationStack {
        SavedStoriesView()
    }
    .environmentObject(StoryStateModel())
}
