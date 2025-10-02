import Foundation

// MARK: - Transcription Response Structures

struct WordTimestamp: Codable {
    let word: String
    let start: Double
    let end: Double
}

struct TranscriptionSegment: Codable {
    let id: Int
    let seek: Int
    let start: Double
    let end: Double
    let text: String
    let tokens: [Int]
    let temperature: Double
    let avgLogprob: Double
    let compressionRatio: Double
    let noSpeechProb: Double
    let words: [WordTimestamp]? // Optional because it depends on timestamp_granularities

    enum CodingKeys: String, CodingKey {
        case id, seek, start, end, text, tokens, temperature
        case avgLogprob = "avg_logprob"
        case compressionRatio = "compression_ratio"
        case noSpeechProb = "no_speech_prob"
        case words
    }
}

struct GroqTranscriptionResponse: Codable {
    let text: String // Always present, even in verbose_json
    let task: String? // Present in verbose_json
    let language: String? // Present in verbose_json
    let duration: Double? // Present in verbose_json
    let segments: [TranscriptionSegment]? // Present in verbose_json
}
struct GroqTranslationsResponse: Codable {
    let text: String // Always present, even in verbose_json
    let task: String? // Present in verbose_json
    let language: String? // Present in verbose_json
    let duration: Double? // Present in verbose_json
    let segments: [TranscriptionSegment]? // Present in verbose_json
}


// MARK: - Transcription Service Protocol

protocol TranscriptionService {
    func transcribe(
        audioData: Data,
        fileName: String, // Required by multipart/form-data
        model: String,
        language: String?, // ISO-639-1 format
        prompt: String?,
        responseFormat: String?, // "json", "text", "verbose_json"
        temperature: Double?,
        timestampGranularities: [String]? // ["word", "segment"]
    ) async throws -> GroqTranscriptionResponse
}

enum TranscriptionError: Error, LocalizedError {
    case apiKeyMissing
    case invalidEndpoint
    case requestEncodingFailed(Error?)
    case networkError(Error)
    case apiError(statusCode: Int, message: String?)
    case decodingError(Error)
    case unknownError

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "Groq API key is missing. Please set it in settings."
        case .invalidEndpoint:
            return "Invalid API endpoint URL configured."
        case .requestEncodingFailed(let underlyingError):
            return "Failed to encode the transcription request. \(underlyingError?.localizedDescription ?? "")"
        case .networkError(let error):
            return "A network error occurred: \(error.localizedDescription)"
        case .apiError(let statusCode, let message):
            return "Groq API returned an error (Status \(statusCode)): \(message ?? "No additional details")"
        case .decodingError(let error):
            return "Failed to decode the API response: \(error.localizedDescription)"
        case .unknownError:
            return "An unknown error occurred during transcription."
        }
    }
}
