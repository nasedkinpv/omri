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
        #if os(macOS)
        if TerminalWindowController.shared.isTerminalActive {
            TerminalWindowController.shared.sendText(processedText)
            delegate?.pasteManagerDidFinishProcessing()
            return
        }
        #endif

        copyToClipboard(processedText)
        performPaste()  // Paste immediately after clipboard copy
        delegate?.pasteManagerDidFinishProcessing()
    }

    func appendStreamingText(_ text: String, withAI: Bool = true) async {
        // For streaming, process AI transformation if needed but don't notify start/finish
        let shouldUseAI = withAI && Settings.shared.enableAIProcessing
        let processedText = await processText(text, withAI: shouldUseAI)

        // Check if terminal window is active - send to terminal instead
        #if os(macOS)
        if TerminalWindowController.shared.isTerminalActive {
            TerminalWindowController.shared.sendText(processedText)
            return
        }
        #endif

        // Append to existing text instead of replacing
        appendTextToCurrentPosition(processedText)
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

    func appendTextToCurrentPosition(_ text: String) {
        if hasAccessibilityPermissions() {
            // Try native insertion first (more precise, preserves clipboard)
            if tryNativeStreamingInsertion(text) {
                Logger.log("Native streaming insertion succeeded", context: "Paste", level: .info)
                return
            }
        }

        // Fall back to clipboard + Cmd+V approach (works even without accessibility)
        Logger.log("Streaming insertion using Cmd+V fallback", context: "Paste", level: .debug)
        copyToClipboard(text)
        tryFallbackPaste()
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

        let axElement = focusedElement as! AXUIElement

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
    
    func tryNativeStreamingInsertion(_ text: String) -> Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier as Int32? else {
            Logger.log("Could not get frontmost application PID", context: "Paste", level: .error)
            return false
        }

        let appElement = AXUIElementCreateApplication(pid)
        var focusedElement: AnyObject?

        // Get focused element
        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard focusResult == .success, let axElement = focusedElement as! AXUIElement? else {
            Logger.log("No focused UI element for native insertion", context: "Paste", level: .debug)
            return false
        }

        // Get current text value
        var currentValue: AnyObject?
        let valueResult = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &currentValue)
        guard valueResult == .success, let currentText = currentValue as? String else {
            Logger.log("Could not read current text value", context: "Paste", level: .debug)
            return false
        }

        // Get selected text range (cursor position)
        var rangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
        guard rangeResult == .success, let axValue = rangeValue as! AXValue? else {
            Logger.log("Could not read selected text range", context: "Paste", level: .debug)
            return false
        }

        // Extract CFRange from AXValue
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            Logger.log("Could not extract CFRange from AXValue", context: "Paste", level: .debug)
            return false
        }

        // Calculate insertion position
        let insertPosition = range.location

        // Validate insertion position
        guard insertPosition >= 0 && insertPosition <= currentText.count else {
            Logger.log("Invalid insertion position \(insertPosition) for text length \(currentText.count)", context: "Paste", level: .error)
            return false
        }

        // Insert text at cursor position
        let index = currentText.index(currentText.startIndex, offsetBy: insertPosition)
        let newText = String(currentText.prefix(upTo: index)) + text + String(currentText.suffix(from: index))

        // Write new text value
        let setValueResult = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, newText as CFTypeRef)
        guard setValueResult == .success else {
            Logger.log("Failed to set new text value (result: \(setValueResult.rawValue))", context: "Paste", level: .warning)
            return false
        }

        // Update cursor position to after inserted text
        let newCursorPosition = insertPosition + text.count
        var newRange = CFRange(location: newCursorPosition, length: 0)

        // Create AXValue from CFRange
        guard let newRangeValue = AXValueCreate(.cfRange, &newRange) else {
            Logger.log("Warning - could not create AXValue for new cursor position", context: "Paste", level: .warning)
            // Still return true because text was inserted successfully
            return true
        }

        let setRangeResult = AXUIElementSetAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, newRangeValue)

        if setRangeResult != .success {
            Logger.log("Warning - cursor position not updated (result: \(setRangeResult.rawValue))", context: "Paste", level: .warning)
            // Still return true because text was inserted successfully
        }

        Logger.log("Native insertion - inserted \(text.count) chars at position \(insertPosition)", context: "Paste", level: .debug)
        return true
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
