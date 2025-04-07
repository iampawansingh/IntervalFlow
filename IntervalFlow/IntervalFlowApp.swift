//
//  IntervalFlowApp.swift
//  IntervalFlow
//
//  Created by Pawan kumar Singh on 31/03/25.
//

import SwiftUI
import SwiftData

@main
struct IntervalFlowAppApp: App { // Renamed from YourAppNameApp
    var body: some Scene {
        WindowGroup {
            // Embed TimerLogicView, potentially within a NavigationStack
            // if you need navigation to a history view.
            NavigationStack { // Add NavigationStack for navigation features
                TimerLogicView()
                    // Add environment object or modelContext if needed elsewhere
            }
        }
        // Set up the SwiftData container for the TimerSession model
        .modelContainer(for: TimerSession.self)
    }
}
