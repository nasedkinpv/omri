//
//  SSHConnectionsWindowController.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  macOS window controller for SSH connections management
//

#if os(macOS)
import Cocoa
import SwiftUI

class SSHConnectionsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.setFrameAutosaveName("OmriSSHConnections")
        window.contentView = NSHostingView(rootView: SSHConnectionsView())
        window.title = "SSH Connections"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 600, height: 500)
        window.backgroundColor = NSColor.controlBackgroundColor

        self.init(window: window)
    }
}
#endif
