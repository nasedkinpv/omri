//
//  ParakeetTranscriptionManager.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Manages Parakeet CoreML transcription for on-device multilingual ASR
//  Cross-platform: macOS 14+ and iOS 17+
//
//  Supports two modes:
//  - Batch mode: Collects all audio, transcribes at end (fastest for short recordings)
//  - Streaming mode: Uses FluidAudio's StreamingAsrManager for true real-time transcription
//    with volatile (in-progress) and confirmed text updates
//

import Foundation
import AVFAudio
import FluidAudio

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

@available(macOS 14.0, iOS 17.0, *)
@MainActor
class ParakeetTranscriptionManager: OnDeviceTranscriptionManager {
    // MARK: - Properties

    private var asrManager: AsrManager?
    private var models: AsrModels?
    private var isActive = false
    private var audioFormat: AVAudioFormat?

    // Buffer collection for batch transcription
    private var audioBuffers: [AVAudioPCMBuffer] = []

    // Streaming mode components
    private var streamingManager: StreamingAsrManager?
    private var streamingTask: Task<Void, Never>?
    private var isStreamingMode = false

    weak var delegate: ParakeetTranscriptionDelegate?

    // MARK: - Lifecycle

    init() {}

    // MARK: - Status

    /// Check if models are initialized and ready for transcription
    var isInitialized: Bool {
        return asrManager != nil
    }

    // MARK: - Model Management

    /// Initialize Parakeet models (downloads if needed)
    func initializeModels() async throws {
        Logger.log("Initializing models...", context: "Parakeet", level: .info)

        // Notify delegate about potential download
        await delegate?.parakeetWillDownloadModels()

        // Download and load models (cached after first download)
        let models = try await AsrModels.downloadAndLoad()
        self.models = models

        Logger.log("Models loaded successfully", context: "Parakeet", level: .info)
        await delegate?.parakeetDidDownloadModels()

        // Initialize ASR manager with default configuration
        let asrManager = AsrManager()
        try await asrManager.initialize(models: models)
        self.asrManager = asrManager

        Logger.log("ASR Manager initialized", context: "Parakeet", level: .info)
    }

    /// Check if models are already downloaded
    func areModelsDownloaded() async -> Bool {
        // FluidAudio caches models, so we can check by attempting to load
        do {
            let _ = try await AsrModels.downloadAndLoad()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Session Management

    /// Start a batch transcription session
    /// - Parameter locale: Language locale (ignored - Parakeet detects language automatically)
    /// - Returns: The recommended audio format (16kHz mono Float32)
    func startSession(locale: Locale = .current) async throws -> AVAudioFormat {
        guard !isActive else {
            Logger.log("Session already active", context: "Parakeet", level: .warning)
            throw ParakeetError.sessionAlreadyActive
        }

        guard asrManager != nil else {
            throw ParakeetError.modelsNotInitialized
        }

        // Parakeet expects 16kHz mono Float32 PCM
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw ParakeetError.audioFormatCreationFailed
        }

        self.audioFormat = format
        audioBuffers.removeAll()
        isStreamingMode = false
        isActive = true

        Logger.log("Batch session started - 16kHz mono Float32", context: "Parakeet", level: .info)
        return format
    }

    // MARK: - Streaming Mode

    /// Start a streaming transcription session with real-time volatile/confirmed updates
    /// - Parameter locale: Language locale (ignored - Parakeet detects language automatically)
    /// - Returns: The recommended audio format (16kHz mono Float32)
    func startStreamingSession(locale: Locale = .current) async throws -> AVAudioFormat {
        guard !isActive else {
            Logger.log("Session already active", context: "Parakeet", level: .warning)
            throw ParakeetError.sessionAlreadyActive
        }

        guard let models = models else {
            throw ParakeetError.modelsNotInitialized
        }

        // Create streaming manager with ultra-low-latency config for real-time feedback
        // Key insight: rightContextSeconds is the main latency driver (lookahead buffer)
        // FluidAudio defaults: chunk=11s, hypothesis=1s, left=2s, right=2s, threshold=0.80
        let ultraLowLatencyConfig = StreamingAsrConfig(
            chunkSeconds: 3.0,              // 3s chunks (balance speed vs accuracy)
            hypothesisChunkSeconds: 0.5,    // 500ms volatile updates for quick feedback
            leftContextSeconds: 2.0,        // Keep left context for accuracy
            rightContextSeconds: 0.5,       // Reduced lookahead: 2s → 0.5s saves ~1.5s latency
            confirmationThreshold: 0.70     // Lower threshold for faster confirmation
        )
        let manager = StreamingAsrManager(config: ultraLowLatencyConfig)

        // Start with pre-loaded models
        try await manager.start(models: models, source: .microphone)

        self.streamingManager = manager
        self.isStreamingMode = true
        self.isActive = true

        // Start listening for transcription updates
        // Note: We need to capture the stream reference within the actor context
        let updates = await manager.transcriptionUpdates

        streamingTask = Task { [weak self] in
            guard let self = self else { return }

            for await update in updates {
                guard !Task.isCancelled else { break }

                if update.isConfirmed {
                    Logger.log("Confirmed: '\(update.text)' (conf: \(String(format: "%.2f", update.confidence)))", context: "Parakeet", level: .info)
                    await self.delegate?.parakeet(didReceiveConfirmedTranscription: update.text)
                } else {
                    Logger.log("Volatile: '\(update.text)' (conf: \(String(format: "%.2f", update.confidence)))", context: "Parakeet", level: .debug)
                    await self.delegate?.parakeet(didReceiveVolatileTranscription: update.text)
                }
            }
        }

        // Parakeet expects 16kHz mono Float32 PCM
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw ParakeetError.audioFormatCreationFailed
        }

        self.audioFormat = format
        Logger.log("Streaming session started - 16kHz mono Float32", context: "Parakeet", level: .info)
        return format
    }

