//
//  TransformationService.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//
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

// Common transformation error types
enum TransformationError: Error, LocalizedError, Equatable {
    case apiKeyMissing
    case invalidResponse
    case requestFailed(Error)
    case apiError(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "API key is missing. Get your API key at:\n• OpenAI: https://platform.openai.com/api-keys\n• Groq: https://console.groq.com/keys"
        case .invalidResponse:
            return "Received an invalid response from the server."
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
        case (.apiError(let lhsCode, let lhsMsg), .apiError(let rhsCode, let rhsMsg)):
            return lhsCode == rhsCode && lhsMsg == rhsMsg
        case (.requestFailed, .requestFailed):
            // Can't compare errors directly, so just check if they're both requestFailed
            return true
        default:
            return false
        }
    }
}

// MARK: - Groq Implementation

class GroqTransformationService: BaseHTTPService, TransformationService {
    init(apiKey: String) {
        super.init(apiKey: apiKey, endpoint: "https://api.groq.com/openai/v1/chat/completions")
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

        var request = createBaseRequest()
        
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

        } catch let error as TransformationError {
            throw error
        } catch {
            throw TransformationError.requestFailed(error)
        }
    }
}

// MARK: - OpenAI Implementation

class OpenAITransformationService: BaseHTTPService, TransformationService {
    init(apiKey: String) {
        super.init(apiKey: apiKey, endpoint: "https://api.openai.com/v1/chat/completions")
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

        var request = createBaseRequest()
        
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

        } catch let error as TransformationError {
            throw error
        } catch {
            throw TransformationError.requestFailed(error)
        }
    }
}

// MARK: - Custom/OpenAI Compatible Implementation

class CustomTransformationService: BaseHTTPService, TransformationService {
    init(apiKey: String, baseURL: String) {
        super.init(apiKey: apiKey, endpoint: baseURL)
    }

    func transform(
        text: String,
        prompt: String,
        model: String,
        temperature: Double? = 0.7
    ) async throws -> String {
        var request = createBaseRequest()
        
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

        } catch let error as TransformationError {
            throw error
        } catch {
            throw TransformationError.requestFailed(error)
        }
    }
}

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
