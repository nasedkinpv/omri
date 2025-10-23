//
//  SSHConnectionsView.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  SSH connections manager - iOS-native Form/List, macOS GroupBox
//  Cross-platform SwiftUI view for managing SSH connections
//

import SwiftUI

struct SSHConnectionsView: View {
    @StateObject private var settings = TerminalSettings.shared

    // Connection form state
    @State private var host = ""
    @State private var username = ""
    @State private var port = "22"
    @State private var password = ""
    @State private var authMethod: AuthMethod = .password
    @State private var selectedKeyPath: String?
    @State private var connectionName = ""
    @State private var showingSaveSheet = false

    // Focus management for keyboard navigation
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case host, username, port, password, keyPath, connectionName
    }

    // Optional callback for connection (iOS will use this for navigation)
    var onConnect: ((SSHConnection) -> Void)?

    var body: some View {
        #if os(iOS)
        iosLayout
        #else
        macOSLayout
        #endif
    }

    // MARK: - iOS Native Layout

    @ViewBuilder
    private var iosLayout: some View {
        List {
            // Saved Connections Section
            Section {
                if settings.savedConnections.isEmpty {
                    Text("No saved connections yet")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(settings.savedConnections) { connection in
                        savedConnectionRow(connection)
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            settings.removeConnection(settings.savedConnections[index])
                        }
                    }
                }
            } header: {
                Label("Saved Connections", systemImage: "server.rack")
            }

            // New Connection Form Section
            Section {
                TextField(text: $host, prompt: Text("server.example.com")) {
                    Text("Host")
                }
                #if os(iOS)
                .autocapitalization(.none)
                .textContentType(.URL)
                .submitLabel(.next)
                #endif
                .autocorrectionDisabled()
                .focused($focusedField, equals: .host)
                .onSubmit { focusedField = .username }

                TextField(text: $username, prompt: Text("username")) {
                    Text("Username")
                }
                #if os(iOS)
                .autocapitalization(.none)
                .textContentType(.username)
                .submitLabel(.next)
                #endif
                .autocorrectionDisabled()
                .focused($focusedField, equals: .username)
                .onSubmit { focusedField = .port }

                TextField(text: $port, prompt: Text("22")) {
                    Text("Port")
                }
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .focused($focusedField, equals: .port)
            } header: {
                Label("New Connection", systemImage: "plus.circle")
            }

            // Authentication Section
            Section("Authentication") {
                Picker("Method", selection: $authMethod) {
                    ForEach(AuthMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)

                if authMethod == .password {
                    SecureField(text: $password, prompt: Text("Required")) {
                        Text("Password")
                    }
                    #if os(iOS)
                    .textContentType(.password)
                    .submitLabel(.go)
                    #endif
                    .focused($focusedField, equals: .password)
                    .onSubmit { attemptQuickConnect() }
                } else if authMethod == .key {
                    TextField(text: Binding(
                        get: { selectedKeyPath ?? "" },
                        set: { selectedKeyPath = $0.isEmpty ? nil : $0 }
                    ), prompt: Text("~/.ssh/id_rsa")) {
                        Text("SSH Key Path")
                    }
                    #if os(iOS)
                    .autocapitalization(.none)
                    .submitLabel(.go)
                    #endif
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .keyPath)
                    .onSubmit { attemptQuickConnect() }
                }
            }

            // Action Buttons Section
            Section {
                Button {
                    attemptQuickConnect()
                } label: {
                    Label("Quick Connect", systemImage: "arrow.right.circle.fill")
                }
                .disabled(!isFormValid)

                Button {
                    showingSaveSheet = true
                } label: {
                    Label("Save Connection", systemImage: "square.and.arrow.down")
                }
                .disabled(!isFormValid)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .sheet(isPresented: $showingSaveSheet) {
            iosSaveSheet
        }
    }

    private var iosSaveSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $connectionName, prompt: Text("My Server")) {
                        Text("Connection Name")
                    }
                    #if os(iOS)
                    .autocapitalization(.words)
                    .submitLabel(.done)
                    #endif
                    .focused($focusedField, equals: .connectionName)
                    .onSubmit { saveConnection() }
                } header: {
                    Text("Name")
                } footer: {
                    Text("Give this connection a memorable name")
                }

                Section("Details") {
                    LabeledContent("Host", value: host)
                    LabeledContent("Username", value: username)
                    LabeledContent("Port", value: port)
                    LabeledContent("Auth", value: authMethod.rawValue)
                }
            }
            .navigationTitle("Save Connection")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingSaveSheet = false
                        connectionName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConnection()
                    }
                    .fontWeight(.semibold)
                    .disabled(connectionName.isEmpty)
                }
            }
            .onAppear {
                focusedField = .connectionName
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - macOS Layout

    @ViewBuilder
    private var macOSLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Saved Connections
                savedConnectionsSection

                Divider()

                // New Connection
                newConnectionSection
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

    private var newConnectionSection: some View {
        GroupBox(label: Label("New Connection", systemImage: "plus.circle")) {
            VStack(spacing: 16) {
                TextField("Host (e.g., server.example.com)", text: $host)
                    .textFieldStyle(.roundedBorder)

                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)

                TextField("Port", text: $port)
                    .textFieldStyle(.roundedBorder)

                Picker("Authentication", selection: $authMethod) {
                    ForEach(AuthMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)

                if authMethod == .password {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                } else if authMethod == .key {
                    TextField("SSH Key Path (e.g., ~/.ssh/id_rsa)", text: Binding(
                        get: { selectedKeyPath ?? "" },
                        set: { selectedKeyPath = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 12) {
                    Button("Save") {
                        showingSaveSheet = true
                    }
                    .disabled(host.isEmpty || username.isEmpty)
                    .frame(maxWidth: .infinity)

                    Button("Quick Connect") {
                        let connection = makeConnection()
                        connectTo(connection)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(host.isEmpty || username.isEmpty)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showingSaveSheet) {
            macOSSaveSheet
        }
    }

    private var macOSSaveSheet: some View {
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
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }

    // MARK: - Shared Components

    private func savedConnectionRow(_ connection: SSHConnection) -> some View {
        #if os(iOS)
        Button {
            connectTo(connection)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(connection.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    HStack(spacing: 6) {
                        Text("\(connection.username)@\(connection.host):\(connection.port)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: connection.authMethod == .key ? "key.fill" : "lock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        #else
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
                connectTo(connection)
            }
            .buttonStyle(.borderedProminent)

            Button(action: { settings.removeConnection(connection) }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
        }
        .padding(.vertical, 4)
        #endif
    }

    // MARK: - Helper Methods

    private var isFormValid: Bool {
        !host.isEmpty && !username.isEmpty
    }

    private func attemptQuickConnect() {
        guard isFormValid else { return }
        let connection = makeConnection()
        connectTo(connection)
    }

    private func saveConnection() {
        guard !connectionName.isEmpty else { return }
        let connection = makeConnection(name: connectionName)
        settings.addConnection(connection)
        clearForm()
        showingSaveSheet = false
    }

    private func makeConnection(name: String = "") -> SSHConnection {
        var connection = SSHConnection(
            name: name,
            host: host,
            username: username,
            port: Int(port) ?? 22,
            authMethod: authMethod,
            keyPath: authMethod == .key ? selectedKeyPath : nil
        )

        // Save password to Keychain if using password auth
        if authMethod == .password && !password.isEmpty {
            connection.savePassword(password)
        }

        return connection
    }

    private func clearForm() {
        host = ""
        username = ""
        port = "22"
        password = ""
        authMethod = .password
        selectedKeyPath = nil
        connectionName = ""
        focusedField = nil
    }

    private func connectTo(_ connection: SSHConnection) {
        #if os(macOS)
        // macOS: Open terminal window
        TerminalWindowController.shared.connect(to: connection)
        #else
        // iOS: Use callback for navigation
        onConnect?(connection)
        #endif
    }
}

// MARK: - Preview

#Preview("iOS") {
    NavigationStack {
        SSHConnectionsView()
            .navigationTitle("SSH Connections")
    }
}

#Preview("macOS") {
    SSHConnectionsView()
        .frame(width: 600, height: 500)
}
