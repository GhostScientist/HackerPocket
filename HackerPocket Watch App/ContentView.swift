//
//  ContentView.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/23/24.
//

import SwiftUI

struct ContentView: View {
    
    @State private var storiesRows: [StoryRow] = []
    @State private var isRefreshing = false
    @State private var rotationDegrees = 0.0
    @State private var initialFetch = true
    
    private func fetchTopStories() {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let url = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json")!
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data {
                    if let storyIds = try? JSONDecoder().decode([Int].self, from: data) {
                        // Process the story IDs and fetch individual story details
                        storiesRows.removeAll()
                        let onlyFirst30 = storyIds.prefix(30)
                        for storyId in onlyFirst30 {
                            fetchDetailForStory(storyId)
                        }
                    }
                }
            }.resume()
            
            rotationDegrees = 0.0
            isRefreshing = false
            initialFetch = false
        }
        
        
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
            ZStack {
                List(storiesRows, id: \.self) { story in
                    NavigationLink(destination: DetailView(number: story.id)) {
                        StoryRowView(story: story)
                    }
                }
                .toolbar{
                    Button {
                        isRefreshing = true
                        fetchTopStories()
                    } label: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                    }
                }
                .blur(radius: isRefreshing ? 5 : 0) // Apply blur effect when refreshing
                .scrollDisabled(isRefreshing)
                .navigationTitle("Hacker News")
                .animation(Animation.easeOut(duration: 0.3), value: isRefreshing)
                
                if isRefreshing {
                    VStack {
                        Text("Fetching latest stories...")
                        Image(systemName: "arrow.circlepath")
                        
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .rotationEffect(Angle(degrees: rotationDegrees))
                            .onAppear {
                                withAnimation(Animation.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                                    rotationDegrees = -360
                                }
                            }
                    }
                }
            }
        }
        .onAppear {
            fetchTopStories()
        }
        
    }
}

#Preview {
    ContentView()
}
