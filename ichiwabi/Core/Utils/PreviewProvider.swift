import SwiftUI

struct PreviewProvider {
    static var devices = [
        "iPhone 15 Pro",
        "iPhone SE (3rd generation)",
        "iPhone 15 Pro Max"
    ]
    
    static var devicePreviewLayout: some View {
        ForEach(devices, id: \.self) { device in
            ContentView()
                .previewDevice(PreviewDevice(rawValue: device))
                .previewDisplayName(device)
        }
    }
} 