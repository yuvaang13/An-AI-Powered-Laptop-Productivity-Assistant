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
                FlowingLinesView(size: Configuration.Dimensions.orbSize)
                    .frame(width: Configuration.Dimensions.orbSize, height: Configuration.Dimensions.orbSize)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: Configuration.Animation.orbTransitionDuration)) {
                            windowManager?.expandOrb()
                        }
                    }
            }
        }
    }
}

struct FlowingLinesView: View {
    let size: CGFloat
    
    @State private var phase: CGFloat = 0
    @State private var breath: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
            
            // White flowing lines animation
            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    FlowingLine(
                        phase: phase + CGFloat(index) * 0.8,
                        amplitude: 15 + CGFloat(index) * 3,
                        frequency: 0.03 + CGFloat(index) * 0.005,
                        yOffset: CGFloat(index - 2) * 8
                    )
                    .stroke(
                        Color.white.opacity(0.6 - CGFloat(index) * 0.08),
                        lineWidth: 1.5
                    )
                }
            }
            .frame(width: size * 0.8, height: size * 0.6)
            .blur(radius: 0.5)
        }
        .frame(width: size, height: size)
        .scaleEffect(1 + breath * 0.05)
        .opacity(0.95 + breath * 0.05)
        .drawingGroup(opaque: false, colorMode: .linear)
        .accessibilityLabel("MindGate flowing lines")
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                breath = 1
            }
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
        }
    }
}

struct FlowingLine: Shape {
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
