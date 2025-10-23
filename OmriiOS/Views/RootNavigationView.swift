//
//  RootNavigationView.swift
//  Omri (iOS)
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Root navigation container using NavigationStack
//

import SwiftUI

struct RootNavigationView: View {
    @State private var connectionState = ConnectionState()
    @State private var showingSettings = false

    var body: some View {
        NavigationStack(path: $connectionState.navigationPath) {
            // Root view: SSH Connections list
            SSHConnectionsView(onConnect: { connection in
                connectionState.connect(to: connection)
            })
            .navigationTitle("SSH Connections")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .navigationDestination(for: SSHConnection.self) { connection in
                TerminalSessionView(
                    connection: connection,
                    connectionState: connectionState
                )
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
        .environment(connectionState)
    }
}

#Preview {
    RootNavigationView()
}
