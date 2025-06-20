//
//  LocalGamesV1PersistentStateModel.swift
//  Mythic
//

import Foundation

public struct LocalGamesV1PersistentStateModel: StorablePersistentStateModel.State {
    /// Shared instance.
//    @MainActor public static let shared: StorablePersistentStateModel.Store<Self> = .init()

    public typealias RootType = LocalGames
    public static let persistentStateStoreName = "WineContainersV1"

    public static func defaultValue() -> LocalGames {
        .init()
    }
    
    /// A local game.
    public struct LocalGame: Codable, Hashable, Equatable {
        /// The game's id.
        public var id: UUID
        
    }

    /// All local games.
    public struct LocalGames: Codable, Hashable, Equatable {
        public var games: [UUID:LocalGame] = [:]
    }
}
