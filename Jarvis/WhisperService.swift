//
//  WhisperService.swift
//  Jarvis
//
//  Created by Jaanu Megalathan on 2026-05-24.
//

//
//  WhisperService.swift
//  Jarvis
//

import Foundation

class WhisperService {
    private let apiKey = Config.geminiAPIKey

    func transcribe(audioURL: URL, language: String? = nil) async -> String? {
        guard let audioData = try? Data(contentsOf: audioURL) else {
            print("❌ Could not read audio file at \(audioURL)")
            return nil
        }

        print("📦 Audio file size: \(audioData.count) bytes")

        // Too small = just silence, skip
        guard audioData.count > 5000 else {
            print("❌ Audio too short, skipping")
            return nil
        }

        let base64Audio = audioData.base64EncodedString()

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    [
                        "inline_data": [
                            "mime_type": "audio/mp4",
                            "data": base64Audio
                        ]
                    ],
                    [
                        "text": "Transcribe this audio exactly as spoken. Preserve all song names, movie names, and artist names including Tamil and Hindi words exactly as heard. Return only the transcription, nothing else."
                    ]
                ]
            ]]
        ]

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            print("❌ Network request failed")
            return nil
        }

        // Print raw response for debugging
        let rawResponse = String(data: data, encoding: .utf8) ?? "unreadable"
        print("📡 Gemini raw response: \(rawResponse.prefix(500))")

        let http = response as? HTTPURLResponse
        print("📡 HTTP status: \(http?.statusCode ?? -1)")

        guard let json       = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content    = candidates.first?["content"] as? [String: Any],
              let parts      = content["parts"] as? [[String: Any]],
              let text       = parts.first?["text"] as? String else {
            print("❌ Gemini parse failed")
            return nil
        }

        print("🎤 Gemini transcribed: \(text)")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
