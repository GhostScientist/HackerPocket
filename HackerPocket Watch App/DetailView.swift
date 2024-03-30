//
//  DetailView.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/24/24.
//

import SwiftUI
import AuthenticationServices


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
        ScrollView {
            VStack(alignment: .leading) {
                if let story = story {
                    Text(story.title)
                        .font(.headline)
                    
                    Text(.init(story.postedDetails)).font(.footnote)
                    
                    if (story.url != nil) {
                        Text(.init("Source: *\(story.url!)*")).font(.footnote).lineLimit(2).padding([.top, .bottom], 5)
                    }
                   
                    
                    if let url = story.url {
                        Button {
                            guard let url = URL(string: url) else { return }
                            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "") { _,_ in
                            }
                            session.prefersEphemeralWebBrowserSession = true
                            session.start()
                        } label: {
                            Text("View Source")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }.buttonBorderShape(.roundedRectangle(radius: 10))
                    }
                    
                    NavigationLink(destination: CommentsView(commentIds: story.kids!)) {
                        Text("View Comments")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }.buttonBorderShape(.roundedRectangle(radius: 10))
                    
                    if let text = story.text {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Text:")
                                .font(.subheadline)
                            
                            Text(text.textWithoutTags)
                                .font(.body)
                        }
                    }
                    
                    let shareUrl: String = story.url ?? "https://news.ycombinator.com/item?id=\(story.id)"
                    ShareLink(item: shareUrl) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }.buttonBorderShape(.roundedRectangle(radius: 10))
                    
                    Text("News Type: \(story.type.capitalized)")
                        .font(.footnote)
                } else {
                    Text("Loading story details...")
                }
            }
            .padding()
        }
        .navigationTitle("Story Details")
        .onAppear {
            fetchDetailsForStory()
        }
    }
}

#Preview {
    DetailView(number: 39810320)
}

