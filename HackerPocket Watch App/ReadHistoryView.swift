//
//  ReadHistoryView.swift
//  HackerPocket Watch App
//

import SwiftUI

struct ReadHistoryView: View {
    @EnvironmentObject var storyState: StoryStateModel

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("\(storyState.readIDs.count) stories marked read")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Clear Read History", role: .destructive) {
                storyState.clearReadHistory()
            }
            .font(.caption2)
            .disabled(storyState.readIDs.isEmpty)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .navigationTitle("Read History")
        .onAppear {
            storyState.loadIfNeeded()
        }
    }
}

#Preview {
    NavigationStack {
        ReadHistoryView()
    }
    .environmentObject(StoryStateModel())
}
