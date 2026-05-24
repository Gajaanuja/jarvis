//
//  UserPreference.swift
//  Jarvis
//
//  Created by Jaanu Megalathan on 2026-05-23.
//


//
//  JarvisMemory.swift
//  Jarvis
//

import Foundation

// MARK: - Memory Models

struct UserPreference: Codable {
    var name: String = ""
    var wakeTime: String = ""
    var sleepTime: String = ""
    var favoriteMusic: [String] = []
    var favoriteApps: [String] = []
    var location: String = ""
    var language: String = "en"
    var customFacts: [String: String] = [:]  // "boss name": "John"
}

struct Conversation: Codable {
    let id: UUID
    let date: Date
    let userMessage: String
    let jarvisResponse: String
    let agent: String  // gemini/claude/chatgpt
}

struct DailyRoutineEntry: Codable {
    let hour: Int
    let action: String
    var count: Int  // how many times this was done at this hour
}

struct LearningTopic: Codable {
    let topic: String
    var level: Int          // 1=beginner, 2=intermediate, 3=advanced
    var lessonsCompleted: Int
    var totalLessons: Int
    var lastStudied: Date
    var notes: [String]     // key points Jarvis taught
    var nextLesson: String  // what to cover next
}

struct JarvisMemoryStore: Codable {
    var preferences: UserPreference = UserPreference()
    var conversations: [Conversation] = []
    var routine: [DailyRoutineEntry] = []
    var learningTopics: [String: LearningTopic] = [:]
    var lastUpdated: Date = Date()
}