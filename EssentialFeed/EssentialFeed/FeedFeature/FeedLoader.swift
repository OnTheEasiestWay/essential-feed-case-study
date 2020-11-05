//
//  FeedLoader.swift
//  EssentialFeed
//
//  Created by liuzhijin on 2020/11/3.
//

import Foundation

enum FeedLoaderResult {
    case success([FeedItem])
    case failure(Error)
}

protocol FeedLoader {
    func load(completion: @escaping (FeedLoaderResult) -> Void)
}
