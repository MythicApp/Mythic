//
//  OperationButton.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 11/11/2025.
//

// Copyright © 2023-2025 vapidinfinity

import Foundation
import SwiftUI

struct OperationButton<Label>: View where Label: View {
    @Binding var operating: Bool
    @Binding var successful: Bool?
    let action: () async -> Void
    let label: () -> Label
    let autoReset: Bool
    let disablesDuringOperation: Bool
    let placement: OperationStatusViewModifier.Placement

    private func executeActionTask() {
        Task(priority: .userInitiated) {
            successful = nil
            withAnimation {
                operating = true
            }

            defer {
                withAnimation {
                    operating = false
                }
            }

            await action()
        }
    }

    var body: some View {
        Button(action: executeActionTask, label: label)
            .disabled(disablesDuringOperation && operating)
            .modifier(
                OperationStatusViewModifier(operating: $operating,
                                            successful: $successful,
                                            autoReset: autoReset,
                                            placement: placement)
            )
    }
}

extension OperationButton {
    /**
     - Parameters:
        - operating: Automatically managed; `true` during operation, `false` upon completion.
        - successful: Set to `true`/`false` in your action to indicate result.
        - autoReset: Auto-reset `successful` to `nil` after 3 seconds. Defaults to `true`.
        - disablesDuringOperation: Disable button while operating. Defaults to `true`.
        - placement: Status indicator position. Defaults to `.trailing`.
        - action: Async closure executed on tap.
        - label: View builder for button label.
     */
    init(
        operating: Binding<Bool>,
        successful: Binding<Bool?>,
        autoReset: Bool = true,
        disablesDuringOperation: Bool = true,
        placement: OperationStatusViewModifier.Placement = .trailing,
        action: @escaping () async -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self._operating = operating
        self._successful = successful
        self.action = action
        self.label = label
        self.autoReset = autoReset
        self.disablesDuringOperation = disablesDuringOperation
        self.placement = placement
    }
}

extension OperationButton where Label == Text {
    /**
     - Parameters:
        - title: Button text.
        - operating: Automatically managed; `true` during operation, `false` upon completion.
        - successful: Set to `true`/`false` in your action to indicate result.
        - autoReset: Auto-reset `successful` to `nil` after 3 seconds. Defaults to `true`.
        - disablesDuringOperation: Disable button while operating. Defaults to `true`.
        - placement: Status indicator position. Defaults to `.trailing`.
        - action: Async closure executed on tap.
     */
    init(
        _ title: String,
        operating: Binding<Bool>,
        successful: Binding<Bool?>,
        autoReset: Bool = true,
        disablesDuringOperation: Bool = true,
        placement: OperationStatusViewModifier.Placement = .trailing,
        action: @escaping () async -> Void
    ) {
        self.init(operating: operating,
                  successful: successful,
                  autoReset: autoReset,
                  disablesDuringOperation: disablesDuringOperation,
                  placement: placement,
                  action: action,
                  label: { Text(title) })
    }
}

extension OperationButton where Label == SwiftUI.Label<Text, Image> {
    /**
     - Parameters:
        - title: Button text.
        - systemImage: SF Symbol name.
        - operating: Automatically managed; `true` during operation, `false` upon completion.
        - successful: Set to `true`/`false` in your action to indicate result.
        - autoReset: Auto-reset `successful` to `nil` after 3 seconds. Defaults to `true`.
        - disablesDuringOperation: Disable button while operating. Defaults to `true`.
        - placement: Status indicator position. Defaults to `.trailing`.
        - action: Async closure executed on tap.
     */
    init(
        _ title: String,
        systemImage: String,
        operating: Binding<Bool>,
        successful: Binding<Bool?>,
        autoReset: Bool = true,
        disablesDuringOperation: Bool = true,
        placement: OperationStatusViewModifier.Placement = .trailing,
        action: @escaping () async -> Void
    ) {
        self.init(operating: operating,
                  successful: successful,
                  autoReset: autoReset,
                  disablesDuringOperation: disablesDuringOperation,
                  placement: placement,
                  action: action,
                  label: { Label(title, systemImage: systemImage) })
    }
}
