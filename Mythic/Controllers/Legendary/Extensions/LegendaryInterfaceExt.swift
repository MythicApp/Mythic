//
//  LegendaryInterfaceExt.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/10/2023.
//

// MARK: - Copyright
// Copyright © 2023 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

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
    
    enum InstallationType {
        case install
        case update
        case repair
    }
    
    // MARK: - ImageError Enumeration
    /// Error for image errors.
    enum ImageError: Error {
        /// Failure to get an image from the source.
        case get
        
        /// Failure to load an image to Mythic or storage.
        case load
    }
    
    struct UnableToGetPlatformError: Error {  }
    
    /// Your father.
    struct GameDoesNotExistError: Error {
        init(_ game: Game) { self.game = game }
        let game: Game
    }
    
    /// Struct to store games.
    struct Game: Hashable, Codable {
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
        init(_ message: String) { self.message = message }
        
        let message: String
    }
}
