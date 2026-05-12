// AudioHandler.swift
// Sends audio to server at 20/sec for feature extraction.
// Client-side exponential smoothing on F1/F2 for fluid dot movement.

import SwiftUI
import Combine
import Foundation
import AVFoundation

class AudioHandler: ObservableObject {
    private let audioEngine = AVAudioEngine()

    @Published var currentF1:       Double = 500
    @Published var currentF2:       Double = 1500
    @Published var currentVolume:   Double = 0
    @Published var currentCentroid: Double = 0
    @Published var currentFlatness: Double = 0
    @Published var isRecording:     Bool   = false

    // Smoothing — applied client-side so dot moves fluidly
    private var smoothF1: Double = 500
    private var smoothF2: Double = 1500
    private let smoothAlpha: Double = 0.4  // 0 = very smooth, 1 = raw

    // 20 requests/sec (50ms interval)
    private var lastSentTime: Date = .distantPast
    private let sendInterval: TimeInterval = 0.05

    func startTracking() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
        } catch {
            print("Session setup failed: \(error)")
            return
        }

        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                guard granted, let self = self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startEngine()
                }
            }
        } else {
            session.requestRecordPermission { [weak self] granted in
                guard granted, let self = self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startEngine()
                }
            }
        }
    }

    private func startEngine() {
        let inputNode = audioEngine.inputNode
        let bus       = 0
        let format    = inputNode.inputFormat(forBus: bus)

        guard format.sampleRate > 0 else {
            print("0Hz — check mic permissions")
            return
        }

        inputNode.removeTap(onBus: bus)

        inputNode.installTap(onBus: bus, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self,
                  let channelData = buffer.floatChannelData?[0] else { return }

            let now = Date()
            guard now.timeIntervalSince(self.lastSentTime) >= self.sendInterval else { return }
            self.lastSentTime = now

            let frameLength = Int(buffer.frameLength)
            let data = Data(bytes: channelData, count: frameLength * MemoryLayout<Float>.size)

            NetworkManager.shared.analyzeAudio(data) { [weak self] response in
                guard let self = self, let r = response else { return }
                self.applySmoothing(f1: r.f1, f2: r.f2,
                                    volume: r.volume,
                                    centroid: r.centroid,
                                    flatness: r.flatness)
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            DispatchQueue.main.async { self.isRecording = true }
            print("Audio streaming started at 20/sec")
        } catch {
            print("Engine start failed: \(error)")
        }
    }

    private func applySmoothing(f1: Double, f2: Double,
                                volume: Double, centroid: Double, flatness: Double) {
        // Only smooth F1/F2 — volume/centroid/flatness stay raw for responsive detection
        if f1 > 0 { smoothF1 = smoothF1 * (1 - smoothAlpha) + f1 * smoothAlpha }
        if f2 > 0 { smoothF2 = smoothF2 * (1 - smoothAlpha) + f2 * smoothAlpha }

        DispatchQueue.main.async {
            self.currentF1       = self.smoothF1
            self.currentF2       = self.smoothF2
            self.currentVolume   = volume
            self.currentCentroid = centroid
            self.currentFlatness = flatness
        }
    }

    func updateUI(f1: Double, f2: Double,
                  volume: Double = 0, centroid: Double = 0, flatness: Double = 0) {
        DispatchQueue.main.async {
            self.currentF1       = f1
            self.currentF2       = f2
            self.currentVolume   = volume
            self.currentCentroid = centroid
            self.currentFlatness = flatness
        }
    }

    func stopTracking() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        DispatchQueue.main.async { self.isRecording = false }
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
