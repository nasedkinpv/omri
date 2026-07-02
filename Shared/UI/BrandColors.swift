//
//  BrandColors.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Shared brand colors and gradients (iOS + macOS)
//

import SwiftUI

// MARK: - Omri Brand Colors

extension Color {
    // Brand Gradient (Vivid Royal → Glaucous, asset catalog colors)
    static let omriBrandGradient = LinearGradient(
        colors: [Color("BrandPrimary"), Color("BrandSecondary")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
