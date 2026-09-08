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
    let storyID: Int?
    let storyCount: Int
}

struct HackerPocketTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HackerPocketEntry {
        HackerPocketEntry(date: Date(), topStoryTitle: "Top Story", storyID: nil, storyCount: 0)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (HackerPocketEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            fetchTopStory { title, storyID, count in
                completion(HackerPocketEntry(
                    date: Date(), topStoryTitle: title, storyID: storyID, storyCount: count
                ))
            }
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<HackerPocketEntry>) -> Void) {
        fetchTopStory { title, storyID, count in
            let currentDate = Date()
            let entry = HackerPocketEntry(
                date: currentDate,
                topStoryTitle: title,
                storyID: storyID,
                storyCount: count
            )
            
            // Request another fetch in an hour; watchOS decides when it can run.
            let nextUpdate = currentDate.addingTimeInterval(60 * 60)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    private func fetchTopStory(completion: @escaping (String?, Int?, Int) -> Void) {
        let url = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil,
                  let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode),
                  let data = data,
                  let storyIds = try? JSONDecoder().decode([Int].self, from: data),
                  let firstId = storyIds.first else {
                completion(nil, nil, 0)
                return
            }
            
            // Fetch the first story's title
            let storyURL = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(firstId).json")!
            URLSession.shared.dataTask(with: storyURL) { data, response, error in
                if error == nil,
                   let response = response as? HTTPURLResponse,
                   (200..<300).contains(response.statusCode),
                   let data = data,
                   let story = try? JSONDecoder().decode(StoryData.self, from: data),
                   story.id == firstId,
                   story.dead != true, story.deleted != true,
                   !story.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    completion(story.title, story.id, storyIds.count)
                } else {
                    completion(nil, nil, storyIds.count)
                }
            }.resume()
        }.resume()
    }
    
    struct StoryData: Codable {
        let id: Int
        let title: String
        let dead: Bool?
        let deleted: Bool?
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
                // Clean "HN" icon representing Y Combinator / Hacker News
                Text("HN")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open HackerPocket")
    }
    
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let title = entry.topStoryTitle {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2)
                    .layoutPriority(1)
                HStack(spacing: 4) {
                    Text("HN")
                        .foregroundStyle(.orange)
                    Text("Fetched \(entry.date, style: .relative) ago")
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)
                .lineLimit(1)
            } else {
                Text("Headline unavailable")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2)
                Text("Open HackerPocket")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(
            entry.storyID.flatMap { URL(string: "hackerpocket://story/\($0)") }
                ?? URL(string: "hackerpocket://")
        )
        .accessibilityElement(children: .combine)
    }
    
    private var cornerView: some View {
        Button(intent: OpenAppIntent()) {
            // Keep the small complication recognizable at a glance.
            Text("HN")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open HackerPocket")
    }
    
    private var inlineView: some View {
        Button(intent: OpenAppIntent()) {
            HStack(spacing: 3) {
                Text("HN")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Text("Hacker News")
                    .font(.system(size: 12))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open HackerPocket")
    }
}

#Preview(as: .accessoryCircular) {
    HackerPocketWidget()
} timeline: {
    HackerPocketEntry(date: Date(), topStoryTitle: "Sample Story", storyID: 1, storyCount: 500)
}

#Preview(as: .accessoryRectangular) {
    HackerPocketWidget()
} timeline: {
    HackerPocketEntry(
        date: Date(),
        topStoryTitle: "Interesting Tech Article About New Developments",
        storyID: 1,
        storyCount: 500
    )
}
#Preview(as: .accessoryCorner) {
    HackerPocketWidget()
} timeline: {
    HackerPocketEntry(date: Date(), topStoryTitle: "Sample Story", storyID: nil, storyCount: 500)
}

#Preview(as: .accessoryInline) {
    HackerPocketWidget()
} timeline: {
    HackerPocketEntry(date: Date(), topStoryTitle: "Sample Story", storyID: nil, storyCount: 500)
}

#Preview("Unavailable", as: .accessoryRectangular) {
    HackerPocketWidget()
} timeline: {
    HackerPocketEntry(date: Date(), topStoryTitle: nil, storyID: nil, storyCount: 0)
}

#Preview("Older headline", as: .accessoryRectangular) {
    HackerPocketWidget()
} timeline: {
    HackerPocketEntry(
        date: Date().addingTimeInterval(-6 * 60 * 60),
        topStoryTitle: "Show HN: A small project with a surprisingly long headline",
        storyID: 1,
        storyCount: 500
    )
}
