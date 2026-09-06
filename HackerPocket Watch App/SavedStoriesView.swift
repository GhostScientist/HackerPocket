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
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text("No saved stories")
                        .font(.headline)
                    Text("Save a story from its page or swipe left on a headline.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            } else {
                List {
                    ForEach(storyState.savedStories) { saved in
                        NavigationLink {
                            DetailView(number: saved.id, fallback: saved.row.asStory)
                        } label: {
                            StoryRowView(story: saved.row)
                        }
                        .listRowBackground(Color.white.opacity(0.08))
                    }
                }
            }
        }
        .navigationTitle("Saved")
        .containerBackground(.black, for: .navigation)
        .onAppear {
            storyState.loadIfNeeded()
        }
    }
}

#Preview {
    NavigationStack {
        SavedStoriesView()
    }
    .environmentObject(HNAuthManager())
    .environmentObject(StoryStateModel())
}
