//
//  AudioManager.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//
//

import AVFoundation
import Cocoa


@MainActor  // Make AudioManager a MainActor class
class AudioManager {
    private var isProcessingTranscription = false
    weak var delegate: AudioManagerDelegate?
    private var pasteManager: PasteManager  // Will be injected
    private var transcriptionService: TranscriptionService?

    private var audioEngine: AVAudioEngine
    private var audioBuffers: [AVAudioPCMBuffer] = []  // To store audio buffers
    private let expectedBufferCount = 50  // Pre-allocate for ~1-2 seconds of audio
    private var recordingFormat: AVAudioFormat?  // To store the recording format for WAV conversion
    private var monitor: Any?

    // Track both fn and shift key states
    private var isFnKeyPressed = false
    private var isShiftKeyPressed = false
    private var wasShiftPressedOnStart = false
    private var hasPendingPaste = false

    private var isRecording = false {
        didSet {
            if isRecording {
                delegate?.audioManagerDidStartRecording()
            } else {
                delegate?.audioManagerDidStopRecording()
            }
        }
    }

    // Modified init to accept injected PasteManager and TranscriptionService
    init(transcriptionService: TranscriptionService?, pasteManager: PasteManager) {
        self.pasteManager = pasteManager  // Use the injected instance
        self.transcriptionService = transcriptionService
        audioEngine = AVAudioEngine()
        setupKeyboardMonitoring()
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        // Ensure engine is stopped if it was running
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }


