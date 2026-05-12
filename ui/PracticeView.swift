// PracticeView.swift

import SwiftUI
import AVFoundation

// ─────────────────────────────────────────────────────────────
//  PHONEME VISUAL GUIDE
//  Describes what to do for each phoneme category
// ─────────────────────────────────────────────────────────────
struct PhonemeGuide {
    let title:       String   // e.g. "Soft D"
    let instruction: String   // plain English what to do
    let category:    String   // "vowel", "plosive", "fricative", "nasal", "soft", "liquid", "vibrant"
    let contactPoint: String? // where tongue/lips touch
}

let phonemeGuides: [String: PhonemeGuide] = [
    // Vowels
    "a": PhonemeGuide(title: "A", instruction: "Open your mouth wide, tongue low and flat", category: "vowel", contactPoint: nil),
    "e": PhonemeGuide(title: "E", instruction: "Spread your lips slightly, tongue mid-front", category: "vowel", contactPoint: nil),
    "i": PhonemeGuide(title: "I", instruction: "Smile wide, tongue high and forward", category: "vowel", contactPoint: nil),
    "o": PhonemeGuide(title: "O", instruction: "Round your lips, tongue mid-back", category: "vowel", contactPoint: nil),
    "u": PhonemeGuide(title: "U", instruction: "Pucker your lips, tongue high and back", category: "vowel", contactPoint: nil),
    "j": PhonemeGuide(title: "Y glide", instruction: "Start with tongue high and forward, glide into next vowel", category: "vowel", contactPoint: nil),
    "w": PhonemeGuide(title: "W glide", instruction: "Start with lips rounded, glide into next vowel", category: "vowel", contactPoint: nil),

    // Plosives
    "p": PhonemeGuide(title: "P", instruction: "Press both lips together, then release with a pop", category: "plosive", contactPoint: "lips"),
    "b": PhonemeGuide(title: "B", instruction: "Press both lips together with voice, then release", category: "plosive", contactPoint: "lips"),
    "t": PhonemeGuide(title: "T", instruction: "Touch tongue tip to the back of upper front teeth, then release", category: "plosive", contactPoint: "upper teeth back"),
    "d": PhonemeGuide(title: "D", instruction: "Touch tongue tip to the back of upper front teeth with voice", category: "plosive", contactPoint: "upper teeth back"),
    "k": PhonemeGuide(title: "K", instruction: "Raise the back of your tongue to touch your soft palate, then release", category: "plosive", contactPoint: "soft palate"),
    "c": PhonemeGuide(title: "K (front)", instruction: "Raise mid-tongue to touch hard palate, release — slightly further forward than K", category: "plosive", contactPoint: "hard palate"),
    "g": PhonemeGuide(title: "G", instruction: "Raise the back of your tongue to soft palate with voice", category: "plosive", contactPoint: "soft palate"),

    // Fricatives
    "s": PhonemeGuide(title: "S", instruction: "Bring tongue close to the ridge behind upper teeth, let air hiss through", category: "fricative", contactPoint: "alveolar ridge"),
    "f": PhonemeGuide(title: "F", instruction: "Touch upper teeth to lower lip, push air through", category: "fricative", contactPoint: "upper teeth to lower lip"),
    "x": PhonemeGuide(title: "Spanish J", instruction: "Raise back of tongue toward soft palate, force air through the narrow gap", category: "fricative", contactPoint: "soft palate"),
    "θ": PhonemeGuide(title: "TH", instruction: "Put tongue tip between your teeth, push air through", category: "fricative", contactPoint: "between teeth"),

    // Soft consonants
    "β": PhonemeGuide(title: "Soft B/V", instruction: "Let both lips barely touch — not a full press, just a soft contact with voice", category: "soft", contactPoint: "lips (barely)"),
    "ð": PhonemeGuide(title: "Soft D", instruction: "Let tongue tip barely touch back of upper teeth — relaxed, not a full stop", category: "soft", contactPoint: "upper teeth (barely)"),
    "ɣ": PhonemeGuide(title: "Soft G", instruction: "Raise back of tongue near soft palate without fully touching — create gentle friction", category: "soft", contactPoint: "soft palate (barely)"),

    // Nasals
    "m": PhonemeGuide(title: "M", instruction: "Close both lips, let air flow through your nose while humming", category: "nasal", contactPoint: "lips closed"),
    "n": PhonemeGuide(title: "N", instruction: "Touch tongue tip to the ridge behind upper teeth, hum through nose", category: "nasal", contactPoint: "alveolar ridge"),
    "ɲ": PhonemeGuide(title: "Ñ", instruction: "Press mid-tongue to hard palate, hum through nose — like 'canyon'", category: "nasal", contactPoint: "hard palate"),
    "ŋ": PhonemeGuide(title: "NG", instruction: "Raise back of tongue to soft palate, hum through nose — like 'sing'", category: "nasal", contactPoint: "soft palate"),

    // Liquids
    "l": PhonemeGuide(title: "L", instruction: "Touch tongue tip to the ridge behind upper teeth, let air flow around the sides", category: "liquid", contactPoint: "alveolar ridge"),

    // Vibrants
    "ɾ": PhonemeGuide(title: "Tap R", instruction: "Flick tongue tip once quickly against the ridge behind upper teeth — one tap only", category: "vibrant", contactPoint: "alveolar ridge"),
    "r": PhonemeGuide(title: "Trill R", instruction: "Relax tongue tip near the ridge, let airflow make it flutter rapidly", category: "vibrant", contactPoint: "alveolar ridge"),

    // Approximants
    "ʝ": PhonemeGuide(title: "Spanish LL/Y", instruction: "Raise mid-tongue toward hard palate, let air flow with voice", category: "soft", contactPoint: "hard palate"),
    "ʎ": PhonemeGuide(title: "Spanish LL", instruction: "Press mid-tongue to hard palate sides, like a lateral palatal", category: "liquid", contactPoint: "hard palate"),
]

