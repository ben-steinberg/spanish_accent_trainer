// DiagnosticView.swift

import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────────
//  PHONEME → ENGLISH SOUND DESCRIPTION
// ─────────────────────────────────────────────────────────────
let phonemeDescriptions: [String: String] = [
    "a":  "A (like father)",
    "e":  "E (like bet)",
    "i":  "EE (like see)",
    "o":  "O (like go)",
    "u":  "OO (like food)",
    "ɪ":  "short I (like bit)",
    "ʌ":  "UH (like cup)",
    "p":  "P (like pen)",
    "b":  "B (like bed)",
    "t":  "T (like top)",
    "d":  "D (like dog)",
    "k":  "K (like cat)",
    "c":  "K sound (tongue further forward, like keep)",
    "g":  "G (like go)",
    "f":  "F (like fan)",
    "s":  "S (like sun)",
    "x":  "H (like hot) — Spanish J",
    "θ":  "TH (like think)",
    "ʝ":  "Y (like yes) — Spanish LL/Y",
    "ʎ":  "LL (like million) — Spanish LL",
    "β":  "soft B/V (lips barely touching)",
    "ð":  "soft D (like this) — between vowels",
    "ɣ":  "soft G (gentle gargle)",
    "ç":  "SH/H (like hue)",
    "m":  "M (like man)",
    "n":  "N (like no)",
    "ɲ":  "NY (like canyon) — Spanish Ñ",
    "ŋ":  "NG (like sing)",
    "l":  "L (like let)",
    "r":  "trilled R (tongue flutters rapidly)",
    "ɾ":  "tap R (like butter said fast)",
    "tʃ": "CH (like chair)",
    "dʒ": "J (like jump)",
    "j":  "Y (like yet)",
    "w":  "W (like wet)",
    "h":  "H (like hot)",
]

func phonemeLabel(_ ipa: String) -> String {
    phonemeDescriptions[ipa] ?? "/\(ipa)/"
}

// ─────────────────────────────────────────────────────────────
//  PHONEME WORDS CACHE
// ─────────────────────────────────────────────────────────────
class PhonemeWordsCache: ObservableObject {
    @Published var cache: [String: ([String], [String])] = [:]

    func fetch(shouldBe: String, actual: String) {
        let key = "\(shouldBe)→\(actual)"
        guard cache[key] == nil else { return }
        NetworkManager.shared.fetchPhonemeWords(shouldBe: shouldBe, actual: actual) { sb, ac in
            DispatchQueue.main.async { self.cache[key] = (sb, ac) }
        }
    }

    func words(shouldBe: String, actual: String) -> ([String], [String])? {
        cache["\(shouldBe)→\(actual)"]
    }
}

// ─────────────────────────────────────────────────────────────
//  PHONEME HISTORY CACHE
// ─────────────────────────────────────────────────────────────
class PhonemeHistoryCache: ObservableObject {
    @Published var cache: [String: [DayCount]] = [:]

    func fetch(shouldBe: String, actual: String) {
        let key = "\(shouldBe)→\(actual)"
        guard cache[key] == nil else { return }
        NetworkManager.shared.fetchPhonemeHistory(shouldBe: shouldBe, actual: actual) { response in
            DispatchQueue.main.async {
                self.cache[key] = response?.history ?? []
            }
        }
    }

    func history(shouldBe: String, actual: String) -> [DayCount]? {
        cache["\(shouldBe)→\(actual)"]
    }
}

struct DiagnosticView: View {
    @StateObject private var vm            = DiagnosticViewModel()
    @StateObject private var wordsCache    = PhonemeWordsCache()
    @StateObject private var historyCache  = PhonemeHistoryCache()
    @State private var expandedMiss:     String? = nil
    @State private var expandedProgress: String? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    serverBanner
                    recordingSection

                    if !vm.isLoading && vm.farMisses.isEmpty && vm.closeMisses.isEmpty {
                        emptyState
                    }

                    if !vm.trends.isEmpty { progressSection }

