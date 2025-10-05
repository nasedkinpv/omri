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
// import SwiftTerm - will be added

struct TerminalWindowView: View {
    // Will accept LocalProcessTerminalView once SwiftTerm is available
    // let terminalView: LocalProcessTerminalView
    let connection: SSHConnection

    @State private var isDictating = false
    @State private var showingHelp = false

    var body: some View {
        VStack(spacing: 0) {
            // Terminal view (will be wrapped NSView)
            // TerminalViewRepresentable(terminalView: terminalView)
            //     .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Placeholder until SwiftTerm is added
            Color.black
                .overlay(
                    VStack {
                        Text("Terminal Output Area")
                            .foregroundColor(.green)
                            .font(.system(.body, design: .monospaced))
                        Text("SwiftTerm integration pending")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                )

            // Bottom toolbar
            HStack(spacing: 12) {
                // Dictation button
                Button(action: startDictation) {
                    Label(
                        isDictating ? "Listening..." : "Dictate",
                        systemImage: isDictating ? "waveform" : "mic.fill"
                    )
                }
                .disabled(isDictating)
                .buttonStyle(.borderedProminent)
                .tint(isDictating ? .red : .blue)

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

                // Keyboard shortcut hint
                Text("fn to dictate")
                    .font(.caption)
                    .foregroundColor(.secondary)

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

    private func startDictation() {
        isDictating = true

        // Trigger AudioManager (reuse existing dictation system)
        Task { @MainActor in
            if let audioManager = AppDelegate.shared?.getAudioManager() {
                // AudioManager will handle the recording
                // Result will come back through delegate
                print("Terminal: Starting dictation via AudioManager")
            }
        }
    }
}

/* Will be uncommented once SwiftTerm is available:

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

*/

#Preview {
    TerminalWindowView(
        connection: SSHConnection(
            host: "example.com",
            username: "user"
        )
    )
    .frame(width: 800, height: 600)
}

#endif
