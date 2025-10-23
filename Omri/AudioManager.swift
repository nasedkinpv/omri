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
    private var isProcessingTranscription = false
    weak var delegate: AudioManagerDelegate?
    private var pasteManager: PasteManager  // Will be injected
    private var transcriptionService: TranscriptionService?

    private var audioEngine: AVAudioEngine
    nonisolated(unsafe) private var audioBuffers: [AVAudioPCMBuffer] = []  // Accessed from audio thread
    private let expectedBufferCount = 50  // Pre-allocate for ~1-2 seconds of audio
    nonisolated(unsafe) private var recordingFormat: AVAudioFormat?  // Accessed from audio thread for conversion
    private var monitor: Any?

    // VAD Integration
    private var vadManager: VADManager?

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
    nonisolated(unsafe) private var cachedEnableVAD = false
    nonisolated(unsafe) private var cachedVADManager: VADManager?
    nonisolated(unsafe) private var cachedSpeechAnalyzer: (any OnDeviceTranscriptionManager)?
    nonisolated(unsafe) private var cachedParakeetManager: (any OnDeviceTranscriptionManager)?

    // Modified init to accept injected PasteManager and TranscriptionService
    init(transcriptionService: TranscriptionService?, pasteManager: PasteManager) {
        self.pasteManager = pasteManager  // Use the injected instance
        self.transcriptionService = transcriptionService
        audioEngine = AVAudioEngine()
        setupKeyboardMonitoring()
        // VAD will be initialized lazily when first needed
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        // Ensure engine is stopped properly - remove tap before stopping
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        // Clean up VAD resources
        Task { @MainActor [weak self] in
            self?.vadManager?.shutdown()
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

    // MARK: - VAD Setup and Management

    private func setupVADManager() async throws {
        // Initialize VAD manager if enabled (but never for Apple - it has built-in VAD)
        let provider = Settings.shared.transcriptionProvider
        if Settings.shared.enableVAD && provider != .apple {
            let vadManager = VADManager(
                sensitivity: Settings.shared.vadSensitivity,
                minSpeechDuration: Settings.shared.vadMinSpeechDuration,
                silenceTimeout: Settings.shared.vadSilenceTimeout
            )
            vadManager.delegate = self
            self.vadManager = vadManager

            // Initialize VAD synchronously - must complete before use
            do {
                try await vadManager.initialize()
                Logger.log("VAD Manager initialized successfully", context: "Audio", level: .info)
            } catch {
                Logger.log("Failed to initialize VAD Manager: \(error.localizedDescription)", context: "Audio", level: .error)
                self.vadManager = nil
                throw error
            }
        } else {
            vadManager?.shutdown()
            vadManager = nil
        }
    }

    private func updateVADSettings() {
        // Update existing VAD with new settings if available
        if let vadManager = vadManager {
            vadManager.updateSensitivity(Settings.shared.vadSensitivity)
            vadManager.updateTimingParameters(
                newMinSpeechDuration: Settings.shared.vadMinSpeechDuration,
                newSilenceTimeout: Settings.shared.vadSilenceTimeout
            )
        } else if Settings.shared.enableVAD {
            // Create VAD if it doesn't exist but is now enabled
            Task {
                do {
                    try await setupVADManager()
                } catch {
                    Logger.log("Failed to initialize from settings update: \(error.localizedDescription)", context: "VAD", level: .error)
                }
            }
        }
    }

    // Public methods for settings to call
    func updateVADSensitivity() {
        vadManager?.updateSensitivity(Settings.shared.vadSensitivity)
    }

    func updateVADTimingParameters() {
        vadManager?.updateTimingParameters(
            newMinSpeechDuration: Settings.shared.vadMinSpeechDuration,
            newSilenceTimeout: Settings.shared.vadSilenceTimeout
        )
    }

    private func handleKeyFlags(_ event: NSEvent) {
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
        isProcessingTranscription = false
        hasPendingPaste = false
        audioBuffers.removeAll(keepingCapacity: true)
        audioBuffers.reserveCapacity(expectedBufferCount)
        audioConverter = nil  // Reset converter for new session

        // Cache settings for audio thread access
        cachedIsOnDevice = provider.isOnDevice
        // Never use VAD with Apple - it has built-in speech detection
        cachedEnableVAD = provider == .apple ? false : Settings.shared.enableVAD
        cachedVADManager = vadManager
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
        let provider = Settings.shared.transcriptionProvider

        // Initialize provider-specific components
        if provider.isOnDevice {
            if provider == .apple {
                // Apple SpeechAnalyzer mode - initialize analyzer first to get format
                guard #available(macOS 26.0, *) else {
                    delegate?.audioManager(didReceiveError: AudioManagerError.recordingFailed("macOS 26.0+ required for Apple on-device transcription"))
                    return
                }

                // Reuse existing analyzer or create new one
                if appleSpeechAnalyzer == nil {
                    let analyzer = AppleSpeechAnalyzerManager()
                    analyzer.delegate = self
                    appleSpeechAnalyzer = analyzer
                    Logger.log("Initialized for on-device transcription", context: "SpeechAnalyzer", level: .info)
                } else {
                    Logger.log("Reusing existing analyzer instance", context: "SpeechAnalyzer", level: .debug)
                }

                // Update cached reference for audio thread
                cachedSpeechAnalyzer = appleSpeechAnalyzer
                Logger.log("Cached analyzer for audio thread - \(cachedSpeechAnalyzer != nil ? "SUCCESS" : "FAILED")", context: "Audio", level: .debug)

                // Start analyzer session and wait for format
                Task {
                    do {
                        if let analyzer = appleSpeechAnalyzer as? AppleSpeechAnalyzerManager {
                            let languageSetting = Settings.shared.transcriptionLanguage
                            let locale: Locale = languageSetting.isEmpty ? .current : Locale(identifier: languageSetting)

                            // Start session and get recommended format
                            let format = try await analyzer.startSession(locale: locale)
                            speechAnalyzerFormat = format
                            Logger.log("Session started with format \(format.sampleRate)Hz", context: "SpeechAnalyzer", level: .info)

                            // Now start audio engine with the recommended format
                            await MainActor.run {
                                startAudioEngineAndTap()
                            }
                        }
                    } catch {
                        await MainActor.run {
                            self.delegate?.audioManager(didReceiveError: AudioManagerError.recordingFailed("SpeechAnalyzer error: \(error.localizedDescription)"))
                        }
                    }
                }
            } else if provider == .parakeet {
                // Parakeet CoreML mode - initialize manager first
                guard #available(macOS 14.0, *) else {
                    delegate?.audioManager(didReceiveError: AudioManagerError.recordingFailed("macOS 14.0+ required for Parakeet transcription"))
                    return
                }

                // Check if VAD is enabled for streaming mode
                let useVAD = Settings.shared.enableVAD

                if useVAD {
                    Logger.log("Using VAD streaming mode", context: "Parakeet", level: .info)

                    // Ensure VAD is initialized (lazy initialization)
                    if vadManager == nil {
                        Logger.log("Initializing on-demand for streaming mode", context: "VAD", level: .info)
                        Task {
                            do {
                                try await setupVADManager()
                                Logger.log("Initialization complete, starting listening", context: "VAD", level: .info)
                                await MainActor.run {
                                    self.vadManager?.startListening()
                                    self.cachedVADManager = self.vadManager
                                }
                            } catch {
                                Logger.log("Initialization failed, disabling VAD mode: \(error.localizedDescription)", context: "VAD", level: .warning)
                                // Continue without VAD - will use batch mode
                            }
                        }
                    } else {
                        // VAD already initialized, start immediately
                        vadManager?.startListening()
                        cachedVADManager = vadManager
                    }
                }

                // Reuse existing manager or create new one
                if parakeetManager == nil {
                    let manager = ParakeetTranscriptionManager()
                    manager.delegate = self
                    parakeetManager = manager
                    Logger.log("Initialized for on-device transcription", context: "Parakeet", level: .info)

                    // Initialize models asynchronously (downloads if needed)
                    Task {
                        do {
                            try await manager.initializeModels()
                            Logger.log("Models initialized, starting session", context: "Parakeet", level: .info)

                            // Set format for audio engine
                            guard let parakeetFormat = AVAudioFormat(
                                commonFormat: .pcmFormatFloat32,
                                sampleRate: 16000,
                                channels: 1,
                                interleaved: false
                            ) else {
                                await MainActor.run {
                                    self.delegate?.audioManager(didReceiveError: AudioManagerError.recordingFailed("Failed to create Parakeet audio format"))
                                }
                                return
                            }

                            // Start session only for batch mode
                            if !useVAD {
                                let _ = try await manager.startSession()
                                await MainActor.run {
                                    self.parakeetFormat = parakeetFormat
                                    self.cachedParakeetManager = self.parakeetManager
                                    Logger.log("Session started with format \(parakeetFormat.sampleRate)Hz", context: "Parakeet", level: .info)
                                    self.startAudioEngineAndTap()
                                }
                            } else {
                                // VAD mode - no session needed, just set format and cache manager
                                await MainActor.run {
                                    self.parakeetFormat = parakeetFormat
                                    self.cachedParakeetManager = self.parakeetManager
                                    Logger.log("Ready for VAD streaming with format \(parakeetFormat.sampleRate)Hz", context: "Parakeet", level: .info)
                                    self.startAudioEngineAndTap()
                                }
                            }
                        } catch {
                            await MainActor.run {
                                self.delegate?.audioManager(didReceiveError: AudioManagerError.recordingFailed("Parakeet error: \(error.localizedDescription)"))
                            }
                        }
                    }
                } else {
                    Logger.log("Reusing existing manager instance", context: "Parakeet", level: .debug)

                    // Start new session with existing manager
                    Task {
                        do {
                            if let manager = parakeetManager as? ParakeetTranscriptionManager {
                                // Create format for audio engine
                                guard let parakeetFormat = AVAudioFormat(
                                    commonFormat: .pcmFormatFloat32,
                                    sampleRate: 16000,
                                    channels: 1,
                                    interleaved: false
                                ) else {
                                    await MainActor.run {
                                        self.delegate?.audioManager(didReceiveError: AudioManagerError.recordingFailed("Failed to create Parakeet audio format"))
                                    }
                                    return
                                }

                                if !useVAD {
                                    // Batch mode - start session
                                    let _ = try await manager.startSession()
                                    await MainActor.run {
                                        self.parakeetFormat = parakeetFormat
                                        self.cachedParakeetManager = self.parakeetManager
                                        Logger.log("Session started with format \(parakeetFormat.sampleRate)Hz", context: "Parakeet", level: .info)
                                        self.startAudioEngineAndTap()
                                    }
                                } else {
                                    // VAD mode - no session needed, just set format
                                    await MainActor.run {
                                        self.parakeetFormat = parakeetFormat
                                        self.cachedParakeetManager = self.parakeetManager
                                        Logger.log("Ready for VAD streaming with format \(parakeetFormat.sampleRate)Hz", context: "Parakeet", level: .info)
                                        self.startAudioEngineAndTap()
                                    }
                                }
                            }
                        } catch {
                            await MainActor.run {
                                self.delegate?.audioManager(didReceiveError: AudioManagerError.recordingFailed("Parakeet error: \(error.localizedDescription)"))
                            }
                        }
                    }
                }
            }
        } else {
            // Cloud API mode - initialize VAD if enabled
            if Settings.shared.enableVAD {
                // Ensure VAD is initialized (lazy initialization)
                if vadManager == nil {
                    Logger.log("Initializing on-demand for cloud streaming mode", context: "VAD", level: .info)
                    Task {
                        do {
                            try await setupVADManager()
                            Logger.log("Initialization complete, starting listening", context: "VAD", level: .info)
                            await MainActor.run {
                                self.vadManager?.startListening()
                                self.cachedVADManager = self.vadManager
                            }
                        } catch {
                            Logger.log("Initialization failed, disabling VAD mode: \(error.localizedDescription)", context: "VAD", level: .warning)
                            // Continue without VAD - will use batch mode
                        }
                    }
                } else {
                    // VAD already initialized, start immediately
                    vadManager?.startListening()
                    cachedVADManager = vadManager
                }
            }
            // Start audio engine immediately for cloud mode
            startAudioEngineAndTap()
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
            // Use Parakeet's format (16kHz mono Float32)
            optimizedFormat = parakeetFormat
            Logger.log("Using Parakeet format - \(parakeetFormat.sampleRate)Hz, \(parakeetFormat.channelCount) channels", context: "Audio", level: .debug)
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

        // Debug: Log routing decision (once at start)
        struct OnceToken { static var didLog = false }
        if !OnceToken.didLog {
            OnceToken.didLog = true
            Logger.log("Routing: VAD=\(cachedEnableVAD), OnDevice=\(cachedIsOnDevice), VADMgr=\(cachedVADManager != nil), Analyzer=\(cachedSpeechAnalyzer != nil), Parakeet=\(cachedParakeetManager != nil)", context: "Audio", level: .debug)
        }

        // Route buffers based on cached provider settings (no MainActor access)
        // Priority: VAD (if enabled) > On-device > Batch recording
        if cachedEnableVAD, let vadManager = cachedVADManager {
            // VAD mode - works with both cloud and on-device providers
            // Process buffer through VAD for real-time speech detection and streaming transcription
            // VADManager is @MainActor, so dispatch to MainActor
            Task { @MainActor in
                vadManager.processAudioBuffer(optimizedBuffer)
            }
        } else if cachedIsOnDevice {
            // On-device batch mode (no VAD) - feed buffers directly to on-device manager
            // Apple SpeechAnalyzer mode - feed buffer directly to analyzer
            if #available(macOS 26.0, *) {
                if let analyzer = cachedSpeechAnalyzer as? AppleSpeechAnalyzerManager {
                    Task { @MainActor in
                        analyzer.feedAudio(optimizedBuffer)
                    }
                } else if let manager = cachedParakeetManager as? ParakeetTranscriptionManager {
                    // Parakeet mode - feed buffer to manager
                    Task { @MainActor in
                        manager.feedAudio(optimizedBuffer)
                    }
                } else {
                    Logger.log("WARNING - No on-device manager available", context: "Audio", level: .warning)
                }
            } else if let manager = cachedParakeetManager as? ParakeetTranscriptionManager {
                // Parakeet mode (macOS 15-25) - feed buffer to manager
                Task { @MainActor in
                    manager.feedAudio(optimizedBuffer)
                }
            }
        } else {
            // Cloud API batch mode (no VAD) - traditional recording: store all audio for batch processing
            audioBuffers.append(optimizedBuffer)

            // Log every 50 buffers to track progress
            if audioBuffers.count % 50 == 0 {
                let totalFrames = audioBuffers.reduce(0) { $0 + Int($1.frameLength) }
                Logger.log("Captured \(audioBuffers.count) buffers (\(totalFrames) frames total)", context: "Audio", level: .debug)
            }
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

        // Handle provider-specific cleanup
        // Priority: Check provider first (Apple never uses VAD)
        if provider == .apple {
            // Apple SpeechAnalyzer mode (never uses external VAD)
            if #available(macOS 26.0, *) {
                stopAppleSpeechAnalyzerSession()
            }
        } else if Settings.shared.enableVAD && provider != .apple {
            // VAD mode (works with Parakeet and cloud providers)
            // Streaming transcription already handled, just stop VAD
            vadManager?.stopListening()
            audioBuffers.removeAll()
        } else if provider.isOnDevice {
            // Other on-device modes (Parakeet batch mode)
            if provider == .parakeet {
                stopParakeetSession()
            }
        } else {
            // Cloud API batch mode (no VAD): process collected audio buffers
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
        // Stop Parakeet session and process audio
        // Keep manager instance alive for reuse
        if let manager = parakeetManager as? ParakeetTranscriptionManager {
            Task { @MainActor in
                await manager.stopSession()
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

    private func performStreamingTranscription(audioData: Data, duration: Double) async {
        // Skip transcription if already processing to avoid overwhelming API
        if self.isProcessingTranscription {
            Logger.log("Skipping chunk transcription - already processing", context: "VAD", level: .debug)
            return
        }

        self.isProcessingTranscription = true

        guard let service = self.transcriptionService else {
            self.delegate?.audioManager(didReceiveError: AudioManagerError.transcriptionServiceMissing)
            self.isProcessingTranscription = false
            return
        }

        do {
            let selectedModel = Settings.shared.transcriptionModel
            let languageSetting = Settings.shared.transcriptionLanguage
            let language = languageSetting.isEmpty ? nil : languageSetting

            let response = try await service.transcribe(
                audioData: audioData,
                fileName: "chunk_\(UUID().uuidString).wav",
                model: selectedModel,
                language: language,
                prompt: nil,
                responseFormat: "json",
                temperature: nil,
                timestampGranularities: nil
            )

            // Stream the text - append to existing content instead of replacing
            await self.pasteManager.appendStreamingText(
                response.text, withAI: self.wasShiftPressedOnStart)
            self.isProcessingTranscription = false

        } catch let error as TranscriptionError {
            self.delegate?.audioManager(didReceiveError: error)
            self.isProcessingTranscription = false
        } catch {
            self.delegate?.audioManager(
                didReceiveError: AudioManagerError.transcriptionFailed(
                    error.localizedDescription))
            self.isProcessingTranscription = false
        }
    }

    private func performParakeetStreamingTranscription(audioSamples: [Float], duration: Double) async {
        // Skip transcription if already processing
        if self.isProcessingTranscription {
            Logger.log("Skipping chunk transcription - already processing", context: "Parakeet", level: .debug)
            return
        }

        self.isProcessingTranscription = true

        // Get Parakeet manager
        guard let manager = self.parakeetManager as? ParakeetTranscriptionManager else {
            self.isProcessingTranscription = false
            return
        }

        Logger.log("Transcribing chunk with \(audioSamples.count) samples", context: "Parakeet", level: .debug)

        // Transcribe the chunk (this calls the delegate internally)
        let _ = await manager.transcribeChunk(audioSamples)

        self.isProcessingTranscription = false
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

// MARK: - VADManagerDelegate

@MainActor
extension AudioManager: VADManagerDelegate {

    func vadManagerDidStartListening() {
        Logger.log("Started listening for speech", context: "VAD", level: .debug)
    }

    func vadManagerDidStopListening() {
        Logger.log("Stopped listening for speech", context: "VAD", level: .debug)
    }

    func vadManagerDidDetectSpeechStart() {
        Logger.log("Speech started", context: "VAD", level: .debug)
        // In streaming mode, the VADManager handles all audio collection
        // No need to manage buffers here - just for UI feedback
        delegate?.audioManagerDidStartRecording()
    }

    func vadManagerDidDetectSpeechEnd() {
        Logger.log("Speech ended", context: "VAD", level: .debug)

        // In streaming mode, don't finalize recording - just wait for next speech
        // The VADManager will handle generating audio chunks automatically
        // Recording will continue until the user releases the button
    }

    func vadManager(didCompleteAudioSamples samples: [Float], duration: Double) {
        // New Float samples method - direct transcription for on-device providers
        Logger.log("Processing Float samples (\(samples.count) samples, \(String(format: "%.2f", duration))s)", context: "VAD", level: .debug)

        // Skip very short chunks
        guard duration >= 0.5 else {
            Logger.log("Chunk too short (\(String(format: "%.2f", duration))s), skipping", context: "VAD", level: .debug)
            return
        }

        let provider = Settings.shared.transcriptionProvider

        // Route to on-device transcription (Parakeet)
        if provider == .parakeet {
            Task {
                await performParakeetStreamingTranscription(audioSamples: samples, duration: duration)
            }
        }
    }

    func vadManager(didCompleteAudioChunk audioData: Data, duration: Double) {
        // WAV data method - for cloud APIs
        Logger.log("Processing audio chunk (\(audioData.count) bytes, \(String(format: "%.2f", duration))s)", context: "VAD", level: .debug)

        // Skip very short chunks to avoid API waste
        guard duration >= 0.5 else {
            Logger.log("Chunk too short (\(String(format: "%.2f", duration))s), skipping", context: "VAD", level: .debug)
            return
        }

        let provider = Settings.shared.transcriptionProvider

        // Route to cloud APIs only (Parakeet uses Float samples now)
        if provider != .parakeet && !provider.isOnDevice {
            Task {
                await performStreamingTranscription(audioData: audioData, duration: duration)
            }
        }
    }

    func vadManager(didEncounterError error: VADError) {
        Logger.log("Error: \(error.localizedDescription)", context: "VAD", level: .error)

        // Fall back to traditional recording on VAD error
        delegate?.audioManager(didReceiveError: AudioManagerError.recordingFailed("VAD error: \(error.localizedDescription)"))
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

    func parakeet(didReceivePartialTranscription text: String) async {
        Logger.log("Partial transcription - '\(text)'", context: "Parakeet", level: .debug)

        // Stream the text - append to existing content instead of replacing
        await self.pasteManager.appendStreamingText(text, withAI: self.wasShiftPressedOnStart)
    }

    func parakeet(didReceiveFinalTranscription text: String) async {
        Logger.log("Final transcription - '\(text)'", context: "Parakeet", level: .info)

        // Process and paste the text
        await self.pasteManager.processAndPasteText(text, withAI: self.wasShiftPressedOnStart)
    }

    func parakeetWillDownloadModels() async {
        Logger.log("Downloading models...", context: "Parakeet", level: .info)

        // Show download status in menu bar (minimalist native UX)
        await MainActor.run {
            AppDelegate.shared?.showDownloadStatus(message: "Downloading Parakeet models (600MB)...")
        }

        // Also send notification for background awareness
        let content = UNMutableNotificationContent()
        content.title = "Omri"
        content.body = "Downloading Parakeet language model (600MB)..."
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "parakeet-model-download",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.log("Failed to show download notification: \(error.localizedDescription)", context: "Parakeet", level: .warning)
        }
    }

    func parakeetDidDownloadModels() async {
        Logger.log("Models download complete", context: "Parakeet", level: .info)

        // Hide download status
        await MainActor.run {
            AppDelegate.shared?.hideDownloadStatus()
        }

        // Notify user that download completed
        let content = UNMutableNotificationContent()
        content.title = "Omri"
        content.body = "Parakeet model downloaded. On-device transcription ready!"
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "parakeet-model-complete",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.log("Failed to show completion notification: \(error.localizedDescription)", context: "Parakeet", level: .warning)
        }
    }

    func parakeet(didEncounterError error: ParakeetError) async {
        Logger.log("Error - \(error.localizedDescription)", context: "Parakeet", level: .error)
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
