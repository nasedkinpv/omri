//
//  TerminalWindowController.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Manages terminal window lifecycle and SSH connections
//

#if os(macOS)
import Cocoa
import SwiftUI
import SwiftTerm

@MainActor
class TerminalWindowController: NSWindowController {
    static let shared = TerminalWindowController()

    private var terminalView: LocalProcessTerminalView?
    private var currentConnection: SSHConnection?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Dictly Terminal"
        window.titlebarAppearsTransparent = true
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)

        self.init(window: window)

        // Set placeholder content until SwiftTerm is added
        let placeholderView = NSHostingView(
            rootView: TerminalPlaceholderView()
        )
        window.contentView = placeholderView
    }

    /// Connect to SSH server and display terminal
    func connect(to connection: SSHConnection) {
        currentConnection = connection

        let terminalView = LocalProcessTerminalView(frame: .zero)

        // Configure terminal appearance
        terminalView.font = NSFont.monospacedSystemFont(
            ofSize: CGFloat(TerminalSettings.shared.fontSize),
            weight: .regular
        )

        // Spawn SSH process
        let (executable, args) = connection.sshCommand
        terminalView.startProcess(
            executable: executable,
            args: args
        )

        // Wrap in SwiftUI with dictation controls
        let contentView = TerminalWindowView(
            terminalView: terminalView,
            connection: connection
        )

        let hostingView = NSHostingView(rootView: contentView)
        window?.contentView = hostingView
        window?.title = "Dictly Terminal - \(connection.name)"

        self.terminalView = terminalView

        // Show window
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Send text to terminal (for dictation integration)
    func sendText(_ text: String) {
        terminalView?.send(txt: text)

        // Notify that text was received (for UI state updates)
        NotificationCenter.default.post(
            name: .terminalDidReceiveText,
            object: nil
        )
    }

    /// Clear current input line in terminal (Ctrl+U)
    func clearInput() {
        // Send Ctrl+U control character (ASCII 21)
        // This is the standard Unix sequence to clear the current input line
        let ctrlU = "\u{15}"
        terminalView?.send(txt: ctrlU)
        print("Terminal: Cleared input line")
    }

    /// Send Enter key to terminal (execute command)
    func sendEnter() {
        // Send newline character to execute the current command
        terminalView?.send(txt: "\n")
        print("Terminal: Sent Enter")
    }

    /// Check if terminal window is active
    var isTerminalActive: Bool {
        window?.isKeyWindow ?? false
    }
}

// Notification for text received in terminal
extension Notification.Name {
    static let terminalDidReceiveText = Notification.Name("terminalDidReceiveText")
}

// Placeholder view shown until SwiftTerm is integrated
struct TerminalPlaceholderView: View {
    var connection: SSHConnection?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Terminal Ready")
                .font(.title)

            if let connection = connection {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connection:")
                        .font(.headline)
                    Text("Host: \(connection.host)")
                    Text("User: \(connection.username)")
                    Text("Port: \(connection.port)")
                    Text("Auth: \(connection.authMethod.rawValue)")
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }

            Text("SwiftTerm integration coming next...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#endif
