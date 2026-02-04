//
//  types.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/24/24.
//

import Foundation

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

    var postedDetails: String {
        let timestampText = timeAgoString(from: time)
        return "\(score) points by **\(by)** \(timestampText)"
    }
}

struct StoryRow: Codable, Hashable {
    let id: Int
    let title: String
    let score: Int
    let kids: [Int]
}

struct Comment: Codable, Identifiable {
    let id: Int
    let by: String
    let text: String
    let time: Int
    let type: String

    var formattedText: String {
        return text.htmlToPlainText()
    }

    // Keep legacy accessor for compatibility
    var textWithoutTags: String {
        return formattedText
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

    // Legacy accessors
    var textWithoutTags: String {
        return htmlToPlainText()
    }

    var decodingUnicodeCharacters: String {
        applyingTransform(.init("Hex-Any"), reverse: false) ?? ""
    }

    func unescape() -> String {
        return decodeHTMLEntities()
    }
}
