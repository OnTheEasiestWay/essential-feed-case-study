//
//  RemoteFeedLoader.swift
//  EssentialFeed
//
//  Created by liuzhijin on 2020/11/5.
//

import Foundation

public class RemoteFeedLoader {
    private let url: URL
    private let client: HTTPClient

    public init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }

    public enum Error {
        case connectivity
        case invalidData
    }

    public enum Result {
        case success([FeedItem])
        case failure(Error)
    }

    public func load(completion: @escaping (Result) -> Void) {
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
