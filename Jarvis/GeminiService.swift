//
//  GeminiService.swift
//  Jarvis
//
//  Created by Jaanu Megalathan on 2026-05-20.
//

import Foundation


// Replace the three model strings with these:
enum GeminiModel: String {
    case flashLite = "gemini-3.1-flash-lite-preview"
//    case flash     = "gemini-2.5-flash"        // your working model — stays as default
    case pro       = "gemini-3.5-flash"
}

class GeminiService {
    private let apiKey: String
    private let base = "https://generativelanguage.googleapis.com/v1beta/models"

    // Rate limit tracking per model
    private var requestTimestamps: [GeminiModel: [Date]] = [
        .flashLite: [], /*.flash: [],*/ .pro: []
    ]
    private let rpmLimits: [GeminiModel: Int] = [
        .flashLite: 15, /*.flash: 10, */.pro: 5
    ]

    init(apiKey: String) { self.apiKey = apiKey }

    // MARK: - Model Selection

    static func selectModel(for input: String) -> GeminiModel {
        let q = input.lowercased()

        // Pro: complex reasoning, math, deep analysis
        let proKeywords = [
            "explain", "analyze", "compare", "difference", "why does",
            "how does", "calculate", "solve", "reason", "think through",
            "step by step", "pros and cons", "summarize"
        ]

        // Flash: normal conversational queries, weather, tools
        let flashKeywords = [
            "weather", "reminder", "what is", "who is", "when",
            "where", "tell me", "give me", "show me", "find"
        ]

        // Flash-Lite: short commands, app control, music, quick facts
        let liteKeywords = [
            "open", "play", "stop", "pause", "close", "set",
            "turn on", "turn off", "volume", "hi", "hello", "thanks"
        ]

        if proKeywords.contains(where: q.contains)  { return .pro       }
        if liteKeywords.contains(where: q.contains) { return .flashLite }
//        if flashKeywords.contains(where: q.contains){ return .flash     }

        return .flashLite// default
    }

    // MARK: - Rate Limit Check

    private func isRateLimited(_ model: GeminiModel) -> Bool {
        let now = Date()
        let windowStart = now.addingTimeInterval(-60)
        let recentRequests = (requestTimestamps[model] ?? [])
            .filter { $0 > windowStart }
        requestTimestamps[model] = recentRequests
        return recentRequests.count >= (rpmLimits[model] ?? 5)
    }

    private func recordRequest(_ model: GeminiModel) {
        requestTimestamps[model]?.append(Date())
    }

    // Pick best available model, fall back if rate limited
    private func availableModel(preferred: GeminiModel) -> GeminiModel {
        let fallbackChain: [GeminiModel: [GeminiModel]] = [
            .pro:       [.pro, /*.flash,*/ .flashLite],
//            .flash:     [.flash, .flashLite, .pro],
            .flashLite: [.flashLite, /*.flash,*/ .pro]
        ]
        for model in fallbackChain[preferred] ?? [preferred] {
            if !isRateLimited(model) {
                if model != preferred {
                    print("⚠️ \(preferred.rawValue) rate limited, falling back to \(model.rawValue)")
                }
                return model
            }
        }
        print("⚠️ All models rate limited, using Flash-Lite anyway")
        return .flashLite
    }

    // MARK: - Chat

    func chat(messages: [[String: Any]], tools: [[String: Any]] = [], preferredModel: GeminiModel = .flashLite) async throws -> [String: Any] {
        let model = availableModel(preferred: preferredModel)
        recordRequest(model)

        print("🧠 Using \(model.rawValue)")

        let url = URL(string: "\(base)/\(model.rawValue):generateContent?key=\(apiKey)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["contents": messages]
        if !tools.isEmpty {
            body["tools"] = [["function_declarations": tools]]
        }

        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.badServerResponse)
        }

        // Handle rate limit error from API — retry with next model
        if let error = json["error"] as? [String: Any],
           let code = error["code"] as? Int, code == 429 {
            print("🔴 429 from \(model.rawValue), retrying with Flash-Lite...")
            return try await chat(messages: messages, tools: tools, preferredModel: .flashLite)
        }

        return json
    }

    // MARK: - Parse

    enum GeminiResult {
        case text(String)
        case toolCall(String, [String: Any])
    }

    func parse(_ json: [String: Any]) -> GeminiResult {
        guard let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let part = parts.first else {
            return .text("No response")
        }

        if let fnCall = part["functionCall"] as? [String: Any],
           let name = fnCall["name"] as? String,
           let args = fnCall["args"] as? [String: Any] {
            return .toolCall(name, args)
        }

        return .text(part["text"] as? String ?? "No response")
    }
}
