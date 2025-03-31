//
//  Item.swift
//  IntervalFlow
//
//  Created by Pawan kumar Singh on 31/03/25.
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
