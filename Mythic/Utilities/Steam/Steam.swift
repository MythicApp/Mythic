//
//  SteamInterface.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 27/7/2024.
//

// MARK: - Copyright
// Copyright © 2024 blackxfiied, Jecta

// This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

// You can fold these comments by pressing [⌃ ⇧ ⌘ ◀︎], unfold with [⌃ ⇧ ⌘ ▶︎]

// Reference: https://developer.valvesoftware.com/wiki/SteamCMD

// TODO: steamcmd autoupdater parser
// TODO: use licenses_print to get all available games' IDs -- see steam-cli GH src for more ino
// TODO: onetap steam gui installer -- for DRM
// TODO: user-interactive shell?
// TODO: use find <command> to search for other commands -- steamcmd docs are literally nonexistent
// TODO: use steamcmd app decorators to change behaviour eg @ShutdownOnFailedCommand 1, @NoPromptForPassword 1, @sSteamCmdForcePlatformType windows -- you can use pluses on these
// FIXME: ^^ only windows games will be playable on Mythic... DRM means steam needs to be DL'd on either host or wine
// TODO: SHELL STARTUP: force_install_dir \(FileLocations.globalGames?.absoluteString)
// TODO: use steamcmd runscript combined with heredoc to emulate a file being passed in, example:
/*
./steamcmd +runscript <<EOF
[example command]
quit
EOF
 *//*
 Connecting to your Steam account using steamcmd is similar to using the
 regular Steam client UI. You can login, logout, and set your Steam Guard
 email code. Any other account management should be done using the Steam
 client UI.

 The first time logging in to a given account on this machine, you'll need to
 specify the password. For subsequent sessions you can omit the password;
 using the 'logout' command will clear those cached credentials (your
 password is never stored locally) and require a password on the next login.
 If the password is required but not supplied as part of the 'login' command,
 you will be prompted for a password. To disable this prompt, first set the
 '@NoPromptForPassword' ConVar to 1 (see the help topic 'convars' for more
 info). If the prompt is disabled and the password is required, the login
 command will fail.

 Note: you may login anonymously using "login anonymous" if the content you
 wish to download is available for anonymous access.
 */

// regex this: Update state (0x61) downloading, progress: 99.91 (1103729421 / 1104777997)
// look for this: Success! App '291550' fully installed.

import Foundation
import OSLog

final class Steam {
    internal static let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "steam")
    
    static var installed: Bool {
        files.fileExists(atPath: directory.appending(path: "steamcmd").path(percentEncoded: false))
    }
    
    static let directory: URL = Bundle.appHome!.appending(path: "Steam")
    
    private static let steamcmd: URL = directory.appending(path: "steamcmd")
    
    static func install() async throws { // you can specify +login..., +whatever command... w/o using the steam shell
        if !files.fileExists(atPath: directory.path) {
            try files.createDirectory(at: directory, withIntermediateDirectories: false)
        }
        
        try Process.execute("/bin/bash", arguments: ["-c", "curl -sqL \"https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz\" | tar zxvf - -C \(directory)"])
        
        if installed { /* return completion */ }
    }
    
    static func uninstall() throws {
        try files.removeItem(at: directory)
    }
}