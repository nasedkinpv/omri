//
//  SettingsView.swift
//  Omri (iOS)
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  iOS settings view with TabView navigation
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = Settings.shared
    @State private var showingApiKeySheet = false
    @State private var currentProvider: String = ""
    @State private var apiKeyInput = ""

    var body: some View {
        TabView {
            // Dictation Settings
            Tab("Dictation", systemImage: "mic.fill") {
                NavigationStack {
                    DictationSettingsContent(
                        settings: settings,
                        showingApiKeySheet: $showingApiKeySheet,
                        currentProvider: $currentProvider,
                        apiKeyInput: $apiKeyInput
                    )
                    .navigationTitle("Dictation")
                    .navigationBarTitleDisplayMode(.large)
                }
            }

            // AI Polish Settings
            Tab("AI Polish", systemImage: "wand.and.stars") {
                NavigationStack {
                    AIPolishSettingsContent(
                        settings: settings,
                        showingApiKeySheet: $showingApiKeySheet,
                        currentProvider: $currentProvider,
                        apiKeyInput: $apiKeyInput
                    )
                    .navigationTitle("AI Polish")
                    .navigationBarTitleDisplayMode(.large)
                }
            }

            // General Settings
            Tab("General", systemImage: "gearshape.fill") {
                NavigationStack {
                    GeneralSettingsContent(settings: settings)
                        .navigationTitle("General")
                        .navigationBarTitleDisplayMode(.large)
                }
            }

            // TODO: Terminal Settings UI (Future Enhancement)
            // Planned features for terminal customization:
            // - Font size slider (10pt - 24pt) with live preview
            // - Font family picker (Hack Nerd Font, SF Mono, Menlo, etc.)
            // - Color scheme selection (Default, Solarized, Dracula, etc.)
            // - Bold fonts toggle
            // - Cursor blinking toggle
            //
            // Note: Font size is currently adjustable via pinch-to-zoom gesture
            // and persists automatically via TerminalSettings.shared.fontSize
            //
            // Uncomment below when implementing terminal settings UI:
            // Tab("Terminal", systemImage: "terminal.fill") {
            //     NavigationStack {
            //         TerminalSettingsContent(settings: TerminalSettings.shared)
            //             .navigationTitle("Terminal")
            //             .navigationBarTitleDisplayMode(.large)
            //     }
            // }

            // About
            Tab("About", systemImage: "info.circle.fill") {
                NavigationStack {
                    AboutSettingsContent()
                        .navigationTitle("About")
                        .navigationBarTitleDisplayMode(.large)
                }
            }
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackgroundVisibility(.visible, for: .tabBar)
        .sheet(isPresented: $showingApiKeySheet) {
            ApiKeyConfigurationSheet(
                provider: currentProvider,
                apiKeyInput: $apiKeyInput
            ) {
                saveApiKey()
            }
        }
    }

    private func saveApiKey() {
        guard !apiKeyInput.isEmpty else { return }

        if let transcriptionProvider = TranscriptionProvider(rawValue: currentProvider) {
            settings.setApiKey(apiKeyInput, for: transcriptionProvider)
        } else if let transformationProvider = TransformationProvider(rawValue: currentProvider) {
            settings.setApiKey(apiKeyInput, for: transformationProvider)
        }

        apiKeyInput = ""
    }
}

#Preview {
    SettingsView()
}
