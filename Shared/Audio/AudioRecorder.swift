//
//  AudioRecorder.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Platform-agnostic audio recording using AVAudioEngine
//  Works on both macOS and iOS

@preconcurrency import AVFoundation
import Foundation

#if os(iOS)
import UIKit
#endif

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

@MainActor
class AudioRecorder {
    weak var delegate: AudioRecorderDelegate?

    private var audioEngine: AVAudioEngine

    // MARK: - Thread Safety Documentation
    //
    // The following properties are marked `nonisolated(unsafe)` to allow access from the
    // real-time audio thread (AVAudioEngine tap callback). This is necessary because:
    //
    // 1. AVAudioEngine callbacks run on a real-time thread separate from MainActor
    // 2. Audio processing requires minimal latency - actor isolation would introduce unacceptable delays
    // 3. Swift's @MainActor isolation cannot be used in real-time audio contexts
    //
    // Thread Safety Guarantees:
    // - audioBuffers: Only appended from audio thread, only read/cleared from MainActor
    //   - Write: Single-threaded (audio callback)
    //   - Read/Clear: Only when isRecording = false (after audio engine stopped)
    //   - No concurrent access possible due to sequential recording lifecycle
    //
    // - recordingFormat: Set once before recording starts, read-only during recording
    //   - Immutable after initialization until next recording session
    //
    // - audioConverter: Created once per session, read-only during recording
    //   - AVAudioConverter is thread-safe for concurrent reads (Apple documentation)
    //
    // - isRecording: Acts as synchronization flag
    //   - Transitions: MainActor controls start/stop lifecycle
    //   - Audio thread checks before processing (guard isRecording)
    //   - No race conditions due to sequential state transitions
    //
    // External Synchronization:
    // - Recording lifecycle enforced by AVAudioEngine state machine
    // - Audio thread callbacks stop before engine.stop() returns
    // - MainActor code only accesses buffers after engine stopped
    //
    // Reference: Swift Concurrency Migration Guide on nonisolated(unsafe)
    // https://github.com/swiftlang/swift-migration-guide

    nonisolated(unsafe) private var audioBuffers: [AVAudioPCMBuffer] = []
    private let expectedBufferCount = 50
    nonisolated(unsafe) private var recordingFormat: AVAudioFormat?
    nonisolated(unsafe) private var audioConverter: AVAudioConverter?

    nonisolated(unsafe) private var isRecording = false {
        didSet {
            Task { @MainActor in
                if isRecording {
                    self.delegate?.audioRecorderDidStartRecording()
                } else {
                    self.delegate?.audioRecorderDidStopRecording()
                }
            }
        }
    }

    init() {
        self.audioEngine = AVAudioEngine()
    }

    deinit {
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
    }

    // MARK: - Public API

    var recording: Bool {
        return isRecording
    }

    func startRecording() async throws {
        guard !isRecording else { return }

        // Check microphone permission
        #if os(iOS)
        let granted = await checkMicrophonePermission()
        guard granted else {
            throw AudioRecorderError.microphoneAccessDenied
        }

        // Configure AVAudioSession for iOS
        try configureAudioSession()
        #else
        // macOS permission check
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            guard granted else {
                throw AudioRecorderError.microphoneAccessDenied
            }
        default:
            throw AudioRecorderError.microphoneAccessDenied
        }
        #endif

        // Reset state for new recording
        audioBuffers.removeAll(keepingCapacity: true)
        audioBuffers.reserveCapacity(expectedBufferCount)
        audioConverter = nil

