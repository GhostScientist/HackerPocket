//
//  ContentView.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/23/24.
//

import SwiftUI

private enum RootDestination: Hashable {
    case actions
    case account
    case savedStories
    case feeds
    case briefing
}

struct ContentView: View {

    @EnvironmentObject var authManager: HNAuthManager
    @EnvironmentObject var storyState: StoryStateModel
    @StateObject private var viewModel = StoriesViewModel()

    @AppStorage("selectedFeed") private var feed: Feed = .top
    @AppStorage("hasSeenStoryHint") private var hasSeenStoryHint = false
    @State private var navigationPath = NavigationPath()
    @State private var briefingStories: [StoryRow] = []
    @State private var briefingFeed: Feed = .top
    @State private var briefingUpdatedAt: Date?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading && !viewModel.hasContent {
                    LoadingStateView(message: "Loading stories...")
                } else if let error = viewModel.error, !viewModel.hasContent {
                    ErrorStateView(error: error) {
                        viewModel.refresh()
                    }
                } else {
                    storyList
                }
            }
            .navigationTitle(feed.displayName)
            // Declared once for the whole stack so pushed screens (search)
            // share the same destination instead of redeclaring it.
            .navigationDestination(for: StoryRow.self) { story in
                DetailView(number: story.id, fallback: story.asStory)
            }
            .navigationDestination(for: Int.self) { storyID in
                DetailView(number: storyID)
            }
            .navigationDestination(for: RootDestination.self) { destination in
                switch destination {
                case .actions:
                    RootActionsView(
                        isLoggedIn: authManager.isLoggedIn,
                        isRefreshing: viewModel.isLoading || viewModel.isRevalidating,
                        refresh: viewModel.refresh
                    )
                case .account:
                    if authManager.isLoggedIn {
                        AccountView()
                    } else {
                        LoginView()
                    }
                case .savedStories:
                    SavedStoriesView()
                case .feeds:
                    List {
                        Picker("Feed", selection: $feed) {
                            ForEach(Feed.allCases) { option in
                                Label(option.displayName, systemImage: option.symbolName)
                                    .tag(option)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                    .navigationTitle("Feeds")
                case .briefing:
                    BriefingView(
                        stories: briefingStories,
                        feed: briefingFeed,
                        updatedAt: briefingUpdatedAt
                    ) {
                        navigationPath.removeLast()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: RootDestination.feeds) {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .accessibilityLabel("Change Feed")
                    .accessibilityValue(feed.displayName)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        // Freeze this session so refreshes cannot change its order or length.
                        briefingStories = Array(viewModel.stories.prefix(5))
                        briefingFeed = feed
                        briefingUpdatedAt = viewModel.lastUpdated
                        navigationPath.append(RootDestination.briefing)
                    } label: {
                        Image(systemName: "rectangle.stack")
                    }
                    .disabled(!viewModel.hasContent)
                    .accessibilityLabel("Briefing")
                    .accessibilityHint("Browse up to five stories from this feed.")

                    NavigationLink(value: RootDestination.savedStories) {
                        Image(systemName: "bookmark")
                    }
                    .accessibilityLabel("Saved Stories")

                    NavigationLink(value: RootDestination.actions) {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More")
                    .accessibilityHint("Open search, history, account, and refresh actions.")
                }
            }
        }
        .tint(.orange)
        .onAppear {
            storyState.loadIfNeeded()
            viewModel.loadIfNeeded(feed: feed)
        }
        .onChange(of: feed) { _, newFeed in
            viewModel.select(newFeed)
            navigationPath = NavigationPath()
        }
        .onOpenURL { url in
            guard url.scheme?.lowercased() == "hackerpocket",
                  url.host?.lowercased() == "story",
                  let storyID = url.pathComponents.dropFirst().first.flatMap(Int.init) else {
                return
            }
            navigationPath.append(storyID)
        }
    }

    private var storyList: some View {
        List {
            if !viewModel.hasContent && !viewModel.isLoading {
                Text("No stories in \(feed.displayName) right now.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.stories) { story in
                NavigationLink(value: story) {
                    StoryRowView(story: story)
                }
                .listRowBackground(Color.white.opacity(0.08))

                if story.id == viewModel.stories.first?.id {
                    if let error = viewModel.error {
                        InlineErrorView(error: error) {
                            viewModel.refresh()
                        }
                    } else if let updated = viewModel.lastUpdated {
                        CacheStatusRow(updatedAt: updated, isRefreshing: viewModel.isRevalidating)
                    }

                    if !hasSeenStoryHint {
                        OnboardingView(hasSeenOnboarding: $hasSeenStoryHint)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            if viewModel.canLoadMore {
                LoadMoreRow(title: "Load More", isLoading: viewModel.isLoadingMore) {
                    viewModel.loadMore()
                }
            }
            .containerBackground(.black, for: .navigation)
        }
    }
}

private struct RootActionsView: View {
    let isLoggedIn: Bool
    let isRefreshing: Bool
    let refresh: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            NavigationLink {
                SearchView()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }

            NavigationLink {
                ReadHistoryView()
            } label: {
                Label("Read History", systemImage: "checkmark.circle")
            }

            NavigationLink(value: RootDestination.account) {
                Label(
                    isLoggedIn ? "Account" : "Sign In",
                    systemImage: isLoggedIn
                        ? "person.crop.circle.fill.badge.checkmark"
                        : "person.circle"
                )
            }

            Button {
                refresh()
                dismiss()
            } label: {
                Label("Refresh Stories", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)
        }
        .navigationTitle("More")
    }
}

private struct BriefingView: View {
    let stories: [StoryRow]
    let feed: Feed
    let updatedAt: Date?
    let browseMore: () -> Void

    @EnvironmentObject private var storyState: StoryStateModel
    @State private var index = 0

    var body: some View {
        List {
            if stories.indices.contains(index) {
                let story = stories[index]

                Section {
                    NavigationLink(value: story) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(story.title)
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                            if let sourceDetails = story.sourceDetails {
                                Text(sourceDetails)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Label("Read Story", systemImage: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                } header: {
                    Text("\(feed.displayName) · \(index + 1) of \(stories.count)")
                        .monospacedDigit()
                        .accessibilityLabel("Story \(index + 1) of \(stories.count) from \(feed.displayName)")
                }

                Button {
                    if storyState.isSaved(story.id) {
                        storyState.unsave(story.id)
                    } else {
                        storyState.save(story)
                        WatchHaptics.success()
                    }
                } label: {
                    Label(
                        storyState.isSaved(story.id) ? "Unsave Story" : "Save Story",
                        systemImage: storyState.isSaved(story.id) ? "bookmark.fill" : "bookmark"
                    )
                }

                if !story.kids.isEmpty {
                    NavigationLink {
                        CommentsView(commentIds: story.kids, storyId: story.id)
                    } label: {
                        Label("Comments", systemImage: "bubble.left.and.bubble.right")
                    }
                }

                Button(index + 1 == stories.count ? "Finish Briefing" : "Next Story") {
                    index += 1
                }

                if let updatedAt {
                    CacheStatusRow(updatedAt: updatedAt, isRefreshing: false)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text(stories.isEmpty ? "No stories yet" : "Briefing complete")
                        .font(.headline)
                    Text("Browse more when you’re ready.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)

                Button("Browse More", action: browseMore)
            }

            if index > 0 {
                Button("Previous Story") {
                    index -= 1
                }
            }
        }
        // Reset only between briefing entries, never when returning from a story or thread.
        .id(index)
        .navigationTitle("Briefing")
        .containerBackground(.black, for: .navigation)
    }
}

#Preview {
    ContentView()
        .environmentObject(HNAuthManager())
        .environmentObject(StoryStateModel())
}

#Preview("Briefing · Large Text") {
    NavigationStack {
        BriefingView(
            stories: [
                StoryRow(
                    id: 1,
                    title: "Show HN: A small project with a long headline that needs room to breathe",
                    score: 123,
                    kids: [2],
                    descendants: 42
                )
            ],
            feed: .show,
            updatedAt: Date().addingTimeInterval(-3600),
            browseMore: {}
        )
    }
    .environmentObject(HNAuthManager())
    .environmentObject(StoryStateModel())
    .dynamicTypeSize(.accessibility2)
    .tint(.orange)
}
