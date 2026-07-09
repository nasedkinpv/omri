//
//  AudioManager.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//
//

@preconcurrency import AVFoundation
import Cocoa
import Speech
import UserNotifications

// MARK: - Shared Logger
// Logger.swift is in Shared/Utils/ and available to both targets


@MainActor  // Make AudioManager a MainActor class
class AudioManager {
    weak var delegate: AudioManagerDelegate?
    private var pasteManager: PasteManager  // Will be injected
    private var transcriptionService: TranscriptionService?

    private var audioEngine: AVAudioEngine
    nonisolated(unsafe) private var audioBuffers: [AVAudioPCMBuffer] = []  // Accessed from audio thread
    private let expectedBufferCount = 50  // Pre-allocate for ~1-2 seconds of audio
    nonisolated(unsafe) private var recordingFormat: AVAudioFormat?  // Accessed from audio thread for conversion
    private var eventTap: CFMachPort?

    // Apple SpeechAnalyzer Integration (macOS 26.0+)
    // Protocol-based approach eliminates type erasure while maintaining availability checking
    private var appleSpeechAnalyzer: (any OnDeviceTranscriptionManager)?
    // Analyzer's recommended audio format
    nonisolated(unsafe) private var speechAnalyzerFormat: AVAudioFormat?

    // Parakeet CoreML Integration (macOS 14.0+)
    private var parakeetManager: (any OnDeviceTranscriptionManager)?
    nonisolated(unsafe) private var parakeetFormat: AVAudioFormat?

    // Track both fn and shift key states
    private var isFnKeyPressed = false
    private var isShiftKeyPressed = false
    private var wasShiftPressedOnStart = false
    private var hasPendingPaste = false

    // Cache recording state and provider settings for audio thread access
    // These are accessed from the audio tap callback (real-time thread)
    nonisolated(unsafe) private var isRecording = false {
        didSet {
            // Delegate calls must be on MainActor
            Task { @MainActor in
                if isRecording {
                    self.delegate?.audioManagerDidStartRecording()
                } else {
                    self.delegate?.audioManagerDidStopRecording()
                }
            }
        }
    }
    nonisolated(unsafe) private var cachedIsOnDevice = false
    nonisolated(unsafe) private var cachedSpeechAnalyzer: (any OnDeviceTranscriptionManager)?
    nonisolated(unsafe) private var cachedParakeetManager: (any OnDeviceTranscriptionManager)?

    // Modified init to accept injected PasteManager and TranscriptionService
    init(transcriptionService: TranscriptionService?, pasteManager: PasteManager) {
        self.pasteManager = pasteManager  // Use the injected instance
        self.transcriptionService = transcriptionService
        audioEngine = AVAudioEngine()
        setupKeyboardMonitoring()
    }

    deinit {
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        // Ensure engine is stopped properly - remove tap before stopping
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
    }


