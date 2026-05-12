// NetworkManager.swift
// Drop this file into your Xcode project.
// It replaces PythonBridge — every call to your Python backend goes through here.

import Foundation
import Combine

// ─────────────────────────────────────────────────────────────
//  CONFIG  — set this to your Mac's local IP while developing
//  Find it: System Settings > Wi-Fi > Details > IP Address
// ─────────────────────────────────────────────────────────────
enum ServerConfig {
    static let baseURL = "http://localhost:5001"
}

// ─────────────────────────────────────────────────────────────
//  RESPONSE MODELS
// ─────────────────────────────────────────────────────────────

struct AudioAnalysisResponse: Codable {
    let f1: Double
    let f2: Double
    let centroid: Double
    let flatness: Double
    let volume: Double
}

struct PhonemeError: Codable, Identifiable {
    var id: String { "\(shouldBe)-\(actual)" }
    let shouldBe: String
    let actual: String
    let count: Int

    enum CodingKeys: String, CodingKey {
        case shouldBe = "should_be"
        case actual, count
    }
}

struct MissesResponse: Codable {
    let closeMisses: [PhonemeError]
    let farMisses:   [PhonemeError]

    enum CodingKeys: String, CodingKey {
        case closeMisses = "close_misses"
        case farMisses   = "far_misses"
    }
}

struct SuggestedWord: Codable, Identifiable {
    var id: String { word }
    let word:     String
    let phonemes: String
}

struct SuggestedWordsResponse: Codable {
    let phonemes:       [String]
    let suggestedWords: [SuggestedWord]

    enum CodingKeys: String, CodingKey {
        case phonemes
        case suggestedWords = "suggested_words"
    }
}

struct PhonemeTrend: Codable, Identifiable {
    var id: String { phonemes }
    let phonemes:       String
    let trend:          String
    let recent:         Double
    let older:          Double
    let recentAccuracy: Int
    let olderAccuracy:  Int

    enum CodingKeys: String, CodingKey {
        case phonemes, trend, recent, older
        case recentAccuracy = "recent_accuracy"
        case olderAccuracy  = "older_accuracy"
    }
}

struct ProgressResponse: Codable {
    let trends: [PhonemeTrend]
}

struct DayCount: Codable, Identifiable {
    var id: String { date }
    let date:  String
    let count: Int
}

struct PhonemeHistoryResponse: Codable {
    let history: [DayCount]
}




// ─────────────────────────────────────────────────────────────
//  NETWORK MANAGER
// ─────────────────────────────────────────────────────────────

class NetworkManager: ObservableObject {

    static let shared = NetworkManager()
    private init() {}

    // ── 1. Real-time audio analysis ───────────────────────────
    /// Call this from AudioHandler's tap closure with each PCM buffer.
    func analyzeAudio(_ data: Data, completion: @escaping (AudioAnalysisResponse?) -> Void) {
        guard let url = URL(string: "\(ServerConfig.baseURL)/analyze_audio") else {
            completion(nil); return
        }

        var request        = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody   = data
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        // Short timeout — this fires ~20x/sec, we don't want stale callbacks piling up
        request.timeoutInterval = 1.0

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let result = try? JSONDecoder().decode(AudioAnalysisResponse.self, from: data)
            else { completion(nil); return }
            completion(result)
        }.resume()
    }

    // ── 2. Upload a recording for full MFA pipeline ───────────
    /// Sends a .wav file to the server, gets back miss analysis when done.
    func uploadRecording(wavData: Data, fileName: String,
                         completion: @escaping (MissesResponse?) -> Void) {
        guard let url = URL(string: "\(ServerConfig.baseURL)/upload_recording") else {
            completion(nil); return
        }

        let boundary = UUID().uuidString
        var request        = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")
        // MFA alignment can take a while — give it 60 seconds
        request.timeoutInterval = 120.0

        var body = Data()

        // filename field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"filename\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(fileName)\r\n".data(using: .utf8)!)

        // audio field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(fileName).wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wavData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let result = try? JSONDecoder().decode(MissesResponse.self, from: data)
            else { completion(nil); return }
            completion(result)
        }.resume()
    }

    // ── 3. Fetch cached miss analysis ─────────────────────────
    func fetchMisses(completion: @escaping (MissesResponse?) -> Void) {
        fetch("/misses", decode: MissesResponse.self, completion: completion)
    }
    
    func fetchProgress(completion: @escaping (ProgressResponse?) -> Void) {
        fetch("/progress", decode: ProgressResponse.self, completion: completion)
    }

    // ── 4. Fetch suggested practice words ────────────────────
    func fetchSuggestedWords(n: Int = 1,
                             completion: @escaping (SuggestedWordsResponse?) -> Void) {
        fetch("/suggested_words?n=\(n)", decode: SuggestedWordsResponse.self, completion: completion)
    }
    
    func fetchPhonemeWords(shouldBe: String, actual: String,
                           completion: @escaping ([String], [String]) -> Void) {
        let encoded = "\(ServerConfig.baseURL)/phoneme_words?should_be=\(shouldBe)&actual=\(actual)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: encoded) else { completion([], []); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { completion([], []); return }
            let sb = json["should_be_words"] as? [String] ?? []
            let ac = json["actual_words"]    as? [String] ?? []
            completion(sb, ac)
        }.resume()
    }
    
    func fetchPhonemeHistory(shouldBe: String, actual: String,
                             completion: @escaping (PhonemeHistoryResponse?) -> Void) {
        let path = "/phoneme_history?should_be=\(shouldBe)&actual=\(actual)"
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(ServerConfig.baseURL)\(encoded)")
        else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let result = try? JSONDecoder().decode(PhonemeHistoryResponse.self, from: data)
            else { completion(nil); return }
            completion(result)
        }.resume()
    }

    // ── 5. Health check ───────────────────────────────────────
    func ping(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(ServerConfig.baseURL)/ping") else {
            completion(false); return
        }
        URLSession.shared.dataTask(with: url) { _, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            completion(ok)
        }.resume()
    }

    // ── Private helper ────────────────────────────────────────
    private func fetch<T: Decodable>(_ path: String, decode type: T.Type,
                                     completion: @escaping (T?) -> Void) {
        guard let url = URL(string: "\(ServerConfig.baseURL)\(path)") else {
            completion(nil); return
        }
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let result = try? JSONDecoder().decode(type, from: data)
            else { completion(nil); return }
            completion(result)
        }.resume()
    }
}
