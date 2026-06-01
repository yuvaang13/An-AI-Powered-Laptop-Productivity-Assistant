import SwiftUI

struct OrbView: View {
    weak var windowManager: WindowManager?
    let decisionEngine: DecisionEngine

    init(windowManager: WindowManager?, decisionEngine: DecisionEngine) {
        self.windowManager = windowManager
        self.decisionEngine = decisionEngine
    }

    var body: some View {
        ZStack {
            if windowManager?.isOrbExpanded ?? false {
                ChatView(windowManager: windowManager, decisionEngine: decisionEngine)
                    .frame(width: Configuration.Dimensions.orbExpandedWidth, height: Configuration.Dimensions.orbExpandedHeight)
            } else {
                MindGateOrb(size: Configuration.Dimensions.orbSize, presentation: .compact)
                    .frame(width: Configuration.Dimensions.orbSize, height: Configuration.Dimensions.orbSize)
                    .contentShape(Circle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: Configuration.Animation.orbTransitionDuration)) {
                            windowManager?.expandOrb()
                        }
                    }
            }
        }
    }
}

struct MindGateOrb: View {
    enum Presentation {
        case compact
        case interface
    }

    let size: CGFloat
    var presentation: Presentation = .compact
    var palette: MindGateOrbPalette = .mindGate

    @State private var wavePhase: CGFloat = 0
    @State private var breath: CGFloat = 0

    var body: some View {
        ZStack {
            // Luminescent glow background
            RadialGradient(
                colors: [
                    palette.violet.opacity(0.4),
                    palette.indigo.opacity(0.2),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: size * 0.6
            )
            .blur(radius: 15)
            .frame(width: size, height: size)

            // Glassmorphic base
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .clear, palette.violet.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: palette.violet.opacity(0.5), radius: 20, x: 0, y: 0)

            // Siri-inspired animated wave lines
            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    WaveLine(
                        phase: wavePhase + CGFloat(index) * 0.5,
                        amplitude: 8 + CGFloat(index) * 2,
                        frequency: 0.02 + CGFloat(index) * 0.005,
                        yOffset: CGFloat(index - 2) * 4
                    )
                    .stroke(
                        LinearGradient(
                            colors: [palette.violet, palette.teal, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    .opacity(0.3 + CGFloat(index) * 0.1)
                }
            }
            .frame(width: size * 0.7, height: size * 0.5)
            .blur(radius: 1)
        }
        .frame(width: size, height: size)
        .scaleEffect(1 + breath * 0.03)
        .opacity(0.95 + breath * 0.05)
        .drawingGroup(opaque: false, colorMode: .linear)
        .accessibilityLabel("MindGate AI orb")
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breath = 1
            }
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                wavePhase = 2 * .pi
            }
        }
    }
}

struct WaveLine: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat
    var yOffset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height / 2 + yOffset

        path.move(to: CGPoint(x: 0, y: midY))

        for x in stride(from: 0, through: width, by: 1) {
            let normalizedX = x / width
            let y = midY + sin(normalizedX * .pi * 2 * frequency + phase) * amplitude * sin(normalizedX * .pi)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

struct MindGateOrbPalette {
    // Icon-matched color palette based on the MindGate icon
    let indigo = Color(hex: "#7C3AED")
    let violet = Color(hex: "#8B5CF6")
    let deepViolet = Color(hex: "#4C1D95")
    let teal = Color(hex: "#A78BFA")
    let emerald = Color(hex: "#C4B5FD")
    let cyan = Color(hex: "#DDD6FE")
    let pink = Color(hex: "#F5D0FE")
    let ink = Color(hex: "#1E1B4B")
    let glassWhite = Color.white

    static let mindGate = MindGateOrbPalette()
}

private extension Color {
    init(hex: String, alpha: Double = 1) {
        var value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }

        var integer: UInt64 = 0
        Scanner(string: value).scanHexInt64(&integer)

        let red = Double((integer >> 16) & 0xFF) / 255.0
        let green = Double((integer >> 8) & 0xFF) / 255.0
        let blue = Double(integer & 0xFF) / 255.0

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
