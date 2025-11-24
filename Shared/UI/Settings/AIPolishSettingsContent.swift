//
//  AIPolishSettingsContent.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Shared AI Polish settings content (iOS + macOS)
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct AIPolishSettingsContent: View {
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
                // Enable/Disable
                VStack(alignment: .leading, spacing: 16) {
                    SettingsSectionHeader(title:"AI Polish")

                    Toggle("Enable AI Processing", isOn: $settings.enableAIProcessing)

                    if settings.enableAIProcessing {
                        SettingsSectionFooter(text:"Automatically improves your dictated text with grammar correction and smart formatting")
                    }
                }

                if settings.enableAIProcessing {
                    // AI Service Configuration
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsSectionHeader(title:"AI Service")

                        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 20, verticalSpacing: 12) {
                            GridRow {
                                Text("Provider")
                                    .gridColumnAlignment(.trailing)
                                Picker("", selection: $settings.transformationProviderRaw) {
                                    ForEach(TransformationProvider.allCases, id: \.rawValue) { provider in
                                        Text(provider.rawValue).tag(provider.rawValue)
                                    }
                                }
                                .labelsHidden()
                                .fixedSize()
                            }

                            GridRow {
                                Text("Model")
                                    .gridColumnAlignment(.trailing)
                                if settings.transformationProvider.supportsCustomBaseURL {
                                    TextField("", text: $settings.transformationModel, prompt: Text("gpt-oss-20b"))
                                        .frame(minWidth: 200)
                                } else {
                                    Picker("", selection: $settings.transformationModel) {
                                        ForEach(settings.transformationProvider.availableModels, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    }
                                    .labelsHidden()
                                    .fixedSize()
                                }
                            }
                        }
                    }

                    // Custom Base URL
                    if settings.transformationProvider.supportsCustomBaseURL {
                        VStack(alignment: .leading, spacing: 16) {
                            SettingsSectionHeader(title:"Custom API Endpoint")

                            HStack(spacing: 12) {
                                TextField("Base URL", text: $settings.customTransformationBaseURL, prompt: Text("http://localhost:11434/v1/chat/completions"))

                                OmriStatusIndicator(
                                    state: mapEndpointStatus(settings.customTransformationEndpointStatus),
                                    service: .enhancement
                                )

                                Button("Test") {
                                    Task {
                                        await testTransformationEndpoint()
                                    }
                                }
                                .disabled(settings.customTransformationBaseURL.isEmpty)
                            }

                            // Show error message if validation failed
                            if case .invalid(let error) = settings.customTransformationEndpointStatus {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }

                            SettingsSectionFooter(text:"For local AI models like Ollama, LM Studio, or other OpenAI-compatible APIs")
                        }
                    }

                    // Account Settings
                    if settings.transformationProvider.requiresApiKey {
                        VStack(alignment: .leading, spacing: 16) {
                            SettingsSectionHeader(title:"Account")

                            HStack(alignment: .top, spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("API Key")
                                        .font(.headline)
                                    Text("Required for AI text processing")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                HStack(spacing: 12) {
                                    OmriStatusIndicator(
                                        state: settings.apiKey(for: settings.transformationProvider) != nil ? .connected : .disconnected,
                                        service: .enhancement
                                    )

                                    Button("Configure") {
                                        currentProvider = settings.transformationProviderRaw
                                        apiKeyInput = settings.apiKey(for: settings.transformationProvider) ?? ""
                                        showingApiKeySheet = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
                                }
                            }
                        }
                    }

                    // Custom Enhancement Prompt
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsSectionHeader(title:"Polish Instructions")

                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Customize how AI processes your transcribed text")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(Color("BrandBlue"))
                                        .font(.caption)
                                    Text("Use {transcribed_text} as a placeholder for the dictated content")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color("BrandBlue").opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            }

                            TextEditor(text: $settings.transformationPrompt)
                                .frame(minHeight: 140)
                                .font(.system(.body, design: .monospaced))
                                .padding(12)
                                #if os(macOS)
                                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                )
                                #endif
                                .overlay(alignment: .topLeading) {
                                    if settings.transformationPrompt.isEmpty {
                                        Text("Enter your custom prompt here...")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.secondary.opacity(0.6))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 20)
                                            .allowsHitTesting(false)
                                    }
                                }

                            HStack {
                                Text("\(settings.transformationPrompt.count) characters")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.6))

                                Spacer()

                                Button("Reset to Default") {
                                    settings.resetTransformationPromptToDefault()
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .foregroundColor(Color("BrandBlue"))
                            }
                        }
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
            // Enable/Disable
            Section {
                Toggle("Enable AI Processing", isOn: $settings.enableAIProcessing)
            } header: {
                Text("AI Polish")
            } footer: {
                if settings.enableAIProcessing {
                    Text("Automatically improves your dictated text with grammar correction and smart formatting")
                }
            }

            if settings.enableAIProcessing {
                // AI Service Configuration
                Section("AI Service") {
                    Picker("Provider", selection: $settings.transformationProviderRaw) {
                        ForEach(TransformationProvider.allCases, id: \.rawValue) { provider in
                            Text(provider.rawValue).tag(provider.rawValue)
                        }
                    }

                    if settings.transformationProvider.supportsCustomBaseURL {
                        TextField("Model", text: $settings.transformationModel, prompt: Text("gpt-oss-20b"))
                    } else {
                        Picker("Model", selection: $settings.transformationModel) {
                            ForEach(settings.transformationProvider.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }
                }

                // Custom Base URL for OpenAI Compatible providers
                if settings.transformationProvider.supportsCustomBaseURL {
                    Section {
                        HStack(spacing: 12) {
                            TextField("Base URL", text: $settings.customTransformationBaseURL, prompt: Text("http://localhost:11434/v1/chat/completions"))

                            OmriStatusIndicator(
                                state: mapEndpointStatus(settings.customTransformationEndpointStatus),
                                service: .enhancement
                            )

                            Button("Test") {
                                Task {
                                    await testTransformationEndpoint()
                                }
                            }
                            .disabled(settings.customTransformationBaseURL.isEmpty)
                        }

                        // Show error message if validation failed
                        if case .invalid(let error) = settings.customTransformationEndpointStatus {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } header: {
                        Text("Custom API Endpoint")
                    } footer: {
                        Text("For local AI models like Ollama, LM Studio, or other OpenAI-compatible APIs")
                    }
                }

                // Account Settings (only show for providers that require API keys)
                if settings.transformationProvider.requiresApiKey {
                    Section("Account") {
                        LabeledContent {
                            HStack(spacing: 12) {
                                OmriStatusIndicator(
                                    state: settings.apiKey(for: settings.transformationProvider) != nil ? .connected : .disconnected,
                                    service: .enhancement
                                )

                                Button("Configure") {
                                    currentProvider = settings.transformationProviderRaw
                                    apiKeyInput = settings.apiKey(for: settings.transformationProvider) ?? ""
                                    showingApiKeySheet = true
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("API Key")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                Text("Required for AI text processing")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("API Key configuration")
                    }
                }

                // Custom Enhancement Prompt
                Section("Polish Instructions") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Customize how AI processes your transcribed text")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(Color("BrandBlue"))
                                    .font(.caption)
                                Text("Use {transcribed_text} as a placeholder for the dictated content")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color("BrandBlue").opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                        }

                        TextEditor(text: $settings.transformationPrompt)
                            .frame(minHeight: 140)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            #if os(iOS)
                            .background(Color(UIColor.systemBackground), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(UIColor.separator), lineWidth: 1)
                            )
                            #endif
                            .overlay(alignment: .topLeading) {
                                if settings.transformationPrompt.isEmpty {
                                    Text("Enter your custom prompt here...")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.secondary.opacity(0.6))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                        .allowsHitTesting(false)
                                }
                            }

                        HStack {
                            Text("\(settings.transformationPrompt.count) characters")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.6))

                            Spacer()

                            Button("Reset to Default") {
                                settings.resetTransformationPromptToDefault()
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .foregroundColor(Color("BrandBlue"))
                        }
                    }
                }
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
    private func testTransformationEndpoint() async {
        settings.customTransformationEndpointStatus = .validating

        let apiKey = settings.apiKey(for: settings.transformationProvider) ?? ""
        let result = await BaseHTTPService.validateEndpoint(
            baseURL: settings.customTransformationBaseURL,
            apiKey: apiKey
        )

        settings.customTransformationEndpointStatus = result
    }

}
