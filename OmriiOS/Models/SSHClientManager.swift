//
//  SSHClientManager.swift
//  Omri (iOS)
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  SSH client manager using Citadel for iOS terminal connections
//

import Foundation
import Citadel
import NIOSSH
import NIO
import NIOFoundationCompat

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

@MainActor
class SSHClientManager {
    private var client: SSHClient?
    private var ptyStdinWriter: TTYStdinWriter?
    private var isConnected = false
    private var initialCols: Int
    private var initialRows: Int

    let connection: SSHConnection

    // Closure-based callbacks (iOS pattern)
    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?
    var onReceiveOutput: ((Data) -> Void)?

    init(connection: SSHConnection, initialCols: Int = 80, initialRows: Int = 24) {
        self.connection = connection
        self.initialCols = initialCols
        self.initialRows = initialRows
    }

    /// Connect to SSH server with authentication
    /// - Parameters:
    ///   - cols: Initial terminal columns (optional, uses value from init)
    ///   - rows: Initial terminal rows (optional, uses value from init)
    func connect(cols: Int? = nil, rows: Int? = nil) async throws {
        // Use provided dimensions or fall back to initial values
        if let cols = cols { self.initialCols = cols }
        if let rows = rows { self.initialRows = rows }
        guard !isConnected else {
            Logger.log("Already connected", context: "SSH", level: .debug)
            return
        }

        Logger.log("Starting connection to \(connection.host):\(connection.port)", context: "SSH", level: .info)

        // Create connection settings
        let settings: SSHClientSettings

        switch connection.authMethod {
        case .password:
            // Password authentication
            let username = connection.username
            let password = connection.password ?? ""

            if password.isEmpty {
                Logger.log("Empty password - connection will likely fail", context: "SSH", level: .warning)
            } else {
                Logger.log("Using password auth for user '\(username)'", context: "SSH", level: .info)
            }

            settings = SSHClientSettings(
                host: connection.host,
                port: connection.port,
                authenticationMethod: {
                    .passwordBased(
                        username: username,
                        password: password
                    )
                },
                hostKeyValidator: .acceptAnything() // For production, use proper validation
            )

        case .key:
            // SSH key authentication
            Logger.log("Key auth not yet supported", context: "SSH", level: .warning)
            throw SSHClientError.unsupportedKeyFormat
            // TODO: Implement key-based authentication with Citadel
        }

        // Connect to server using Citadel
        Logger.log("Attempting connection...", context: "SSH", level: .info)
        client = try await SSHClient.connect(to: settings)
        Logger.log("Connection established!", context: "SSH", level: .info)

        isConnected = true
        onConnect?()

        // Start PTY session
        Logger.log("Starting PTY session...", context: "SSH", level: .info)
        try await startPTYSession()
    }

    /// Start pseudo-terminal (PTY) session
    private func startPTYSession() async throws {
        guard let client = client else {
            Logger.log("No client available for PTY", context: "SSH", level: .error)
            return
        }

        // Create PTY request with actual terminal dimensions
        // These dimensions are critical - remote applications (vim, tmux, htop)
        // use them to format output correctly
        let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: "xterm-256color",
            terminalCharacterWidth: initialCols,
            terminalRowHeight: initialRows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: .init([
                .ECHO: 1,
                .ISIG: 1,
                .ICANON: 1,
                .OPOST: 1
            ])
        )

        Logger.log("Opening PTY session (\(initialCols)x\(initialRows))...", context: "SSH", level: .info)

