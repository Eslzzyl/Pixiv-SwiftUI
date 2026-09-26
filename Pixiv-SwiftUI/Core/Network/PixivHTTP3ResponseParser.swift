import Foundation

nonisolated final class PixivHTTP3ResponseParser: @unchecked Sendable {
    private enum ResponsePhase: Equatable {
        case awaitingFinalHeaders
        case body
        case trailers
    }

    private struct HeaderBlock {
        let statusCode: Int?
        let fields: [(name: String, value: String)]
    }

    private let requestURL: URL
    private let requestMethod: String
    private let maxResponseBytes: Int?
    private let onResponse: (@Sendable (HTTPURLResponse) throws -> Void)?
    private let onBody: (@Sendable (Data) throws -> Void)?
    private let maxBufferedBytes = 128 * 1024 * 1024
    private var buffer = Data()
    private var body = Data()
    private var bodyByteCount: Int64 = 0
    private var activeFrameType: UInt64?
    private var activeFrameBytesRemaining: UInt64 = 0
    private var headers: [String: String] = [:]
    private var statusCode: Int?
    private var contentLength: UInt64?
    private var responseForbidsContent = false
    private var responsePhase = ResponsePhase.awaitingFinalHeaders

    init(
        requestURL: URL,
        requestMethod: String,
        maxResponseBytes: Int?,
        onResponse: (@Sendable (HTTPURLResponse) throws -> Void)?,
        onBody: (@Sendable (Data) throws -> Void)?
    ) {
        self.requestURL = requestURL
        self.requestMethod = requestMethod
        self.maxResponseBytes = maxResponseBytes
        self.onResponse = onResponse
        self.onBody = onBody
    }

    func append(_ data: Data) throws {
        buffer.append(data)
        guard buffer.count <= maxBufferedBytes,
              maxResponseBytes.map({ buffer.count + body.count <= $0 }) ?? true else {
            throw PixivDirectConnectionError.responseTooLarge
        }
        try parseAvailableFrames()
    }

    func finish() throws -> PixivDirectResponse {
        try parseAvailableFrames()
        guard buffer.isEmpty, activeFrameType == nil, activeFrameBytesRemaining == 0 else {
            throw PixivDirectConnectionError.incompleteResponse
        }
        guard let statusCode else { throw PixivDirectConnectionError.messageError }
        if !responseForbidsContent,
           let contentLength,
           contentLength > UInt64(bodyByteCount) {
            throw PixivDirectConnectionError.incompleteResponse
        }
        if !responseForbidsContent,
           let contentLength,
           contentLength < UInt64(bodyByteCount) {
            throw PixivDirectConnectionError.messageError
        }
        let response = try makeHTTPResponse(statusCode: statusCode)
        return PixivDirectResponse(
            data: body,
            response: response,
            negotiatedProtocol: "h3",
            bodyByteCount: bodyByteCount
        )
    }

    func diagnosticSummary() -> String {
        let prefix = buffer.prefix(32).map { String(format: "%02x", $0) }.joined()
        return "bufferBytes=\(buffer.count) bodyBytes=\(bodyByteCount) status=\(statusCode.map(String.init) ?? "nil") prefix=\(prefix)"
    }

    private func parseAvailableFrames() throws {
        while true {
            if activeFrameType == nil {
                var offset = 0
                guard let type = decodeInteger(in: buffer, offset: &offset),
                      let length = decodeInteger(in: buffer, offset: &offset),
                      length <= UInt64(Int.max) else {
                    return
                }
                guard type != 0x00 || responsePhase == .body else {
                    throw PixivDirectConnectionError.frameUnexpected
                }
                guard type != 0x00 || !responseForbidsContent else {
                    throw PixivDirectConnectionError.messageError
                }
                switch type {
                case 0x02, 0x03, 0x04, 0x06, 0x07, 0x08, 0x09, 0x0d:
                    throw PixivDirectConnectionError.frameUnexpected
                case 0x05:
                    throw PixivDirectConnectionError.idError
                default:
                    break
                }
                buffer.removeSubrange(0..<offset)
                activeFrameType = type
                activeFrameBytesRemaining = length
                if length == 0 {
                    try processCompleteFrame(type: type, payload: Data())
                    activeFrameType = nil
                    continue
                }
            }

            guard let type = activeFrameType else { return }
            if type == 0x00 || ![0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0d].contains(type) {
                let available = min(UInt64(buffer.count), activeFrameBytesRemaining)
                guard available > 0 else { return }
                let byteCount = Int(available)
                let payload = Data(buffer.prefix(byteCount))
                buffer.removeSubrange(0..<byteCount)
                if type == 0x00 {
                    try processData(payload)
                }
                activeFrameBytesRemaining -= available
                if activeFrameBytesRemaining == 0 {
                    activeFrameType = nil
                    continue
                }
                return
            }

            guard activeFrameBytesRemaining <= UInt64(maxBufferedBytes) else {
                throw PixivDirectConnectionError.responseTooLarge
            }
            guard buffer.count >= Int(activeFrameBytesRemaining) else { return }
            let payloadLength = Int(activeFrameBytesRemaining)
            let payload = Data(buffer.prefix(payloadLength))
            buffer.removeSubrange(0..<payloadLength)
            try processCompleteFrame(type: type, payload: payload)
            activeFrameType = nil
            activeFrameBytesRemaining = 0
        }
    }

    private func processCompleteFrame(type: UInt64, payload: Data) throws {
        switch type {
        case 0x00:
            try processData(payload)
        case 0x01:
            try processHeaderBlock(payload)
        default:
            break
        }
    }

    private func processData(_ payload: Data) throws {
        guard responsePhase == .body else {
            throw PixivDirectConnectionError.frameUnexpected
        }
        guard !responseForbidsContent else {
            throw PixivDirectConnectionError.messageError
        }
        let (nextBodyByteCount, overflow) = bodyByteCount.addingReportingOverflow(Int64(payload.count))
        guard !overflow else {
            throw PixivDirectConnectionError.responseTooLarge
        }
        if let contentLength, UInt64(nextBodyByteCount) > contentLength {
            throw PixivDirectConnectionError.messageError
        }
        if let maxResponseBytes,
           onBody == nil,
           nextBodyByteCount > Int64(maxResponseBytes) {
            throw PixivDirectConnectionError.responseTooLarge
        }
        if let onBody {
            do {
                try onBody(payload)
            } catch {
                throw PixivDirectResponseCallbackError(error)
            }
        } else {
            body.append(payload)
        }
        bodyByteCount = nextBodyByteCount
    }

    private func makeHTTPResponse(statusCode: Int) throws -> HTTPURLResponse {
        guard let response = HTTPURLResponse(
            url: requestURL,
            statusCode: statusCode,
            httpVersion: "HTTP/3",
            headerFields: headers
        ) else {
            throw PixivDirectConnectionError.invalidResponse
        }
        return response
    }

    private func processHeaderBlock(_ payload: Data) throws {
        guard responsePhase != .trailers else {
            throw PixivDirectConnectionError.frameUnexpected
        }

        let headerBlock = try decodeHeaderBlock(payload)
        guard let blockStatus = headerBlock.statusCode else {
            guard responsePhase == .body else {
                throw PixivDirectConnectionError.messageError
            }
            guard !responseForbidsContent else {
                throw PixivDirectConnectionError.messageError
            }
            guard !headerBlock.fields.contains(where: { $0.name == "content-length" }) else {
                throw PixivDirectConnectionError.messageError
            }
            responsePhase = .trailers
            return
        }

        guard responsePhase == .awaitingFinalHeaders, statusCode == nil else {
            throw PixivDirectConnectionError.messageError
        }
        if (100..<200).contains(blockStatus) {
            guard blockStatus != 101,
                  !headerBlock.fields.contains(where: { $0.name == "content-length" }) else {
                throw PixivDirectConnectionError.messageError
            }
            return
        }

        statusCode = blockStatus
        responsePhase = .body
        responseForbidsContent = requestMethod == "HEAD" || blockStatus == 204 || blockStatus == 304
        contentLength = try parseContentLength(headerBlock.fields)
        guard blockStatus != 204 || contentLength == nil else {
            throw PixivDirectConnectionError.messageError
        }
        for field in headerBlock.fields where field.name != ":status" {
            if field.name == "content-encoding", let previousValue = headers[field.name] {
                headers[field.name] = "\(previousValue), \(field.value)"
            } else {
                headers[field.name] = field.value
            }
        }
        if let onResponse {
            do {
                try onResponse(makeHTTPResponse(statusCode: blockStatus))
            } catch {
                throw PixivDirectResponseCallbackError(error)
            }
        }
    }

    private func decodeHeaderBlock(_ payload: Data) throws -> HeaderBlock {
        var offset = 0
        guard let requiredInsertCount = decodePrefixedInteger(in: payload, offset: &offset, prefixBits: 8),
              requiredInsertCount == 0,
              offset < payload.count else {
            throw PixivDirectConnectionError.qpackDecompressionFailed
        }

        let baseSign = payload[offset] & 0x80 != 0
        guard let deltaBase = decodePrefixedInteger(in: payload, offset: &offset, prefixBits: 7),
              !baseSign,
              deltaBase == 0 else {
            throw PixivDirectConnectionError.qpackDecompressionFailed
        }

        var fields: [(name: String, value: String)] = []
        while offset < payload.count {
            let first = payload[offset]
            if first & 0x80 != 0 {
                guard let index = decodePrefixedInteger(in: payload, offset: &offset, prefixBits: 6) else {
                    throw PixivDirectConnectionError.qpackDecompressionFailed
                }
                guard first & 0x40 != 0, let entry = staticEntry(index: index) else {
                    throw PixivDirectConnectionError.qpackDecompressionFailed
                }
                fields.append(entry)
                continue
            }

            if first & 0xc0 == 0x40 {
                let isStatic = first & 0x10 != 0
                guard let index = decodePrefixedInteger(in: payload, offset: &offset, prefixBits: 4) else {
                    throw PixivDirectConnectionError.qpackDecompressionFailed
                }
                guard isStatic, let name = staticEntry(index: index)?.name else {
                    throw PixivDirectConnectionError.qpackDecompressionFailed
                }
                let value = try decodeString(in: payload, offset: &offset, prefixBits: 7)
                fields.append((name: name, value: value))
                continue
            }

            if first & 0xe0 == 0x20 {
                let name = try decodeString(in: payload, offset: &offset, prefixBits: 3)
                let value = try decodeString(in: payload, offset: &offset, prefixBits: 7)
                fields.append((name: name, value: value))
                continue
            }

            throw PixivDirectConnectionError.qpackDecompressionFailed
        }

        return try validateHeaderBlock(fields)
    }

    private func validateHeaderBlock(_ fields: [(name: String, value: String)]) throws -> HeaderBlock {
        var statusCode: Int?
        var regularFields: [(name: String, value: String)] = []
        var didReadRegularField = false

        for field in fields {
            if field.name.hasPrefix(":") {
                guard field.name == ":status",
                      statusCode == nil,
                      !didReadRegularField,
                      field.value.utf8.count == 3,
                      field.value.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                      let parsedStatus = Int(field.value),
                      (100...599).contains(parsedStatus) else {
                    throw PixivDirectConnectionError.messageError
                }
                statusCode = parsedStatus
            } else {
                let fieldName = field.name.utf8
                guard !fieldName.isEmpty,
                      field.name == field.name.lowercased(),
                      fieldName.allSatisfy(Self.isFieldNameCharacter),
                      field.value.utf8.allSatisfy(Self.isValidFieldValue),
                      !Self.connectionSpecificFieldNames.contains(field.name),
                      field.name != "te" else {
                    throw PixivDirectConnectionError.messageError
                }
                didReadRegularField = true
                regularFields.append(field)
            }
        }

        return HeaderBlock(statusCode: statusCode, fields: regularFields)
    }

    private func parseContentLength(_ fields: [(name: String, value: String)]) throws -> UInt64? {
        let values = fields.filter { $0.name == "content-length" }.map(\.value)
        guard !values.isEmpty else { return nil }

        var parsedValue: UInt64?
        for fieldValue in values {
            let components = fieldValue.split(separator: ",", omittingEmptySubsequences: false)
            for component in components {
                let digits = component.trimmingCharacters(in: .whitespaces)
                guard !digits.isEmpty,
                      digits.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                      let value = UInt64(digits) else {
                    throw PixivDirectConnectionError.messageError
                }
                guard parsedValue == nil || parsedValue == value else {
                    throw PixivDirectConnectionError.messageError
                }
                parsedValue = value
            }
        }
        return parsedValue
    }

    private static let connectionSpecificFieldNames: Set<String> = [
        "connection",
        "keep-alive",
        "proxy-connection",
        "transfer-encoding",
        "upgrade"
    ]

    private static func isFieldNameCharacter(_ byte: UInt8) -> Bool {
        (byte >= 48 && byte <= 57) ||
            (byte >= 65 && byte <= 90) ||
            (byte >= 97 && byte <= 122) ||
            [33, 35, 36, 37, 38, 39, 42, 43, 45, 46, 94, 95, 96, 124, 126].contains(byte)
    }

    private static func isValidFieldValue(_ byte: UInt8) -> Bool {
        byte == 9 || (byte >= 32 && byte <= 126) || byte >= 128
    }

    private func decodeString(in data: Data, offset: inout Int, prefixBits: Int) throws -> String {
        guard offset < data.count else {
            throw PixivDirectConnectionError.qpackDecompressionFailed
        }
        let first = data[offset]
        let huffmanMask = UInt8(1 << prefixBits)
        let isHuffman = first & huffmanMask != 0
        guard let length = decodePrefixedInteger(in: data, offset: &offset, prefixBits: prefixBits),
              length <= UInt64(data.count - offset) else {
            throw PixivDirectConnectionError.qpackDecompressionFailed
        }
        let end = offset + Int(length)
        let valueData = data.subdata(in: offset..<end)
        offset = end
        let decodedData = if isHuffman {
            try PixivHPACKHuffmanDecoder.decode(valueData)
        } else {
            valueData
        }
        guard let string = String(data: decodedData, encoding: .utf8) else {
            throw PixivDirectConnectionError.qpackDecompressionFailed
        }
        return string
    }

    private func decodeInteger(in data: Data, offset: inout Int) -> UInt64? {
        PixivHTTP3VariableInteger.decode(in: data, offset: &offset)
    }

    private func decodePrefixedInteger(in data: Data, offset: inout Int, prefixBits: Int) -> UInt64? {
        guard offset < data.count, prefixBits > 0, prefixBits <= 8 else { return nil }
        let first = data[offset]
        let mask = UInt8((1 << prefixBits) - 1)
        var value = UInt64(first & mask)
        offset += 1
        let limit = UInt64(mask)
        guard value == limit else { return value }

        var shift: UInt64 = 0
        while offset < data.count {
            let byte = data[offset]
            offset += 1
            if shift >= 63 {
                return nil
            }
            value += UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 {
                return value
            }
            shift += 7
        }
        return nil
    }

    private func staticEntry(index: UInt64) -> (name: String, value: String)? {
        PixivQPACKStaticTable.entry(index: index)
    }
}
