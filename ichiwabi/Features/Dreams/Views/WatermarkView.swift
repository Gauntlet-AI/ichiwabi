import SwiftUI

struct WatermarkView: View {
    let date: Date
    let title: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // App branding
            HStack {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(.white)
                Text("ichiwabi")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            // Dream title if available
            if let title = title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            
            // Dream date
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(8)
        .background(.black.opacity(0.3))
        .cornerRadius(8)
        .padding(12)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Preview with video background
        ZStack {
            Color.blue
                .frame(width: 300, height: 500)
                .overlay {
                    Text("Video Preview")
                        .foregroundStyle(.white)
                }
            
            VStack {
                Spacer()
                HStack {
                    WatermarkView(
                        date: Date(),
                        title: "Flying over mountains"
                    )
                    Spacer()
                }
            }
        }
        
        // Preview with different backgrounds
        HStack(spacing: 20) {
            // Dark background
            WatermarkView(
                date: Date(),
                title: "Night dream"
            )
            .background(.black)
            
            // Light background
            WatermarkView(
                date: Date(),
                title: "Day dream"
            )
            .background(.white)
        }
        
        // Preview without title
        WatermarkView(
            date: Date(),
            title: nil
        )
        .background(.gray)
    }
    .padding()
    .background(Color(.systemBackground))
} 