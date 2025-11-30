//
//  DictationSettingsContent.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Shared dictation settings content (iOS + macOS)
//

import SwiftUI

struct DictationSettingsContent: View {
    @ObservedObject var settings: Settings
    @Binding var showingApiKeySheet: Bool
    @Binding var currentProvider: String
    @Binding var apiKeyInput: String

    // Model download state
    @State private var parakeetState: ModelDownloadState = .notDownloaded
    @State private var isCheckingModel = false

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
                // Speech Recognition Service
                VStack(alignment: .leading, spacing: 16) {
                    SettingsSectionHeader(title: "Speech Recognition")

                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 20, verticalSpacing: 12) {
                        GridRow {
                            Text("Service")
                                .gridColumnAlignment(.trailing)
                            Picker("", selection: $settings.transcriptionProviderRaw) {
                                ForEach(TranscriptionProvider.allCases, id: \.rawValue) { provider in
                                    Text(provider.rawValue).tag(provider.rawValue)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }

                        // Model selection
                        if settings.transcriptionProvider.supportsCustomBaseURL || settings.transcriptionProvider.availableModels.count > 1 {
                            GridRow {
                                Text("Model")
                                    .gridColumnAlignment(.trailing)
                                if settings.transcriptionProvider.supportsCustomBaseURL {
                                    TextField("", text: $settings.transcriptionModel, prompt: Text("whisper-1"))
                                        .frame(minWidth: 200)
                                } else {
                                    Picker("", selection: $settings.transcriptionModel) {
                                        ForEach(settings.transcriptionProvider.availableModels, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    }
                                    .labelsHidden()
                                    .fixedSize()
                                }
                            }
                        }

                        // Language selection
                        if settings.transcriptionProviderRaw != "Groq Translations" {
                            GridRow {
                                Text("Language")
                                    .gridColumnAlignment(.trailing)
                                Picker("", selection: $settings.transcriptionLanguage) {
                                    Text("Auto-detect").tag("")
                                    Text("English").tag("en")
                                    Text("Spanish").tag("es")
                                    Text("French").tag("fr")
                                    Text("German").tag("de")
                                    Text("Italian").tag("it")
                                    Text("Portuguese").tag("pt")
                                    Text("Russian").tag("ru")
                                    Text("Japanese").tag("ja")
                                    Text("Korean").tag("ko")
                                    Text("Chinese").tag("zh")
                                    Text("Arabic").tag("ar")
                                }
                                .labelsHidden()
                                .fixedSize()
                            }
                        }
                    }

                    SettingsSectionFooter(text: transcriptionFooterText)
                }

                // Parakeet Model Download (for on-device transcription)
                if settings.transcriptionProviderRaw == "Parakeet (On-Device)" {
                    parakeetModelSection
                }

                // Custom Base URL
                if settings.transcriptionProvider.supportsCustomBaseURL {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsSectionHeader(title: "Custom API Endpoint")

                        HStack(spacing: 12) {
                            TextField("Base URL", text: $settings.customTranscriptionBaseURL, prompt: Text("http://localhost:8000/v1/audio/transcriptions"))

                            OmriStatusIndicator(
                                state: mapEndpointStatus(settings.customTranscriptionEndpointStatus),
                                service: .transcription
                            )

                            Button("Test") {
                                Task {
                                    await testTranscriptionEndpoint()
                                }
                            }
                            .disabled(settings.customTranscriptionBaseURL.isEmpty)
                        }

                        // Show error message if validation failed
                        if case .invalid(let error) = settings.customTranscriptionEndpointStatus {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        SettingsSectionFooter(text: "For local Whisper servers, faster-whisper, or other OpenAI-compatible transcription APIs")
                    }
                }

                // Account Settings
                if settings.transcriptionProvider.requiresAPIKey {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsSectionHeader(title: "Account")

                        HStack(alignment: .top, spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("API Key")
                                    .font(.headline)
                                Text("Securely stored in your keychain")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            HStack(spacing: 12) {
                                OmriStatusIndicator(
                                    state: settings.apiKey(for: settings.transcriptionProvider) != nil ? .connected : .disconnected,
                                    service: .transcription
                                )

                                Button("Configure") {
                                    currentProvider = settings.transcriptionProviderRaw
                                    apiKeyInput = settings.apiKey(for: settings.transcriptionProvider) ?? ""
                                    showingApiKeySheet = true
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            }
                        }
                    }
                }

                // Voice Activity Detection / Streaming Mode
                if !settings.transcriptionProvider.isOnDevice || settings.transcriptionProviderRaw == "Parakeet (On-Device)" {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            SettingsSectionHeader(title: settings.transcriptionProviderRaw == "Parakeet (On-Device)" ? "Streaming Mode" : "Smart Voice Detection")
                            if settings.transcriptionProviderRaw != "Parakeet (On-Device)" {
                                Text("Experimental")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .clipShape(Capsule())
                            }
                        }

                        Toggle(settings.transcriptionProviderRaw == "Parakeet (On-Device)" ? "Enable Real-Time Streaming" : "Enable Smart Recording", isOn: $settings.enableVAD)

                        if settings.enableVAD && settings.transcriptionProviderRaw != "Parakeet (On-Device)" {
                            vadControls
                        }

                        SettingsSectionFooter(text: vadFooterText)
                    }
                }

