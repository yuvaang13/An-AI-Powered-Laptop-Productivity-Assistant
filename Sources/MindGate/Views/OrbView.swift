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
                MindGateOrb(size: Configuration.Dimensions.orbSize)
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
    let size: CGFloat

    @State private var pulse: CGFloat = 0.96
    @State private var glow: Double = 0.45
    @State private var rotation: Double = 0.0

    var body: some View {
        ZStack {
            haloLayer
            spectrumLayer
            coreLayer
            highlightLayer
        }
        .frame(width: size, height: size)
        .scaleEffect(pulse)
        .shadow(color: Configuration.Colors.primary.opacity(glow), radius: size * 0.38)
        .shadow(color: Configuration.Colors.accent.opacity(glow * 0.65), radius: size * 0.24)
        .onAppear(perform: startAnimation)
    }

    private var haloLayer: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Configuration.Colors.accent.opacity(glow * 0.35),
                        Configuration.Colors.primary.opacity(glow * 0.22),
                        Configuration.Colors.secondary.opacity(glow * 0.16),
                        .clear
                    ],
                    center: .center,
                    startRadius: size * 0.22,
                    endRadius: size * 0.92
                )
            )
            .frame(width: size * 1.9, height: size * 1.9)
            .blur(radius: size * 0.14)
    }

    private var spectrumLayer: some View {
        Circle()
            .fill(
                AngularGradient(
                    colors: [
                        Configuration.Colors.accent,
                        Configuration.Colors.primary,
                        Configuration.Colors.secondary,
                        Color(red: 0.95, green: 0.23, blue: 0.63),
                        Configuration.Colors.accent
                    ],
                    center: .center
                )
            )
            .rotationEffect(.degrees(rotation))
            .blur(radius: size * 0.015)
    }

    private var coreLayer: some View {
        let outerStroke = max(size * 0.018, 1)
        let innerStroke = max(size * 0.012, 1)

        return ZStack {
            Circle()
                .fill(coreGradient)
                .padding(size * 0.08)

            Circle()
                .stroke(Color.white.opacity(0.28), lineWidth: outerStroke)

            Circle()
                .stroke(Configuration.Colors.accent.opacity(0.5), lineWidth: innerStroke)
                .blur(radius: size * 0.018)
                .padding(size * 0.09)
        }
    }

    private var coreGradient: RadialGradient {
        RadialGradient(
            colors: [
                Color.white.opacity(0.9),
                Configuration.Colors.accent.opacity(0.82),
                Configuration.Colors.primary.opacity(0.88),
                Configuration.Colors.secondary.opacity(0.82),
                Configuration.Colors.background.opacity(0.7)
            ],
            center: .topLeading,
            startRadius: 1,
            endRadius: size * 0.64
        )
    }

    private var highlightLayer: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.7),
                        Color.white.opacity(0.08),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.24
                )
            )
            .frame(width: size * 0.42, height: size * 0.42)
            .offset(x: -size * 0.17, y: -size * 0.19)
            .blendMode(.screen)
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: Configuration.Animation.orbBreathingDuration).repeatForever(autoreverses: true)) {
            pulse = 1.05
            glow = 0.75
        }

        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            rotation = 360.0
        }
    }
}
