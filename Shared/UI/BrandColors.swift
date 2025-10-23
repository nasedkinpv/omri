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

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Omri Brand Colors

extension Color {
    // Neutral System Colors (using semantic colors for better dark mode support)
    static let brandGray900 = Color.primary
    static let brandGray600 = Color.secondary

    #if os(macOS)
    static let brandGray100 = Color(NSColor.tertiaryLabelColor)
    static let brandGray300 = Color(NSColor.separatorColor)
    #else
    static let brandGray100 = Color(UIColor.tertiaryLabel)
    static let brandGray300 = Color(UIColor.separator)
    #endif

    // Brand Gradients (using asset catalog colors)
    static let omriBrandGradient = LinearGradient(
        colors: [Color("BrandBlue"), Color("BrandPurple")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let omriPremiumGradient = LinearGradient(
        colors: [Color("BrandIndigo"), Color("BrandPurple")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
