//
//  TerminalSettingsTab.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Terminal tab in Settings window - becomes iPad UI later
//

import SwiftUI

struct TerminalSettingsTab: View {
    @StateObject private var settings = TerminalSettings.shared

    @State private var host = ""
    @State private var username = ""
    @State private var port = "22"
    @State private var authMethod: AuthMethod = .password
    @State private var selectedKeyPath: String?
    @State private var connectionName = ""
    @State private var showingSaveSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Saved Connections
                savedConnectionsSection

                Divider()

                // New Connection
                newConnectionSection

                Divider()

                // Terminal Settings
                terminalSettingsSection
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var savedConnectionsSection: some View {
        GroupBox(label: Label("Saved Connections", systemImage: "server.rack")) {
            if settings.savedConnections.isEmpty {
                Text("No saved connections yet")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(settings.savedConnections) { connection in
                        savedConnectionRow(connection)
                    }
                }
            }
        }
    }

    private func savedConnectionRow(_ connection: SSHConnection) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(connection.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text("\(connection.username)@\(connection.host):\(connection.port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: connection.authMethod == .key ? "key.fill" : "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Connect") {
                openTerminal(with: connection)
            }
            .buttonStyle(.borderedProminent)

            Button(action: { settings.removeConnection(connection) }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }

    private var newConnectionSection: some View {
        GroupBox(label: Label("New Connection", systemImage: "plus.circle")) {
            Form {
                TextField("Host (e.g., server.example.com)", text: $host)
                TextField("Username", text: $username)
                TextField("Port", text: $port)

                Picker("Authentication", selection: $authMethod) {
                    ForEach(AuthMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }

                if authMethod == .key {
                    SSHKeyPickerView(selectedPath: $selectedKeyPath)
                }

                HStack {
                    Button("Save Connection") {
                        showingSaveSheet = true
                    }
                    .disabled(host.isEmpty || username.isEmpty)

                    Spacer()

                    Button("Quick Connect") {
                        let connection = makeConnection()
                        openTerminal(with: connection)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(host.isEmpty || username.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingSaveSheet) {
            saveConnectionSheet
        }
    }

    private var saveConnectionSheet: some View {
        VStack(spacing: 16) {
            Text("Save Connection")
                .font(.headline)

            TextField("Connection Name (optional)", text: $connectionName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    showingSaveSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    let connection = makeConnection(name: connectionName)
                    settings.addConnection(connection)
                    clearForm()
                    showingSaveSheet = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private var terminalSettingsSection: some View {
        GroupBox(label: Label("Terminal Settings", systemImage: "gearshape")) {
            Form {
                HStack {
                    Text("Font Size:")
                    Slider(value: $settings.fontSize, in: 10...20, step: 1)
                    Text("\(Int(settings.fontSize))pt")
                        .frame(width: 40, alignment: .trailing)
                }

                Picker("Color Scheme", selection: $settings.colorScheme) {
                    Text("Default").tag("Default")
                    Text("Solarized Dark").tag("Solarized Dark")
                    Text("Dracula").tag("Dracula")
                }
            }
        }
    }

    private func makeConnection(name: String = "") -> SSHConnection {
        SSHConnection(
            name: name,
            host: host,
            username: username,
            port: Int(port) ?? 22,
            authMethod: authMethod,
            keyPath: authMethod == .key ? selectedKeyPath : nil
        )
    }

    private func clearForm() {
        host = ""
        username = ""
        port = "22"
        authMethod = .password
        selectedKeyPath = nil
        connectionName = ""
    }

    private func openTerminal(with connection: SSHConnection) {
        #if os(macOS)
        TerminalWindowController.shared.connect(to: connection)
        #endif
    }
}

// SSH Key Picker
struct SSHKeyPickerView: View {
    @Binding var selectedPath: String?
    @State private var availableKeys: [URL] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SSH Key:")
                .font(.caption)
            Picker("SSH Key", selection: $selectedPath) {
                Text("Select Key...").tag(nil as String?)
                ForEach(availableKeys, id: \.path) { keyURL in
                    Text(keyURL.lastPathComponent).tag(keyURL.path as String?)
                }
            }

            Button("Browse...") {
                selectKeyFile()
            }
            .font(.caption)
        }
        .onAppear {
            loadSSHKeys()
        }
    }

    private func loadSSHKeys() {
        // Use getpwuid to get real home directory (sandbox returns container path)
        guard let pw = getpwuid(getuid()),
              let homeDir = String(validatingUTF8: pw.pointee.pw_dir) else {
            print("SSH Key Picker: Could not get home directory")
            return
        }

        let sshDir = URL(fileURLWithPath: homeDir).appendingPathComponent(".ssh")
        print("SSH Key Picker: Looking for keys in \(sshDir.path)")

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: sshDir,
            includingPropertiesForKeys: nil
        ) else {
            print("SSH Key Picker: Could not read .ssh directory")
            return
        }

        availableKeys = files.filter { url in
            let name = url.lastPathComponent
            return !name.hasSuffix(".pub") && !name.contains("known_hosts") && !name.contains("config")
        }

        print("SSH Key Picker: Found \(availableKeys.count) keys")
    }

    private func selectKeyFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowsOtherFileTypes = true
        panel.showsHiddenFiles = true  // Show hidden files like SSH keys

        // Use getpwuid to get real home directory
        if let pw = getpwuid(getuid()),
           let homeDir = String(validatingUTF8: pw.pointee.pw_dir) {
            let sshDir = URL(fileURLWithPath: homeDir).appendingPathComponent(".ssh")
            panel.directoryURL = sshDir
            print("SSH Key Picker: Opening panel at \(sshDir.path)")
        }

        if panel.runModal() == .OK {
            selectedPath = panel.url?.path
            print("SSH Key Picker: Selected key at \(panel.url?.path ?? "nil")")
        }
    }
}

#Preview {
    TerminalSettingsTab()
        .frame(width: 600, height: 500)
}
