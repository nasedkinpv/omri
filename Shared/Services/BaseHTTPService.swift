//
//  BaseHTTPService.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Generic HTTP service base class supporting both JSON and multipart requests
//

import Foundation

class BaseHTTPService: HTTPService {
    let apiKey: String
    let endpoint: String

    init(apiKey: String, endpoint: String) {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }

    // MARK: - Request Creation

    /// Create a base HTTP request with specified content type
    func createRequest(contentType: HTTPContentType) throws -> URLRequest {
        guard let url = URL(string: endpoint) else {
            throw HTTPError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(contentType.headerValue, forHTTPHeaderField: "Content-Type")

        // Only add Authorization header if API key is provided
        if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    /// Convenience method for JSON requests (backward compatibility)
    func createBaseRequest() throws -> URLRequest {
        return try createRequest(contentType: .json)
    }

    // MARK: - Response Handling

    /// Validate HTTP response and extract error messages if needed
    func handleHTTPResponse(_ data: Data, _ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = extractErrorMessage(from: data)
            throw HTTPError.apiError(
                statusCode: httpResponse.statusCode,
                message: errorMessage
            )
        }
    }

    /// Extract error message from API response
    func extractErrorMessage(from data: Data) -> String? {
        guard let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = errorJson["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }

    // MARK: - Generic Request Execution

    /// Perform a generic HTTP request with Decodable response
    func performRequest<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        try handleHTTPResponse(data, response)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw HTTPError.invalidResponse
        }
    }
}