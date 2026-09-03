//
//  types.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/24/24.
//

import Foundation

/// Only `id` is guaranteed by the HN API. Job posts have no `descendants`,
/// dead or deleted items have no `by`/`title`, and polls have no `url`, so
/// every other field decodes defensively — a single missing key used to make
/// the whole item fail to decode and the screen hang on "Loading…".
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

    enum CodingKeys: String, CodingKey {
        case id, title, by, score, time, url, descendants, kids, text, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "(untitled)"
        by = try container.decodeIfPresent(String.self, forKey: .by) ?? "unknown"
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 0
        time = try container.decodeIfPresent(Int.self, forKey: .time) ?? 0
        url = try container.decodeIfPresent(String.self, forKey: .url)
        descendants = try container.decodeIfPresent(Int.self, forKey: .descendants) ?? 0
        kids = try container.decodeIfPresent([Int].self, forKey: .kids)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "story"
    }

    init(id: Int, title: String, by: String, score: Int, time: Int, url: String? = nil,
         descendants: Int = 0, kids: [Int]? = nil, text: String? = nil, type: String = "story") {
        self.id = id
        self.title = title
        self.by = by
        self.score = score
        self.time = time
        self.url = url
        self.descendants = descendants
        self.kids = kids
        self.text = text
        self.type = type
    }

    var postedDetails: String {
        let timestampText = timeAgoString(from: time)
        return "\(score) points by **\(by)** \(timestampText)"
    }

    /// Job posts have no `descendants` and often no comments at all, so the
    /// button falls back to an unnumbered label rather than claiming zero.
    var commentButtonTitle: String {
        let count = max(descendants, kids?.count ?? 0)
        return count > 0 ? "\(count) Comments" : "Comments"
    }
}

struct StoryRow: Codable, Hashable, Identifiable {
    let id: Int
    let title: String
    let score: Int
    let kids: [Int]
    let descendants: Int

    enum CodingKeys: String, CodingKey {
        case id, title, score, kids, descendants
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "(untitled)"
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 0
        kids = try container.decodeIfPresent([Int].self, forKey: .kids) ?? []
        descendants = try container.decodeIfPresent(Int.self, forKey: .descendants) ?? 0
    }

    init(id: Int, title: String, score: Int, kids: [Int], descendants: Int = 0) {
        self.id = id
        self.title = title
        self.score = score
        self.kids = kids
        self.descendants = descendants
    }
}

struct Comment: Codable, Identifiable, Hashable {
    let id: Int
    let by: String
    let text: String
    let time: Int
    let type: String
    let kids: [Int]?
    let deleted: Bool
    let dead: Bool

    enum CodingKeys: String, CodingKey {
        case id, by, text, time, type, kids, deleted, dead
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        by = try container.decodeIfPresent(String.self, forKey: .by) ?? "unknown"
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        time = try container.decodeIfPresent(Int.self, forKey: .time) ?? 0
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "comment"
        kids = try container.decodeIfPresent([Int].self, forKey: .kids)
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
        dead = try container.decodeIfPresent(Bool.self, forKey: .dead) ?? false
    }

    init(id: Int, by: String, text: String, time: Int, type: String, kids: [Int]? = nil,
         deleted: Bool = false, dead: Bool = false) {
        self.id = id
        self.by = by
        self.text = text
        self.time = time
        self.type = type
        self.kids = kids
        self.deleted = deleted
        self.dead = dead
    }

    /// Moderated, self-deleted, or empty comments are dropped before display.
    var isHidden: Bool {
        deleted || dead || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var formattedText: String {
        return text.htmlToPlainText()
    }

    var postedTime: String {
        return timeAgoString(from: time)
    }
}

// MARK: - Time Formatting

func timeAgoString(from unixTime: Int) -> String {
    let timeDifference = Date().timeIntervalSince1970 - Double(unixTime)

    if timeDifference < 60 {
        return "just now"
    } else if timeDifference < 3600 {
        let minutes = Int(timeDifference / 60)
        return "\(minutes)m ago"
    } else if timeDifference < 86400 {
        let hours = Int(timeDifference / 3600)
        return "\(hours)h ago"
    } else {
        let days = Int(timeDifference / 86400)
        return "\(days)d ago"
    }
}

// MARK: - HTML Processing

extension String {
    func htmlToPlainText() -> String {
        var result = self

        // Normalize line breaks in source
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")

        // Convert paragraph tags to double newlines
        result = result.replacingOccurrences(of: "<p>", with: "\n\n", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</p>", with: "", options: .caseInsensitive)

        // Convert line breaks
        result = result.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])

        // Handle code blocks - preserve formatting
        result = result.replacingOccurrences(of: "<pre><code>", with: "\n\n", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</code></pre>", with: "\n\n", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "<code>", with: "", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</code>", with: "", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "<pre>", with: "\n\n", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</pre>", with: "\n\n", options: .caseInsensitive)

        // Handle italic
        result = result.replacingOccurrences(of: "<i>", with: "", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</i>", with: "", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "<em>", with: "", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</em>", with: "", options: .caseInsensitive)

        // Handle bold
        result = result.replacingOccurrences(of: "<b>", with: "", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</b>", with: "", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "<strong>", with: "", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</strong>", with: "", options: .caseInsensitive)

        // Extract link text, discard href
        result = result.replacingOccurrences(of: "<a[^>]*>", with: "", options: [.regularExpression, .caseInsensitive])
        result = result.replacingOccurrences(of: "</a>", with: "", options: .caseInsensitive)

        // Remove any remaining HTML tags
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode HTML entities
        result = result.decodeHTMLEntities()

        // Clean up excessive newlines (3+ → 2)
        result = result.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

        // Trim
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    func decodeHTMLEntities() -> String {
        var result = self

        // Named entities
        let namedEntities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&lsquo;": "\u{2018}",
            "&rsquo;": "\u{2019}",
            "&ldquo;": "\u{201C}",
            "&rdquo;": "\u{201D}",
        ]
        for (entity, char) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        // Hex numeric entities: &#x27; &#x2F; etc.
        if let regex = try? NSRegularExpression(pattern: "&#x([0-9a-fA-F]+);", options: []) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let hexRange = match.range(at: 1)
                let hexStr = nsString.substring(with: hexRange)
                if let codePoint = UInt32(hexStr, radix: 16), let scalar = Unicode.Scalar(codePoint) {
                    result = (result as NSString).replacingCharacters(in: match.range, with: String(scalar))
                }
            }
        }

        // Decimal numeric entities: &#39; &#62; etc.
        if let regex = try? NSRegularExpression(pattern: "&#([0-9]+);", options: []) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let decRange = match.range(at: 1)
                let decStr = nsString.substring(with: decRange)
                if let codePoint = UInt32(decStr), let scalar = Unicode.Scalar(codePoint) {
                    result = (result as NSString).replacingCharacters(in: match.range, with: String(scalar))
                }
            }
        }

        return result
    }

}
