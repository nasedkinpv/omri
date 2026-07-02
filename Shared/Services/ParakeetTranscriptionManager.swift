//
//  ParakeetTranscriptionManager.swift
//  Omri
//
//  Stored provider value is still "Parakeet (On-Device)" for migration.
//  Implementation uses FluidAudio Nemotron multilingual streaming ASR.
//

import Foundation
import AVFAudio
import FluidAudio

@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class ParakeetTranscriptionManager: OnDeviceTranscriptionManager {
    private let chunkMs = 1120
    private var manager: StreamingNemotronMultilingualAsrManager?
    private var isActive = false
    private var partialText = ""
    private var feedTasks: [Task<Void, Never>] = []
    private var fedBufferCount = 0

    weak var delegate: ParakeetTranscriptionDelegate?

    var isInitialized: Bool { manager != nil }
    var isInStreamingMode: Bool { isActive }

    func initializeModels() async throws {
        guard manager == nil else { return }

        Logger.log("Initializing Nemotron models...", context: "Nemotron", level: .info)
        await delegate?.parakeetWillDownloadModels()

        let language = Settings.shared.onDeviceLanguage
        let loaded = try await StreamingNemotronMultilingualAsrManager.downloadAndPreloadShared(
            languageCode: language,
            chunkMs: chunkMs,
            progressHandler: { progress in
                Logger.log("Nemotron download progress: \(Int(progress.fractionCompleted * 100))%", context: "Nemotron", level: .debug)
            }
        )

        let manager = StreamingNemotronMultilingualAsrManager()
        try await manager.loadFromShared(loaded)
        self.manager = manager

        Logger.log("Nemotron models ready", context: "Nemotron", level: .info)
        await delegate?.parakeetDidDownloadModels()
    }

    func areModelsDownloaded() async -> Bool {
        do {
            _ = try await StreamingNemotronMultilingualAsrManager.downloadVariant(
                languageCode: Settings.shared.onDeviceLanguage,
                chunkMs: chunkMs
            )
            return true
        } catch {
            return false
        }
    }

    func startSession(locale: Locale = .current) async throws -> AVAudioFormat {
        guard !isActive else { throw ParakeetError.sessionAlreadyActive }
        guard let manager else { throw ParakeetError.modelsNotInitialized }
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false) else {
            throw ParakeetError.audioFormatCreationFailed
        }

        partialText = ""
        feedTasks.removeAll()
        fedBufferCount = 0
        await manager.reset()
        await manager.setLanguage(Settings.shared.onDeviceLanguage)
        await manager.setPartialCallback { [weak self] text in
            Task { @MainActor in
                let cleaned = Self.cleanTranscript(text)
                guard let self, cleaned != self.partialText else { return }
                self.partialText = cleaned
                await self.delegate?.parakeet(didReceiveVolatileTranscription: cleaned)
            }
        }

        isActive = true
        Logger.log("Nemotron session started", context: "Nemotron", level: .info)
        return format
    }

    func startStreamingSession(locale: Locale = .current) async throws -> AVAudioFormat {
        try await startSession(locale: locale)
    }

    func feedAudio(_ buffer: AVAudioPCMBuffer) {
        guard isActive, let manager else { return }
        fedBufferCount += 1
        let task = Task {
            do {
                _ = try await manager.process(audioBuffer: buffer)
            } catch {
                await delegate?.parakeet(didEncounterError: .audioProcessingFailed(error.localizedDescription))
            }
        }
        feedTasks.append(task)
    }

    @discardableResult
    func stopSession() async -> String? {
        guard isActive, let manager else { return nil }
        isActive = false

        for task in feedTasks {
            await task.value
        }
        feedTasks.removeAll()

        do {
            Logger.log("Finishing Nemotron session after \(fedBufferCount) audio buffers", context: "Nemotron", level: .debug)
            let text = Self.cleanTranscript(try await manager.finish())
            let detected = await manager.detectedLanguage() ?? "unknown"
            Logger.log("Nemotron final (\(detected)): '\(text)'", context: "Nemotron", level: .info)
            await manager.reset()
            if !text.isEmpty {
                await delegate?.parakeet(didReceiveFinalTranscription: text)
            }
            return text
        } catch {
            Logger.log("Nemotron finish failed: \(error.localizedDescription)", context: "Nemotron", level: .error)
            await delegate?.parakeet(didEncounterError: .transcriptionFailed(error.localizedDescription))
            await manager.reset()
            return nil
        }
    }

    private static func cleanTranscript(_ text: String) -> String {
        text.replacingOccurrences(of: "<unk>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
protocol ParakeetTranscriptionDelegate: AnyObject {
    func parakeet(didReceivePartialTranscription text: String) async
    func parakeet(didReceiveVolatileTranscription text: String) async
    func parakeet(didReceiveConfirmedTranscription text: String) async
    func parakeet(didReceiveFinalTranscription text: String) async
    func parakeetWillDownloadModels() async
    func parakeetDidDownloadModels() async
    func parakeet(didEncounterError error: ParakeetError) async
}

enum ParakeetError: LocalizedError {
    case modelsNotInitialized
    case sessionAlreadyActive
    case audioFormatCreationFailed
    case audioProcessingFailed(String)
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelsNotInitialized:
            return "Nemotron models are not initialized. Please wait for model download to complete."
        case .sessionAlreadyActive:
            return "A Nemotron transcription session is already active"
        case .audioFormatCreationFailed:
            return "Failed to create audio format for Nemotron transcription"
        case .audioProcessingFailed(let reason):
            return "Nemotron audio processing failed: \(reason)"
        case .transcriptionFailed(let reason):
            return "Nemotron transcription failed: \(reason)"
        }
    }
}
