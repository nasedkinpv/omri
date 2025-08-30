//
//  SettingsModel.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Core settings model extracted from SettingsViewController for better separation
//

import Foundation
import Combine

// MARK: - Notifications

extension Notification.Name {
    static let transcriptionApiChanged = Notification.Name("transcriptionApiChanged")
    static let transformationApiChanged = Notification.Name("transformationApiChanged")
    static let apiKeyChanged = Notification.Name("apiKeyChanged")
}

// MARK: - API Provider Enums

enum TranscriptionProvider: String, CaseIterable {
    case groq = "Groq"
    case groqTranslations = "Groq Translations"
    case openai = "OpenAI"

    var availableModels: [String] {
        switch self {
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
        }
    }

    var endpoint: String {
        switch self {
        case .groqTranslations: return "https://api.groq.com/openai/v1/audio/translations"
        case .groq: return "https://api.groq.com/openai/v1/audio/transcriptions"
        case .openai: return "https://api.openai.com/v1/audio/transcriptions"
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