//
//  SearchView.swift
//  HackerPocket Watch App
//
//  Algolia-backed search. Text entry is whatever the watch offers —
//  dictation, Scribble, or the keyboard — via a plain TextField.
//

import SwiftUI

struct SearchView: View {

    @StateObject private var viewModel = SearchViewModel()
    @State private var query = ""

    var body: some View {
        List {
            TextField("Search stories", text: $query)
                .submitLabel(.search)
                .onSubmit { viewModel.search(query) }

            content
        }
        .navigationTitle("Search")
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearching {
            LoadingStateView(message: "Searching...")
                .listRowBackground(Color.clear)
        } else if let error = viewModel.error, viewModel.results.isEmpty {
            ErrorStateView(error: error) {
                viewModel.search(query)
            }
            .listRowBackground(Color.clear)
        } else if viewModel.results.isEmpty {
            if let completedQuery = viewModel.completedQuery {
                noResults(for: completedQuery)
            } else {
                recentSearches
            }
        } else {
            if let error = viewModel.error {
                InlineErrorView(error: error) {
                    viewModel.search(query)
                }
            }

            ForEach(viewModel.results) { story in
                NavigationLink(value: story) {
                    StoryRowView(story: story)
                }
            }
        }
    }

    private func noResults(for searchedQuery: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("No results")
                .font(.caption)
                .fontWeight(.semibold)

            Text("Nothing on Hacker News matches \u{201C}\(searchedQuery)\u{201D}.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var recentSearches: some View {
        if viewModel.recentSearches.isEmpty {
            Text("Search Hacker News stories by title.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        } else {
            Section("Recent") {
                ForEach(viewModel.recentSearches, id: \.self) { recent in
                    Button {
                        query = recent
                        viewModel.search(recent)
                    } label: {
                        Label(recent, systemImage: "clock.arrow.circlepath")
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }

                Button("Clear", role: .destructive) {
                    viewModel.clearRecentSearches()
                }
                .font(.caption2)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
            .navigationDestination(for: StoryRow.self) { story in
                DetailView(number: story.id)
            }
    }
    .environmentObject(HNAuthManager())
}
