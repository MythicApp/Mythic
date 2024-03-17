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
    
    // MARK: - ImageError Enumeration
    /// Error for image errors.
    enum ImageError: Error {
        /// Failure to get an image from the source.
        case get
        
        /// Failure to load an image to Mythic or storage.
        case load
    }
    
    struct UnableToGetPlatformError: LocalizedError { 
        var errorDescription: String? = "Mythic is unable to get the platform of this game."
    }
    
    struct IsNotLegendaryError: LocalizedError { 
        var errorDescription: String? = "This is not an epic game."
    }
    
    // GameDoesNotExistError unified!
    
    /// Struct to store games.
    @available(*, deprecated, message: "Replaced by Mythic.Game")
    struct Game: Hashable, Codable {
        var id: String
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
    struct NotSignedInError: LocalizedError {
        var errorDescription: String? = "You aren't signed in to epic games"
    }
    
    /// Installation error with a message, see ``Legendary.install()``
    struct InstallationError: LocalizedError {
        init(message: String) { self.message = message }
        
        let message: String
        var errorDescription: String? = "Unable to install game." // TODO: message
    }
}
