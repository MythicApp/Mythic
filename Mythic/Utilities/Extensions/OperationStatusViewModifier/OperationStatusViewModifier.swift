//
//  OperationStatusViewModifier.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 10/11/2025.
//

// Copyright © 2023-2026 vapidinfinity

import Foundation
import SwiftUI

struct OperationStatusViewModifier: ViewModifier {
    @Binding var operating: Bool
    @Binding var successful: Bool?
    let autoReset: Bool
    let placement: Placement

    enum Placement {
        case leading
        case trailing
        case overlapping
    }

    func body(content: Content) -> some View {
        layout(content)
    }

    @ViewBuilder
    private func layout(_ content: Content) -> some View {
        switch placement {
        case .trailing:
            HStack {
                content
                indicator
            }
        case .leading:
            HStack {
                indicator
                content
            }
        case .overlapping:
            if operating || successful != nil {
                indicator
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private var indicator: some View {
        if operating {
            ProgressView()
                .controlSize(.small)
        } else if let isSuccessful: Bool = successful {
            Image(systemName: isSuccessful ? "checkmark" : "xmark")
                .help("Operation \(isSuccessful ? "successfully completed" : "failed to complete").")
                .symbolVariant(.circle.fill)
                .transition(.scale.combined(with: .opacity))
                .task {
                    if autoReset {
                        try? await Task.sleep(for: .seconds(isSuccessful ? 3 : 5))
                        await MainActor.run {
                            withAnimation {
                                successful = nil
                            }
                        }
                    }
                }
        }
    }
}
