//
//  DictationManager.swift
//  OmriiOS
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  iOS-specific dictation manager with multi-provider support (cloud + Nemotron on-device)

import AVFoundation
import Foundation

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

@available(iOS 17.0, *)
@MainActor
class DictationManager {
    // Closure-based callbacks instead of delegate
    var onStartRecording: (() -> Void)?
    var onStopRecording: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onTranscriptionComplete: ((String) -> Void)?
    var onModelLoading: ((Bool) -> Void)?  // true = loading, false = done

    // Streaming callback (Nemotron real-time transcription); final text via onTranscriptionComplete
    var onVolatileText: ((String) -> Void)?

    private let audioRecorder = AudioRecorder()
    private var transcriptionService: TranscriptionService?
    private var parakeetManager: ParakeetTranscriptionManager?

    init() {
        audioRecorder.delegate = self
        updateTranscriptionService()
    }

    // MARK: - Configuration

    func updateTranscriptionService() {
        let provider = Settings.shared.transcriptionProvider

        // Handle Nemotron on-device transcription
        if provider == .parakeet {
            transcriptionService = nil
            if parakeetManager == nil {
                parakeetManager = ParakeetTranscriptionManager()
                parakeetManager?.delegate = self
            }
            return
        }

        // Apple on-device provider not supported on iOS yet
        if provider == .apple {
            transcriptionService = nil
            parakeetManager = nil
            return
        }

        // Cloud providers require API key
        guard let apiKey = Settings.shared.apiKey(for: provider), !apiKey.isEmpty else {
            transcriptionService = nil
            parakeetManager = nil
            return
        }

        // Create appropriate service based on provider
        parakeetManager = nil
        switch provider {
        case .groq:
            transcriptionService = GroqTranscriptionService(apiKey: apiKey)
        case .groqTranslations:
            transcriptionService = GroqTranscriptionService(apiKey: apiKey, translation: true)
        case .openai:
            transcriptionService = OpenAITranscriptionService(apiKey: apiKey)
        case .custom:
            let customURL = Settings.shared.customTranscriptionBaseURL
            transcriptionService = CustomTranscriptionService(apiKey: apiKey, baseURL: customURL)
        case .apple, .parakeet:
            transcriptionService = nil
        }
    }

    // MARK: - Public API

    var isRecording: Bool {
        return audioRecorder.recording
    }

    func startDictation() async throws {
        // Update service in case provider or settings changed
        updateTranscriptionService()

        // Handle Nemotron on-device transcription
        if let parakeet = parakeetManager {
            if !parakeet.isInitialized {
                try await parakeet.initializeModels()
            }
            _ = try await parakeet.startSession()
            Logger.log("Nemotron session started", context: "Dictation", level: .info)
            try await audioRecorder.startRecording()
            return
        }

        // Cloud providers require API key
        guard transcriptionService != nil else {
            throw DictationError.apiKeyMissing
        }

        try await audioRecorder.startRecording()
    }

    func stopDictation() async {
        // Handle Nemotron on-device transcription
        if let parakeet = parakeetManager {
            _ = await audioRecorder.stopRecordingAndGetBuffers()
            await parakeet.stopSession()
            return
        }

        // Cloud API transcription
        guard let audioData = await audioRecorder.stopRecording() else {
            onError?(DictationError.noAudioData)
            return
        }

        await performTranscription(with: audioData)
    }

    // MARK: - Transcription

    private func performTranscription(with audioData: Data) async {
        guard let service = transcriptionService else {
            onError?(DictationError.serviceNotConfigured)
            return
        }

        do {
            let selectedModel = Settings.shared.transcriptionModel
            let languageSetting = Settings.shared.transcriptionLanguage
            let language = languageSetting.isEmpty ? nil : languageSetting

            let response = try await service.transcribe(
                audioData: audioData,
                fileName: "recording.wav",
                model: selectedModel,
                language: language,
                prompt: nil,
                responseFormat: "json",
                temperature: nil,
                timestampGranularities: nil
            )

            let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                onError?(DictationError.emptyTranscription)
                return
            }

            Logger.log("Transcription complete - '\(text)'", context: "Dictation", level: .info)
            onTranscriptionComplete?(text)

        } catch let error as TranscriptionError {
            Logger.log("Transcription error - \(error.localizedDescription)", context: "Dictation", level: .error)
            onError?(error)
        } catch {
            Logger.log("Unexpected error - \(error.localizedDescription)", context: "Dictation", level: .error)
            onError?(DictationError.transcriptionFailed(error.localizedDescription))
        }
    }
}

// MARK: - Nemotron Transcription Delegate

extension DictationManager: ParakeetTranscriptionDelegate {
    func parakeet(didReceiveVolatileTranscription text: String) async {
        // Streaming mode: in-progress text that may change
        Logger.log("Nemotron volatile - '\(text)'", context: "Dictation", level: .debug)
        onVolatileText?(text)
    }

    func parakeet(didReceiveFinalTranscription text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onError?(DictationError.emptyTranscription)
            return
        }

        Logger.log("Nemotron transcription complete - '\(trimmed)'", context: "Dictation", level: .info)
        onTranscriptionComplete?(trimmed)
    }

    func parakeetWillDownloadModels() async {
        Logger.log("Nemotron downloading models...", context: "Dictation", level: .info)
        onModelLoading?(true)  // Show loading state
    }

    func parakeetDidDownloadModels() async {
        Logger.log("Nemotron models downloaded", context: "Dictation", level: .info)
        onModelLoading?(false)  // Hide loading state
    }

    func parakeet(didEncounterError error: ParakeetError) async {
        Logger.log("Nemotron error - \(error.localizedDescription)", context: "Dictation", level: .error)
        onError?(error)
    }
}

// MARK: - AudioRecorderDelegate

extension DictationManager: AudioRecorderDelegate {
    func audioRecorderDidStartRecording() {
        onStartRecording?()
    }

    func audioRecorderDidStopRecording() {
        onStopRecording?()
    }

    func audioRecorder(didReceiveError error: AudioRecorderError) {
        onError?(error)
    }

    func audioRecorder(didCompleteWithAudioData audioData: Data) {
        // Audio data handled in stopDictation()
    }

    func audioRecorder(didCaptureBuffer buffer: AVAudioPCMBuffer) {
        parakeetManager?.feedAudio(buffer)
    }
}

// MARK: - Errors

enum DictationError: LocalizedError {
    case apiKeyMissing
    case serviceNotConfigured
    case noAudioData
    case emptyTranscription
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "API key is required for the selected transcription provider. Please add it in Settings."
        case .serviceNotConfigured:
            return "Transcription service is not configured."
        case .noAudioData:
            return "No audio data was recorded."
        case .emptyTranscription:
            return "Transcription returned empty text."
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        }
    }
}
