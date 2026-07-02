//
//  AppVersion.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  App version read from the bundle (MARKETING_VERSION / CURRENT_PROJECT_VERSION
//  in the project are the single source of truth)
//

import Foundation

enum AppVersion {
    static var marketing: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// Display string for UI
    static var display: String {
        "Version \(marketing) (\(build))"
    }
}
