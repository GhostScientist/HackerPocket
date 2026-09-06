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

    @State private var webSession: ASWebAuthenticationSession?
    @State private var handoffURL: URL?
    @State private var handoffTitle = ""

    var fallback: Story? = nil

    private func openBrowser(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        // watchOS has no system Safari, so use its supported web presentation session.
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "hackerpocket") { _, _ in
        }
        session.prefersEphemeralWebBrowserSession = true
        webSession = session
        session.start()
    }

    private func activateHandoff(urlString: String, title: String) {
        guard let url = URL(string: urlString) else { return }
        handoffTitle = title
        handoffURL = url
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
        .background(.black)
        .tint(.orange)
        .navigationTitle("Story")
        .userActivity("NSUserActivityTypeBrowsingWeb", isActive: handoffURL != nil) { activity in
            activity.webpageURL = handoffURL
            activity.title = handoffTitle
        }
        .onDisappear {
            handoffURL = nil
        }
        .onAppear {
            storyState.loadIfNeeded()
            storyState.markRead(number)
            viewModel.loadIfNeeded(id: number, fallback: fallback)
        }
    }

    @ViewBuilder
    private func storyContent(_ story: Story) -> some View {
        Text(story.title)
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)

        if let domain = story.asRow.domain {
            Text(domain)
                .font(.footnote)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }

        Text(story.postedDetails)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        if let text = story.text {
            let plainText = text.htmlToPlainText()
            if !plainText.isEmpty {
                Text(plainText)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        Divider()

        VStack(spacing: 8) {
            if let kids = story.kids, !kids.isEmpty {
                NavigationLink {
                    CommentsView(commentIds: kids, storyId: story.id)
                } label: {
                    actionLabel(story.commentButtonTitle, systemImage: "bubble.left.and.bubble.right")
                }
                .tint(.orange)
            } else if story.descendants > 0 {
                // Search and older saved rows may know the count without comment IDs.
                Button {
                    openBrowser("https://news.ycombinator.com/item?id=\(story.id)")
                } label: {
                    actionLabel(story.commentButtonTitle, systemImage: "bubble.left.and.bubble.right")
                }
                .accessibilityHint("Read the discussion on Hacker News.")
            } else if story.type != "job" {
                NavigationLink {
                    CommentsView(commentIds: [], storyId: story.id)
                } label: {
                    actionLabel("Comments", systemImage: "bubble.left.and.bubble.right")
                }
            }

            Button {
                if storyState.isSaved(story.id) {
                    storyState.unsave(story.id)
                } else {
                    storyState.save(story.asRow)
                }
            } label: {
                actionLabel(
                    storyState.isSaved(story.id) ? "Unsave Story" : "Save Story",
                    systemImage: storyState.isSaved(story.id) ? "bookmark.fill" : "bookmark"
                )
            }
            .accessibilityHint(
                storyState.isSaved(story.id)
                    ? "Remove this story from saved stories."
                    : "Keep this story for later."
            )

            if let storyURL = story.url {
                Button {
                    openBrowser(storyURL)
                } label: {
                    actionLabel("Read Article", systemImage: "safari")
                }
                .tint(.gray.opacity(0.3))
                .accessibilityHint("Read this article in the watchOS web view.")

                Button {
                    activateHandoff(urlString: storyURL, title: story.title)
                } label: {
                    actionLabel("Handoff to iPhone", systemImage: "iphone")
                }
                .tint(.gray.opacity(0.3))
                .accessibilityHint("Make this article available through Handoff on a nearby iPhone.")

                if handoffURL != nil {
                    Text("On your nearby iPhone, open the App Switcher and look for Handoff. Both devices need Handoff enabled and the same Apple Account.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            NavigationLink {
                List {
                    let shareURL = story.url ?? "https://news.ycombinator.com/item?id=\(story.id)"
                    ShareLink(item: shareURL) {
                        actionLabel("Share", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        openBrowser("https://news.ycombinator.com/item?id=\(story.id)")
                    } label: {
                        actionLabel("View on HN", systemImage: "globe")
                    }
                }
                .navigationTitle("More Actions")
                .tint(.orange)
            } label: {
                actionLabel("More Actions", systemImage: "ellipsis")
            }
            .tint(.gray.opacity(0.3))
        }
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 36)
    }
}

#Preview {
    NavigationStack {
        DetailView(number: 39810320, fallback: Story(
            id: 39810320,
            title: "Ask HN: What small tools have made the biggest difference to your working day?",
            by: "curious_builder", score: 128,
            time: Int(Date().timeIntervalSince1970) - 3600,
            descendants: 42, kids: [1, 2],
            text: "I am interested in the quiet improvements: a script, a notebook, or a habit.<p>What have you kept using, and why?"
        ))
            .environmentObject(HNAuthManager())
            .environmentObject(StoryStateModel())
    }
}
