import SwiftUI

struct DreamCell: View {
    let dream: Dream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dream.title)
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            if let transcript = dream.transcript {
                Text(transcript)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Theme.textSecondary)
                Text(dream.dreamDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                
                if !dream.videoURL.absoluteString.isEmpty {
                    Spacer()
                    Image(systemName: "video.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding()
        .background(Theme.darkNavy.opacity(0.3))
        .cornerRadius(12)
    }
}

#Preview {
    DreamCell(dream: Dream(
        userId: "preview-user-id",
        title: "Flying Dream",
        description: "I was flying over mountains and oceans...",
        date: Date(),
        videoURL: URL(string: "https://example.com/video.mp4")!,
        dreamDate: Date()
    ))
    .padding()
    .background(Color(.systemGroupedBackground))
} 