//
//  SteamConfig.swift
//  Mythic
//

import Foundation

enum SteamConfig {
    private static let apiKeyPattern = #"^[0-9A-Fa-f]{32}$"#
    private static let fallbackRealm = URL(string: "https://getmythic.app/")! // swiftlint:disable:this force_unwrapping

    static var bundledWebAPIKey: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "MythicSteamWebAPIKey") as? String,
              !value.isEmpty,
              !value.contains("$("),
              value.range(of: apiKeyPattern, options: .regularExpression) != nil else {
            return nil
        }
        return value
    }

    static var userWebAPIKey: String? {
        guard let key = SteamKeychain.get(.webAPIKey),
              key.range(of: apiKeyPattern, options: .regularExpression) != nil else {
            return nil
        }
        return key
    }

    static func setUserWebAPIKey(_ key: String?) throws {
        guard let key, !key.isEmpty else {
            SteamKeychain.delete(.webAPIKey)
            return
        }
        guard key.range(of: apiKeyPattern, options: .regularExpression) != nil else {
            throw NSError(
                domain: "Mythic.SteamConfig",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The Steam Web API key must be 32 hexadecimal characters."]
            )
        }
        try SteamKeychain.set(key, for: .webAPIKey)
    }

    static var webAPIKey: String? {
        userWebAPIKey ?? bundledWebAPIKey
    }

    static var openIDRealm: URL {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "MythicSteamOpenIDRealm") as? String,
              let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              let url = components.url else {
            return fallbackRealm
        }
        return url
    }

    static var openIDReturnTo: URL {
        guard var components = URLComponents(url: openIDRealm, resolvingAgainstBaseURL: false) else {
            return fallbackRealm
        }
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = "\(basePath)/steam/openid/callback"
        components.query = nil
        components.fragment = nil
        return components.url ?? fallbackRealm
    }
}
