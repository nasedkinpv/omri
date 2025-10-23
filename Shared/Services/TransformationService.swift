//
//  TransformationService.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Protocol and implementations for AI text transformation services
//

import Foundation

protocol TransformationService {
    func transform(
        text: String,
        prompt: String,
        model: String,
        temperature: Double?
    ) async throws -> String
}

// MARK: - Error Types

enum TransformationError: Error, LocalizedError, Equatable {
    case apiKeyMissing
    case invalidResponse
    case invalidEndpoint
    case requestFailed(Error)
    case apiError(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "API key is missing. Get your API key at:\n• OpenAI: https://platform.openai.com/api-keys\n• Groq: https://console.groq.com/keys"
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .invalidEndpoint:
            return "Invalid API endpoint URL configured."
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .apiError(let statusCode, let message):
            return "API error (Status \(statusCode)): \(message ?? "No additional details")"
        }
    }

    static func == (lhs: TransformationError, rhs: TransformationError) -> Bool {
        switch (lhs, rhs) {
        case (.apiKeyMissing, .apiKeyMissing):
            return true
        case (.invalidResponse, .invalidResponse):
            return true
        case (.invalidEndpoint, .invalidEndpoint):
            return true
        case (.apiError(let lhsCode, let lhsMsg), .apiError(let rhsCode, let rhsMsg)):
            return lhsCode == rhsCode && lhsMsg == rhsMsg
        case (.requestFailed, .requestFailed):
            return true
        default:
            return false
        }
    }

    // Helper to convert HTTPError to TransformationError
    init(from httpError: HTTPError) {
        switch httpError {
        case .invalidEndpoint:
            self = .invalidEndpoint
        case .invalidResponse:
            self = .invalidResponse
        case .apiError(let statusCode, let message):
            self = .apiError(statusCode: statusCode, message: message)
        }
    }
}

// MARK: - Unified Implementation

/// Unified transformation service supporting OpenAI, Groq, and custom endpoints
class UnifiedTransformationService: BaseHTTPService, TransformationService {

    override init(apiKey: String, endpoint: String) {
        super.init(apiKey: apiKey, endpoint: endpoint)
    }

    /// Convenience initializers for specific providers
    static func groq(apiKey: String) -> UnifiedTransformationService {
        UnifiedTransformationService(apiKey: apiKey, endpoint: "https://api.groq.com/openai/v1/chat/completions")
    }

    static func openAI(apiKey: String) -> UnifiedTransformationService {
        UnifiedTransformationService(apiKey: apiKey, endpoint: "https://api.openai.com/v1/chat/completions")
    }

    static func custom(apiKey: String, baseURL: String) -> UnifiedTransformationService {
        UnifiedTransformationService(apiKey: apiKey, endpoint: baseURL)
    }

    func transform(
        text: String,
        prompt: String,
        model: String,
        temperature: Double? = 0.7
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw TransformationError.apiKeyMissing
        }

        var request = try createBaseRequest()

        // Use centralized model configuration system
        let requestBody = ModelConfigurationManager.shared.buildRequestParameters(
            for: model,
            prompt: prompt,
            requestedTemperature: temperature
        )

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try handleHTTPResponse(data, response)

            guard let responseJson = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data),
                  let content = responseJson.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) else {
                throw TransformationError.invalidResponse
            }

            return content

        } catch let error as HTTPError {
            throw TransformationError(from: error)
        } catch let error as TransformationError {
            throw error
        } catch {
            throw TransformationError.requestFailed(error)
        }
    }
}

// MARK: - Legacy Type Aliases (for backward compatibility)

typealias GroqTransformationService = UnifiedTransformationService
typealias OpenAITransformationService = UnifiedTransformationService
typealias CustomTransformationService = UnifiedTransformationService

// MARK: - Response Models

struct ChatCompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]

    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Message: Codable {
        let role: String
        let content: String
    }
}
