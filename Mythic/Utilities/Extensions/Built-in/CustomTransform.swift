//
//  CustomTransform.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 13/6/2025.
//

struct CustomTransform<Content: View>: ViewModifier {
    let transform: (Content) -> Content
    
    init(@ViewBuilder transform: @escaping (Content) -> Content) {
        self.transform = transform
    }
    
    func body(content: Content) -> some View {
        transform(content)
    }
}

extension View {
    func customTransform<Content: View>(@ViewBuilder _ transform: @escaping (Self) -> Content) -> some View {
        self.modifier(CustomTransform(transform: transform))
    }
}
