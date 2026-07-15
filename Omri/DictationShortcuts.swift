//
//  DictationShortcuts.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2026 beneric.studio. All rights reserved.
//
//  Global dictation hotkeys, backed by KeyboardShortcuts (Carbon RegisterEventHotKey under
//  the hood — no TCC permission, App Store safe). Two separate shortcuts because a registered
//  hotkey only fires on its exact chord: holding an extra modifier would suppress it rather
//  than modify it, so "dictate" and "dictate with AI" are distinct bindings.
//

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let dictate = Self("dictate", default: .init(.space, modifiers: [.option]))
    static let dictateWithAI = Self("dictateWithAI", default: .init(.space, modifiers: [.option, .shift]))
}
