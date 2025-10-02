import Foundation

class OpenAITranscriptionService: BaseHTTPService, TranscriptionService {

    init(apiKey: String) {
        super.init(apiKey: apiKey, endpoint: "https://api.openai.com/v1/audio/transcriptions")
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
            language: language,
            prompt: prompt,
            responseFormat: responseFormat,
            temperature: temperature,
            timestampGranularities: timestampGranularities
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

            // Handle OpenAI response format
            let effectiveResponseFormat = responseFormat ?? "verbose_json"
            if effectiveResponseFormat == "verbose_json" {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let text = json["text"] as? String {
                    return GroqTranscriptionResponse(
                        text: text,
                        task: "transcribe",
                        language: language,
                        duration: nil,
                        segments: nil
                    )
                }
            }

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