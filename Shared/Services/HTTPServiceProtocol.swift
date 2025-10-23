//
//  HTTPServiceProtocol.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Protocol-based HTTP service layer for modern Swift networking
//

import Foundation

// MARK: - HTTP Service Protocol

protocol HTTPService {
    var apiKey: String { get }
    var endpoint: String { get }
}

// MARK: - Content Type

enum HTTPContentType {
    case json
    case multipartFormData(boundary: String)

    var headerValue: String {
        switch self {
        case .json:
            return "application/json"
        case .multipartFormData(let boundary):
            return "multipart/form-data; boundary=\(boundary)"
        }
    }
}

// MARK: - HTTP Error

enum HTTPError: Error, LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case apiError(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Invalid API endpoint URL configured."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .apiError(let statusCode, let message):
            return "API error (Status \(statusCode)): \(message ?? "No additional details")"
        }
    }
}
