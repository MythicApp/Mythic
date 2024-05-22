//
//  UpdaterSettingsView.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

// Reference: https://sparkle-project.org/documentation/preferences-ui/#adding-settings-in-swiftui

import SwiftUI
import Sparkle

// This is the view for our updater settings
// It manages local state for checking for updates and automatically downloading updates
// Upon user changes to these, the updater's properties are set. These are backed by NSUserDefaults.
// Note the updater properties should *only* be set when the user changes the state.

struct UpdaterSettingsView: View {
    private let updater: SPUUpdater
    
    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool
    
    init(updater: SPUUpdater) {
        self.updater = updater
        self._automaticallyChecksForUpdates = State(initialValue: updater.automaticallyChecksForUpdates)
        self._automaticallyDownloadsUpdates = State(initialValue: updater.automaticallyDownloadsUpdates)
    }
    
    var body: some View {
        VStack {
            Toggle("Automatically check for updates", isOn: Binding(
                get: { automaticallyChecksForUpdates },
                set: { newValue in
                    automaticallyChecksForUpdates = newValue
                    updater.automaticallyChecksForUpdates = newValue
                }
            ))
            
            Toggle("Automatically download updates", isOn: Binding(
                get: { automaticallyDownloadsUpdates },
                set: { newValue in
                    automaticallyDownloadsUpdates = newValue
                    updater.automaticallyDownloadsUpdates = newValue
                }
            ))
            .disabled(!automaticallyChecksForUpdates)
        }
        .padding()
    }
}
