import SwiftUI

struct DreamCell: View {
    let dream: Dream
    @State private var phase = 0.0
    @State private var innerPhase = 0.0
    @State private var isPressed = false
    @State private var borderPhase = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dream.title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(dream.dreamDescription)
                .font(.subheadline)
                .foregroundStyle(.black.opacity(0.7))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
            
            Text(dream.dreamDate.formatted(date: .abbreviated, time: .omitted))
                .font(.callout)
                .foregroundStyle(Color(red: 51/255, green: 153/255, blue: 255/255))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(width: 160, height: 160)
        .background(
            ZStack {
                // Base gradient layer
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color(red: 244/255, green: 218/255, blue: 248/255),
                        Color(red: 218/255, green: 244/255, blue: 248/255),
                        Color(red: 248/255, green: 228/255, blue: 244/255),
                        Color(red: 244/255, green: 218/255, blue: 248/255)
                    ]),
                    center: .center,
                    angle: .degrees(phase * 360)
                )
                
                // Overlay gradient for smoke effect
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.2),
                        Color.white.opacity(0.0)
                    ]),
                    center: .init(x: 0.5 + cos(innerPhase) * 0.5,
                                y: 0.5 + sin(innerPhase) * 0.5),
                    startRadius: 0,
                    endRadius: 150
                )
                .blendMode(.plusLighter)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.3),
                            Color.blue.opacity(0.8),
                            Color(red: 0/255, green: 122/255, blue: 255/255),
                            Color.blue.opacity(0.8),
                            Color.blue.opacity(0.3)
                        ]),
                        center: .center,
                        angle: .degrees(borderPhase * 360)
                    ),
                    lineWidth: 8
                )
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(isPressed ? 0.1 : 0.2), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                phase = 1.0
            }
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                innerPhase = .pi * 2
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                borderPhase = 1.0
            }
        }
    }
}

#Preview {
    DreamCell(dream: Dream(
        userId: "preview-user-id",
        title: "Flying Dream with Gang in the Magical Sky Adventure",
        description: "I was flying over mountains and oceans with my gang, soaring through clouds and witnessing the most breathtaking views of the world below.",
        date: Date(),
        videoURL: URL(string: "https://example.com/video.mp4")!,
        dreamDate: Date()
    ))
    .padding()
    .background(Color(.systemGroupedBackground))
} 
