//
//  DetailView.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/24/24.
//

import SwiftUI
import AuthenticationServices

struct DetailView: View {
    let number: Int

    @EnvironmentObject var authManager: HNAuthManager
    @EnvironmentObject var storyState: StoryStateModel
    @StateObject private var viewModel = StoryDetailViewModel()

    @AppStorage("hasSeenWebViewTip") private var hasSeenWebViewTip = false
    @State private var webSession: ASWebAuthenticationSession?
    @State private var showWebViewTip = false
    @State private var pendingURL: String?

    var fallback: Story? = nil

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "hackerpocket") { _, _ in
            // Browser dismissed - no action needed
        }
        session.prefersEphemeralWebBrowserSession = true
        webSession = session // Retain the session
        session.start()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let story = viewModel.story {
                    storyContent(story)
                } else if let error = viewModel.error {
                    ErrorStateView(error: error) {
                        viewModel.load(id: number, fallback: fallback)
                    }
                } else {
                    LoadingStateView(message: "Loading story...")
                }
            }
            .padding()
        }
        .navigationTitle("Story")
        .alert("Quick Tip", isPresented: $showWebViewTip) {
            Button("Got it") {
                hasSeenWebViewTip = true
                if let url = pendingURL {
                    openURL(url)
                    pendingURL = nil
                }
            }
        } message: {
            Text("If a site doesn't load correctly, tap the URL bar, switch to Reader Mode, then back to Web View to reload the page.")
        }
        .userActivity("NSUserActivityTypeBrowsingWeb", isActive: viewModel.story?.url != nil) { activity in
            if let urlString = viewModel.story?.url, let url = URL(string: urlString) {
                activity.webpageURL = url
                activity.isEligibleForHandoff = true
                activity.title = viewModel.story?.title
            }
        }
        .onAppear {
            storyState.loadIfNeeded()
            storyState.markRead(number)
            viewModel.loadIfNeeded(id: number, fallback: fallback)
        }
    }

    @ViewBuilder
    private func storyContent(_ story: Story) -> some View {
        // Title
        Text(story.title)
            .font(.headline)

        // Metadata
        Text(.init(story.postedDetails))
            .font(.caption2)
            .foregroundStyle(.secondary)

        // Source URL display
        if let url = story.url {
            if let host = URL(string: url)?.host {
                Text(host)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }

        Divider()

        // Action buttons
        VStack(spacing: 8) {
            if let storyURL = story.url {
                Button {
                    if !hasSeenWebViewTip {
                        pendingURL = storyURL
                        showWebViewTip = true
                    } else {
                        openURL(storyURL)
                    }
                } label: {
                    Label("Read Article", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                        .font(.caption)
                }
                .tint(.orange)
            }

            if let kids = story.kids, !kids.isEmpty {
                NavigationLink {
                    CommentsView(commentIds: kids, storyId: story.id)
                } label: {
                    // Job posts and some dead items carry no `descendants` even
                    // when they have kids, so never render "0 Comments".
                    Label(story.commentButtonTitle, systemImage: "bubble.left.and.bubble.right")
                        .frame(maxWidth: .infinity)
                        .font(.caption)
                }
                .tint(.blue)
            }

            let shareUrl: String = story.url ?? "https://news.ycombinator.com/item?id=\(story.id)"
            ShareLink(item: shareUrl) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .font(.caption)
            }
            .tint(.gray)

            // Open on HN
            Button {
                openURL("https://news.ycombinator.com/item?id=\(story.id)")
            } label: {
                Label("View on HN", systemImage: "globe")
                    .frame(maxWidth: .infinity)
                    .font(.caption)
            }
            .tint(.orange.opacity(0.7))
        }

        // Story text content (for Ask HN, Show HN, etc.)
        if let text = story.text, !text.isEmpty {
            Divider()
            Text(text.htmlToPlainText())
                .font(.caption2)
        }
    }
}

#Preview {
    NavigationStack {
        DetailView(number: 39810320)
            .environmentObject(HNAuthManager())
            .environmentObject(StoryStateModel())
    }
}
