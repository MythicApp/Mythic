//
//  LegendaryExt.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/10/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎]

import Foundation

extension Legendary {
    /// Enumeration containing the two terminal stream types.
    enum Stream {
        case stdout
        case stderr
    }

    /// Enumeration to specify image types.
    enum ImageType {
        case normal
        case tall
    }

    /// Enumeration containing the activities legendary does that require a data lock.
    enum DataLockUse {
        case installing
        case removing
        case moving
        case none
    }

    // MARK: - GamePlatform Enumeration
    /// Enumeration containing the two different platforms legendary can download games for.
    enum GamePlatform {
        case macOS
        case windows
    }

    // MARK: - ImageError Enumeration
    /// Error for image errors.
    enum ImageError: Error {
        /// Failure to get an image from the source.
        case get

        /// Failure to load an image to Mythic or storage.
        case load
    }

    /// Your father.
    enum DoesNotExistError: Error {
        case game
        case aliases
        case file(file: URL)
        case directory(directory: String)
    }

    /// Struct to store games.
    struct Game: Hashable {
        var appName: String
        var title: String
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
        /// The stream to be checked (stdout or stderr).
        let stream: Stream

        /// The string pattern to be matched in the selected stream's output.
        let string: String
    }

    /// Error when legendary is signed out on a command that enforces signin.
    @available(*, message: "This error will be deprecated soon, in favor of UserValidationError")
    struct NotSignedInError: Error {}

    /// Installation error with a message, see ``Legendary.install()``
    struct InstallationError: Error {
        let message: String

        init(_ message: String) {
            self.message = message
        }
    }

    /// Whether legendary is currently modifying (installing, removing, moving) a game/service.
    static var dataLockInUse: (value: Bool, inUse: DataLockUse) = (true, .installing) // TODO: make datalockinuse variable not always true

    // MARK: - Installing
    struct Progress {
        var percentage: Double
        var downloaded: Int
        var total: Int
        var runtime: Substring
        var eta: Substring
    }

    struct Download {
        var downloaded: Double
        var written: Double
    }

    struct Cache {
        var usage: Double
        var activeTasks: Int
    }

    struct DownloadAdvanced {
        var raw: Double
        var decompressed: Double
    }

    struct Disk {
        var write: Double
        var read: Double
    }

    /// Structure to define legendary's installing output status.
    struct InstallStatus {
        var progress: Progress?
        var download: Download?
        var cache: Cache?
        var downloadAdvanced: DownloadAdvanced?
        var disk: Disk?

        init() {
            self.progress = nil
            self.download = nil
            self.cache = nil
            self.downloadAdvanced = nil
            self.disk = nil
        }
    }

    // MARK: - Installing Class
    /// Class with information on if legendary is currently installing a game/service.
    class Installing: ObservableObject {
        // swiftlint:disable identifier_name
        @Published var _value: Bool = false
        @Published var _finished: Bool = false
        @Published var _game: Game?
        @Published var _status: InstallStatus = InstallStatus()
        // swiftlint:enable identifier_name

        static var shared = Installing()

        static var value: Bool {
            get { return shared._value }
            set {
                DispatchQueue.main.async {
                    shared._value = newValue
                }
            }
        }

        static var finished: Bool {
            get { return shared._finished }
            set {
                DispatchQueue.main.async {
                    shared._value = newValue
                }
            }
        }

        static var game: Game? {
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
            Installing.game = nil
            Installing.installStatus = InstallStatus()
        }
    }
}
