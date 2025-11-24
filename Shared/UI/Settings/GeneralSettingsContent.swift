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
        #if os(macOS) && canImport(FluidAudio)
        if #available(macOS 14.0, *) {
            let manager = ModelDownloadManager.shared

            VStack(alignment: .leading, spacing: 16) {
                ForEach(manager.availableModels, id: \.id) { model in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.displayName)
                                    .font(.headline)
                                Text(model.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(model.estimatedSize)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            HStack(spacing: 12) {
                                // Status indicator
                                OmriStatusIndicator(
                                    state: modelStatusToConnectionState(manager.state(for: model.id)),
                                    service: .transcription
                                )

                                // Action button
                                modelActionButton(for: model, state: manager.state(for: model.id), manager: manager)
                            }
                        }

                        // Progress indicator when downloading
                        if case .downloading = manager.state(for: model.id) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Downloading model files (~600 MB)...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Error message
                        if case .error(let message) = manager.state(for: model.id) {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                // Clear all models button
                if manager.availableModels.contains(where: { manager.state(for: $0.id) == .downloaded }) {
                    HStack {
                        Spacer()
                        Button("Clear All Models...") {
                            showingClearModelsAlert = true
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                        .disabled(manager.availableModels.contains(where: { manager.state(for: $0.id) == .downloading }))
                    }
                }
            }
            .onAppear {
                Task {
                    await manager.checkAllModelsStatus()
                }
            }
        } else {
            Text("On-device models require macOS 14.0+")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        #elseif canImport(FluidAudio)
        if #available(iOS 17.0, *) {
            let manager = ModelDownloadManager.shared

            VStack(spacing: 16) {
                ForEach(manager.availableModels, id: \.id) { model in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.displayName)
                                    .font(.headline)
                                    .fontWeight(.medium)
                                Text(model.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(model.estimatedSize)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            HStack(spacing: 12) {
                                OmriStatusIndicator(
                                    state: modelStatusToConnectionState(manager.state(for: model.id)),
                                    service: .transcription
                                )

                                modelActionButton(for: model, state: manager.state(for: model.id), manager: manager)
                            }
                        }

                        // Progress indicator when downloading
                        if case .downloading = manager.state(for: model.id) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Downloading model files (~600 MB)...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Error message
                        if case .error(let message) = manager.state(for: model.id) {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                // Clear all models button
                if manager.availableModels.contains(where: { manager.state(for: $0.id) == .downloaded }) {
                    HStack {
                        Spacer()
                        Button("Clear All Models...") {
                            showingClearModelsAlert = true
                        }
                        .foregroundColor(.red)
                        .disabled(manager.availableModels.contains(where: { manager.state(for: $0.id) == .downloading }))
                    }
                }
            }
            .onAppear {
                Task {
                    await manager.checkAllModelsStatus()
                }
            }
        }
        #else
        Text("On-device models not available on this platform")
            .font(.caption)
            .foregroundColor(.secondary)
        #endif
    }

    @ViewBuilder
    private func modelActionButton(for model: any DownloadableModel, state: ModelDownloadState, manager: ModelDownloadManager) -> some View {
        switch state {
        case .notDownloaded:
            Button("Download") {
                Task {
                    await manager.downloadModel(model.id)
                }
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
                    // Clear partial/corrupted downloads before retrying
                    manager.clearModel(model.id)
                    await manager.downloadModel(model.id)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private func modelStatusToConnectionState(_ state: ModelDownloadState) -> OmriStatusIndicator.ConnectionState {
        switch state {
        case .notDownloaded:
            return .disconnected
        case .downloading:
            return .connecting
        case .downloaded:
            return .connected
        case .error:
            return .error
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
        #if canImport(FluidAudio)
        if #available(macOS 14.0, iOS 17.0, *) {
            Task {
                await ModelDownloadManager.shared.checkAllModelsStatus()
            }
        }
        #endif
    }
}
