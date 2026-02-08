//
//  OpenAppIntent.swift
//  HackerPocket Watch App
//
//  App Intent for opening the main app from complications
//

import AppIntents
import Foundation

struct OpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Hacker News"
    static var description = IntentDescription("Opens Hacker News to view top stories")
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
