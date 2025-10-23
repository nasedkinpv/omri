//
//  VADManager.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Voice Activity Detection Manager using Silero VAD via FluidAudio
//

@preconcurrency import AVFoundation
import Foundation

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

// MARK: - Shared Types (used by both implementations)

enum VADError: LocalizedError {
    case notInitialized
    case initializationFailed(String)
    case unsupportedFormat
    case audioProcessingFailed
    case processingError(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "VAD Manager is not initialized. Call initialize() first."
        case .initializationFailed(let reason):
            return "Failed to initialize VAD: \(reason)"
        case .unsupportedFormat:
            return "Audio format not supported. VAD requires 16kHz PCM Float32 format."
        case .audioProcessingFailed:
            return "Failed to process audio data for VAD analysis."
        case .processingError(let reason):
            return "VAD processing error: \(reason)"
        }
    }
}

@MainActor
protocol VADManagerDelegate: AnyObject {
    func vadManagerDidStartListening()
    func vadManagerDidStopListening()
    func vadManagerDidDetectSpeechStart()
    func vadManagerDidDetectSpeechEnd()
    func vadManager(didCompleteAudioSamples samples: [Float], duration: Double)
    func vadManager(didCompleteAudioChunk audioData: Data, duration: Double)
    func vadManager(didEncounterError error: VADError)
}

// MARK: - FluidAudio Implementation

#if canImport(FluidAudio)
import FluidAudio

@MainActor
class VADManager: ObservableObject {

    // MARK: - Properties

    private var vadInstance: VadManager?
    private var streamState: VadStreamState?
    private var isInitialized = false

    // VAD Configuration - simplified to match FluidAudio examples
    private var vadConfig: VadConfig
    private var sensitivity: Double
    private var minSpeechDuration: Double
    private var silenceTimeout: Double

    // State tracking
    @Published var isListening = false
    @Published var isSpeechDetected = false
    @Published var lastError: VADError?

    // Streaming speech collection
    private var currentSpeechBuffers: [AVAudioPCMBuffer] = []
    private var speechStartTime: Double = 0
    private var currentRecordingFormat: AVAudioFormat?

    // Delegate for speech events
    weak var delegate: VADManagerDelegate?

    // MARK: - Initialization

    init(sensitivity: Double = 0.5, minSpeechDuration: Double = 0.25, silenceTimeout: Double = 1.0) {
        // Simplified VAD configuration - following FluidAudio examples
        self.vadConfig = VadConfig(threshold: Float(sensitivity))
        self.sensitivity = sensitivity
        self.minSpeechDuration = minSpeechDuration
        self.silenceTimeout = silenceTimeout

        Logger.log("VAD Configuration - Speech threshold: \(Float(sensitivity))", context: "VAD", level: .info)
    }

    // MARK: - Lifecycle

    func initialize() async throws {
        guard !isInitialized else { return }

        do {
            vadInstance = try await VadManager(config: vadConfig)
            streamState = await vadInstance?.makeStreamState()
            isInitialized = true
            Logger.log("VAD Manager initialized successfully", context: "VAD", level: .info)
        } catch {
            let vadError = VADError.initializationFailed(error.localizedDescription)
            await MainActor.run {
                self.lastError = vadError
            }
            throw vadError
        }
    }

    func shutdown() {
        vadInstance = nil
        streamState = nil
        isInitialized = false

        Task { @MainActor in
            isListening = false
            isSpeechDetected = false
        }
    }

    // MARK: - Voice Activity Detection

    func startListening() {
        guard isInitialized else {
            lastError = VADError.notInitialized
            return
        }

        isListening = true
        currentSpeechBuffers.removeAll(keepingCapacity: true)
        isSpeechDetected = false
        speechStartTime = 0
        currentRecordingFormat = nil

        // Reset stream state to start fresh timing for this recording session
        Task {
            streamState = await vadInstance?.makeStreamState()
        }

        delegate?.vadManagerDidStartListening()
    }

    func stopListening() {
        // If we're in the middle of speech when stopping, process what we have
        if isSpeechDetected && !currentSpeechBuffers.isEmpty {
            // Calculate duration from actual audio frames, not timestamps
            let totalFrames = currentSpeechBuffers.reduce(0) { $0 + Int($1.frameLength) }
            let estimatedDuration = Double(totalFrames) / 16000.0
            Logger.log("Stopping mid-speech, processing partial chunk (estimated \(String(format: "%.2f", estimatedDuration))s)", context: "VAD", level: .info)

            if estimatedDuration >= minSpeechDuration {
                processCollectedSpeechBuffers(duration: estimatedDuration)
            }
        }

        isListening = false
        isSpeechDetected = false

        delegate?.vadManagerDidStopListening()
    }

    // MARK: - Audio Processing

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isListening, isInitialized else { return }

