//
//  RemoteFeedLoaderTests.swift
//  EssentialFeedTests
//
//  Created by liuzhijin on 2020/11/4.
//

import XCTest
import Foundation

class RemoteFeedLoader {
    private let url: URL
    private let client: HTTPClient

    init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }

    enum Error {
        case connectivity
    }

    func load(completion: @escaping (Error) -> Void) {
        client.get(from: url) { error in
            completion(.connectivity)
        }
    }
}


protocol HTTPClient {
    func get(from url: URL, completion: @escaping (Error) -> Void)
}

class RemoteFeedLoaderTests: XCTestCase {
    func test_init_doesNotRequestDataFromURL() {
        let (_, client) = makeSUT()

        XCTAssertEqual(client.requestedURLs, [])
    }

    func test_load_requestsDataFromURL() {
        let url = URL(string: "http://a-test-url.com")!
        let (sut, client) = makeSUT(url: url)

        sut.load() { _ in}

        XCTAssertEqual(client.requestedURLs, [url])
    }

    func test_load_loadTwiceRequestsDataFromURLTwice() {
        let url = URL(string: "http://a-test-url.com")!
        let (sut, client) = makeSUT(url: url)

        sut.load() { _ in}
        sut.load() { _ in}

        XCTAssertEqual(client.requestedURLs, [url, url])
    }

    func test_load_failsOnHTTPClientError() {
        let url = URL(string: "http://a-wrong-url.com")!
        let (sut, client) = makeSUT(url: url)
        client.error = NSError(domain: "HTTPClient Error", code: -1)

        var capturedError: RemoteFeedLoader.Error?
        sut.load() { error in
            capturedError = error
        }

        XCTAssertEqual(capturedError, .connectivity)
    }

    // MARK: -- Helpers

    private func makeSUT(url: URL = URL(string: "http://any-url.com")!) -> (sut: RemoteFeedLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        return (sut: sut, client: client)
    }

    private class HTTPClientSpy: HTTPClient {
        var requestedURLs = [URL]()
        var error: NSError?

        func get(from url: URL, completion: @escaping (Error) -> Void) {
            requestedURLs.append(url)
            if let error = error {
                completion(error)
            }
        }
    }
}
