import SwiftUI

struct AIHomeView: View {
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var response: String?
    @State private var error: Error?
    
    struct APIResponse: Codable {
        let message: String
    }
    
    var body: some View {
        ZStack {
            Theme.darkNavy
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                TextField("Enter text", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                Button("おはよう") {
                    Task {
                        await makeAPICall()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(inputText.isEmpty || isLoading)
                
                if isLoading {
                    ProgressView()
                }
                
                if let response = response {
                    Text(response)
                        .foregroundColor(Theme.textPrimary)
                        .padding()
                }
                
                if let error = error {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .navigationTitle("AI")
    }
    
    private func makeAPICall() async {
        isLoading = true
        error = nil
        response = nil
        
        // URL encode the input text
        guard let encodedText = inputText.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://yorutabi-api.vercel.app/hello/\(encodedText)") else {
            error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid input"])
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
            response = apiResponse.message
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        AIHomeView()
    }
} 
