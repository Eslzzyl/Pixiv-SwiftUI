struct GoogleSignature {
    private static let baseValue: Int64 = 406644
    private static let xorValue: Int64 = 3293161072
    private static let salt1 = "+-a^+6"
    private static let salt2 = "+-3^+b+-f"

    static func generateTK(for text: String) -> String {
        let bytes = encodeToUTF8(text)
        var value = baseValue

        for byte in bytes {
            value += Int64(byte)
            value = RLSigner.sign(value, salt: salt1)
        }

        value = RLSigner.sign(value, salt: salt2)
        value ^= xorValue

        if value < 0 {
            value = (value & 0x7FFFFFFF) + 0x80000000
        }

        let result = value % 1_000_000
        return "\(result).\(result ^ baseValue)"
    }

    private static func encodeToUTF8(_ string: String) -> [UInt8] {
        var bytes: [UInt8] = []
        for codeUnit in string.utf8 {
            bytes.append(codeUnit)
        }
        return bytes
    }
}