        // Open PTY session - runs in background
        Task {
            do {
                try await client.withPTY(ptyRequest) { [weak self] ttyOutput, ttyStdinWriter in
                    guard let self = self else {
                        Logger.log("Self deallocated in PTY handler", context: "SSH", level: .debug)
                        return
                    }

                    Logger.log("PTY session started, storing stdin writer", context: "SSH", level: .info)

                    // Store stdin writer for sending commands
                    await MainActor.run {
                        self.ptyStdinWriter = ttyStdinWriter
                    }

                    Logger.log("Starting to read PTY output...", context: "SSH", level: .debug)

                    // Read output from terminal
                    for try await output in ttyOutput {
                        // Convert output to data and send via closure callback
                        switch output {
                        case .stdout(let buffer):
                            let data = Data(buffer: buffer)
                            Logger.log("Received \(data.count) bytes stdout", context: "SSH", level: .debug)
                            await MainActor.run {
                                self.onReceiveOutput?(data)
                            }
                        case .stderr(let buffer):
                            let data = Data(buffer: buffer)
                            Logger.log("Received \(data.count) bytes stderr", context: "SSH", level: .debug)
                            await MainActor.run {
                                self.onReceiveOutput?(data)
                            }
                        }
                    }

                    Logger.log("PTY output stream ended", context: "SSH", level: .info)
                }
            } catch {
                Logger.log("PTY session error: \(error)", context: "SSH", level: .error)
            }
        }

        Logger.log("PTY session task launched", context: "SSH", level: .info)
    }

    /// Send text to terminal
    func sendText(_ text: String) async throws {
        guard let writer = ptyStdinWriter else {
            throw SSHClientError.notConnected
        }

        var buffer = ByteBuffer()
        buffer.writeString(text)
        try await writer.write(buffer)
    }

    /// Update PTY terminal dimensions
    /// - Parameters:
    ///   - cols: New column count
    ///   - rows: New row count
    ///
    /// **LIMITATION**: Citadel 0.11.1 doesn't expose WindowChangeRequest API
    ///
    /// The SSH protocol requires sending `SSHChannelRequestEvent.WindowChangeRequest`
    /// to notify the remote server when terminal dimensions change:
    ///
    /// ```swift
    /// channel.triggerUserOutboundEvent(
    ///     SSHChannelRequestEvent.WindowChangeRequest(
    ///         terminalCharacterWidth: cols,
    ///         terminalRowHeight: rows,
    ///         terminalPixelWidth: 0,
    ///         terminalPixelHeight: 0
    ///     ),
    ///     promise: nil
    /// )
    /// ```
    ///
    /// However, Citadel's `withPTY` API only exposes:
    /// - `ttyOutput` (AsyncSequence) - for reading output
    /// - `ttyStdinWriter` (TTYStdinWriter) - for writing input
    ///
    /// It does NOT expose the underlying NIO `Channel` needed to call
    /// `triggerUserOutboundEvent()`.
    ///
    /// **Impact**:
    /// - ✅ SwiftTerm resizes locally (cols/rows recalculated)
    /// - ❌ Remote applications (vim, tmux, htop) don't adapt to size changes
    /// - ❌ Line wrapping breaks when terminal shrinks
    /// - ❌ Content gets cut off on device rotation/Split View
    ///
    /// **Workarounds**:
    /// 1. Monitor Citadel updates for WindowChangeRequest support
    /// 2. Switch to raw NIOSSH (complex - requires full SSH rewrite)
    /// 3. Use initial dimensions correctly (implemented below)
    ///
    /// **Mitigation**: We set correct dimensions on initial PTY connection,
    /// so remote apps start with the right size. Only dynamic resizes are affected.
    func resizeTerminal(cols: Int, rows: Int) async throws {
        guard isConnected else {
            throw SSHClientError.notConnected
        }

        Logger.log("Terminal resized locally to \(cols)x\(rows)", context: "SSH", level: .warning)
        Logger.log("Remote server NOT notified (Citadel 0.11.1 limitation)", context: "SSH", level: .warning)
        Logger.log("Tip: Reconnect to apply new dimensions to remote applications", context: "SSH", level: .info)
    }

    /// Disconnect from SSH server
    func disconnect() async {
        do {
            try await client?.close()
        } catch {
            Logger.log("Error closing SSH connection: \(error)", context: "SSH", level: .error)
        }

        ptyStdinWriter = nil
        client = nil
        isConnected = false
        onDisconnect?()
    }
}

// MARK: - Errors

enum SSHClientError: LocalizedError {
    case notConnected
    case invalidKeyPath
    case unsupportedKeyFormat
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "SSH client is not connected"
        case .invalidKeyPath:
            return "Invalid SSH key path"
        case .unsupportedKeyFormat:
            return "Unsupported SSH key format"
        case .authenticationFailed:
            return "SSH authentication failed"
        }
    }
}