                // Keyboard Shortcuts
                VStack(alignment: .leading, spacing: 16) {
                    SettingsSectionHeader(title: "Keyboard Shortcuts")

                    VStack(spacing: 12) {
                        KeyboardShortcutRow(
                            description: "Start dictation",
                            shortcut: "fn",
                            detail: settings.enableVAD ? "Press to activate smart recording" : "Hold to record voice input"
                        )

                        KeyboardShortcutRow(
                            description: "Dictation with enhancement",
                            shortcut: "fn + ⇧",
                            detail: "Record and apply AI text processing"
                        )
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - iOS Form Layout

    @ViewBuilder
    private var iosLayout: some View {
        Form {
            // Speech Recognition Service
            Section {
                Picker("Service", selection: $settings.transcriptionProviderRaw) {
                    ForEach(TranscriptionProvider.allCases, id: \.rawValue) { provider in
                        Text(provider.rawValue).tag(provider.rawValue)
                    }
                }

                // Show model selection (text field for custom, picker for others)
                if settings.transcriptionProvider.supportsCustomBaseURL || settings.transcriptionProvider.availableModels.count > 1 {
                    if settings.transcriptionProvider.supportsCustomBaseURL {
                        TextField("Model", text: $settings.transcriptionModel, prompt: Text("whisper-1"))
                    } else {
                        Picker("Model", selection: $settings.transcriptionModel) {
                            ForEach(settings.transcriptionProvider.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }
                }

                if settings.transcriptionProviderRaw != "Groq Translations" {
                    Picker("Language", selection: $settings.transcriptionLanguage) {
                        Text("Auto-detect").tag("")
                        Text("English").tag("en")
                        Text("Spanish").tag("es")
                        Text("French").tag("fr")
                        Text("German").tag("de")
                        Text("Italian").tag("it")
                        Text("Portuguese").tag("pt")
                        Text("Russian").tag("ru")
                        Text("Japanese").tag("ja")
                        Text("Korean").tag("ko")
                        Text("Chinese").tag("zh")
                        Text("Arabic").tag("ar")
                    }
                }
            } header: {
                Text("Speech Recognition")
            } footer: {
                Text(transcriptionFooterText)
            }

            // Parakeet Model Download (for on-device transcription)
            if settings.transcriptionProviderRaw == "Parakeet (On-Device)" {
                Section {
                    parakeetModelRow
                } header: {
                    Text("On-Device Model")
                } footer: {
                    Text("~600 MB download. Required for on-device transcription. Runs entirely on your device.")
                }
            }

            // Custom Base URL for OpenAI Compatible providers
            if settings.transcriptionProvider.supportsCustomBaseURL {
                Section {
                    HStack(spacing: 12) {
                        TextField("Base URL", text: $settings.customTranscriptionBaseURL, prompt: Text("http://localhost:8000/v1/audio/transcriptions"))

                        OmriStatusIndicator(
                            state: mapEndpointStatus(settings.customTranscriptionEndpointStatus),
                            service: .transcription
                        )

                        Button("Test") {
                            Task {
                                await testTranscriptionEndpoint()
                            }
                        }
                        .disabled(settings.customTranscriptionBaseURL.isEmpty)
                    }

                    // Show error message if validation failed
                    if case .invalid(let error) = settings.customTranscriptionEndpointStatus {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Custom API Endpoint")
                } footer: {
                    Text("For local Whisper servers, faster-whisper, or other OpenAI-compatible transcription APIs")
                }
            }

            // Account Settings (hide for on-device providers)
            if settings.transcriptionProvider.requiresAPIKey {
                Section("Account") {
                    LabeledContent {
                        HStack(spacing: 12) {
                            OmriStatusIndicator(
                                state: settings.apiKey(for: settings.transcriptionProvider) != nil ? .connected : .disconnected,
                                service: .transcription
                            )

                            Button("Configure") {
                                currentProvider = settings.transcriptionProviderRaw
                                apiKeyInput = settings.apiKey(for: settings.transcriptionProvider) ?? ""
                                showingApiKeySheet = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Key")
                                .font(.headline)
                                .fontWeight(.medium)
                            Text("Securely stored in your keychain")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("API Key configuration")
                }
            }

            // Voice Activity Detection / Streaming Mode (hide for Apple which has built-in VAD)
            if !settings.transcriptionProvider.isOnDevice || settings.transcriptionProviderRaw == "Parakeet (On-Device)" {
                Section {
                    Toggle(settings.transcriptionProviderRaw == "Parakeet (On-Device)" ? "Enable Real-Time Streaming" : "Enable Smart Recording", isOn: $settings.enableVAD)

                    if settings.enableVAD && settings.transcriptionProviderRaw != "Parakeet (On-Device)" {
                        vadControls
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text(settings.transcriptionProviderRaw == "Parakeet (On-Device)" ? "Streaming Mode" : "Smart Voice Detection")
                        if settings.transcriptionProviderRaw != "Parakeet (On-Device)" {
                            Text("Experimental")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                } footer: {
                    Text(vadFooterText)
                }
            }
        }
    }

    // MARK: - Shared Components

    @ViewBuilder
    private var vadControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Noise Floor")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int((1.0 - settings.vadSensitivity) * 10))/10")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Low")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Slider(
                        value: Binding(
                            get: { 1.0 - settings.vadSensitivity },
                            set: { settings.vadSensitivity = 1.0 - $0 }
                        ),
                        in: 0.1...0.9,
                        step: 0.1
                    )

                    Text("High")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Noise floor")
                .accessibilityValue("\(Int((1.0 - settings.vadSensitivity) * 10)) out of 10")

                Text("Higher = detect speech in noisy environments")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Min Speech Duration")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(settings.vadMinSpeechDuration, specifier: "%.2f")s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("0.1s")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Slider(value: $settings.vadMinSpeechDuration, in: 0.1...1.0, step: 0.05)

                    Text("1.0s")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Minimum speech duration")
                .accessibilityValue("\(settings.vadMinSpeechDuration, specifier: "%.2f") seconds")

                Text("Minimum length of speech to detect")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Silence Timeout")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(settings.vadSilenceTimeout, specifier: "%.1f")s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("0.5s")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Slider(value: $settings.vadSilenceTimeout, in: 0.5...3.0, step: 0.1)

                    Text("3.0s")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Silence timeout")
                .accessibilityValue("\(settings.vadSilenceTimeout, specifier: "%.1f") seconds")

                Text("How long to wait after speech stops")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Parakeet Model Download UI

    /// macOS version - full section with header
    @available(macOS 14.0, iOS 17.0, *)
    @ViewBuilder
    private var parakeetModelSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionHeader(title: "On-Device Model")

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Parakeet TDT v3")
                        .font(.headline)
                    Text("~600 MB • 25 languages • NVIDIA CC-BY 4.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                modelStatusView
            }

            SettingsSectionFooter(text: "Required for on-device transcription. Runs entirely on your device.")
        }
        .task {
            await checkParakeetModel()
        }
    }

    /// iOS version - row for Form
    @available(macOS 14.0, iOS 17.0, *)
    @ViewBuilder
    private var parakeetModelRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Parakeet TDT v3")
                    .font(.headline)
                Text("25 languages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            modelStatusView
        }
        .task {
            await checkParakeetModel()
        }
    }

    /// Shared status view (buttons and indicators)
    @available(macOS 14.0, iOS 17.0, *)
    @ViewBuilder
    private var modelStatusView: some View {
        switch parakeetState {
        case .notDownloaded:
            Button("Download") {
                Task {
                    await downloadParakeetModel()
                }
            }
            .buttonStyle(.borderedProminent)

        case .downloading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Downloading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        case .downloaded:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Ready")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Clear") {
                    clearParakeetModel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

        case .error(let message):
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Button("Retry") {
                        Task {
                            await downloadParakeetModel()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Model Management

    @available(macOS 14.0, iOS 17.0, *)
    @MainActor
    private func checkParakeetModel() async {
        guard !isCheckingModel else { return }
        isCheckingModel = true

        let manager = ModelDownloadManager.shared
        await manager.checkModelStatus("parakeet-tdt-v3")
        parakeetState = manager.state(for: "parakeet-tdt-v3")

        isCheckingModel = false
    }

    @available(macOS 14.0, iOS 17.0, *)
    @MainActor
    private func downloadParakeetModel() async {
        parakeetState = .downloading

        let manager = ModelDownloadManager.shared
        await manager.downloadModel("parakeet-tdt-v3")
        parakeetState = manager.state(for: "parakeet-tdt-v3")
    }

    @available(macOS 14.0, iOS 17.0, *)
    private func clearParakeetModel() {
        let manager = ModelDownloadManager.shared
        manager.clearModel("parakeet-tdt-v3")
        parakeetState = .notDownloaded
    }

    // MARK: - Computed Properties

    private var transcriptionFooterText: String {
        if settings.transcriptionProviderRaw == "Groq Translations" {
            return "Understands speech in any language and converts it to English text"
        } else if settings.transcriptionProviderRaw == "Apple (On-Device)" {
            #if os(macOS)
            return "100% private, offline transcription. No API key required. Faster response times."
            #else
            return "macOS 26.0+ only. Use Parakeet for on-device transcription on iOS."
            #endif
        } else if settings.transcriptionProviderRaw == "Parakeet (On-Device)" {
            return "On-device multilingual (25 languages). ANE-accelerated. No API key required. Works offline."
        }
        return ""
    }

    private var vadFooterText: String {
        if settings.enableVAD {
            if settings.transcriptionProviderRaw == "Parakeet (On-Device)" {
                return "Low-latency streaming transcription. Words appear as you speak (~0.5s latency). For fastest dictate-to-paste, disable this and use batch mode."
            } else {
                return "⚠️ Not recommended for cloud APIs. Each speech segment requires a separate API call, causing delays. Disable this for best experience with Groq/OpenAI."
            }
        } else {
            if settings.transcriptionProviderRaw == "Parakeet (On-Device)" {
                return "Batch mode: fastest dictate-to-paste. All audio processed at once when you release the key."
            } else {
                return "Recommended: fastest dictate-to-paste. Single API call when you release the key."
            }
        }
    }

    // MARK: - Endpoint Validation Helpers

    private func mapEndpointStatus(_ state: EndpointValidationState) -> OmriStatusIndicator.ConnectionState {
        switch state {
        case .unchecked:
            return .disconnected
        case .validating:
            return .connecting
        case .valid:
            return .connected
        case .invalid:
            return .error
        }
    }

    @MainActor
    private func testTranscriptionEndpoint() async {
        settings.customTranscriptionEndpointStatus = .validating

        let apiKey = settings.apiKey(for: settings.transcriptionProvider) ?? ""
        let result = await BaseHTTPService.validateEndpoint(
            baseURL: settings.customTranscriptionBaseURL,
            apiKey: apiKey
        )

        settings.customTranscriptionEndpointStatus = result
    }
}
