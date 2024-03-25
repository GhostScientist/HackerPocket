//
//  ContentView.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/23/24.
//

import SwiftUI

struct ContentView: View {
    
    @State private var stories: [Int] = []
    @State private var storiesRows: [StoryRow] = []
    
    private func fetchTopStories() {
        let url = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let storyIds = try? JSONDecoder().decode([Int].self, from: data) {
                    // Process the story IDs and fetch individual story details
                    let onlyFirst30 = storyIds.prefix(30)
                    for storyId in onlyFirst30 {
                        fetchDetailForStory(storyId)
                    }
                }
            }
        }.resume()
    }
    
    private func fetchDetailForStory(_ storyId: Int) {
        
        let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(storyId).json")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let story = try? JSONDecoder().decode(StoryRow.self, from: data) {
                    storiesRows.append(story)
                }
            }
        }.resume()
    }
    
    var body: some View {
        NavigationView {
            List(storiesRows, id: \.self) { story in
                NavigationLink(destination: DetailView(number: story.id)) {
                    StoryRowView(story: story)
                }
            }
            .navigationTitle("Hacker News")
        }.onAppear {
            fetchTopStories()
        }
    }
}

#Preview {
    ContentView()
}
