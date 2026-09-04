//
//  ContentView.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/23/24.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var authManager: HNAuthManager
    @EnvironmentObject var storyState: StoryStateModel
    @StateObject private var viewModel = StoriesViewModel()

    @AppStorage("selectedFeed") private var feed: Feed = .top

    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        if authManager.isLoggedIn {
                            AccountView()
                        } else {
                            LoginView()
                        }
                    } label: {
                        Image(systemName: authManager.isLoggedIn ? "person.crop.circle.fill.badge.checkmark" : "person.circle")
                            .foregroundStyle(authManager.isLoggedIn ? .green : .secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        NavigationLink {
                            SavedStoriesView()
                        } label: {
                            Image(systemName: "bookmark")
                        }
                        Button {
                            viewModel.refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isLoading)
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

#Preview {
    ContentView()
        .environmentObject(HNAuthManager())
        .environmentObject(StoryStateModel())
}
