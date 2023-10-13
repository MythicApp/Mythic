//
//  LegendaryExt.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/10/2023.
//

import Foundation

extension Legendary {
    
    /// Enumeration to specify image types
    enum ImageType {
        case normal
        case tall
    }
    
    /// A struct to hold closures for handling stdout and stderr output.
    struct OutputHandler {
        /// A closure to handle stdout output.
        let stdout: (String) -> Void
        
        /// A closure to handle stderr output.
        let stderr: (String) -> Void
    }
    
    
    /// Represents a condition to be checked for in the output streams before input is appended.
    struct InputIfCondition {
        enum Stream {
            case stdout
            case stderr
        }
        
        /// The stream to be checked (stdout or stderr).
        let stream: Stream
        
        /// The string pattern to be matched in the selected stream's output.
        let string: String
    }
    
    
    /// Enumeration containing the activities legendary does that require a data lock.
    enum DataLockUse {
        case installing
        case removing
        case moving
        case none
    }
    
    /// Whether legendary is currently modifying (installing, removing, moving) a game/service.
    static var dataLockInUse: (value: Bool, inUse: DataLockUse) = (true, .installing) // temporarily
    
    // Installing
    
    /// Structure to define legendary's installing output status.
    struct InstallStatus {
        var progress: (
            percentage: Double,
            downloaded: Int,
            total: Int,
            runtime: Substring,
            eta: Substring
        )?
        var download: (
            downloaded: Double,
            written: Double
        )?
        var cache: (
            usage: Double,
            activeTasks: Int
        )?
        var downloadAdvanced: (
            raw: Double,
            decompressed: Double
        )?
        var disk: (
            write: Double,
            read: Double
        )?
        
        init() {
            self.progress = nil
            self.download = nil
            self.cache = nil
            self.downloadAdvanced = nil
            self.disk = nil
        }
    }
    
    /// Class  with information on if legendary is currently installing a game/service.
    class Installing: ObservableObject {
        @Published var _value: Bool = false
        @Published var _game: String = String()
        @Published var _status: InstallStatus = InstallStatus()

        static var shared = Installing()

        static var value: Bool {
            get { return shared._value }
            set {
                DispatchQueue.main.async {
                    shared._value = newValue
                }
            }
        }

        static var game: String {
            get { return shared._game }
            set {
                DispatchQueue.main.async {
                    shared._game = newValue
                }
            }
        }

        static var installStatus: InstallStatus {
            get { return shared._status }
            set {
                DispatchQueue.main.async {
                    shared._status = newValue
                }
            }
        }

        func reset() {
            Legendary.dataLockInUse = (false, .none)
            Installing.value = false
            Installing.game = String()
            Installing.installStatus = InstallStatus()
        }
    }
}