                    if !vm.farMisses.isEmpty {
                        missChart(title: "Big Misses",
                                  subtitle: "Sounds you're pronouncing very differently",
                                  misses: vm.farMisses, color: .red)
                    }
                    if !vm.closeMisses.isEmpty {
                        missChart(title: "Close Misses",
                                  subtitle: "Sounds you're almost getting right",
                                  misses: vm.closeMisses, color: .yellow)
                    }
                    if !vm.suggestedWords.isEmpty { suggestedWordsSection }
                }
                .padding()
            }
        }
        .onAppear { vm.refresh() }
    }

    // ─────────────────────────────────────────────────────────
    //  SERVER BANNER
    // ─────────────────────────────────────────────────────────
    private var serverBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(vm.serverOnline ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            Text(vm.serverOnline ? "Server connected" : "Server offline — run server.py on your Mac")
                .font(.caption).foregroundColor(.gray)
            Spacer()
            if vm.isLoading { ProgressView().tint(.cyan).scaleEffect(0.7) }
            Button(action: { vm.refresh() }) {
                Image(systemName: "arrow.clockwise").foregroundColor(.cyan)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    // ─────────────────────────────────────────────────────────
    //  PROGRESS SECTION
    // ─────────────────────────────────────────────────────────
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle().fill(Color.purple).frame(width: 3, height: 20).cornerRadius(2)
                Text("Your Progress").font(.title3.bold()).foregroundColor(.white)
            }
            Text("Tap a row to see your history")
                .font(.caption).foregroundColor(.gray).padding(.leading, 11)

            VStack(spacing: 8) {
                ForEach(vm.trends) { trend in
                    trendRow(trend)
                }
            }
        }
    }

    @ViewBuilder
    private func trendRow(_ trend: PhonemeTrend) -> some View {
        let parts    = trend.phonemes.split(separator: "→").map(String.init)
        let shouldBe = parts.count > 0 ? parts[0] : "?"
        let actual   = parts.count > 1 ? parts[1] : "?"
        let isExp    = expandedProgress == trend.id
        let tcolor: Color = trend.trend == "improving" ? .green :
                            trend.trend == "worsening" ? .red : .yellow
        let history  = historyCache.history(shouldBe: shouldBe, actual: actual)

        VStack(alignment: .leading, spacing: 0) {
            // ── Row header ─────────────────────────────────────
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedProgress = isExp ? nil : trend.id
                }
                if !isExp {
                    historyCache.fetch(shouldBe: shouldBe, actual: actual)
                }
            }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("/\(actual)/")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9)).foregroundColor(.gray)
                            Text("/\(shouldBe)/")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        Text(phonemeLabel(actual))
                            .font(.system(size: 10)).foregroundColor(.gray).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 4) {
                        if trend.recentAccuracy == 0 {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.gray)
                            Text("No recent data")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                        } else if trend.trend == "improving" {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.green)
                            Text("Improving")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                        } else if trend.trend == "worsening" {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.red)
                            Text("Needs work")
                                .font(.caption.bold())
                                .foregroundColor(.red)
                        } else {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.yellow)
                            Text("Steady")
                                .font(.caption.bold())
                                .foregroundColor(.yellow)
                        }
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("recent: \(trend.recentAccuracy == 0 ? "N/A" : "\(trend.recentAccuracy)%")")
                            .font(.system(size: 10).monospacedDigit()).foregroundColor(.gray)
                        Text("before: \(trend.olderAccuracy == 0 ? "N/A" : "\(trend.olderAccuracy)%")")
                            .font(.system(size: 10).monospacedDigit()).foregroundColor(.gray)
                    }
                    
                    let tcolor: Color = trend.recentAccuracy == 0 ? .gray :
                                        trend.trend == "improving" ? .green :
                                        trend.trend == "worsening" ? .red : .yellow

                    Image(systemName: isExp ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10)).foregroundColor(.gray)
                }
                .padding(10)
            }
            .buttonStyle(.plain)

            // ── Expanded history chart ─────────────────────────
            if isExp {
                Divider().background(Color.white.opacity(0.08))

                if let history = history {
                    if history.isEmpty {
                        Text("No detailed history found")
                            .font(.caption).foregroundColor(.gray)
                            .padding(12)
                    } else {
                        miniBarChart(history: history, color: tcolor)
                            .padding(12)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                } else {
                    HStack(spacing: 6) {
                        ProgressView().tint(.gray).scaleEffect(0.7)
                        Text("Loading history…").font(.caption).foregroundColor(.gray)
                    }
                    .padding(12)
                }
            }
        }
        .background(tcolor.opacity(0.05))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tcolor.opacity(0.2), lineWidth: 1))
    }

    // ─────────────────────────────────────────────────────────
    //  MINI BAR CHART
    // ─────────────────────────────────────────────────────────
    @ViewBuilder
    private func miniBarChart(history: [DayCount], color: Color) -> some View {
        let maxCount = Double(history.map(\.count).max() ?? 1)

        VStack(alignment: .leading, spacing: 8) {
            Text("Misses per day")
                .font(.system(size: 10)).foregroundColor(.gray)

            GeometryReader { geo in
                let barWidth = max(12, (geo.size.width - CGFloat(history.count - 1) * 6) / CGFloat(history.count))
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(history) { day in
                        let barH = max(4, CGFloat(Double(day.count) / maxCount) * 60)
                        VStack(spacing: 4) {
                            Text("\(day.count)")
                                .font(.system(size: 9).monospacedDigit())
                                .foregroundColor(.gray)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color.opacity(0.7))
                                .frame(width: barWidth, height: barH)
                            Text(shortDate(day.date))
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 90)
        }
    }

    private func shortDate(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count >= 3 else { return dateStr }
        return "\(parts[1])/\(parts[2])"
    }

    // ─────────────────────────────────────────────────────────
    //  MISS CHART
    // ─────────────────────────────────────────────────────────
    private func missChart(title: String, subtitle: String,
                           misses: [PhonemeError], color: Color) -> some View {
        let maxCount = Double(misses.prefix(10).map(\.count).max() ?? 1)

        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Rectangle().fill(color).frame(width: 3, height: 20).cornerRadius(2)
                    Text(title).font(.title3.bold()).foregroundColor(.white)
                }
                Text(subtitle).font(.caption).foregroundColor(.gray).padding(.leading, 11)
            }

            VStack(spacing: 8) {
                ForEach(misses.prefix(10)) { miss in
                    let isExpanded  = expandedMiss == miss.id
                    let cachedWords = wordsCache.words(shouldBe: miss.shouldBe, actual: miss.actual)

                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedMiss = isExpanded ? nil : miss.id
                            }
                            if !isExpanded {
                                wordsCache.fetch(shouldBe: miss.shouldBe, actual: miss.actual)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text("/\(miss.actual)/")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundColor(color)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10)).foregroundColor(.gray)
                                Text("/\(miss.shouldBe)/")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(miss.count)×")
                                    .font(.caption.monospacedDigit()).foregroundColor(.gray)
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10)).foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(.plain)

                        if isExpanded {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("You said").font(.system(size: 10)).foregroundColor(.gray)
                                        Text(phonemeLabel(miss.actual))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(color)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Should be").font(.system(size: 10)).foregroundColor(.gray)
                                        Text(phonemeLabel(miss.shouldBe))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Divider().background(Color.white.opacity(0.1))

                                if let (sbWords, acWords) = cachedWords {
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Words with /\(miss.actual)/")
                                                .font(.system(size: 10)).foregroundColor(.gray)
                                            if acWords.isEmpty {
                                                Text("none found").font(.system(size: 12)).foregroundColor(.gray)
                                            } else {
                                                ForEach(acWords, id: \.self) { word in
                                                    Text(word)
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(color)
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Words with /\(miss.shouldBe)/")
                                                .font(.system(size: 10)).foregroundColor(.gray)
                                            if sbWords.isEmpty {
                                                Text("none found").font(.system(size: 12)).foregroundColor(.gray)
                                            } else {
                                                ForEach(sbWords, id: \.self) { word in
                                                    Text(word)
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                } else {
                                    HStack(spacing: 6) {
                                        ProgressView().tint(.gray).scaleEffect(0.7)
                                        Text("Loading words…").font(.caption).foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.white.opacity(0.06)).cornerRadius(4)
                                Rectangle()
                                    .fill(color.opacity(0.7))
                                    .frame(width: geo.size.width * CGFloat(Double(miss.count) / maxCount))
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(10)
                    .background(color.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isExpanded ? color.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
            }
            .padding(12)
            .background(color.opacity(0.05))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.15), lineWidth: 1))
        }
    }

    // ─────────────────────────────────────────────────────────
    //  SUGGESTED WORDS
    // ─────────────────────────────────────────────────────────
    private var suggestedWordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle().fill(Color.cyan).frame(width: 3, height: 20).cornerRadius(2)
                Text("Suggested Practice Words").font(.title3.bold()).foregroundColor(.white)
            }
            Text("Words that contain your most-missed sounds")
                .font(.caption).foregroundColor(.gray).padding(.leading, 11)

            if !vm.strugglingPhonemes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus sounds:").font(.caption).foregroundColor(.gray)
                    ForEach(vm.strugglingPhonemes, id: \.self) { p in
                        Text("• \(phonemeLabel(p))")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.cyan)
                    }
                }
                .padding(.leading, 11)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(vm.suggestedWords.prefix(20)) { word in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(word.word).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        Text(word.phonemes)
                            .font(.system(size: 11, design: .monospaced)).foregroundColor(.cyan).lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.2), lineWidth: 1))
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    //  RECORDING SECTION
    // ─────────────────────────────────────────────────────────
    private var recordingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Rectangle().fill(Color.green).frame(width: 3, height: 20).cornerRadius(2)
                Text("Record & Analyze").font(.title3.bold()).foregroundColor(.white)
            }
            Text("Record yourself speaking Spanish — it will be transcribed and analyzed.")
                .font(.caption).foregroundColor(.gray)

            if !vm.waitingForConfirmation {
                HStack(spacing: 16) {
                    Button(action: {
                        if vm.isRecording { vm.stopAndTranscribe() }
                        else              { vm.startRecording() }
                    }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(vm.isRecording ? Color.red : Color.green)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    vm.isRecording ?
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white).frame(width: 6, height: 6) : nil
                                )
                            Text(vm.isRecording ? "Stop Recording" : "Start Recording")
                                .font(.headline).foregroundColor(.white)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(vm.isRecording ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(vm.isRecording ? Color.red : Color.green, lineWidth: 1))
                    }

                    if vm.isRecording {
                        HStack(spacing: 3) {
                            ForEach(0..<5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2).fill(Color.red)
                                    .frame(width: 3, height: CGFloat.random(in: 8...24))
                                    .animation(.easeInOut(duration: 0.4).repeatForever()
                                        .delay(Double(i) * 0.1), value: vm.isRecording)
                            }
                        }
                    }
                }
            }

            if !vm.recordingStatus.isEmpty {
                HStack(spacing: 6) {
                    if vm.isAnalyzing { ProgressView().tint(.cyan).scaleEffect(0.7) }
                    Text(vm.recordingStatus)
                        .font(.caption)
                        .foregroundColor(vm.isAnalyzing ? .cyan : .gray)
                }
            }

            if vm.waitingForConfirmation {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Is this what you said?").font(.caption.bold()).foregroundColor(.gray)

                    TextField("Transcription", text: $vm.editableTranscription, axis: .vertical)
                        .font(.body).foregroundColor(.white).padding(12)
                        .background(Color.white.opacity(0.08)).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.4), lineWidth: 1))

                    Text("Edit above if it got something wrong, then tap Confirm.")
                        .font(.caption).foregroundColor(.gray)

                    HStack(spacing: 12) {
                        Button(action: { vm.confirmAndAnalyze() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Confirm & Analyze").font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            .background(Color.cyan.opacity(0.2)).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan, lineWidth: 1))
                        }
                        Button(action: { vm.cancelConfirmation() }) {
                            Text("Discard").font(.subheadline).foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color.cyan.opacity(0.04)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.15), lineWidth: 1))
            }

            if let result = vm.latestAnalysis {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Analysis complete — charts updated below.")
                        .font(.caption).foregroundColor(.green)
                    if !result.farMisses.isEmpty {
                        Text("Biggest miss: /\(result.farMisses[0].actual)/ → /\(result.farMisses[0].shouldBe)/")
                            .font(.caption).foregroundColor(.red)
                    }
                }
                .padding(10)
                .background(Color.green.opacity(0.05)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.03)).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // ─────────────────────────────────────────────────────────
    //  EMPTY STATE
    // ─────────────────────────────────────────────────────────
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.badge.mic").font(.system(size: 44)).foregroundColor(.gray)
            Text("No data yet").font(.headline).foregroundColor(.white)
            Text("Record yourself speaking Spanish above\nand your miss analysis will appear here.")
                .font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

