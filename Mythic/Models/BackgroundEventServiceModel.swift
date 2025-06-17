//
//  BackgroundEventServiceModel.swift
//  Mythic
//
//  Created by Josh on 10/24/24.
//

import Foundation

public struct BackgroundEventServiceModel {
    /// Shared instance.
    public private(set) static var shared = BackgroundEventServiceModel()

    /// The dispatch queue for the events
    public let queue: DispatchQueue = DispatchQueue(label: "app.getmythic.MythicMacOS.BackgroundEventService",
                                                     qos: .background)
}
