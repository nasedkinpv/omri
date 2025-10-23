//
//  AppleSpeechAnalyzerManager.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Manages SpeechAnalyzer lifecycle for on-device transcription

import Foundation
import AVFAudio
import Speech

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

@available(macOS 26.0, *)
@MainActor
class AppleSpeechAnalyzerManager: OnDeviceTranscriptionManager {
    // MARK: - Properties

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var analyzerFormat: AVAudioFormat?

    private var resultConsumerTask: Task<Void, Never>?

    weak var delegate: AppleSpeechAnalyzerDelegate?

    private var isActive = false
    private var isFinishing = false  // Track when audio input is finishing

    // Audio stream continuation for feeding audio buffers
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?

    // Track latest transcription for batch mode
    private var lastPartialText: String = ""

    // MARK: - Lifecycle

    init() {}

    deinit {
        // Cancel result consumer task - deinit cannot be async
        resultConsumerTask?.cancel()
    }

    // MARK: - Session Management

    /// Start a transcription session with streaming audio input
    /// - Parameters:
    ///   - locale: Language locale for transcription
    /// - Returns: The recommended audio format for the transcriber
    func startSession(locale: Locale = .current) async throws -> AVAudioFormat {
        // If session is already active, stop it first to start fresh
        if isActive {
            Logger.log("Session already active, waiting for previous results to complete...", context: "SpeechAnalyzer", level: .warning)

            // Give a brief moment for any pending results to be processed
            // SpeechAnalyzer emits results asynchronously after finishAudioInput()
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

            Logger.log("Stopping previous session", context: "SpeechAnalyzer", level: .info)
            await stopSession()
        }

        // Get supported locale (exact match from Apple's installed locales)
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw SpeechAnalyzerError.languageModelDownloadFailed("No supported locale found for \(locale.identifier)")
        }
        Logger.log("Using supported locale: \(supportedLocale.identifier)", context: "SpeechAnalyzer", level: .info)

        // Check for language model availability
        try await ensureLanguageModelAvailable(for: supportedLocale)

