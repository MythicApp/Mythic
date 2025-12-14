//
//  WhatsNewCollection.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 11/9/24.
//

// Copyright © 2023-2025 vapidinfinity

import WhatsNewKit
import SwiftUI

extension MythicApp: @MainActor WhatsNewCollectionProvider {
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
                    title: "Bugfixes & Performance Improvements",
                    subtitle: "Y'know, the usual."
                ),
                .init(
                    image: .init(
                        systemName: "macbook.gen1",
                        foregroundColor: .accentColor
                    ),
                    title: "Intel Mac Epic support",
                    subtitle: "Epic functionality is now fully supported on Intel macs."
                ),
                .init(
                    image: .init(
                        systemName: "person.badge.shield.checkmark",
                        foregroundColor: .accentColor
                    ),
                    title: "Sign in to Epic Games within Mythic",
                    subtitle: "You no longer need to sign in to Epic separately from Mythic."
                )
            ],
            primaryAction: .init(),
            secondaryAction: .init(
                title: "Learn more",
                action: .openURL(.init(string: "https://github.com/MythicApp/Mythic/releases/tag/v0.4.3"))
            )
        )

        WhatsNew(
            version: "0.4.4",
            title: "What's new in Mythic",
            features: [
                .init(
                    image: .init(
                        systemName: "ladybug",
                        foregroundColor: .red
                    ),
                    title: "Bug Fixes & Performance Improvements",
                    subtitle: "A critical crash to do with the Epic Games signin window has been fixed, among other miscallaneous fixes."
                ),
                .init(
                    image: .init(
                        systemName: "gear.badge.checkmark",
                        foregroundColor: .orange
                    ),
                    title: "Overhauled settings view",
                    subtitle: "Implemented intuitive navigation on users with macOS 15 (Sequoia) or above."
                ),
                .init(
                    image: .init(
                        systemName: "square.grid.2x2",
                        foregroundColor: .green
                    ),
                    title: "Revamped library view",
                    subtitle: "Scroll, resize, and adjust game cards to your liking."
                ),
                .init(
                    image: .init(
                        systemName: "gamecontroller.circle",
                        foregroundColor: .teal
                    ),
                    title: "Improved game compatibility",
                    subtitle: "DXVK and AVX2 are now integrated into Mythic."
                )
            ],
            primaryAction: .init(),
            secondaryAction: .init(
                title: "Learn more",
                action: .openURL(.init(string: "https://github.com/MythicApp/Mythic/releases/tag/v0.4.4"))
            )
        )

        WhatsNew(
            version: "0.4.5",
            title: "What's new in Mythic",
            features: [
                .init(
                    image: .init(
                        systemName: "ladybug",
                        foregroundColor: .red
                    ),
                    title: "Bug Fixes & Performance Improvements",
                    subtitle: "Back to just the usual. 🙏🏾"
                ),
                .init(
                    image: .init(
                        systemName: "person.badge.shield.exclamationmark",
                        foregroundColor: .orange
                    ),
                    title: "Added fallback signin view support",
                    subtitle: "Users can now sign into Epic Games accounts through third parties by using the fallback signin view."
                ),
                .init(
                    image: .init(
                        systemName: "progress.indicator",
                        foregroundColor: .purple
                    ),
                    title: "Immediate game library population",
                    subtitle: "Mythic's game library will now immediately populate upon signing in."
                ),
                .init(
                    image: .init(image: {
                        Image("HarmonyIcon")
                            .resizable()
                            .scaledToFit()
                    }),
                    title: "Stay tuned! 👀",
                    subtitle: "Something's coming to Mythic."
                )
            ],
            primaryAction: .init(),
            secondaryAction: .init(
                title: "Learn more",
                action: .openURL(.init(string: "https://github.com/MythicApp/Mythic/releases/tag/v0.4.5"))
            )
        )

        WhatsNew(
            version: "0.5.0",
            title: "What's new in Mythic",
            features: [
                .init(
                    image: .init(systemName: "ladybug"),
                    title: "Bug Fixes & Performance Improvements",
                    subtitle: "A fair bit of bugfixes this time around."
                ),
                .init(
                    image: .init(systemName: "macwindow"),
                    title: "Brand New Interface",
                    subtitle: "Mythic now uses Apple's new 'Liquid Glass' design language (and looks amazing doing it!)"
                ),
                .init(
                    image: .init(systemName: "figure.wave"),
                    title: "Overhauled Onboarding Experience",
                    subtitle: "Reimagined for speed and ease-of-use."
                ),
                .init(
                    image: .init(systemName: "macwindow.and.pointer.arrow"),
                    title: "Improved View Responsiveness",
                    subtitle: "Smoother scrolling, snappier animations, happier everyone!!"
                ),
                .init(
                    image: .init(systemName: "curlybraces"),
                    title: "Codebase Improvements",
                    subtitle: "Refactored EVERYTHING for Swift 6 safety and swiftness."
                )
            ],
            primaryAction: .init(),
            secondaryAction: .init(
                title: "Learn more",
                action: .openURL(.init(string: "https://github.com/MythicApp/Mythic/releases/tag/v0.5.0"))
            )
        )
        
        WhatsNew(
            version: "0.6.0",
            title: "What's new in Mythic",
            features: [
                .init(
                    image: .init(systemName: "ladybug.slash"),
                    title: "Major bug fixes and performance improvements",
                    subtitle: """
                        Mythic has undergone a complete logical rewrite to address long-standing critical bugs and issues.
                        This update brings better performance, lower resource usage, and better error handling, providing the foundation for Mythic's full release.
                        """
                ),
                .init(
                    image: .init(systemName: "progress.indicator"),
                    title: "Redesigned Downloads (now Operations) view",
                    subtitle: "\"it looks so good i can't even lie someone hire me\" — vapidinfinity, the developer"
                ),
                .init(
                    image: .init(systemName: "list.bullet.below.rectangle"),
                    title: "Redesigned list library view",
                    subtitle: "\"dude im on a roll this is fire\" — vapidinfinity, the developer"
                ),
                .init(
                    image: .init(systemName: "app.badge.checkmark"),
                    title: "View operation progress directly from the dock",
                    subtitle: "Yup. View your game operation's progress, without even having to open Mythic."
                ),
                .init(
                    image: .init(systemName: "questionmark"),
                    title: "wait. i'm goated?",
                    subtitle: "you should donate if you love Mythic. Find the donation link in \"Help\" on your Mac's menu bar."
                )
            ],
            primaryAction: .init(),
            secondaryAction: .init(
                title: "Learn more",
                action: .openURL(.init(string: "https://github.com/MythicApp/Mythic/releases/tag/v0.6.0"))
            )
        )
        
        // TODO: optimise release schedule + localise
    }
}

#Preview {
    WhatsNewView(whatsNew: MythicApp().whatsNewCollection.last ?? WhatsNew(title: "N/A", features: []))
}