// ─────────────────────────────────────────────────────────────
//  MOUTH DIAGRAM VIEW
//  SVG-style SwiftUI drawing of mouth cross-section
// ─────────────────────────────────────────────────────────────
struct MouthDiagram: View {
    let phoneme: String
    let isActive: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let guide = phonemeGuides[phoneme]

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.06))

                if let guide = guide {
                    switch guide.category {
                    case "vowel":
                        vowelDiagram(w: w, h: h, phoneme: phoneme)
                    case "plosive":
                        plosiveDiagram(w: w, h: h, guide: guide)
                    case "fricative":
                        fricativeDiagram(w: w, h: h, guide: guide)
                    case "nasal":
                        nasalDiagram(w: w, h: h, guide: guide)
                    case "soft":
                        softDiagram(w: w, h: h, guide: guide)
                    case "liquid", "vibrant":
                        liquidDiagram(w: w, h: h, guide: guide)
                    default:
                        defaultDiagram(w: w, h: h, guide: guide)
                    }
                } else {
                    defaultDiagram(w: w, h: h, guide: PhonemeGuide(
                        title: "/\(phoneme)/",
                        instruction: "Make the sound",
                        category: "other",
                        contactPoint: nil
                    ))
                }
            }
        }
    }

    // ── Vowel — mini F1/F2 map with target highlighted ────────
    @ViewBuilder
    private func vowelDiagram(w: CGFloat, h: CGFloat, phoneme: String) -> some View {
        let vowelPositions: [String: (x: CGFloat, y: CGFloat)] = [
            "i": (0.15, 0.15), "j": (0.18, 0.18), "e": (0.28, 0.38),
            "a": (0.5,  0.82), "o": (0.72, 0.45), "u": (0.85, 0.25),
            "w": (0.82, 0.28), "ʝ": (0.2,  0.22),
        ]

        ZStack {
            // Axes labels
            Text("FRONT")
                .font(.system(size: 7)).foregroundColor(.gray)
                .position(x: w * 0.18, y: h * 0.06)
            Text("BACK")
                .font(.system(size: 7)).foregroundColor(.gray)
                .position(x: w * 0.82, y: h * 0.06)
            Text("OPEN")
                .font(.system(size: 7)).foregroundColor(.gray)
                .position(x: w * 0.06, y: h * 0.82)
                .rotationEffect(.degrees(-90))
            Text("CLOSED")
                .font(.system(size: 7)).foregroundColor(.gray)
                .position(x: w * 0.06, y: h * 0.2)
                .rotationEffect(.degrees(-90))

            // Grid lines
            Path { p in
                p.move(to: CGPoint(x: w * 0.12, y: h * 0.1))
                p.addLine(to: CGPoint(x: w * 0.95, y: h * 0.1))
                p.move(to: CGPoint(x: w * 0.12, y: h * 0.1))
                p.addLine(to: CGPoint(x: w * 0.12, y: h * 0.92))
            }
            .stroke(Color.white.opacity(0.1), lineWidth: 1)

            // All vowel dots
            ForEach(Array(vowelPositions.keys), id: \.self) { v in
                let pos = vowelPositions[v]!
                Circle()
                    .fill(v == phoneme ? Color.cyan : Color.white.opacity(0.15))
                    .frame(width: v == phoneme ? 24 : 8, height: v == phoneme ? 24 : 8)
                    .position(x: w * pos.x + w * 0.1, y: h * pos.y + h * 0.08)
                Text(v)
                    .font(.system(size: v == phoneme ? 11 : 7, weight: .bold))
                    .foregroundColor(v == phoneme ? .black : .white.opacity(0.4))
                    .position(x: w * pos.x + w * 0.1, y: h * pos.y + h * 0.08)
            }

            // Instruction at bottom
            if let guide = phonemeGuides[phoneme] {
                Text(guide.instruction)
                    .font(.system(size: 8))
                    .foregroundColor(.cyan)
                    .multilineTextAlignment(.center)
                    .frame(width: w * 0.85)
                    .position(x: w * 0.5, y: h * 0.92)
            }
        }
    }

    // ── Plosive — shows where contact is made ─────────────────
    @ViewBuilder
    private func plosiveDiagram(w: CGFloat, h: CGFloat, guide: PhonemeGuide) -> some View {
        ZStack {
            mouthOutline(w: w, h: h)

            // Highlight contact point
            let contactColor = isActive ? Color.red : Color.cyan

            switch phoneme {
            case "p", "b":
                // Lips together
                RoundedRectangle(cornerRadius: 3)
                    .fill(contactColor.opacity(0.6))
                    .frame(width: w * 0.5, height: 5)
                    .position(x: w * 0.5, y: h * 0.5)
                arrowLabel("Press lips together", w: w, h: h, y: 0.72, color: contactColor)

            case "t", "d":
                // Tongue tip to upper teeth back
                tongueShape(w: w, h: h, tipX: 0.38, tipY: 0.38, color: contactColor)
                arrowLabel("Tongue to back of upper teeth", w: w, h: h, y: 0.82, color: contactColor)

            case "k", "c", "g":
                // Tongue back to soft palate
                tongueShape(w: w, h: h, tipX: 0.62, tipY: 0.28, color: contactColor)
                arrowLabel(phoneme == "c" ? "Mid-tongue to hard palate" : "Back of tongue to soft palate",
                           w: w, h: h, y: 0.82, color: contactColor)

            default:
                arrowLabel(guide.instruction, w: w, h: h, y: 0.82, color: contactColor)
            }

            // Pulsing dot when active
            if isActive {
                Circle()
                    .fill(Color.red.opacity(0.4))
                    .frame(width: 20, height: 20)
                    .position(x: w * 0.5, y: h * 0.15)
                Text("RELEASE!")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.red)
                    .position(x: w * 0.5, y: h * 0.06)
            }
        }
    }

    // ── Fricative — shows narrow gap and airflow ──────────────
    @ViewBuilder
    private func fricativeDiagram(w: CGFloat, h: CGFloat, guide: PhonemeGuide) -> some View {
        ZStack {
            mouthOutline(w: w, h: h)
            let airColor = isActive ? Color.yellow : Color.cyan.opacity(0.6)

            switch phoneme {
            case "s":
                tongueShape(w: w, h: h, tipX: 0.4, tipY: 0.35, color: airColor)
                // Airflow lines
                ForEach(0..<3, id: \.self) { i in
                    Path { p in
                        let startX = w * CGFloat(0.35 + Double(i) * 0.08)
                        p.move(to: CGPoint(x: startX, y: h * 0.35))
                        p.addLine(to: CGPoint(x: startX - w * 0.08, y: h * 0.15))
                    }
                    .stroke(airColor, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                }
                arrowLabel("Hiss through narrow gap", w: w, h: h, y: 0.82, color: airColor)

            case "f":
                // Upper teeth to lower lip
                Path { p in
                    p.move(to: CGPoint(x: w * 0.3, y: h * 0.52))
                    p.addLine(to: CGPoint(x: w * 0.7, y: h * 0.52))
                }
                .stroke(airColor, lineWidth: 3)
                arrowLabel("Upper teeth touch lower lip", w: w, h: h, y: 0.82, color: airColor)

            case "x":
                tongueShape(w: w, h: h, tipX: 0.65, tipY: 0.25, color: airColor)
                arrowLabel("Constrict at back — force air through", w: w, h: h, y: 0.82, color: airColor)

            case "θ":
                // Tongue between teeth
                tongueShape(w: w, h: h, tipX: 0.32, tipY: 0.47, color: airColor)
                arrowLabel("Tongue TIP between teeth", w: w, h: h, y: 0.82, color: airColor)

            default:
                arrowLabel(guide.instruction, w: w, h: h, y: 0.82, color: airColor)
            }
        }
    }

    // ── Nasal — shows closed mouth, air through nose ──────────
    @ViewBuilder
    private func nasalDiagram(w: CGFloat, h: CGFloat, guide: PhonemeGuide) -> some View {
        ZStack {
            mouthOutline(w: w, h: h)
            let nasalColor = isActive ? Color.green : Color.cyan.opacity(0.7)

            // Lips closed
            RoundedRectangle(cornerRadius: 2)
                .fill(nasalColor.opacity(0.5))
                .frame(width: w * 0.45, height: 4)
                .position(x: w * 0.5, y: h * 0.5)

            // Nasal airflow arrows going up
            ForEach(0..<2, id: \.self) { i in
                Path { p in
                    let x = w * CGFloat(0.42 + Double(i) * 0.16)
                    p.move(to: CGPoint(x: x, y: h * 0.45))
                    p.addLine(to: CGPoint(x: x, y: h * 0.08))
                }
                .stroke(nasalColor, style: StrokeStyle(lineWidth: 2, dash: [4, 2]))
            }

            // Nose indicator
            Text("↑ through nose")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(nasalColor)
                .position(x: w * 0.5, y: h * 0.06)

            switch phoneme {
            case "m":
                arrowLabel("Lips closed — hum through nose", w: w, h: h, y: 0.82, color: nasalColor)
            case "n":
                tongueShape(w: w, h: h, tipX: 0.38, tipY: 0.38, color: nasalColor)
                arrowLabel("Tongue to ridge — hum through nose", w: w, h: h, y: 0.82, color: nasalColor)
            case "ɲ":
                tongueShape(w: w, h: h, tipX: 0.52, tipY: 0.28, color: nasalColor)
                arrowLabel("Mid-tongue to palate — like canyon", w: w, h: h, y: 0.82, color: nasalColor)
            case "ŋ":
                tongueShape(w: w, h: h, tipX: 0.65, tipY: 0.25, color: nasalColor)
                arrowLabel("Back of tongue up — like sing", w: w, h: h, y: 0.82, color: nasalColor)
            default:
                arrowLabel(guide.instruction, w: w, h: h, y: 0.82, color: nasalColor)
            }
        }
    }

    // ── Soft consonant — barely touching ─────────────────────
    @ViewBuilder
    private func softDiagram(w: CGFloat, h: CGFloat, guide: PhonemeGuide) -> some View {
        ZStack {
            mouthOutline(w: w, h: h)
            let softColor = isActive ? Color.orange : Color.cyan.opacity(0.7)

            switch phoneme {
            case "β":
                // Lips barely apart
                Path { p in
                    p.move(to: CGPoint(x: w * 0.28, y: h * 0.48))
                    p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.48))
                }
                .stroke(softColor, lineWidth: 1.5)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.28, y: h * 0.52))
                    p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.52))
                }
                .stroke(softColor, lineWidth: 1.5)
                Text("tiny gap")
                    .font(.system(size: 7)).foregroundColor(softColor)
                    .position(x: w * 0.78, y: h * 0.5)
                arrowLabel("Lips BARELY touching — not a full B", w: w, h: h, y: 0.82, color: softColor)

            case "ð":
                tongueShape(w: w, h: h, tipX: 0.37, tipY: 0.4, color: softColor)
                Text("barely")
                    .font(.system(size: 7)).foregroundColor(softColor)
                    .position(x: w * 0.28, y: h * 0.34)
                arrowLabel("Tongue barely touches upper teeth", w: w, h: h, y: 0.82, color: softColor)

            case "ɣ":
                tongueShape(w: w, h: h, tipX: 0.64, tipY: 0.27, color: softColor)
                arrowLabel("Back of tongue near palate — don't touch", w: w, h: h, y: 0.82, color: softColor)

            case "ʝ":
                tongueShape(w: w, h: h, tipX: 0.5, tipY: 0.25, color: softColor)
                arrowLabel("Mid-tongue near hard palate with voice", w: w, h: h, y: 0.82, color: softColor)

            default:
                arrowLabel(guide.instruction, w: w, h: h, y: 0.82, color: softColor)
            }
        }
    }

    // ── Liquid / Vibrant ──────────────────────────────────────
    @ViewBuilder
    private func liquidDiagram(w: CGFloat, h: CGFloat, guide: PhonemeGuide) -> some View {
        ZStack {
            mouthOutline(w: w, h: h)
            let lColor = isActive ? Color.purple : Color.cyan.opacity(0.7)

            switch phoneme {
            case "l":
                tongueShape(w: w, h: h, tipX: 0.38, tipY: 0.35, color: lColor)
                // Side airflow arrows
                ForEach([0.22, 0.78] as [CGFloat], id: \.self) { x in
                    Path { p in
                        p.move(to: CGPoint(x: w * x, y: h * 0.45))
                        p.addLine(to: CGPoint(x: w * x, y: h * 0.15))
                    }
                    .stroke(lColor, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                }
                arrowLabel("Tongue to ridge, air flows around sides", w: w, h: h, y: 0.82, color: lColor)

            case "ɾ":
                // Single tap visualization
                tongueShape(w: w, h: h, tipX: 0.38, tipY: 0.32, color: lColor)
                Text("ONE quick flick!")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(lColor)
                    .position(x: w * 0.5, y: h * 0.12)
                arrowLabel("Single fast flick of tongue tip", w: w, h: h, y: 0.82, color: lColor)

            case "r":
                // Trill — show flutter
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(lColor.opacity(isActive ? 0.8 : 0.3))
                        .frame(width: 6, height: 6)
                        .position(x: w * CGFloat(0.32 + Double(i) * 0.08),
                                  y: h * (0.38 + (i % 2 == 0 ? 0.0 : 0.06)))
                }
                arrowLabel("Tongue flutters rapidly against ridge", w: w, h: h, y: 0.82, color: lColor)

            default:
                arrowLabel(guide.instruction, w: w, h: h, y: 0.82, color: lColor)
            }
        }
    }

    // ── Default ───────────────────────────────────────────────
    @ViewBuilder
    private func defaultDiagram(w: CGFloat, h: CGFloat, guide: PhonemeGuide) -> some View {
        VStack(spacing: 6) {
            Text("/\(phoneme)/")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            Text(guide.instruction)
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .position(x: w * 0.5, y: h * 0.5)
    }

    // ── Drawing helpers ───────────────────────────────────────
    @ViewBuilder
    private func mouthOutline(w: CGFloat, h: CGFloat) -> some View {
        // Simplified side-view mouth cross section
        ZStack {
            // Upper palate curve
            Path { p in
                p.move(to: CGPoint(x: w * 0.15, y: h * 0.5))
                p.addCurve(to: CGPoint(x: w * 0.85, y: h * 0.2),
                           control1: CGPoint(x: w * 0.3, y: h * 0.15),
                           control2: CGPoint(x: w * 0.65, y: h * 0.15))
            }
            .stroke(Color.white.opacity(0.25), lineWidth: 2)

            // Lower jaw line
            Path { p in
                p.move(to: CGPoint(x: w * 0.15, y: h * 0.5))
                p.addCurve(to: CGPoint(x: w * 0.85, y: h * 0.55),
                           control1: CGPoint(x: w * 0.3, y: h * 0.7),
                           control2: CGPoint(x: w * 0.65, y: h * 0.65))
            }
            .stroke(Color.white.opacity(0.25), lineWidth: 2)

            // Teeth marks
            ForEach(0..<4, id: \.self) { i in
                let x = w * CGFloat(0.2 + Double(i) * 0.06)
                Path { p in
                    p.move(to: CGPoint(x: x, y: h * 0.46))
                    p.addLine(to: CGPoint(x: x, y: h * 0.54))
                }
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
            }
        }
    }

    @ViewBuilder
    private func tongueShape(w: CGFloat, h: CGFloat, tipX: CGFloat, tipY: CGFloat, color: Color) -> some View {
        Path { p in
            let tx = w * tipX
            let ty = h * tipY
            p.move(to: CGPoint(x: tx, y: ty))
            p.addCurve(to: CGPoint(x: w * 0.75, y: h * 0.6),
                       control1: CGPoint(x: tx + w * 0.15, y: ty + h * 0.1),
                       control2: CGPoint(x: w * 0.65, y: h * 0.5))
            p.addCurve(to: CGPoint(x: w * 0.75, y: h * 0.7),
                       control1: CGPoint(x: w * 0.82, y: h * 0.62),
                       control2: CGPoint(x: w * 0.82, y: h * 0.68))
            p.addCurve(to: CGPoint(x: tx, y: ty + h * 0.08),
                       control1: CGPoint(x: w * 0.6, y: h * 0.62),
                       control2: CGPoint(x: tx + w * 0.12, y: ty + h * 0.15))
            p.closeSubpath()
        }
        .fill(color.opacity(0.4))
        .overlay(
            Path { p in
                let tx = w * tipX
                let ty = h * tipY
                p.move(to: CGPoint(x: tx, y: ty))
                p.addCurve(to: CGPoint(x: w * 0.75, y: h * 0.6),
                           control1: CGPoint(x: tx + w * 0.15, y: ty + h * 0.1),
                           control2: CGPoint(x: w * 0.65, y: h * 0.5))
            }
            .stroke(color, lineWidth: 2)
        )
    }

    @ViewBuilder
    private func arrowLabel(_ text: String, w: CGFloat, h: CGFloat, y: CGFloat, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(color)
            .multilineTextAlignment(.center)
            .frame(width: w * 0.9)
            .position(x: w * 0.5, y: h * y)
    }
}

