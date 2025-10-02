//
//  PasteManager.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//

import ApplicationServices
import Cocoa
import UserNotifications

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

        copyToClipboard(processedText)
        performPaste()  // Paste immediately after clipboard copy
        delegate?.pasteManagerDidFinishProcessing()
    }

    func appendStreamingText(_ text: String, withAI: Bool = true) async {
        // For streaming, process AI transformation if needed but don't notify start/finish
        let shouldUseAI = withAI && Settings.shared.enableAIProcessing
        let processedText = await processText(text, withAI: shouldUseAI)

        // Append to existing text instead of replacing
        appendTextToCurrentPosition(processedText)
    }
    
}

// MARK: - Text Processing
private extension PasteManager {
    func processText(_ text: String, withAI: Bool) async -> String {
        guard withAI else {
            print("AI processing disabled, using original text")
            return removeSubjectLine(from: text)
        }
        
        print("Processing text with AI enabled using custom transformation prompt")
        
        // Try transformation
        print("Attempting transformation...")
        if let transformed = await tryTransformation(text) {
            print("Transformation successful")
            return transformed
        }
        print("Transformation failed, trying fallback")
        
        // No legacy AI formatting fallback - modern version only uses transformation
        print("All AI processing failed, using original text")
        return removeSubjectLine(from: text)
    }
    
    func tryTransformation(_ text: String) async -> String? {
        guard let service = transformationService else {
            print("No transformation service available")
            return nil
        }
        
        print("Transformation service available, attempting transform...")
        
        // Notify delegate that AI transformation is starting
        await MainActor.run {
            delegate?.pasteManagerWillStartTransformation()
        }
        
        do {
            let processedPrompt = Settings.shared.processedTransformationPrompt(for: text)
            
            print("Using custom transformation prompt")
            
            return try await service.transform(
                text: text,
                prompt: processedPrompt,
                model: Settings.shared.transformationModel,
                temperature: 0.7
            )
        } catch {
            print("Transformation service error: \(error)")
            await handleTransformationError(error)
            return nil
        }
    }
    
    func handleTransformationError(_ error: Error) async {
        guard let transformError = error as? TransformationError,
              transformError == .apiKeyMissing else { return }
        
        await MainActor.run {
            showAPIKeyAlert()
        }
    }
}

