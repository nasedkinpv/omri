import Foundation

class OpenAITranscriptionService: TranscriptionService {
    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/audio/transcriptions"

    init(apiKey: String) {
        self.apiKey = apiKey
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

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

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
        
        NSLog("OpenAI Transcription Request URL: \(request.url?.absoluteString ?? "N/A")")
        NSLog("OpenAI Transcription Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        NSLog("OpenAI Transcription Request Parameters (excluding file): \(parameters)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscriptionError.networkError(URLError(.badServerResponse))
            }
            
            NSLog("OpenAI Transcription API Response Status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                 NSLog("OpenAI Transcription API Raw Response: \(responseString)")
            }

            if !(200...299).contains(httpResponse.statusCode) {
                var errorMessage: String?
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorDetail = errorJson["error"] as? [String: Any],
                   let message = errorDetail["message"] as? String {
                    errorMessage = message
                }
                throw TranscriptionError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            do {
                // Convert OpenAI response format to Groq format for API compatibility
                let decoder = JSONDecoder()
                
                // Basic response handling - in a real implementation we'd need to handle
                // the differences between OpenAI and Groq response formats more completely
                let effectiveResponseFormat = responseFormat ?? "verbose_json"
                if effectiveResponseFormat == "verbose_json" {
                    // OpenAI doesn't have a verbose_json equivalent yet, so we simulate it
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let text = json["text"] as? String {
                        // Create a simplified GroqTranscriptionResponse with just the text
                        let response = GroqTranscriptionResponse(
                            text: text,
                            task: "transcribe",
                            language: language,
                            duration: nil,
                            segments: nil
                        )
                        return response
                    }
                }
                
                // Fallback: try to decode directly assuming formats are compatible
                let transcriptionResponse = try decoder.decode(GroqTranscriptionResponse.self, from: data)
                NSLog("OpenAI Transcription successful.")
                return transcriptionResponse
            } catch {
                NSLog("OpenAI Transcription decoding error: \(error.localizedDescription). Data: \(String(data: data, encoding: .utf8) ?? "Non-UTF8 data")")
                throw TranscriptionError.decodingError(error)
            }
        } catch let error as TranscriptionError {
            NSLog("OpenAI Transcription failed with TranscriptionError: \(error.localizedDescription)")
            throw error
        } catch {
            NSLog("OpenAI Transcription failed with general error: \(error.localizedDescription)")
            throw TranscriptionError.networkError(error)
        }
    }
    
}