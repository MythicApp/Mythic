//
//  LegendaryInterfaceExt.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/10/2023.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

import Foundation

extension Legendary {
    /// Enumeration to specify image types.
    enum ImageType {
        case normal
        case tall
    }

    enum RetrievalType {
        case platform
        case launchArguments
    }

    struct UnableToRetrieveError: LocalizedError {
        var errorDescription: String? = "Mythic is unable to retrive the requested metadata for this game."
    }

    struct IsNotLegendaryError: LocalizedError {
        var errorDescription: String? = "This is not an epic game."
    }
    
    /// A struct to hold closures for handling stdout and stderr output.
    struct OutputHandler {
        /// A closure to handle stdout output.
        let stdout: (String) -> Void
        
        /// A closure to handle stderr output.
        let stderr: (String) -> Void
    }
    
    /// Error when legendary is signed out on a command that enforces signin.
    struct NotSignedInError: LocalizedError {
        var errorDescription: String? = "You aren't signed in to epic games."
    }
    
    /// Installation error with a message, see ``Legendary.install()``
    struct InstallationError: LocalizedError {
        var errorDescription: String? = "Unable to install game."

        init(errorDescription: String) {
            self.errorDescription = errorDescription
        }
    }
}
