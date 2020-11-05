//
//  URLSessionHTTPClientTests.swift
//  EssentialFeedTests
//
//  Created by liuzhijin on 2020/11/5.
//

import XCTest
import EssentialFeed

class URLSessionHTTPClient {
    private let session: URLSession

    init(session: URLSession = URLSession.shared) {
        self.session = session
    }

    struct InvalidRepresentation: Error {}

    func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
            } else if let data = data, let response = response as? HTTPURLResponse {
                completion(.success(data, response))
            } else {
                completion(.failure(InvalidRepresentation()))
            }
        }.resume()
    }
}

class URLSessionHTTPClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocolStub.startInterceptingRequest()
    }

    override func tearDown() {
        URLProtocolStub.stopInterceptingRequest()
        super.tearDown()
    }

    func test_get_requestsDataFromURL() {
        let url = anyURL()

        let exp = expectation(description: "Wait get to complete")
        URLProtocolStub.observer = { request in
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "GET")
            exp.fulfill()
        }

        makeSUT().get(from: url) { _ in }
        wait(for: [exp], timeout: 1.0)
    }

    func test_get_deliversErrorWithURLSessionError() {
        let expectedError = NSError(domain: "URLSession Error", code: -1)
        let receivedError = expectErrorFor(data: nil, response: nil, error: expectedError)
        XCTAssertEqual(receivedError as NSError?, expectedError)
    }

    func test_get_deliversErrorWithURLSessionAllInvalidRepresentations() {
        XCTAssertNotNil(expectErrorFor(data: nil, response: nil, error: nil))
        XCTAssertNotNil(expectErrorFor(data: nil, response: anyURLResponse(), error: nil))
        XCTAssertNotNil(expectErrorFor(data: anyData(), response: nil, error: nil))
        XCTAssertNotNil(expectErrorFor(data: anyData(), response: nil, error: anyNSError()))
        XCTAssertNotNil(expectErrorFor(data: nil, response: anyURLResponse(), error: anyNSError()))
        XCTAssertNotNil(expectErrorFor(data: nil, response: anyHTTPURLResponse(), error: anyNSError()))
        XCTAssertNotNil(expectErrorFor(data: anyData(), response: anyURLResponse(), error: anyNSError()))
        XCTAssertNotNil(expectErrorFor(data: anyData(), response: anyHTTPURLResponse(), error: anyNSError()))
        XCTAssertNotNil(expectErrorFor(data: anyData(), response: anyURLResponse(), error: nil))
    }

    func test_get_deliversSuccessWithURLSessionValidData() {
        let expectedData = anyData()
        let expectedResponse = anyHTTPURLResponse()
        let receivedValues = expectValuesFor(data: expectedData, response: expectedResponse, error: nil)

        XCTAssertEqual(receivedValues?.data, expectedData)
        XCTAssertEqual(receivedValues?.response.statusCode, expectedResponse.statusCode)
        XCTAssertEqual(receivedValues?.response.url, expectedResponse.url)
    }

    func test_get_deliversSuccessWithURLSessionNilDataAndHTTPResponse() {
        let expectedResponse = anyHTTPURLResponse()
        let receivedValues = expectValuesFor(data: nil, response: expectedResponse, error: nil)

        let emptyData = Data()
        XCTAssertEqual(receivedValues?.data, emptyData)
        XCTAssertEqual(receivedValues?.response.statusCode, expectedResponse.statusCode)
        XCTAssertEqual(receivedValues?.response.url, expectedResponse.url)
    }

    // MARK: -- Helpers

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> URLSessionHTTPClient {
        let sut = URLSessionHTTPClient()
        trackMemoryLeak(sut, file: file, line: line)
        return sut
    }

    private func trackMemoryLeak(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should be nil, potential memory leak", file: file, line: line)
        }
    }

    private func anyURL() -> URL {
        return URL(string: "http://any-url.com")!
    }

    private func anyData() -> Data {
        return Data("any data".utf8)
    }

    private func anyNSError() -> NSError {
        return NSError(domain: "URLSession Error", code: -1)
    }

    private func anyURLResponse() -> URLResponse {
        return URLResponse(url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    }

    private func anyHTTPURLResponse() -> HTTPURLResponse {
        return HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    private func expectResultFor(data: Data?, response: URLResponse?, error: Error?, file: StaticString = #filePath, line: UInt = #line) -> HTTPClientResult {
        URLProtocolStub.stub(data: data, response: response, error: error)

        let exp = expectation(description: "Wait get to complete")
        var receivedResult: HTTPClientResult!
        makeSUT().get(from: anyURL()) { result in
            receivedResult = result
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
        return receivedResult
    }

    private func expectErrorFor(data: Data?, response: URLResponse?, error: Error?, file: StaticString = #filePath, line: UInt = #line) -> Error? {
        let result = expectResultFor(data: data, response: response, error: error)

        switch result {
        case let .failure(error):
            return error
        default:
            XCTFail("Expect to get failure, got \(result) instead", file: file, line: line)
            return nil
        }
    }

    private func expectValuesFor(data: Data?, response: URLResponse?, error: Error?, file: StaticString = #filePath, line: UInt = #line) -> (data: Data, response: HTTPURLResponse)? {
        let result = expectResultFor(data: data, response: response, error: error)

        switch result {
        case let .success(receivedData, receivedResponse):
            return (data: receivedData, response: receivedResponse)
        case .failure:
            XCTFail("Expect to get success, got \(result) instead", file: file, line: line)
            return nil
        }
    }

    class URLProtocolStub: URLProtocol {
        static var observer: ((URLRequest) -> Void)?

        struct Stub {
            let data: Data?
            let response: URLResponse?
            let error: Error?
        }
        static var stub: Stub?

        class func stub(data: Data?, response: URLResponse?, error: Error?) {
            URLProtocolStub.stub = Stub(data: data, response: response, error:error)
        }

        class func startInterceptingRequest() {
            URLProtocol.registerClass(URLProtocolStub.self)
        }

        class func stopInterceptingRequest() {
            URLProtocol.unregisterClass(URLProtocolStub.self)
            URLProtocolStub.observer = nil
            URLProtocolStub.stub = nil
        }

        override class func canInit(with task: URLSessionTask) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            if let response = URLProtocolStub.stub?.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }

            if let data = URLProtocolStub.stub?.data {
                client?.urlProtocol(self, didLoad: data)
            }

            if let error = URLProtocolStub.stub?.error {
                client?.urlProtocol(self, didFailWithError: error)
            } else {
                client?.urlProtocolDidFinishLoading(self)
            }

            if let observer = URLProtocolStub.observer {
                observer(self.request)
            }
        }

        override func stopLoading() {

        }
    }
}
