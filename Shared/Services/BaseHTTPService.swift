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

    // MARK: - Endpoint Validation

    /// Validate a custom endpoint by performing a lightweight health check
    /// Returns EndpointValidationState based on the response
    static func validateEndpoint(baseURL: String, apiKey: String = "", timeout: TimeInterval = 5.0) async -> EndpointValidationState {
        // Validate URL format
        guard let url = URL(string: baseURL) else {
            return .invalid("Invalid URL format")
        }

        // Ensure URL has a scheme
        guard url.scheme != nil else {
            return .invalid("URL must include protocol (http:// or https://)")
        }

        // Create a simple HEAD request for health check
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout

        // Add API key if provided
        if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .invalid("Invalid response from server")
            }

            // Accept 2xx success codes and 405 Method Not Allowed (some servers don't support HEAD)
            if (200...299).contains(httpResponse.statusCode) {
                return .valid
            } else if httpResponse.statusCode == 405 {
                // Retry with OPTIONS method if HEAD is not supported
                return await validateWithOptions(url: url, apiKey: apiKey, timeout: timeout)
            } else if httpResponse.statusCode == 404 {
                return .invalid("Endpoint not found (404)")
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return .invalid("Authentication failed (\(httpResponse.statusCode))")
            } else {
                return .invalid("Server error (\(httpResponse.statusCode))")
            }
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                return .invalid("Connection timed out")
            case .cannotConnectToHost, .cannotFindHost:
                return .invalid("Cannot connect to server")
            case .notConnectedToInternet:
                return .invalid("No internet connection")
            default:
                return .invalid("Network error: \(error.localizedDescription)")
            }
        } catch {
            return .invalid("Unexpected error: \(error.localizedDescription)")
        }
    }

    /// Fallback validation using OPTIONS method
    private static func validateWithOptions(url: URL, apiKey: String, timeout: TimeInterval) async -> EndpointValidationState {
        var request = URLRequest(url: url)
        request.httpMethod = "OPTIONS"
        request.timeoutInterval = timeout

        if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .invalid("Invalid response from server")
            }

            if (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 405 {
                // If OPTIONS also fails with 405, assume endpoint exists but doesn't support HEAD/OPTIONS
                // This is acceptable for custom API endpoints
                return .valid
            } else {
                return .invalid("Server error (\(httpResponse.statusCode))")
            }
        } catch {
            return .invalid("Connection failed")
        }
    }
}