    /// Listens for fn/shift via a listen-only CGEventTap, which needs the Input Monitoring
    /// privilege rather than Accessibility. NSEvent's global monitor would require
    /// Accessibility, which sandboxed and Mac App Store apps may not use.
    private func setupKeyboardMonitoring() {
        guard CGPreflightListenEventAccess() else {
            Logger.log("Input Monitoring not granted, requesting", context: "Audio", level: .warning)
            CGRequestListenEventAccess()
            return
        }

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<AudioManager>.fromOpaque(userInfo).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                MainActor.assumeIsolated { manager.reenableEventTap() }
            } else {
                let flags = event.flags
                MainActor.assumeIsolated { manager.handleKeyFlags(flags) }
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.flagsChanged.rawValue),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Logger.log("Failed to create event tap for fn key", context: "Audio", level: .error)
            return
        }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        Logger.log("Listening for fn key via event tap", context: "Audio", level: .info)
    }

    private func reenableEventTap() {
        guard let eventTap else { return }
        Logger.log("Event tap disabled by system, re-enabling", context: "Audio", level: .warning)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func handleKeyFlags(_ flags: CGEventFlags) {
        let isFnPressed = flags.contains(.maskSecondaryFn)
        let isShiftPressed = flags.contains(.maskShift)

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

    // Public method to manually trigger recording (for dictation button)
    func startRecording() {
        // Check provider requirements
        let provider = Settings.shared.transcriptionProvider
        let needsTranscriptionService = !provider.isOnDevice

        guard !isRecording else { return }
        guard needsTranscriptionService ? transcriptionService != nil : true else {
            delegate?.audioManager(didReceiveError: AudioManagerError.transcriptionServiceMissing)
            return
        }

        // Reset state and prepare for new recording
        hasPendingPaste = false
        audioBuffers.removeAll(keepingCapacity: true)
        audioBuffers.reserveCapacity(expectedBufferCount)
        audioConverter = nil  // Reset converter for new session

        // Cache settings for audio thread access
        cachedIsOnDevice = provider.isOnDevice
        // Note: cachedSpeechAnalyzer is set in continueStartRecording() after analyzer is created

        // Microphone permission check
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.continueStartRecording()
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
        continueStartRecording()
    }

    private func continueStartRecording() {
        switch Settings.shared.transcriptionProvider {
        case .apple:
            startAppleRecording()
        case .parakeet:
            startNemotronRecording()
        default:
            startAudioEngineAndTap()
        }
    }

    private func startAppleRecording() {
        guard #available(macOS 26.0, *) else {
            delegate?.audioManager(didReceiveError: AudioManagerError.recordingFailed("macOS 26.0+ required for Apple on-device transcription"))
            return
        }

        if appleSpeechAnalyzer == nil {
            let analyzer = AppleSpeechAnalyzerManager()
            analyzer.delegate = self
            appleSpeechAnalyzer = analyzer
        }
        cachedSpeechAnalyzer = appleSpeechAnalyzer

        Task {
            do {
                guard let analyzer = appleSpeechAnalyzer as? AppleSpeechAnalyzerManager else { return }
                let language = Settings.shared.transcriptionLanguage
                let format = try await analyzer.startSession(locale: language.isEmpty ? .current : Locale(identifier: language))
                speechAnalyzerFormat = format
                startAudioEngineAndTap()
            } catch {
                delegate?.audioManager(didReceiveError: AudioManagerError.recordingFailed("SpeechAnalyzer error: \(error.localizedDescription)"))
            }
        }
    }

    private func startNemotronRecording() {
        guard #available(macOS 14.0, *) else {
            delegate?.audioManager(didReceiveError: AudioManagerError.recordingFailed("macOS 14.0+ required for Nemotron transcription"))
            return
        }

        if parakeetManager == nil {
            let manager = ParakeetTranscriptionManager()
            manager.delegate = self
            parakeetManager = manager
        }
        cachedParakeetManager = parakeetManager

        Task {
            do {
                guard let manager = parakeetManager as? ParakeetTranscriptionManager else { return }
                if !manager.isInitialized {
                    try await manager.initializeModels()
                }
                parakeetFormat = try await manager.startSession()
                startAudioEngineAndTap()
            } catch {
                delegate?.audioManager(didReceiveError: AudioManagerError.recordingFailed("Nemotron error: \(error.localizedDescription)"))
            }
        }
    }

    private func startAudioEngineAndTap() {
        guard !audioEngine.isRunning else {
            Logger.log("Audio engine already running", context: "Audio", level: .debug)
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
        
        // Create optimized format
        let optimizedFormat: AVAudioFormat
        if let analyzerFormat = speechAnalyzerFormat {
            // Use SpeechAnalyzer's recommended format for on-device transcription
            optimizedFormat = analyzerFormat
            Logger.log("Using SpeechAnalyzer recommended format - \(analyzerFormat.sampleRate)Hz, \(analyzerFormat.channelCount) channels", context: "Audio", level: .debug)
        } else if let parakeetFormat = parakeetFormat {
            // Use Nemotron's format (16kHz mono Float32)
            optimizedFormat = parakeetFormat
            Logger.log("Using Nemotron format - \(parakeetFormat.sampleRate)Hz, \(parakeetFormat.channelCount) channels", context: "Audio", level: .debug)
        } else {
            // Cloud APIs - use 16kHz mono Float32
            guard let cloudFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16000,
                channels: 1,
                interleaved: false
            ) else {
                delegate?.audioManager(
                    didReceiveError: AudioManagerError.recordingFailed(
                        "Failed to create optimized recording format"))
                return
            }
            optimizedFormat = cloudFormat
            Logger.log("Using cloud format - 16kHz mono Float32", context: "Audio", level: .debug)
        }

        // Use optimized format for recording
        recordingFormat = optimizedFormat

        Logger.log("\(inputFormat.sampleRate)Hz → \(optimizedFormat.sampleRate)Hz, \(inputFormat.channelCount) → \(optimizedFormat.channelCount) channels", context: "Audio", level: .debug)

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
    
    // Called from audio tap callback (real-time thread) - must be nonisolated
    nonisolated private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        guard isRecording else { return }

        // Skip empty buffers
        guard buffer.frameLength > 0 else {
            Logger.log("Received empty buffer, skipping", context: "Audio", level: .debug)
            return
        }

        // Convert to optimized format in real-time
        guard let optimizedBuffer = convertToOptimizedFormat(buffer) else {
            Logger.log("Failed to convert buffer to optimized format", context: "Audio", level: .warning)
            return
        }

        if cachedIsOnDevice {
            if #available(macOS 26.0, *), let analyzer = cachedSpeechAnalyzer as? AppleSpeechAnalyzerManager {
                Task { @MainActor in analyzer.feedAudio(optimizedBuffer) }
            } else if let manager = cachedParakeetManager as? ParakeetTranscriptionManager {
                Task { @MainActor in manager.feedAudio(optimizedBuffer) }
            } else {
                Logger.log("No on-device manager available", context: "Audio", level: .warning)
            }
        } else {
            audioBuffers.append(optimizedBuffer)
        }
    }
    
    nonisolated(unsafe) private var audioConverter: AVAudioConverter?

    nonisolated private func convertToOptimizedFormat(_ sourceBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
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

        if let error = error {
            Logger.log("Audio conversion error: \(error.localizedDescription)", context: "Audio", level: .error)
        }

        return (status == .haveData || status == .endOfStream) ? outputBuffer : nil
    }

    // Public method to manually stop recording
    func stopRecording() {
        guard isRecording else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false

        let provider = Settings.shared.transcriptionProvider

        if provider == .apple {
            if #available(macOS 26.0, *) {
                stopAppleSpeechAnalyzerSession()
            }
        } else if provider == .parakeet {
            stopParakeetSession()
        } else {
            processCollectedBuffers()
        }
    }

    @available(macOS 26.0, *)
    private func stopAppleSpeechAnalyzerSession() {
        // Signal end of audio input and stop session
        if let analyzer = appleSpeechAnalyzer as? AppleSpeechAnalyzerManager {
            Task { @MainActor in
                analyzer.finishAudioInput()
                Logger.log("Audio input finished", context: "SpeechAnalyzer", level: .info)

                // Stop session to close results stream and trigger final result
                // Analyzer emits final results immediately, no artificial delay needed
                await analyzer.stopSession()
            }
        }

        // Clear cached format
        speechAnalyzerFormat = nil
    }

    @available(macOS 14.0, *)
    private func stopParakeetSession() {
        // Stop the session; final text arrives via didReceiveFinalTranscription.
        // Keep manager instance alive for reuse.
        if let manager = parakeetManager as? ParakeetTranscriptionManager {
            Task { @MainActor in
                _ = await manager.stopSession()
            }
        }

        // Clear cached format
        parakeetFormat = nil
    }

    private func processCollectedBuffers() {
        let totalFrames = audioBuffers.reduce(0) { $0 + Int($1.frameLength) }
        guard totalFrames > 0, let recordingFormat = recordingFormat else {
            audioBuffers.removeAll()
            return
        }

        let duration = Double(totalFrames) / recordingFormat.sampleRate
        Logger.log("Processing \(audioBuffers.count) buffers: \(totalFrames) frames (\(String(format: "%.1f", duration))s)", context: "Audio", level: .info)

        // Convert all buffers to single audio file data
        guard let audioData = pcmBuffersToWavData(buffers: audioBuffers, format: recordingFormat) else {
            delegate?.audioManager(didReceiveError: AudioManagerError.audioConversionFailed)
            audioBuffers.removeAll()
            return
        }

        Logger.log("Generated \(audioData.count) bytes WAV file (\(String(format: "%.1f", duration))s audio)", context: "Audio", level: .info)

        // Clear buffers after conversion
        audioBuffers.removeAll()

        // Notify delegate and perform transcription
        delegate?.audioManagerWillStartNetworkProcessing()

        guard let service = transcriptionService else {
            delegate?.audioManager(didReceiveError: AudioManagerError.transcriptionServiceMissing)
            return
        }

        Task {
            await performTranscription(with: service, audioData: audioData)
        }
    }

    private func performTranscription(with service: TranscriptionService, audioData: Data) async {
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

            // Process transcribed text sequentially: transcription → transformation → paste
            await self.pasteManager.processAndPasteText(
                response.text, withAI: self.wasShiftPressedOnStart)

        } catch let error as TranscriptionError {
            self.delegate?.audioManager(didReceiveError: error)
        } catch {
            self.delegate?.audioManager(
                didReceiveError: AudioManagerError.transcriptionFailed(
                    error.localizedDescription))
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
            Logger.log("WAV conversion error: \(error.localizedDescription)", context: "Audio", level: .error)
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

// MARK: - AppleSpeechAnalyzerDelegate

@available(macOS 26.0, *)
extension AudioManager: AppleSpeechAnalyzerDelegate {

    func speechAnalyzer(didReceivePartialTranscription text: String) async {
        Logger.log("Partial transcription - '\(text)'", context: "SpeechAnalyzer", level: .debug)
        // Batch mode: Partials logged but not acted on - waiting for final result
        // Apple continues refining after segment boundaries, so batch mode captures all refinements
    }

    func speechAnalyzer(didReceiveFinalTranscription text: String) async {
        Logger.log("Final transcription - '\(text)'", context: "SpeechAnalyzer", level: .info)

        // Batch mode: Process complete text with all refinements (same as Parakeet batch mode)
        // Provides better quality by including all refinements + full context for AI processing
        await self.pasteManager.processAndPasteText(text, withAI: self.wasShiftPressedOnStart)
    }

    func speechAnalyzerWillDownloadLanguageModel(for locale: Locale) async {
        Logger.log("Downloading language model for \(locale.identifier)...", context: "SpeechAnalyzer", level: .info)

        // Show download status in menu bar (minimalist native UX)
        let languageName = locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
        await MainActor.run {
            AppDelegate.shared?.showDownloadStatus(message: "Downloading \(languageName) model...")
        }

        // Also send notification for background awareness
        let content = UNMutableNotificationContent()
        content.title = "Omri"
        content.body = "Downloading language model for \(languageName)..."
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "language-model-download",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.log("Failed to show download notification: \(error.localizedDescription)", context: "SpeechAnalyzer", level: .warning)
        }
    }

    func speechAnalyzerDidDownloadLanguageModel(for locale: Locale) async {
        Logger.log("Language model download complete for \(locale.identifier)", context: "SpeechAnalyzer", level: .info)

        // Hide download status
        await MainActor.run {
            AppDelegate.shared?.hideDownloadStatus()
        }

        // Notify user that download completed
        let content = UNMutableNotificationContent()
        content.title = "Omri"
        content.body = "Language model downloaded. On-device transcription ready!"
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "language-model-complete",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.log("Failed to show completion notification: \(error.localizedDescription)", context: "SpeechAnalyzer", level: .warning)
        }
    }

    func speechAnalyzer(didEncounterError error: SpeechAnalyzerError) async {
        Logger.log("Error - \(error.localizedDescription)", context: "SpeechAnalyzer", level: .error)
        await MainActor.run {
            self.delegate?.audioManager(didReceiveError: AudioManagerError.recordingFailed(error.localizedDescription))
        }
    }
}

