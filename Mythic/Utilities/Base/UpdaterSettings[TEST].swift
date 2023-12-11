//
//  UpdaterSettings.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 29/9/2023.
//

// Copyright © 2023 blackxfiied

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

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
