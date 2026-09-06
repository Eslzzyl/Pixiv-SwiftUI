import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var reorderToFill = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        FlowResult(
            in: proposal.width ?? .infinity,
            subviews: subviews,
            spacing: spacing,
            reorderToFill: reorderToFill
        ).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing,
            reorderToFill: reorderToFill
        )

        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: ProposedViewSize(width: nil, height: .infinity)
            )
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat, reorderToFill: Bool) {
            let sizes = subviews.map {
                $0.sizeThatFits(ProposedViewSize(width: nil, height: .infinity))
            }
            let availableWidth = maxWidth.isFinite ? max(0, maxWidth) : .infinity

            if reorderToFill {
                let rows = Self.makePackedRows(
                    sizes: sizes,
                    maxWidth: availableWidth,
                    spacing: spacing
                )
                positions = Array(repeating: .zero, count: subviews.count)

                var currentY: CGFloat = 0
                var contentWidth: CGFloat = 0

                for row in rows {
                    var currentX: CGFloat = 0
                    var lineHeight: CGFloat = 0

                    for index in row.indices {
                        positions[index] = CGPoint(x: currentX, y: currentY)
                        currentX += sizes[index].width + spacing
                        lineHeight = max(lineHeight, sizes[index].height)
                    }

                    contentWidth = max(contentWidth, max(0, currentX - spacing))
                    currentY += lineHeight + spacing
                }

                size.width = availableWidth.isFinite ? availableWidth : contentWidth
                size.height = max(0, currentY - spacing)
                return
            }

            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var contentWidth: CGFloat = 0

            for itemSize in sizes {
                if currentX + itemSize.width > availableWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, itemSize.height)
                currentX += itemSize.width + spacing
                contentWidth = max(contentWidth, max(0, currentX - spacing))
            }

            size.width = availableWidth.isFinite ? availableWidth : contentWidth
            size.height = sizes.isEmpty ? 0 : currentY + lineHeight
        }

        private struct PackedRow {
            var indices: [Int]
            var width: CGFloat
        }

        private static func makePackedRows(
            sizes: [CGSize],
            maxWidth: CGFloat,
            spacing: CGFloat
        ) -> [PackedRow] {
            guard !sizes.isEmpty else { return [] }
            guard maxWidth.isFinite else {
                let indices = Array(sizes.indices)
                return [PackedRow(
                    indices: indices,
                    width: rowWidth(indices: indices, sizes: sizes, spacing: spacing)
                )]
            }

            var rows = [PackedRow(indices: [0], width: sizes[0].width)]
            let remainingIndices = sizes.indices.dropFirst().sorted { lhs, rhs in
                if sizes[lhs].width == sizes[rhs].width {
                    return lhs < rhs
                }
                return sizes[lhs].width > sizes[rhs].width
            }

            for index in remainingIndices {
                let itemWidth = sizes[index].width
                var bestRowIndex: Int?
                var bestRemainingWidth = CGFloat.greatestFiniteMagnitude

                for rowIndex in rows.indices {
                    let addedWidth = rows[rowIndex].indices.isEmpty ? itemWidth : spacing + itemWidth
                    let candidateWidth = rows[rowIndex].width + addedWidth
                    guard candidateWidth <= maxWidth else { continue }

                    let remainingWidth = maxWidth - candidateWidth
                    if remainingWidth < bestRemainingWidth {
                        bestRowIndex = rowIndex
                        bestRemainingWidth = remainingWidth
                    }
                }

                if let bestRowIndex {
                    rows[bestRowIndex].indices.append(index)
                    rows[bestRowIndex].width += spacing + itemWidth
                } else {
                    rows.append(PackedRow(indices: [index], width: itemWidth))
                }
            }

            return rows
                .map { row in
                    let indices = row.indices.sorted()
                    return PackedRow(
                        indices: indices,
                        width: rowWidth(indices: indices, sizes: sizes, spacing: spacing)
                    )
                }
                .sorted { lhs, rhs in
                    (lhs.indices.first ?? .max) < (rhs.indices.first ?? .max)
                }
        }

        private static func rowWidth(indices: [Int], sizes: [CGSize], spacing: CGFloat) -> CGFloat {
            guard let firstIndex = indices.first else { return 0 }
            return indices.dropFirst().reduce(sizes[firstIndex].width) { width, index in
                width + spacing + sizes[index].width
            }
        }
    }
}
