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
    case custom = "OpenAI Compatible"

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
        case .custom:
            return ["gpt-oss-20b"] // Default placeholder, user inputs their own model name
        }
    }

    var endpoint: String {
        switch self {
        case .groq: return "https://api.groq.com/openai/v1/chat/completions"
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .custom: return "http://localhost:11434/v1/chat/completions"
        }
    }
    
    var requiresApiKey: Bool {
        switch self {
        case .groq, .openai: return true
        case .custom: return false
        }
    }
    
    var supportsCustomBaseURL: Bool {
        switch self {
        case .groq, .openai: return false
        case .custom: return true
        }
    }
}
