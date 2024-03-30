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
        // Desired Format: 174 points by iscream26 4 hours ago
        let currentTime = Date().timeIntervalSince1970
        let timeDifference = currentTime - Double(time)
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        
        var timestampText = ""
        
        if timeDifference < 3600 {
            let minutes = Int(timeDifference / 60)
            timestampText = "\(minutes)m ago"
        } else if timeDifference < 86400 {
            let hours = Int(timeDifference / 3600)
            timestampText = "\(hours)h ago"
        } else {
            let days = Int(timeDifference / 86400)
            timestampText = "\(days) days ago"
        }
        
        
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
    
    var textWithoutTags: String {
        return text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression, range: nil)
    }
    
    var postedTime: String {
        let currentTime = Date().timeIntervalSince1970
        let timeDifference = currentTime - Double(time)
        
        if timeDifference < 3600 {
            let minutes = Int(timeDifference / 60)
            return "Posted \(minutes)m ago"
        } else if timeDifference < 86400 {
            let hours = Int(timeDifference / 3600)
            return "Posted \(hours)h ago"
        } else {
            let days = Int(timeDifference / 86400)
            return "Posted \(days) days ago"
        }
    }
}


extension String {
    var textWithoutTags: String {
        return replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression, range: nil)
    }
    
    var decodingUnicodeCharacters: String { applyingTransform(.init("Hex-Any"), reverse: false) ?? "" }
    
    func unescape() -> String {
        let characters = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'"
        ]
        var str = self
        for (escaped, unescaped) in characters {
            str = str.replacingOccurrences(of: escaped, with: unescaped, options: NSString.CompareOptions.literal, range: nil)
        }
        return str
    }
}
