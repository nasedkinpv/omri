//
//  AboutSettingsContent.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Shared about settings content (iOS + macOS)
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct AboutSettingsContent: View {
    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iosLayout
        #endif
    }

    // MARK: - macOS Layout

    @ViewBuilder
    private var macOSLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App Identity
                VStack(spacing: 24) {
                    HStack(spacing: 16) {
                        Image("Brand Icon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Omri")
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            Text("AI-Powered Voice Transcription")
                                .font(.title3)
                                .foregroundColor(.secondary)

                            Text(AppVersion.display)
                                .font(.subheadline)
                                .foregroundColor(.secondary.opacity(0.7))
                        }

                        Spacer()
                    }

                    Divider()

                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 20, verticalSpacing: 10) {
                        GridRow {
                            Text("Platform")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .gridColumnAlignment(.trailing)
                            Text("macOS 26.0 or later")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        GridRow {
                            Text("Architecture")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .gridColumnAlignment(.trailing)
                            Text("Universal (Apple Silicon & Intel)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        GridRow {
                            Text("License")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .gridColumnAlignment(.trailing)
                            Text("MIT License")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        GridRow {
                            Text("Developer")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .gridColumnAlignment(.trailing)
                            Button("beneric.studio") {
                                openURL("https://beneric.studio")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color("BrandPrimary"))
                            .buttonStyle(.plain)
                            #if os(macOS)
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.pointingHand.set()
                                }
                            }
                            #endif
                        }
                    }
                }

                // Features Overview
                VStack(alignment: .leading, spacing: 16) {
                    Text("Features")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    VStack(spacing: 16) {
                        FeatureRow(icon: "mic.fill", title: "Voice Dictation", description: "Convert speech to text with multiple language support", style: .monochrome)
                        FeatureRow(icon: "globe.americas.fill", title: "Translation", description: "Translate speech from any language to English", style: .monochrome)
                        FeatureRow(icon: "sparkles", title: "AI Enhancement", description: "Intelligent text formatting and style improvement", style: .monochrome)
                        FeatureRow(icon: "square.grid.2x2.fill", title: "System Integration", description: "Works seamlessly with any Mac application", style: .monochrome)
                    }
                }

                // Permissions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Permissions")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    permissionsContent
                }

                // Acknowledgments
                VStack(alignment: .leading, spacing: 16) {
                    Text("Acknowledgments")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    acknowledgmentsContent
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
            // App Identity
            Section {
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        Image("Brand Icon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Omri")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("AI-Powered Voice Transcription")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(AppVersion.display)
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.7))
                        }

                        Spacer()
                    }

                    Divider()

                    VStack(spacing: 12) {
                        InfoDetailRow(title: "Platform", value: "iOS 26.0 or later")
                        InfoDetailRow(title: "Architecture", value: "Universal")
                        InfoDetailRow(title: "License", value: "MIT License")

                        HStack {
                            Text("Developer")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button("beneric.studio") {
                                openURL("https://beneric.studio")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color("BrandPrimary"))
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Features Overview
            Section("Features") {
                FeatureRow(icon: "mic.fill", title: "Voice Dictation", description: "Convert speech to text with multiple language support", style: .monochrome)
                FeatureRow(icon: "globe.americas.fill", title: "Translation", description: "Translate speech from any language to English", style: .monochrome)
                FeatureRow(icon: "sparkles", title: "AI Enhancement", description: "Intelligent text formatting and style improvement", style: .monochrome)
                FeatureRow(icon: "square.grid.2x2.fill", title: "System Integration", description: "Works seamlessly with any iOS application", style: .monochrome)
            }

            // Acknowledgments
            Section("Acknowledgments") {
                acknowledgmentsContent
            }
        }
    }

    // MARK: - Permissions (macOS)

    @ViewBuilder
    private var permissionsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(
                icon: "mic.fill",
                title: "Microphone",
                description: "Records your voice for transcription. Audio is processed on-device or sent only to the cloud provider you choose.",
                style: .monochrome
            )
            FeatureRow(
                icon: "keyboard.fill",
                title: "Input Monitoring",
                description: "Detects the fn key while another app is focused, so you can start dictating without switching to Omri. Only modifier keys are read; keystrokes are never recorded.",
                style: .monochrome
            )
            #if !MAS_BUILD
            FeatureRow(
                icon: "doc.on.clipboard.fill",
                title: "Accessibility",
                description: "Inserts transcribed text at your cursor in the app you're using. Omri never reads screen contents. If declined, the transcript is copied to the clipboard instead.",
                style: .monochrome
            )
            #endif
        }
    }


    // MARK: - Acknowledgments (shared)

    @ViewBuilder
    private var acknowledgmentsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("On-device transcription uses the NVIDIA Nemotron 3.5 ASR model. Copyright © NVIDIA Corporation. Licensed under the OpenMDW-1.1 license. CoreML conversion and runtime by FluidAudio (Apache-2.0).")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            #if os(macOS)
            Text("The dictation overlay is built with DynamicNotchKit by Kai Azim (MIT).")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            #endif

            HStack(spacing: 16) {
                Button("OpenMDW-1.1 License") {
                    openURL("https://openmdw.ai/license/1-1/")
                }
                Button("Model Card") {
                    openURL("https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b")
                }
                Button("FluidAudio") {
                    openURL("https://github.com/FluidInference/FluidAudio")
                }
                #if os(macOS)
                Button("DynamicNotchKit") {
                    openURL("https://github.com/MrKai77/DynamicNotchKit")
                }
                #endif
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(Color("BrandPrimary"))
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helper Methods

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }

        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }
}
