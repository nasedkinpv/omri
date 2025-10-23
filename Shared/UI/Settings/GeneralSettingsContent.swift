//
//  GeneralSettingsContent.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Shared general settings content (iOS + macOS)
//

import SwiftUI

#if os(macOS)
import AppKit
#endif

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

struct GeneralSettingsContent: View {
    @ObservedObject var settings: Settings
    @State private var showingClearModelsAlert = false

    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iosLayout
        #endif
    }

    // MARK: - macOS Grid Layout

    @ViewBuilder
    private var macOSLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App Behavior
                VStack(alignment: .leading, spacing: 16) {
                    SettingsSectionHeader(title:"App Behavior")

                    Toggle("Launch Omri at startup", isOn: $settings.startAtLogin)
                }

                // System Integration
                VStack(alignment: .leading, spacing: 16) {
                    SettingsSectionHeader(title:"System Integration")

                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("System Permissions")
                                .font(.headline)
                            Text("Required for voice input and text insertion")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        SystemPermissionStatusView()
                    }

                    SettingsSectionFooter(text:"Microphone access enables voice recording. Accessibility permission allows Omri to insert text into any app.")
                }

                // Storage Management
                VStack(alignment: .leading, spacing: 16) {
                    SettingsSectionHeader(title:"Storage")

                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Downloaded Models")
                                .font(.headline)
                            Text("On-device transcription models (~600MB)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Clear models...") {
                            showingClearModelsAlert = true
                        }
                        .buttonStyle(.borderless)
                        .help("Remove downloaded models to free ~600MB of space")
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert("Clear Downloaded Models?", isPresented: $showingClearModelsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Models", role: .destructive) {
                clearDownloadedModels()
            }
        } message: {
            Text("This will remove all downloaded transcription models (~600MB). Models will be re-downloaded automatically when you use on-device transcription.")
        }
    }

    // MARK: - iOS Form Layout

    @ViewBuilder
    private var iosLayout: some View {
        Form {
            // System Integration
            Section {
                LabeledContent {
                    SystemPermissionStatusView()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Permissions")
                            .font(.headline)
                            .fontWeight(.medium)
                        Text("Required for voice input and text insertion")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("System Integration")
            } footer: {
                Text("Microphone access enables voice recording for dictation.")
            }

            // Storage Management
            Section {
                LabeledContent {
                    Button("Clear models...") {
                        showingClearModelsAlert = true
                    }
                    .buttonStyle(.borderless)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Downloaded Models")
                            .font(.headline)
                            .fontWeight(.medium)
                        Text("On-device transcription models (~600MB)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Storage")
            }
        }
        .alert("Clear Downloaded Models?", isPresented: $showingClearModelsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Models", role: .destructive) {
                clearDownloadedModels()
            }
        } message: {
            Text("This will remove all downloaded transcription models (~600MB). Models will be re-downloaded automatically when you use on-device transcription.")
        }
    }

    // MARK: - Helper Methods

    private func clearDownloadedModels() {
        let fileManager = FileManager.default

        // Get app support directory
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            Logger.log("Failed to find Application Support directory", context: "Settings", level: .error)
            return
        }

        // Parakeet models path (FluidAudio)
        let fluidAudioPath = appSupportURL.appendingPathComponent("FluidAudio/Models")

        do {
            if fileManager.fileExists(atPath: fluidAudioPath.path) {
                try fileManager.removeItem(at: fluidAudioPath)
                Logger.log("Cleared Parakeet models at \(fluidAudioPath.path)", context: "Settings", level: .info)
            }
        } catch {
            Logger.log("Failed to clear Parakeet models: \(error.localizedDescription)", context: "Settings", level: .error)
        }

        // Apple SpeechAnalyzer models are managed by system, no manual cleanup needed
        Logger.log("Model cache cleared successfully", context: "Settings", level: .info)
    }
}
