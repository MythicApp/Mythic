//
//  RichAlertView.swift
//  Mythic
//

import SwiftUI

public struct RichAlertView<
    TitleContent: View,
    MessageContent: View,
    Content: View,
    LeadingContent: View,
    TrailingContent: View
>: View {
    public let title: (() -> TitleContent)
    public let message: (() -> MessageContent)
    public let content: (() -> Content)
    public let buttonsLeading: (() -> LeadingContent)
    public let buttonsTrailing: (() -> TrailingContent)

    public init(
        title: @escaping () -> TitleContent,
        message: @escaping (() -> MessageContent) = EmptyView.init,
        content: @escaping (() -> Content) = EmptyView.init,
        buttonsLeft: @escaping (() -> LeadingContent) = EmptyView.init,
        buttonsRight: @escaping (() -> TrailingContent) = EmptyView.init
    ) {
        self.title = title
        self.message = message
        self.content = content
        self.buttonsLeading = buttonsLeft
        self.buttonsTrailing = buttonsRight
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            BundleIconView()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    title().bold()
                    if MessageContent.self != EmptyView.self {
                        message().foregroundStyle(.secondary)
                    }
                }
                if Content.self != EmptyView.self {
                    content()
                }
                HStack(spacing: 8) {
                    if LeadingContent.self != EmptyView.self {
                        buttonsLeading()
                    }
                    Spacer()
                    if TrailingContent.self != EmptyView.self {
                        buttonsTrailing()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .frame(width: 448)
    }
}

#Preview {
    RichAlertView(
        title: { Text("Title") },
        message: { Text("Message") },
        content: { Text("Content") },
        buttonsLeft: { Button("Left") {} },
        buttonsRight: { Button("Right") {} }
    )
}
