//
//  TerminalSettings.swift
//  Dictly
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

    private init() {
        loadConnections()
        fontSize = UserDefaults.standard.double(forKey: "terminalFontSize")
        if fontSize == 0 { fontSize = 13.0 }
        colorScheme = UserDefaults.standard.string(forKey: "terminalColorScheme") ?? "Default"
    }

    func addConnection(_ connection: SSHConnection) {
        savedConnections.append(connection)
    }

    func removeConnection(_ connection: SSHConnection) {
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
