//
//  CustomTerminalAccessory.swift
//  OmriiOS
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Custom keyboard accessory for iOS terminal with easy button customization
//
//  Usage:
//  1. Enable custom keyboard in TerminalSessionView.swift:
//     Uncomment the CustomTerminalAccessory code block in makeUIView()
//  2. Customize buttons by modifying the button arrays below
//  3. Add new button actions as methods in the TerminalKeyboardActions struct
//
//  Note: This is a standalone implementation (does not subclass SwiftTerm's TerminalAccessory)
//  because TerminalAccessory is not open for subclassing outside the SwiftTerm module.
//

import SwiftUI
import SwiftTerm
import UIKit

/// Custom terminal keyboard accessory with easy button customization
/// Provides a UIToolbar-based keyboard with common terminal keys and actions
class CustomTerminalAccessory: UIToolbar, UIInputViewAudioFeedback {

    weak var terminalView: TerminalView?

    // MARK: - Configuration

    /// Button groups to display (customize by adding/removing buttons)
    private let leftButtons: [KeyboardButton] = [
        .esc,
        .ctrl,
        // .tab // todo: since we limited on space on ios iphone. we should check if this keyboard can be natively scrollable.
    ]

    private let rightButtons: [KeyboardButton] = [
        //  .paste,    // remove for now
        .arrowUp,
        .arrowDown,
        // .arrowLeft,
        // .arrowRight
        .hideKeyboard
    ]

    // MARK: - Initialization

    init(frame: CGRect, terminalView: TerminalView) {
        self.terminalView = terminalView

        // Ensure non-zero frame to avoid layout constraint errors
        var validFrame = frame
        if validFrame.height == 0 {
            validFrame.size.height = 44  // Standard toolbar height
        }

        super.init(frame: validFrame)
        setupToolbar()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupToolbar() {
        // Enable auto-resizing for rotation and iPad multitasking
        autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Add layout margins for modern iOS appearance
        // This adds padding around toolbar items (8pt horizontal)
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 8,
            leading: 8,
            bottom: 8,
            trailing: 8
        )

        sizeToFit()

        var toolbarItems: [UIBarButtonItem] = []

        // Add left buttons
        for button in leftButtons {
            let item = createBarButtonItem(for: button)
            toolbarItems.append(item)
        }

        // Add flexible space
        toolbarItems.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil))

        // Add right buttons
        for button in rightButtons {
            let item = createBarButtonItem(for: button)
            toolbarItems.append(item)
        }

        items = toolbarItems
    }

    // MARK: - Button Creation

    private func createBarButtonItem(for button: KeyboardButton) -> UIBarButtonItem {
        let action = button.action

        if let systemImage = button.systemImage {
            let item = UIBarButtonItem(
                image: UIImage(systemName: systemImage),
                style: .plain,
                target: self,
                action: action
            )
            item.accessibilityLabel = button.accessibilityLabel
            return item
        } else {
            let item = UIBarButtonItem(
                title: button.title,
                style: .plain,
                target: self,
                action: action
            )
            item.accessibilityLabel = button.accessibilityLabel
            return item
        }
    }

    // MARK: - Audio Feedback

    var enableInputClicksWhenVisible: Bool { true }

    private func playClick() {
        #if os(iOS)
        UIDevice.current.playInputClick()
        #endif
    }

    // MARK: - Button Actions

    @objc private func escAction() {
        playClick()
        terminalView?.send([0x1b])  // ESC
    }

    @objc private func ctrlAction() {
        playClick()
        // Ctrl is a modifier - for simplicity, send Ctrl+C for now
        // Full Ctrl modifier support would require state management
        terminalView?.send([0x03])  // Ctrl+C
    }

    @objc private func tabAction() {
        playClick()
        terminalView?.send([0x09])  // TAB
    }

    @objc private func pasteAction() {
        playClick()
        if let clipboardText = UIPasteboard.general.string {
            terminalView?.send(Array(clipboardText.utf8))
        }
    }

    @objc private func arrowUpAction() {
        playClick()
        terminalView?.send([0x1b, 0x5b, 0x41])  // ESC [ A
    }

    @objc private func arrowDownAction() {
        playClick()
        terminalView?.send([0x1b, 0x5b, 0x42])  // ESC [ B
    }

    @objc private func arrowLeftAction() {
        playClick()
        terminalView?.send([0x1b, 0x5b, 0x44])  // ESC [ D
    }

    @objc private func arrowRightAction() {
        playClick()
        terminalView?.send([0x1b, 0x5b, 0x43])  // ESC [ C
    }

    @objc private func hideKeyboardAction() {
        playClick()
        _ = terminalView?.resignFirstResponder()
    }

    // MARK: - Safe Area Handling (iPhone X+ Home Indicator)

    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize

        // Add bottom padding to separate from keyboard (8pt spacing)
        size.height += 8

        // Add safe area inset for home indicator on iPhone X and later
        if #available(iOS 11.0, *) {
            size.height += safeAreaInsets.bottom
        }

        return size
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()

        // Recalculate size when safe area changes (rotation, multitasking)
        invalidateIntrinsicContentSize()
    }
}

