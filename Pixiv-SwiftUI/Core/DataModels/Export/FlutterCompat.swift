import Foundation

enum FlutterDataFormat {
    case unknown
    case flutterSearchHistory
    case flutterGlanceHistory
    case flutterMuteData
    case swiftuiExport
}

struct FlutterCompat {
    static func detectFormat(from json: [String: Any]) -> FlutterDataFormat {
        if json["version"] is Int {
            if let typeStr = json["type"] as? String {
                switch typeStr {
                case "search_history":
                    return .swiftuiExport
                case "glance_history":
                    return .swiftuiExport
                case "mute_data":
                    return .swiftuiExport
                default:
                    return .unknown
                }
            }
        }

        if json["tagHisotry"] != nil || json["bookTags"] != nil {
            return .flutterSearchHistory
        }

        if json["banillustid"] is [[String: Any]],
           json["banuserid"] is [[String: Any]],
           json["bantag"] is [[String: Any]] {
            return .flutterMuteData
        }

        if let firstItem = json.values.first as? [[String: Any]],
           let first = firstItem.first,
           first["illust_id"] != nil || first["novel_id"] != nil {
            return .flutterGlanceHistory
        }

        return .unknown
    }

    static func parseFlutterSearchHistory(from json: [String: Any]) -> SearchHistoryExport? {
        var tagHistory: [TagHistoryItem] = []

        if let flutterTagHistory = json["tagHisotry"] as? [[String: Any]] {
            tagHistory = flutterTagHistory.compactMap { item -> TagHistoryItem? in
                guard let name = item["name"] as? String else { return nil }
                return TagHistoryItem(
                    name: name,
                    translatedName: item["translated_name"] as? String,
                    type: item["type"] as? Int
                )
            }
        }

        let bookTags: [String] = (json["bookTags"] as? [String]) ?? []

        return SearchHistoryExport(tagHistory: tagHistory, bookTags: bookTags)
    }

    static func parseFlutterGlanceHistory(from json: [String: Any]) -> GlanceHistoryExport? {
        var illustHistory: [IllustHistoryItem] = []
        var novelHistory: [NovelHistoryItem] = []

        for (key, value) in json {
            guard let items = value as? [[String: Any]] else { continue }

            switch key.lowercased() {
            case "illust_history", "illusthistory":
                illustHistory = items.compactMap { item -> IllustHistoryItem? in
                    guard let illustId = item["illust_id"] as? Int else { return nil }
                    let timeInterval = item["time"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)
                    return IllustHistoryItem(
                        illustId: illustId,
                        viewedAt: timeInterval,
                        title: item["title"] as? String,
                        userName: item["user_name"] as? String
                    )
                }

            case "novel_history", "novelhistory":
                novelHistory = items.compactMap { item -> NovelHistoryItem? in
                    guard let novelId = item["novel_id"] as? Int else { return nil }
                    let timeInterval = item["time"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)
                    return NovelHistoryItem(
                        novelId: novelId,
                        viewedAt: timeInterval,
                        title: item["title"] as? String,
                        userName: item["user_name"] as? String
                    )
                }

            default:
                break
            }
        }

        if illustHistory.isEmpty && novelHistory.isEmpty {
            return nil
        }

        return GlanceHistoryExport(illustHistory: illustHistory, novelHistory: novelHistory)
    }

    static func parseFlutterMuteData(from json: [String: Any]) -> MuteDataExport? {
        let banTags: [BanTagItem] = (json["bantag"] as? [[String: Any]] ?? json["ban_tags"] as? [[String: Any]] ?? []).compactMap { item in
            guard let name = item["name"] as? String else { return nil }
            return BanTagItem(
                name: name,
                translatedName: item["translateName"] as? String ?? item["translated_name"] as? String
            )
        }

        let banUserIds: [BanUserIdItem] = (json["banuserid"] as? [[String: Any]] ?? json["ban_user_ids"] as? [[String: Any]] ?? []).compactMap { item in
            guard let userId = item["user_id"] as? String ?? item["userId"] as? String else { return nil }
            return BanUserIdItem(
                userId: userId,
                name: item["name"] as? String
            )
        }

        let banIllustIds: [BanIllustIdItem] = (json["banillustid"] as? [[String: Any]] ?? json["ban_illust_ids"] as? [[String: Any]] ?? []).compactMap { item in
            guard let illustId = item["illust_id"] as? Int ?? item["illustId"] as? Int else { return nil }
            return BanIllustIdItem(
                illustId: illustId,
                name: item["name"] as? String
            )
        }

        return MuteDataExport(banTags: banTags, banUserIds: banUserIds, banIllustIds: banIllustIds)
    }
}
