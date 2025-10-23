//
//  HTTPUtilities.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//

import Foundation

// MARK: - MIME Type Utilities

struct MIMETypeUtility {
    static func mimeType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "wav": return "audio/wav"
        case "mp3": return "audio/mpeg"
        case "mp4": return "audio/mp4"
        case "mpeg": return "audio/mpeg"
        case "mpga": return "audio/mpeg"
        case "m4a": return "audio/m4a"
        case "ogg": return "audio/ogg"
        case "flac": return "audio/flac"
        case "webm": return "audio/webm"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Multipart Form Data Extension

extension Data {
    @inlinable
    mutating func appendString(_ string: String) {
        append(contentsOf: string.utf8)
    }
}

extension URLRequest {
    mutating func setMultipartFormData(
        fileData: Data,
        fileName: String,
        mimeType: String,
        parameters: [String: CustomStringConvertible],
        arrayParameters: [String: [String]] = [:]
    ) {
        let boundary = UUID().uuidString
        setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.reserveCapacity(fileData.count + 2048)
        
        let boundaryBytes = "--\(boundary)\r\n".utf8
        let endBoundary = "--\(boundary)--\r\n".utf8
        
        // Add file
        body.append(contentsOf: boundaryBytes)
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n")
        
        // Add regular parameters
        for (key, value) in parameters {
            body.append(contentsOf: boundaryBytes)
            body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendString("\(value)\r\n")
        }
        
        // Add array parameters
        for (key, values) in arrayParameters {
            for value in values {
                body.append(contentsOf: boundaryBytes)
                body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.appendString("\(value)\r\n")
            }
        }
        
        body.append(contentsOf: endBoundary)
        httpBody = body
    }
}