// ─────────────────────────────────────────────────────────────
//  CONSTANTS
// ─────────────────────────────────────────────────────────────
private struct VowelTarget {
    let symbol: String
    let f2: Double
    let f1: Double
}

private let VOWELS: [VowelTarget] = [
    VowelTarget(symbol: "a",  f2: 1450, f1: 750),
    VowelTarget(symbol: "e",  f2: 1900, f1: 450),
    VowelTarget(symbol: "i",  f2: 2300, f1: 300),
    VowelTarget(symbol: "o",  f2: 1000, f1: 500),
    VowelTarget(symbol: "u",  f2: 800,  f1: 350),
    VowelTarget(symbol: "w",  f2: 900,  f1: 350),
    VowelTarget(symbol: "j",  f2: 2200, f1: 300),
    VowelTarget(symbol: "ʝ",  f2: 2100, f1: 350),
]

private let VOWEL_SET  = Set(["a","e","i","o","u","w","j","ʝ"])
private let FRICTION   = Set(["s","f","x","θ"])
private let NASAL      = Set(["m","n","ɲ","ŋ"])
private let POPS       = Set(["p","t","k","b","d","g"])
private let VIBRANT    = Set(["r","ɾ"])
private let LIQUID     = Set(["l"])
private let SOFT_B     = Set(["β","ð","ɣ","ʝ"])
private let MAX_STABILITY = 5
private let VOLUME_THRESHOLD: Double = 80

