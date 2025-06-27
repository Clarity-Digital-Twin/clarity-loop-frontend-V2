//
//  SampleViewModelTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for SampleViewModel demonstrating testing patterns
//

import XCTest
@testable import ClarityUI

final class SampleViewModelTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: ArticleListViewModel!
    private var mockRepository: MockArticleRepository!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        mockRepository = MockArticleRepository()
        sut = ArticleListViewModel(repository: mockRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    @MainActor
    func test_initialState_shouldBeIdle() {
        // Given/When - initial state
        
        // Then
        XCTAssertEqual(sut.viewState, .idle)
        XCTAssertEqual(sut.searchQuery, "")
        XCTAssertTrue(sut.hasMorePages)
        XCTAssertFalse(sut.isLoadingMore)
    }
    
    @MainActor
    func test_load_withArticles_shouldSetSuccessState() async {
        // Given
        let expectedArticles = [
            createArticle(title: "Article 1"),
            createArticle(title: "Article 2")
        ]
        mockRepository.mockArticles = expectedArticles
        
        // When
        await sut.load()
        
        // Then
        XCTAssertEqual(sut.viewState, .success(expectedArticles))
        XCTAssertTrue(mockRepository.fetchArticlesCalled)
        XCTAssertEqual(mockRepository.lastRequestedPage, 1)
    }
    
    @MainActor
    func test_load_withEmptyResult_shouldSetEmptyState() async {
        // Given
        mockRepository.mockArticles = []
        
        // When
        await sut.load()
        
        // Then
        XCTAssertEqual(sut.viewState, .empty)
    }
    
    @MainActor
    func test_load_withError_shouldSetErrorState() async {
        // Given
        mockRepository.shouldThrowError = true
        
        // When
        await sut.load()
        
        // Then
        if case .error(let error) = sut.viewState {
            XCTAssertTrue(error is MockArticleRepository.RepositoryError)
        } else {
            XCTFail("Expected error state")
        }
    }
    
    @MainActor
    func test_search_shouldLoadSearchResults() async {
        // Given
        let searchResults = [
            createArticle(title: "Search Result 1"),
            createArticle(title: "Search Result 2")
        ]
        mockRepository.mockSearchResults = searchResults
        
        // When
        await sut.search(query: "test query")
        
        // Then
        XCTAssertEqual(sut.searchQuery, "test query")
        XCTAssertEqual(sut.viewState, .success(searchResults))
        XCTAssertTrue(mockRepository.searchArticlesCalled)
        XCTAssertEqual(mockRepository.lastSearchQuery, "test query")
    }
    
    @MainActor
    func test_clearSearch_shouldReloadAllArticles() async {
        // Given
        await sut.search(query: "test")
        XCTAssertEqual(sut.searchQuery, "test")
        
        let allArticles = [createArticle(title: "All Articles")]
        mockRepository.mockArticles = allArticles
        
        // When
        await sut.clearSearch()
        
        // Then
        XCTAssertEqual(sut.searchQuery, "")
        XCTAssertEqual(sut.viewState, .success(allArticles))
        XCTAssertTrue(mockRepository.fetchArticlesCalled)
    }
    
    @MainActor
    func test_loadMore_shouldAppendArticles() async {
        // Given - Load initial articles
        let initialArticles = [
            createArticle(title: "Article 1"),
            createArticle(title: "Article 2")
        ]
        mockRepository.mockArticles = initialArticles
        await sut.load()
        
        // Setup more articles for page 2
        let moreArticles = [
            createArticle(title: "Article 3"),
            createArticle(title: "Article 4")
        ]
        mockRepository.mockArticles = moreArticles
        
        // When
        await sut.loadMore()
        
        // Then
        XCTAssertEqual(sut.viewState, .success(initialArticles + moreArticles))
        XCTAssertEqual(mockRepository.lastRequestedPage, 2)
        XCTAssertTrue(sut.hasMorePages)
    }
    
    @MainActor
    func test_loadMore_withEmptyResult_shouldSetHasMorePagesFalse() async {
        // Given - Load initial articles
        mockRepository.mockArticles = [createArticle(title: "Article 1")]
        await sut.load()
        
        // Setup empty result for page 2
        mockRepository.mockArticles = []
        
        // When
        await sut.loadMore()
        
        // Then
        XCTAssertFalse(sut.hasMorePages)
        // State should remain unchanged with original article
        XCTAssertEqual(sut.value?.count, 1)
    }
    
    @MainActor
    func test_loadMore_duringSearch_shouldNotLoad() async {
        // Given - Search is active
        await sut.search(query: "test")
        
        // When
        await sut.loadMore()
        
        // Then
        XCTAssertEqual(mockRepository.fetchArticlesCallCount, 0)
    }
    
    @MainActor
    func test_loadMore_whileLoadingMore_shouldNotLoadAgain() async {
        // Given - Initial load
        mockRepository.mockArticles = [createArticle(title: "Article 1")]
        await sut.load()
        
        // Setup delay for second load
        mockRepository.delay = 0.1
        
        // When - Call loadMore twice quickly
        let task1 = Task { await sut.loadMore() }
        let task2 = Task { await sut.loadMore() }
        
        await task1.value
        await task2.value
        
        // Then - Should only call repository once more (total 2 times)
        XCTAssertEqual(mockRepository.fetchArticlesCallCount, 2)
    }
    
    @MainActor
    func test_reload_shouldResetPaginationState() async {
        // Given - Load and then load more
        mockRepository.mockArticles = [createArticle(title: "Article 1")]
        await sut.load()
        await sut.loadMore()
        
        // When
        await sut.reload()
        
        // Then
        XCTAssertTrue(sut.hasMorePages)
        XCTAssertEqual(mockRepository.lastRequestedPage, 1)
    }
    
    // MARK: - Helpers
    
    private func createArticle(title: String) -> Article {
        Article(
            id: UUID(),
            title: title,
            author: "Test Author",
            content: "Test content",
            publishedAt: Date(),
            tags: ["test"]
        )
    }
}

// MARK: - Mock Repository

private final class MockArticleRepository: ArticleRepositoryProtocol {
    // Control properties
    var mockArticles: [Article] = []
    var mockSearchResults: [Article] = []
    var shouldThrowError = false
    var delay: TimeInterval = 0
    
    // Tracking properties
    var fetchArticlesCalled = false
    var fetchArticlesCallCount = 0
    var lastRequestedPage: Int?
    var searchArticlesCalled = false
    var lastSearchQuery: String?
    
    enum RepositoryError: Error {
        case testError
    }
    
    func fetchArticles(page: Int, pageSize: Int) async throws -> [Article] {
        fetchArticlesCalled = true
        fetchArticlesCallCount += 1
        lastRequestedPage = page
        
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw RepositoryError.testError
        }
        
        return mockArticles
    }
    
    func searchArticles(query: String) async throws -> [Article] {
        searchArticlesCalled = true
        lastSearchQuery = query
        
        if shouldThrowError {
            throw RepositoryError.testError
        }
        
        return mockSearchResults
    }
    
    func fetchArticle(id: UUID) async throws -> Article? {
        return mockArticles.first { $0.id == id }
    }
}