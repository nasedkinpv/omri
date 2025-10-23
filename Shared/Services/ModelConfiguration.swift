//
//  ModelConfiguration.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Centralized model configuration system for API parameters
//

import Foundation

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

// MARK: - Model Type

enum ModelType {
    case transcription
    case transformation
}

// MARK: - Model Configuration Protocol

protocol ModelConfigurable {
    var modelType: ModelType { get }
    var supportsTemperature: Bool { get }
    var supportsReasoning: Bool { get }
    var supportsLanguage: Bool { get }
    var supportsPrompt: Bool { get }
    var supportsTimestamps: Bool { get }
    var defaultTemperature: Double? { get }
    var defaultResponseFormat: String { get }
    var maxTokens: Int? { get }  // Optional for transcription models
    var additionalParameters: [String: Any] { get }
}

// MARK: - Model Configuration Implementation

struct ModelConfiguration: ModelConfigurable {
    let modelType: ModelType
    let supportsTemperature: Bool
    let supportsReasoning: Bool
    let supportsLanguage: Bool
    let supportsPrompt: Bool
    let supportsTimestamps: Bool
    let defaultTemperature: Double?
    let defaultResponseFormat: String
    let maxTokens: Int?
    let additionalParameters: [String: Any]
    
    // Transformation model initializer
    init(
        supportsTemperature: Bool = true,
        supportsReasoning: Bool = false,
        defaultTemperature: Double? = 0.7,
        maxTokens: Int = 1024,
        additionalParameters: [String: Any] = [:]
    ) {
        self.modelType = .transformation
        self.supportsTemperature = supportsTemperature
        self.supportsReasoning = supportsReasoning
        self.supportsLanguage = false
        self.supportsPrompt = false
        self.supportsTimestamps = false
        self.defaultTemperature = defaultTemperature
        self.defaultResponseFormat = "json"
        self.maxTokens = maxTokens
        self.additionalParameters = additionalParameters
    }
    
    // Transcription model initializer
    init(
        transcription: Bool,
        supportsLanguage: Bool = true,
        supportsPrompt: Bool = true,
        supportsTimestamps: Bool = true,
        supportsTemperature: Bool = false,
        defaultResponseFormat: String = "json",
        additionalParameters: [String: Any] = [:]
    ) {
        self.modelType = .transcription
        self.supportsTemperature = supportsTemperature
        self.supportsReasoning = false
        self.supportsLanguage = supportsLanguage
        self.supportsPrompt = supportsPrompt
        self.supportsTimestamps = supportsTimestamps
        self.defaultTemperature = supportsTemperature ? 0.0 : nil
        self.defaultResponseFormat = defaultResponseFormat
        self.maxTokens = nil
        self.additionalParameters = additionalParameters
    }
}

// MARK: - Model Configuration Manager

class ModelConfigurationManager {
    static let shared = ModelConfigurationManager()
    
