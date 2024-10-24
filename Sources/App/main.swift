//
//  main.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 10/23/24.
//

import Foundation
import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
