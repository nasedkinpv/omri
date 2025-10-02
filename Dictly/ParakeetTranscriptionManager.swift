//
//  ParakeetTranscriptionManager.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Manages Parakeet CoreML transcription for on-device multilingual ASR
//

import Foundation
import AVFAudio
import FluidAudio

@available(macOS 14.0, *)
@MainActor
class ParakeetTranscriptionManager {
    // MARK: - Properties

    private var asrManager: AsrManager?
    private var models: AsrModels?
    private var isActive = false
    private var audioFormat: AVAudioFormat?

    // Buffer collection for batch transcription
    private var audioBuffers: [AVAudioPCMBuffer] = []

    weak var delegate: ParakeetTranscriptionDelegate?

    // MARK: - Lifecycle

    init() {}

    // MARK: - Model Management

    /// Initialize Parakeet models (downloads if needed)
    func initializeModels() async throws {
        print("Parakeet: Initializing models...")

        // Notify delegate about potential download
        await delegate?.parakeetWillDownloadModels()

        // Download and load models (cached after first download)
        let models = try await AsrModels.downloadAndLoad()
        self.models = models

        print("Parakeet: Models loaded successfully")
        await delegate?.parakeetDidDownloadModels()

        // Initialize ASR manager with default configuration
        let asrManager = AsrManager()
        try await asrManager.initialize(models: models)
        self.asrManager = asrManager

        print("Parakeet: ASR Manager initialized")
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

    /// Start a transcription session
    /// - Returns: The recommended audio format (16kHz mono Float32)
    func startSession() async throws -> AVAudioFormat {
        guard !isActive else {
            print("Parakeet: Session already active")
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
        isActive = true

        print("Parakeet: Session started - 16kHz mono Float32")
        return format
    }

    /// Feed an audio buffer to the transcription pipeline
    /// - Parameter buffer: Audio buffer in 16kHz mono Float32 format
    func feedAudio(_ buffer: AVAudioPCMBuffer) {
        guard isActive else {
            print("Parakeet: Cannot feed audio - session not active")
            return
        }

        // Collect buffers for batch processing
        audioBuffers.append(buffer)
    }

    /// Stop the current transcription session and process collected audio
    func stopSession() async {
        guard isActive else { return }

        print("Parakeet: Stopping session, processing \(audioBuffers.count) buffers")

        // Convert buffers to Float array for FluidAudio
        guard let audioSamples = pcmBuffersToFloatArray(buffers: audioBuffers, format: audioFormat) else {
            print("Parakeet: Failed to convert audio buffers")
            await delegate?.parakeet(didEncounterError: .audioProcessingFailed("Failed to convert audio buffers"))
            cleanup()
            return
        }

        let duration = Double(audioSamples.count) / 16000.0
        print("Parakeet: Transcribing \(audioSamples.count) samples (\(String(format: "%.2f", duration))s)")

        // Perform transcription
        await transcribeAudio(samples: audioSamples)

        cleanup()
    }

    // MARK: - Transcription

    /// Transcribe a single audio chunk for streaming mode (VAD integration)
    /// - Parameter samples: Float32 audio samples at 16kHz
    /// - Returns: Transcribed text, or nil if transcription failed
    func transcribeChunk(_ samples: [Float]) async -> String? {
        guard let asrManager = asrManager else {
            print("Parakeet: Cannot transcribe chunk - models not initialized")
            await delegate?.parakeet(didEncounterError: .modelsNotInitialized)
            return nil
        }

        // Skip very short chunks (less than 0.5s might not transcribe well)
        let duration = Double(samples.count) / 16000.0
        guard duration >= 0.5 else {
            print("Parakeet: Chunk too short (\(String(format: "%.2f", duration))s), skipping")
            return nil
        }

        do {
            let result = try await asrManager.transcribe(samples, source: .system)
            let transcribedText = result.text

            guard !transcribedText.isEmpty else {
                print("Parakeet: Chunk transcription returned empty text")
                return nil
            }

            print("Parakeet: Chunk transcribed - '\(transcribedText)' (\(String(format: "%.2f", duration))s, confidence: \(result.confidence))")

            // Send partial result to delegate
            await delegate?.parakeet(didReceivePartialTranscription: transcribedText)

            return transcribedText

        } catch {
            print("Parakeet: Chunk transcription error - \(error.localizedDescription)")
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
            print("Parakeet: Transcription complete - '\(transcribedText)' (confidence: \(result.confidence))")

            // Send final result to delegate
            await delegate?.parakeet(didReceiveFinalTranscription: transcribedText)

        } catch {
            print("Parakeet: Transcription error - \(error.localizedDescription)")
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
    }
}

// MARK: - Delegate Protocol

@MainActor
protocol ParakeetTranscriptionDelegate: AnyObject {
    func parakeet(didReceivePartialTranscription text: String) async
    func parakeet(didReceiveFinalTranscription text: String) async
    func parakeetWillDownloadModels() async
    func parakeetDidDownloadModels() async
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
