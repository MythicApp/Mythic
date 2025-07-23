//
//  EngineVersionsDownloadModel.swift
//  Mythic
//

import Foundation
import CryptoKit
import SemanticVersion
import BLAKE3

public enum EngineVersionsDownloadModel {
    private static let logger = AppLoggerModel(category: EngineVersionsDownloadModel.self)

    // Filesystem paths
    public static let engineDirectory = DirectoriesUtility.applicationSupportDirectory?.appendingPathComponent("Engine")
    public static let engineMetadataFile = engineDirectory?.appendingPathComponent("EngineMetadata.plist")

    // Cloudfront URLs
    private static let cloudfrontBaseURL = URL(string: "https://dl.getmythic.app")

    // Engine download
    private static let wineCloudfrontPrefix = "wine"
    private static let versionsFile = "versions.json"

    // Known signatures
    private static let knownSignatures: [KnownSignature] = if let downloadSignature =
        Bundle.main.object(forInfoDictionaryKey: "EngineDownloadSignature") as? String,
        let data = Data(base64Encoded: downloadSignature) {
        [.init(algorithm: .ed25519, publicKey: data)]
    } else {
        []
    }

    /// Supported engine release branches
    public enum ReleaseBranch: String, Codable, CaseIterable, Sendable {
        case stable = "stable"
        case development = "development"
    }

    // Release info

    /// A localizable representation of a ReleaseInfo object
    public struct ReleaseInfoData: Identifiable, Hashable, Codable, Sendable {
        public var id: Int {
            self.hashValue
        }
        let name: String
        let description: String
    }

    /// A localizable representation of a ReleaseInfo file
    public struct ReleaseInfo: Hashable, Codable, Sendable {
        let defaultData: ReleaseInfoData
        let localizedData: [String: ReleaseInfoData]

        enum CodingKeys: String, CodingKey {
            case defaultData = "default"
            case localizedData = "localized"
        }
    }

    // Versions.json

    /// Supported Hashing Algorithms
    public enum HashAlgorithm: String, Codable, Sendable {
        case blake3
    }

    /// Supported Signature Algorithms
    public enum SignatureAlgorithm: String, Codable, Sendable {
        case ed25519
    }

    /// Supported Build Platforms
    public enum BuildPlatform: String, Codable, Sendable {
        case macOS
    }

    /// Supported Build Architectures
    public enum BuildArchitecture: String, Codable, Sendable {
        case x64 = "x86_64"
        case arm64 = "arm64"
    }

    /// Update Priorites
    public enum UpdatePriority: String, Comparable, Equatable, Codable, Sendable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"

        public var intValue: Int {
            switch self {
            case .low:
                return 0
            case .medium:
                return 1
            case .high:
                return 2
            case .critical:
                return 3
            }
        }

        public static func < (lhs: UpdatePriority, rhs: UpdatePriority) -> Bool {
            return lhs.intValue < rhs.intValue
        }

