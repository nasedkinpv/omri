//
//  SettingsView.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//

import SwiftUI
import Combine
import AVFoundation
import ApplicationServices

// MARK: - Dictly Brand Colors

extension Color {
    // Neutral System Colors (using semantic colors for better dark mode support)
    static let brandGray900 = Color.primary
    static let brandGray100 = Color(NSColor.tertiaryLabelColor)
    static let brandGray600 = Color.secondary
    static let brandGray300 = Color(NSColor.separatorColor)
    
    // Brand Gradients (using asset catalog colors)
    static let dictlyBrandGradient = LinearGradient(
        colors: [Color("BrandBlue"), Color("BrandPurple")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let dictlyPremiumGradient = LinearGradient(
        colors: [Color("BrandIndigo"), Color("BrandPurple")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Custom Components

struct DictlyIcon: View {
    let name: String
    let size: CGFloat
    let style: IconStyle
    
    enum IconStyle {
        case brand          // Uses brand gradient
        case premium        // Uses premium gradient  
        case monochrome     // Uses single color
        case system         // Uses system colors
    }
    
    var body: some View {
        Image(systemName: name)
            .font(.system(size: size))
            .foregroundStyle(foregroundStyle)
            .symbolRenderingMode(.hierarchical)
    }
    
    private var foregroundStyle: AnyShapeStyle {
        switch style {
        case .brand:
            AnyShapeStyle(Color.dictlyBrandGradient)
        case .premium:
            AnyShapeStyle(Color.dictlyPremiumGradient)
        case .monochrome:
            AnyShapeStyle(Color("BrandBlue"))
        case .system:
            AnyShapeStyle(Color.primary)
        }
    }
}

struct DictlyStatusIndicator: View {
    let state: ConnectionState
    let service: ServiceType
    
    enum ConnectionState {
        case connected, connecting, disconnected, error
    }
    
    enum ServiceType {
        case transcription, enhancement, general
    }
    
    var body: some View {
        Image(systemName: statusIcon)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(statusColor)
            .scaleEffect(state == .connecting ? 1.2 : 1.0)
            .opacity(state == .connecting ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), 
                     value: state == .connecting)
    }
    
    private var statusColor: Color {
        switch state {
        case .connected: return Color("BrandMint")
        case .connecting: return Color("BrandTeal")
        case .disconnected: return .brandGray600
        case .error: return Color("BrandOrange")
        }
    }
    
    private var statusIcon: String {
        switch state {
        case .connected: return "checkmark.circle.fill"
        case .connecting: return "arrow.clockwise.circle.fill"
        case .disconnected: return "xmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

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
        HSplitView {
            // Brand-focused Sidebar
            VStack(spacing: 0) {
                // Dictly Header
                VStack(spacing: 16) {
                    Image("Brand Icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 52, height: 52)
                    
                    VStack(spacing: 4) {
                        Text("Dictly")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Voice to Text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }
                }
                .padding(.vertical, 28)
                
                Divider()
                
                // Navigation Sections
                VStack(spacing: 6) {
                    ForEach(SettingsTab.allCases, id: \.rawValue) { tab in
                        SettingsSidebarButton(
                            title: tab.rawValue,
                            icon: iconForTab(tab),
                            isSelected: selectedTab == tab
                        ) {
                            selectedTab = tab
                        }
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                
                Spacer()
                
                // Connection Status
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        DictlyStatusIndicator(
                            state: settings.apiKey(for: settings.transcriptionProvider) != nil ? .connected : .disconnected,
                            service: .transcription
                        )
                        
                        Text("Dictation")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    
                    if settings.enableAIProcessing {
                        HStack(spacing: 8) {
                            DictlyStatusIndicator(
                                state: settings.apiKey(for: settings.transformationProvider) != nil ? .connected : .disconnected,
                                service: .enhancement
                            )
                            
                            Text("AI Polish")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.bottom, 24)
                .padding(.horizontal, 16)
            }
            .frame(width: 220)
            .background(.ultraThinMaterial)
            
            // Content Area
            VStack(spacing: 0) {
                // Section Header
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedTab.rawValue)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(descriptionForTab(selectedTab))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Contextual Actions
                    if selectedTab == .general {
                        Button("Check System Access") {
                            showingPermissionsAlert = true
                        }
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .background(.regularMaterial)
                
                // Settings Content
                ScrollView {
                    LazyVStack(spacing: 24) {
                        switch selectedTab {
                        case .dictation:
                            DictationSettingsContent(
                                settings: settings,
                                showingApiKeySheet: $showingApiKeySheet,
                                currentProvider: $currentProvider,
                                apiKeyInput: $apiKeyInput
                            )
                        case .enhancement:
                            TextEnhancementSettingsContent(
                                settings: settings,
                                showingApiKeySheet: $showingApiKeySheet,
                                currentProvider: $currentProvider,
                                apiKeyInput: $apiKeyInput
                            )
                        case .general:
                            GeneralSettingsContent(settings: settings)
                        case .about:
                            AboutSettingsContent()
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 650)
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
    
    private func iconForTab(_ tab: SettingsTab) -> String {
        switch tab {
        case .dictation: return "mic.fill"
        case .enhancement: return "wand.and.stars.inverse"
        case .general: return "gearshape.fill"
        case .about: return "info.circle.fill"
        }
    }
    
    private func descriptionForTab(_ tab: SettingsTab) -> String {
        switch tab {
        case .dictation: return "Configure speech recognition and language settings"
        case .enhancement: return "Set up AI-powered text processing and formatting"
        case .general: return "App behavior and system permissions"
        case .about: return "Version information and acknowledgments"
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
    
    private func permissionStatus() -> String {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let accessibilityStatus: Bool = {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }()
        
        if micStatus && accessibilityStatus {
            return "✅ All permissions granted. Dictly is ready to use!"
        } else {
            return """
            Dictly requires additional system access:
            
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

// MARK: - Content Views

struct DictationSettingsContent: View {
    @ObservedObject var settings: Settings
    @Binding var showingApiKeySheet: Bool
    @Binding var currentProvider: String
    @Binding var apiKeyInput: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Speech Recognition Service
            SettingsGroup("Speech Recognition") {
                VStack(spacing: 16) {
                    SettingRow(label: "Service") {
                        Picker("", selection: $settings.transcriptionProviderRaw) {
                            ForEach(TranscriptionProvider.allCases, id: \.rawValue) { provider in
                                Text(provider.rawValue).tag(provider.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180, alignment: .trailing)
                    }
                    
                    if settings.transcriptionProviderRaw == "Groq Translations" {
                        InformationBanner(
                            text: "Understands speech in any language and converts it to English text",
                            icon: "globe.americas.fill",
                            color: Color("BrandBlue")
                        )
                    }

                    if settings.transcriptionProviderRaw == "Apple (On-Device)" {
                        InformationBanner(
                            text: "100% private, offline transcription. No API key required. Faster response times.",
                            icon: "lock.shield.fill",
                            color: Color("BrandMint")
                        )
                    }

                    if settings.transcriptionProviderRaw == "Parakeet (On-Device)" {
                        InformationBanner(
                            text: "On-device multilingual (25 languages). ANE-accelerated. No API key required. Works offline.",
                            icon: "cpu.fill",
                            color: Color("BrandMint")
                        )
                    }

                    // Show model selection (text field for custom, picker for others)
                    if settings.transcriptionProvider.supportsCustomBaseURL || settings.transcriptionProvider.availableModels.count > 1 {
                        SettingRow(label: "Model") {
                            if settings.transcriptionProvider.supportsCustomBaseURL {
                                TextField("whisper-1", text: $settings.transcriptionModel)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 180, alignment: .trailing)
                            } else {
                                Picker("", selection: $settings.transcriptionModel) {
                                    ForEach(settings.transcriptionProvider.availableModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 180, alignment: .trailing)
                            }
                        }
                    }
                    
                    if settings.transcriptionProviderRaw != "Groq Translations" {
                        SettingRow(label: "Language") {
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
                            .pickerStyle(.menu)
                            .frame(width: 180, alignment: .trailing)
                        }
                    }
                }
            }
            
            // Custom Base URL for OpenAI Compatible providers
            if settings.transcriptionProvider.supportsCustomBaseURL {
                SettingsGroup("Custom API Endpoint") {
                    VStack(spacing: 16) {
                        SettingRow(label: "Base URL") {
                            TextField("http://localhost:8000/v1/audio/transcriptions", text: $settings.customTranscriptionBaseURL)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 300, alignment: .trailing)
                        }

                        InformationBanner(
                            text: "For local Whisper servers, faster-whisper, or other OpenAI-compatible transcription APIs",
                            icon: "server.rack",
                            color: Color("BrandIndigo")
                        )
                    }
                }
            }

            // Account Settings (hide for on-device providers)
            if settings.transcriptionProvider.requiresAPIKey {
                SettingsGroup("Account") {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("API Key")
                                .font(.headline)
                                .fontWeight(.medium)
                            Text("Securely stored in your keychain")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        DictlyStatusIndicator(
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
            
            // Voice Activity Detection (hide for Apple - it has built-in VAD, show for Parakeet and cloud providers)
            if !settings.transcriptionProvider.isOnDevice || settings.transcriptionProviderRaw == "Parakeet (On-Device)" {
                SettingsGroup("Smart Voice Detection") {
                    VStack(spacing: 16) {
                        SettingRow(label: "Enable Smart Recording") {
                            Toggle("", isOn: $settings.enableVAD)
                                .toggleStyle(.switch)
                        }

                        if settings.enableVAD {
                        InformationBanner(
                            text: settings.transcriptionProviderRaw == "Parakeet (On-Device)"
                                ? "Real-time streaming transcription. Text appears as you speak, completely on-device."
                                : "Automatically starts recording when speech is detected and stops during silence",
                            icon: "waveform.and.mic",
                            color: Color("BrandTeal")
                        )

                        VStack(spacing: 12) {
                            SettingRow(label: "Noise Floor") {
                                VStack(alignment: .trailing, spacing: 4) {
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
                                        .frame(width: 120)

                                        Text("High")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }

                                    Text("Higher = detect speech in noisy environments")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }

                            SettingRow(label: "Min Speech Duration") {
                                VStack(alignment: .trailing, spacing: 4) {
                                    HStack {
                                        Text("0.1s")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .frame(width: 25, alignment: .leading)

                                        Slider(value: $settings.vadMinSpeechDuration, in: 0.1...1.0, step: 0.05)
                                            .frame(width: 200)

                                        Text("1.0s")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .frame(width: 25, alignment: .trailing)

                                        Text("\(settings.vadMinSpeechDuration, specifier: "%.2f")s")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .frame(width: 50, alignment: .trailing)
                                    }

                                    Text("Minimum length of speech to detect")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }

                            SettingRow(label: "Silence Timeout") {
                                VStack(alignment: .trailing, spacing: 4) {
                                    HStack {
                                        Text("0.5s")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .frame(width: 25, alignment: .leading)

                                        Slider(value: $settings.vadSilenceTimeout, in: 0.5...3.0, step: 0.1)
                                            .frame(width: 200)

                                        Text("3.0s")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .frame(width: 25, alignment: .trailing)

                                        Text("\(settings.vadSilenceTimeout, specifier: "%.1f")s")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .frame(width: 50, alignment: .trailing)
                                    }

                                    Text("How long to wait after speech stops")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                        }
                    }
                }
            }
            }

            // Keyboard Controls
            SettingsGroup("Keyboard Shortcuts") {
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
    }
}

struct TextEnhancementSettingsContent: View {
    @ObservedObject var settings: Settings
    @Binding var showingApiKeySheet: Bool
    @Binding var currentProvider: String
    @Binding var apiKeyInput: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Enable/Disable
            SettingsGroup("AI Polish") {
                VStack(spacing: 16) {
                    SettingRow(label: "Enable AI Processing") {
                        Toggle("", isOn: $settings.enableAIProcessing)
                            .toggleStyle(.switch)
                    }
                    
                    if settings.enableAIProcessing {
                        InformationBanner(
                            text: "Automatically improves your dictated text with grammar correction and smart formatting",
                            icon: "sparkles",
                            color: Color("BrandPurple")
                        )
                    }
                }
            }
            
            if settings.enableAIProcessing {
                // AI Service Configuration
                SettingsGroup("AI Service") {
                    VStack(spacing: 16) {
                        SettingRow(label: "Provider") {
                            Picker("", selection: $settings.transformationProviderRaw) {
                                ForEach(TransformationProvider.allCases, id: \.rawValue) { provider in
                                    Text(provider.rawValue).tag(provider.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 180, alignment: .trailing)
                        }
                        
                        SettingRow(label: "Model") {
                            if settings.transformationProvider.supportsCustomBaseURL {
                                TextField("gpt-oss-20b", text: $settings.transformationModel)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 180, alignment: .trailing)
                            } else {
                                Picker("", selection: $settings.transformationModel) {
                                    ForEach(settings.transformationProvider.availableModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 180, alignment: .trailing)
                            }
                        }
                    }
                }
                
                // Custom Base URL for OpenAI Compatible providers
                if settings.transformationProvider.supportsCustomBaseURL {
                    SettingsGroup("Custom API Endpoint") {
                        VStack(spacing: 16) {
                            SettingRow(label: "Base URL") {
                                TextField("http://localhost:11434/v1/chat/completions", text: $settings.customTransformationBaseURL)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 300, alignment: .trailing)
                            }
                            
                            InformationBanner(
                                text: "For local AI models like Ollama, LM Studio, or other OpenAI-compatible APIs",
                                icon: "server.rack",
                                color: Color("BrandIndigo")
                            )
                        }
                    }
                }
                
                // Account Settings (only show for providers that require API keys)
                if settings.transformationProvider.requiresApiKey {
                    SettingsGroup("Account") {
                        HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("API Key")
                                .font(.headline)
                                .fontWeight(.medium)
                            Text("Required for AI text processing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        DictlyStatusIndicator(
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
                
                // Custom Enhancement Prompt
                SettingsGroup("Polish Instructions") {
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
                            .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
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
}

struct GeneralSettingsContent: View {
    @ObservedObject var settings: Settings
    @State private var showingClearModelsAlert = false

    var body: some View {
        VStack(spacing: 20) {
            // App Behavior
            SettingsGroup("App Behavior") {
                SettingRow(label: "Launch Dictly at startup") {
                    Toggle("", isOn: $settings.startAtLogin)
                        .toggleStyle(.switch)
                }
            }

            // System Integration
            SettingsGroup("System Integration") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("System Permissions")
                                .font(.headline)
                                .fontWeight(.medium)
                            Text("Required for voice input and text insertion")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        SystemPermissionStatusView()
                    }

                    Text("Microphone access enables voice recording. Accessibility permission allows Dictly to insert text into any app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }

            // Storage Management
            SettingsGroup("Storage") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Downloaded Models")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("On-device transcription models (~600MB)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    Button(action: {
                        showingClearModelsAlert = true
                    }) {
                        Text("Clear models...")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .help("Remove downloaded models to free ~600MB of space")
                }
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

    private func clearDownloadedModels() {
        let fileManager = FileManager.default

        // Get app support directory
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("Failed to find Application Support directory")
            return
        }

        // Parakeet models path (FluidAudio)
        let fluidAudioPath = appSupportURL.appendingPathComponent("FluidAudio/Models")

        do {
            if fileManager.fileExists(atPath: fluidAudioPath.path) {
                try fileManager.removeItem(at: fluidAudioPath)
                print("Cleared Parakeet models at \(fluidAudioPath.path)")
            }
        } catch {
            print("Failed to clear Parakeet models: \(error.localizedDescription)")
        }

        // Apple SpeechAnalyzer models are managed by system, no manual cleanup needed
        print("Model cache cleared successfully")
    }
}

struct AboutSettingsContent: View {
    var body: some View {
        VStack(spacing: 24) {
            // App Identity
            SettingsGroup {
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        Image("Brand Icon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dictly")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("AI-Powered Voice Transcription")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Version 1.4.0 • Build 2025.10")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    VStack(spacing: 12) {
                        InfoDetailRow(title: "Platform", value: "macOS 15.0 or later")
                        InfoDetailRow(title: "Architecture", value: "Universal (Apple Silicon & Intel)")
                        InfoDetailRow(title: "License", value: "MIT License")
                        
                        HStack {
                            Text("Developer")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("beneric.studio") {
                                if let url = URL(string: "https://beneric.studio") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color("BrandBlue"))
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                NSCursor.pointingHand.set()
                            }
                        }
                    }
                }
            }
            
            // Features Overview  
            SettingsGroup("Features") {
                VStack(spacing: 12) {
                    FeatureRow(icon: "mic.fill", title: "Voice Dictation", description: "Convert speech to text with multiple language support", style: .brand)
                    FeatureRow(icon: "globe.americas.fill", title: "Translation", description: "Translate speech from any language to English", style: .monochrome)
                    FeatureRow(icon: "wand.and.stars.inverse", title: "AI Enhancement", description: "Intelligent text formatting and style improvement", style: .premium)
                    FeatureRow(icon: "keyboard", title: "System Integration", description: "Works seamlessly with any Mac application", style: .system)
                }
            }
        }
    }
}

// MARK: - Reusable Components

struct SettingsSidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 16)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isSelected ? 
                Color.dictlyBrandGradient :
                LinearGradient(colors: [.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String?
    let content: Content
    
    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = title {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct SettingRow<Control: View>: View {
    let label: String
    let control: Control
    
    init(label: String, @ViewBuilder control: () -> Control) {
        self.label = label
        self.control = control()
    }
    
    var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            control
        }
        .frame(minHeight: 20)
    }
}


struct InformationBanner: View {
    let text: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(16)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct KeyboardShortcutRow: View {
    let description: String
    let shortcut: String
    let detail: String
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(shortcut)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }
            
            HStack {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
}

struct SystemPermissionStatusView: View {
    @State private var microphoneGranted = false
    @State private var accessibilityGranted = false
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(microphoneGranted ? Color("BrandMint") : Color("BrandOrange"))
                    .frame(width: 6, height: 6)
                Text("Microphone")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                Circle()
                    .fill(accessibilityGranted ? Color("BrandMint") : Color("BrandOrange"))
                    .frame(width: 6, height: 6)
                Text("Accessibility")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }
}

struct InfoDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}


struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let style: DictlyIcon.IconStyle
    
    var body: some View {
        HStack(spacing: 12) {
            DictlyIcon(name: icon, size: 20, style: style)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
}

// MARK: - SwiftUI Wrapper for PasteableTextField

class PasteableSecureTextFieldView: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "v":
                return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
            case "c":
                return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
            case "x":
                return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
            case "a":
                return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

struct PasteableSecureTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    
    func makeNSView(context: Context) -> PasteableSecureTextFieldView {
        let textField = PasteableSecureTextFieldView()
        textField.placeholderString = placeholder
        textField.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textField.delegate = context.coordinator
        return textField
    }
    
    func updateNSView(_ nsView: PasteableSecureTextFieldView, context: Context) {
        nsView.stringValue = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: PasteableSecureTextField
        
        init(_ parent: PasteableSecureTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
    }
}

struct ApiKeyConfigurationSheet: View {
    let provider: String
    @Binding var apiKeyInput: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.dictlyBrandGradient)
                    .symbolRenderingMode(.hierarchical)
                
                VStack(spacing: 8) {
                    Text("Configure API Key")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Enter your \(provider) API key to enable the service")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("API Key")
                    .font(.headline)
                    .fontWeight(.medium)
                
                PasteableSecureTextField(text: $apiKeyInput, placeholder: "Paste your API key here")
                    .frame(height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                
                Text("Your API key is stored securely in the macOS Keychain and never shared.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)
                
                Button("Save") {
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKeyInput.isEmpty)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
        }
        .padding(32)
        .frame(width: 420, height: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Extensions


// MARK: - Window Controller

class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.setFrameAutosaveName("DictlySettings")
        window.contentView = NSHostingView(rootView: SettingsView())
        window.title = "Dictly Settings"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 800, height: 600)
        window.backgroundColor = NSColor.controlBackgroundColor
        
        self.init(window: window)
    }
}
