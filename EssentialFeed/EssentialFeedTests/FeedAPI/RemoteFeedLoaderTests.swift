//
//  RemoteFeedLoaderTests.swift
//  EssentialFeedTests
//
//  Created by liuzhijin on 2020/11/4.
//

import XCTest
import Foundation
import EssentialFeed

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
        let (sut, client) = makeSUT()
        let error = NSError(domain: "HTTPClient Error", code: -1)

        expect(sut, with: failure(.connectivity), when: {
            client.completeWith(error: error)
        })
    }

    func test_load_failsOnNon200HTTPResponse() {
        let (sut, client) = makeSUT()
        let invalidCodes = [199, 201, 300, 400, 500]

        invalidCodes.enumerated().forEach { index, code in
            expect(sut, with: failure(.invalidData), when: {
                let data = Data("any data".utf8)
                client.completeWith(statusCode: code, data: data, at: index)
            })
        }
    }

    func test_load_failsOn200HTTPResponseWithInvalidData() {
        let (sut, client) = makeSUT()

        expect(sut, with: failure(.invalidData), when: {
            let data = Data("invalid json".utf8)
            client.completeWith(statusCode: 200, data: data)
        })
    }

    func test_load_succeedsOn200HTTPResponseWithEmptyJSONList() {
        let (sut, client) = makeSUT()

        expect(sut, with: .success([]), when: {
            let data = makeJSONData(from: [])
            client.completeWith(statusCode: 200, data: data)
        })
    }

    func test_load_succeedsOn200HTTPResponseWithJSONList() {
        let (sut, client) = makeSUT()
        let (item1, json1) = makeItem(
                id: UUID(),
                imageURL: URL(string: "http://image-url1.com")!)
        let (item2, json2) = makeItem(
                id: UUID(),
                description: "a description",
                location: "a location",
                imageURL: URL(string: "http:/image-url2.com")!)

        expect(sut, with: .success([item1, item2]), when: {
            let data = makeJSONData(from: [json1, json2])
            client.completeWith(statusCode: 200, data: data)
        })
    }

    func test_load_shouldNotCallCompletionClosureWhenSUTWasDeallocated() {
        let url = URL(string: "http://any-url.com")!
        let client = HTTPClientSpy()
        var sut: RemoteFeedLoader? = RemoteFeedLoader(url: url, client: client)
        let data = makeJSONData(from: [])
        var capturedResult: RemoteFeedLoader.Result?

        sut?.load() { capturedResult = $0 }
        sut = nil
        client.completeWith(statusCode: 200, data: data)

        XCTAssertNil(capturedResult)
    }

    // MARK: -- Helpers

    private func makeSUT(url: URL = URL(string: "http://any-url.com")!, file: StaticString = #filePath, line: UInt = #line) -> (sut: RemoteFeedLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)

        trackMemoryLeak(client, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)

        return (sut: sut, client: client)
    }

    private func failure(_ error: RemoteFeedLoader.Error) -> RemoteFeedLoader.Result {
        .failure(error)
    }

    private func makeItem(id: UUID, description: String? = nil, location: String? = nil, imageURL: URL) -> (model: FeedItem, json: [String: Any]) {
        let item = FeedItem(id: id, description: description, location: location, imageURL: imageURL)
        let json = [
            "id": item.id.uuidString,
            "description": item.description,
            "location": item.location,
            "image": item.imageURL.absoluteString
        ].compactMapValues { $0 }

        return (item, json)
    }

    private func makeJSONData(from jsons: [[String: Any]]) -> Data {
        let json = [
            "items": jsons
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)

        return data
    }

    private func expect(_ sut: RemoteFeedLoader, with expectedResult: RemoteFeedLoader.Result, when action: () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "Wait load to complete")

        sut.load() { receivedResult in
            switch (receivedResult, expectedResult) {
            case let (.success(receivedItems), .success(expectedItems)):
                XCTAssertEqual(receivedItems, expectedItems, file: file, line: line)
            case let (.failure(receivedError as RemoteFeedLoader.Error), .failure(expectedError as RemoteFeedLoader.Error)):
                XCTAssertEqual(receivedError, expectedError, file: file, line: line)
            default:
                XCTFail("Expected \(expectedResult), got \(receivedResult) instead", file: file, line: line)
            }
            exp.fulfill()
        }

        action()

        wait(for: [exp], timeout: 1.0)
    }

    private class HTTPClientSpy: HTTPClient {
        var messages = [(url: URL, completion: (HTTPClientResult) -> Void)]()

        var requestedURLs: [URL] {
            messages.map { $0.url }
        }

        func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
            messages.append((url, completion))
        }

        func completeWith(error: NSError, at index: Int = 0) {
            messages[index].completion(.failure(error));
        }

        func completeWith(statusCode: Int, data: Data, at index: Int = 0) {
            let response = HTTPURLResponse(url: requestedURLs[index],
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil)!
            messages[index].completion(.success(data, response));
        }
    }
}
