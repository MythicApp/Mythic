//
//  SwordRPC.swift
//  Mythic
//
//  Created by vapidinfinity (esi) on 13/1/2025.
//

import Foundation
import SwordRPC

extension SwordRPC {
    var isDiscordInstalled: Bool {
        let discordURLScheme: URL = .init(string: "discord://")!
        return workspace.urlForApplication(toOpen: discordURLScheme) != nil
    }
}
