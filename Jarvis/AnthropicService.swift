//
//  AnthropicService.swift
//  Jarvis
//
//  Created by Jaanu Megalathan on 2026-05-20.
//


//
//  AnthropicService.swift
//  Jarvis
//

import Foundation

class AnthropicService {
    private let apiKey: String
    private let endpoint = "https://api.anthropic.com/v1/messages"

    init(apiKey: String) { self.apiKey = apiKey }

    func chat(messages: [[String: String]], system: String = "You are Jarvis, a concise AI assistant.") async throws -> String {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue(apiKey,              forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",        forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model":      "claude-opus-4-5",
            "max_tokens": 1024,
            "system":     system,
            "messages":   messages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let content = json?["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw URLError(.badServerResponse)
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}