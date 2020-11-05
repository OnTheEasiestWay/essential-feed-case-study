//
//  URLSessionHTTPClientTests.swift
//  EssentialFeedTests
//
//  Created by liuzhijin on 2020/11/5.
//

import XCTest

class URLSessionHTTPClient {
    private let session: URLSession

    init(session: URLSession = URLSession.shared) {
        self.session = session
    }

    func get(from url: URL) {
        session.dataTask(with: url) { _, _, _ in

        }.resume()
    }
}

class URLSessionHTTPClientTests: XCTestCase {
    func test_get_requestsDataFromURL() {
        URLProtocol.registerClass(URLProtocolStub.self)

        let url = URL(string: "http://any-url.com")!
        let sut = URLSessionHTTPClient()

        let exp = expectation(description: "Wait get to complete")
        URLProtocolStub.observer = { request in
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "GET")
            exp.fulfill()
        }

        sut.get(from: url)
        wait(for: [exp], timeout: 1.0)

        URLProtocol.unregisterClass(URLProtocolStub.self)
    }

    // MARK: -- Helpers

    class URLProtocolStub: URLProtocol {
        static var observer: ((URLRequest) -> Void)?

        override class func canInit(with task: URLSessionTask) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            client?.urlProtocolDidFinishLoading(self)

            if let observer = URLProtocolStub.observer {
                observer(self.request)
            }
        }

        override func stopLoading() {

        }
    }
}
