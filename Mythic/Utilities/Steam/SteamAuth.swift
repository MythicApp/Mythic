//
//  SteamAuth.swift
//  Mythic
//

import Foundation
import OSLog

enum SteamAuth {
    static let log = Logger.custom(category: "steamAuth")
    static let endpoint = URL(string: "https://steamcommunity.com/openid/login")! // swiftlint:disable:this force_unwrapping

    private static let openIDNamespace = "http://specs.openid.net/auth/2.0"
    private static let identityPrefix = "https://steamcommunity.com/openid/id/"
    private static let responseLimit = 1_048_576
    private static let maximumCallbackQueryLength = 65_536
    /// Maximum accepted age / clock skew of `openid.response_nonce` (OpenID 2.0 §11.3: RPs should reject stale nonces).
    private static let maximumNonceSkew: TimeInterval = 15 * 60

    static var currentSteamID: String? {
        guard let steamID = SteamKeychain.get(.steamID), isValidSteamID(steamID) else {
            return nil
        }
        return steamID
    }

    static var isSignedIn: Bool {
        currentSteamID != nil
    }

    static func makeLoginURL(nonce: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "steamcommunity.com"
        components.path = "/openid/login"
        components.queryItems = [
            URLQueryItem(name: "openid.ns", value: openIDNamespace),
            URLQueryItem(name: "openid.mode", value: "checkid_setup"),
            URLQueryItem(name: "openid.identity", value: "http://specs.openid.net/auth/2.0/identifier_select"),
            URLQueryItem(name: "openid.claimed_id", value: "http://specs.openid.net/auth/2.0/identifier_select"),
            URLQueryItem(name: "openid.realm", value: SteamConfig.openIDRealm.absoluteString),
            URLQueryItem(name: "openid.return_to", value: returnToURL(nonce: nonce).absoluteString)
        ]
        return components.url ?? endpoint
    }

    static func isCallback(_ url: URL) -> Bool {
        guard let actual = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let expected = URLComponents(url: SteamConfig.openIDReturnTo, resolvingAgainstBaseURL: false) else {
            return false
        }
        return actual.scheme?.lowercased() == expected.scheme?.lowercased()
            && actual.host?.lowercased() == expected.host?.lowercased()
            && actual.port == expected.port
            && actual.path == expected.path
    }

    /// Verifies an OpenID callback. Throws on any mismatch and returns the verified SteamID64.
    static func verify(callbackURL: URL, expectedNonce: String, session: URLSession = SteamWebAPI.session) async throws -> String {
        guard callbackURL.scheme?.lowercased() == "https",
              isCallback(callbackURL),
              let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let query = components.percentEncodedQuery,
              query.utf8.count <= maximumCallbackQueryLength,
              let queryItems = components.queryItems else {
            throw VerificationError(reason: "The OpenID callback URL is invalid.")
        }

        // OpenID 2.0 §11.1: the URL we were called back on must be the return_to we asked for, i.e. carry exactly our nonce.
        let nonOpenIDItems = queryItems.filter { !$0.name.hasPrefix("openid.") }
        guard nonOpenIDItems.count == 1,
              nonOpenIDItems[0].name == "mythic_nonce",
              nonOpenIDItems[0].value == expectedNonce else {
            throw VerificationError(reason: "The OpenID callback nonce or return URL does not match.")
        }

        var parameters: [String: String] = [:]
        for item in queryItems where item.name.hasPrefix("openid.") {
            guard let value = item.value, parameters[item.name] == nil else {
                throw VerificationError(reason: "The OpenID callback contains invalid or duplicate parameters.")
            }
            parameters[item.name] = value
        }

        guard parameters["openid.mode"] == "id_res",
              parameters["openid.ns"] == openIDNamespace,
              parameters["openid.op_endpoint"] == endpoint.absoluteString else {
            throw VerificationError(reason: "The OpenID assertion does not match the expected Steam response.")
        }

        let expectedReturnTo = returnToURL(nonce: expectedNonce).absoluteString
        guard parameters["openid.return_to"] == expectedReturnTo else {
            throw VerificationError(reason: "The OpenID callback nonce or return URL does not match.")
        }

        guard let claimedID = parameters["openid.claimed_id"],
              let identity = parameters["openid.identity"],
              claimedID == identity,
              claimedID.hasPrefix(identityPrefix) else {
            throw VerificationError(reason: "The OpenID identity is invalid.")
        }

        let steamID = String(claimedID.dropFirst(identityPrefix.count))
        guard isValidSteamID(steamID),
              let signed = parameters["openid.signed"] else {
            throw VerificationError(reason: "The OpenID identity or signed fields are invalid.")
        }

        let signedFields = Set(signed.split(separator: ":").map(String.init))
        let requiredSignedFields: Set<String> = [
            "op_endpoint", "claimed_id", "identity", "return_to", "response_nonce", "assoc_handle"
        ]
        guard requiredSignedFields.isSubset(of: signedFields) else {
            throw VerificationError(reason: "The OpenID assertion does not sign all required fields.")
        }

        guard let responseNonce = parameters["openid.response_nonce"],
              isFresh(responseNonce: responseNonce) else {
            throw VerificationError(reason: "The OpenID assertion has expired. Check your Mac's clock and try again.")
        }

        var postParameters = parameters
        postParameters["openid.mode"] = "check_authentication"
        let body = postParameters.keys.sorted().map { key in
            "\(formEncode(key))=\(formEncode(postParameters[key] ?? ""))"
        }.joined(separator: "&")

        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)

