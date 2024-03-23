//
//  Downloads.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 17/3/2024.
//

/*
 _  __
(_)/ /
 _| |
(_) |     _   _    _
 _ \_\___| |_| |_ (_)_ _  __ _
| ' \/ _ \  _| ' \| | ' \/ _` |
|_||_\___/\__|_||_|_|_||_\__, |
| |_ ___   ___ ___ ___   |___/
|  _/ _ \ (_-</ -_) -_)
 \__\___/ /__/\___\___|      _
| |_  ___ _ _ ___   _  _ ___| |_
| ' \/ -_) '_/ -_) | || / -_)  _|
|_||_\___|_| \___|  \_, \___|\__|
                    |__/
 */

import SwiftUI

struct DownloadsView: View {
    @ObservedObject private var gameModification: GameModification = .shared
    
    var body: some View {
        if gameModification.game != nil { // TODO: FIXME: will require change after dl queue is implemented
            List {
                HStack { // will eventually foreach when dl queue is implemented
                    
                    VStack {
                        HStack {
                            Text("Now Installing")
                            Spacer()
                        }
                        HStack {
                            Text(gameModification.game?.title ?? "Unknown")
                                .font(.bold(.title3)())
                            
                            SubscriptedTextView(gameModification.game?.type.rawValue ?? "Unknown")
                            Spacer()
                        }
                    }
                    
                    Spacer()
                    
                    InstallationProgressView()
                }
            }
            .formStyle(.automatic)
        } else {
            Text("No downloads are queued.")
                .font(.largeTitle.bold())
        }
    }
}

#Preview {
    DownloadsView()
}
