//
//  SplashView.swift
//  Omri (iOS)
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Launch splash screen with animated logo
//

import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0

    var body: some View {
        ZStack {
            // Background gradient
            Color.omriBrandGradient
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // App icon/logo
                Image(systemName: "terminal.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .scaleEffect(scale)
                    .opacity(opacity)

                // App name
                Text("Omri")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(opacity)

                // Tagline
                Text("SSH Terminal with Voice")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    SplashView()
}
