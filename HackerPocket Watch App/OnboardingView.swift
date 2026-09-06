//
//  OnboardingView.swift
//  HackerPocket Watch App
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A moment for discovery")
                .font(.caption.weight(.semibold))
            Text("Swipe a story to save it, or tap the stacked cards below for a briefing of up to five stories.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Got It") {
                hasSeenOnboarding = true
            }
            .font(.caption)
            .frame(minHeight: 44)
            .tint(.orange)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
}
