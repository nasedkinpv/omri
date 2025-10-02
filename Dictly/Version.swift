//
//  Version.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Single source of truth for app version information
//

import Foundation

struct AppVersion {
    /// Semantic version (major.minor.patch)
    static let marketing = "1.4.1"

    /// Build identifier (year.month or build number)
    static let build = "2025.10"

    /// Display string for UI
    static var display: String {
        "Version \(marketing) • Build \(build)"
    }

    /// Git tag format
    static var tag: String {
        "v\(marketing)"
    }
}
