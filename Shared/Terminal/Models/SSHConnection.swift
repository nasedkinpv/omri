//
//  SSHConnection.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  SSH connection profile data model
//

import Foundation
import Security

enum AuthMethod: String, Codable, CaseIterable {
    case password = "Password"
    case key = "SSH Key"
}

struct SSHConnection: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var username: String
    var port: Int
    var authMethod: AuthMethod
    var keyPath: String?  // Path to SSH key file
    var password: String?  // NOT persisted to disk for security - stored in Keychain

    enum CodingKeys: String, CodingKey {
        case id, name, host, username, port, authMethod, keyPath
        // Explicitly exclude password from Codable - stored in Keychain instead
    }

    /// Keychain key for this connection's password
    private var keychainPasswordKey: String {
        "ssh_password_\(id.uuidString)"
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        host: String,
        username: String,
        port: Int = 22,
        authMethod: AuthMethod = .password,
        keyPath: String? = nil,
        password: String? = nil
    ) {
        self.id = id
        self.name = name.isEmpty ? "\(username)@\(host)" : name
        self.host = host
        self.username = username
        self.port = port
        self.authMethod = authMethod
        self.keyPath = keyPath
        self.password = password
    }

    /// Save password to Keychain
    mutating func savePassword(_ password: String) {
        self.password = password
        _ = KeychainManager.shared.save(key: keychainPasswordKey, value: password)
    }

    /// Retrieve password from Keychain
    mutating func loadPassword() {
        if password == nil {
            password = KeychainManager.shared.retrieve(key: keychainPasswordKey)
        }
    }

    /// Delete password from Keychain
    func deletePassword() {
        _ = KeychainManager.shared.delete(key: keychainPasswordKey)
    }

    /// SSH command components
    var sshCommand: (executable: String, args: [String]) {
        var args = [
            "\(username)@\(host)",
            "-p", "\(port)",
            // Accept new host keys without prompting
            "-o", "StrictHostKeyChecking=accept-new",
            // Prevent "too many authentication failures"
            "-o", "IdentitiesOnly=yes"
        ]

        if authMethod == .key, let keyPath = keyPath {
            // Use specific key
            args.append(contentsOf: ["-i", keyPath])
        } else {
            // Password auth - don't try any keys
            args.append(contentsOf: [
                "-o", "PubkeyAuthentication=no",
                "-o", "PasswordAuthentication=yes"
            ])
        }

        return ("/usr/bin/ssh", args)
    }
}
