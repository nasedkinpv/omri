//
//  SettingsModel.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Core settings model (shared between iOS and macOS)
//

import Foundation
import Combine

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

// MARK: - Notifications

extension Notification.Name {
    static let transcriptionApiChanged = Notification.Name("transcriptionApiChanged")
    static let transformationApiChanged = Notification.Name("transformationApiChanged")
    static let apiKeyChanged = Notification.Name("apiKeyChanged")
}

// MARK: - API Provider Enums

enum TranscriptionProvider: String, CaseIterable {
    case apple = "Apple (On-Device)"
    case parakeet = "Parakeet (On-Device)"
    case groq = "Groq"
    case groqTranslations = "Groq Translations"
    case openai = "OpenAI"
    case custom = "Custom (OpenAI Compatible)"

    var availableModels: [String] {
        switch self {
        case .apple:
            return ["On-Device Model"]
        case .parakeet:
            return ["parakeet-tdt-v3"]
        case .groq:
            return [
                "whisper-large-v3-turbo",
                "whisper-large-v3",
                "distil-whisper-large-v3-en",
            ]
        case .groqTranslations:
            return [
                "whisper-large-v3",
            ]
        case .openai:
            return [
                "whisper-1",
                "nova-1-whisper",
                "nova-1-whisper-en",
            ]
        case .custom:
            return ["whisper-1"] // Default, user can specify their own model
        }
    }

    var endpoint: String {
        switch self {
        case .apple, .parakeet: return ""
        case .groqTranslations: return "https://api.groq.com/openai/v1/audio/translations"
        case .groq: return "https://api.groq.com/openai/v1/audio/transcriptions"
        case .openai: return "https://api.openai.com/v1/audio/transcriptions"
        case .custom: return "" // Custom endpoint set via customTranscriptionBaseURL
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .apple, .parakeet: return false
        case .groq, .groqTranslations, .openai, .custom: return true
        }
    }

    var supportsCustomBaseURL: Bool {
        return self == .custom
    }

    var isOnDevice: Bool {
        return self == .apple || self == .parakeet
    }
}

enum TransformationProvider: String, CaseIterable {
    case groq = "Groq"
    case openai = "OpenAI"
    case custom = "OpenAI Compatible"

    var availableModels: [String] {
        switch self {
        case .groq:
            return [
                "llama-3.3-70b-versatile",
                "llama-3.1-8b-instant",
            ]
        case .openai:
            return [
                "gpt-5",
                "gpt-5-mini",
                "gpt-5-nano",
            ]
        case .custom:
            return ["gpt-oss-20b"] // Default placeholder, user inputs their own model name
        }
    }

    var endpoint: String {
        switch self {
        case .groq: return "https://api.groq.com/openai/v1/chat/completions"
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .custom: return "http://localhost:11434/v1/chat/completions"
        }
    }

    var requiresApiKey: Bool {
        switch self {
        case .groq, .openai: return true
        case .custom: return false
        }
    }

    var supportsCustomBaseURL: Bool {
        switch self {
        case .groq, .openai: return false
        case .custom: return true
        }
    }
}

// MARK: - Settings Class

class Settings: ObservableObject {
    static let shared = Settings()

    // MARK: - Transcription Settings

    @UserDefault("transcriptionProvider", defaultValue: TranscriptionProvider.groqTranslations.rawValue)
    var transcriptionProviderRaw: String {
        didSet {
            synchronizeChanges()
            NotificationCenter.default.post(name: .transcriptionApiChanged, object: nil)
            objectWillChange.send()

            // Auto-select first available model for new provider if current model is invalid
            if let provider = TranscriptionProvider(rawValue: transcriptionProviderRaw) {
                let availableModels = provider.availableModels
                if !availableModels.contains(transcriptionModel) {
                    transcriptionModel = availableModels.first ?? transcriptionModel
                    Logger.log("Auto-selected model '\(transcriptionModel)' for provider '\(provider.rawValue)'", context: "Settings", level: .info)
                }

                // Disable VAD for Apple (it has built-in speech detection)
                if provider == .apple && enableVAD {
                    enableVAD = false
                    Logger.log("Disabled VAD for Apple provider (has built-in speech detection)", context: "Settings", level: .info)
                }
            }
        }
    }

    var transcriptionProvider: TranscriptionProvider {
        get {
            if let provider = TranscriptionProvider(rawValue: transcriptionProviderRaw) {
                return provider
            }
            transcriptionProviderRaw = TranscriptionProvider.groq.rawValue
            return .groq
        }
        set {
            transcriptionProviderRaw = newValue.rawValue

            // Auto-select first available model for new provider if current model is invalid
            let availableModels = newValue.availableModels
            if !availableModels.contains(transcriptionModel) {
                transcriptionModel = availableModels.first ?? transcriptionModel
            }
        }
    }

    @UserDefault("transcriptionModel", defaultValue: "whisper-large-v3")
    var transcriptionModel: String {
        didSet {
            synchronizeChanges()
            objectWillChange.send()
        }
    }

    @UserDefault("transcriptionLanguage", defaultValue: "")  // Empty for auto-detect
    var transcriptionLanguage: String {
        didSet {
            synchronizeChanges()
            objectWillChange.send()
        }
    }

    // MARK: - Transformation Settings

    @UserDefault("enableAIProcessing", defaultValue: false)
    var enableAIProcessing: Bool {
        didSet {
            synchronizeChanges()
            objectWillChange.send()
        }
    }

