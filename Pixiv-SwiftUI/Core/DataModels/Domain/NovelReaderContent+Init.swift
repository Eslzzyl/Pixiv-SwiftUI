import Foundation

extension NovelReaderContent {
    init(
        id: Int,
        title: String,
        seriesId: Int? = nil,
        seriesTitle: String? = nil,
        seriesIsWatched: Bool? = nil,
        userId: Int,
        coverUrl: String? = nil,
        tags: [String],
        caption: String,
        createDate: String,
        totalView: Int,
        totalBookmarks: Int,
        isBookmarked: Bool? = nil,
        xRestrict: Int? = nil,
        novelAIType: Int? = nil,
        marker: String? = nil,
        text: String,
        illusts: [NovelIllustData]? = nil,
        images: [NovelUploadedImage]? = nil,
        seriesNavigation: SeriesNavigation? = nil
    ) {
        self.id = id
        self.title = title
        self.seriesId = seriesId
        self.seriesTitle = seriesTitle
        self.seriesIsWatched = seriesIsWatched
        self.userId = userId
        self.coverUrl = coverUrl
        self.tags = tags
        self.caption = caption
        self.createDate = createDate
        self.totalView = totalView
        self.totalBookmarks = totalBookmarks
        self.isBookmarked = isBookmarked
        self.xRestrict = xRestrict
        self.novelAIType = novelAIType
        self.marker = marker
        self.text = text
        self.illusts = illusts
        self.images = images
        self.seriesNavigation = seriesNavigation
    }
}