private let F2_MAX: Double = 2800
private let F2_MIN: Double = 600
private let F1_MAX: Double = 1000
private let F1_MIN: Double = 200

private func mapF2(_ f2: Double, width: CGFloat) -> CGFloat {
    CGFloat((F2_MAX - f2) / (F2_MAX - F2_MIN)) * width
}
private func mapF1(_ f1: Double, height: CGFloat) -> CGFloat {
    CGFloat((f1 - F1_MIN) / (F1_MAX - F1_MIN)) * height
}

// ─────────────────────────────────────────────────────────────
//  PRACTICE VIEW
// ─────────────────────────────────────────────────────────────
struct PracticeView: View {
    var f1: Double
    var f2: Double
    var volume:   Double
    var centroid: Double
    var flatness: Double
    var isRecording: Bool

    @State private var wordInput:        String          = ""
    @State private var activeWord:       String          = ""
    @State private var phonemes:         [String]        = []
    @State private var letterPhonemeMap: [Int: Int]      = [:]
    @State private var wordReady:        Bool            = false
    @State private var isLoading:        Bool            = false
    @State private var errorMsg:         String          = ""
    @State private var suggestedWords:   [SuggestedWord] = []
    @State private var loadingSuggested: Bool            = false

    @State private var phoneIdx:          Int      = 0
    @State private var stability:         Int      = 0
    @State private var completedPhonemes: Set<Int> = []
    @State private var finished:          Bool     = false

