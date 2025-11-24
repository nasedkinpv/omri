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

                // Voice Activity Detection
                if !settings.transcriptionProvider.isOnDevice || settings.transcriptionProviderRaw == "Parakeet (On-Device)" {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsSectionHeader(title: "Smart Voice Detection")

                        Toggle("Enable Smart Recording", isOn: $settings.enableVAD)

                        if settings.enableVAD {
                            vadControls
                        }

                        if settings.enableVAD {
                            SettingsSectionFooter(text: vadFooterText)
                        }
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

            // Voice Activity Detection (hide for Apple - it has built-in VAD, show for Parakeet and cloud providers)
            if !settings.transcriptionProvider.isOnDevice || settings.transcriptionProviderRaw == "Parakeet (On-Device)" {
                Section {
                    Toggle("Enable Smart Recording", isOn: $settings.enableVAD)

                    if settings.enableVAD {
                        vadControls
                    }
                } header: {
                    Text("Smart Voice Detection")
                } footer: {
                    if settings.enableVAD {
                        Text(vadFooterText)
                    }
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
        if settings.transcriptionProviderRaw == "Parakeet (On-Device)" {
            return "Real-time streaming transcription. Text appears as you speak, completely on-device."
        } else {
            return "Automatically starts recording when speech is detected and stops during silence"
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