// MARK: - Clipboard & Paste
private extension PasteManager {
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        print("PasteManager: Copied to clipboard (\(text.count) chars, success: \(success))")
    }
    
    func performPaste() {
        if !hasAccessibilityPermissions() {
            print("⚠️ PasteManager: No accessibility permissions - using Cmd+V fallback (restart app after granting permissions)")
            tryFallbackPaste()
            return
        }

        print("PasteManager: Attempting paste...")
        if !tryAccessibilityPaste() {
            print("PasteManager: Accessibility paste failed, trying fallback (Cmd+V)")
            tryFallbackPaste()
        } else {
            print("✅ PasteManager: Accessibility paste succeeded")
        }
    }

    func appendTextToCurrentPosition(_ text: String) {
        if hasAccessibilityPermissions() {
            // Try native insertion first (more precise, preserves clipboard)
            if tryNativeStreamingInsertion(text) {
                print("✅ PasteManager: Native streaming insertion succeeded")
                return
            }
        }

        // Fall back to clipboard + Cmd+V approach (works even without accessibility)
        print("PasteManager: Streaming insertion using Cmd+V fallback")
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
            print("PasteManager: No text in clipboard")
            return false
        }

        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier as Int32?,
              let appName = NSWorkspace.shared.frontmostApplication?.localizedName else {
            print("PasteManager: Could not get frontmost application")
            return false
        }

        print("PasteManager: Frontmost app: \(appName) (pid: \(pid))")

        let appElement = AXUIElementCreateApplication(pid)
        var focusedElement: AnyObject?

        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard focusResult == .success, focusedElement != nil else {
            // Error -25204 (kAXErrorAPIDisabled) means accessibility permissions aren't fully granted
            // This can happen after initial permission grant before app restart
            if focusResult.rawValue == -25204 {
                print("PasteManager: Accessibility API disabled - permissions may need app restart")
            } else {
                print("PasteManager: No focused UI element (result: \(focusResult.rawValue))")
            }
            return false
        }

        let axElement = focusedElement as! AXUIElement

        var isSettable: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(axElement, kAXValueAttribute as CFString, &isSettable)
        guard settableResult == .success, isSettable.boolValue else {
            print("PasteManager: Focused element is not settable (result: \(settableResult.rawValue), settable: \(isSettable.boolValue))")
            return false
        }

        let setResult = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, textToPaste as CFTypeRef)
        if setResult != .success {
            print("PasteManager: Failed to set value (result: \(setResult.rawValue))")
        }
        return setResult == .success
    }
    
    func tryNativeStreamingInsertion(_ text: String) -> Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier as Int32? else {
            print("PasteManager: Could not get frontmost application PID")
            return false
        }

        let appElement = AXUIElementCreateApplication(pid)
        var focusedElement: AnyObject?

        // Get focused element
        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard focusResult == .success, let axElement = focusedElement as! AXUIElement? else {
            print("PasteManager: No focused UI element for native insertion")
            return false
        }

        // Get current text value
        var currentValue: AnyObject?
        let valueResult = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &currentValue)
        guard valueResult == .success, let currentText = currentValue as? String else {
            print("PasteManager: Could not read current text value")
            return false
        }

        // Get selected text range (cursor position)
        var rangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
        guard rangeResult == .success, let axValue = rangeValue as! AXValue? else {
            print("PasteManager: Could not read selected text range")
            return false
        }

        // Extract CFRange from AXValue
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            print("PasteManager: Could not extract CFRange from AXValue")
            return false
        }

        // Calculate insertion position
        let insertPosition = range.location

        // Validate insertion position
        guard insertPosition >= 0 && insertPosition <= currentText.count else {
            print("PasteManager: Invalid insertion position \(insertPosition) for text length \(currentText.count)")
            return false
        }

        // Insert text at cursor position
        let index = currentText.index(currentText.startIndex, offsetBy: insertPosition)
        let newText = String(currentText.prefix(upTo: index)) + text + String(currentText.suffix(from: index))

        // Write new text value
        let setValueResult = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, newText as CFTypeRef)
        guard setValueResult == .success else {
            print("PasteManager: Failed to set new text value (result: \(setValueResult.rawValue))")
            return false
        }

        // Update cursor position to after inserted text
        let newCursorPosition = insertPosition + text.count
        var newRange = CFRange(location: newCursorPosition, length: 0)

        // Create AXValue from CFRange
        guard let newRangeValue = AXValueCreate(.cfRange, &newRange) else {
            print("PasteManager: Warning - could not create AXValue for new cursor position")
            // Still return true because text was inserted successfully
            return true
        }

        let setRangeResult = AXUIElementSetAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, newRangeValue)

        if setRangeResult != .success {
            print("PasteManager: Warning - cursor position not updated (result: \(setRangeResult.rawValue))")
            // Still return true because text was inserted successfully
        }

        print("PasteManager: Native insertion - inserted \(text.count) chars at position \(insertPosition)")
        return true
    }

    func tryFallbackPaste() {
        print("PasteManager: Simulating Cmd+V keypress")
        let source = CGEventSource(stateID: .combinedSessionState)
        let pasteDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let pasteUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

        pasteDown?.flags = .maskCommand
        pasteUp?.flags = .maskCommand

        pasteDown?.post(tap: .cgSessionEventTap)
        pasteUp?.post(tap: .cgSessionEventTap)
        print("✅ PasteManager: Cmd+V posted")
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
    
    func createFormattingContext() -> FormattingContext {
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName?.lowercased() ?? ""
        
        let appType: TextFormat = switch appName {
        case "mail": .email
        case "messages": .message
        case "slack": .slack
        case "terminal", "iterm2": .terminal
        default: .default
        }
        
        return FormattingContext(appName: appName, appType: appType)
    }
    
    func showAPIKeyAlert() {
        // Use modern UserNotifications framework for non-intrusive notification
        let content = UNMutableNotificationContent()
        content.title = "API Key Required"
        content.body = "Set your API key in Dictly Settings to enable AI processing."
        content.sound = nil // Silent to avoid workflow interruption

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error.localizedDescription)")
            }
        }

        print("API key required - notification sent")
    }
}
