//
//  SteamWebAPI.swift
//  Mythic
//

import Foundation
import OSLog

enum SteamWebAPI {
    static let log = Logger.custom(category: "steamWebAPI")

    private static let responseLimit = 16 * 1024 * 1024

    /// Dedicated session for all Steam HTTP traffic (Web API and OpenID verification).
    ///
    /// * No URL cache: the Web API key travels in the query string, and `URLSession.shared` would persist the request URL
    ///   (and the owned-games response) in the app's on-disk `Cache.db`.
    /// * No cookies / credential storage.
    /// * Redirects are refused, so a request carrying the key (or an OpenID assertion) is never re-sent to another URL.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        return URLSession(configuration: configuration, delegate: RedirectRefusingDelegate(), delegateQueue: nil)
    }()

    private final class RedirectRefusingDelegate: NSObject, URLSessionTaskDelegate, Sendable {
        func urlSession(_ session: URLSession,
                        task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest) async -> URLRequest? {
            nil
        }
    }

    struct OwnedGame: Decodable, Hashable {
        let appid: Int
        let name: String?
        let playtimeForever: Int?
        let imageIconURL: String?

        enum CodingKeys: String, CodingKey {
            case appid, name
            case playtimeForever = "playtime_forever"
            case imageIconURL = "img_icon_url"
        }
    }

    struct PlayerSummary: Decodable, Hashable {
        let steamid: String
        let personaname: String
        let avatarfull: String?
    }

    struct MissingAPIKeyError: LocalizedError {
        var errorDescription: String? {
            "A Steam Web API key is required."
        }
    }

    struct HTTPError: LocalizedError {
        let statusCode: Int

        var errorDescription: String? {
            "Steam Web API returned HTTP \(statusCode)."
        }
    }

    struct OwnedGamesUnavailableError: LocalizedError {
        var errorDescription: String? {
            String(localized: "Steam did not provide a complete owned-games list. Check the account's Game Details privacy settings.")
        }
    }

    static func getOwnedGames(steamID: String,
                              session: URLSession = SteamWebAPI.session) async throws -> [OwnedGame] {
        try validateSteamID(steamID)
        guard let key = SteamConfig.webAPIKey else {
            throw MissingAPIKeyError()
        }
        let url = try makeURL(
            path: "/IPlayerService/GetOwnedGames/v1/",
            queryItems: [
                URLQueryItem(name: "key", value: key),
                URLQueryItem(name: "steamid", value: steamID),
                URLQueryItem(name: "include_appinfo", value: "1"),
                URLQueryItem(name: "include_played_free_games", value: "1"),
                URLQueryItem(name: "format", value: "json")
            ]
        )
        let data = try await getData(from: url, session: session)
        let response = try JSONDecoder().decode(OwnedGamesResponse.self, from: data).response
        guard let count = response.gameCount, count >= 0 else {
            throw OwnedGamesUnavailableError()
        }
        let games = response.games ?? []
        guard games.count == count else {
            throw OwnedGamesUnavailableError()
        }
        return games
    }

    static func getPlayerSummary(steamID: String,
                                 session: URLSession = SteamWebAPI.session) async throws -> PlayerSummary? {
        try validateSteamID(steamID)
        guard let key = SteamConfig.webAPIKey else {
            throw MissingAPIKeyError()
        }
        let url = try makeURL(
            path: "/ISteamUser/GetPlayerSummaries/v2/",
            queryItems: [
                URLQueryItem(name: "key", value: key),
                URLQueryItem(name: "steamids", value: steamID)
            ]
        )
        let data = try await getData(from: url, session: session)
        return try JSONDecoder().decode(PlayerSummariesResponse.self, from: data).response.players.first
    }

    private struct OwnedGamesResponse: Decodable {
        struct Payload: Decodable {
            let gameCount: Int?
            let games: [OwnedGame]?

            enum CodingKeys: String, CodingKey {
                case gameCount = "game_count"
                case games
            }
        }

        let response: Payload
    }

    private struct PlayerSummariesResponse: Decodable {
        struct Payload: Decodable {
            let players: [PlayerSummary]
        }

        let response: Payload
    }

    private static func validateSteamID(_ steamID: String) throws {
        guard steamID.range(of: #"^7656119[0-9]{10}$"#, options: .regularExpression) != nil else {
            throw URLError(.badURL)
        }
    }

    private static func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.steampowered.com"
        components.path = path
        components.queryItems = queryItems
        guard components.scheme == "https",
              let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    private static func getData(from url: URL, session: URLSession) async throws -> Data {
        guard url.scheme?.lowercased() == "https" else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpShouldHandleCookies = false
        let result: (Data, URLResponse)
        do {
            result = try await boundedData(for: request, session: session)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            // Drop `userInfo`: NSURLErrorFailingURLErrorKey / NSURLErrorFailingURLStringErrorKey hold the full request URL,
            // including `key=<Web API key>`, and would leak it into logs, alerts or crash reports via `"\(error)"`.
            throw URLError(error.code)
        } catch {
            throw URLError(.unknown)
        }
        let (data, response) = result
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw HTTPError(statusCode: status)
        }
        return data
    }

    private static func boundedData(for request: URLRequest, session: URLSession) async throws -> (Data, URLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        var data = Data()
        for try await byte in bytes {
            guard data.count < responseLimit else {
                throw URLError(.dataLengthExceedsMaximum)
            }
            data.append(byte)
        }
        return (data, response)
    }
}
