//
//  AudioRecorderDelegate.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//

import Foundation

@MainActor
protocol AudioRecorderDelegate: AnyObject {
    func audioRecorderDidStartRecording()
    func audioRecorderDidStopRecording()
    func audioRecorder(didReceiveError error: AudioRecorderError)
    func audioRecorder(didCompleteWithAudioData audioData: Data)
}

enum AudioRecorderError: LocalizedError {
    case microphoneAccessDenied
    case recordingFailed(String)
    case audioConversionFailed
    case noAudioData

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "Microphone access is required. Please enable it in Settings."
        case .recordingFailed(let reason):
            return "Failed to start recording: \(reason)"
        case .audioConversionFailed:
            return "Failed to convert audio data."
        case .noAudioData:
            return "No audio data was recorded."
        }
    }
}
