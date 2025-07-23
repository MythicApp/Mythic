//
//  DirectoriesUtility.swift
//  Mythic
//
//  Created by Josh on 10/24/24.
//

import Foundation

public enum DirectoriesUtility {
    /// Mythic's application support directory
    public static var applicationSupportDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent(AppDelegate.bundleIdentifier)
    }

    /// Mythic's container directory
    public static var containerDirectory: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Containers").appendingPathComponent(AppDelegate.bundleIdentifier)
    }

    /// Mythic's temporary directory
    public static var temporaryDirectory: URL? {
        FileManager.default.temporaryDirectory.appendingPathComponent(AppDelegate.bundleIdentifier)
    }
}
