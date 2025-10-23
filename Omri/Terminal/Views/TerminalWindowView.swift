//
//  TerminalWindowView.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  SwiftUI wrapper for terminal view with floating dictation controls
//

#if os(macOS)
import SwiftUI
import SwiftTerm

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

struct TerminalWindowView: View {
    let terminalView: LocalProcessTerminalView
    let connection: SSHConnection

    @State private var isDictating = false
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Terminal view with padding
            TerminalViewRepresentable(terminalView: terminalView)
                .padding(4)

            // Bottom floating controls (macOS uses full-width layout)
            HStack {
                Spacer()

                FloatingDictationControls(
                    isDictating: isDictating,
                    isLoading: isLoading,
                    onToggleDictation: toggleDictation,
                    onClear: clearInput,
                    onClearLongPress: clearScreen,
                    onEnter: sendEnter
                )

                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .onReceive(NotificationCenter.default.publisher(for: .terminalDidReceiveText)) { _ in
            // Text was received in terminal - recording is done
            if isDictating {
                Logger.log("Received text, resetting dictation state", context: "Terminal", level: .debug)
                isDictating = false
            }
        }
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
            Logger.log("Started dictation via AudioManager", context: "Terminal", level: .debug)

            // Monitor for when recording finishes
            Task { @MainActor in
                // Wait for transcription to complete
                // AudioManager will automatically call PasteManager when done
                // PasteManager will detect terminal is active and send text here
                // After 30 seconds max, auto-reset (safety)
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s timeout
                if isDictating {
                    Logger.log("Auto-stopping dictation after timeout", context: "Terminal", level: .debug)
                    stopDictation()
                }
            }
        }
    }

    private func stopDictation() {
        guard isDictating else { return }
        Logger.log("Stopping dictation", context: "Terminal", level: .debug)
        isDictating = false
        AppDelegate.shared?.getAudioManager()?.stopRecording()
    }

    private func clearInput() {
        TerminalWindowController.shared.clearInput()
    }

    private func clearScreen() {
        TerminalWindowController.shared.clearScreen()
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
