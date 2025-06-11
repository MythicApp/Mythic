//
//  View.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/6/2025.
//

import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    func conditionalTransform<Content: View>(if condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
