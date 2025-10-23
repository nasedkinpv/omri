//
//  TerminalSettings.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Terminal settings and saved connections
//

import Foundation
import Combine

class TerminalSettings: ObservableObject {
    static let shared = TerminalSettings()

    @Published var savedConnections: [SSHConnection] = [] {
        didSet {
            saveConnections()
        }
    }

    #if os(macOS)
    @Published var fontSize: Double = 13.0 {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: "terminalFontSize")
        }
    }

    @Published var colorScheme: String = "Default" {
        didSet {
            UserDefaults.standard.set(colorScheme, forKey: "terminalColorScheme")
        }
    }
    #endif

    #if os(iOS)
    @Published var fontSize: Double = 12.0 {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: "terminalFontSize")
        }
    }

    // TODO: Future terminal customization settings (font family, color schemes)
    // @Published var fontFamily: String = "HackNFM-Regular"
    // @Published var colorScheme: String = "Default"
    #endif

    private init() {
        loadConnections()
        #if os(macOS)
        fontSize = UserDefaults.standard.double(forKey: "terminalFontSize")
        if fontSize == 0 { fontSize = 13.0 }
        colorScheme = UserDefaults.standard.string(forKey: "terminalColorScheme") ?? "Default"
        #elseif os(iOS)
        fontSize = UserDefaults.standard.double(forKey: "terminalFontSize")
        if fontSize == 0 { fontSize = 12.0 }
        #endif
    }

    func addConnection(_ connection: SSHConnection) {
        savedConnections.append(connection)
    }

    func removeConnection(_ connection: SSHConnection) {
        // Delete password from Keychain
        connection.deletePassword()

        // Remove from saved connections
        savedConnections.removeAll { $0.id == connection.id }
    }

    func updateConnection(_ connection: SSHConnection) {
        if let index = savedConnections.firstIndex(where: { $0.id == connection.id }) {
            savedConnections[index] = connection
        }
    }

    private func saveConnections() {
        if let encoded = try? JSONEncoder().encode(savedConnections) {
            UserDefaults.standard.set(encoded, forKey: "terminalConnections")
        }
    }

    private func loadConnections() {
        if let data = UserDefaults.standard.data(forKey: "terminalConnections"),
           let decoded = try? JSONDecoder().decode([SSHConnection].self, from: data) {
            savedConnections = decoded
        }
    }
}
