//
//  StarRatingView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 16/1/2025.
//

import Foundation
import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    @Binding var hoveringOverIndex: Int
    @State var isInteractive: Bool = true

    var body: some View {
        HStack {
            ForEach(1..<6) { index in
                Image(systemName: "star")
                    .symbolVariant(hoveringOverIndex >= index ? .fill : .none)
                    .shadow(color: .secondary, radius: hoveringOverIndex == index ? 10 : 0)
                    .onHover { hovering in
                        if isInteractive {
                            withAnimation {
                                hoveringOverIndex = hovering ? index : hoveringOverIndex
                            }
                        }
                    }
                    .onTapGesture {
                        if isInteractive {
                            withAnimation {
                                rating = index
                            }
                        }
                    }
            }
        }
        .onAppear {
            withAnimation {
                hoveringOverIndex = rating
            }
        }
        .onHover { hovering in
            withAnimation {
                hoveringOverIndex = hovering ? hoveringOverIndex : rating
            }
        }
        .imageScale(.large)
    }
}
