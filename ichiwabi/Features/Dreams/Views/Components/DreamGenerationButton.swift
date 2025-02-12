import SwiftUI

struct DreamGenerationButton: View {
    let action: () -> Void
    @State private var isAnimating = false
    
    // Gradient colors for the magical effect
    private let gradientColors = [
        Color(red: 0.4, green: 0.2, blue: 0.8), // Deep purple
        Color(red: 0.8, green: 0.2, blue: 0.6), // Magenta
        Color(red: 0.2, green: 0.4, blue: 0.8)  // Royal blue
    ]
    
    var body: some View {
        Button(action: action) {
            Text("Make my Dream Real")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    GeometryReader { geometry in
                        ZStack {
                            // Base gradient
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            // Animated overlay gradient
                            LinearGradient(
                                colors: gradientColors.map { $0.opacity(0.5) },
                                startPoint: isAnimating ? .topLeading : .bottomTrailing,
                                endPoint: isAnimating ? .bottomTrailing : .topLeading
                            )
                            .blur(radius: 10)
                            
                            // Glow effect
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            .white.opacity(isAnimating ? 0.3 : 0.1),
                                            .clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: geometry.size.width / 2
                                    )
                                )
                                .scaleEffect(isAnimating ? 1.2 : 1.0)
                                .opacity(isAnimating ? 0.8 : 0.4)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: gradientColors[0].opacity(0.5),
                    radius: isAnimating ? 15 : 10,
                    x: 0,
                    y: 0
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 24)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

// Custom button style for scale animation on press
private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        DreamGenerationButton {
            print("Button tapped")
        }
    }
} 