        // Start audio engine
        try startAudioEngine()
    }

    func stopRecording() async -> Data? {
        guard isRecording else { return nil }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false

        #if os(iOS)
        // Deactivate audio session on iOS
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif

        // Convert buffers to WAV data
        guard let audioData = pcmBuffersToWavData() else {
            delegate?.audioRecorder(didReceiveError: .audioConversionFailed)
            audioBuffers.removeAll()
            return nil
        }

        #if DEBUG
        let totalFrames = audioBuffers.reduce(0) { $0 + Int($1.frameLength) }
        let duration = recordingFormat.map { Double(totalFrames) / $0.sampleRate } ?? 0
        Logger.log("Generated \(audioData.count) bytes WAV (\(String(format: "%.1f", duration))s)", context: "Audio", level: .debug)
        #endif

        audioBuffers.removeAll()

        // Notify delegate
        delegate?.audioRecorder(didCompleteWithAudioData: audioData)

        return audioData
    }

    /// Stop recording and get raw PCM buffers for on-device transcription (Parakeet)
    /// Returns captured buffers and the recording format
    func stopRecordingAndGetBuffers() async -> ([AVAudioPCMBuffer], AVAudioFormat?) {
        guard isRecording else { return ([], nil) }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false

        #if os(iOS)
        // Deactivate audio session on iOS
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif

        let buffers = audioBuffers
        let format = recordingFormat

        #if DEBUG
        let totalFrames = buffers.reduce(0) { $0 + Int($1.frameLength) }
        let duration = format.map { Double(totalFrames) / $0.sampleRate } ?? 0
        Logger.log("Captured \(buffers.count) buffers (\(String(format: "%.1f", duration))s)", context: "Audio", level: .debug)
        #endif

        audioBuffers.removeAll()

        return (buffers, format)
    }

    // MARK: - Private Implementation

    #if os(iOS)
    private func checkMicrophonePermission() async -> Bool {
        // Modern iOS 17+ approach: Use AVAudioApplication for microphone permissions
        // Info.plist must contain NSMicrophoneUsageDescription
        let status = AVAudioApplication.shared.recordPermission

        if status == .undetermined {
            // Request permission asynchronously
            return await AVAudioApplication.requestRecordPermission()
        }

        return status == .granted
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default, options: [])
        try session.setActive(true)
    }
    #endif

    private func startAudioEngine() throws {
        guard !audioEngine.isRunning else { return }

        // Clean shutdown if needed
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Validate input format
        guard validateAudioFormat(inputFormat) else {
            throw AudioRecorderError.recordingFailed("Invalid audio format from input device")
        }

        // Create optimized 16kHz mono Float32 format for transcription
        guard let optimizedFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecorderError.recordingFailed("Failed to create recording format")
        }

        recordingFormat = optimizedFormat

        #if DEBUG
        Logger.log("\(inputFormat.sampleRate)Hz → 16kHz, \(inputFormat.channelCount) → 1 channel", context: "Audio", level: .debug)
        #endif

        // Install tap with input format, convert in callback
        inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) {
            [weak self] (buffer, time) in
            self?.handleAudioBuffer(buffer, at: time)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    private func validateAudioFormat(_ format: AVAudioFormat) -> Bool {
        guard format.isStandard,
              format.channelCount > 0,
              format.sampleRate > 0 else {
            return false
        }
        return true
    }

    nonisolated private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        guard isRecording else { return }
        guard buffer.frameLength > 0 else { return }

        // Convert to optimized format in real-time
        guard let optimizedBuffer = convertToOptimizedFormat(buffer) else {
            Logger.log("Failed to convert buffer", context: "Audio", level: .error)
            return
        }

        audioBuffers.append(optimizedBuffer)

        // Log progress every 50 buffers
        #if DEBUG
        if audioBuffers.count % 50 == 0 {
            let totalFrames = audioBuffers.reduce(0) { $0 + Int($1.frameLength) }
            Logger.log("Captured \(audioBuffers.count) buffers (\(totalFrames) frames)", context: "Audio", level: .debug)
        }
        #endif
    }

    nonisolated private func convertToOptimizedFormat(_ sourceBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let optimizedFormat = recordingFormat else { return nil }

        // Reuse converter for performance
        if audioConverter == nil {
            audioConverter = AVAudioConverter(from: sourceBuffer.format, to: optimizedFormat)
        }

        guard let converter = audioConverter else { return nil }

        // Calculate output capacity
        let ratio = optimizedFormat.sampleRate / sourceBuffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount(ceil(Double(sourceBuffer.frameLength) * ratio))

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: optimizedFormat,
            frameCapacity: outputCapacity
        ) else { return nil }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if let error = error {
            Logger.log("Conversion error - \(error.localizedDescription)", context: "Audio", level: .error)
        }

        return (status == .haveData || status == .endOfStream) ? outputBuffer : nil
    }

    private func pcmBuffersToWavData() -> Data? {
        guard !audioBuffers.isEmpty, let format = recordingFormat else { return nil }

        let tempURL = createTemporaryFileURL()
        defer { cleanupTemporaryFile(at: tempURL) }

        do {
            let outputFile = try AVAudioFile(forWriting: tempURL, settings: format.settings)

            for buffer in audioBuffers where buffer.frameLength > 0 {
                try outputFile.write(from: buffer)
            }

            return try Data(contentsOf: tempURL)
        } catch {
            Logger.log("WAV conversion error - \(error.localizedDescription)", context: "Audio", level: .error)
            return nil
        }
    }

    private func createTemporaryFileURL() -> URL {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        return tempDir.appendingPathComponent(UUID().uuidString + ".wav")
    }

    private func cleanupTemporaryFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
