//
//  AIAgent.swift
//  Jarvis
//
//  Created by Jaanu Megalathan on 2026-05-20.
//


//
//  AIRouter.swift
//  Jarvis
//

import Foundation

enum AIAgent: String {
    case gemini  = "Gemini"
//    case claude  = "Claude"
//    case chatgpt = "ChatGPT"
}

struct AIRouter {

    // Route based on query intent
    static func route(_ input: String) -> AIAgent {
        let q = input.lowercased()

        // Claude: code, debugging, analysis, long reasoning
        let claudeKeywords = [
            "code", "debug", "fix", "error", "swift", "python", "javascript",
            "function", "class", "algorithm", "refactor", "review", "explain this",
            "analyze", "compare", "difference between", "how does", "architecture",
            "regex", "sql", "database", "api", "json", "xml"
        ]

        // ChatGPT: creative, writing, brainstorming, general knowledge
        let chatgptKeywords = [
            "write", "story", "poem", "essay", "email", "letter", "draft",
            "creative", "brainstorm", "ideas", "suggest", "recommend",
            "recipe", "plan", "itinerary", "blog", "caption", "tweet",
            "summarize", "translate", "joke", "fun"
        ]

        // Gemini: quick facts, tools, weather, math, real-time, casual
        // (also the fallback — it's free)
        let geminiKeywords = [
            "weather", "reminder", "open", "play", "calculate", "math",
            "convert", "what time", "news", "latest", "today", "tomorrow",
            "search", "find", "lookup", "define", "meaning","write", "story", "poem", "essay", "email", "letter", "draft", "creative", "brainstorm", "ideas", "suggest", "recommend",
            "recipe", "plan", "itinerary", "blog", "caption", "tweet",
            "summarize", "translate", "joke", "fun"
        ]

//        if claudeKeywords.contains(where: q.contains) { return .claude  }
//        if chatgptKeywords.contains(where: q.contains) { return .chatgpt }
        if geminiKeywords.contains(where: q.contains)  { return .gemini  }

        // Default: Gemini (free tier)
        return .gemini
    }
}
