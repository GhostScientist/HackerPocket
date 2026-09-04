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
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                ContentView()
                    .environmentObject(authManager)
            } else {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            }
        }
    }
}
