//
//  SupportView.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 12/9/2023.
//

// Copyright © 2023-2025 vapidinfinity

import SwiftUI
import AppKit
import SwordRPC

struct SupportView: View {
    
    var body: some View {
        Text("Support")
            .font(.title)
            .fontWeight(.bold)
            .frame(maxWidth: 400, alignment: .leading)
            .padding(.leading)
            
        Spacer()
            
        VStack {
            Text("Resources")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: 400, alignment: .leading)
            HStack{
                Button("Documentation"){
                    openLink(urlString: "https://docs.getmythic.app/")
                }
                verticalDivider(height: 30)
                Button("FAQ"){
                    openLink(urlString: "https://getmythic.app/faq/")
                }
                verticalDivider(height: 30)
                Button("Compatibility List"){
                    openLink(urlString: "https://docs.google.com/spreadsheets/d/1W_1UexC1VOcbP2CHhoZBR5-8koH-ZPxJBDWntwH-tsc/")
                }
            }
            .padding(.bottom)
            .frame(maxWidth: 400, alignment: .leading)
            
            Text("Recieve Help")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: 400, alignment: .leading)
            HStack{
                Button("Report an issue"){
                    openLink(urlString: "https://github.com/MythicApp/Mythic/issues")
                }
                verticalDivider(height: 30)
                Button("Create a support ticket"){
                    openLink(urlString: "https://discord.gg/kQKdvjTVqh")
                }
            }
            .frame(maxWidth: 400, alignment: .leading)
        }
        .padding([.leading, .bottom])
        .frame(maxWidth: 400, alignment: .leading)
            
        Spacer()
        
        VStack{
            Text("\(Image(systemName: "exclamationmark.triangle.fill")) Go through all resources before reporting an issue.")
                .font(.footnote)
                .frame(maxWidth: 400, alignment: .leading)
                .padding([.leading, .bottom])
        }
        .task(priority: .background) {
            // Set rich presence using SwordRPC
            discordRPC.setPresence({
                var presence = RichPresence()
                presence.details = "Looking for help"
                presence.state = "Viewing Support"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"
                return presence
            }())
        }
        .navigationTitle("Support")
    }
}

public class SupportWindowController: NSWindowController {
    static var shared: SupportWindowController?
    
    convenience init() {
        let supportView = SupportView()
        let hosting = NSHostingController(rootView: supportView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [
                .titled,
                .closable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden
        
        if let zoomButton = window.standardWindowButton(.zoomButton) {
            zoomButton.isEnabled = false
        }
            
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 28),
            hosting.view.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        ])
        
        window.contentView = visualEffectView
        window.center()
        self.init(window: window)
    }
        
    static func show() {
        if let existing = shared {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            let controller = SupportWindowController()
            shared = controller
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
    
private func openLink(urlString: String) {
    if let url = URL(string: urlString) {
        NSWorkspace.shared.open(url)
    }
}
    
@ViewBuilder
private func verticalDivider(height: CGFloat) -> some View {
    Divider()
        .frame(width: 1, height: height)
}

#Preview {
    SupportView()
}
