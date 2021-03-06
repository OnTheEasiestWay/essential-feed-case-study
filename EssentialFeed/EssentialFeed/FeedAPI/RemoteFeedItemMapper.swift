//
// Created by liuzhijin on 2020/11/5.
//

import Foundation

class RemoteFeedItemMapper {
    struct Root: Decodable {
        let items: [RemoteFeedItem]

        var feedItems: [FeedItem] {
            items.map { $0.item }
        }
    }

    struct RemoteFeedItem: Equatable, Decodable {
        let id: UUID
        let description: String?
        let location: String?
        let image: URL

        var item: FeedItem {
            FeedItem(id: id, description: description, location: location, imageURL: image)
        }
    }

    static func map(data: Data, response: HTTPURLResponse) -> RemoteFeedLoader.Result {
        guard response.statusCode == 200, let root = try? JSONDecoder().decode(Root.self, from: data) else {
            return .failure(RemoteFeedLoader.Error.invalidData)
        }

        return .success(root.feedItems)
    }
}