    private let configurations: [String: ModelConfiguration] = [
        // MARK: - Transformation Models
        
        // OpenAI Transformation Models
        "gpt-5": ModelConfiguration(
            supportsTemperature: false,
            supportsReasoning: true,
            defaultTemperature: nil,
            maxTokens: 1024,
            additionalParameters: ["reasoning": ["effort": "minimal"]]
        ),
        "gpt-5-mini": ModelConfiguration(
            supportsTemperature: false,
            supportsReasoning: true,
            defaultTemperature: nil,
            maxTokens: 1024,
            additionalParameters: ["reasoning": ["effort": "minimal"]]
        ),
        "gpt-5-nano": ModelConfiguration(
            supportsTemperature: false,
            supportsReasoning: true,
            defaultTemperature: nil,
            maxTokens: 1024,
            additionalParameters: ["reasoning": ["effort": "minimal"]]
        ),
        
        // Groq Transformation Models
        "llama-3.3-70b-versatile": ModelConfiguration(
            supportsTemperature: true,
            supportsReasoning: false,
            defaultTemperature: 0.7,
            maxTokens: 1024,
            additionalParameters: ["stream": false]
        ),
        "llama-3.1-8b-instant": ModelConfiguration(
            supportsTemperature: true,
            supportsReasoning: false,
            defaultTemperature: 0.7,
            maxTokens: 1024,
            additionalParameters: ["stream": false]
        ),
        
        // MARK: - Transcription Models
        
        // OpenAI Transcription Models
        "whisper-1": ModelConfiguration(
            transcription: true,
            supportsLanguage: true,
            supportsPrompt: true,
            supportsTimestamps: true,
            supportsTemperature: false,
            defaultResponseFormat: "json"
        ),
        "nova-1-whisper": ModelConfiguration(
            transcription: true,
            supportsLanguage: true,
            supportsPrompt: true,
            supportsTimestamps: true,
            supportsTemperature: false,
            defaultResponseFormat: "json"
        ),
        "nova-1-whisper-en": ModelConfiguration(
            transcription: true,
            supportsLanguage: false, // English-only model
            supportsPrompt: true,
            supportsTimestamps: true,
            supportsTemperature: false,
            defaultResponseFormat: "json"
        ),
        
        // Groq Transcription Models
        "whisper-large-v3-turbo": ModelConfiguration(
            transcription: true,
            supportsLanguage: true,
            supportsPrompt: true,
            supportsTimestamps: true,
            supportsTemperature: false,
            defaultResponseFormat: "json"
        ),
        "whisper-large-v3": ModelConfiguration(
            transcription: true,
            supportsLanguage: true,
            supportsPrompt: true,
            supportsTimestamps: true,
            supportsTemperature: false,
            defaultResponseFormat: "verbose_json"
        ),
        "distil-whisper-large-v3-en": ModelConfiguration(
            transcription: true,
            supportsLanguage: false, // English-only model
            supportsPrompt: true,
            supportsTimestamps: true,
            supportsTemperature: false,
            defaultResponseFormat: "json"
        )
    ]
    
    private let defaultTransformationConfiguration = ModelConfiguration(
        supportsTemperature: true,
        supportsReasoning: false,
        defaultTemperature: 0.7,
        maxTokens: 1024
    )
    
    private let defaultTranscriptionConfiguration = ModelConfiguration(
        transcription: true,
        supportsLanguage: true,
        supportsPrompt: true,
        supportsTimestamps: true,
        supportsTemperature: false,
        defaultResponseFormat: "json"
    )
    
    private init() {}
    
    /// Get configuration for a specific model
    func configuration(for model: String) -> ModelConfiguration {
        if let config = configurations[model] {
            return config
        }
        // Return appropriate default based on model name patterns
        if isTranscriptionModel(model) {
            return defaultTranscriptionConfiguration
        }
        return defaultTransformationConfiguration
    }
    
    /// Build transformation request parameters
    func buildRequestParameters(
        for model: String,
        prompt: String,
        requestedTemperature: Double? = nil
    ) -> [String: Any] {
        let config = configuration(for: model)
        guard config.modelType == .transformation else {
            Logger.log("buildRequestParameters called with transcription model: \(model), using fallback", context: "ModelConfig", level: .warning)
            return buildFallbackTransformationParameters(model: model, prompt: prompt, temperature: requestedTemperature)
        }
        
        var parameters: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        // Add max tokens if specified
        if let maxTokens = config.maxTokens {
            parameters["max_completion_tokens"] = maxTokens
        }
        
        // Add temperature if supported
        if config.supportsTemperature {
            parameters["temperature"] = requestedTemperature ?? config.defaultTemperature ?? 0.7
        }
        
        // Add additional model-specific parameters
        for (key, value) in config.additionalParameters {
            parameters[key] = value
        }
        
        return parameters
    }
    
