//
//  BackgroundEventServiceModel.swift
//  Mythic
//
//  Created by Josh on 10/24/24.
//

import Foundation

public struct BackgroundEventServiceModel: Sendable {
    /// Shared instance.
    public static let shared = BackgroundEventServiceModel()

    /// The dispatch queue for the events
    public let queue: DispatchQueue = DispatchQueue(label: "app.getmythic.Mythic.BackgroundEventService",
                                                     qos: .background)
}
