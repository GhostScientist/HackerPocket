//
//  OnboardingView.swift
//  HackerPocket Watch App
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool

    var body: some View {
        TabView {
            // Page 1: Welcome
            VStack(spacing: 12) {
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                Text("HackerWatch")
                    .font(.headline)
                Text("Hacker News on your wrist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()

            // Page 2: Features
            VStack(spacing: 10) {
                FeatureRow(icon: "list.bullet", text: "Browse top stories")
                FeatureRow(icon: "bubble.left.and.bubble.right", text: "Read & post comments")
                FeatureRow(icon: "iphone", text: "Read articles on watch or iPhone")
                FeatureRow(icon: "square.and.arrow.up", text: "Share with friends")
            }
            .padding(.horizontal, 4)

            // Page 3: Tips
            VStack(spacing: 10) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                Text("Quick Tips")
                    .font(.headline)
                Text("Tap comment text to expand it. Swipe left for more options.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()

            // Page 4: Get Started
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                Text("You're all set!")
                    .font(.headline)
                Button {
                    withAnimation {
                        hasSeenOnboarding = true
                    }
                } label: {
                    Text("Get Started")
                        .font(.footnote)
                        .fontWeight(.semibold)
                }
                .tint(.orange)
            }
            .padding()
        }
        .tabViewStyle(.verticalPage)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(width: 20)
            Text(text)
                .font(.caption2)
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
}
