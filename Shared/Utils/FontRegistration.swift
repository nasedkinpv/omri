//
//  FontRegistration.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Programmatic font registration for macOS
//  Registers Hack Nerd Font family for terminal use
//

#if os(macOS)
import AppKit
import CoreText

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

struct FontRegistration {
    /// Registers Hack Nerd Font family for terminal use
    ///
    /// Call this once during app launch (AppDelegate.applicationDidFinishLaunching)
    /// Uses CTFontManagerRegisterFontURLs with .process scope (fonts available only to this app)
    ///
    /// Registered fonts:
    /// - HackNFM-Regular (HackNerdFontMono-Regular.ttf)
    /// - HackNFM-Bold (HackNerdFontMono-Bold.ttf)
    /// - HackNFM-Italic (HackNerdFontMono-Italic.ttf)
    /// - HackNFM-BoldItalic (HackNerdFontMono-BoldItalic.ttf)
    static func registerHackNerdFont() {
        guard let resourcePath = Bundle.main.resourcePath else {
            Logger.log("Cannot find bundle resources", context: "Fonts", level: .error)
            return
        }

        let fontFiles = [
            "HackNerdFontMono-Regular.ttf",
            "HackNerdFontMono-Bold.ttf",
            "HackNerdFontMono-Italic.ttf",
            "HackNerdFontMono-BoldItalic.ttf"
        ]

        let fontURLs = fontFiles.compactMap { fileName -> URL? in
            let url = URL(fileURLWithPath: resourcePath).appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: url.path) else {
                Logger.log("Font file not found: \(fileName)", context: "Fonts", level: .warning)
                return nil
            }
            return url
        }

        guard !fontURLs.isEmpty else {
            Logger.log("No Hack Nerd Font files found in bundle", context: "Fonts", level: .error)
            return
        }

        // Register fonts using modern Core Text API
        // .process scope = fonts available only to this app's process (not system-wide)
        var hasErrors = false
        CTFontManagerRegisterFontURLs(
            fontURLs as CFArray,
            .process,
            true  // enabled = true
        ) { errors, success in
            if !success {
                hasErrors = true
                if let errors = errors as? [CFError] {
                    for error in errors {
                        Logger.log("Font registration error: \(error)", context: "Fonts", level: .error)
                    }
                }
            }
            return true  // Continue processing
        }

        if !hasErrors {
            Logger.log("✅ Registered \(fontURLs.count) Hack Nerd Font variants", context: "Fonts", level: .info)
        } else {
            Logger.log("⚠️ Font registration completed with some errors", context: "Fonts", level: .warning)
        }
    }
}
#endif
