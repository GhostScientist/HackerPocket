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
}

struct ContentView: View {

    @EnvironmentObject var authManager: HNAuthManager
    @EnvironmentObject var storyState: StoryStateModel
    @StateObject private var viewModel = StoriesViewModel()

    @AppStorage("selectedFeed") private var feed: Feed = .top
    @State private var navigationPath = NavigationPath()

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
                DetailView(number: story.id)
            }
            .navigationDestination(for: Int.self) { storyID in
                DetailView(number: storyID)
            }
            .navigationDestination(for: RootDestination.self) { destination in
                switch destination {
                case .actions:
                    RootActionsView(
                        isLoggedIn: authManager.isLoggedIn,
                        isRefreshing: viewModel.isLoading,
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
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: RootDestination.actions) {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More")
                    .accessibilityHint("Open account, saved story, and refresh actions.")
                }
            }
        }
        .onAppear {
            storyState.loadIfNeeded()
            viewModel.loadIfNeeded(feed: feed)
        }
        .onChange(of: feed) { _, newFeed in
            viewModel.select(newFeed)
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
            // `.navigationLink` style pushes a full-screen, Crown-scrollable
            // list of feeds — the standard watchOS affordance, and it leaves the
            // Crown free for scrolling stories on this screen.
            Picker("Feed", selection: $feed) {
                ForEach(Feed.allCases) { option in
                    Label(option.displayName, systemImage: option.symbolName)
                        .tag(option)
                }
            }
            .pickerStyle(.navigationLink)
            .font(.caption2)

            NavigationLink {
                SearchView()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
                    .font(.caption2)
            }

            NavigationLink {
                ReadHistoryView()
            } label: {
                Label("Read History", systemImage: "checkmark.circle")
                    .font(.caption2)
            }

            // Content is already on screen, so a failed refresh degrades to a
            // banner rather than replacing everything with an error screen.
            if let error = viewModel.error {
                InlineErrorView(error: error) {
                    viewModel.refresh()
                }
            } else if let updated = viewModel.lastUpdated {
                CacheStatusRow(updatedAt: updated, isRefreshing: viewModel.isRevalidating)
            }

            if !viewModel.hasContent && !viewModel.isLoading {
                Text("No stories in \(feed.displayName) right now.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.stories) { story in
                NavigationLink(value: story) {
                    StoryRowView(story: story)
                }
            }

            if viewModel.canLoadMore {
                LoadMoreRow(title: "Load More", isLoading: viewModel.isLoadingMore) {
                    viewModel.loadMore()
                }
            }
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
            NavigationLink(value: RootDestination.account) {
                Label(
                    isLoggedIn ? "Account" : "Sign In",
                    systemImage: isLoggedIn
                        ? "person.crop.circle.fill.badge.checkmark"
                        : "person.circle"
                )
            }

            NavigationLink(value: RootDestination.savedStories) {
                Label("Saved Stories", systemImage: "bookmark")
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

#Preview {
    ContentView()
        .environmentObject(HNAuthManager())
        .environmentObject(StoryStateModel())
}
