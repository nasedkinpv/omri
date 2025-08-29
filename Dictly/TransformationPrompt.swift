//
//  TransformationPrompt.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//
//
import Foundation


enum TransformationProvider: String, CaseIterable {
    case groq = "Groq"
    case openai = "OpenAI"

    var availableModels: [String] {
        switch self {
        case .groq:
            return [
                "llama-3.3-70b-versatile",
                "llama-3.1-8b-instant",
            ]
        case .openai:
            return [
                "gpt-5",
                "gpt-5-mini",
                "gpt-5-nano",
            ]
        }
    }

    var endpoint: String {
        switch self {
        case .groq: return "https://api.groq.com/openai/v1/chat/completions"
        case .openai: return "https://api.openai.com/v1/chat/completions"
        }
    }
}
