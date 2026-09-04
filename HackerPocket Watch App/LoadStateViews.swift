//
//  LoadStateViews.swift
//  HackerPocket Watch App
//
//  Shared loading / error / pagination affordances.
//

import SwiftUI

struct LoadingStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ErrorStateView: View {
    let error: HNError
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: error.symbolName)
                .font(.title3)
                .foregroundStyle(.orange)

            Text(error.shortDescription)
                .font(.caption)
                .fontWeight(.semibold)

            Text(error.errorDescription ?? "Something went wrong.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let retry, error.isRetryable {
                Button("Try Again", action: retry)
                    .font(.caption2)
                    .tint(.orange)
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
    }
}

/// Inline banner for a failure that happened while content is already on screen.
struct InlineErrorView: View {
    let error: HNError
    var retry: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: error.symbolName)
                .font(.caption2)
                .foregroundStyle(.orange)

            Text(error.shortDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            if let retry, error.isRetryable {
                Button("Retry", action: retry)
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(.orange)
            }
        }
    }
}

/// How old the rows on screen are, plus whether a revalidation is running
/// behind them. Cached content renders before the network answers, so without
/// this the list can silently be hours stale.
struct CacheStatusRow: View {
    let updatedAt: Date
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isRefreshing {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .listRowBackground(Color.clear)
    }

    private var label: String {
        isRefreshing
            ? "Updating…"
            : "Updated \(timeAgoString(from: Int(updatedAt.timeIntervalSince1970)))"
    }
}

struct LoadMoreRow: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                if isLoading {
                    ProgressView()
                } else {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

#Preview("Error") {
    ErrorStateView(error: .offline, retry: {})
}

#Preview("Load more") {
    LoadMoreRow(title: "Load 20 More", isLoading: false, action: {})
}