    @State private var vHistory:    [Double] = Array(repeating: 0, count: 5)
    @State private var impactCount: Int      = 0
    @State private var trillWindow: Int      = 0

    private var volDelta:     Double { volume - (vHistory.reduce(0,+) / Double(vHistory.count)) }
    private var isImpact:     Bool   { (volDelta > 80 && volume > 150) || flatness > 0.05 }
    private var isHiss:       Bool   { centroid > 3200 }
    private var isSmooth:     Bool   { !isImpact && !isHiss && volume > 120 }
    private var volumeHeight: Double { min(0.95, volume / 700) }
    private var hissHeight:   Double { min(0.95, centroid / 5500) }
    private var impactHeight: Double { min(0.95, max(0, volDelta) / 400) }

    private var showHissTarget: Bool {
        guard let t = targetPhone else { return false }
        return FRICTION.contains(t)
    }
    private var showImpactTarget: Bool {
        guard let t = targetPhone else { return false }
        return VIBRANT.contains(t) || POPS.contains(t)
    }

    private var targetPhone: String? {
        phoneIdx < phonemes.count ? phonemes[phoneIdx] : nil
    }
    private var targetVowel: VowelTarget? {
        guard let t = targetPhone else { return nil }
        return VOWELS.first(where: { $0.symbol == t })
    }

