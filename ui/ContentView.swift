// ContentView.swift
// Tab 0 = Diagnostic (miss analysis)
// Tab 1 = Practice (live vowel map trainer)

import SwiftUI

struct ContentView: View {
    @State private var selectedMode = 0
    @StateObject private var audioHandler     = AudioHandler()
    @StateObject private var recordingManager = RecordingManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────
                Text("Spanish Accent Lab")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // ── Mode Switcher ─────────────────────────────
                Picker("Mode", selection: $selectedMode) {
                    Text("Diagnostic").tag(0)
                    Text("Practice").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // ── Main Content ──────────────────────────────
                if selectedMode == 0 {
                    // Diagnostic — miss analysis + suggested words
                    DiagnosticView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else {
                    // Practice — live vowel map trainer
                    PracticeView(
                        f1:          audioHandler.currentF1,
                        f2:          audioHandler.currentF2,
                        volume:      audioHandler.currentVolume,
                        centroid:    audioHandler.currentCentroid,
                        flatness:    audioHandler.currentFlatness,
                        isRecording: audioHandler.isRecording
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // ── Status text ───────────────────────────────
                Group {
                    if selectedMode == 1 {
                        Text(audioHandler.isRecording ? "Listening…" : "Tap mic to start")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text(recordingManager.statusMessage)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 4)

                // ── Buttons ───────────────────────────────────
                HStack(spacing: 24) {

                    // Blue mic — live vowel tracking (Practice mode)
                    if selectedMode == 1 {
                        Button(action: {
                            if audioHandler.isRecording {
                                audioHandler.stopTracking()
                            } else {
                                audioHandler.startTracking()
                            }
                        }) {
                            Circle()
                                .fill(audioHandler.isRecording ? Color.red : Color.blue)
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: audioHandler.isRecording ? "stop.fill" : "mic.fill")
                                        .foregroundColor(.white)
                                        .font(.title2)
                                )
                                .shadow(color: audioHandler.isRecording ? .red : .blue, radius: 10)
                        }
                    }

                    // Green waveform — record + upload for analysis (Diagnostic mode)
//                    if selectedMode == 0 {
//                        Button(action: {
//                            if recordingManager.isRecording {
//                                recordingManager.stopAndUpload()
//                            } else {
//                                recordingManager.startRecording()
//                            }
//                        }) {
//                            Circle()
//                                .fill(recordingManager.isRecording ? Color.orange : Color.green)
//                                .frame(width: 72, height: 72)
//                                .overlay(
//                                    Image(systemName: recordingManager.isRecording ? "stop.fill" : "waveform")
//                                        .foregroundColor(.white)
//                                        .font(.title2)
//                                )
//                                .shadow(color: recordingManager.isRecording ? .orange : .green, radius: 10)
//                        }
//                    }
                }
                .padding(.vertical, 16)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