    @UserDefault("transformationProvider", defaultValue: TransformationProvider.groq.rawValue)
    var transformationProviderRaw: String {
        didSet {
            synchronizeChanges()
            NotificationCenter.default.post(name: .transformationApiChanged, object: nil)
            objectWillChange.send()

            // Auto-select first available model for new provider if current model is invalid
            if let provider = TransformationProvider(rawValue: transformationProviderRaw) {
                let availableModels = provider.availableModels
                if !availableModels.contains(transformationModel) {
                    transformationModel = availableModels.first ?? transformationModel
                    Logger.log("Auto-selected transformation model '\(transformationModel)' for provider '\(provider.rawValue)'", context: "Settings", level: .info)
                }
            }
        }
    }

    var transformationProvider: TransformationProvider {
        get {
            if let provider = TransformationProvider(rawValue: transformationProviderRaw) {
                return provider
            }
            transformationProviderRaw = TransformationProvider.groq.rawValue
            return .groq
        }
        set {
            transformationProviderRaw = newValue.rawValue

            // Auto-select first available model for new provider if current model is invalid
            let availableModels = newValue.availableModels
            if !availableModels.contains(transformationModel) {
                transformationModel = availableModels.first ?? transformationModel
            }
        }
    }

    @UserDefault("transformationModel", defaultValue: "llama-3.1-8b-instant")
    var transformationModel: String {
        didSet {
            synchronizeChanges()
            objectWillChange.send()
        }
    }

    @UserDefault("transformationPrompt", defaultValue: Settings.defaultTransformationPrompt)
    var transformationPrompt: String {
        didSet {
            synchronizeChanges()
            objectWillChange.send()
        }
    }

    @UserDefault("customTransformationBaseURL", defaultValue: "http://localhost:11434/v1/chat/completions")
    var customTransformationBaseURL: String {
        didSet {
            synchronizeChanges()
            objectWillChange.send()
        }
    }

    @UserDefault("customTranscriptionBaseURL", defaultValue: "http://localhost:8000/v1/audio/transcriptions")
    var customTranscriptionBaseURL: String {
        didSet {
            synchronizeChanges()
            objectWillChange.send()
        }
    }

    static let defaultTransformationPrompt = """
        You are an expert text processor specialized in improving transcribed speech. Transform the following transcribed content by:

        • Removing filler words, false starts, and speech artifacts (um, uh, like, you know, etc.)
        • Correcting transcription errors and improving clarity
        • Maintaining the speaker's original meaning and intent
        • Adjusting formatting and structure for readability
        • Making the text more polished while preserving the natural tone

        Return only the improved text without any additional commentary.

        Transcribed content:
        {transcribed_text}
        """

    func processedTransformationPrompt(for transcribedText: String) -> String {
        return transformationPrompt.replacingOccurrences(of: "{transcribed_text}", with: transcribedText)
    }

    func resetTransformationPromptToDefault() {
        transformationPrompt = Self.defaultTransformationPrompt
    }

    @UserDefault("startAtLogin", defaultValue: false)
    var startAtLogin: Bool {
        didSet {
            objectWillChange.send()
        }
    }

    // MARK: - VAD Settings

    @UserDefault("enableVAD", defaultValue: false)
    var enableVAD: Bool {
        didSet {
            synchronizeChanges()
            objectWillChange.send()
        }
    }

    @UserDefault("vadSensitivity", defaultValue: 0.5)
    var vadSensitivity: Double {
        didSet {
            synchronizeChanges()
            objectWillChange.send()

            // Update AudioManager with new VAD sensitivity (macOS only)
            #if os(macOS)
            Task { @MainActor in
                AppDelegate.shared?.getAudioManager()?.updateVADSensitivity()
            }
            #endif
        }
    }

    @UserDefault("vadMinSpeechDuration", defaultValue: 0.25)
    var vadMinSpeechDuration: Double {
        didSet {
            synchronizeChanges()
            objectWillChange.send()

            // Update AudioManager with new VAD timing parameters (macOS only)
            #if os(macOS)
            Task { @MainActor in
                AppDelegate.shared?.getAudioManager()?.updateVADTimingParameters()
            }
            #endif
        }
    }

    @UserDefault("vadSilenceTimeout", defaultValue: 1.0)
    var vadSilenceTimeout: Double {
        didSet {
            synchronizeChanges()
            objectWillChange.send()

            // Update AudioManager with new VAD timing parameters (macOS only)
            #if os(macOS)
            Task { @MainActor in
                AppDelegate.shared?.getAudioManager()?.updateVADTimingParameters()
            }
            #endif
        }
    }

    // MARK: - API Key Management (Keychain-based)

    func apiKey<T>(for provider: T) -> String? where T: RawRepresentable, T.RawValue == String {
        return KeychainManager.shared.retrieve(key: "\(provider.rawValue)APIKey")
    }

    func setApiKey<T>(_ key: String?, for provider: T)
    where T: RawRepresentable, T.RawValue == String {
        let keychainKey = "\(provider.rawValue)APIKey"
        if let key = key {
            _ = KeychainManager.shared.save(key: keychainKey, value: key)
            NotificationCenter.default.post(name: .apiKeyChanged, object: provider)
        } else {
            _ = KeychainManager.shared.delete(key: keychainKey)
            NotificationCenter.default.post(name: .apiKeyChanged, object: provider)
        }
        objectWillChange.send()
    }

    private func synchronizeChanges() {
        UserDefaults.standard.synchronize()
    }
}

// MARK: - UserDefault Property Wrapper

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T

    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get {
            return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}
