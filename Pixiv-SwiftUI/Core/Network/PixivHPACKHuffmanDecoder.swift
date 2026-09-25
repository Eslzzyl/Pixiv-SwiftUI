import Foundation

nonisolated enum PixivHPACKHuffmanDecoder {
    private static let symbolByCode: [UInt64: UInt16] = {
        var symbols: [UInt64: UInt16] = [:]
        for (symbol, codeword) in codewords.enumerated() {
            let bitCount = codeword >> 32
            let code = codeword & 0xffff_ffff
            symbols[(bitCount << 32) | code] = UInt16(symbol)
        }
        return symbols
    }()

    private static let codewords: [UInt64] = [
        0xd00001ff8, 0x17007fffd8, 0x1c0fffffe2, 0x1c0fffffe3, 0x1c0fffffe4, 0x1c0fffffe5, 0x1c0fffffe6, 0x1c0fffffe7,
        0x1c0fffffe8, 0x1800ffffea, 0x1e3ffffffc, 0x1c0fffffe9, 0x1c0fffffea, 0x1e3ffffffd, 0x1c0fffffeb, 0x1c0fffffec,
        0x1c0fffffed, 0x1c0fffffee, 0x1c0fffffef, 0x1c0ffffff0, 0x1c0ffffff1, 0x1c0ffffff2, 0x1e3ffffffe, 0x1c0ffffff3,
        0x1c0ffffff4, 0x1c0ffffff5, 0x1c0ffffff6, 0x1c0ffffff7, 0x1c0ffffff8, 0x1c0ffffff9, 0x1c0ffffffa, 0x1c0ffffffb,
        0x600000014, 0xa000003f8, 0xa000003f9, 0xc00000ffa, 0xd00001ff9, 0x600000015, 0x8000000f8, 0xb000007fa,
        0xa000003fa, 0xa000003fb, 0x8000000f9, 0xb000007fb, 0x8000000fa, 0x600000016, 0x600000017, 0x600000018,
        0x500000000, 0x500000001, 0x500000002, 0x600000019, 0x60000001a, 0x60000001b, 0x60000001c, 0x60000001d,
        0x60000001e, 0x60000001f, 0x70000005c, 0x8000000fb, 0xf00007ffc, 0x600000020, 0xc00000ffb, 0xa000003fc,
        0xd00001ffa, 0x600000021, 0x70000005d, 0x70000005e, 0x70000005f, 0x700000060, 0x700000061, 0x700000062,
        0x700000063, 0x700000064, 0x700000065, 0x700000066, 0x700000067, 0x700000068, 0x700000069, 0x70000006a,
        0x70000006b, 0x70000006c, 0x70000006d, 0x70000006e, 0x70000006f, 0x700000070, 0x700000071, 0x700000072,
        0x8000000fc, 0x700000073, 0x8000000fd, 0xd00001ffb, 0x130007fff0, 0xd00001ffc, 0xe00003ffc, 0x600000022,
        0xf00007ffd, 0x500000003, 0x600000023, 0x500000004, 0x600000024, 0x500000005, 0x600000025, 0x600000026,
        0x600000027, 0x500000006, 0x700000074, 0x700000075, 0x600000028, 0x600000029, 0x60000002a, 0x500000007,
        0x60000002b, 0x700000076, 0x60000002c, 0x500000008, 0x500000009, 0x60000002d, 0x700000077, 0x700000078,
        0x700000079, 0x70000007a, 0x70000007b, 0xf00007ffe, 0xb000007fc, 0xe00003ffd, 0xd00001ffd, 0x1c0ffffffc,
        0x14000fffe6, 0x16003fffd2, 0x14000fffe7, 0x14000fffe8, 0x16003fffd3, 0x16003fffd4, 0x16003fffd5, 0x17007fffd9,
        0x16003fffd6, 0x17007fffda, 0x17007fffdb, 0x17007fffdc, 0x17007fffdd, 0x17007fffde, 0x1800ffffeb, 0x17007fffdf,
        0x1800ffffec, 0x1800ffffed, 0x16003fffd7, 0x17007fffe0, 0x1800ffffee, 0x17007fffe1, 0x17007fffe2, 0x17007fffe3,
        0x17007fffe4, 0x15001fffdc, 0x16003fffd8, 0x17007fffe5, 0x16003fffd9, 0x17007fffe6, 0x17007fffe7, 0x1800ffffef,
        0x16003fffda, 0x15001fffdd, 0x14000fffe9, 0x16003fffdb, 0x16003fffdc, 0x17007fffe8, 0x17007fffe9, 0x15001fffde,
        0x17007fffea, 0x16003fffdd, 0x16003fffde, 0x1800fffff0, 0x15001fffdf, 0x16003fffdf, 0x17007fffeb, 0x17007fffec,
        0x15001fffe0, 0x15001fffe1, 0x16003fffe0, 0x15001fffe2, 0x17007fffed, 0x16003fffe1, 0x17007fffee, 0x17007fffef,
        0x14000fffea, 0x16003fffe2, 0x16003fffe3, 0x16003fffe4, 0x17007ffff0, 0x16003fffe5, 0x16003fffe6, 0x17007ffff1,
        0x1a03ffffe0, 0x1a03ffffe1, 0x14000fffeb, 0x130007fff1, 0x16003fffe7, 0x17007ffff2, 0x16003fffe8, 0x1901ffffec,
        0x1a03ffffe2, 0x1a03ffffe3, 0x1a03ffffe4, 0x1b07ffffde, 0x1b07ffffdf, 0x1a03ffffe5, 0x1800fffff1, 0x1901ffffed,
        0x130007fff2, 0x15001fffe3, 0x1a03ffffe6, 0x1b07ffffe0, 0x1b07ffffe1, 0x1a03ffffe7, 0x1b07ffffe2, 0x1800fffff2,
        0x15001fffe4, 0x15001fffe5, 0x1a03ffffe8, 0x1a03ffffe9, 0x1c0ffffffd, 0x1b07ffffe3, 0x1b07ffffe4, 0x1b07ffffe5,
        0x14000fffec, 0x1800fffff3, 0x14000fffed, 0x15001fffe6, 0x16003fffe9, 0x15001fffe7, 0x15001fffe8, 0x17007ffff3,
        0x16003fffea, 0x16003fffeb, 0x1901ffffee, 0x1901ffffef, 0x1800fffff4, 0x1800fffff5, 0x1a03ffffea, 0x17007ffff4,
        0x1a03ffffeb, 0x1b07ffffe6, 0x1a03ffffec, 0x1a03ffffed, 0x1b07ffffe7, 0x1b07ffffe8, 0x1b07ffffe9, 0x1b07ffffea,
        0x1b07ffffeb, 0x1c0ffffffe, 0x1b07ffffec, 0x1b07ffffed, 0x1b07ffffee, 0x1b07ffffef, 0x1b07fffff0, 0x1a03ffffee,
        0x1e3fffffff,
    ]

    static func decode(_ data: Data) throws -> Data {
        var result = Data()
        var code: UInt32 = 0
        var bitCount = 0

        for byte in data {
            for bitIndex in (0..<8).reversed() {
                code = (code << 1) | UInt32((byte >> bitIndex) & 1)
                bitCount += 1
                guard bitCount <= 30 else {
                    throw PixivDirectConnectionError.qpackDecompressionFailed
                }

                let key = (UInt64(bitCount) << 32) | UInt64(code)
                if let symbol = symbolByCode[key] {
                    guard symbol < 256 else {
                        throw PixivDirectConnectionError.qpackDecompressionFailed
                    }
                    result.append(UInt8(symbol))
                    code = 0
                    bitCount = 0
                }
            }
        }

        if bitCount > 0 {
            let padding = (UInt32(1) << UInt32(bitCount)) - 1
            guard bitCount <= 7, code == padding else {
                throw PixivDirectConnectionError.qpackDecompressionFailed
            }
        }
        return result
    }
}
