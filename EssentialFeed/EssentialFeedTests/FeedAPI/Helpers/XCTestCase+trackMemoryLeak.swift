//
//  XCTestCase+trackMemoryLeak.swift
//  EssentialFeedTests
//
//  Created by liuzhijin on 2020/11/5.
//

import XCTest

extension XCTestCase {
    func trackMemoryLeak(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should be nil, potential memory leak", file: file, line: line)
        }
    }
}
