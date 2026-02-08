//
//  HackerPocketWidget.swift
//  HackerPocket Watch App
//
//  Complication widget for quick access to Hacker News stories
//

import SwiftUI
import WidgetKit
import AppIntents

struct HackerPocketWidget: Widget {
    let kind: String = "HackerPocketWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HackerPocketTimelineProvider()) { entry in
            HackerPocketWidgetView(entry: entry)
        }
        .configurationDisplayName("Hacker News")
        .description("Quick access to top Hacker News stories")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

struct HackerPocketEntry: TimelineEntry {
    let date: Date
    let topStoryTitle: String?
    let storyCount: Int
}

struct HackerPocketTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HackerPocketEntry {
        HackerPocketEntry(date: Date(), topStoryTitle: "Top Story", storyCount: 0)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (HackerPocketEntry) -> Void) {
        let entry = HackerPocketEntry(date: Date(), topStoryTitle: "Hacker News", storyCount: 0)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<HackerPocketEntry>) -> Void) {
        // Fetch the latest story count or title if desired
        fetchTopStory { title, count in
            let currentDate = Date()
            let entry = HackerPocketEntry(date: currentDate, topStoryTitle: title, storyCount: count)
            
            // Update every hour
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    private func fetchTopStory(completion: @escaping (String?, Int) -> Void) {
        let url = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let storyIds = try? JSONDecoder().decode([Int].self, from: data),
                  let firstId = storyIds.first else {
                completion(nil, 0)
                return
            }
            
            // Fetch the first story's title
            let storyURL = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(firstId).json")!
            URLSession.shared.dataTask(with: storyURL) { data, _, _ in
                if let data = data,
                   let story = try? JSONDecoder().decode(StoryData.self, from: data) {
                    completion(story.title, storyIds.count)
                } else {
                    completion(nil, storyIds.count)
                }
            }.resume()
        }.resume()
    }
    
    struct StoryData: Codable {
        let title: String
    }
}

struct HackerPocketWidgetView: View {
    let entry: HackerPocketEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }
    
    private var circularView: some View {
        Button(intent: OpenAppIntent()) {
            ZStack {
                AccessoryWidgetBackground()
                // Clean "Y" icon representing Y Combinator / Hacker News
                Text("Y")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var rectangularView: some View {
        Button(intent: OpenAppIntent()) {
            HStack(spacing: 6) {
                // Y icon
                Text("Y")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Hacker News")
                        .font(.system(size: 14, weight: .semibold))
                    if let title = entry.topStoryTitle {
                        Text(title)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("Top Stories")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
    
    private var cornerView: some View {
        Button(intent: OpenAppIntent()) {
            // For corner, just use the Y icon
            Text("Y")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
        }
        .buttonStyle(.plain)
    }
    
    private var inlineView: some View {
        Button(intent: OpenAppIntent()) {
            HStack(spacing: 3) {
                Text("Y")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Text("Hacker News")
                    .font(.system(size: 12))
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview(as: .accessoryCircular) {
    HackerPocketWidget()
} timeline: {
    HackerPocketEntry(date: Date(), topStoryTitle: "Sample Story", storyCount: 500)
}

#Preview(as: .accessoryRectangular) {
    HackerPocketWidget()
} timeline: {
    HackerPocketEntry(date: Date(), topStoryTitle: "Interesting Tech Article About New Developments", storyCount: 500)
}
#Preview(as: .accessoryCorner) {
    HackerPocketWidget()
} timeline: {
    HackerPocketEntry(date: Date(), topStoryTitle: "Sample Story", storyCount: 500)
}

#Preview(as: .accessoryInline) {
    HackerPocketWidget()
} timeline: {
    HackerPocketEntry(date: Date(), topStoryTitle: "Sample Story", storyCount: 500)
}