    private var hintText: String {
        guard isRecording else { return "TAP MIC TO START" }
        guard volume > VOLUME_THRESHOLD else { return "SPEAK NOW..." }
        guard let target = targetPhone else { return "" }

        if VOWEL_SET.contains(target), let v = targetVowel {
            if f1 > v.f1 + 130 { return "CLOSE MOUTH ↑" }
            if f1 < v.f1 - 130 { return "OPEN WIDER ↓" }
            if f2 > v.f2 + 200 { return "TONGUE FORWARD →" }
            if f2 < v.f2 - 200 { return "TONGUE BACK ←" }
            return "✓ PERFECT!"
        }
        return phonemeGuides[target]?.instruction.uppercased() ?? "MAKE THE SOUND"
    }

    private var isSuccess: Bool {
        guard isRecording, volume > VOLUME_THRESHOLD, let target = targetPhone else { return false }

        if VOWEL_SET.contains(target), let v = targetVowel {
            let dist = ((f2 - v.f2) * (f2 - v.f2) + (f1 - v.f1) * (f1 - v.f1)).squareRoot()
            return dist < 600 && volumeHeight > 0.35
        }
        if target == "r"                { return volume > VOLUME_THRESHOLD }
        if target == "ɾ"               { return volume > VOLUME_THRESHOLD }
        if FRICTION.contains(target)   { return centroid > 3000 }
        return volume > VOLUME_THRESHOLD
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !wordReady        { wordInputScreen }
            else if finished     { successScreen }
            else                 { trainerScreen }
        }
        .onChange(of: volume) { _, _ in
            updateVHistory()
            handleProgression()
        }
        .onAppear { fetchSuggestedWords() }
    }

    // ─────────────────────────────────────────────────────────
    //  WORD INPUT SCREEN
    // ─────────────────────────────────────────────────────────
    private var wordInputScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 8)
                Text("Practice")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if loadingSuggested {
                    ProgressView().tint(.cyan)
                } else if !suggestedWords.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Rectangle().fill(Color.cyan).frame(width: 3, height: 18).cornerRadius(2)
                            Text("Suggested for You").font(.headline).foregroundColor(.white)
                        }
                        Text("Based on your recent misses — tap to practice")
                            .font(.caption).foregroundColor(.gray)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(suggestedWords.prefix(8)) { word in
                                Button(action: { wordInput = word.word; fetchPhonemes() }) {
                                    ZStack(alignment: .topTrailing) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(word.word)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.white)
                                            Text(word.phonemes)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.cyan).lineLimit(1)
                                        }
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.cyan.opacity(0.08))
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1))

                                        let count = UserDefaults.standard.integer(
                                            forKey: "practiced_\(word.word.lowercased())")
                                        if count > 0 {
                                            Text("\(count)×")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 5).padding(.vertical, 2)
                                                .background(Color.cyan).cornerRadius(6)
                                                .padding(5)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                HStack {
                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                    Text("or type your own").font(.caption).foregroundColor(.gray).fixedSize()
                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                }
                .padding(.horizontal, 16)

                VStack(spacing: 12) {
                    TextField("e.g. encontrar", text: $wordInput)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.title3)
                        .padding(.horizontal, 32)
                        .onSubmit { fetchPhonemes() }

                    if !errorMsg.isEmpty {
                        Text(errorMsg).font(.caption).foregroundColor(.red)
                    }

                    Button(action: fetchPhonemes) {
                        HStack {
                            if isLoading { ProgressView().tint(.black) }
                            Text(isLoading ? "Loading…" : "Start Practicing").font(.headline)
                        }
                        .foregroundColor(.black)
                        .frame(width: 220, height: 48)
                        .background(wordInput.isEmpty ? Color.gray : Color.cyan)
                        .cornerRadius(12)
                    }
                    .disabled(wordInput.isEmpty || isLoading)
                }
                Spacer().frame(height: 16)
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    //  SUCCESS SCREEN
    // ─────────────────────────────────────────────────────────
    private var successScreen: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle().fill(Color.green.opacity(0.15)).frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 80)).foregroundColor(.green)
            }
            Text("EXCELLENT!")
                .font(.system(size: 36, weight: .black, design: .rounded)).foregroundColor(.green)
            Text("You nailed \(activeWord)").font(.title3).foregroundColor(.white)

            HStack(spacing: 4) {
                ForEach(Array(activeWord.enumerated()), id: \.offset) { i, char in
                    VStack(spacing: 2) {
                        Text(String(char).uppercased())
                            .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.green)
                        if let pi = letterPhonemeMap[i], pi < phonemes.count {
                            Text("/\(phonemes[pi])/").font(.system(size: 10)).foregroundColor(.green.opacity(0.8))
                        }
                    }
                    .frame(minWidth: 36)
                }
            }
            .padding().background(Color.green.opacity(0.08)).cornerRadius(12)

            Button(action: resetForNewWord) {
                Text("Choose Another Word").font(.headline).foregroundColor(.black)
                    .frame(width: 240, height: 52).background(Color.green).cornerRadius(14)
            }
            Button(action: resetWithSameWord) {
                Text("Practice Again").font(.subheadline).foregroundColor(.green)
            }
            Spacer()
        }
        .padding()
    }

    // ─────────────────────────────────────────────────────────
    //  TRAINER SCREEN
    // ─────────────────────────────────────────────────────────
    private var trainerScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Text(activeWord)
                    .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.white)
                Spacer()
                Button("Change Word") { resetForNewWord() }.font(.caption).foregroundColor(.cyan)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            // ── Main visual area ───────────────────────────────
            if let target = targetPhone {
                if VOWEL_SET.contains(target) {
                    // Vowel: show F1/F2 map with labeled axes
                    vowelMapPanel
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .padding(.horizontal, 8)
                } else {
                    // Consonant: show mouth diagram + airflow side by side
                    HStack(spacing: 8) {
                        MouthDiagram(phoneme: target, isActive: volume > VOLUME_THRESHOLD)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        if FRICTION.contains(target) || POPS.contains(target) || VIBRANT.contains(target) {
                            airflowPanel.frame(width: 100)
                        }
                    }
                    .frame(height: 260)
                    .padding(.horizontal, 8)
                }
            }

            wordProgressStrip
                .frame(height: 90)
                .padding(8)

            Spacer()
        }
    }

    // ─────────────────────────────────────────────────────────
    //  VOWEL MAP  — with labeled axes
    // ─────────────────────────────────────────────────────────
    private var vowelMapPanel: some View {
        VStack(spacing: 0) {
            // Axis labels
            HStack {
                Text("MOUTH\nOPEN").font(.system(size: 8)).foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                Spacer()
                Text("TONGUE\nFRONT").font(.system(size: 8)).foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                Spacer()
                Text("TONGUE\nBACK").font(.system(size: 8)).foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                Spacer()
                Text("MOUTH\nCLOSED").font(.system(size: 8)).foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8).padding(.bottom, 2)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                if w > 0 && h > 0 {
                    ZStack {
                        Rectangle()
                            .fill(Color(white: 0.04))
                            .overlay(Rectangle().stroke(Color.white.opacity(0.15), lineWidth: 1))

                        ForEach(VOWELS, id: \.symbol) { v in
                            let cx = mapF2(v.f2, width: w)
                            let cy = mapF1(v.f1, height: h)
                            let isTarget = targetPhone == v.symbol
                            let rx = max(1, CGFloat(200 / (F2_MAX - F2_MIN)) * w)
                            let ry = max(1, CGFloat(180 / (F1_MAX - F1_MIN)) * h)

                            Ellipse()
                                .fill(isTarget ? Color.green.opacity(0.15) : Color.white.opacity(0.06))
                                .frame(width: rx * 2, height: ry * 2.2)
                                .position(x: cx, y: cy)

                            Text(v.symbol)
                                .font(.system(size: isTarget ? 15 : 12, weight: .bold))
                                .foregroundColor(isTarget ? .green : .white.opacity(0.5))
                                .position(x: cx, y: cy)
                        }

                        // Target circle
                        if let tv = targetVowel {
                            let tx = mapF2(tv.f2, width: w)
                            let ty = mapF1(tv.f1, height: h)
                            let tr = max(1, CGFloat(250 / (F2_MAX - F2_MIN)) * w)
                            Circle()
                                .stroke(Color.green, lineWidth: 2)
                                .frame(width: tr * 2, height: tr * 2)
                                .position(x: tx, y: ty)
                                .opacity(isRecording ? 0.85 : 0.4)
                        }

                        // Live dot
                        if isRecording && f1 > 0 && f2 > 0 {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 18, height: 18)
                                .shadow(color: .red, radius: 6)
                                .position(x: mapF2(f2, width: w), y: mapF1(f1, height: h))
                                .animation(.easeOut(duration: 0.05), value: f1)
                                .animation(.easeOut(duration: 0.05), value: f2)
                        }

                        // Hint
                        VStack {
                            Spacer()
                            Text(hintText)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(hintText.contains("✓") ? .green : .yellow)
                                .padding(.bottom, 6)
                        }
                    }
                }
            }
        }
        .background(Color(white: 0.05))
        .cornerRadius(10)
    }

    // ─────────────────────────────────────────────────────────
    //  AIRFLOW PANEL
    // ─────────────────────────────────────────────────────────
    private var airflowPanel: some View {
        VStack(spacing: 0) {
            Text("Airflow").font(.system(size: 11, weight: .semibold)).foregroundColor(.white).padding(.bottom, 4)
            GeometryReader { geo in
                let totalH = geo.size.height
                if totalH > 24 {
                    let maxH = totalH - 24
                    HStack(alignment: .bottom, spacing: 4) {
                        airBar(label: "Hiss", barHeight: isHiss ? hissHeight : 0,
                               color: Color(red: 1, green: 0, blue: 1),
                               showTarget: showHissTarget, maxH: maxH)
                        airBar(label: "Pop", barHeight: isImpact ? impactHeight : 0,
                               color: Color(red: 0.4, green: 1, blue: 0.4),
                               showTarget: showImpactTarget, maxH: maxH)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(6)
        .background(Color(white: 0.05))
        .cornerRadius(10)
    }

    private func airBar(label: String, barHeight: Double, color: Color,
                        showTarget: Bool, maxH: CGFloat) -> some View {
        let targetBottom = maxH * 0.15
        let targetHeight = maxH * 0.50
        let barPx = max(0, CGFloat(barHeight) * maxH)
        return VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Rectangle().fill(Color.white.opacity(0.05)).frame(width: 26, height: maxH)
                if showTarget {
                    Rectangle().stroke(Color.green, lineWidth: 1.5)
                        .frame(width: 26, height: targetHeight).offset(y: -targetBottom)
                }
                Rectangle().fill(color.opacity(0.75)).frame(width: 26, height: barPx)
                    .animation(.easeOut(duration: 0.08), value: barHeight)
            }
            .frame(height: maxH)
            Text(label).font(.system(size: 7)).foregroundColor(.white.opacity(0.6))
                .fixedSize().padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    // ─────────────────────────────────────────────────────────
    //  WORD PROGRESS STRIP
    // ─────────────────────────────────────────────────────────
    private var wordProgressStrip: some View {
        let letters = Array(activeWord)
        return GeometryReader { geo in
            let letterWidth: CGFloat = 44
            let totalWidth = CGFloat(letters.count) * letterWidth
            let needsScroll = totalWidth > geo.size.width

            let content = HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(letters.enumerated()), id: \.offset) { i, char in
                    let phonemeIdx = letterPhonemeMap[i]
                    let isDone     = phonemeIdx.map { completedPhonemes.contains($0) } ?? false
                    let isCurrent  = phonemeIdx == phoneIdx

                    VStack(spacing: 2) {
                        Text(String(char).uppercased())
                            .font(.system(size: needsScroll ? 24 : 32, weight: .bold, design: .rounded))
                            .foregroundColor(isDone ? .green : .white)
                            .opacity(isDone ? 1.0 : isCurrent ? 1.0 : 0.25)
                        if let pi = phonemeIdx, pi < phonemes.count {
                            Text("/\(phonemes[pi])/")
                                .font(.system(size: needsScroll ? 9 : 11, weight: .medium))
                                .foregroundColor(isDone ? .green : .cyan)
                                .opacity(isDone ? 1.0 : isCurrent ? 1.0 : 0.2)
                        }
                    }
                    .frame(minWidth: needsScroll ? 32 : 40)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)

            if needsScroll {
                ScrollView(.horizontal, showsIndicators: false) { content }
                    .background(Color(white: 0.05)).cornerRadius(10)
            } else {
                content.frame(maxWidth: .infinity)
                    .background(Color(white: 0.05)).cornerRadius(10)
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    //  PROGRESSION LOGIC
    // ─────────────────────────────────────────────────────────
    private func updateVHistory() {
        vHistory.append(volume); vHistory.removeFirst()
    }

    private func handleProgression() {
        guard wordReady, !finished, phoneIdx < phonemes.count else { return }
        guard volume > VOLUME_THRESHOLD else { stability = 0; return }

        if isSuccess {
            stability += 1
            if stability >= MAX_STABILITY {
                completedPhonemes.insert(phoneIdx)
                phoneIdx   += 1
                stability   = 0
                impactCount = 0
                trillWindow = 0
                if phoneIdx >= phonemes.count {
                    finished = true
                    let key   = "practiced_\(activeWord.lowercased())"
                    let count = UserDefaults.standard.integer(forKey: key)
                    UserDefaults.standard.set(count + 1, forKey: key)
                }
            }
        } else {
            stability = 0
        }
    }

    // ─────────────────────────────────────────────────────────
    //  HELPERS
    // ─────────────────────────────────────────────────────────
    private func fetchSuggestedWords() {
        loadingSuggested = true
        NetworkManager.shared.fetchSuggestedWords(n: 2) { response in
            DispatchQueue.main.async {
                self.suggestedWords   = response?.suggestedWords ?? []
                self.loadingSuggested = false
            }
        }
    }

    private func resetForNewWord() {
        wordReady = false; wordInput = ""; phonemes = []
        letterPhonemeMap = [:]; phoneIdx = 0; stability = 0
        completedPhonemes = []; finished = false
        impactCount = 0; trillWindow = 0
    }

    private func resetWithSameWord() {
        phoneIdx = 0; stability = 0; completedPhonemes = []
        finished = false; impactCount = 0; trillWindow = 0
    }

    private func fetchPhonemes() {
        let cleaned = wordInput.lowercased().trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return }
        isLoading = true; errorMsg = ""

        let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleaned
        guard let url = URL(string: "\(ServerConfig.baseURL)/phonemize?word=\(encoded)") else {
            errorMsg = "Bad URL"; isLoading = false; return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                guard let data = data, error == nil,
                      let json = try? JSONDecoder().decode(PhonemizeResponse.self, from: data)
                else { errorMsg = "Couldn't reach server — is server.py running?"; return }

                activeWord       = cleaned.uppercased()
                phonemes         = json.phonemes
                letterPhonemeMap = buildLetterMap(word: cleaned, phonemes: json.phonemes)
                phoneIdx = 0; stability = 0; completedPhonemes = []; finished = false
                wordReady = true
            }
        }.resume()
    }

    private func buildLetterMap(word: String, phonemes: [String]) -> [Int: Int] {
        var map: [Int: Int] = [:]
        var pOffset = 0
        let letters = Array(word)
        for (i, char) in letters.enumerated() {
            if char == "h" || char == " " { continue }
            if i > 0 && char == letters[i-1] && (char == "l" || char == "r") { continue }
            if pOffset < phonemes.count { map[i] = pOffset; pOffset += 1 }
        }
        return map
    }
}

private struct PhonemizeResponse: Codable {
    let phonemes: [String]
}

#Preview {
    PracticeView(f1: 450, f2: 1900, volume: 300, centroid: 2000, flatness: 0.05, isRecording: true)
        .preferredColorScheme(.dark)
}
