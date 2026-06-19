struct GoogleSignature {
    private static let b: Int64 = 406644
    private static let b1: Int64 = 3293161072
    private static let salt1 = "+-a^+6"
    private static let salt2 = "+-3^+b+-f"

    static func generateTK(for text: String) -> String {
        let bytes = encodeToUTF8(text)
        var a = b

        for byte in bytes {
            a += Int64(byte)
            a = RLSigner.sign(a, salt: salt1)
        }

        a = RLSigner.sign(a, salt: salt2)
        a ^= b1

        if a < 0 {
            a = (a & 0x7FFFFFFF) + 0x80000000
        }

        let result = a % 1_000_000
        return "\(result).\(result ^ b)"
    }

    private static func encodeToUTF8(_ string: String) -> [UInt8] {
        var bytes: [UInt8] = []
        for codeUnit in string.utf8 {
            bytes.append(codeUnit)
        }
        return bytes
    }
}
