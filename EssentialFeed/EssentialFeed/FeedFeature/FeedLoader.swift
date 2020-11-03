//
//  FeedLoader.swift
//  EssentialFeed
//
//  Created by liuzhijin on 2020/11/3.
//

import Foundation

enum Result {
    case success([FeedItem])
    case failure(Error)
}

protocol FeedLoader {
    func load(completion: @escaping (Result) -> Void)
}
