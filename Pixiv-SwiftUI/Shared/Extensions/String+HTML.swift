import Foundation

extension String {
    func stripHTML() -> String {
        return TextCleaner.stripHTMLTags(self)
    }
}