// ─────────────────────────────────────────────────────────────
//  VIEW MODEL
// ─────────────────────────────────────────────────────────────
@MainActor
class DiagnosticViewModel: ObservableObject {
    @Published var farMisses:          [PhonemeError]  = []
    @Published var closeMisses:        [PhonemeError]  = []
    @Published var suggestedWords:     [SuggestedWord] = []
    @Published var strugglingPhonemes: [String]        = []
    @Published var trends:             [PhonemeTrend]  = []
    @Published var isLoading:          Bool            = false
    @Published var serverOnline:       Bool            = false

    @Published var isRecording:            Bool            = false
    @Published var isAnalyzing:            Bool            = false
    @Published var recordingStatus:        String          = ""
    @Published var waitingForConfirmation: Bool            = false
    @Published var editableTranscription:  String          = ""
    @Published var latestAnalysis:         MissesResponse? = nil

    private var recorder = RecordingManager()

    func refresh() {
        isLoading     = true
        recordingStatus = ""
        NetworkManager.shared.ping { [weak self] online in
            DispatchQueue.main.async { self?.serverOnline = online }
        }
        NetworkManager.shared.fetchMisses { [weak self] response in
            DispatchQueue.main.async {
                if let r = response {
                    self?.farMisses   = r.farMisses
                    self?.closeMisses = r.closeMisses
                }
            }
        }
        NetworkManager.shared.fetchSuggestedWords(n: 2) { [weak self] response in
            DispatchQueue.main.async {
                self?.suggestedWords     = response?.suggestedWords ?? []
                self?.strugglingPhonemes = response?.phonemes ?? []
                self?.isLoading          = false
            }
        }
        NetworkManager.shared.fetchProgress { [weak self] response in
            DispatchQueue.main.async { self?.trends = response?.trends ?? [] }
        }
    }

