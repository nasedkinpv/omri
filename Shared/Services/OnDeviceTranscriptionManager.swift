//
//  OnDeviceTranscriptionManager.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Protocol for on-device transcription managers (Parakeet, Apple SpeechAnalyzer)
//  Eliminates need for type erasure with Any?
//

import Foundation
import AVFAudio

/// Protocol for on-device transcription managers
/// Provides common interface for Parakeet and Apple SpeechAnalyzer
@MainActor
protocol OnDeviceTranscriptionManager: AnyObject {
    /// Start a transcription session
    /// - Parameter locale: Optional language locale for transcription (default: .current)
    /// - Returns: The recommended audio format for this transcriber
    func startSession(locale: Locale) async throws -> AVAudioFormat

    /// Stop the transcription session
    /// - Returns: Optional final transcription text (for streaming mode)
    @discardableResult
    func stopSession() async -> String?

    /// Feed audio buffer for transcription
    /// - Parameter buffer: PCM audio buffer in the format returned by startSession()
    func feedAudio(_ buffer: AVAudioPCMBuffer)

    /// Check if the manager is initialized and ready
    var isInitialized: Bool { get }
}

/// Extension to provide default implementation for optional methods
extension OnDeviceTranscriptionManager {
    var isInitialized: Bool { true }

    /// Default implementation of startSession without locale parameter
    /// Calls the locale-based version with .current
    func startSession() async throws -> AVAudioFormat {
        return try await startSession(locale: .current)
    }
}
