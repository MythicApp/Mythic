//
//  View.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/6/2025.
//

import Foundation
import SwiftUI

extension View {
    // FIXME: stateful, only conditional
    @ViewBuilder
    func conditionalTransform<Content: View>(if condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    // FIXME: not stateful, versatile
    @ViewBuilder
    func customTransform<Content: View>(@ViewBuilder transform: (Self) -> Content) -> some View {
        transform(self)
    }
}
