//
//  MemoryManager.swift
//  Jarvis
//
//  Created by Jaanu Megalathan on 2026-05-23.
//


//
//  MemoryManager.swift
//  Jarvis
//

import Foundation

class MemoryManager: ObservableObject {
    static let shared = MemoryManager()

    @Published var store = JarvisMemoryStore()

    private let localKey  = "jarvis_memory"
    private let icloudKey = "jarvis_memory_icloud"
    private let maxConversations = 200

    init() {
        load()
        setupICloudSync()
    }

    // MARK: - Load / Save

    func load() {
        // Try iCloud first, fall back to local
        if let icloudData = NSUbiquitousKeyValueStore.default.data(forKey: icloudKey),
           let decoded = try? JSONDecoder().decode(JarvisMemoryStore.self, from: icloudData) {
            store = decoded
            print("☁️ Memory loaded from iCloud")
        } else if let localData = UserDefaults.standard.data(forKey: localKey),
                  let decoded = try? JSONDecoder().decode(JarvisMemoryStore.self, from: localData) {
            store = decoded
            print("💾 Memory loaded from local storage")
        } else {
            print("🆕 Fresh memory store created")
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(store) else { return }
        // Save both locally and iCloud
        UserDefaults.standard.set(data, forKey: localKey)
        NSUbiquitousKeyValueStore.default.set(data, forKey: icloudKey)
        NSUbiquitousKeyValueStore.default.synchronize()
        store.lastUpdated = Date()
    }

    private func setupICloudSync() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    @objc private func iCloudDidChange(_ notification: Notification) {
        print("☁️ iCloud memory updated externally")
        load()
    }

    // MARK: - Conversations

    func addConversation(user: String, jarvis: String, agent: String) {
        let entry = Conversation(
            id: UUID(),
            date: Date(),
            userMessage: user,
            jarvisResponse: jarvis,
            agent: agent
        )
        store.conversations.append(entry)
        // Keep last 200 only
        if store.conversations.count > maxConversations {
            store.conversations.removeFirst(store.conversations.count - maxConversations)
        }
        save()
    }

    // MARK: - Preferences

    func setPreference(key: String, value: String) {
        switch key {
        case "name":     store.preferences.name = value
        case "location": store.preferences.location = value
        case "wake":     store.preferences.wakeTime = value
        case "sleep":    store.preferences.sleepTime = value
        default:         store.preferences.customFacts[key] = value
        }
        save()
    }

    func getPreference(key: String) -> String? {
        switch key {
        case "name":     return store.preferences.name.isEmpty ? nil : store.preferences.name
        case "location": return store.preferences.location.isEmpty ? nil : store.preferences.location
        case "wake":     return store.preferences.wakeTime.isEmpty ? nil : store.preferences.wakeTime
        case "sleep":    return store.preferences.sleepTime.isEmpty ? nil : store.preferences.sleepTime
        default:         return store.preferences.customFacts[key]
        }
    }

    // MARK: - Routine Tracking

    func trackRoutine(action: String) {
        let hour = Calendar.current.component(.hour, from: Date())
        if let idx = store.routine.firstIndex(where: { $0.hour == hour && $0.action == action }) {
            store.routine[idx].count += 1
        } else {
            store.routine.append(DailyRoutineEntry(hour: hour, action: action, count: 1))
        }
        save()
    }

    func getRoutineSuggestion() -> String? {
        let hour = Calendar.current.component(.hour, from: Date())
        // Find most common action at this hour
        let hourEntries = store.routine
            .filter { abs($0.hour - hour) <= 1 }
            .sorted { $0.count > $1.count }
        guard let top = hourEntries.first, top.count >= 3 else { return nil }
        return "You usually \(top.action) around this time. Want me to do that?"
    }

    // MARK: - Learning

    func startLearning(topic: String, totalLessons: Int = 10) -> LearningTopic {
        if let existing = store.learningTopics[topic.lowercased()] {
            return existing
        }
        let newTopic = LearningTopic(
            topic: topic,
            level: 1,
            lessonsCompleted: 0,
            totalLessons: totalLessons,
            lastStudied: Date(),
            notes: [],
            nextLesson: "Introduction to \(topic)"
        )
        store.learningTopics[topic.lowercased()] = newTopic
        save()
        return newTopic
    }

    func updateLearning(topic: String, lessonNote: String, nextLesson: String) {
        guard var t = store.learningTopics[topic.lowercased()] else { return }
        t.lessonsCompleted += 1
        t.notes.append(lessonNote)
        t.nextLesson = nextLesson
        t.lastStudied = Date()
        // Level up every 3 lessons
        t.level = min(3, 1 + t.lessonsCompleted / 3)
        store.learningTopics[topic.lowercased()] = t
        save()
    }

    func getLearningProgress(topic: String) -> String {
        guard let t = store.learningTopics[topic.lowercased()] else {
            return "You haven't started learning \(topic) yet."
        }
        let levelName = ["", "Beginner", "Intermediate", "Advanced"][t.level]
        let pct = Int((Double(t.lessonsCompleted) / Double(t.totalLessons)) * 100)
        return "\(topic): \(pct)% complete, Level: \(levelName), Next: \(t.nextLesson)"
    }

    // MARK: - Context Summary for AI

    func contextSummary() -> String {
        var parts: [String] = []

        if !store.preferences.name.isEmpty {
            parts.append("User's name is \(store.preferences.name).")
        }
        if !store.preferences.location.isEmpty {
            parts.append("User is in \(store.preferences.location).")
        }
        if !store.preferences.wakeTime.isEmpty {
            parts.append("User usually wakes at \(store.preferences.wakeTime).")
        }
        for (key, value) in store.preferences.customFacts {
            parts.append("User's \(key) is \(value).")
        }

        // Recent conversations summary
        let recent = store.conversations.suffix(5)
        if !recent.isEmpty {
            parts.append("Recent topics: \(recent.map { $0.userMessage }.joined(separator: ", ")).")
        }

        // Active learning topics
        let activeTopics = store.learningTopics.values.filter {
            $0.lessonsCompleted < $0.totalLessons
        }
        if !activeTopics.isEmpty {
            parts.append("Currently learning: \(activeTopics.map { $0.topic }.joined(separator: ", ")).")
        }

        return parts.joined(separator: " ")
    }
}