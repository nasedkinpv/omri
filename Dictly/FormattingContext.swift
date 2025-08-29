//
//  FormattingContext.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//
//

import Foundation

struct FormattingContext {
    let appName: String
    let appType: TextFormat

    var systemPrompt: String {
        let basePrompt = """
            You are an AI assistant that helps format text appropriately.
            Current context: Writing in \(appName)
            """

        switch appType {
        case .email:
            return basePrompt + """
                \n
                Format this text as a professional email:
                - Add appropriate greetings and closings
                - Structure in clear paragraphs
                - Maintain appropriate tone for email correspondence
                """
        case .message:
            return basePrompt + """
                \n
                Format this as a message:
                - Keep it brief and conversational
                - Use natural language
                - Maintain the core message
                """
        case .slack:
            return basePrompt + """
                \n
                Format this for Slack:
                - Use appropriate Slack formatting
                - Keep it professional but conversational
                - Add emoji when appropriate
                """
        case .terminal:
            return basePrompt + """
                \n
                Convert this natural language into appropriate terminal commands:
                - Use proper command syntax
                - Include necessary flags and options
                - Maintain the intended operation
                """
        case .default:
            return basePrompt + """
                \n
                Format this text appropriately while maintaining its original meaning.
                """
        }
    }
}
