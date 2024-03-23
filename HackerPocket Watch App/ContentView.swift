//
//  ContentView.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/23/24.
//

import SwiftUI
import AuthenticationServices

struct StoryRow: Codable, Hashable {
    let id: Int
    let title: String
    let score: Int
    let kids: [Int]
}

struct ContentView: View {
    
    @State private var stories: [Int] = []
    @State private var storiesRows: [StoryRow] = []
    
    func fetchTopStories() {
        let url = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let storyIds = try? JSONDecoder().decode([Int].self, from: data) {
                    // Process the story IDs and fetch individual story details
                    for storyId in storyIds {
                        fetchDetailForStory(storyId)
                    }
                }
            }
        }.resume()
    }
    
    // Once I have a list of storyIds, I need to fetch the titles
    // for each of them, fetch the story
    
    
    
    func fetchDetailForStory(_ storyId: Int) {
        
        let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(storyId).json")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let story = try? JSONDecoder().decode(StoryRow.self, from: data) {
                    // Process the story IDs and fetch individual story details
                    
                    print("@D \(story)")
                    storiesRows.append(story)
                }
            }
        }.resume()
    }
    
    var body: some View {
            NavigationView {
                List(storiesRows, id: \.self) { story in
                    NavigationLink(destination: DetailView(number: story.id)) {
                        HStack {
                            Text(String(story.title))
                            Spacer()
                            VStack {
                                Text(String(story.score))
                                Text(String(story.kids.count))
                            }
                            
                        }
                    }
                }
                .navigationTitle("Top Stories")
            }.onAppear {
                fetchTopStories()
            }
    }
}

struct Story: Codable {
    let id: Int
    let title: String
    let by: String
    let score: Int
    let time: Int
    let url: String?
    let descendants: Int
    let kids: [Int]?
    let text: String?
    let type: String
}

struct DetailView: View {
    let number: Int
    
    @State private var story: Story?
    
    func fetchDetailsForStory() {
        let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(number).json")!
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let data = data {
                        if let storyDetails = try? JSONDecoder().decode(Story.self, from: data) {
                            DispatchQueue.main.async {
                                story = storyDetails
                            }
                        }
                    }
                }.resume()
    }
    
    var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                if let story = story {
                    ScrollView {
                        Text(story.title)
                            .font(.headline)
                        Text("By \(story.by)")
                            .font(.subheadline)
                        Text("Score: \(story.score)")
                        Text("Posted: \(story.time)")
                        if let url = story.url {
                            Text("URL: \(url)")
                            Button {
                                
                                guard let url = URL(string: story.url!) else { return }
                                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "") { _, _ in

                                }
                                session.prefersEphemeralWebBrowserSession = true
                                session.start()
                            } label: {
                                Text("Open URL")
                            }

                        }
                        Text("Descendants: \(story.descendants)")
                        if let kids = story.kids {
                            Text("Kids: \(kids.count)")
                        }
                        NavigationLink(destination: CommentsView(commentIds: story.kids!)) {
                            Text("View Comments")
                        }
                        if let text = story.text {
                            Text("Text:")
                            Text(text)
                        }
                        Text("Type: \(story.type)")
                    }
                    
                } else {
                    Text("Loading story details...")
                }
            }
            .padding()
            .navigationTitle("Story Details")
            .onAppear {
                fetchDetailsForStory()
            }
        }
}

#Preview {
    ContentView()
}
