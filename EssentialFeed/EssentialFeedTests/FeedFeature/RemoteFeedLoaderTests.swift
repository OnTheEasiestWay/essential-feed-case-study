//
//  RemoteFeedLoaderTests.swift
//  EssentialFeedTests
//
//  Created by liuzhijin on 2020/11/4.
//

import XCTest
import Foundation
import EssentialFeed

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

    enum Result {
        case success([FeedItem])
        case failure(Error)
    }

    func load(completion: @escaping (Result) -> Void) {
        client.get(from: url) { result in
            switch (result) {
            case let .success(data, response):
                guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                      let root = try? JSONDecoder().decode(Root.self, from: data) else {
                    completion(.failure(.invalidData))
                    return
                }

                completion(.success(root.items))

            case .failure:
                completion(.failure(.connectivity))
            }
        }
    }
}

struct Root: Decodable {
    let items: [FeedItem]
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

    func test_load_succeedsOn200HTTPResponse() {
        let url = URL(string: "http://a-url.com")!
        let (sut, client) = makeSUT(url: url)
        let item1 = FeedItem(id: UUID(), description: nil, location: nil, imageURL: URL(string: "http://image-url1.com")!)
        let item1JSON = [
            "id": item1.id.uuidString,
            "description": item1.description,
            "location": item1.location,
            "image": item1.imageURL.absoluteString
        ].compactMapValues { $0 }
        
        let item2 = FeedItem(id: UUID(), description: "a description", location: "a location", imageURL: URL(string: "http:/image-url2.com")!)
        let item2JSON = [
            "id": item2.id.uuidString,
            "description": item2.description,
            "location": item2.location,
            "image": item2.imageURL.absoluteString
        ].compactMapValues { $0 }

        let itemsJSON = [
            "items": [
                item1JSON,
                item2JSON
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: itemsJSON)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

        let exp = expectation(description: "Wait load to complete")
        var capturedResult: [FeedItem]?
        sut.load { result in
            switch (result) {
            case let .success(items):
                capturedResult = items
            case .failure:
                XCTFail("Expected success, got \(result) instead", file: #filePath, line: #line)
            }
            exp.fulfill()
        }
        client.complete(with: (data: data, response: response))
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(capturedResult, [item1, item2])
    }

    // MARK: -- Helpers

    private func makeSUT(url: URL = URL(string: "http://any-url.com")!) -> (sut: RemoteFeedLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        return (sut: sut, client: client)
    }

    private func expect(_ sut: RemoteFeedLoader, with error: RemoteFeedLoader.Error, when action: () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "Wait load to complete")
        var capturedError: RemoteFeedLoader.Error?
        sut.load() { result in
            switch (result) {
            case let .failure(error):
                capturedError = error
            case .success:
                XCTFail("Expected failure, got \(result) instead", file: file, line: line)
            }
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

        func complete(with success: (data: Data, response: URLResponse), at index: Int = 0) {
            messages[index].completion(.success(success.data, success.response))
        }
    }
}
