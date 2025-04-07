//
//  TimerSession.swift
//  IntervalFlow
//
//  Created by Pawan kumar Singh on 31/03/25.
//

import SwiftData
import Foundation

@Model
final class TimerSession {
    var date: Date // Timestamp when the session ended/was saved
    var estimatedDuration: Int // Estimated total duration based on settings (seconds)
    var actualDuration: Int // Actual time elapsed during the session (seconds)
    var wasCompleted: Bool // True if timer finished all reps, false if reset/interrupted
    // Optional: Store the settings used for this session
    var workDurationSetting: Int
    var totalRepsSetting: Int
    var gapDurationSetting: Int
    var breakDurationSetting: Int
    var repsPerBreakSetting: Int

    init(date: Date = Date(), estimatedDuration: Int, actualDuration: Int, wasCompleted: Bool, workDurationSetting: Int, totalRepsSetting: Int, gapDurationSetting: Int, breakDurationSetting: Int, repsPerBreakSetting: Int) {
        self.date = date
        self.estimatedDuration = estimatedDuration
        self.actualDuration = actualDuration
        self.wasCompleted = wasCompleted
        self.workDurationSetting = workDurationSetting
        self.totalRepsSetting = totalRepsSetting
        self.gapDurationSetting = gapDurationSetting
        self.breakDurationSetting = breakDurationSetting
        self.repsPerBreakSetting = repsPerBreakSetting
    }
}
