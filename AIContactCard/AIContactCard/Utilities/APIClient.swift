//
//  APIClient.swift
//  AIContactCard
//

import Foundation

enum APIError: Error, LocalizedError {
    case httpError(statusCode: Int, body: String)
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .httpError(let statusCode, let body):
            return "HTTP \(statusCode): \(body)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

struct APIClient {
    static let proxyURL = "https://ai-contact-card-proxy.ai-contact-cards-sz.workers.dev"
    static let model = "claude-sonnet-4-5-20250929"

    /// Standard call (query) — free-form text response
    static func send(messages: [[String: Any]], mode: String = "managed", apiKey: String? = nil) async throws -> Data {
        var body: [String: Any] = [
            "mode": mode,
            "messages": messages,
            "model": model
        ]
        if let apiKey {
            body["apiKey"] = apiKey
        }
        return try await post(body: body)
    }

    /// Structured call (extraction) — includes output_config for guaranteed JSON
    static func sendStructured(messages: [[String: Any]], outputSchema: [String: Any], mode: String = "managed", apiKey: String? = nil) async throws -> Data {
        var body: [String: Any] = [
            "mode": mode,
            "messages": messages,
            "model": model,
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": outputSchema
                ]
            ]
        ]
        if let apiKey {
            body["apiKey"] = apiKey
        }
        return try await post(body: body)
    }

    // MARK: - Private

    private static func post(body: [String: Any]) async throws -> Data {
        guard let url = URL(string: proxyURL) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? "No body"
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: bodyString)
        }

        return data
    }
}