        public static func == (lhs: UpdatePriority, rhs: UpdatePriority) -> Bool {
            return lhs.intValue == rhs.intValue
        }
    }

    /// An artifact hash
    public struct ArtifactHash: Hashable, Codable, Sendable {
        public let algorithm: HashAlgorithm
        public let value: String
    }

    /// An artifact
    public struct Artifact: Identifiable, Hashable, Codable, Sendable {
        public let id: UUID
        public let href: String
        public let hash: ArtifactHash
        public let byteCount: UInt64
    }

    /// A build signature
    public struct BuildSignature: Hashable, Codable, Sendable {
        public let algorithm: SignatureAlgorithm
        public let publicKey: String
        public let value: String
    }

    /// A build
    public struct Build: Identifiable, Hashable, Codable, Sendable {
        public var id: Int {
            self.hashValue
        }
        public let operatingSystem: BuildPlatform
        public let architecture: BuildArchitecture
        public let artifact: UUID
        public let signature: BuildSignature
    }

    /// A version
    public struct Version: Identifiable, Hashable, Codable, Sendable {
        public let id: UUID
        public let publishDate: Date
        public let version: SemanticVersion
        public let updatePriority: UpdatePriority
        public let releaseInfo: UUID
        public let builds: [Build]
    }

    /// A versions file
    public struct VersionsFile: Hashable, Codable, Sendable {
        public let artifacts: [String: Artifact]
        public let versions: [String: Version]
    }

    // Internal

    /// Known signatures
    public struct KnownSignature: Hashable, Codable, Sendable {
        public let algorithm: SignatureAlgorithm
        public let publicKey: Data
    }

    /// Stored metadata
    public struct EngineSidecarMetadata: Hashable, Codable, Sendable {
        public let version: SemanticVersion
        public let versionID: UUID
        public let versionPublishDate: Date
        public let versionUpdatePriority: UpdatePriority
        public let releaseInfo: ReleaseInfo
        public let buildOperatingSystem: BuildPlatform
        public let buildArchitecture: BuildArchitecture
        public let buildSignature: BuildSignature
    }

    public enum GetStoredMetadataError: LocalizedError {
        case urlCreationError
        case fileReadError(Error)
        case plistDecodingError(Error)
    }

    /// Get the stored metadata
    public static func getStoredMetadata() -> Result<EngineSidecarMetadata, GetStoredMetadataError> {
        guard let engineMetadataFile = engineMetadataFile else {
            logger.error("engineMetadataFile is nil.")
            return .failure(.urlCreationError)
        }

        // Fetch the plist
        let plistData: Data
        do {
            plistData = try Data(contentsOf: engineMetadataFile)
        } catch {
            logger.error("Failed to fetch plist: \(error)")
            return .failure(.fileReadError(error))
        }

        // Decode the plist
        let decoder = PropertyListDecoder()
        do {
            let metadata = try decoder.decode(EngineSidecarMetadata.self, from: plistData)
            return .success(metadata)
        } catch {
            logger.error("Failed to decode plist: \(error)")
            return .failure(.plistDecodingError(error))
        }
    }

    public enum SetStoredMetadataError: LocalizedError {
        case urlCreationError
        case pathCreationError(Error)
        case plistEncodingError(Error)
        case fileWriteError(Error)
    }

    /// Set the stored metadata
    public static func setStoredMetadata(_ metadata: EngineSidecarMetadata) -> Result<Void, SetStoredMetadataError> {
        guard let engineMetadataFile = engineMetadataFile else {
            logger.error("engineMetadataFile is nil.")
            return .failure(.urlCreationError)
        }

        // Create the directory
        do {
            if !FileManager.default.fileExists(atPath: engineMetadataFile.deletingLastPathComponent().path) {
                try FileManager.default.createDirectory(at: engineMetadataFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            }
        } catch {
            logger.error("Failed to create directory: \(error)")
            return .failure(.pathCreationError(error))
        }

        // Encode the plist
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        
        let plistData: Data
        do {
            plistData = try encoder.encode(metadata)
        } catch {
            logger.error("Failed to encode plist: \(error)")
            return .failure(.plistEncodingError(error))
        }

        // Write the plist
        do {
            try plistData.write(to: engineMetadataFile)
        } catch {
            logger.error("Failed to write plist: \(error)")
            return .failure(.fileWriteError(error))
        }

        return .success(())
    }

    public enum GetVersionsFileError: LocalizedError {
        case urlCreationError
        case urlSessionError(Error)
        case jsonDecodingError(Error)
    }

    /// Get the versions file
    public static func getVersionsFile(for branch: ReleaseBranch) async -> Result<VersionsFile, GetVersionsFileError> {
        guard let cloudfrontBaseURL = cloudfrontBaseURL else {
            logger.error("cloudfrontBaseURL is nil.")
            return .failure(.urlCreationError)
        }

        let url = cloudfrontBaseURL
            .appendingPathComponent(wineCloudfrontPrefix)
            .appendingPathComponent(branch.rawValue)
            .appendingPathComponent(versionsFile)

        // Fetch the JSON
        let data: Data
        do {
            data = try await URLSession.shared.data(from: url).0
        } catch {
            logger.error("Failed to fetch versions file: \(error)")
            return .failure(.urlSessionError(error))
        }

        // Decode the JSON
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-DD'T'HH:mm:ss.SSS'Z'"
        decoder.dateDecodingStrategy = .formatted(formatter)
        decoder.semanticVersionDecodingStrategy = .semverString

        do {
            let versionsFile = try decoder.decode(VersionsFile.self, from: data)
            return .success(versionsFile)
        } catch {
            logger.error("Failed to decode versions file: \(error)")
            return .failure(.jsonDecodingError(error))
        }
    }

    public enum ArtifactURLError: LocalizedError {
        case urlCreationError
    }

    /// Get the URL of an artifact
    public static func artifactURL(for artifact: Artifact) -> Result<URL, ArtifactURLError> {
        guard let cloudfrontBaseURL = cloudfrontBaseURL else {
            logger.error("cloudfrontBaseURL is nil.")
            return .failure(.urlCreationError)
        }

        let components = artifact.href.components(separatedBy: "/")
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0 }
            .filter { !$0.isEmpty }
            .compactMap({ $0 })

        // Append to the base URL
        var url = cloudfrontBaseURL
        for component in components {
            url = url.appendingPathComponent(component)
        }

        return .success(url)
    }

    /// Verify the checksum of an artifact
    public static func verifyChecksum(of artifact: Artifact, with data: Data) -> Bool {
        switch artifact.hash.algorithm {
        case .blake3:
            // Hash the data
            let hasher = BLAKE3()
            hasher.update(data: data)
            let hash = hasher.finalizeData()
            // Parse the hash as a hex string
            let hexResult = HexParserUtility.parseHexStringToData(artifact.hash.value)
            switch hexResult {
            case .success(let expectedHashData):
                // Compare the hashes
                return hash == expectedHashData
            case .failure(let error):
                logger.error("Failed to parse hash: \(error)")
                return false
            }
        }
    }

    public enum DownloadArtifactError: LocalizedError {
        case urlCreationError(ArtifactURLError)
        case invalidRefError
        case urlSessionError(Error)
        case sizeMismatchError
    }

    /// Download an artifact
    public static func downloadArtifact(_ artifact: Artifact) async -> Result<Data, DownloadArtifactError> {
        let downloadURL: URL
        switch artifactURL(for: artifact) {
            case .success(let url):
            downloadURL = url
            case .failure(let error):
                return .failure(.urlCreationError(error))
        }
        
        // Fetch the data
        let data: Data
        do {
            data = try await URLSession.shared.data(from: downloadURL).0
        } catch {
            logger.error("Failed to fetch artifact: \(error)")
            return .failure(.urlSessionError(error))
        }

        // Verify the size
        if data.count != artifact.byteCount {
            logger.error("Size mismatch: \(data.count) != \(artifact.byteCount)")
            return .failure(.sizeMismatchError)
        }

        return .success(data)
    }

    public static func downloadArtifact(_ artifact: Artifact,
                                        progress: @escaping (Int64, Int64) -> Void
                                        ) async -> Result<Data, DownloadArtifactError> {
        let downloadURL: URL
        switch artifactURL(for: artifact) {
            case .success(let url):
            downloadURL = url
            case .failure(let error):
                return .failure(.urlCreationError(error))
        }

        let data: Data
        do {
            var observerTotalBytes: NSKeyValueObservation?
            var observerCompletedBytes: NSKeyValueObservation?
            data = try await withCheckedThrowingContinuation { continuation in
                let task = URLSession.shared.dataTask(with: downloadURL) { data, _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data {
                        continuation.resume(returning: data)
                    }
                }

                observerTotalBytes = task.observe(\.countOfBytesExpectedToReceive) { task, _ in
                    progress(task.countOfBytesExpectedToReceive, task.countOfBytesReceived)
                }

                observerCompletedBytes = task.observe(\.countOfBytesReceived) { task, _ in
                    progress(task.countOfBytesExpectedToReceive, task.countOfBytesReceived)
                }

                task.resume()
            }
            observerTotalBytes?.invalidate()
            observerCompletedBytes?.invalidate()
        } catch {
            return .failure(.urlSessionError(error))
        }

        if data.count != artifact.byteCount {
            logger.error("Size mismatch: \(data.count) != \(artifact.byteCount)")
            return .failure(.sizeMismatchError)
        }

        return .success(data)
    }

    public enum ParseReleaseInfoError: LocalizedError {
        case jsonDecodingError(Error)
    }

    /// Parse the release info from data
    public static func parseReleaseInfo(from data: Data) -> Result<ReleaseInfo, ParseReleaseInfoError> {
        let decoder = JSONDecoder()
        do {
            let releaseInfo = try decoder.decode(ReleaseInfo.self, from: data)
            return .success(releaseInfo)
        } catch {
            logger.error("Failed to decode release info: \(error)")
            return .failure(.jsonDecodingError(error))
        }
    }

    public enum VerifySignatureError: LocalizedError {
        case base64ParseError
        case unknownSignature
        case hexParserError(HexParserUtility.HexParserError)
        case ed25519PublicKeyCreationError(Error)
    }

    /// Verify an update package
    public static func verifySignature(
        for data: Data,
        with signature: BuildSignature
    ) -> Result<Bool, VerifySignatureError> {
        // Find the known signature that matches the public key
        guard let unsafePublicKeyDoNotUseOrYouWillBeFired = Data(base64Encoded: signature.publicKey) else {
            logger.warning("Signature public key is not valid base64: \(signature.publicKey)")
            return .failure(.base64ParseError)
        }
        guard let knownSignature = Self.knownSignatures.first(where: { $0.publicKey == unsafePublicKeyDoNotUseOrYouWillBeFired && $0.algorithm == signature.algorithm }) else {
            logger.warning("Unknown signature: \(signature.publicKey) \(signature.algorithm)")
            return .failure(.unknownSignature)
        }
        
        // Parse the hex
        let hexResult = HexParserUtility.parseHexStringToData(signature.value)
        let hexData: Data
        switch hexResult {
        case .success(let data):
            hexData = data
        case .failure(let error):
            return .failure(.hexParserError(error))
        }

        // Verify the signature
        switch signature.algorithm {
        case .ed25519:
            // Get the public key (removing PCKS data)
            let publicKeyData = knownSignature.publicKey.subdata(in: 12..<knownSignature.publicKey.endIndex)
            let publicKey: Curve25519.Signing.PublicKey
            do {
                publicKey = try CryptoKit.Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
            } catch {
                return .failure(.ed25519PublicKeyCreationError(error))
            }
            
            return .success(publicKey.isValidSignature(hexData, for: data))
        }
    }

    public enum InstallUpdatePackageError: LocalizedError {
        case urlCreationError
        case filesystemError(Error)
        case tarXZExtractionError(Error)
    }

    public static func installUpdatePackage(at url: URL) async -> Result<Void, InstallUpdatePackageError> {
        // Create the destination directory
        guard let destinationDirectory = Self.engineDirectory else {
            logger.error("Failed to get application support directory.")
            return .failure(.urlCreationError)
        }

        // Delete the engine directory folder if it exists, and create it again
        do {
            if FileManager.default.fileExists(atPath: destinationDirectory.path) {
                try FileManager.default.removeItem(at: destinationDirectory)
            }
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create engine directory: \(error)")
            return .failure(.filesystemError(error))
        }

        // Extract the package (xz format)
        do {
            try await withCheckedThrowingContinuation { continuation in
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                task.arguments = ["-xJf", url.path, "-C", destinationDirectory.path]
                task.terminationHandler = { _ in
                    continuation.resume(with: .success(()))
                }
                do {
                    try task.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } catch {
            logger.error("Failed to run tar process: \(error)")
            return .failure(.tarXZExtractionError(error))
        }

        // Clean up
        try? FileManager.default.removeItem(at: url)

        return .success(())
    }
}