        // Ensure buffer is in correct format (16kHz mono)
        guard validateAudioFormat(buffer.format) else {
            lastError = VADError.unsupportedFormat
            return
        }

        // Store the recording format for WAV conversion
        if currentRecordingFormat == nil {
            currentRecordingFormat = buffer.format
        }

        // Process on background queue to avoid blocking audio thread
        Task.detached { [weak self] in
            await self?.processBufferInternal(buffer)
        }
    }

    private func processBufferInternal(_ buffer: AVAudioPCMBuffer) async {
        guard let vadInstance = vadInstance,
              let currentStreamState = streamState else {
            await MainActor.run {
                self.lastError = VADError.notInitialized
            }
            return
        }

        // Convert buffer to Float32 array for VAD processing
        guard let audioSamples = extractAudioSamples(from: buffer) else {
            await MainActor.run {
                self.lastError = VADError.audioProcessingFailed
            }
            return
        }

        // FluidAudio VAD handles arbitrary chunk sizes efficiently
        do {
            // Create custom streaming config with our timing parameters
            var streamConfig = VadSegmentationConfig.default
            streamConfig.minSpeechDuration = minSpeechDuration
            streamConfig.minSilenceDuration = silenceTimeout

            // Use streaming chunk processing with custom config
            let result = try await vadInstance.processStreamingChunk(
                audioSamples,
                state: currentStreamState,
                config: streamConfig,
                returnSeconds: true,
                timeResolution: 2
            )

            await MainActor.run {
                // Update stream state for next chunk
                self.streamState = result.state

                // Handle VAD events FIRST to set proper flags
                // This ensures the buffer that triggers speechStart gets collected
                if let event = result.event {
                    self.handleVADEvent(event)
                }

                // Collect audio buffer if currently detecting speech
                // After event handling, this properly includes the triggering buffer
                if self.isSpeechDetected {
                    self.currentSpeechBuffers.append(buffer)
                }
            }

        } catch {
            await MainActor.run {
                self.lastError = VADError.processingError(error.localizedDescription)
            }
        }
    }

    private func handleVADEvent(_ event: VadStreamEvent) {
        switch event.kind {
        case .speechStart:
            isSpeechDetected = true
            speechStartTime = event.time ?? 0
            currentSpeechBuffers.removeAll(keepingCapacity: true)
            Logger.log("Speech started at \(speechStartTime)s", context: "VAD", level: .info)
            delegate?.vadManagerDidDetectSpeechStart()
            // Note: Current buffer will be collected after this event handler returns

        case .speechEnd:
            isSpeechDetected = false
            let speechEndTime = event.time ?? 0
            let speechDuration = speechEndTime - speechStartTime
            Logger.log("Speech ended at \(speechEndTime)s (duration: \(String(format: "%.2f", speechDuration))s)", context: "VAD", level: .info)

            // Process collected speech buffers into audio chunk
            if currentSpeechBuffers.isEmpty {
                Logger.log("No audio buffers collected, skipping chunk", context: "VAD", level: .debug)
            } else if speechDuration < minSpeechDuration {
                Logger.log("Speech too short (\(String(format: "%.2f", speechDuration))s < \(String(format: "%.2f", minSpeechDuration))s threshold), skipping chunk", context: "VAD", level: .debug)
            } else {
                processCollectedSpeechBuffers(duration: speechDuration)
            }

            delegate?.vadManagerDidDetectSpeechEnd()
        }
    }

    private func processCollectedSpeechBuffers(duration: Double) {
        guard !currentSpeechBuffers.isEmpty,
              let format = currentRecordingFormat else {
            Logger.log("No speech buffers or format to process", context: "VAD", level: .debug)
            return
        }

        // Extract Float samples directly from buffers for on-device processing
        guard let floatSamples = extractFloatSamples(from: currentSpeechBuffers) else {
            Logger.log("Failed to extract Float samples from buffers", context: "VAD", level: .error)
            return
        }

        Logger.log("Generated \(floatSamples.count) Float samples (\(String(format: "%.2f", duration))s)", context: "VAD", level: .info)

        // Emit Float samples for immediate transcription (on-device)
        delegate?.vadManager(didCompleteAudioSamples: floatSamples, duration: duration)

        // Also emit WAV data for cloud APIs (backward compatibility)
        if let audioData = pcmBuffersToWavData(buffers: currentSpeechBuffers, format: format) {
            delegate?.vadManager(didCompleteAudioChunk: audioData, duration: duration)
        }

        // Clear processed buffers
        currentSpeechBuffers.removeAll(keepingCapacity: true)
    }

    private func extractFloatSamples(from buffers: [AVAudioPCMBuffer]) -> [Float]? {
        guard !buffers.isEmpty else { return nil }

        // Calculate total sample count
        let totalFrames = buffers.reduce(0) { $0 + Int($1.frameLength) }
        guard totalFrames > 0 else { return nil }

        // Pre-allocate array for efficiency
        var samples: [Float] = []
        samples.reserveCapacity(totalFrames)

        // Extract Float32 samples from each buffer
        for buffer in buffers {
            guard let floatChannelData = buffer.floatChannelData else { continue }
            let frameLength = Int(buffer.frameLength)
            let channelCount = Int(buffer.format.channelCount)

            // Use first channel (mono) or average channels (stereo)
            if channelCount == 1 {
                // Mono - direct copy
                let channel = floatChannelData[0]
                for i in 0..<frameLength {
                    samples.append(channel[i])
                }
            } else if channelCount == 2 {
                // Stereo - average to mono
                let leftChannel = floatChannelData[0]
                let rightChannel = floatChannelData[1]
                for i in 0..<frameLength {
                    samples.append((leftChannel[i] + rightChannel[i]) / 2.0)
                }
            }
        }

        return samples
    }

    private func pcmBuffersToWavData(buffers: [AVAudioPCMBuffer], format: AVAudioFormat) -> Data? {
        guard !buffers.isEmpty else { return nil }

        let tempURL = createTemporaryFileURL()
        defer { cleanupTemporaryFile(at: tempURL) }

        do {
            let outputFile = try AVAudioFile(forWriting: tempURL, settings: format.settings)

            // Write all buffers efficiently
            for buffer in buffers {
                try outputFile.write(from: buffer)
            }

            return try Data(contentsOf: tempURL)

        } catch {
            Logger.log("Error converting buffers to WAV: \(error)", context: "VAD", level: .error)
            return nil
        }
    }

    private func createTemporaryFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "vad_chunk_\(UUID().uuidString).wav"
        return tempDir.appendingPathComponent(fileName)
    }

    private func cleanupTemporaryFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Audio Format Handling

    private func validateAudioFormat(_ format: AVAudioFormat) -> Bool {
        // VAD requires 16kHz sample rate
        let requiredSampleRate: Double = 16000
        let tolerance: Double = 100 // Allow small variations

        return abs(format.sampleRate - requiredSampleRate) < tolerance &&
               format.channelCount <= 2 && // Accept mono or stereo
               format.commonFormat == .pcmFormatFloat32
    }

    private func extractAudioSamples(from buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData else { return nil }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Convert to mono if stereo by averaging channels
        if channelCount == 2 {
            let leftChannel = channelData[0]
            let rightChannel = channelData[1]

            return (0..<frameLength).map { index in
                (leftChannel[index] + rightChannel[index]) / 2.0
            }
        } else {
            // Already mono
            let channel = channelData[0]
            return Array(UnsafeBufferPointer(start: channel, count: frameLength))
        }
    }

    // MARK: - Configuration Updates

    func updateSensitivity(_ newSensitivity: Double) {
        Logger.log("Updating VAD sensitivity from \(sensitivity) to \(newSensitivity)", context: "VAD", level: .info)

        // Update configuration - simplified approach
        self.sensitivity = newSensitivity
        self.vadConfig = VadConfig(threshold: Float(newSensitivity))

        Logger.log("New VAD Configuration - Speech threshold: \(Float(newSensitivity))", context: "VAD", level: .info)

        // Reinitialize VAD with new configuration
        Task {
            if isInitialized {
                try await reinitialize()
            }
        }
    }

    func updateTimingParameters(newMinSpeechDuration: Double, newSilenceTimeout: Double) {
        Logger.log("Updating VAD timing - minSpeech: \(newMinSpeechDuration)s, silence: \(newSilenceTimeout)s", context: "VAD", level: .info)

        // Store new timing parameters - they're used in speech processing logic
        self.minSpeechDuration = newMinSpeechDuration
        self.silenceTimeout = newSilenceTimeout
    }

    private func reinitialize() async throws {
        // Save listening state before shutdown
        let wasListening = isListening

        shutdown()
        try await initialize()

        // Restore listening state
        if wasListening {
            await MainActor.run {
                self.startListening()
            }
        }
    }
}

#else

// MARK: - Fallback Implementation (FluidAudio not available)

@MainActor
class VADManager: ObservableObject {

    @Published var isListening = false
    @Published var isSpeechDetected = false
    @Published var lastError: VADError?

    weak var delegate: VADManagerDelegate?

    init(sensitivity: Double = 0.5, minSpeechDuration: Double = 0.25, silenceTimeout: Double = 1.0) {
        Logger.log("FluidAudio not available, using fallback implementation", context: "VAD", level: .warning)
    }

    func initialize() async throws {
        throw VADError.initializationFailed("FluidAudio dependency not available")
    }

    func shutdown() {}
    func startListening() {}
    func stopListening() {}
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {}
    func updateSensitivity(_ sensitivity: Double) {}
    func updateTimingParameters(minSpeechDuration: Double, silenceTimeout: Double) {}
}

#endif
