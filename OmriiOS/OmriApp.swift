//
//  OmriApp.swift
//  Omri (iOS)
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  iOS app entry point - SSH terminal with voice dictation
//

import SwiftUI

@main
struct OmriApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashView()
                    .onAppear {
                        // Show splash for 1.5 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showSplash = false
                            }
                        }
                    }
            } else {
                RootNavigationView()
            }
        }
    }
}
