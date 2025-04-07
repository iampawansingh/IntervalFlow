//
//  TimerView.swift
//  IntervalFlow
//
//  Created by Pawan kumar Singh on 31/03/25.
//

import SwiftUI
import Combine // Needed for Timer.publish and Cancellable
import AVFoundation // Needed for sound playback AND speech synthesis
import UIKit

struct TimerLogicView: View {
    
    //    @Environment(\.modelContext) private var modelContext
    
    //MARK: - User Default Keys
    // Define keys for saving / loading settings
    private enum SettingsKeys {
        static let timerDuration: String = "timerDurationValue"
        static let totalReps: String = "totalRepsValue"
        static let breakDuration: String = "breakDurationValue"
        static let repsPerBreak: String = "repsPerBreakValue"
        static let gapDuration: String = "gapDurationValue"
    }
    // MARK: - Input State Variables (Loading from UserDefaults)
    // Initialize state variables by loading from UserDefaults, providing defaults if no value is saved
    @State private var timerDurationValue: Double = UserDefaults.standard.double(forKey: SettingsKeys.timerDuration).isZero ? 30.0 : UserDefaults.standard.double(forKey: SettingsKeys.timerDuration)
    @State private var totalRepsValue: Double = UserDefaults.standard.double(forKey: SettingsKeys.totalReps).isZero ? 6.0 : UserDefaults.standard.double(forKey: SettingsKeys.totalReps)
    @State private var breakDurationValue: Double = UserDefaults.standard.double(forKey: SettingsKeys.breakDuration).isZero ? 8.0 : UserDefaults.standard.double(forKey: SettingsKeys.breakDuration)
    @State private var repsPerBreakValue: Double = UserDefaults.standard.double(forKey: SettingsKeys.repsPerBreak).isZero ? 3.0 : UserDefaults.standard.double(forKey: SettingsKeys.repsPerBreak)
    @State private var gapDurationValue: Double = UserDefaults.standard.double(forKey: SettingsKeys.gapDuration).isZero ? 5.0 : UserDefaults.standard.double(forKey: SettingsKeys.gapDuration)
    
    
    
    // Define slider ranges
    private let durationRange: ClosedRange<Double> = 1...300
    private let repsRange: ClosedRange<Double> = 1...100
    private let breakRange: ClosedRange<Double> = 0...300 // Min 0 for no break
    private let repsPerBreakRange: ClosedRange<Double> = 1...100 // Min 1 rep before break
    private let gapRange: ClosedRange<Double> = 0...60      // NEW: Range for gap (0-60s)
    
    // MARK: - Internal Timer State
    @State private var remainingTime: Int = 0
    @State private var currentRep: Int = 0
    @State private var timerIsActive: Bool = false
    @State private var isOnBreak: Bool = false
    @State private var isInGap: Bool = false // NEW: State for tracking if in the short gap
    @State private var timerComplete: Bool = false
    @State private var statusMessage: String = "Setup Timer"
    @State private var activeElapsedTime: Int = 0
    @State private var sessionStartDate: Date? = nil
    
    // MARK: - Timer Publisher & Subscription
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timerSubscription: Cancellable?
    
    // MARK: - Speech Synthesizer
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // MARK: - Computed Properties for Input Values (Casting Double to Int)
    private var timerDuration: Int { Int(timerDurationValue) }
    private var totalReps: Int { Int(totalRepsValue) }
    private var breakDuration: Int { Int(breakDurationValue) }
    private var repsPerBreak: Int { Int(repsPerBreakValue) }
    private var gapDuration: Int { Int(gapDurationValue) } // NEW: Computed property for gap
    
    //MARK: - NEW: Computed Property for Estimated Total Duration
    
    private var estimatedTotalDuration: Int {
        var estimated: Int = 0
        let work  = timerDuration
        let reps = totalReps
        let gap = gapDuration
        let longBreak = breakDuration
        let repsBeforeBreak = repsPerBreak
        
        for i in 1...reps {
            estimated += work
            if i < reps { // Add gap or break *after* the rep, unless it's the last one
                let isBreakTime = longBreak > 0 && repsBeforeBreak > 0 && (i % repsBeforeBreak == 0)
                if isBreakTime {
                    estimated += longBreak // Add long break duration
                } else if gap > 0 {
                    estimated += gap // Add gap duration
                }
            }
            
        }
        return estimated
    }
    