        // Create transcriber with real-time configuration
        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],  // Enable real-time partial results
            attributeOptions: [.audioTimeRange]    // Include timing information
        )
        Logger.log("Created transcriber with volatileResults enabled", context: "SpeechAnalyzer", level: .info)
        self.transcriber = transcriber

        // Create analyzer
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer

        // Get recommended audio format for this transcriber
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw SpeechAnalyzerError.audioProcessingFailed("Failed to get recommended audio format")
        }
        self.analyzerFormat = format
        Logger.log("Recommended format - \(format.sampleRate)Hz, \(format.channelCount) channels, \(format.commonFormat.rawValue)", context: "SpeechAnalyzer", level: .debug)

        // Create audio input stream
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = continuation

        Logger.log("Starting session for locale \(supportedLocale.identifier)", context: "SpeechAnalyzer", level: .info)

        isActive = true
        isFinishing = false
        lastPartialText = ""  // Reset for new session

        // Start consuming results (concurrent task)
        startConsumingResults()

        // Start analyzer with input stream (runs autonomously in its own task)
        do {
            try await analyzer.start(inputSequence: stream)
            Logger.log("Analyzer started successfully", context: "SpeechAnalyzer", level: .info)
        } catch {
            cleanup()
            throw SpeechAnalyzerError.audioProcessingFailed("Failed to start analyzer: \(error.localizedDescription)")
        }

        Logger.log("Session setup complete", context: "SpeechAnalyzer", level: .info)
        return format
    }

    /// Feed an audio buffer to the analyzer
    /// - Parameter buffer: Audio buffer in the format returned by startSession()
    func feedAudio(_ buffer: AVAudioPCMBuffer) {
        guard isActive else {
            Logger.log("Cannot feed audio - session not active", context: "SpeechAnalyzer", level: .warning)
            return
        }

        guard let continuation = inputContinuation else {
            Logger.log("WARNING - No input continuation available", context: "SpeechAnalyzer", level: .warning)
            return
        }

        // Debug: Log first buffer
        struct OnceToken { static var didLog = false }
        if !OnceToken.didLog {
            OnceToken.didLog = true
            Logger.log("Feeding audio buffers to analyzer (\(buffer.frameLength) frames)", context: "SpeechAnalyzer", level: .debug)
        }

        let input = AnalyzerInput(buffer: buffer)
        continuation.yield(input)
    }

    /// Signal end of audio input
    func finishAudioInput() {
        isFinishing = true
        inputContinuation?.finish()
        inputContinuation = nil
        Logger.log("Audio input finished, waiting for final results...", context: "SpeechAnalyzer", level: .info)
    }

    /// Stop the current transcription session
    func stopSession() async {
        guard isActive else { return }

        Logger.log("Stopping session", context: "SpeechAnalyzer", level: .info)

        // Cancel result consumer task
        resultConsumerTask?.cancel()

        // Finalize analyzer to get remaining results
        if let analyzer = analyzer {
            await analyzer.cancelAndFinishNow()
        }

        // Clean up all resources
        cleanup()

        Logger.log("Session stopped", context: "SpeechAnalyzer", level: .info)
    }

    // MARK: - Result Consumption

    private func startConsumingResults() {
        guard let transcriber = transcriber else { return }
        let delegate = self.delegate

        resultConsumerTask = Task {
            do {
                Logger.log("Starting to consume results from transcriber...", context: "SpeechAnalyzer", level: .debug)
                var resultCount = 0

                for try await result in transcriber.results {
                    guard !Task.isCancelled else {
                        Logger.log("Result consumer task cancelled", context: "SpeechAnalyzer", level: .debug)
                        break
                    }

                    resultCount += 1

                    // Process transcription result and store last transcription
                    await self.handleTranscriptionResult(result, delegate: delegate)
                }

                Logger.log("Results stream completed (total: \(resultCount) results)", context: "SpeechAnalyzer", level: .info)

                // Batch mode: Send complete text with all refinements
                // Apple continues refining after segment boundaries, so batch mode is more reliable
                if !lastPartialText.isEmpty {
                    Logger.log("Final result - '\(lastPartialText)'", context: "SpeechAnalyzer", level: .info)
                    await delegate?.speechAnalyzer(didReceiveFinalTranscription: lastPartialText)
                } else {
                    Logger.log("No transcription results", context: "SpeechAnalyzer", level: .warning)
                }
            } catch {
                if !Task.isCancelled {
                    Logger.log("Error consuming results - \(error.localizedDescription)", context: "SpeechAnalyzer", level: .error)
                }
            }
        }
    }

    private func handleTranscriptionResult(_ result: some Any, delegate: AppleSpeechAnalyzerDelegate?) async {
        // SpeechTranscriber.Result has:
        // - alternatives: [AttributedString] - array of possible transcriptions (first is most likely)
        // - range: CMTimeRange - timing information
        // - resultsFinalizationTime: CMTime
        let mirror = Mirror(reflecting: result)

        // Extract alternatives array (first alternative is the best transcription)
        guard let alternatives = mirror.children.first(where: { $0.label == "alternatives" })?.value as? [AttributedString],
              let firstAlternative = alternatives.first else {
            Logger.log("Unable to extract alternatives from result", context: "SpeechAnalyzer", level: .warning)
            return
        }

        let transcribedText = String(firstAlternative.characters)
        guard !transcribedText.isEmpty else { return }

        // Batch mode: Just track the latest text (includes all refinements)
        // Don't stream during recording - wait for final result
        lastPartialText = transcribedText

        // Log partials for debugging only
        Logger.log("Partial result - '\(transcribedText)'", context: "SpeechAnalyzer", level: .debug)
        await delegate?.speechAnalyzer(didReceivePartialTranscription: transcribedText)
    }

    // MARK: - Asset Management

    private func ensureLanguageModelAvailable(for locale: Locale) async throws {
        // Check if locale is already installed
        let installedLocales = await SpeechTranscriber.installedLocales

        Logger.log("Checking locale \(locale.identifier)", context: "SpeechAnalyzer", level: .debug)
        Logger.log("Installed locales: \(installedLocales.map { $0.identifier }.joined(separator: ", "))", context: "SpeechAnalyzer", level: .debug)

        // Check by identifier string instead of Locale equality (more reliable)
        let isInstalled = installedLocales.contains { $0.identifier == locale.identifier }

        if isInstalled {
            Logger.log("Language model for \(locale.identifier) already installed", context: "SpeechAnalyzer", level: .info)
            return
        }

        Logger.log("Language model for \(locale.identifier) not installed", context: "SpeechAnalyzer", level: .warning)

        // Notify delegate about download
        await delegate?.speechAnalyzerWillDownloadLanguageModel(for: locale)

        // Create temporary transcriber to get asset installation request
        let tempTranscriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )

        if let request = try await AssetInventory.assetInstallationRequest(supporting: [tempTranscriber]) {
            Logger.log("Downloading language model for \(locale.identifier)...", context: "SpeechAnalyzer", level: .info)
            try await request.downloadAndInstall()
            Logger.log("Language model download complete", context: "SpeechAnalyzer", level: .info)
            await delegate?.speechAnalyzerDidDownloadLanguageModel(for: locale)
        } else {
            Logger.log("No asset download required", context: "SpeechAnalyzer", level: .debug)
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        resultConsumerTask?.cancel()
        resultConsumerTask = nil
        inputContinuation?.finish()
        inputContinuation = nil
        transcriber = nil
        analyzer = nil
        analyzerFormat = nil
        isActive = false
        isFinishing = false
        lastPartialText = ""
    }
}

// MARK: - Delegate Protocol

@MainActor
protocol AppleSpeechAnalyzerDelegate: AnyObject {
    func speechAnalyzer(didReceivePartialTranscription text: String) async
    func speechAnalyzer(didReceiveFinalTranscription text: String) async
    func speechAnalyzerWillDownloadLanguageModel(for locale: Locale) async
    func speechAnalyzerDidDownloadLanguageModel(for locale: Locale) async
    func speechAnalyzer(didEncounterError error: SpeechAnalyzerError) async
}

// MARK: - Error Handling

enum SpeechAnalyzerError: LocalizedError {
    case audioProcessingFailed(String)
    case sessionAlreadyActive
    case noAnalyzerAvailable
    case languageModelDownloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .audioProcessingFailed(let reason):
            return "Audio processing failed: \(reason)"
        case .sessionAlreadyActive:
            return "A transcription session is already active"
        case .noAnalyzerAvailable:
            return "No speech analyzer is available"
        case .languageModelDownloadFailed(let reason):
            return "Language model download failed: \(reason)"
        }
    }
}