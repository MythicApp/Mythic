//
//  Downloads.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 17/3/2024.
//

import SwiftUI

struct DownloadsView: View {
    @ObservedObject private var operation: GameOperation = .shared
    
    var body: some View {
        if operation.current != nil || !operation.queue.isEmpty { // TODO: FIXME: will require change after dl queue is implemented
            List {
                HStack {
                    VStack {
                        HStack {
                            Text("Now Installing")
                            Spacer()
                        }
                        HStack {
                            Text(operation.current?.args.game.title ?? "Unknown")
                                .font(.bold(.title3)())
                            
                            SubscriptedTextView(operation.current?.args.game.type.rawValue ?? "Unknown")
                            Spacer()
                        }
                    }
                    
                    Spacer()
                    
                    InstallationProgressView()
                }
                
                ForEach(operation.queue, id: \.self) { queuedItem in
                    VStack {
                        HStack {
                            Text("Queued")
                            Spacer()
                        }
                        HStack {
                            Text(queuedItem.game.title)
                                .font(.bold(.title3)())
                            
                            SubscriptedTextView(operation.current?.args.game.type.rawValue ?? "Unknown")
                            Spacer()
                        }
                    }
                }
            }
        } else {
            Text("No downloads are queued.")
                .font(.largeTitle.bold())
        }
    }
}

#Preview {
    DownloadsView()
}
