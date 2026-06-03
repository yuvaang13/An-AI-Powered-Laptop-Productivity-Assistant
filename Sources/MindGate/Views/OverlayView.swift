import SwiftUI

struct OverlayView: View {
    let configuration: Configuration

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent dark background
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                
                // Liquid Glass overlay card
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .red.opacity(0.5), radius: 20)
                    
                    Text("Access Denied")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.white.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Return to your work")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: configuration.theme.colors.textSecondary))
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: configuration.theme.colors.accent)))
                        .scaleEffect(1.5)
                }
                .frame(width: 400, height: 300)
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.regularMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.black.opacity(0.3))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 50, x: 0, y: 20)
                .shadow(color: .white.opacity(0.05), radius: 30, x: 0, y: 10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}