    /// Build transcription request parameters
    func buildTranscriptionParameters(
        for model: String,
        language: String? = nil,
        prompt: String? = nil,
        responseFormat: String? = nil,
        temperature: Double? = nil,
        timestampGranularities: [String]? = nil
    ) -> ([String: CustomStringConvertible], [String: [String]]) {
        let config = configuration(for: model)
        guard config.modelType == .transcription else {
            Logger.log("buildTranscriptionParameters called with transformation model: \(model), using fallback", context: "ModelConfig", level: .warning)
            return buildFallbackTranscriptionParameters(model: model, language: language, prompt: prompt, responseFormat: responseFormat, temperature: temperature, timestampGranularities: timestampGranularities)
        }
        
        var parameters: [String: CustomStringConvertible] = [
            "model": model,
            "response_format": responseFormat ?? config.defaultResponseFormat
        ]
        
        // Add language if supported and provided
        if config.supportsLanguage, let language = language {
            parameters["language"] = language
        }
        
        // Add prompt if supported and provided
        if config.supportsPrompt, let prompt = prompt {
            parameters["prompt"] = prompt
        }
        
        // Add temperature if supported and provided
        if config.supportsTemperature, let temperature = temperature {
            parameters["temperature"] = temperature
        }
        
        // Handle timestamp granularities as array parameter
        var arrayParams: [String: [String]] = [:]
        if config.supportsTimestamps, let granularities = timestampGranularities, !granularities.isEmpty {
            arrayParams["timestamp_granularities"] = granularities
        }
        
        // Add additional model-specific parameters
        for (key, value) in config.additionalParameters {
            if let stringValue = value as? CustomStringConvertible {
                parameters[key] = stringValue
            }
        }
        
        return (parameters, arrayParams)
    }
    
    /// Check if a model supports a specific feature
    func modelSupports(_ feature: ModelFeature, for model: String) -> Bool {
        let config = configuration(for: model)
        switch feature {
        case .temperature:
            return config.supportsTemperature
        case .reasoning:
            return config.supportsReasoning
        case .language:
            return config.supportsLanguage
        case .prompt:
            return config.supportsPrompt
        case .timestamps:
            return config.supportsTimestamps
        }
    }
}

// MARK: - Model Features

enum ModelFeature {
    case temperature
    case reasoning
    case language
    case prompt
    case timestamps
}

// MARK: - Convenience Extensions

extension ModelConfigurationManager {
    /// Quick check if model is a GPT-5 series model
    func isGPT5Model(_ model: String) -> Bool {
        return model.hasPrefix("gpt-5")
    }
    
    /// Quick check if model is a Groq model
    func isGroqModel(_ model: String) -> Bool {
        return model.contains("llama") || model.contains("groq")
    }
    
    /// Quick check if model is a transcription model
    func isTranscriptionModel(_ model: String) -> Bool {
        return model.contains("whisper") || model.contains("nova-1-whisper")
    }
    
    /// Quick check if model is a transformation model
    func isTransformationModel(_ model: String) -> Bool {
        return model.contains("gpt") || model.contains("llama")
    }
    
    /// Fallback transformation parameters for unconfigured models
    private func buildFallbackTransformationParameters(
        model: String,
        prompt: String,
        temperature: Double?
    ) -> [String: Any] {
        return [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "temperature": temperature ?? 0.7,
            "max_completion_tokens": 1024
        ]
    }
    
    /// Fallback transcription parameters for unconfigured models
    private func buildFallbackTranscriptionParameters(
        model: String,
        language: String?,
        prompt: String?,
        responseFormat: String?,
        temperature: Double?,
        timestampGranularities: [String]?
    ) -> ([String: CustomStringConvertible], [String: [String]]) {
        var parameters: [String: CustomStringConvertible] = [
            "model": model,
            "response_format": responseFormat ?? "json"
        ]
        
        if let language = language { parameters["language"] = language }
        if let prompt = prompt { parameters["prompt"] = prompt }
        if let temperature = temperature { parameters["temperature"] = temperature }
        
        var arrayParams: [String: [String]] = [:]
        if let granularities = timestampGranularities {
            arrayParams["timestamp_granularities"] = granularities
        }
        
        return (parameters, arrayParams)
    }
}