//
//  ModelDownloadManager.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Flexible manager for on-device model downloads (Parakeet, Apple SpeechAnalyzer, etc.)
//

import Foundation
import SwiftUI

// MARK: - Downloadable Model Protocol

/// Protocol for any downloadable on-device model
@MainActor
protocol DownloadableModel: Identifiable {
    /// Unique identifier for the model
    var id: String { get }

    /// Display name for UI
    var displayName: String { get }

    /// Short description of the model
    var description: String { get }

    /// Estimated download size
    var estimatedSize: String { get }

    /// Platform availability
    var isAvailable: Bool { get }

    /// Storage path for model files (for cleanup)
    var storagePath: String { get }

    /// Check if model is already downloaded
    func isDownloaded() async -> Bool

    /// Download and initialize the model
    func download() async throws
}

// MARK: - Model Download State

enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading
    case downloaded
    case error(String)

    static func == (lhs: ModelDownloadState, rhs: ModelDownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.notDownloaded, .notDownloaded),
             (.downloading, .downloading),
             (.downloaded, .downloaded):
            return true
        case (.error(let lhs), .error(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

// MARK: - Parakeet Model Implementation

@available(macOS 14.0, iOS 17.0, *)
struct ParakeetModel: DownloadableModel {
    let id = "parakeet-tdt-v3"
    let displayName = "Parakeet TDT v3"
    let description = "Multilingual speech recognition (25 languages) • NVIDIA CC-BY 4.0"
    let estimatedSize = "~600 MB"

    var isAvailable: Bool {
        #if canImport(FluidAudio)
        return true
        #else
        return false
        #endif
    }

    var storagePath: String {
        "FluidAudio/Models/parakeet-tdt-0.6b-v3-coreml"
    }

    @MainActor
    func isDownloaded() async -> Bool {
        #if canImport(FluidAudio)
        // Check if model files exist WITHOUT triggering download
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return false
        }

        let modelPath = appSupportURL.appendingPathComponent(storagePath)

        // Check if the model directory exists and contains required files
        let configPath = modelPath.appendingPathComponent("config.json")
        return fileManager.fileExists(atPath: configPath.path)
        #else
        return false
        #endif
    }

    @MainActor
    func download() async throws {
        #if canImport(FluidAudio)
        let manager = ParakeetTranscriptionManager()
        try await manager.initializeModels()
        #else
        throw ModelDownloadError.platformNotSupported
        #endif
    }
}

// MARK: - Model Download Manager

@available(macOS 14.0, iOS 17.0, *)
@Observable
@MainActor
class ModelDownloadManager {
    // MARK: - State

    /// Download state for each model (keyed by model.id)
    var modelStates: [String: ModelDownloadState] = [:]

    /// Available models for download
    var availableModels: [any DownloadableModel] = []

    // MARK: - Singleton

    static let shared = ModelDownloadManager()

    private init() {
        // Register available models
        registerModels()

        // Don't check on init - only check when UI is shown
        // This prevents automatic downloads on app launch
    }

    // MARK: - Model Registration

    private func registerModels() {
        // Register Parakeet model
        availableModels.append(ParakeetModel())

        // Future: Register other models here
        // availableModels.append(AppleSpeechAnalyzerModel())
        // availableModels.append(WhisperLocalModel())
    }

    // MARK: - Status Checking

    /// Check download status for all models
    func checkAllModelsStatus() async {
        for model in availableModels {
            guard model.isAvailable else {
                modelStates[model.id] = .error("Not available on this platform")
                continue
            }

            // Skip checking if currently downloading
            if modelStates[model.id] == .downloading {
                continue
            }

            // Check file existence for all other states (including .downloaded to detect manual deletion)
            let downloaded = await model.isDownloaded()
            modelStates[model.id] = downloaded ? .downloaded : .notDownloaded
        }
    }

    /// Check status for a specific model
    func checkModelStatus(_ modelId: String) async {
        guard let model = availableModels.first(where: { $0.id == modelId }) else { return }

        let downloaded = await model.isDownloaded()
        modelStates[modelId] = downloaded ? .downloaded : .notDownloaded
    }

    // MARK: - Download Management

    /// Download a specific model
    func downloadModel(_ modelId: String) async {
        guard let model = availableModels.first(where: { $0.id == modelId }) else {
            modelStates[modelId] = .error("Model not found")
            return
        }

        // Prevent concurrent downloads
        if modelStates[modelId] == .downloading {
            return
        }

        // Don't re-download if already downloaded
        if modelStates[modelId] == .downloaded {
            return
        }

        modelStates[modelId] = .downloading

        do {
            try await model.download()
            modelStates[modelId] = .downloaded

        } catch {
            // Provide user-friendly error messages
            let errorMessage = parseDownloadError(error)
            modelStates[modelId] = .error(errorMessage)
        }
    }

    /// Parse download errors into user-friendly messages
    private func parseDownloadError(_ error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()

        if errorString.contains("couldn't be moved") || errorString.contains("couldn't be opened") {
            return "Download incomplete. Try clearing models and retry."
        } else if errorString.contains("no such file") {
            return "Download failed. Clear models and retry."
        } else if errorString.contains("network") || errorString.contains("internet") {
            return "Network error. Check connection and retry."
        } else if errorString.contains("space") || errorString.contains("disk") {
            return "Not enough disk space (~600MB needed)"
        } else {
            return "Download failed. Clear models and retry."
        }
    }

    /// Reset state for a specific model (allows retry)
    func resetModel(_ modelId: String) {
        modelStates[modelId] = .notDownloaded
    }

    /// Clear partial/corrupted downloads for a model
    func clearModel(_ modelId: String) {
        // Get the model to access its storage path
        guard let model = availableModels.first(where: { $0.id == modelId }) else {
            return
        }

        // Clear the model directory if it exists
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        // Use model-specific storage path (dynamic, not hardcoded)
        let modelPath = appSupportURL.appendingPathComponent(model.storagePath)

        do {
            if fileManager.fileExists(atPath: modelPath.path) {
                try fileManager.removeItem(at: modelPath)
            }
        } catch {
            // Ignore errors, best effort cleanup
        }

        // Reset state
        resetModel(modelId)
    }

    /// Get state for a specific model
    func state(for modelId: String) -> ModelDownloadState {
        return modelStates[modelId] ?? .notDownloaded
    }
}

// MARK: - Errors

enum ModelDownloadError: LocalizedError {
    case platformNotSupported
    case modelNotFound

    var errorDescription: String? {
        switch self {
        case .platformNotSupported:
            return "This model is not available on your platform"
        case .modelNotFound:
            return "Model not found"
        }
    }
}
