//
//  DictationManager.swift
//  OmriiOS
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  iOS-specific dictation manager with multi-provider support (cloud + Parakeet on-device)
//  Supports Parakeet streaming mode for real-time transcription

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

    // Streaming mode callbacks (Parakeet real-time transcription)
    var onVolatileText: ((String) -> Void)?      // In-progress text (may change)
    var onConfirmedText: ((String) -> Void)?     // Stable text (won't change)

    private let audioRecorder = AudioRecorder()
    private var transcriptionService: TranscriptionService?
    private var parakeetManager: ParakeetTranscriptionManager?

    // Streaming mode state
    private var isStreamingMode = false
    private var accumulatedConfirmedText = ""

    init() {
        audioRecorder.delegate = self
        updateTranscriptionService()
    }

    // MARK: - Configuration

    func updateTranscriptionService() {
        let provider = Settings.shared.transcriptionProvider

        // Handle Parakeet on-device transcription
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

        // Handle Parakeet on-device transcription
        if let parakeet = parakeetManager {
            // Initialize models if needed (only once, downloads on first use)
            if !parakeet.isInitialized {
                try await parakeet.initializeModels()
            }

            // Check if streaming mode is enabled
            isStreamingMode = Settings.shared.enableVAD  // VAD toggle = streaming mode for Parakeet
            accumulatedConfirmedText = ""

            // Start Parakeet session (streaming or batch)
            if isStreamingMode {
                // Streaming mode: StreamingAsrManager handles its own microphone capture
                _ = try await parakeet.startStreamingSession()
                Logger.log("Parakeet streaming session started", context: "Dictation", level: .info)
                // Don't start audioRecorder - StreamingAsrManager uses source: .microphone
                return
            } else {
                // Batch mode: We capture audio and feed it to Parakeet
                _ = try await parakeet.startSession()
                Logger.log("Parakeet batch session started", context: "Dictation", level: .info)
                try await audioRecorder.startRecording()
                return
            }
        }

        // Cloud providers require API key
        guard transcriptionService != nil else {
            throw DictationError.apiKeyMissing
        }

        try await audioRecorder.startRecording()
    }

    func stopDictation() async {
        // Handle Parakeet on-device transcription
        if let parakeet = parakeetManager {
            if isStreamingMode {
                // Streaming mode: Just stop the session (StreamingAsrManager handles its own audio)
                // Final text is delivered via delegate callback
                Logger.log("Stopping Parakeet streaming session", context: "Dictation", level: .info)
                await parakeet.stopSession()
                isStreamingMode = false
                return
            } else {
                // Batch mode: Stop recording and feed buffers to Parakeet
                let (buffers, _) = await audioRecorder.stopRecordingAndGetBuffers()

                guard !buffers.isEmpty else {
                    onError?(DictationError.noAudioData)
                    return
                }

                // Feed buffers to Parakeet
                for buffer in buffers {
                    parakeet.feedAudio(buffer)
                }

                // Stop Parakeet session (triggers transcription and delegate callback)
                await parakeet.stopSession()
                return
            }
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

// MARK: - ParakeetTranscriptionDelegate

extension DictationManager: ParakeetTranscriptionDelegate {
    func parakeet(didReceivePartialTranscription text: String) async {
        // Batch mode partial transcriptions (not used in streaming)
        Logger.log("Parakeet partial - '\(text)'", context: "Dictation", level: .debug)
    }

    func parakeet(didReceiveVolatileTranscription text: String) async {
        // Streaming mode: in-progress text that may change
        Logger.log("Parakeet volatile - '\(text)'", context: "Dictation", level: .debug)
        onVolatileText?(text)
    }

    func parakeet(didReceiveConfirmedTranscription text: String) async {
        // Streaming mode: stable text that won't change
        // Note: Send only the new increment (text parameter), not accumulated
        Logger.log("Parakeet confirmed increment - '\(text)'", context: "Dictation", level: .info)
        accumulatedConfirmedText += text
        onConfirmedText?(text)  // Send just the increment for terminal input
    }

    func parakeet(didReceiveFinalTranscription text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onError?(DictationError.emptyTranscription)
            return
        }

        Logger.log("Parakeet transcription complete - '\(trimmed)'", context: "Dictation", level: .info)
        onTranscriptionComplete?(trimmed)
    }

    func parakeetWillDownloadModels() async {
        Logger.log("Parakeet downloading models...", context: "Dictation", level: .info)
        onModelLoading?(true)  // Show loading state
    }

    func parakeetDidDownloadModels() async {
        Logger.log("Parakeet models downloaded", context: "Dictation", level: .info)
        onModelLoading?(false)  // Hide loading state
    }

    func parakeet(didEncounterError error: ParakeetError) async {
        Logger.log("Parakeet error - \(error.localizedDescription)", context: "Dictation", level: .error)
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
