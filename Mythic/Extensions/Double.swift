//
//  Double.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 8/4/2024.
//

import Foundation

extension Double {
    func rounded(_ to: Int) -> Double {
        let multiplier = pow(10, Double(to))
        return Darwin.round(self * multiplier) / multiplier
    }
}
