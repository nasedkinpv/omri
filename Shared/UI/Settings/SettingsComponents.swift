//
//  SettingsComponents.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Shared settings UI components (iOS + macOS)
//

import SwiftUI

#if os(macOS)
import AppKit
import AVFoundation
import ApplicationServices
#else
import UIKit
import AVFoundation
#endif

// MARK: - Icon Components

struct OmriIcon: View {
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
            AnyShapeStyle(Color.omriBrandGradient)
        case .premium:
            AnyShapeStyle(Color.omriPremiumGradient)
        case .monochrome:
            AnyShapeStyle(Color("BrandBlue"))
        case .system:
            AnyShapeStyle(Color.primary)
        }
    }
}

struct OmriStatusIndicator: View {
    let state: ConnectionState
    let service: ServiceType

    @Environment(\.horizontalSizeClass) var sizeClass

    enum ConnectionState {
        case connected, connecting, disconnected, error
    }

    enum ServiceType {
        case transcription, enhancement, general
    }

    // Responsive sizing: iPhone (10pt) → iPad (12pt)
    private var fontSize: CGFloat {
        sizeClass == .regular ? 12 : 10
    }

    var body: some View {
        Image(systemName: statusIcon)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(statusColor)
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

// MARK: - Layout Components

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
    let style: OmriIcon.IconStyle

    var body: some View {
        HStack(spacing: 12) {
            OmriIcon(name: icon, size: 20, style: style)
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

// MARK: - macOS Section Headers/Footers

struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

struct SettingsSectionFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

// MARK: - Platform-Specific Components

#if os(macOS)
struct SystemPermissionStatusView: View {
    @State private var microphoneGranted = false
    @State private var accessibilityGranted = false

    @Environment(\.horizontalSizeClass) var sizeClass

    // Responsive sizing: Compact (6pt) → Regular (8pt)
    private var circleSize: CGFloat {
        sizeClass == .regular ? 8 : 6
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(microphoneGranted ? Color("BrandMint") : Color("BrandOrange"))
                    .frame(width: circleSize, height: circleSize)
                Text("Microphone")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(accessibilityGranted ? Color("BrandMint") : Color("BrandOrange"))
                    .frame(width: circleSize, height: circleSize)
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
#else
struct SystemPermissionStatusView: View {
    @State private var microphoneGranted = false

    @Environment(\.horizontalSizeClass) var sizeClass

    // Responsive sizing: Compact (6pt) → Regular (8pt)
    private var circleSize: CGFloat {
        sizeClass == .regular ? 8 : 6
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(microphoneGranted ? Color("BrandMint") : Color("BrandOrange"))
                    .frame(width: circleSize, height: circleSize)
                Text("Microphone")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        // Modern iOS 17+ approach: Use AVAudioApplication for microphone permissions
        microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
    }
}
#endif

// MARK: - Secure Text Field (Platform-Specific)

#if os(macOS)
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
#else
// iOS uses native SecureField, no custom wrapper needed
typealias PasteableSecureTextField = SecureField<Text>
#endif

// MARK: - API Key Configuration Sheet

struct ApiKeyConfigurationSheet: View {
    let provider: String
    @Binding var apiKeyInput: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                OmriIcon(name: "key.fill", size: 32, style: .brand)

                Text("Configure API Key")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Enter your API key for \(provider)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            // API Key Input
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.subheadline)
                    .fontWeight(.medium)

                #if os(macOS)
                PasteableSecureTextField(text: $apiKeyInput, placeholder: "sk-...")
                    .textFieldStyle(.roundedBorder)
                #else
                SecureField("sk-...", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                #endif
            }

            // Help Text
            Text("Your API key is stored securely in the system keychain and never shared.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            // Actions
            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                #if os(macOS)
                .keyboardShortcut(.cancelAction)
                #endif

                Spacer()

                Button("Save") {
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKeyInput.isEmpty)
                #if os(macOS)
                .keyboardShortcut(.defaultAction)
                #endif
            }
        }
        .padding(32)
        #if os(macOS)
        .frame(minWidth: 400, idealWidth: 450, maxWidth: 600)
        #else
        .frame(maxWidth: .infinity)
        .presentationDetents([.medium])
        #endif
    }
}
