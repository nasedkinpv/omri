//
//  TextFormat.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//

import Foundation

enum TextFormat {
    case email
    case message
    case slack
    case terminal
    case `default`

    var capitalizesSentences: Bool {
        switch self {
        case .email:
            return true
        default:
            return false
        }
    }
}
