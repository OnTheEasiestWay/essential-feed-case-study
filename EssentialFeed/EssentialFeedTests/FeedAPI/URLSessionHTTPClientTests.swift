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
        session.dataTask(with: url) { _, _, error in
            if let error = error {
                completion(.failure(error))
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

    func test_get_diliversErrorWithURLSessionError() {
        let expectedError = NSError(domain: "URLSession Error", code: -1)
        URLProtocolStub.stub(data: nil, response: nil, error: expectedError)

        let exp = expectation(description: "Wait get to complete")
        makeSUT().get(from: anyURL()) { result in
            switch result {
            case let .failure(capturedError as NSError):
                XCTAssertEqual(capturedError, expectedError)
            default:
                XCTFail("Expect to get failure, got \(result) instead")
            }

            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func test_get_diliversErrorWithURLSessionAllNilValues() {
        URLProtocolStub.stub(data: nil, response: nil, error: nil)

        let exp = expectation(description: "Wait get to complete")
        makeSUT().get(from: anyURL()) { result in
            switch result {
            case let .failure(error):
                XCTAssertNotNil(error)
            default:
                XCTFail("Expect to get failure, got \(result) instead")
            }

            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    // MARK: -- Helpers

    private func makeSUT() -> URLSessionHTTPClient {
        return URLSessionHTTPClient()
    }

    private func anyURL() -> URL {
        return URL(string: "http://any-url.com")!
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