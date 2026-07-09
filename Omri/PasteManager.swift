//
//  PasteManager.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//

import ApplicationServices
import Cocoa
import UserNotifications

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

@MainActor
protocol PasteManagerDelegate: AnyObject {
    func pasteManagerWillStartProcessing()
    func pasteManagerWillStartTransformation()  // New method for AI transformation phase
    func pasteManagerDidFinishProcessing()

    /// In-progress transcript from streaming providers; replaced on every update.
    func pasteManager(didUpdateVolatileText text: String)
    /// Final transcript. `inserted` is false when the text was only put on the clipboard.
    func pasteManager(didDeliver text: String, inserted: Bool)
}

@MainActor
class PasteManager {
    private let transformationService: TransformationService?
    weak var delegate: PasteManagerDelegate?

    init(
        transformationService: TransformationService? = nil,
        delegate: PasteManagerDelegate? = nil
    ) {
        self.transformationService = transformationService
        self.delegate = delegate
    }

    func processAndPasteText(_ text: String, withAI: Bool = true) async {
        delegate?.pasteManagerWillStartProcessing()

        // Respect both the parameter AND the settings toggle
        let shouldUseAI = withAI && Settings.shared.enableAIProcessing
        let processedText = await processText(text, withAI: shouldUseAI)

        // Check if terminal window is active - send to terminal instead of pasting
        #if os(macOS) && SSH_TERMINAL
        if TerminalWindowController.shared.isTerminalActive {
            TerminalWindowController.shared.sendText(processedText)
            delegate?.pasteManagerDidFinishProcessing()
            return
        }
        #endif

        copyToClipboard(processedText)
        let inserted = deliverToFrontmostApp()
        delegate?.pasteManager(didDeliver: processedText, inserted: inserted)
        delegate?.pasteManagerDidFinishProcessing()
    }

    /// Update volatile (in-progress) text that may change
    /// This replaces any previous volatile text at the cursor position
    /// Used by streaming transcription to show real-time feedback
    func updateVolatileText(_ text: String) async {
        // For volatile text updates in terminal, just show the new text
        // (Terminal doesn't support volatile text replacement)
        #if os(macOS) && SSH_TERMINAL
        if TerminalWindowController.shared.isTerminalActive {
            // For terminal, we could implement a "preview" mode
            // For now, just log the volatile text without showing it
            Logger.log("Volatile (terminal preview): '\(text)'", context: "Paste", level: .debug)
            return
        }
        #endif

        // Volatile text is never inserted into the target app — it changes as the model
        // refines it. It is only shown in the overlay.
        delegate?.pasteManager(didUpdateVolatileText: text)
    }

}

// MARK: - Text Processing
private extension PasteManager {
    func processText(_ text: String, withAI: Bool) async -> String {
        guard withAI else {
            Logger.log("AI processing disabled, using original text", context: "Transform", level: .debug)
            return removeSubjectLine(from: text)
        }

        Logger.log("Processing text with AI enabled using custom transformation prompt", context: "Transform", level: .info)

        // Try transformation
        Logger.log("Attempting transformation...", context: "Transform", level: .debug)
        if let transformed = await tryTransformation(text) {
            Logger.log("Transformation successful", context: "Transform", level: .info)
            return transformed
        }
        Logger.log("Transformation failed, trying fallback", context: "Transform", level: .warning)

        // No legacy AI formatting fallback - modern version only uses transformation
        Logger.log("All AI processing failed, using original text", context: "Transform", level: .warning)
        return removeSubjectLine(from: text)
    }
    
    func tryTransformation(_ text: String) async -> String? {
        guard let service = transformationService else {
            Logger.log("No transformation service available", context: "Transform", level: .warning)
            return nil
        }

        Logger.log("Transformation service available, attempting transform...", context: "Transform", level: .debug)

        // Notify delegate that AI transformation is starting
        // Already on MainActor (class is @MainActor)
        delegate?.pasteManagerWillStartTransformation()

        do {
            let processedPrompt = Settings.shared.processedTransformationPrompt(for: text)

            Logger.log("Using custom transformation prompt", context: "Transform", level: .debug)

            return try await service.transform(
                text: text,
                prompt: processedPrompt,
                model: Settings.shared.transformationModel,
                temperature: 0.7
            )
        } catch {
            Logger.log("Transformation service error: \(error)", context: "Transform", level: .error)
            await handleTransformationError(error)
            return nil
        }
    }
    
    func handleTransformationError(_ error: Error) async {
        guard let transformError = error as? TransformationError,
              transformError == .apiKeyMissing else { return }

        // Already on MainActor (class is @MainActor)
        showAPIKeyAlert()
    }
}

