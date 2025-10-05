//
//  TerminalWindowView.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  SwiftUI wrapper for terminal view with dictation controls
//

#if os(macOS)
import SwiftUI
import SwiftTerm

struct TerminalWindowView: View {
    let terminalView: LocalProcessTerminalView
    let connection: SSHConnection

    @State private var isDictating = false
    @State private var showingHelp = false

    var body: some View {
        VStack(spacing: 0) {
            // Terminal view
            TerminalViewRepresentable(terminalView: terminalView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom toolbar
            HStack(spacing: 12) {
                // Dictation button (toggle)
                Button(action: toggleDictation) {
                    Label(
                        isDictating ? "Stop" : "Dictate",
                        systemImage: isDictating ? "stop.fill" : "mic.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(isDictating ? .red : .blue)

                // Clear input button
                Button(action: clearInput) {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)

                // Enter button (for iPad/touch-only use)
                Button(action: sendEnter) {
                    Label("Enter", systemImage: "return")
                }
                .buttonStyle(.bordered)

                Divider()
                    .frame(height: 20)

                // Connection info
                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .foregroundColor(.green)
                    Text("\(connection.username)@\(connection.host)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { showingHelp.toggle() }) {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .help("Terminal shortcuts")
            }
            .padding(8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .popover(isPresented: $showingHelp) {
            helpPopover
        }
        .onReceive(NotificationCenter.default.publisher(for: .terminalDidReceiveText)) { _ in
            // Text was received in terminal - recording is done
            if isDictating {
                print("Terminal: Received text, resetting dictation state")
                isDictating = false
            }
        }
    }

    private var helpPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Terminal Shortcuts")
                .font(.headline)

            Divider()

            HStack {
                Text("fn (hold)")
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                Text("Start dictation")
                    .font(.caption)
            }

            HStack {
                Text("⌘W")
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                Text("Close terminal")
                    .font(.caption)
            }

            HStack {
                Text("⌘K")
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                Text("Clear screen")
                    .font(.caption)
            }
        }
        .padding()
        .frame(width: 220)
    }

    private func toggleDictation() {
        if isDictating {
            stopDictation()
        } else {
            startDictation()
        }
    }

    private func startDictation() {
        guard !isDictating else { return }

        // Start recording via AudioManager
        if let audioManager = AppDelegate.shared?.getAudioManager() {
            isDictating = true
            audioManager.startRecording()
            print("Terminal: Started dictation via AudioManager")

            // Monitor for when recording finishes
            Task { @MainActor in
                // Wait for transcription to complete
                // AudioManager will automatically call PasteManager when done
                // PasteManager will detect terminal is active and send text here
                // After 30 seconds max, auto-reset (safety)
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s timeout
                if isDictating {
                    print("Terminal: Auto-stopping dictation after timeout")
                    stopDictation()
                }
            }
        }
    }

    private func stopDictation() {
        guard isDictating else { return }
        print("Terminal: Stopping dictation")
        isDictating = false
        AppDelegate.shared?.getAudioManager()?.stopRecording()
    }

    private func clearInput() {
        TerminalWindowController.shared.clearInput()
    }

    private func sendEnter() {
        TerminalWindowController.shared.sendEnter()
    }
}

// NSViewRepresentable to embed LocalProcessTerminalView
struct TerminalViewRepresentable: NSViewRepresentable {
    let terminalView: LocalProcessTerminalView

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Terminal view manages its own state
    }
}

// Preview disabled - requires actual LocalProcessTerminalView instance
// #Preview {
//     TerminalWindowView(
//         terminalView: LocalProcessTerminalView(frame: .zero),
//         connection: SSHConnection(
//             host: "example.com",
//             username: "user"
//         )
//     )
//     .frame(width: 800, height: 600)
// }

#endif
