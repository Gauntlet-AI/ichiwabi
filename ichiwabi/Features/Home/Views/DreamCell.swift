import SwiftUI

struct DreamCell: View {
    let dream: Dream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dream.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            if let transcript = dream.transcript {
                Text(transcript)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                Text(dream.dreamDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if dream.videoURL != nil {
                    Spacer()
                    Image(systemName: "video.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    DreamCell(dream: Dream(
        title: "Flying Dream", 
        transcript: "I was flying over mountains and oceans...",
        dreamDate: Date(),
        userId: "preview-user-id"
    ))
    .padding()
    .background(Color(.systemGroupedBackground))
} 