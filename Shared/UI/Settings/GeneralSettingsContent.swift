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

                    #if MAS_BUILD
                    Toggle("Insert transcript into the active app", isOn: .constant(false))
                        .disabled(true)
                    SettingsSectionFooter(text: "The App Store version copies the transcript to the clipboard. Press \u{2318}V to paste it. Dictation into Omri's own terminal still inserts directly.")
                    #else
                    Toggle("Insert transcript into the active app", isOn: $settings.automaticPaste)
                    SettingsSectionFooter(text: "Requires Accessibility permission. When off, the transcript is copied to the clipboard instead.")
                    #endif
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

                    SettingsSectionFooter(text:"Microphone access enables voice recording. Input Monitoring lets Omri see the fn key while other apps are focused.")
                }

                // Storage Management
                VStack(alignment: .leading, spacing: 16) {
                    SettingsSectionHeader(title:"Storage")

                    onDeviceModelsSection

                    SettingsSectionFooter(text: "Download models for offline, private transcription. Models are cached after first download.")
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
                onDeviceModelsSection
            } header: {
                Text("Storage")
            } footer: {
                Text("Download models for offline, private transcription. Models are cached after first download.")
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

    // MARK: - Model Download UI

    @ViewBuilder
    private var onDeviceModelsSection: some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            let manager = ModelDownloadManager.shared

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(manager.displayName)
                            .font(.headline)
                        Text(manager.modelDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(manager.estimatedSize)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        OmriStatusIndicator(
                            state: modelStatusToConnectionState(manager.state),
                            service: .transcription
                        )
                        modelActionButton(state: manager.state, manager: manager)
                    }
                }

                if case .downloading = manager.state {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Downloading model files (~600 MB)...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if case .error(let message) = manager.state {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                if manager.state == .downloaded {
                    HStack {
                        Spacer()
                        Button("Clear Model...") {
                            showingClearModelsAlert = true
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                manager.checkStatus()
            }
        }
    }

    @available(macOS 14.0, iOS 17.0, *)
    @ViewBuilder
    private func modelActionButton(state: ModelDownloadState, manager: ModelDownloadManager) -> some View {
        switch state {
        case .notDownloaded:
            Button("Download") {
                Task { await manager.download() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

        case .downloading:
            Button("Downloading...") {}
                .disabled(true)
                .buttonStyle(.bordered)
                .controlSize(.small)

        case .downloaded:
            Button("Ready") {}
                .disabled(true)
                .buttonStyle(.bordered)
                .controlSize(.small)

        case .error:
            Button("Clear & Retry") {
                Task {
                    manager.clear()
                    await manager.download()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    @available(macOS 14.0, iOS 17.0, *)
    private func modelStatusToConnectionState(_ state: ModelDownloadState) -> OmriStatusIndicator.ConnectionState {
        switch state {
        case .notDownloaded: return .disconnected
        case .downloading: return .connecting
        case .downloaded: return .connected
        case .error: return .error
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

        // Refresh model download manager state
        if #available(macOS 14.0, iOS 17.0, *) {
            ModelDownloadManager.shared.checkStatus()
        }
    }
}
