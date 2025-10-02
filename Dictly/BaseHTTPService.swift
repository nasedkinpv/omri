//
//  BaseHTTPService.swift  
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//

import Foundation

class BaseHTTPService {
    let apiKey: String
    let endpoint: String
    
    init(apiKey: String, endpoint: String) {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }
    
    func createBaseRequest() throws -> URLRequest {
        guard let url = URL(string: endpoint) else {
            throw TransformationError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Only add Authorization header if API key is provided
        if !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
    
    func handleHTTPResponse(_ data: Data, _ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransformationError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = extractErrorMessage(from: data)
            throw TransformationError.apiError(
                statusCode: httpResponse.statusCode, 
                message: errorMessage
            )
        }
    }
    
    private func extractErrorMessage(from data: Data) -> String? {
        guard let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = errorJson["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }
}