// MARK: - ParakeetTranscriptionDelegate

@available(macOS 14.0, *)
extension AudioManager: ParakeetTranscriptionDelegate {

    func parakeet(didReceiveFinalTranscription text: String) async {
        Logger.log("Final transcription - '\(text)'", context: "Nemotron", level: .info)

        let shouldApplyAI = wasShiftPressedOnStart && Settings.shared.enableAIProcessing
        await self.pasteManager.processAndPasteText(text, withAI: shouldApplyAI)
    }

    func parakeet(didReceiveVolatileTranscription text: String) async {
        // Volatile text is in-progress and may change; final text arrives via didReceiveFinalTranscription
        Logger.log("Volatile: '\(text)'", context: "Nemotron", level: .debug)
        await self.pasteManager.updateVolatileText(text)
    }

    func parakeetWillDownloadModels() async {
        Logger.log("Downloading models...", context: "Nemotron", level: .info)

        // Show download status in menu bar (minimalist native UX)
        await MainActor.run {
            AppDelegate.shared?.showDownloadStatus(message: "Downloading Nemotron model (600MB)...")
        }

        // Also send notification for background awareness
        let content = UNMutableNotificationContent()
        content.title = "Omri"
        content.body = "Downloading Nemotron language model (600MB)..."
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "parakeet-model-download",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.log("Failed to show download notification: \(error.localizedDescription)", context: "Nemotron", level: .warning)
        }
    }

    func parakeetDidDownloadModels() async {
        Logger.log("Models download complete", context: "Nemotron", level: .info)

        // Hide download status
        await MainActor.run {
            AppDelegate.shared?.hideDownloadStatus()
        }

        // Notify user that download completed
        let content = UNMutableNotificationContent()
        content.title = "Omri"
        content.body = "Nemotron model downloaded. On-device transcription ready!"
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "parakeet-model-complete",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.log("Failed to show completion notification: \(error.localizedDescription)", context: "Nemotron", level: .warning)
        }
    }

    func parakeet(didEncounterError error: ParakeetError) async {
        Logger.log("Error - \(error.localizedDescription)", context: "Nemotron", level: .error)
        await MainActor.run {
            self.delegate?.audioManager(didReceiveError: AudioManagerError.recordingFailed(error.localizedDescription))
        }
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