    func startRecording() {
        latestAnalysis  = nil
        recordingStatus = "Recording…"
        isRecording     = true
        recorder.startRecording()
    }

    func stopAndTranscribe() {
        isRecording     = false
        recordingStatus = "Transcribing…"
        recorder.stopAndTranscribe { [weak self] text in
            DispatchQueue.main.async {
                self?.editableTranscription  = text ?? ""
                self?.recordingStatus        = ""
                self?.waitingForConfirmation = true
            }
        }
    }

    func confirmAndAnalyze() {
        waitingForConfirmation = false
        isAnalyzing            = true
        recordingStatus        = "Running analysis…"
        recorder.uploadForAnalysis(correctedText: editableTranscription) { [weak self] response in
            DispatchQueue.main.async {
                self?.isAnalyzing = false
                if let r = response {
                    self?.latestAnalysis  = r
                    self?.recordingStatus = "Analysis complete!"
                    self?.farMisses       = r.farMisses
                    self?.closeMisses     = r.closeMisses
                    self?.refresh()
                } else {
                    self?.recordingStatus = "Upload failed — check server is running."
                }
            }
        }
    }

    func cancelConfirmation() {
        waitingForConfirmation = false
        editableTranscription  = ""
        recordingStatus        = ""
        latestAnalysis         = nil
        recorder.cancelRecording()
    }
}

#Preview {
    DiagnosticView()
}
