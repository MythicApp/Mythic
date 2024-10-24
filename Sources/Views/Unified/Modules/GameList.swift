import Foundation

struct FilterOptions {
    var showInstalled: Bool = false
    var platform: Platform = .all
    var source: GameSource = .all
}

enum Platform: String, CaseIterable {
    case all = "All"
    case mac = "macOS"
    case windows = "Windows®"
}

enum GameSource: String, CaseIterable {
    case all = "All"
    case epic = "Epic"
    case steam = "Steam"
    case local = "Local"
}
