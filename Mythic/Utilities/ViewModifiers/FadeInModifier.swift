import Foundation
import SwiftUI

struct FadeInModifier: ViewModifier {
    @State var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5)) {
                    opacity = 1
                }
            }
    }
}
