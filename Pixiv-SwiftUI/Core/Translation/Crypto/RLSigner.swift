struct RLSigner {
    static func sign(_ value: Int64, salt: String) -> Int64 {
        var result = value
        var index = salt.startIndex

        while index < salt.index(salt.endIndex, offsetBy: -2) {
            guard let nextIndex = salt.index(index, offsetBy: 2, limitedBy: salt.endIndex) else {
                break
            }
            let dChar = salt[nextIndex]
            var digitValue: Int64 = 0

            if dChar >= "a" && dChar <= "z" {
                digitValue = Int64((dChar.asciiValue ?? 0) - 96)
            } else if dChar >= "0" && dChar <= "9" {
                digitValue = Int64(String(dChar)) ?? 0
            }

            let op1 = salt[salt.index(index, offsetBy: 1)]
            if op1 == "+" {
                result = result >> digitValue
            } else {
                result = result << digitValue
            }

            let op2 = salt[index]
            if op2 == "+" {
                result = (result + digitValue) & 0xFFFFFFFF
            } else {
                result = result ^ digitValue
            }

            index = salt.index(index, offsetBy: 3)
        }

        return result
    }
}
