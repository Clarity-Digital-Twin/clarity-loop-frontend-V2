//
//  SampleViewModel.swift
//  clarity-loop-frontend-v2
//
//  Example implementation of BaseViewModel to demonstrate usage patterns
//

import Foundation
import Observation

// MARK: - Sample Data Models

struct Article: Equatable, Identifiable {
    let id: UUID
    let title: String
    let author: String
    let content: String
    let publishedAt: Date
    let tags: [String]
}

// MARK: - Sample Repository Protocol

protocol ArticleRepositoryProtocol {
    func fetchArticles(page: Int, pageSize: Int) async throws -> [Article]
    func searchArticles(query: String) async throws -> [Article]
    func fetchArticle(id: UUID) async throws -> Article?
}

// MARK: - Sample ViewModel Implementation

/// Example ViewModel showing how to extend BaseViewModel for a real feature
///
/// This example demonstrates:
/// - Proper dependency injection
/// - Overriding loadData() method
/// - Adding custom functionality (search, pagination)
/// - Proper error handling
@Observable
final class ArticleListViewModel: BaseViewModel<[Article]> {
    
    // MARK: - Properties
    
    private let repository: ArticleRepositoryProtocol
    private var currentPage = 1
    private let pageSize = 20
    
    /// Search query for filtering articles
    private(set) var searchQuery = ""
    
    /// Whether more articles can be loaded
    private(set) var hasMorePages = true
    
    /// Whether currently loading more articles (for pagination)
    private(set) var isLoadingMore = false
    
    // MARK: - Initialization
    
    init(repository: ArticleRepositoryProtocol) {
        self.repository = repository
        super.init()
    }
    
    // MARK: - Override Methods
    
    /// Load initial articles
    override func loadData() async throws -> [Article]? {
        // Reset pagination
        currentPage = 1
        hasMorePages = true
        
        // Load based on search query
        if searchQuery.isEmpty {
            return try await repository.fetchArticles(page: currentPage, pageSize: pageSize)
        } else {
            return try await repository.searchArticles(query: searchQuery)
        }
    }
    
    // MARK: - Public Methods
    
    /// Search for articles with the given query
    @MainActor
    func search(query: String) async {
        searchQuery = query
        await load() // Reload with new search query
    }
    
    /// Clear search and reload all articles
    @MainActor
    func clearSearch() async {
        searchQuery = ""
        await load()
    }
    
    /// Load more articles (pagination)
    @MainActor
    func loadMore() async {
        // Guard against multiple simultaneous loads
        guard !isLoadingMore,
              hasMorePages,
              searchQuery.isEmpty, // Don't paginate search results
              case .success(let currentArticles) = viewState else {
            return
        }
        
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        do {
            let nextPage = currentPage + 1
            let moreArticles = try await repository.fetchArticles(
                page: nextPage,
                pageSize: pageSize
            )
            
            if moreArticles.isEmpty {
                hasMorePages = false
            } else {
                currentPage = nextPage
                // Append to existing articles
                viewState = .success(currentArticles + moreArticles)
            }
        } catch {
            // Don't change main state for pagination errors
            // Could show a toast or inline error instead
            print("Failed to load more articles: \(error)")
        }
    }
    
    /// Refresh articles (pull to refresh)
    @MainActor
    override func reload() async {
        // Clear any pagination state
        hasMorePages = true
        await super.reload()
    }
}

// MARK: - Usage Example in SwiftUI

import SwiftUI

struct ArticleListView: View {
    @State private var viewModel: ArticleListViewModel
    @State private var searchText = ""
    
    init(repository: ArticleRepositoryProtocol) {
        self._viewModel = State(wrappedValue: ArticleListViewModel(repository: repository))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.viewState {
                case .idle:
                    Color.clear
                        .onAppear {
                            Task { await viewModel.load() }
                        }
                    
                case .loading:
                    ProgressView("Loading articles...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .success(let articles):
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(articles) { article in
                                ArticleRow(article: article)
                            }
                            
                            // Load more indicator
                            if viewModel.hasMorePages && viewModel.searchQuery.isEmpty {
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                        .padding()
                                } else {
                                    Color.clear
                                        .frame(height: 1)
                                        .onAppear {
                                            Task { await viewModel.loadMore() }
                                        }
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.reload()
                    }
                    
                case .error(let error):
                    ErrorView(error: error) {
                        Task { await viewModel.reload() }
                    }
                    
                case .empty:
                    ContentUnavailableView(
                        viewModel.searchQuery.isEmpty ? "No Articles" : "No Results",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(
                            viewModel.searchQuery.isEmpty
                                ? "There are no articles available."
                                : "No articles match '\(viewModel.searchQuery)'."
                        )
                    )
                }
            }
            .navigationTitle("Articles")
            .searchable(text: $searchText, prompt: "Search articles")
            .onSubmit(of: .search) {
                Task { await viewModel.search(query: searchText) }
            }
            .onChange(of: searchText) { _, newValue in
                if newValue.isEmpty {
                    Task { await viewModel.clearSearch() }
                }
            }
        }
    }
}

// MARK: - Supporting Views

private struct ArticleRow: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.headline)
            
            Text(article.author)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(article.content)
                .font(.body)
                .lineLimit(2)
            
            HStack {
                ForEach(article.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ErrorView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}