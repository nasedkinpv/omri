//
//  SettingsView.swift
//  Omri (macOS)
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  macOS settings view with TabView navigation (unified with iOS approach)
//

#if os(macOS)
import SwiftUI
import AVFoundation
import ApplicationServices

// MARK: - Main Settings View

struct SettingsView: View {
    @StateObject private var settings = Settings.shared
    @State private var showingApiKeySheet = false
    @State private var currentProvider: String = ""
    @State private var apiKeyInput = ""
    @State private var showingPermissionsAlert = false
    @State private var selectedTab: SettingsTab = .dictation

    enum SettingsTab: String, CaseIterable {
        case dictation = "Dictation"
        case enhancement = "AI Polish"
        case general = "General"
        case about = "About"
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dictation", systemImage: "mic.fill", value: SettingsTab.dictation) {
                DictationSettingsContent(
                    settings: settings,
                    showingApiKeySheet: $showingApiKeySheet,
                    currentProvider: $currentProvider,
                    apiKeyInput: $apiKeyInput
                )
            }

            Tab("AI Polish", systemImage: "wand.and.stars", value: SettingsTab.enhancement) {
                AIPolishSettingsContent(
                    settings: settings,
                    showingApiKeySheet: $showingApiKeySheet,
                    currentProvider: $currentProvider,
                    apiKeyInput: $apiKeyInput
                )
            }

            Tab("General", systemImage: "gearshape.fill", value: SettingsTab.general) {
                GeneralSettingsContent(settings: settings)
            }

            Tab("About", systemImage: "info.circle.fill", value: SettingsTab.about) {
                AboutSettingsContent()
            }
        }
        .tabViewStyle(.automatic)
        .scenePadding()
        .frame(minWidth: 480, maxWidth: 600, minHeight: 420, maxHeight: .infinity)
        .sheet(isPresented: $showingApiKeySheet) {
            ApiKeyConfigurationSheet(
                provider: currentProvider,
                apiKeyInput: $apiKeyInput
            ) {
                saveApiKey()
            }
        }
        .alert("System Access Required", isPresented: $showingPermissionsAlert) {
            Button("Open System Settings") { openSystemSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(permissionStatus())
        }
    }

    // MARK: - Helper Methods

    private func saveApiKey() {
        guard !apiKeyInput.isEmpty else { return }

        if let transcriptionProvider = TranscriptionProvider(rawValue: currentProvider) {
            settings.setApiKey(apiKeyInput, for: transcriptionProvider)
        } else if let transformationProvider = TransformationProvider(rawValue: currentProvider) {
            settings.setApiKey(apiKeyInput, for: transformationProvider)
        }

        apiKeyInput = ""
    }

    private func permissionStatus() -> String {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let accessibilityStatus: Bool = {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }()

        if micStatus && accessibilityStatus {
            return "✅ All permissions granted. Omri is ready to use!"
        } else {
            return """
            Omri requires additional system access:

            🎤 Microphone Access: \(micStatus ? "✅ Granted" : "❌ Required")
            ⚡ Accessibility Access: \(accessibilityStatus ? "✅ Granted" : "❌ Required")

            These permissions enable voice recording and seamless text insertion.
            """
        }
    }

    private func openSystemSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!)
    }
}

// MARK: - Settings Window Controller

class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.center()

        let hostingView = NSHostingView(rootView: SettingsView())
        hostingView.sizingOptions = [.minSize]
        window.contentView = hostingView

        window.isReleasedWhenClosed = false

        // Set content size constraints (aligned with Settings library 450pt content width)
        window.contentMinSize = NSSize(width: 480, height: 420)
        window.contentMaxSize = NSSize(width: 600, height: 10000)

        self.init(window: window)
    }
}

#Preview {
    SettingsView()
        .frame(width: 500, height: 450)
}

#endif
