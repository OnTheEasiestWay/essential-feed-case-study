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
        case invalidData
    }

    func load(completion: @escaping (Error) -> Void) {
        client.get(from: url) { result in
            switch (result) {
            case .success:
                completion(.invalidData)

            case .failure:
                completion(.connectivity)
            }
        }
    }
}

enum HTTPClientResult {
    case success(Data, URLResponse)
    case failure(Error)
}

protocol HTTPClient {
    func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void)
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
        let error = NSError(domain: "HTTPClient Error", code: -1)

        expect(sut, with: .connectivity, when: {
            client.complete(with: error)
        })
    }

    func test_load_failsOnNon200HTTPResponse() {
        let url = URL(string: "http://a-url.com")!
        let (sut, client) = makeSUT(url: url)
        let invalidCodes = [199, 201, 300, 400, 500]

        invalidCodes.enumerated().forEach { index, code in
            expect(sut, with: .invalidData, when: {
                client.complete(with: code, at: index)
            })
        }
    }

    // MARK: -- Helpers

    private func makeSUT(url: URL = URL(string: "http://any-url.com")!) -> (sut: RemoteFeedLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        return (sut: sut, client: client)
    }

    private func expect(_ sut: RemoteFeedLoader, with error: RemoteFeedLoader.Error, when action: () -> Void) {
        let exp = expectation(description: "Wait load to complete")
        var capturedError: RemoteFeedLoader.Error?
        sut.load() { error in
            capturedError = error
            exp.fulfill()
        }

        action()

        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(capturedError, error)
    }

    private class HTTPClientSpy: HTTPClient {
        var messages = [(url: URL, completion: (HTTPClientResult) -> Void)]()

        var requestedURLs: [URL] {
            messages.map { $0.url }
        }

        func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
            messages.append((url, completion))
        }

        func complete(with error: NSError, at index: Int = 0) {
            messages[index].completion(.failure(error));
        }

        func complete(with statusCode: Int, at index: Int = 0) {
            let data = Data("any data".utf8)
            let response = HTTPURLResponse(url: requestedURLs[index],
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil)!
            messages[index].completion(.success(data, response));
        }
    }
}