        let (responseData, response) = try await boundedData(for: request, session: session)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw VerificationError(reason: "Steam rejected the OpenID verification request (HTTP \(status)).")
        }

        // Key-Value Form (OpenID 2.0 §4.1.1): one `key:value` per line; reject duplicates and a mismatched namespace.
        guard let responseText = String(data: responseData, encoding: .utf8) else {
            throw VerificationError(reason: "Steam did not confirm the OpenID assertion.")
        }
        var responseFields: [String: String] = [:]
        for line in responseText.split(whereSeparator: \.isNewline) {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separator])
            guard responseFields[key] == nil else {
                throw VerificationError(reason: "Steam did not confirm the OpenID assertion.")
            }
            responseFields[key] = String(line[line.index(after: separator)...])
        }
        guard responseFields["is_valid"] == "true",
              responseFields["ns"].map({ $0 == openIDNamespace }) ?? true else {
            throw VerificationError(reason: "Steam did not confirm the OpenID assertion.")
        }
        return steamID
    }

    static func completeSignIn(steamID: String) throws {
        guard isValidSteamID(steamID) else {
            throw VerificationError(reason: "The SteamID64 is invalid.")
        }
        try SteamKeychain.set(steamID, for: .steamID)
    }

    static func signOut() {
        SteamKeychain.delete(.steamID)
    }

    struct VerificationError: LocalizedError {
        let reason: String

        var errorDescription: String? {
            reason
        }
    }

    private static func returnToURL(nonce: String) -> URL {
        guard var components = URLComponents(url: SteamConfig.openIDReturnTo, resolvingAgainstBaseURL: false) else {
            return SteamConfig.openIDReturnTo
        }
        components.queryItems = [URLQueryItem(name: "mythic_nonce", value: nonce)]
        return components.url ?? SteamConfig.openIDReturnTo
    }

    /// `response_nonce` starts with a UTC timestamp, e.g. `2026-11-15T12:34:56Z<unique>`.
    private static func isFresh(responseNonce: String, now: Date = .now) -> Bool {
        guard responseNonce.count >= 20, responseNonce.count <= 255 else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let issued = formatter.date(from: String(responseNonce.prefix(20))) else { return false }
        return abs(now.timeIntervalSince(issued)) <= maximumNonceSkew
    }

    private static func isValidSteamID(_ steamID: String) -> Bool {
        steamID.range(of: #"^7656119[0-9]{10}$"#, options: .regularExpression) != nil
    }

    private static func formEncode(_ value: String) -> String {
        let hex = Array("0123456789ABCDEF".utf8)
        var encoded: [UInt8] = []
        for byte in value.utf8 {
            switch byte {
            case 65...90, 97...122, 48...57, 45, 46, 95, 126:
                encoded.append(byte)
            default:
                encoded.append(37)
                encoded.append(hex[Int(byte >> 4)])
                encoded.append(hex[Int(byte & 0x0F)])
            }
        }
        return String(decoding: encoded, as: UTF8.self)
    }

    private static func boundedData(for request: URLRequest, session: URLSession) async throws -> (Data, URLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        var data = Data()
        for try await byte in bytes {
            guard data.count < responseLimit else {
                throw VerificationError(reason: "Steam's OpenID verification response exceeded the size limit.")
            }
            data.append(byte)
        }
        return (data, response)
    }
}
