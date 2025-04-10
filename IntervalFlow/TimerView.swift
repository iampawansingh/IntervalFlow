//
//  TimerView.swift
//  IntervalFlow
//
//  Created by Pawan kumar Singh on 31/03/25.
//

import SwiftUI
import Combine
import AVFoundation
import UIKit
// Removed SwiftData import

// SwiftData Model Removed

struct TimerLogicView: View {

    // SwiftData Model Context Removed

    // MARK: - UserDefaults Keys
    private enum SettingsKeys {
        static let timerDuration = "timerDurationValue"
        static let totalReps = "totalRepsValue"
        static let breakDuration = "breakDurationValue"
        static let repsPerBreak = "repsPerBreakValue"
        static let gapDuration = "gapDurationValue"
    }

    // MARK: - Input State Variables (Loading from UserDefaults)
    @State private var timerDurationValue: Double = UserDefaults.standard.double(forKey: SettingsKeys.timerDuration).isZero ? 30.0 : UserDefaults.standard.double(forKey: SettingsKeys.timerDuration)
    @State private var totalRepsValue: Double = UserDefaults.standard.double(forKey: SettingsKeys.totalReps).isZero ? 10.0 : UserDefaults.standard.double(forKey: SettingsKeys.totalReps)
    @State private var breakDurationValue: Double = UserDefaults.standard.double(forKey: SettingsKeys.breakDuration).isZero ? 60.0 : UserDefaults.standard.double(forKey: SettingsKeys.breakDuration)
    @State private var repsPerBreakValue: Double = UserDefaults.standard.double(forKey: SettingsKeys.repsPerBreak).isZero ? 5.0 : UserDefaults.standard.double(forKey: SettingsKeys.repsPerBreak)
    @State private var gapDurationValue: Double = UserDefaults.standard.double(forKey: SettingsKeys.gapDuration).isZero ? 5.0 : UserDefaults.standard.double(forKey: SettingsKeys.gapDuration)

    // Define slider ranges
    private let durationRange: ClosedRange<Double> = 1...300
    private let repsRange: ClosedRange<Double> = 1...100
    private let breakRange: ClosedRange<Double> = 0...300
    private let repsPerBreakRange: ClosedRange<Double> = 1...100 // Min is 1, conceptually 0 isn't needed
    private let gapRange: ClosedRange<Double> = 0...60

    // MARK: - Internal Timer State
    @State private var remainingTime: Int = 0
    @State private var currentRep: Int = 0
    @State private var timerIsActive: Bool = false
    @State private var isOnBreak: Bool = false
    @State private var isInGap: Bool = false
    @State private var timerComplete: Bool = false // True if stopped OR completed naturally
    @State private var statusMessage: String = "Setup Timer"
    @State private var activeElapsedTime: Int = 0 // Renamed for clarity - tracks active time
    @State private var sessionStartDate: Date? = nil // NEW: Track wall-clock start time

    // MARK: - Timer Publisher & Subscription
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timerSubscription: Cancellable?

    // MARK: - Speech Synthesizer
    private let speechSynthesizer = AVSpeechSynthesizer()

    // MARK: - Computed Properties for Input Values
    private var timerDuration: Int { Int(timerDurationValue) }
    private var totalReps: Int { Int(totalRepsValue) }
    private var breakDuration: Int { Int(breakDurationValue) }
    private var repsPerBreak: Int { Int(repsPerBreakValue) }
    private var gapDuration: Int { Int(gapDurationValue) }

    // MARK: - Computed Property for Estimated Total Duration
    private var estimatedTotalDuration: Int {
        var estimated: Int = 0; let work = timerDuration; let reps = totalReps; let gap = gapDuration; let longBreak = breakDuration; let repsBeforeBreak = repsPerBreak
        guard work > 0 && reps > 0 else { return 0 }
        for i in 1...reps {
            estimated += work
            if i < reps { let isBreakTime = longBreak > 0 && repsBeforeBreak > 0 && (i % repsBeforeBreak == 0); if isBreakTime { estimated += longBreak } else if gap > 0 { estimated += gap } }
        }
        return estimated
    }

