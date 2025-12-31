//
//  View+OperationStatusViewModifier.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 11/11/2025.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import SwiftUI

extension View {
    /**
     Create view with status indication during an operation, indicated by a change in the `observing` value.
     
     - Parameters:
     - operating: Automatically managed; `true` during operation, `false` upon completion.
     - successful: Set to `true`/`false` in your action to indicate result. if unnecessary, use `.constant(nil)`.
     - observing: Observed value; action triggers on change.
     - autoReset: Auto-reset `successful` to `nil` after 3 seconds. Defaults to `true`.
     - disablesDuringOperation: Disable view while operating. Defaults to `true`.
     - placement: Status indicator position. Defaults to `.trailing`.
     - action: Async closure executed on value change.
     */
    func withOperationStatus<Value>(
        operating: Binding<Bool>,
        successful: Binding<Bool?>,
        observing value: Binding<Value>,
        autoReset: Bool = true,
        disablesDuringOperation: Bool = true,
        placement: OperationStatusViewModifier.Placement = .trailing,
        action: @escaping () async throws -> Void
    ) -> some View where Value: Equatable {
        self
            .disabled(disablesDuringOperation && operating.wrappedValue)
            .onChange(of: value.wrappedValue) {
                guard $0 != $1 && !operating.wrappedValue else { return }
                
                Task(priority: .userInitiated) {
                    successful.wrappedValue = nil
                    operating.wrappedValue = true
                    
                    defer {
                        operating.wrappedValue = false
                    }
                    
                    try? await action()
                }
            }
            .modifier(
                OperationStatusViewModifier(operating: operating,
                                            successful: successful,
                                            autoReset: autoReset,
                                            placement: placement)
            )
    }
}
