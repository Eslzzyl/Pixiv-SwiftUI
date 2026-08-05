//
//  Collection+Extensons.swift
//
//
//  Created by Brian Floersch on 7/8/23.
//

// swiftlint:disable all
#if os(iOS)
import Foundation

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
#endif
// swiftlint:enable all
