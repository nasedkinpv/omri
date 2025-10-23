import Foundation

// MARK: - Groq Transcription Service

class GroqTranscriptionService: BaseHTTPService, TranscriptionService {
    private let isTranslation: Bool

    init(apiKey: String, translation: Bool = false) {
        self.isTranslation = translation
        let endpoint = translation
            ? "https://api.groq.com/openai/v1/audio/translations"
            : "https://api.groq.com/openai/v1/audio/transcriptions"
        super.init(apiKey: apiKey, endpoint: endpoint)
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

        // Create multipart form data request
        let boundary = UUID().uuidString
        var request = try createRequest(contentType: .multipartFormData(boundary: boundary))

        // Use centralized model configuration system
        let (parameters, arrayParams) = ModelConfigurationManager.shared.buildTranscriptionParameters(
            for: model,
            language: isTranslation ? "en" : language, // Force "en" for translations
            prompt: prompt,
            responseFormat: responseFormat ?? (isTranslation ? "json" : nil),
            temperature: temperature,
            timestampGranularities: isTranslation ? nil : timestampGranularities
        )

        request.setMultipartFormData(
            fileData: audioData,
            fileName: fileName,
            mimeType: MIMETypeUtility.mimeType(for: fileName),
            parameters: parameters,
            arrayParameters: arrayParams
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try handleHTTPResponse(data, response)
            return try JSONDecoder().decode(GroqTranscriptionResponse.self, from: data)
        } catch let error as HTTPError {
            throw TranscriptionError(from: error)
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.decodingError(error)
        }
    }
}