// MARK: - Keyboard Button Definition

extension CustomTerminalAccessory {
    enum KeyboardButton {
        case esc
        case ctrl
        case tab
        case paste
        case arrowUp
        case arrowDown
        case arrowLeft
        case arrowRight
        case hideKeyboard

        var title: String? {
            switch self {
            case .esc: return "ESC"
            case .ctrl: return "^C"
            case .tab: return "TAB"
            case .paste: return "Paste"
            default: return nil
            }
        }

        var systemImage: String? {
            switch self {
            case .arrowUp: return "arrow.up"
            case .arrowDown: return "arrow.down"
            case .arrowLeft: return "arrow.left"
            case .arrowRight: return "arrow.right"
            case .hideKeyboard: return "keyboard.chevron.compact.down"
            default: return nil
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .esc: return "Escape"
            case .ctrl: return "Control C"
            case .tab: return "Tab"
            case .paste: return "Paste from Clipboard"
            case .arrowUp: return "Up Arrow"
            case .arrowDown: return "Down Arrow"
            case .arrowLeft: return "Left Arrow"
            case .arrowRight: return "Right Arrow"
            case .hideKeyboard: return "Hide Keyboard"
            }
        }

        var action: Selector {
            switch self {
            case .esc: return #selector(CustomTerminalAccessory.escAction)
            case .ctrl: return #selector(CustomTerminalAccessory.ctrlAction)
            case .tab: return #selector(CustomTerminalAccessory.tabAction)
            case .paste: return #selector(CustomTerminalAccessory.pasteAction)
            case .arrowUp: return #selector(CustomTerminalAccessory.arrowUpAction)
            case .arrowDown: return #selector(CustomTerminalAccessory.arrowDownAction)
            case .arrowLeft: return #selector(CustomTerminalAccessory.arrowLeftAction)
            case .arrowRight: return #selector(CustomTerminalAccessory.arrowRightAction)
            case .hideKeyboard: return #selector(CustomTerminalAccessory.hideKeyboardAction)
            }
        }
    }
}

// MARK: - Usage Examples (Commented Out)

/*

 Example 1: Enable Custom Keyboard
 ──────────────────────────────────
 In TerminalSessionView.swift, iOSTerminalView.makeUIView(), uncomment:

 let customAccessory = CustomTerminalAccessory(
     frame: CGRect(x: 0, y: 0, width: size.width, height: 44),
     terminalView: terminalView
 )
 terminalView.inputAccessoryView = customAccessory


 Example 2: Add New Button (Ctrl+Z)
 ───────────────────────────────────
 In CustomTerminalAccessory.swift:

 1. Add to KeyboardButton enum:
    case ctrlZ

 2. Update rightButtons array:
    private let rightButtons: [KeyboardButton] = [
        .paste,
        .ctrlZ,  // ← NEW
        .arrowUp,
        ...
    ]

 3. Add action method:
    @objc private func ctrlZAction() {
        playClick()
        terminalView?.send([0x1a])  // Ctrl+Z
    }

 4. Update KeyboardButton properties:
    var title: String? {
        case .ctrlZ: return "^Z"
        ...
    }

    var accessibilityLabel: String {
        case .ctrlZ: return "Control Z"
        ...
    }

    var action: Selector {
        case .ctrlZ: return #selector(CustomTerminalAccessory.ctrlZAction)
        ...
    }


 Example 3: Add Clear Screen Button
 ───────────────────────────────────
 1. Add to enum:
    case clear

 2. Add to leftButtons or floatButtons:
    private let leftButtons: [KeyboardButton] = [
        .esc,
        .ctrl,
        .tab,
        .clear  // ← NEW
    ]

 3. Add action:
    @objc private func clearAction() {
        playClick()
        // Send ESC [ H ESC [ 2 J (clear screen)
        terminalView?.send([0x1b, 0x5b, 0x48, 0x1b, 0x5b, 0x32, 0x4a])
    }

 4. Update enum properties...


 Common Terminal Sequences:
 ──────────────────────────
 Ctrl+A (Home):     [0x01]
 Ctrl+C (Interrupt):[0x03]
 Ctrl+D (EOF):      [0x04]
 Ctrl+E (End):      [0x05]
 Ctrl+Z (Suspend):  [0x1a]
 ESC:               [0x1b]
 TAB:               [0x09]
 ENTER:             [0x0d]

 Arrow Keys:
 Up:    [0x1b, 0x5b, 0x41]  // ESC [ A
 Down:  [0x1b, 0x5b, 0x42]  // ESC [ B
 Right: [0x1b, 0x5b, 0x43]  // ESC [ C
 Left:  [0x1b, 0x5b, 0x44]  // ESC [ D

 Function Keys:
 F1:  [0x1b, 0x4f, 0x50]    // ESC O P
 F2:  [0x1b, 0x4f, 0x51]    // ESC O Q
 F3:  [0x1b, 0x4f, 0x52]    // ESC O R
 F4:  [0x1b, 0x4f, 0x53]    // ESC O S

 */