    private func setupKeyboardMonitoring() {
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleKeyFlags(event)
            return event
        }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) {
            [weak self] event in
            self?.handleKeyFlags(event)
        }
    }

    private func handleKeyFlags(_ event: NSEvent) {
        _ = NSEvent.ModifierFlags.function
        _ = NSEvent.ModifierFlags.shift

        DispatchQueue.main.async {
            let isFnPressed = event.modifierFlags.contains(.function)
            let isShiftPressed = event.modifierFlags.contains(.shift)

            if isFnPressed != self.isFnKeyPressed {
                self.isFnKeyPressed = isFnPressed

                if isFnPressed {
                    if !self.isRecording && !self.hasPendingPaste {
                        self.wasShiftPressedOnStart = isShiftPressed
                        self.startRecording()
                    }
                } else {
                    if self.isRecording {
                        self.stopRecording()
                    }
                }
            }

            self.isShiftKeyPressed = isShiftPressed
        }
    }

    private func startRecording() {
        guard !isRecording, transcriptionService != nil else {
            if transcriptionService == nil {
                delegate?.audioManager(
                    didReceiveError: AudioManagerError.transcriptionServiceMissing)
            }
            return
        }

        // Reset state and prepare for new recording
        isProcessingTranscription = false
        hasPendingPaste = false
        audioBuffers.removeAll(keepingCapacity: true)
        audioBuffers.reserveCapacity(expectedBufferCount)
        audioConverter = nil  // Reset converter for new session

        // Microphone permission check remains similar
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startAudioEngineAndTap()
                    } else {
                        self?.delegate?.audioManager(
                            didReceiveError: AudioManagerError.microphoneAccessDenied)
                    }
                }
            }
            return
        default:
            delegate?.audioManager(didReceiveError: AudioManagerError.microphoneAccessDenied)
            return
        }
        // If already authorized, proceed directly
        startAudioEngineAndTap()
    }

    private func startAudioEngineAndTap() {
        guard !audioEngine.isRunning else {
            print("Audio engine already running.")
            return
        }
        
        // Clean shutdown before reconfiguration if needed
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Validate input format
        guard validateAudioFormat(inputFormat) else {
            delegate?.audioManager(
                didReceiveError: AudioManagerError.recordingFailed(
                    "Invalid or unsupported audio format from input device."))
            return
        }
        
        // Create optimized format for API: 16kHz mono for faster processing and smaller files
        guard let optimizedFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,  // API-recommended sample rate
            channels: 1,        // Mono sufficient for speech recognition
            interleaved: false
        ) else {
            delegate?.audioManager(
                didReceiveError: AudioManagerError.recordingFailed(
                    "Failed to create optimized recording format"))
            return
        }
        
        // Use optimized format for smaller files and faster API processing
        recordingFormat = optimizedFormat
        
        print("Audio: \(inputFormat.sampleRate)Hz → \(optimizedFormat.sampleRate)Hz, \(inputFormat.channelCount) → \(optimizedFormat.channelCount) channels")

        // Install tap with input format, we'll convert to optimized format in the tap
        inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) {
            [weak self] (buffer, time) in
            self?.handleAudioBuffer(buffer, at: time)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            delegate?.audioManager(
                didReceiveError: AudioManagerError.recordingFailed(error.localizedDescription))
            isRecording = false
        }
    }
    
    private func validateAudioFormat(_ format: AVAudioFormat) -> Bool {
        // Ensure we have a valid PCM format suitable for recording
        guard format.isStandard,
              format.channelCount > 0,
              format.sampleRate > 0 else {
            return false
        }
        return true
    }
    
    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        guard isRecording else { return }
        
        // Skip empty buffers
        guard buffer.frameLength > 0 else {
            print("Received empty buffer, skipping")
            return
        }
        
        // Convert to optimized format in real-time
        guard let optimizedBuffer = convertToOptimizedFormat(buffer) else {
            print("Failed to convert buffer to optimized format")
            return
        }
        
        audioBuffers.append(optimizedBuffer)
        
        // Log every 50 buffers to track progress
        if audioBuffers.count % 50 == 0 {
            let totalFrames = audioBuffers.reduce(0) { $0 + Int($1.frameLength) }
            print("Captured \(audioBuffers.count) buffers (\(totalFrames) frames total)")
        }
    }
    
    private var audioConverter: AVAudioConverter?
    
    private func convertToOptimizedFormat(_ sourceBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let optimizedFormat = recordingFormat else { return nil }
        
        // Reuse converter for performance - create once per recording session
        if audioConverter == nil {
            audioConverter = AVAudioConverter(from: sourceBuffer.format, to: optimizedFormat)
        }
        
        guard let converter = audioConverter else { return nil }
        
        // Calculate output capacity with proper ratio
        let ratio = optimizedFormat.sampleRate / sourceBuffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount(ceil(Double(sourceBuffer.frameLength) * ratio))
        
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: optimizedFormat,
            frameCapacity: outputCapacity
        ) else { return nil }
        
        // Efficient conversion with minimal allocations
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }
        
        return (status == .haveData || status == .endOfStream) ? outputBuffer : nil
    }

    private func stopRecording() {
        guard isRecording else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false

        guard let format = recordingFormat, !audioBuffers.isEmpty else {
            print("No audio buffers to process (\(audioBuffers.count) buffers) or format missing.")
            audioBuffers.removeAll()
            delegate?.audioManager(didReceiveError: AudioManagerError.noAudioData)
            return
        }
        
        let totalFrames = audioBuffers.reduce(0) { $0 + Int($1.frameLength) }
        let audioDuration = Double(totalFrames) / format.sampleRate
        print("Processing \(audioBuffers.count) buffers: \(totalFrames) frames (\(String(format: "%.1f", audioDuration))s)")

        // Convert audio buffers to WAV data
        guard let audioData = pcmBuffersToWavData(buffers: audioBuffers, format: format) else {
            delegate?.audioManager(didReceiveError: AudioManagerError.audioConversionFailed)
            return
        }
        
        // Verify adequate audio data (WAV header is ~44 bytes)
        guard audioData.count > 100 else {
            print("Generated audio data too small: \(audioData.count) bytes")
            delegate?.audioManager(didReceiveError: AudioManagerError.noAudioData)
            return
        }
        
        print("Generated \(audioData.count) bytes WAV file (\(String(format: "%.1f", audioDuration))s audio)")
        
        // Skip transcription for very short recordings to improve UX and avoid wasting API calls
        guard audioDuration > 1.0 else {
            print("Recording too short (\(String(format: "%.1f", audioDuration))s), skipping API call")
            delegate?.audioManagerDidStopRecording()
            return
        }
        
        audioBuffers.removeAll()  // Clear buffers after successful conversion

        // Call transcription service
        guard let service = self.transcriptionService else {
            delegate?.audioManager(didReceiveError: AudioManagerError.transcriptionServiceMissing)
            return
        }

        // Notify delegate that network processing is about to start
        delegate?.audioManagerWillStartNetworkProcessing()

        performTranscription(with: service, audioData: audioData)
    }
    
    private func performTranscription(with service: TranscriptionService, audioData: Data) {
        Task { [weak self] in
            guard let self = self else { return }
            
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
                    responseFormat: "json",  // Faster response format
                    temperature: nil,       // Use API default
                    timestampGranularities: nil  // Skip timestamps for speed
                )
                
                await MainActor.run {
                    // Process transcribed text sequentially: transcription → transformation → paste
                    self.pasteManager.processAndPasteText(
                        response.text, withAI: self.wasShiftPressedOnStart)
                }

            } catch let error as TranscriptionError {
                await MainActor.run {
                    self.delegate?.audioManager(didReceiveError: error)
                }
            } catch {
                await MainActor.run {
                    self.delegate?.audioManager(
                        didReceiveError: AudioManagerError.transcriptionFailed(
                            error.localizedDescription))
                }
            }
        }
    }

    private func pcmBuffersToWavData(buffers: [AVAudioPCMBuffer], format: AVAudioFormat) -> Data? {
        guard !buffers.isEmpty else { return nil }
        
        let tempURL = createTemporaryFileURL()
        defer { cleanupTemporaryFile(at: tempURL) }
        
        do {
            let outputFile = try AVAudioFile(forWriting: tempURL, settings: format.settings)
            
            // Write all buffers efficiently
            for buffer in buffers where buffer.frameLength > 0 {
                try outputFile.write(from: buffer)
            }
            
            return try Data(contentsOf: tempURL)
            
        } catch {
            print("WAV conversion error: \(error.localizedDescription)")
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

enum AudioManagerError: LocalizedError {
    case microphoneAccessDenied
    case recordingFailed(String?)
    case transcriptionServiceMissing
    case audioConversionFailed
    case transcriptionFailed(String?)
    case noAudioData

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "Microphone access is required. Please enable it in System Settings."
        case .recordingFailed(let reason):
            return "Failed to start recording: \(reason ?? "Unknown reason")"
        case .transcriptionServiceMissing:
            return "Transcription service is not configured."
        case .audioConversionFailed:
            return "Failed to convert audio data for transcription."
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason ?? "Unknown reason")"
        case .noAudioData:
            return "No audio data was recorded."
        }
    }
}
