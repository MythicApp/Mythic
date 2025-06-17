//
//  HexParserUtility.swift
//  Mythic
//

import Foundation

public enum HexParserUtility {
    /// Errors
    public enum HexParserError: LocalizedError {
        case stringEncodingError
        case invalidStringLength
        case invalidCharacter
    }

    private static func lowercaseHexChar(for char: UInt8) -> UInt8 {
        if char >= 65 && char <= 90 {
            return char + 32
        }
        return char
    }

    private static func hexCharToByte(for char: UInt8) -> UInt8? {
        let lowercased = lowercaseHexChar(for: char)
        if lowercased >= 48 && lowercased <= 57 {
            return lowercased - 48
        } else if lowercased >= 97 && lowercased <= 102 {
            return lowercased - 87
        }
        return nil
    }

    /// Parse a hex string to a [UInt8]
    public static func parseHexStringToBytes(_ hex: String) -> Result<[UInt8], HexParserError> {
        guard let data = hex.data(using: .utf8) else {
            return .failure(.stringEncodingError)
        }

        // Check if the string length is valid
        if data.count % 2 != 0 {
            return .failure(.invalidStringLength)
        }

        // Chunk data into bytes
        var bytes: [UInt8] = []
        bytes.reserveCapacity(data.count / 2)
        for index in stride(from: 0, to: data.count, by: 2) {
            let hexChar1 = hexCharToByte(for: data[index])
            let hexChar2 = hexCharToByte(for: data[index + 1])
            
            guard let hexChar1 = hexChar1, let hexChar2 = hexChar2 else {
                return .failure(.invalidCharacter)
            }

            // Shift the first hex char by 4 bits and add the second hex char
            let byte = (hexChar1 << 4) | hexChar2
            bytes.append(byte)
        }
        return .success(bytes)
    }

    /// Parse a hex string to a Data
    public static func parseHexStringToData(_ hex: String) -> Result<Data, HexParserError> {
        let bytesResult = parseHexStringToBytes(hex)
        switch bytesResult {
            case .success(let bytes):
                return .success(Data(bytes))
            case .failure(let error):
                return .failure(error)
        }
    }
}
