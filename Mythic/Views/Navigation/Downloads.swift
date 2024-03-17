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
    var body: some View {
        Form {
            InstallationProgressView()
        }
        .formStyle(.automatic)
    }
}

#Preview {
    DownloadsView()
}
