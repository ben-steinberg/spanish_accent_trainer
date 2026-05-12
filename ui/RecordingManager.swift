// RecordingManager.swift

import SwiftUI
import AVFoundation
import Combine

class RecordingManager: NSObject, ObservableObject {
    private var audioRecorder:  AVAudioRecorder?
    private var recordingURL:   URL?
    private var currentFileName = "recording"

    @Published var isRecording:   Bool   = false
    @Published var statusMessage: String = ""

    func startRecording(fileName: String? = nil) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        currentFileName = fileName ?? "recording_\(formatter.string(from: Date()))"

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            print("Session error: \(error)")
            return
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url  = docs.appendingPathComponent("\(currentFileName).wav")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey:             Int(kAudioFormatLinearPCM),
            AVSampleRateKey:           44100,
            AVNumberOfChannelsKey:     1,
            AVLinearPCMBitDepthKey:    16,
            AVLinearPCMIsFloatKey:     false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            DispatchQueue.main.async {
                self.isRecording   = true
                self.statusMessage = "Recording…"
            }
        } catch {
            print("Recorder error: \(error)")
        }
    }

    // Stop and only transcribe — waits for user confirmation before MFA
    func stopAndTranscribe(completion: @escaping (String?) -> Void) {
        print("stopAndTranscribe called")
        audioRecorder?.stop()
        DispatchQueue.main.async {
            self.isRecording   = false
            self.statusMessage = "Transcribing…"
        }

        guard let url = recordingURL,
              let wavData = try? Data(contentsOf: url) else {
            DispatchQueue.main.async { self.statusMessage = "Error reading recording." }
            completion(nil)
            return
        }

        fetchTranscription(wavData: wavData, fileName: currentFileName) { text in
            DispatchQueue.main.async { self.statusMessage = "" }
            completion(text)
        }
    }

    // Upload for full MFA analysis after user confirms/corrects transcription
    func uploadForAnalysis(correctedText: String?,
                           completion: @escaping (MissesResponse?) -> Void) {
        guard let url = recordingURL,
              let wavData = try? Data(contentsOf: url) else {
            completion(nil); return
        }

        if let text = correctedText {
            updateTranscriptionText(text, fileName: currentFileName)
        }

        NetworkManager.shared.uploadRecording(wavData: wavData,
                                              fileName: currentFileName) { response in
            completion(response)
        }
    }

    // Called by ContentView with no arguments
    func stopAndUpload() {
        stopAndUpload { _, _ in }
    }

    func stopAndUpload(completion: @escaping (MissesResponse?, String?) -> Void) {
        audioRecorder?.stop()
        DispatchQueue.main.async {
            self.isRecording   = false
            self.statusMessage = "Uploading and analyzing…"
        }

        guard let url = recordingURL,
              let wavData = try? Data(contentsOf: url) else {
            DispatchQueue.main.async { self.statusMessage = "Error reading recording." }
            completion(nil, nil)
            return
        }

        fetchTranscription(wavData: wavData, fileName: currentFileName) { transcribedText in
            NetworkManager.shared.uploadRecording(wavData: wavData,
                                                  fileName: self.currentFileName) { response in
                DispatchQueue.main.async {
                    self.statusMessage = response != nil ? "Analysis complete!" : "Upload failed — check server."
                }
                completion(response, transcribedText)
            }
        }
    }
    func cancelRecording() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        guard let url = URL(string: "\(ServerConfig.baseURL)/delete_recording") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = try? JSONSerialization.data(withJSONObject: ["filename": currentFileName])
        request.httpBody = body
        URLSession.shared.dataTask(with: request).resume()
        recordingURL = nil
    }

    private func updateTranscriptionText(_ text: String, fileName: String) {
        guard let url = URL(string: "\(ServerConfig.baseURL)/update_transcription") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = try? JSONSerialization.data(withJSONObject: ["filename": fileName, "text": text])
        request.httpBody = body
        URLSession.shared.dataTask(with: request).resume()
    }

    private func fetchTranscription(wavData: Data, fileName: String,
                                    completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(ServerConfig.baseURL)/transcribe") else {
            completion(nil); return
        }

        let boundary = UUID().uuidString
        var request        = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"filename\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(fileName)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(fileName).wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wavData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["transcription"] as? String
            else { completion(nil); return }
            completion(text)
        }.resume()
    }

}

extension RecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            DispatchQueue.main.async { self.statusMessage = "Recording failed." }
        }
    }
}
