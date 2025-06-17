//
//  EngineInstanceModel.swift
//  Mythic
//

import Foundation
import SemanticVersion

public final class EngineInstanceModel: Sendable {
    /// The shared instance.
    public static let shared = EngineInstanceModel()

    private let logger = AppLoggerModel(category: EngineInstanceModel.self)

    /// The engine directory.
    private static let engineDirectory = EngineVersionsDownloadModel.engineDirectory
    /// The package file for the engine containing information.
    private static let enginePackageFile = engineDirectory?.appendingPathComponent("package.json")

    private final class Box<T>: @unchecked Sendable {
        public var value: T

        init(_ value: T) {
            self.value = value
        }
    }

    /// A cached wine package.
    private let winePackage: Box<WinePackage?> = .init(nil)

    // package.json

    /// Package metadata, such as build date, wine version, etc.
    public struct PackageMetadata: Hashable, Codable, Sendable {
        public let buildDate: Date
        public let wineVersion: SemanticVersion
        public let version: SemanticVersion
    }

    /// Package wine data.
    public struct PackageWineData: Hashable, Codable, Sendable {
        public let wine: String
        public let wineserver: String
    }

    /// Package winetricks data.
    public struct PackageWinetricksData: Hashable, Codable, Sendable {
        public let verbs: String
        public let binary: String
    }

    /// Package dxvk data.
    public struct PackageDirectXVulkanData: Hashable, Codable, Sendable {
        public let bits32: [String]
        public let bits64: [String]
    }

    /// Package data.
    public struct PackageData: Hashable, Codable, Sendable {
        public let wine: PackageWineData
        public let winetricks: PackageWinetricksData
        public let directXVulkan: PackageDirectXVulkanData
    }

    /// Package root.
    public struct PackageFile: Hashable, Codable, Sendable {
        public let metadata: PackageMetadata
        public let package: PackageData
    }

    /// Errors that can happen while getting the engine.
    public enum EngineInstanceError: LocalizedError {
        case parseFailure(PackageFileParseError)
        case getPackageFailure
        case verifyPackageFailure
    }

    /// Get the engine.
    /// - Returns: The engine.
    public func getEngine() -> Result<WinePackage, EngineInstanceError> {
        if let winePackage = winePackage.value {
            return .success(winePackage)
        }

        // Load the package file.
        let packageFile = parsePackageFile()
        switch packageFile {
        case .success(let package):
            guard let winePackage = getWinePackage(package: package) else {
                return .failure(.getPackageFailure)
            }

            guard verifyWinePackageFile(package: winePackage) else {
                return .failure(.verifyPackageFailure)
            }

            self.winePackage.value = winePackage
            return .success(winePackage)
        case .failure(let error):
            logger.error("Failed to load package file: \(error.localizedDescription)")
            return .failure(.parseFailure(error))
        }
    }

    /// Errors that can happen while decoding.
    public enum PackageFileParseError: LocalizedError {
        case urlCreationError
        case fileReadError(Error)
        case jsonDecodingError(Error)
    }

    /// Parse package function
    /// - Returns: The package file.
    public func parsePackageFile() -> Result<PackageFile, PackageFileParseError> {
        guard let packageFile = Self.enginePackageFile else {
            return .failure(.urlCreationError)
        }

        let data: Data
        do {
            data = try Data(contentsOf: packageFile)
        } catch {
            return .failure(.fileReadError(error))
        }

        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-DD'T'HH:mm:ss.SSS'Z'"
        decoder.dateDecodingStrategy = .formatted(formatter)
        decoder.semanticVersionDecodingStrategy = .semverString
        do {
            return .success(try decoder.decode(PackageFile.self, from: data))
        } catch {
            return .failure(.jsonDecodingError(error))
        }
    }

    /// Parse path segment.
    /// - Parameter path: The path.
    /// - Returns: The path segments
    public func parsePathSegment(_ path: String) -> [String] {
        let parts = path.components(separatedBy: "/")
            .map { $0.removingPercentEncoding ?? $0 }
            .filter { !$0.isEmpty && $0 != ".." && $0 != "." }

        return parts
    }

    /// Append path segements to URL.
    /// - Parameters:
    ///   - url: The URL.
    ///   - parts: The path.
    /// - Returns: The URL.
    public func appendPathSegments(to url: URL, parts: [String]) -> URL {
        return parts.reduce(url) { $0.appendingPathComponent($1) }.standardized
    }

    /// Wine Package
    public struct WinePackage: Hashable, Sendable {
        public let metadata: PackageMetadata
        public let wineBinary: URL
        public let wineserverBinary: URL
        public let winetricksBinary: URL
        public let winetricksVerbs: URL
        public let dxvk32BitLibs: [URL]
        public let dxvk64BitLibs: [URL]
    }

    /// Convert a PackageFile to a WinePackage.
    /// - Parameter package: The package file.
    /// - Returns: The WinePackage
    public func getWinePackage(package: PackageFile) -> WinePackage? {
        guard let engineDirectory = Self.engineDirectory else {
            return nil
        }

        return WinePackage(
            metadata: package.metadata,
            wineBinary: appendPathSegments(
                to: engineDirectory, parts: parsePathSegment(package.package.wine.wine)),
            wineserverBinary: appendPathSegments(
                to: engineDirectory, parts: parsePathSegment(package.package.wine.wineserver)),
            winetricksBinary: appendPathSegments(
                to: engineDirectory, parts: parsePathSegment(package.package.winetricks.binary)),
            winetricksVerbs: appendPathSegments(
                to: engineDirectory, parts: parsePathSegment(package.package.winetricks.verbs)),
            dxvk32BitLibs: package.package.directXVulkan.bits32.map {
                appendPathSegments(to: engineDirectory, parts: parsePathSegment($0))
            },
            dxvk64BitLibs: package.package.directXVulkan.bits64.map {
                appendPathSegments(to: engineDirectory, parts: parsePathSegment($0))
            }
        )
    }

    /// Verify that all resources in a WinePackage are  present.
    /// - Parameter package: The wine package.
    public func verifyWinePackageFile(package: WinePackage) -> Bool {
        var urls: [URL] = [
            package.wineBinary,
            package.wineserverBinary,
            package.winetricksBinary,
            package.winetricksVerbs
        ]
        urls.append(contentsOf: package.dxvk32BitLibs)
        urls.append(contentsOf: package.dxvk64BitLibs)

        for item in urls {
            if !FileManager.default.fileExists(atPath: item.path) {
                logger.warning("File \(item.path) does not exist.")
                return false
            }
        }

        return true
    }
}