    // MARK: - Formatter for TextFields
    private static var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter(); formatter.numberStyle = .decimal; formatter.maximumFractionDigits = 0; formatter.zeroSymbol = ""; return formatter
    }()

    // MARK: - Body
    var body: some View {
        // Outermost VStack to attach tap gesture for keyboard dismissal
        VStack {
            VStack(spacing: 15) {
                // --- Timer Status Display ---
                Text(statusMessage)
                    .font(.headline)
                    .padding(.bottom, 10)

                Text("Rep: \(currentRep) / \(totalReps)")
                    .font(.title2)
                Text("Time: \(formattedTime(remainingTime))")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                Text("Estimated Total: \(formattedTime(estimatedTotalDuration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)

                // --- Input Controls (Sliders + TextFields) ---
                VStack(alignment: .leading, spacing: 15) {
                    inputControlRow(label: "Work Duration", value: $timerDurationValue, range: durationRange, unit: "sec")
                    inputControlRow(label: "Total Repetitions", value: $totalRepsValue, range: repsRange, unit: "")
                    inputControlRow(label: "Gap Duration", value: $gapDurationValue, range: gapRange, unit: "sec")
                    inputControlRow(label: "Break Duration", value: $breakDurationValue, range: breakRange, unit: "sec")
                        .disabled(Int(repsPerBreakValue) == 0) // Should not happen if min is 1
                    inputControlRow(label: "Reps Before Break", value: $repsPerBreakValue, range: repsPerBreakRange, unit: "")
                         .disabled(Int(breakDurationValue) == 0)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                .disabled(timerIsActive || timerComplete) // Disable inputs when timer running or finished/stopped
                .onChange(of: timerDurationValue) { _, newValue in UserDefaults.standard.set(newValue, forKey: SettingsKeys.timerDuration) }
                .onChange(of: totalRepsValue) { _, newValue in UserDefaults.standard.set(newValue, forKey: SettingsKeys.totalReps) }
                .onChange(of: breakDurationValue) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: SettingsKeys.breakDuration)
                    // NEW: If break duration becomes 0, set reps before break to minimum (1)
                    if newValue == 0 {
                        repsPerBreakValue = repsPerBreakRange.lowerBound // Set to 1
                    }
                }
                .onChange(of: repsPerBreakValue) { _, newValue in UserDefaults.standard.set(newValue, forKey: SettingsKeys.repsPerBreak) }
                .onChange(of: gapDurationValue) { _, newValue in UserDefaults.standard.set(newValue, forKey: SettingsKeys.gapDuration) }


                // --- Control Buttons ---
                HStack(spacing: 20) { // Adjusted spacing
                    Button { // Start / Pause Button
                        if timerIsActive { pauseTimer() }
                        else { startTimer() }
                    } label: {
                        Image(systemName: timerIsActive ? "pause.fill" : "play.fill")
                        Text(timerIsActive ? "Pause" : "Start")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(timerComplete) // Disable if stopped/completed
                    .tint(timerIsActive ? .orange : .green)

                    // NEW: Stop Button
                    Button {
                        stopTimer()
                    } label: {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!timerIsActive) // Only enable Stop when timer is active

                    Button { // Reset Button
                        resetTimer()
                    } label: {
                         Image(systemName: "arrow.clockwise")
                        Text("Reset")
                    }
                    .buttonStyle(.bordered)
                    //.tint(.gray) // Optional different tint for reset
                }
                .imageScale(.medium) // Adjust icon size in buttons


                // --- Display Total Session Time (including pause) on Completion/Stop ---
                if timerComplete {
                    // Calculate wall-clock duration when needed
                    let wallClockDuration = Date().timeIntervalSince(sessionStartDate ?? Date())
                    Text("Total Session Time (including pause): \(formattedTime(Int(wallClockDuration)))")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                }

            }
            .padding()
        }
        // NEW: Tap gesture to dismiss keyboard
        .onTapGesture {
            hideKeyboard()
        }
        .onReceive(timer) { _ in
            if timerSubscription != nil && timerIsActive {
                updateTimer()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            pauseTimer()
        }
    }

    // MARK: - Reusable Input Control Row View Builder
    @ViewBuilder
    private func inputControlRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(label): \(Int(value.wrappedValue)) \(unit)")
            HStack {
                Slider(value: value, in: range, step: 1) { Text(label) }
                TextField(label, value: value, formatter: Self.numberFormatter)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: value.wrappedValue) { oldValue, newValue in // Keep this for clamping
                         let clampedValue = min(max(newValue, range.lowerBound), range.upperBound)
                         if clampedValue != newValue {
                             DispatchQueue.main.async {
                                 value.wrappedValue = clampedValue
                             }
                         }
                    }
            }
        }
    }


    // MARK: - Timer Control Functions
    func startTimer() {
        guard !timerIsActive else { return }
        hideKeyboard() // Dismiss keyboard on start
        if currentRep == 0 {
            guard totalReps > 0 && timerDuration > 0 else {
                statusMessage = "Invalid settings (Reps/Duration > 0)"
                return
            }
            activeElapsedTime = 0 // Reset active time counter
            sessionStartDate = Date() // Record wall-clock start time
            remainingTime = timerDuration
            currentRep = 1
            isOnBreak = false
            isInGap = false
            timerComplete = false
            statusMessage = "Work Interval \(currentRep)"
            speak("Start")
        } else {
             // Resuming from pause
             updateStatusMessage()
             // Do NOT reset sessionStartDate here
        }
        timerSubscription = timer.sink { _ in }
        timerIsActive = true
        UIApplication.shared.isIdleTimerDisabled = true
        print("Screen lock disabled")
    }

    func pauseTimer() {
        timerSubscription?.cancel()
        timerSubscription = nil
        timerIsActive = false
        if !timerComplete {
            statusMessage = "Paused"
        }
        speechSynthesizer.stopSpeaking(at: .immediate)
        UIApplication.shared.isIdleTimerDisabled = false
        print("Screen lock enabled (paused)")
        // Note: sessionStartDate is NOT reset on pause
    }

    // NEW: Stop Timer Function
    func stopTimer() {
        guard timerIsActive else { return } // Only stop if active
        hideKeyboard() // Dismiss keyboard on stop
        timerSubscription?.cancel()
        timerSubscription = nil
        timerIsActive = false
        timerComplete = true // Mark as complete to show final time
        statusMessage = "Stopped"
        speechSynthesizer.stopSpeaking(at: .immediate)
        UIApplication.shared.isIdleTimerDisabled = false
        print("Screen lock enabled (stopped)")
        // Keep activeElapsedTime and sessionStartDate for final calculation display
        // SwiftData Saving Removed
    }


    func resetTimer() {
        hideKeyboard() // Dismiss keyboard on reset
        // SwiftData Saving Removed
        pauseTimer() // Stops timer, speech, enables screen lock
        currentRep = 0
        remainingTime = 0
        isOnBreak = false
        isInGap = false
        timerComplete = false // Reset completion flag
        activeElapsedTime = 0 // Reset active time counter
        sessionStartDate = nil // Reset wall-clock start time
        statusMessage = "Setup Timer"
    }

    // MARK: - Core Timer Update Logic
    func updateTimer() {
        guard timerIsActive else { return }
        if remainingTime > 0 {
            remainingTime -= 1
            activeElapsedTime += 1 // Increment active time
            let shouldSpeakCountdown = remainingTime <= 5 && remainingTime > 0
            if shouldSpeakCountdown && !isInGap {
                 speak("\(remainingTime)")
            }
        }
        if remainingTime <= 0 {
            handleIntervalCompletion()
        }
    }

    // MARK: - Interval Completion Logic
    func handleIntervalCompletion() {
        if isInGap {
            isInGap = false; currentRep += 1; remainingTime = timerDuration; isOnBreak = false; updateStatusMessage(); speak("Start"); return
        }
        if !isOnBreak { // Work interval finished
             playSound()
            if currentRep >= totalReps { // Sequence complete
                statusMessage = "Timer Complete!"; timerComplete = true; pauseTimer(); speak("Timer Complete!")
                // SwiftData Saving Removed
                return
            }
            // Decide next step: Break, Gap, or Next Rep
            let shouldTakeBreak = breakDuration > 0 && repsPerBreak > 0 && (currentRep % repsPerBreak == 0)
            if shouldTakeBreak {
                isOnBreak = true; remainingTime = breakDuration; updateStatusMessage(); speak("Break time")
            } else { // No long break, check for gap
                if gapDuration > 0 {
                    isInGap = true; remainingTime = gapDuration; updateStatusMessage()
                    speak("Change") // <--- ADDED: Announce change into gap
                } else { // No gap, start next rep immediately
                    currentRep += 1; remainingTime = timerDuration; isOnBreak = false; updateStatusMessage()
                    if currentRep > 1 { speak("Start") }
                }
            }
            return
        }
        else { // Break finished
            currentRep += 1; remainingTime = timerDuration; isOnBreak = false; updateStatusMessage()
            if currentRep > totalReps { // Sequence complete (unlikely here, but safety check)
                 statusMessage = "Timer Complete!"; timerComplete = true; pauseTimer(); speak("Timer Complete!")
                 // SwiftData Saving Removed
            } else {
                speak("Start") // Announce start after break
            }
            return
        }
    }

    // SwiftData Save Function Removed

    // MARK: - Helper Functions
    func updateStatusMessage() {
        if isInGap { statusMessage = "Gap Time" }
        else if isOnBreak { statusMessage = "Break Time" }
        else if timerIsActive { statusMessage = "Work Interval \(currentRep)" }
        else if !timerComplete && !timerIsActive && currentRep > 0 { statusMessage = "Paused" }
        else if !timerComplete && !timerIsActive && currentRep == 0 { statusMessage = "Setup Timer" }
        // Note: "Stopped" and "Timer Complete!" are set directly
    }
    func formattedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60; let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    func playSound() { AudioServicesPlaySystemSound(SystemSoundID(1306)); print("Sound Played") }

    // --- MODIFIED speak Function ---
    func speak(_ phrase: String) {
        // FIX: Removed problematic KVC check. Always stop previous speech immediately.
        speechSynthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: phrase)
        // utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // Optional: Set voice
        // utterance.rate = 0.5 // Optional: Adjust rate (0.0 to 1.0)
        // utterance.pitchMultiplier = 1.0 // Optional: Adjust pitch (0.5 to 2.0)
        speechSynthesizer.speak(utterance)
        print("Speaking: \(phrase)")
    }
    // --- End Modified Section ---

    // NEW: Function to dismiss keyboard
    func hideKeyboard() {
         UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
     }
}

// MARK: - Preview
#Preview {
     // Removed model container setup
     TimerLogicView()
}
