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
}
