//
//  GlobalHotKey.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2026 beneric.studio. All rights reserved.
//
//  A system-wide press-to-talk hotkey built on Carbon's RegisterEventHotKey.
//
//  Unlike a global NSEvent monitor (Accessibility) or a CGEventTap (Input Monitoring),
//  RegisterEventHotKey needs no TCC permission and is allowed in the App Store sandbox:
//  the app only learns when this one chord is pressed, never any other input. It cannot
//  bind bare modifier keys like fn, which is why the hotkey is a normal key + modifiers.
//

import AppKit
import Carbon.HIToolbox

@MainActor
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onPress: () -> Void
    private let onRelease: () -> Void

    /// - Parameters:
    ///   - keyCode: a Carbon virtual key code (e.g. `kVK_Space`).
    ///   - modifiers: a Carbon modifier mask (`optionKey`, `cmdKey`, …).
    init(keyCode: UInt32, modifiers: UInt32, onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
        self.onPress = onPress
        self.onRelease = onRelease
        register(keyCode: keyCode, modifiers: modifiers)
    }

    private func register(keyCode: UInt32, modifiers: UInt32) {
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]

        // Carbon delivers hotkey events on the main run loop, so the handler is main-isolated.
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                let kind = GetEventKind(event)
                MainActor.assumeIsolated {
                    if kind == UInt32(kEventHotKeyPressed) {
                        hotKey.onPress()
                    } else if kind == UInt32(kEventHotKeyReleased) {
                        hotKey.onRelease()
                    }
                }
                return noErr
            },
            eventTypes.count,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        let id = EventHotKeyID(signature: OSType(0x4F_4D_52_49), id: 1)  // 'OMRI'
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            Logger.log("Failed to register global hotkey (status: \(status))", context: "Audio", level: .error)
        } else {
            Logger.log("Global hotkey registered", context: "Audio", level: .info)
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
