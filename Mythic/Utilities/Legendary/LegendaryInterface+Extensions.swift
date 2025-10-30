//
//  LegendaryInterface+Extensions.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 10/10/2023.
//

// Copyright © 2023-2025 vapidinfinity

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

    /// Error when legendary is signed out on a command that enforces signin.
    struct NotSignedInError: LocalizedError {
        var errorDescription: String? = "You aren't signed in to Epic Games."
    }

    struct SignInError: LocalizedError {
        var errorDescription: String? = "Unable to sign in to Epic Games."
    }

    /// Installation error with a message, see ``Legendary.install()``
    struct InstallationError: LocalizedError {
        init(reason: String = .init()) {
            self.reason = reason
        }

        var errorDescription: String? { "Unable to install game\(reason.isEmpty ? "" : ": \(reason)")." }
        var reason: String
    }
}
