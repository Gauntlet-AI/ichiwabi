import SwiftUI

struct DreamCell: View {
    let dream: Dream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dream.title)
                .font(.headline)
            
            if let transcript = dream.transcript {
                Text(transcript)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text(dream.dreamDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if !dream.videoURL.absoluteString.isEmpty {
                    Spacer()
                    Image(systemName: "video.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
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