    /// Feed an audio buffer to the transcription pipeline
    /// - Parameter buffer: Audio buffer in 16kHz mono Float32 format
    func feedAudio(_ buffer: AVAudioPCMBuffer) {
        guard isActive else {
            Logger.log("Cannot feed audio - session not active", context: "Parakeet", level: .warning)
            return
        }

        if isStreamingMode {
            // Streaming mode: feed directly to StreamingAsrManager
            // StreamingAsrManager is an actor, so we need to call from a Task
            Task {
                await streamingManager?.streamAudio(buffer)
            }
        } else {
            // Batch mode: collect buffers for processing at end
            audioBuffers.append(buffer)
        }
    }

    /// Stop the current transcription session and process collected audio
    /// - Returns: Final transcription text (for streaming mode) or nil (for batch mode which uses delegate)
    @discardableResult
    func stopSession() async -> String? {
        guard isActive else { return nil }

        if isStreamingMode {
            // Streaming mode: finish and get final text
            Logger.log("Stopping streaming session", context: "Parakeet", level: .info)

            // Cancel the update listener task
            streamingTask?.cancel()
            streamingTask = nil

            // Get final transcription from streaming manager
            var finalText: String?
            if let manager = streamingManager {
                do {
                    finalText = try await manager.finish()
                    Logger.log("Streaming session finished: '\(finalText ?? "")'", context: "Parakeet", level: .info)

                    // Send final result to delegate
                    if let text = finalText, !text.isEmpty {
                        await delegate?.parakeet(didReceiveFinalTranscription: text)
                    }
                } catch {
                    Logger.log("Streaming finish error: \(error.localizedDescription)", context: "Parakeet", level: .error)
                    await delegate?.parakeet(didEncounterError: .transcriptionFailed(error.localizedDescription))
                }
            }

            streamingManager = nil
            cleanup()
            return finalText
        } else {
            // Batch mode: process collected audio
            Logger.log("Stopping batch session, processing \(audioBuffers.count) buffers", context: "Parakeet", level: .info)

            // Convert buffers to Float array for FluidAudio
            guard let audioSamples = pcmBuffersToFloatArray(buffers: audioBuffers, format: audioFormat) else {
                Logger.log("Failed to convert audio buffers", context: "Parakeet", level: .error)
                await delegate?.parakeet(didEncounterError: .audioProcessingFailed("Failed to convert audio buffers"))
                cleanup()
                return nil
            }

            let duration = Double(audioSamples.count) / 16000.0
            Logger.log("Transcribing \(audioSamples.count) samples (\(String(format: "%.2f", duration))s)", context: "Parakeet", level: .info)

            // Perform transcription
            await transcribeAudio(samples: audioSamples)

            cleanup()
            return nil
        }
    }

    // MARK: - Transcription

