//
//  StorablePersistentStateModel.swift
//  Mythic
//

import Foundation

public enum StorablePersistentStateModel {
    /// A protcol that indicates required implementations for a persistent state store.
    public protocol State<RootType> {
        associatedtype RootType: Codable, Hashable

        /// The name of the persistent state store.
        static var persistentStateStoreName: String { get }

        /// The default value if the persistent state store is empty.
        static func defaultValue() -> RootType
    }

    /// A abstract class that provides a way to store and retrieve persistent state while conforming to the
    /// `ObservableObject` protocol.
    public class Store<StateType: State>: ObservableObject {
        /// Loggers for the store.
        private let logger = AppLoggerModel(category: Store<StateType>.self)

        /// The URL of the persistent state store.
        private var persistentStateStoreURL: URL? {
            DirectoriesUtility.applicationSupportDirectory?
                .appendingPathComponent("PersistentState")
                .appendingPathComponent(StateType.persistentStateStoreName)
                .appendingPathExtension("plist")
        }

        /// The persistent state store.
        @Published public var store: StateType.RootType {
            didSet {
                save()
            }
        }

        /// Create a new instance of the persistent state store.
        public init() {
            self.store = StateType.defaultValue()
            if let data = load() {
                self.store = data
            }
        }

        /// Load the persistent state store.
        private func load() -> StateType.RootType? {
            guard let persistentStateStoreURL = persistentStateStoreURL else {
                logger.error("URL persistentStateStoreURL is nil for \(StateType.persistentStateStoreName).")
                return nil
            }

            guard let data = try? Data(contentsOf: persistentStateStoreURL) else {
                logger.info("Creating new persistent state store...")
                let defaultValue = StateType.defaultValue()

                // Create the directory if it doesn't exist.
                do {
                    try FileManager.default.createDirectory(at: persistentStateStoreURL.deletingLastPathComponent(),
                                                            withIntermediateDirectories: true,
                                                            attributes: nil)
                } catch {
                    logger.error("Unable to create directory for persistent state store. \(error)")
                }

                // Save the default value.
                do {
                    let data = try PropertyListEncoder().encode(defaultValue)
                    try data.write(to: persistentStateStoreURL)
                } catch {
                    logger.error("Unable to save default persistent state store. \(error)")
                }
                
                return defaultValue
            }

            do {
                let persistentStateStore = try PropertyListDecoder()
                    .decode(StateType.RootType.self, from: data)

                logger.info("Loaded persistent state store.")
                return persistentStateStore
            } catch {
                logger.warning("Unable to decode persistent state store... Creating default. \(error)")
                
                return StateType.defaultValue()
            }
        }

        /// Save the persistent state store.
        private func save() {
            guard let persistentStateStoreURL = persistentStateStoreURL else {
                logger.error("URL persistentStateStoreURL is nil for \(StateType.persistentStateStoreName).")
                return
            }

            do {
                let data = try PropertyListEncoder().encode(store)
                try data.write(to: persistentStateStoreURL)
            } catch {
                logger.error("Unable to save persistent state store. \(error)")
            }
        }
    }
}
