//
//  HackerPocketApp.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/23/24.
//

import SwiftUI

@main
struct HackerPocket_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(HackerPocketAppDelegate.self) private var appDelegate
    @StateObject private var authManager = HNAuthManager()
    @StateObject private var storyState = StoryStateModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(storyState)
        }
    }
}
