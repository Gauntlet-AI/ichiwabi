//
//  Item.swift
//  ichiwabi
//
//  Created by Gauntlet on 2/3/R7.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
