import Foundation


// MARK: - Optimized Service
class GroqTranscriptionService: TranscriptionService {
    private let apiKey: String
    private let isTranslation: Bool
    private let session = URLSession.shared
    
    init(apiKey: String, translation: Bool = false) {
        self.apiKey = apiKey
        self.isTranslation = translation
    }
    
    private var endpoint: String {
        isTranslation
            ? "https://api.groq.com/openai/v1/audio/translations"
            : "https://api.groq.com/openai/v1/audio/transcriptions"
    }
    
    func transcribe(
        audioData: Data,
        fileName: String,
        model: String,
        language: String?,
        prompt: String?,
        responseFormat: String?,
        temperature: Double?,
        timestampGranularities: [String]?
    ) async throws -> GroqTranscriptionResponse {
        guard !apiKey.isEmpty else {
            throw TranscriptionError.apiKeyMissing
        }

        guard let url = URL(string: endpoint) else {
            throw TranscriptionError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Use centralized model configuration system
        let (parameters, arrayParams) = ModelConfigurationManager.shared.buildTranscriptionParameters(
            for: model,
            language: isTranslation ? "en" : language, // Force "en" for translations
            prompt: prompt,
            responseFormat: responseFormat ?? (isTranslation ? "json" : nil), // Let config handle default
            temperature: temperature,
            timestampGranularities: isTranslation ? nil : timestampGranularities // Skip for translations
        )
        request.setMultipartFormData(
            fileData: audioData,
            fileName: fileName,
            mimeType: MIMETypeUtility.mimeType(for: fileName),
            parameters: parameters,
            arrayParameters: arrayParams
        )
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.networkError(URLError(.badServerResponse))
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            throw TranscriptionError.apiError(
                statusCode: httpResponse.statusCode,
                message: extractErrorMessage(from: data)
            )
        }
        
        do {
            return try JSONDecoder().decode(GroqTranscriptionResponse.self, from: data)
        } catch {
            throw TranscriptionError.decodingError(error)
        }
    }
    
    private func extractErrorMessage(from data: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?
            .flatMap { $0["error"] as? [String: Any] }
            .flatMap { $0["message"] as? String }
    }
    
}

