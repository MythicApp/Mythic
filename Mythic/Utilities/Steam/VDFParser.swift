//
//  VDFParser.swift
//  Mythic
//

import Foundation

/// Minimal Valve KeyValues (text VDF / ACF) parser.
enum VDF {
    indirect enum Node: Equatable {
        case string(String)
        case object([(key: String, value: Node)])

        subscript(key: String) -> Node? {
            guard case .object(let values) = self else { return nil }
            return values.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
        }

        var stringValue: String? {
            guard case .string(let value) = self else { return nil }
            return value
        }

        var children: [(key: String, value: Node)] {
            guard case .object(let values) = self else { return [] }
            return values
        }

        static func == (lhs: Node, rhs: Node) -> Bool {
            switch (lhs, rhs) {
            case let (.string(left), .string(right)):
                return left == right
            case let (.object(left), .object(right)):
                guard left.count == right.count else { return false }
                return zip(left, right).allSatisfy {
                    $0.0.key == $0.1.key && $0.0.value == $0.1.value
                }
            default:
                return false
            }
        }
    }

    struct ParseError: LocalizedError {
        let message: String
        let offset: Int

        var errorDescription: String? {
            "\(message) (offset \(offset))"
        }
    }

    private enum Token {
        case string(String, offset: Int)
        case openBrace(offset: Int)
        case closeBrace(offset: Int)
    }

    private static let maximumFileSize = 8 * 1024 * 1024
    private static let maximumDepth = 64

    static func parse(_ text: String) throws -> Node {
        let tokens = try tokenize(text)
        var parser = Parser(tokens: tokens)
        return try parser.parseRoot()
    }

    static func parse(contentsOf url: URL) throws -> Node {
        // Only read regular files. A planted FIFO (or a symlink to one, or to a device such as /dev/tty) named
        // `appmanifest_<id>.acf` / `libraryfolders.vdf` would otherwise block `open`/`read` forever on the caller's
        // thread. O_NONBLOCK keeps `open` from waiting on a FIFO; checking the type with `fstat` on the already-opened
        // descriptor avoids a check-then-open race.
        let descriptor = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        }
        guard descriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }

        var status = stat()
        guard fstat(descriptor, &status) == 0,
              (status.st_mode & S_IFMT) == S_IFREG else {
            throw ParseError(message: "VDF path is not a regular file", offset: 0)
        }

        var data = Data()
        while data.count <= maximumFileSize {
            let remaining = maximumFileSize + 1 - data.count
            guard let chunk = try handle.read(upToCount: remaining), !chunk.isEmpty else {
                break
            }
            data.append(chunk)
        }

        guard data.count <= maximumFileSize else {
            throw ParseError(message: "VDF file exceeds the 8 MiB size limit", offset: maximumFileSize)
        }

        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return try parse(text)
    }

    private static func tokenize(_ text: String) throws -> [Token] {
        let characters = Array(text)
        var tokens: [Token] = []
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if character.isWhitespace {
                index += 1
                continue
            }

            if character == "/", index + 1 < characters.count, characters[index + 1] == "/" {
                index += 2
                while index < characters.count, !characters[index].isNewline { // "\r\n" is one Character
                    index += 1
                }
                continue
            }

            if character == "{" {
                tokens.append(.openBrace(offset: index))
                index += 1
                continue
            }

            if character == "}" {
                tokens.append(.closeBrace(offset: index))
                index += 1
                continue
            }

            if character == "\"" {
                let start = index
                index += 1
                var value = ""
                var terminated = false

                while index < characters.count {
                    let current = characters[index]
                    if current == "\"" {
                        index += 1
                        terminated = true
                        break
                    }

                    if current == "\\", index + 1 < characters.count {
                        index += 1
                        switch characters[index] {
                        case "\"": value.append("\"")
                        case "\\": value.append("\\")
                        case "n": value.append("\n")
                        case "t": value.append("\t")
                        default: value.append(characters[index])
                        }
                        index += 1
                    } else {
                        value.append(current)
                        index += 1
                    }
                }

                guard terminated else {
                    throw ParseError(message: "Unterminated quoted string", offset: start)
                }
                if !isConditionalTag(value) {
                    tokens.append(.string(value, offset: start))
                }
                continue
            }

            let start = index
            var value = ""
            while index < characters.count,
                  !characters[index].isWhitespace,
                  characters[index] != "{",
                  characters[index] != "}" {
                value.append(characters[index])
                index += 1
            }

            guard !value.isEmpty else {
                throw ParseError(message: "Unexpected token", offset: index)
            }
            if !isConditionalTag(value) {
                tokens.append(.string(value, offset: start))
            }
        }

        return tokens
    }

    private static func isConditionalTag(_ value: String) -> Bool {
        value.hasPrefix("[$") && value.hasSuffix("]")
    }

    private struct Parser {
        let tokens: [Token]
        var index = 0

        mutating func parseRoot() throws -> Node {
            let root = try parseObject(depth: 0, closingBraceExpected: false)
            guard index == tokens.count else {
                throw error("Unexpected token after root object", at: currentOffset)
            }
            return root
        }

        private mutating func parseObject(depth: Int, closingBraceExpected: Bool) throws -> Node {
            guard depth <= VDF.maximumDepth else {
                throw error("Maximum nesting depth of 64 exceeded", at: currentOffset)
            }

            var children: [(key: String, value: Node)] = []
            while index < tokens.count {
                if case .closeBrace(let offset) = tokens[index] {
                    guard closingBraceExpected else {
                        throw error("Unexpected closing brace", at: offset)
                    }
                    index += 1
                    return .object(children)
                }

                guard case .string(let key, let keyOffset) = tokens[index] else {
                    throw error("Expected a key", at: currentOffset)
                }
                index += 1
                guard index < tokens.count else {
                    throw error("Expected a value for a key", at: keyOffset)
                }

                switch tokens[index] {
                case .string(let value, _):
                    children.append((key: key, value: .string(value)))
                    index += 1
                case .openBrace:
                    let openOffset = currentOffset
                    index += 1
                    guard depth < VDF.maximumDepth else {
                        throw error("Maximum nesting depth of 64 exceeded", at: openOffset)
                    }
                    let object = try parseObject(depth: depth + 1, closingBraceExpected: true)
                    children.append((key: key, value: object))
                case .closeBrace(let offset):
                    throw error("Expected a value for a key", at: offset)
                }
            }

            guard !closingBraceExpected else {
                throw error("Missing closing brace", at: tokens.last.map { tokenEndOffset($0) } ?? 0)
            }
            return .object(children)
        }

        private var currentOffset: Int {
            guard index < tokens.count else { return tokens.last.map { tokenEndOffset($0) } ?? 0 }
            return tokenOffset(tokens[index])
        }

        private func error(_ message: String, at offset: Int) -> ParseError {
            ParseError(message: message, offset: offset)
        }

        private func tokenOffset(_ token: Token) -> Int {
            switch token {
            case .string(_, let offset), .openBrace(let offset), .closeBrace(let offset):
                return offset
            }
        }

        private func tokenEndOffset(_ token: Token) -> Int {
            tokenOffset(token) + 1
        }
    }
}