    /// Transcribe a single audio chunk for streaming mode (VAD integration)
    /// - Parameter samples: Float32 audio samples at 16kHz
    /// - Returns: Transcribed text, or nil if transcription failed
    func transcribeChunk(_ samples: [Float]) async -> String? {
        guard let asrManager = asrManager else {
            Logger.log("Cannot transcribe chunk - models not initialized", context: "Parakeet", level: .error)
            await delegate?.parakeet(didEncounterError: .modelsNotInitialized)
            return nil
        }

        // Skip very short chunks (less than 0.5s might not transcribe well)
        let duration = Double(samples.count) / 16000.0
        guard duration >= 0.5 else {
            Logger.log("Chunk too short (\(String(format: "%.2f", duration))s), skipping", context: "Parakeet", level: .debug)
            return nil
        }

        do {
            let result = try await asrManager.transcribe(samples, source: .system)
            let transcribedText = result.text

            guard !transcribedText.isEmpty else {
                Logger.log("Chunk transcription returned empty text", context: "Parakeet", level: .debug)
                return nil
            }

            Logger.log("Chunk transcribed - '\(transcribedText)' (\(String(format: "%.2f", duration))s, confidence: \(result.confidence))", context: "Parakeet", level: .debug)

            // Send partial result to delegate
            await delegate?.parakeet(didReceivePartialTranscription: transcribedText)

            return transcribedText

        } catch {
            Logger.log("Chunk transcription error - \(error.localizedDescription)", context: "Parakeet", level: .error)
            return nil
        }
    }

    private func transcribeAudio(samples: [Float]) async {
        guard let asrManager = asrManager else {
            await delegate?.parakeet(didEncounterError: .modelsNotInitialized)
            return
        }

        do {
            // Transcribe with FluidAudio AsrManager
            // Note: FluidAudio expects RandomAccessCollection<Float>, [Float] conforms to this
            let result = try await asrManager.transcribe(samples, source: .system)

            let transcribedText = result.text
            Logger.log("Transcription complete - '\(transcribedText)' (confidence: \(result.confidence))", context: "Parakeet", level: .info)

            // Send final result to delegate
            await delegate?.parakeet(didReceiveFinalTranscription: transcribedText)

        } catch {
            Logger.log("Transcription error - \(error.localizedDescription)", context: "Parakeet", level: .error)
            await delegate?.parakeet(didEncounterError: .transcriptionFailed(error.localizedDescription))
        }
    }

    // MARK: - Audio Conversion

    private func pcmBuffersToFloatArray(buffers: [AVAudioPCMBuffer], format: AVAudioFormat?) -> [Float]? {
        guard !buffers.isEmpty, format != nil else { return nil }

        // Calculate total sample count
        let totalFrames = buffers.reduce(0) { $0 + Int($1.frameLength) }
        guard totalFrames > 0 else { return nil }

        // Pre-allocate array
        var samples: [Float] = []
        samples.reserveCapacity(totalFrames)

        // Extract Float32 samples from buffers
        for buffer in buffers {
            guard let floatChannelData = buffer.floatChannelData else { continue }
            let frameLength = Int(buffer.frameLength)

            // Use mono channel (first channel if stereo)
            let channelData = floatChannelData[0]

            for i in 0..<frameLength {
                samples.append(channelData[i])
            }
        }

        return samples
    }

    // MARK: - Cleanup

    private func cleanup() {
        audioBuffers.removeAll()
        audioFormat = nil
        isActive = false
        isStreamingMode = false
    }

    /// Check if currently in streaming mode
    var isInStreamingMode: Bool {
        return isStreamingMode
    }
}

// MARK: - Delegate Protocol

@MainActor
protocol ParakeetTranscriptionDelegate: AnyObject {
    // Batch mode callbacks (existing)
    func parakeet(didReceivePartialTranscription text: String) async
    func parakeet(didReceiveFinalTranscription text: String) async

    // Streaming mode callbacks (new - for real-time transcription)
    /// Called when volatile (in-progress, may change) text is received during streaming
    func parakeet(didReceiveVolatileTranscription text: String) async
    /// Called when confirmed (stable, won't change) text is received during streaming
    func parakeet(didReceiveConfirmedTranscription text: String) async

    // Model download callbacks
    func parakeetWillDownloadModels() async
    func parakeetDidDownloadModels() async

    // Error callback
    func parakeet(didEncounterError error: ParakeetError) async
}

// MARK: - Error Handling

enum ParakeetError: LocalizedError {
    case modelsNotInitialized
    case sessionAlreadyActive
    case audioFormatCreationFailed
    case audioProcessingFailed(String)
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelsNotInitialized:
            return "Parakeet models are not initialized. Please wait for model download to complete."
        case .sessionAlreadyActive:
            return "A Parakeet transcription session is already active"
        case .audioFormatCreationFailed:
            return "Failed to create audio format for Parakeet transcription"
        case .audioProcessingFailed(let reason):
            return "Parakeet audio processing failed: \(reason)"
        case .transcriptionFailed(let reason):
            return "Parakeet transcription failed: \(reason)"
        }
    }
}
