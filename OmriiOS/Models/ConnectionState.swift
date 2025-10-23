//
//  ConnectionState.swift
//  Omri (iOS)
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Observable state for SSH connection and navigation
//

import SwiftUI

@Observable
class ConnectionState {
    var navigationPath: [SSHConnection] = []
    var currentConnection: SSHConnection?
    var isConnected: Bool = false

    func connect(to connection: SSHConnection) {
        currentConnection = connection
        isConnected = true
        navigationPath.append(connection)
    }

    func disconnect() {
        isConnected = false
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
        currentConnection = nil
    }
}