    // MARK: - Formatter for TextFields
    private static var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.zeroSymbol = ""
        return formatter
    }()
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 15) {
            // --- Timer Status Display ---
            Text(statusMessage)
                .font(.headline)
                .padding(.bottom, 10)
            
            Text("Rep: \(currentRep) / \(totalReps)")
                .font(.title2)
            Text("Time: \(formattedTime(remainingTime))")
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .padding(.bottom, 20)
            Text("Estimated Session Time: \(formattedTime(estimatedTotalDuration))")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 10)
            
            // --- Input Controls (Sliders + TextFields) ---
            VStack(alignment: .leading, spacing: 15) {
                inputControlRow(label: "Work Duration", value: $timerDurationValue, range: durationRange, unit: "sec")
                inputControlRow(label: "Total Repetitions", value: $totalRepsValue, range: repsRange, unit: "")
                // NEW: Input row for Gap Duration
                inputControlRow(label: "Gap Duration", value: $gapDurationValue, range: gapRange, unit: "sec")
                inputControlRow(label: "Break Duration", value: $breakDurationValue, range: breakRange, unit: "sec")
                    .disabled(Int(repsPerBreakValue) == 0)
                inputControlRow(label: "Reps Before Break", value: $repsPerBreakValue, range: repsPerBreakRange, unit: "")
                    .disabled(Int(breakDurationValue) == 0)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            .disabled(timerIsActive || timerComplete)
            // --- ADDED onChange modifiers to SAVE settings
            .onChange(of: timerDurationValue,{_, newValue in UserDefaults.standard.set(newValue, forKey: SettingsKeys.timerDuration)})
            .onChange(of: totalRepsValue,{_, newValue in UserDefaults.standard.set(newValue, forKey: SettingsKeys.totalReps)})
            .onChange(of: gapDurationValue,{_, newValue in UserDefaults.standard.set(newValue, forKey: SettingsKeys.gapDuration)})
            .onChange(of: breakDurationValue,{_, newValue in UserDefaults.standard.set(newValue, forKey: SettingsKeys.breakDuration)
                if newValue==0{
                    repsPerBreakValue = repsPerBreakRange.upperBound
                }
            })
            .onChange(of: repsPerBreakValue,{_, newValue in UserDefaults.standard.set(newValue, forKey: SettingsKeys.repsPerBreak)})
            // --- Control Buttons ---
            HStack(spacing: 30) {
                Button {
                    if timerIsActive {
                        pauseTimer()
                    } else {
                        startTimer()
                    }
                } label: {
                    Image(systemName: timerIsActive ? "pause.fill" : "play.fill")
                        .imageScale(.large)
                    Text(timerIsActive ? "Pause" : "Start")
                }
                .buttonStyle(.borderedProminent)
                .disabled(timerComplete)
                .tint(timerIsActive ? .orange : .green)
                
                Button{stopTimer()
                } label: {
                    Image(systemName: "stop.fill")
                    Text("Stop")
                }
                
                Button {
                    resetTimer()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .imageScale(.large)
                    Text("Reset")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            if timerComplete{
                let wallClockDuration = Date().timeIntervalSince(sessionStartDate ?? Date())
                Text("Total Session Time: \(formattedTime(Int(wallClockDuration)))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
            }
        }
        .padding()
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
                // Updated onChange signature to address deprecation warning
                    .onChange(of: value.wrappedValue) { oldValue, newValue in
                        let clampedValue = min(max(newValue, range.lowerBound), range.upperBound)
                        if clampedValue != newValue {
                            // Use DispatchQueue to avoid modifying state during view update cycle
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
        if currentRep == 0 {
            guard totalReps > 0 && timerDuration > 0 else {
                statusMessage = "Invalid settings (Reps/Duration > 0)"
                return
            }
            activeElapsedTime = 0
            sessionStartDate = Date()
            remainingTime = timerDuration
            currentRep = 1
            isOnBreak = false
            isInGap = false // Ensure not in gap initially
            timerComplete = false
            statusMessage = "Work Interval \(currentRep)"
            speak("Start") // Announce start on initial press
        } else {
            // Resuming from pause
            updateStatusMessage() // Update status based on current state (work/break/gap)
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
        // Stop speech if timer is paused
        speechSynthesizer.stopSpeaking(at: .immediate)
        UIApplication.shared.isIdleTimerDisabled = false
        print("Screen lock enabled")
    }
    
    func stopTimer() {
        guard timerIsActive else { return }
        hideKeyboard()
        timerSubscription?.cancel()
        timerSubscription = nil
        timerIsActive = false
        timerComplete = true
        statusMessage = "Stopped"
        speechSynthesizer.stopSpeaking(at: .immediate)
        UIApplication.shared.isIdleTimerDisabled = false
        print("Screen lock enabled (stopped)")
    }
    
    func resetTimer() {
        hideKeyboard()
        pauseTimer() // Also stops speech
        currentRep = 0
        remainingTime = 0
        activeElapsedTime = 0
        sessionStartDate = nil
        isOnBreak = false
        isInGap = false // Reset gap state
        timerComplete = false
        statusMessage = "Setup Timer"
        // Reset test values including gap
        //         timerDurationValue = 10.0
        //         totalRepsValue = 6.0
        //         breakDurationValue = 8.0
        //         repsPerBreakValue = 3.0
        //         gapDurationValue = 5.0 // Reset gap duration
        //         totalElapsedTime = 0
    }
    
    // MARK: - Core Timer Update Logic
    
    func updateTimer() {
        guard timerIsActive else { return }
        
        if remainingTime > 0 {
            remainingTime -= 1
            activeElapsedTime+=1
            
            // --- Speak countdown during last 5 seconds of break OR work interval (NOT gap) ---
            let shouldSpeakCountdown = remainingTime <= 5 && remainingTime > 0
            
            if shouldSpeakCountdown && !isInGap { // Exclude gap from countdown
                speak("\(remainingTime)") // Speak "5", "4", "3", "2", "1"
            }
            // --- End of countdown section ---
            
        }
        
        // Check for interval completion *after* decrementing and potential speech
        if remainingTime <= 0 {
            handleIntervalCompletion()
        }
    }
    
    // MARK: - Interval Completion Logic (Restructured for Gap)
    
    func handleIntervalCompletion() {
        // --- Priority 1: Check if a GAP interval just finished ---
        if isInGap {
            isInGap = false // Exit gap state
            currentRep += 1 // Increment rep *after* the gap
            remainingTime = timerDuration // Start next work interval
            isOnBreak = false // Ensure not on break
            updateStatusMessage()
            speak("Start") // Announce start of the next work interval
            return // Handled gap completion, exit function
        }
        
        // --- Priority 2: Check if a WORK interval just finished ---
        if !isOnBreak { // Note: We already know !isInGap from check above
            playSound() // Play sound cue for work rep completion
            
            // Check if all repetitions are completed
            if currentRep >= totalReps {
                statusMessage = "Session Complete!"
                timerComplete = true
                pauseTimer()
                speak("Session Complete!")
                // saveSession(...)
                
                return // Sequence finished
            }
            
            // Determine if it's time for a long break
            let shouldTakeBreak = breakDuration > 0 && repsPerBreak > 0 && (currentRep % repsPerBreak == 0)
            
            if shouldTakeBreak {
                // Start Long Break
                isOnBreak = true
                remainingTime = breakDuration
                updateStatusMessage()
                speak("Break time")
            } else {
                // Check if we need a short gap before the next rep
                if gapDuration > 0 {
                    // Start Short Gap
                    isInGap = true
                    remainingTime = gapDuration
                    updateStatusMessage()
                    speak("Change")
                    // No "Start" announcement here, wait until after the gap
                } else {
                    // No gap, start next work interval immediately
                    currentRep += 1
                    remainingTime = timerDuration
                    isOnBreak = false // Ensure not on break
                    updateStatusMessage()
                    // Announce "Start" only if it's not the very first rep (handled in startTimer)
                    if currentRep > 1 {
                        speak("Start")
                    }
                }
            }
            return // Handled work completion, exit function
        }
        
        // --- Priority 3: Check if a BREAK interval just finished ---
        // This runs only if !isInGap and isOnBreak was true
        else {
            // Break finished, start next work interval
            currentRep += 1
            remainingTime = timerDuration
            isOnBreak = false // Exit break state
            updateStatusMessage()
            
            // Check for completion immediately after break finishes
            if currentRep > totalReps {
                statusMessage = "Timer Complete!"
                timerComplete = true
                pauseTimer()
                speak("Timer Complete!")
                // saveSession(...)
            } else {
                // Announce "Start" when moving from break to work
                speak("Start")
            }
            return // Handled break completion, exit function
        }
    }
    
    // MARK: - Helper Functions
    
    // Updates the status message based on the current state
    func updateStatusMessage() {
        if isInGap {
            statusMessage = "Gap Time"
        } else if isOnBreak {
            statusMessage = "Break Time"
        } else if timerIsActive { // Only show work interval if timer is running
            statusMessage = "Work Interval \(currentRep)"
        }
        // Keep "Paused" or "Timer Complete!" if applicable (handled elsewhere)
    }
    
    
    func formattedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    func playSound() {
        AudioServicesPlaySystemSound(SystemSoundID(1306))
        print("Sound Played")
    }
    
    func speak(_ phrase: String) {
        if phrase == "Break time" || phrase == "Start" || phrase == "Timer Complete!" {
            speechSynthesizer.stopSpeaking(at: .immediate)
        } else if speechSynthesizer.isSpeaking {
            if let currentUtterance = speechSynthesizer.value(forKey: "utterance") as? AVSpeechUtterance,
               let currentNumber = Int(currentUtterance.speechString),
               let nextNumber = Int(phrase), nextNumber == currentNumber - 1 {
                // Allow countdown
            } else {
                speechSynthesizer.stopSpeaking(at: .immediate)
            }
        }
        let utterance = AVSpeechUtterance(string: phrase)
        speechSynthesizer.speak(utterance)
        print("Speaking: \(phrase)")
    }
    
    // Placeholder for saving data
    // func saveSession(reps: Int, duration: Int, /*... other params ...*/) {
    //     print("Saving session: Reps=\(reps), Duration=\(duration)")
    //     // Add SwiftData saving code here
    // }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Preview
#Preview {
    TimerLogicView()
}
