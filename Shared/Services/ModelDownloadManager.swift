//
//  ModelDownloadManager.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Download state for the on-device Nemotron model.
//  ponytail: single-model manager; reintroduce a model list if a second on-device model ever ships
//

import Foundation
import SwiftUI
import FluidAudio

enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading
    case downloaded
    case error(String)
}

@available(macOS 14.0, iOS 17.0, *)
@Observable
@MainActor
final class ModelDownloadManager {
    static let shared = ModelDownloadManager()

    let displayName = "Nemotron 3.5 ASR"
    let modelDescription = "On-device multilingual speech recognition (~40 languages)"
    let estimatedSize = "~600 MB"

    var state: ModelDownloadState = .notDownloaded

    private init() {}

    /// Must match ParakeetTranscriptionManager's variant selection (language + 1120ms tier)
    private var storagePath: String {
        let language = Settings.shared.onDeviceLanguage.lowercased()
        let variant = ["en", "es", "fr", "it", "pt", "de"].contains { language.hasPrefix($0) } ? "latin" : "multilingual"
        return "FluidAudio/Models/nemotron-multilingual/\(variant)/1120ms"
    }

    private var modelDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(storagePath)
    }

    /// Filesystem check only — never triggers a download
    func checkStatus() {
        guard state != .downloading else { return }
        guard let dir = modelDirectory else {
            state = .notDownloaded
            return
        }
        let metadata = dir.appendingPathComponent("metadata.json")
        state = FileManager.default.fileExists(atPath: metadata.path) ? .downloaded : .notDownloaded
    }

    func download() async {
        guard state != .downloading, state != .downloaded else { return }
        state = .downloading
        do {
            _ = try await StreamingNemotronMultilingualAsrManager.downloadVariant(
                languageCode: Settings.shared.onDeviceLanguage,
                chunkMs: 1120
            )
            state = .downloaded
        } catch {
            state = .error(Self.friendlyMessage(error))
        }
    }

    /// Remove downloaded/partial model files (best effort) and reset state
    func clear() {
        if let dir = modelDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
        state = .notDownloaded
    }

    private static func friendlyMessage(_ error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()
        if errorString.contains("couldn't be moved") || errorString.contains("couldn't be opened") || errorString.contains("no such file") {
            return "Download incomplete. Clear model and retry."
        } else if errorString.contains("network") || errorString.contains("internet") {
            return "Network error. Check connection and retry."
        } else if errorString.contains("space") || errorString.contains("disk") {
            return "Not enough disk space (~600MB needed)"
        } else {
            return "Download failed. Clear model and retry."
        }
    }
}
