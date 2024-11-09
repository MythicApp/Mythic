//
//  WhatsNewCollection.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 11/9/24.
//

import WhatsNewKit
import SwiftUI

extension MythicApp: WhatsNewCollectionProvider {
    var whatsNewCollection: WhatsNewCollection {
        WhatsNew(
            version: "0.4.1",
            title: "What's new in Mythic",
            features: [
                .init(
                    image: .init(
                        systemName: "ladybug",
                        foregroundColor: .red
                    ),
                    title: "Bug Fixes & Performance Improvements",
                    subtitle: "Y'know, the usual."
                ),
                .init(
                    image: .init(
                        systemName: "checklist",
                        foregroundColor: .blue
                    ),
                    title: "Optional Pack support",
                    subtitle: "Epic Games that support selective downloads are now supported for download (e.g. Fortnite)."
                ),
                .init(
                    image: .init(
                        systemName: "cursorarrow.motionlines",
                        foregroundColor: .accent
                    ),
                    title: "More animations",
                    subtitle: "Added smooth animations and transitions."
                )
            ],
            primaryAction: .init(),
            secondaryAction: .init(
                title: "Learn more",
                action: .openURL(.init(string: "https://github.com/MythicApp/Mythic/releases/tag/v0.4.1"))
            )
        )

        WhatsNew(
            version: "0.4.2",
            title: "What's new in Mythic",
            features: [
                .init(
                    image: .init(
                        systemName: "ladybug.slash",
                        foregroundColor: .red
                    ),
                    title: "Bugfixes",
                    subtitle: "Y'know, the usual."
                ),
                .init(
                    image: .init(
                        systemName: "app.badge.checkmark",
                        foregroundColor: .cyan
                    ),
                    title: "Fixed crashes when verifying imported games",
                    subtitle: "Someone even called it a 'glorified exit button..'"
                ),
                .init(
                    image: .init(
                        systemName: "square.badge.plus.fill",
                        foregroundColor: .pink
                    ),
                    title: "Fixed launch arguments not saving",
                    subtitle: "Protip: you can use [-nomovie] to skip the intro in Rocket League®."
                )
            ],
            primaryAction: .init(),
            secondaryAction: .init(
                title: "Learn more",
                action: .openURL(.init(string: "https://github.com/MythicApp/Mythic/releases/tag/v0.4.2"))
            )
        )

        WhatsNew(
            version: "0.4.3",
            title: "What's new in Mythic",
            features: [
                .init(
                    image: .init(
                        systemName: "ladybug.slash",
                        foregroundColor: .accentColor
                    ),
                    title: "Bugfixes",
                    subtitle: "Y'know, the usual."
                ),
                .init(
                    image: .init(
                        systemName: "macbook.gen1",
                        foregroundColor: .accentColor
                    ),
                    title: "Intel Mac Epic support",
                    subtitle: "Epic functionality is now fully supported on Intel macs."
                )
            ],
            primaryAction: .init(),
            secondaryAction: .init(
                title: "Learn more",
                action: .openURL(.init(string: "https://github.com/MythicApp/Mythic/releases/tag/v0.4.3"))
            )
        )
    }
}

#Preview {
    WhatsNewView(whatsNew: MythicApp().whatsNewCollection.last ?? WhatsNew(title: "N/A", features: []))
}
