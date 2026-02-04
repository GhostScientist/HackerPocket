//
//  ContentView.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/23/24.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var authManager: HNAuthManager

    @State private var storiesRows: [StoryRow] = []
    @State private var isRefreshing = false

    private func fetchTopStories() {
        isRefreshing = true

        let url = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let storyIds = try? JSONDecoder().decode([Int].self, from: data) {
                    let first30 = Array(storyIds.prefix(30))
                    var fetched: [StoryRow] = []
                    let group = DispatchGroup()

                    for storyId in first30 {
                        group.enter()
                        let storyURL = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(storyId).json")!
                        URLSession.shared.dataTask(with: storyURL) { data, _, _ in
                            if let data = data,
                               let story = try? JSONDecoder().decode(StoryRow.self, from: data) {
                                fetched.append(story)
                            }
                            group.leave()
                        }.resume()
                    }

                    group.notify(queue: .main) {
                        storiesRows = fetched
                        isRefreshing = false
                    }
                } else {
                    DispatchQueue.main.async { isRefreshing = false }
                }
            } else {
                DispatchQueue.main.async { isRefreshing = false }
            }
        }.resume()
    }

    var body: some View {
        NavigationStack {
            Group {
                if isRefreshing && storiesRows.isEmpty {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Loading stories...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(storiesRows, id: \.self) { story in
                        NavigationLink(value: story) {
                            StoryRowView(story: story)
                        }
                    }
                    .navigationDestination(for: StoryRow.self) { story in
                        DetailView(number: story.id)
                    }
                }
            }
            .navigationTitle("Hacker News")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        if authManager.isLoggedIn {
                            AccountView()
                        } else {
                            LoginView()
                        }
                    } label: {
                        Image(systemName: authManager.isLoggedIn ? "person.crop.circle.fill.badge.checkmark" : "person.circle")
                            .foregroundStyle(authManager.isLoggedIn ? .green : .secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        fetchTopStories()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
            }
        }
        .onAppear {
            if storiesRows.isEmpty {
                fetchTopStories()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HNAuthManager())
}
