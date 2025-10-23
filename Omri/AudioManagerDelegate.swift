//
//  AudioManagerDelegate.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//
//

@MainActor  // Mark the protocol as @MainActor
protocol AudioManagerDelegate: AnyObject {
    func audioManagerDidStartRecording()
    func audioManagerDidStopRecording()
    func audioManagerWillStartNetworkProcessing()  // New method
    func audioManager(didReceiveError error: Error)
}
