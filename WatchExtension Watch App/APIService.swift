import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(String)
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .uploadFailed:
            return "Failed to upload file"
        }
    }
}

actor APIService {
    private let baseURL = "https://yorutabi-api.vercel.app"
    
    // MARK: - Transcription
    struct TranscriptionResponse: Codable {
        let transcription: String
    }
    
    func transcribeAudio(fileURL: URL) async throws -> String {
        let endpoint = "\(baseURL)/transcribe-speech"
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create form data with audio file
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        print("🎤 ==================== API REQUEST DEBUG ====================")
        print("🎤 Endpoint: \(endpoint)")
        print("🎤 File URL: \(fileURL)")
        print("🎤 File exists: \(FileManager.default.fileExists(atPath: fileURL.path))")
        
        if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
            print("🎤 File size: \(fileAttributes[.size] ?? 0) bytes")
        }
        
        // Add audio file to form data
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        
        // Read audio file data
        do {
            let audioData = try Data(contentsOf: fileURL)
            print("🎤 Audio data size: \(audioData.count) bytes")
            data.append(audioData)
            data.append("\r\n".data(using: .utf8)!)
            data.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = data
            print("🎤 Total request body size: \(data.count) bytes")
            print("🎤 Content-Type: \(request.value(forHTTPHeaderField: "Content-Type") ?? "none")")
            print("🎤 ==================== END DEBUG ====================")
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            print("🎤 ==================== API RESPONSE DEBUG ====================")
            print("🎤 Status code: \(httpResponse.statusCode)")
            if let responseString = String(data: responseData, encoding: .utf8) {
                print("🎤 Response body: \(responseString)")
            }
            print("🎤 Response headers: \(httpResponse.allHeaderFields)")
            print("🎤 ==================== END DEBUG ====================")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorJson = try? JSONDecoder().decode([String: String].self, from: responseData),
                   let errorMessage = errorJson["error"] {
                    throw APIError.serverError(errorMessage)
                }
                throw APIError.serverError("Status code: \(httpResponse.statusCode)")
            }
            
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: responseData)
            return transcriptionResponse.transcription
        } catch {
            print("❌ Error reading audio file: \(error)")
            throw APIError.uploadFailed
        }
    }
    
    // MARK: - Title Generation
    struct TitleRequest: Codable {
        let dream: String
    }
    
    struct TitleResponse: Codable {
        let title: String
    }
    
    func generateTitle(dream: String) async throws -> String {
        let endpoint = "\(baseURL)/generate-title"
        
        // Create URL with query parameter
        var urlComponents = URLComponents(string: endpoint)
        urlComponents?.queryItems = [
            URLQueryItem(name: "dream", value: dream)
        ]
        
        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        print("\n🎯 ==================== TITLE GENERATION DEBUG ====================")
        print("🎯 Endpoint: \(url)")
        print("🎯 Dream text: \(dream)")
        print("🎯 ==================== END REQUEST DEBUG ====================")
        
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            print("🎯 ==================== RESPONSE DEBUG ====================")
            print("🎯 Status code: \(httpResponse.statusCode)")
            if let responseString = String(data: responseData, encoding: .utf8) {
                print("🎯 Response body: \(responseString)")
            }
            print("🎯 Response headers: \(httpResponse.allHeaderFields)")
            print("🎯 ==================== END DEBUG ====================\n")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorJson = try? JSONDecoder().decode([String: String].self, from: responseData),
                   let errorMessage = errorJson["error"] {
                    throw APIError.serverError(errorMessage)
                }
                throw APIError.serverError("Status code: \(httpResponse.statusCode)")
            }
            
            let titleResponse = try JSONDecoder().decode(TitleResponse.self, from: responseData)
            return titleResponse.title
        } catch {
            print("❌ Title generation error: \(error)")
            throw error
        }
    }
} 