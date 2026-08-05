//
//  Math.swift
//
//
//  Created by Brian Floersch on 7/8/23.
//

// swiftlint:disable all
#if os(iOS)
import Foundation

func lerp(from: CGFloat, to: CGFloat, by: CGFloat) -> CGFloat {
    return from * (1 - by) + to * by
}

func normalize(from min: CGFloat, at val: CGFloat, to max: CGFloat) -> CGFloat {
    let v = (val - min) / (max - min)
    return v < 0 ? 0 : v > 1 ? 1 : v
}
#endif
// swiftlint:enable all
