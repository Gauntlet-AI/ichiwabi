import Foundation

enum DreamAnalysisError: Error {
    case networkError(Error)
    case invalidResponse
    case serverError(String)
}

actor DreamAnalysisService {
    private let baseURL = "https://yorutabi-api.vercel.app"
    private var activeChatId: Int?
    private let throttleInterval: TimeInterval = 1.0 // 1 second between messages
    private var lastMessageTime: Date = .distantPast
    
    func startChat(dream: Dream, analyst: String) async throws -> String {
        let url = URL(string: "\(baseURL)/start-chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "analyst": analyst.lowercased(),
            "dream": dream.dreamDescription,
            "messages": []
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DreamAnalysisError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chatId = json["chat_id"] as? Int,
              let response = json["response"] as? String else {
            throw DreamAnalysisError.invalidResponse
        }
        
        activeChatId = chatId
        lastMessageTime = Date()
        return response
    }
    
    func sendMessage(_ message: String) async throws -> String {
        guard let chatId = activeChatId else {
            throw DreamAnalysisError.serverError("No active chat session")
        }
        
        // Implement throttling
        let timeSinceLastMessage = Date().timeIntervalSince(lastMessageTime)
        if timeSinceLastMessage < throttleInterval {
            try await Task.sleep(nanoseconds: UInt64((throttleInterval - timeSinceLastMessage) * 1_000_000_000))
        }
        
        let url = URL(string: "\(baseURL)/chat/\(chatId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            [
                "role": "user",
                "content": message
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DreamAnalysisError.invalidResponse
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["response"] as? String else {
            throw DreamAnalysisError.invalidResponse
        }
        
        lastMessageTime = Date()
        return response
    }
    
    func endChat() {
        activeChatId = nil
    }
} 