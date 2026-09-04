//
//  ContentView.swift
//  HackerPocket Watch App
//
//  Created by Dakota Kim on 3/23/24.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var authManager: HNAuthManager
    @StateObject private var viewModel = StoriesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && !viewModel.hasContent {
                    LoadingStateView(message: "Loading stories...")
                } else if let error = viewModel.error, !viewModel.hasContent {
                    ErrorStateView(error: error) {
                        viewModel.refresh()
                    }
                } else if !viewModel.hasContent {
                    ErrorStateView(error: .notFound)
                } else {
                    storyList
                }
            }
            .navigationTitle("Hacker News")
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
                    Button {
                        viewModel.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .onAppear {
            viewModel.loadIfNeeded()
        }
    }

    private var storyList: some View {
        List {
            // Content is already on screen, so a failed refresh degrades to a
            // banner rather than replacing everything with an error screen.
            if let error = viewModel.error {
                InlineErrorView(error: error) {
                    viewModel.refresh()
                }
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
        .navigationDestination(for: StoryRow.self) { story in
            DetailView(number: story.id)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HNAuthManager())
}
