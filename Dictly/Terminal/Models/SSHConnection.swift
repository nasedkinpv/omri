//
//  SSHConnection.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  SSH connection profile data model
//

import Foundation

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

    init(
        id: UUID = UUID(),
        name: String = "",
        host: String,
        username: String,
        port: Int = 22,
        authMethod: AuthMethod = .password,
        keyPath: String? = nil
    ) {
        self.id = id
        self.name = name.isEmpty ? "\(username)@\(host)" : name
        self.host = host
        self.username = username
        self.port = port
        self.authMethod = authMethod
        self.keyPath = keyPath
    }

    /// SSH command components
    var sshCommand: (executable: String, args: [String]) {
        var args = [
            "\(username)@\(host)",
            "-p", "\(port)",
            // Accept new host keys without prompting
            "-o", "StrictHostKeyChecking=accept-new"
        ]

        if authMethod == .key, let keyPath = keyPath {
            args.append(contentsOf: ["-i", keyPath])
        }

        return ("/usr/bin/ssh", args)
    }
}
