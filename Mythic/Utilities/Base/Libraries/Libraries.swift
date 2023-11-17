//
//  Libraries.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 24/10/2023.
//

import Foundation
import ZIPFoundation
import CryptoKit
import OSLog

fileprivate let files = FileManager.default

class Libraries {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "Libraries"
    )
    
    static let directory = Bundle.appHome!.appending(path: "Libraries")
    
    private static let dataLock = NSLock()
    
    /// Check the Libraries folder's checksum.
    static func checksum() -> String {
        var dataAggregate = Data()
        
        if let enumerator = FileManager.default.enumerator(atPath: directory.path) {
            for case let fileURL as URL in enumerator {
                do { try dataAggregate.append(Data(contentsOf: fileURL)) }
                catch { Logger.file.error("Error reading libraries and generating a checksum: \(error)") }
            }
        }
        
        let checksum = dataAggregate.hash.map { String(format: "%02hhx", $0) }.joined()
        
        return checksum
    }
    
    @available(*, message: "known issue: lock is blocking thread, leads to hangs. workaround: DQ async")
    /// Install Libraries, as MythicGPTKBuilder artifacts
    static func install(
        downloadProgressHandler: @escaping (Double) -> Void,
        installProgressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) { // storage check later?
        guard !isInstalled() else { completion(.failure(AlreadyInstalledError())); return }
        
        dataLock.lock()
        
        let session = URLSession(configuration: URLSessionConfiguration.default)
        
        let installProgress = Progress(totalUnitCount: 100)
        
        let download = session.downloadTask(
            with: URL(string: "https://nightly.link/MythicApp/GPTKBuilder/workflows/build-gptk/main/Libraries.zip")!
        ) { (file, response, error) in
            guard error == nil else {
                Logger.network.error("Error with GPTK download: \(error)")
                 completion(.failure(error!))
                return
            }
            
            if let file = file {
                defer { dataLock.unlock() }
                do {
                    Logger.file.notice("Installing libraries...")
                    try files.unzipItem(at: file, to: directory, progress: installProgress)
                    Logger.file.notice("Finished downloading and installing libraries.")
                    
                    let checksum = checksum()
                    UserDefaults.standard.set(checksum, forKey: "LibrariesChecksum")
                    Logger.file.notice("Libraries checksum is: \(checksum)")
                    
                    completion(.success(true))
                } catch {
                    Logger.file.error("Unable to install libraries to \(directory.relativePath): \(error)")
                    completion(.failure(error))
                }
            }
        }
        
        let queue = DispatchQueue(label: "InstallProgress")
        
        queue.async {
            while !download.progress.isFinished {
                downloadProgressHandler(((Double(download.countOfBytesReceived) / Double(600137702)))) // rough estimate as of 235579c
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        
        queue.async {
            while !installProgress.isFinished {
                installProgressHandler(installProgress.fractionCompleted)
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        
        download.resume()
    }
    
    static func isInstalled() -> Bool {
        return
            files.fileExists(atPath: directory.path) &&
            checksum() == UserDefaults.standard.string(forKey: "LibrariesChecksum")
        ? true: false
    }
    
    static func remove() -> Result<Bool, Error> {
        guard isInstalled() else { return .failure(NSError()) }
        defer { dataLock.unlock() }
        
        dataLock.lock()
        
        do {
            try files.removeItem(at: directory)
            return .success(true)
        } catch {
            Logger.file.error("Unable to remove libraries: \(error)")
            return .failure(error)
        }
    }
}