// MARK: - Clipboard & Paste
private extension PasteManager {
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        Logger.log("Copied to clipboard (\(text.count) chars, success: \(success))", context: "Paste", level: .debug)
    }

    /// The text is already on the clipboard by this point. Automatic insertion needs the
    /// Accessibility permission, which App Store apps may not use for this purpose
    /// (App Review guideline 2.4.5), so the MAS build always leaves the paste to the user.
    /// Returns whether insertion was attempted.
    func deliverToFrontmostApp() -> Bool {
        #if !MAS_BUILD
        if Settings.shared.automaticPaste {
            performPaste()
            return true
        }
        #endif
        return false
    }
}

#if !MAS_BUILD
// MARK: - Automatic Insertion (direct distribution only)
private extension PasteManager {
    func performPaste() {
        if !hasAccessibilityPermissions() {
            Logger.log("No accessibility permissions - using Cmd+V fallback (restart app after granting permissions)", context: "Paste", level: .warning)
            tryFallbackPaste()
            return
        }

        Logger.log("Attempting paste...", context: "Paste", level: .debug)
        if !tryAccessibilityPaste() {
            Logger.log("Accessibility paste failed, trying fallback (Cmd+V)", context: "Paste", level: .warning)
            tryFallbackPaste()
        } else {
            Logger.log("Accessibility paste succeeded", context: "Paste", level: .info)
        }
    }

    func hasAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func tryAccessibilityPaste() -> Bool {
        guard let textToPaste = NSPasteboard.general.string(forType: .string),
              !textToPaste.isEmpty else {
            Logger.log("No text in clipboard", context: "Paste", level: .warning)
            return false
        }

        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier as Int32?,
              let appName = NSWorkspace.shared.frontmostApplication?.localizedName else {
            Logger.log("Could not get frontmost application", context: "Paste", level: .error)
            return false
        }

        Logger.log("Frontmost app: \(appName) (pid: \(pid))", context: "Paste", level: .debug)

        let appElement = AXUIElementCreateApplication(pid)
        var focusedElement: AnyObject?

        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard focusResult == .success, focusedElement != nil else {
            // Error -25204 (kAXErrorAPIDisabled) means accessibility permissions aren't fully granted
            // This can happen after initial permission grant before app restart
            if focusResult.rawValue == -25204 {
                Logger.log("Accessibility API disabled - permissions may need app restart", context: "Paste", level: .warning)
            } else {
                Logger.log("No focused UI element (result: \(focusResult.rawValue))", context: "Paste", level: .debug)
            }
            return false
        }

        let axElement = unsafeBitCast(focusedElement!, to: AXUIElement.self)

        var isSettable: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(axElement, kAXValueAttribute as CFString, &isSettable)
        guard settableResult == .success, isSettable.boolValue else {
            Logger.log("Focused element is not settable (result: \(settableResult.rawValue), settable: \(isSettable.boolValue))", context: "Paste", level: .debug)
            return false
        }

        let setResult = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, textToPaste as CFTypeRef)
        if setResult != .success {
            Logger.log("Failed to set value (result: \(setResult.rawValue))", context: "Paste", level: .warning)
        }
        return setResult == .success
    }
    
    func tryFallbackPaste() {
        Logger.log("Simulating Cmd+V keypress", context: "Paste", level: .debug)
        let source = CGEventSource(stateID: .combinedSessionState)
        let pasteDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let pasteUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

        pasteDown?.flags = .maskCommand
        pasteUp?.flags = .maskCommand

        pasteDown?.post(tap: .cgSessionEventTap)
        pasteUp?.post(tap: .cgSessionEventTap)
        Logger.log("Cmd+V posted", context: "Paste", level: .debug)
    }
}
#endif

// MARK: - Helpers
private extension PasteManager {
    func removeSubjectLine(from text: String) -> String {
        // Fast path: check if text even contains "subject:" before expensive string operations
        let lowercased = text.lowercased()
        guard lowercased.hasPrefix("subject:") || lowercased.contains("\nsubject:") else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let lines = text.components(separatedBy: .newlines)
        if let firstLine = lines.first,
           firstLine.lowercased().starts(with: "subject:") {
            return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func showAPIKeyAlert() {
        // Use modern UserNotifications framework for non-intrusive notification
        let content = UNMutableNotificationContent()
        content.title = "API Key Required"
        content.body = "Set your API key in Omri Settings to enable AI processing."
        content.sound = nil // Silent to avoid workflow interruption

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.log("Failed to show notification: \(error.localizedDescription)", context: "Paste", level: .error)
            }
        }

        Logger.log("API key required - notification sent", context: "Paste", level: .info)
    }
}
