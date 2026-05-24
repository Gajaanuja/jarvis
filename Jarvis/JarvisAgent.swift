//
//  JarvisAgent.swift
//  Jarvis
//
//  Created by Jaanu Megalathan on 2026-05-20.
//


import Foundation
import EventKit
import AVFoundation
import AppKit

@MainActor
class JarvisAgent: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var transcript  = ""
    @Published var response    = ""
    @Published var isThinking  = false
    @Published var showWindow  = false
    @Published var activeAgent: AIAgent = .gemini  // shown in UI

    private let gemini    = GeminiService(apiKey: Config.geminiAPIKey)
//    private let openai    = OpenAIService(apiKey: "YOUR_OPENAI_KEY")
//    private let anthropic = AnthropicService(apiKey: "YOUR_ANTHROPIC_KEY")

    private let eventStore = EKEventStore()
    private let tts        = AVSpeechSynthesizer()
    weak var speechRecognizer: SpeechRecognizer?

    private var geminiHistory: [[String: Any]] = [
        ["role": "user",  "parts": [["text": "You are Jarvis, a concise AI assistant."]]],
        ["role": "model", "parts": [["text": "Ready."]]]
    ]
    private var openaiHistory:   [[String: String]] = []
    private var claudeHistory:   [[String: String]] = []

    private let tools: [[String: Any]] = [
        [
            "name": "set_reminder",
            "description": "Create a reminder",
            "parameters": [
                "type": "object",
                "properties": [
                    "title":    ["type": "string"],
                    "datetime": ["type": "string", "description": "ISO 8601"]
                ],
                "required": ["title", "datetime"]
            ]
        ],
        [
            "name": "get_weather",
            "description": "Get weather for a city",
            "parameters": [
                "type": "object",
                "properties": ["city": ["type": "string"]],
                "required": ["city"]
            ]
        ],
        [
            "name": "open_app",
            "description": "Open a macOS application",
            "parameters": [
                "type": "object",
                "properties": ["appName": ["type": "string"]],
                "required": ["appName"]
            ]
        ],
        [
            "name": "play_music",
            "description": "Play a song, artist, or songs from a movie in Apple Music or Spotify. If the song, artist, or movie name sounds like Tamil, Malayalam, or any Indian language, preserve it exactly as heard.",
            "parameters": [
                "type": "object",
                "properties": [
                    "song":     ["type": "string", "description": "Song name exactly as spoken"],
                    "artist":   ["type": "string", "description": "Artist or singer name"],
                    "movie":    ["type": "string", "description": "Movie name to play songs from"],
                    "app":      ["type": "string", "description": "Music or Spotify, default Spotify"],
                    "language": ["type": "string", "description": "Language hint: tamil, hindi, english etc"]
                ],
                "required": []
            ]
        ],
        [
            "name": "write_document",
            "description": "Write and save a document in WPS Office",
            "parameters": [
                "type": "object",
                "properties": [
                    "content":  ["type": "string", "description": "The content to write in the document"],
                    "filename": ["type": "string", "description": "Name of the file to save, without extension"],
                    "format":   ["type": "string", "description": "File format: docx, txt, or pdf. Default docx"]
                ],
                "required": ["content"]
            ]
        ],
        [
            "name": "send_email",
            "description": "Send an email using Apple Mail or Gmail",
            "parameters": [
                "type": "object",
                "properties": [
                    "to":      ["type": "string", "description": "Recipient email address"],
                    "subject": ["type": "string", "description": "Email subject"],
                    "body":    ["type": "string", "description": "Email body content"],
                    "service": ["type": "string", "description": "gmail or mail, default gmail"]
                ],
                "required": ["to", "subject", "body"]
            ]
        ],
        [
            "name": "remember_fact",
            "description": "Remember a fact or preference about the user",
            "parameters": [
                "type": "object",
                "properties": [
                    "key":   ["type": "string", "description": "What to remember e.g. name, boss, location"],
                    "value": ["type": "string", "description": "The value to remember"]
                ],
                "required": ["key", "value"]
            ]
        ],
        [
            "name": "recall_fact",
            "description": "Recall a remembered fact about the user",
            "parameters": [
                "type": "object",
                "properties": [
                    "key": ["type": "string", "description": "What to recall"]
                ],
                "required": ["key"]
            ]
        ],
        [
            "name": "teach_topic",
            "description": "Teach the user about a topic progressively lesson by lesson",
            "parameters": [
                "type": "object",
                "properties": [
                    "topic":  ["type": "string", "description": "Topic to learn e.g. quantum science"],
                    "action": ["type": "string", "description": "start, continue, or progress"]
                ],
                "required": ["topic"]
            ]
        ]
    ]

    override init() {
        super.init()
        tts.delegate = self
    }

    // MARK: - Send

    func send(_ input: String) async {
        transcript = input
        isThinking = true
        // ← remove the fixTranscription call entirely
        memory.trackRoutine(action: input)
        let agent = AIRouter.route(input)
        
        activeAgent = agent
        let memoryContext = memory.contextSummary()

        do {
            let reply: String
            switch agent {
            case .gemini:  reply = try await sendToGemini(input)
//            case .chatgpt: reply = try await sendToOpenAI(cleaned, context: memoryContext)
//            case .claude:  reply = try await sendToClaude(cleaned, context: memoryContext)
            }
            response = reply
            memory.addConversation(user: input, jarvis: reply, agent: agent.rawValue)
            speak(reply)
        } catch {
            response = "Error: \(error.localizedDescription)"
        }
        isThinking = false
    }

    private func fixTranscription(_ text: String) async -> String {
        let lower = text.lowercased()
        guard lower.contains("play") || lower.contains("song") || lower.contains("music") else {
            return text
        }

        let prompt = """
            The following text was transcribed from voice recognition.
            Your job is ONLY to fix obvious phonetic spelling errors in song names, movie names, and artist names.

            STRICT RULES:
            - NEVER replace or guess a different song/movie/artist name
            - NEVER change a name to something you think sounds similar
            - ONLY fix clear phonetic mangling like "than game" → "Thangame" or "nah num row dee" → "Naanum Rowdy"
            - If you are not 100% sure what was said, return the original text UNCHANGED
            - Preserve the exact structure of the sentence
            - Do NOT add, remove, or swap any song/movie/artist names

            Return ONLY the corrected sentence. If unsure, return the original exactly.

            Text: "\(text)"
            """

        geminiHistory.append(["role": "user", "parts": [["text": prompt]]])
        guard let raw = try? await gemini.chat(messages: geminiHistory, tools: [], preferredModel: .flashLite),
              case .text(let fixed) = gemini.parse(raw) else {
            geminiHistory.removeLast()
            return text
        }
        geminiHistory.removeLast()

        let result = fixed.trimmingCharacters(in: .whitespacesAndNewlines)

        // Safety check — if Gemini changed too much, ignore it and use original
        let originalWords = text.lowercased().components(separatedBy: " ")
        let fixedWords    = result.lowercased().components(separatedBy: " ")
        let commonWords   = Set(originalWords).intersection(Set(fixedWords))

        // If less than 50% of words match, Gemini went rogue — use original
        let similarity = Double(commonWords.count) / Double(max(originalWords.count, fixedWords.count))
        if similarity < 0.5 {
            print("⚠️ Gemini changed too much (\(Int(similarity*100))% match), using original: \(text)")
            return text
        }

        print("🔤 Cleaned: \(result)")
        return result
    }
    // MARK: - Gemini (with tools)

    private func sendToGemini(_ input: String) async throws -> String {
        geminiHistory.append(["role": "user", "parts": [["text": input]]])

        // Pick model based on query complexity
        let preferredModel = GeminiService.selectModel(for: input)

        let raw    = try await gemini.chat(messages: geminiHistory, tools: tools, preferredModel: preferredModel)
        let result = gemini.parse(raw)

        switch result {
        case .text(let text):
            geminiHistory.append(["role": "model", "parts": [["text": text]]])
            return text

        case .toolCall(let name, let args):
            let toolResult = await executeTool(name: name, args: args)
            geminiHistory.append(["role": "model",    "parts": [["text": "Calling \(name)"]]])
            geminiHistory.append(["role": "function", "parts": [["functionResponse": ["name": name, "response": ["result": toolResult]]]]])

            let raw2 = try await gemini.chat(messages: geminiHistory, tools: tools)
            if case .text(let final) = gemini.parse(raw2) {
                geminiHistory.append(["role": "model", "parts": [["text": final]]])
                return final
            }
            return toolResult
        }
    }

    // MARK: - OpenAI

//    private func sendToOpenAI(_ input: String, context: String = "") async throws -> String {
//        openaiHistory.append(["role": "user", "content": input])
//        if openaiHistory.count > 20 { openaiHistory.removeFirst() }
//
//        var messages: [[String: String]] = [[
//            "role": "system",
//            "content": "You are Jarvis, a concise personal AI assistant. \(context)"
//        ]]
//        messages.append(contentsOf: openaiHistory)
//
//        let reply = try await openai.chat(messages: messages as [[String: Any]])
//        openaiHistory.append(["role": "assistant", "content": reply])
//        return reply
//    }
//
//    private func sendToClaude(_ input: String, context: String = "") async throws -> String {
//        claudeHistory.append(["role": "user", "content": input])
//        if claudeHistory.count > 20 { claudeHistory.removeFirst() }
//
//        let reply = try await anthropic.chat(
//            messages: claudeHistory,
//            system: "You are Jarvis, a concise personal AI assistant. \(context)"
//        )
//        claudeHistory.append(["role": "assistant", "content": reply])
//        return reply
//    }

    // MARK: - Tool Execution

    private func executeTool(name: String, args: [String: Any]) async -> String {
        switch name {
        case "set_reminder": return await createReminder(
            title:    args["title"]    as? String ?? "",
            datetime: args["datetime"] as? String ?? ""
        )
        case "get_weather":  return await fetchWeather(city: args["city"] as? String ?? "")
        case "open_app":     return openApp(name: args["appName"] as? String ?? "")
        case "play_music": return await playMusic(
            song:     args["song"]     as? String ?? "",
            artist:   args["artist"]   as? String ?? "",
            movie:   args["movie"]   as? String ?? "",
            app:      args["app"]      as? String ?? "Spotify",
            language: args["language"] as? String ?? ""
        )
        case "write_document": return await writeDocument(
            content:  args["content"]  as? String ?? "",
            filename: args["filename"] as? String ?? "Jarvis Document",
            format:   args["format"]   as? String ?? "docx"
        )
        case "send_email": return await sendEmail(
            to:      args["to"]      as? String ?? "",
            subject: args["subject"] as? String ?? "",
            body:    args["body"]    as? String ?? "",
            service: args["service"] as? String ?? "gmail"
        )
        case "remember_fact": return rememberFact(
            key:   args["key"]   as? String ?? "",
            value: args["value"] as? String ?? ""
        )
        case "recall_fact": return recallFact(key: args["key"] as? String ?? "")
        case "teach_topic": return await teachTopic(
            topic:  args["topic"]  as? String ?? "",
            action: args["action"] as? String ?? "continue"
        )
        default: return "Unknown tool"
        }
    }

    private func openApp(name: String) -> String {
        NSWorkspace.shared.launchApplication(name) ? "Opened \(name)" : "Could not open \(name)"
    }

    private func createReminder(title: String, datetime: String) async -> String {
        let granted = try? await eventStore.requestFullAccessToReminders()
        guard granted == true else { return "Permission denied" }
        let r = EKReminder(eventStore: eventStore)
        r.title = title
        r.calendar = eventStore.defaultCalendarForNewReminders()
        if let date = ISO8601DateFormatter().date(from: datetime) {
            r.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date
            )
        }
        try? eventStore.save(r, commit: true)
        return "Reminder set: \(title)"
    }

    private func fetchWeather(city: String) async -> String {
        let url = "https://wttr.in/\(city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city)?format=3"
        guard let data = try? await URLSession.shared.data(from: URL(string: url)!).0,
              let result = String(data: data, encoding: .utf8) else { return "Could not fetch weather" }
        return result
    }
    
    private func writeDocument(content: String, filename: String, format: String) async -> String {
        let ext = format == "txt" ? "txt" : format == "pdf" ? "pdf" : "docx"
        let fm  = FileManager.default

        // Without sandbox these paths are the real folders
        let desktopURL   = URL(fileURLWithPath: "/Users/\(NSUserName())/Desktop")
        let documentsURL = URL(fileURLWithPath: "/Users/\(NSUserName())/Documents")

        let saveDir = fm.isWritableFile(atPath: desktopURL.path) ? desktopURL : documentsURL
        let fileURL = saveDir.appendingPathComponent("\(filename).\(ext)")

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("📄 Saved to: \(fileURL.path)")

            NSWorkspace.shared.open(
                [fileURL],
                withAppBundleIdentifier: "com.kingsoft.office.mac",
                options: [],
                additionalEventParamDescriptor: nil,
                launchIdentifiers: nil
            )
            return "Saved to \(saveDir.lastPathComponent)/\(filename).\(ext) and opened in WPS"
        } catch {
            print("❌ Save failed: \(error)")
            return "Failed to write document: \(error.localizedDescription)"
        }
    }
    
    private let memory = MemoryManager.shared

    private func rememberFact(key: String, value: String) -> String {
        memory.setPreference(key: key, value: value)
        return "Got it, I'll remember your \(key) is \(value)"
    }

    private func recallFact(key: String) -> String {
        return memory.getPreference(key: key) ?? "I don't have that stored yet"
    }

    private func teachTopic(topic: String, action: String) async -> String {
        let t = memory.startLearning(topic: topic)
        let levelName = ["", "Beginner", "Intermediate", "Advanced"][t.level]

        let previousNotes = t.notes.suffix(3).joined(separator: ". ")
        let prompt = """
            You are teaching \(topic) to a student.
            Their current level: \(levelName).
            Lessons completed: \(t.lessonsCompleted) of \(t.totalLessons).
            Previously covered: \(previousNotes.isEmpty ? "Nothing yet" : previousNotes).
            Next lesson planned: \(t.nextLesson).

            Deliver the next lesson in 4-5 sentences max, conversational and clear.
            End with one line starting with NEXT: describing what the next lesson should cover.
            """

        // Use Gemini Pro for teaching — best reasoning on free tier
        geminiHistory.append(["role": "user", "parts": [["text": prompt]]])

        guard let raw = try? await gemini.chat(
            messages: geminiHistory,
            tools: [],
            preferredModel: .pro  // use Pro for better explanations
        ) else {
            return "I couldn't load the lesson right now"
        }

        guard case .text(let reply) = gemini.parse(raw) else {
            return "I couldn't parse the lesson"
        }

        geminiHistory.append(["role": "model", "parts": [["text": reply]]])

        // Extract NEXT: line
        let lines = reply.components(separatedBy: "\n")
        let nextLine = lines.first { $0.hasPrefix("NEXT:") }?
            .replacingOccurrences(of: "NEXT:", with: "")
            .trimmingCharacters(in: .whitespaces)
            ?? "Continue \(topic)"

        let lessonText = lines.filter { !$0.hasPrefix("NEXT:") }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        memory.updateLearning(topic: topic, lessonNote: lessonText, nextLesson: nextLine)

        return lessonText
    }
    
    private let gmail = GmailService()

    private func sendEmail(to: String, subject: String, body: String, service: String) async -> String {
        guard !to.isEmpty else { return "No recipient specified" }

        if service.lowercased() == "gmail" {
            return await gmail.sendEmail(to: to, subject: subject, body: body)
        }

        // Apple Mail fallback
        let safeTo      = to.replacingOccurrences(of: "\"", with: "\\\"")
        let safeSubject = subject.replacingOccurrences(of: "\"", with: "\\\"")
        let safeBody    = body.replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
            tell application "Mail"
                activate
                set newMsg to make new outgoing message with properties ¬
                    {subject:"\(safeSubject)", content:"\(safeBody)", visible:true}
                tell newMsg
                    make new to recipient with properties {address:"\(safeTo)"}
                end tell
                send newMsg
            end tell
            """

        let result = runAppleScript(script)
        return result == "OK" ? "Email sent to \(to) via Mail" : "Failed to send email"
    }
    
    private func playMusic(song: String, artist: String, movie: String, app: String, language: String = "") async -> String {
        let target = app.lowercased().contains("spotify") ? "Spotify" : "Music"
        let query  = [song, artist, movie].filter { !$0.isEmpty }.joined(separator: " ")

        if target == "Spotify" {
            return await playSpotify(
                query:    query,
                song:     song,
                movie:    movie,
                artist:   artist,
                language: language
            )
        } else {
            return await playAppleMusic(query: query)
        }
    }

    // Spotify — use URI scheme, no AppleScript needed
    private func playSpotify(query: String, song: String = "", movie: String = "", artist: String = "", language: String = "") async -> String {
        guard !query.isEmpty else {
            NSWorkspace.shared.open(URL(string: "spotify:")!)
            return "Opening Spotify"
        }

        // Append language to all strategies if provided
        let langHint    = language.lowercased().contains("tamil") ? " tamil"
                        : language.lowercased().contains("hindi") ? " hindi" : ""
        let songHinted  = song.isEmpty  ? song  : song  + langHint
        let movieHinted = movie.isEmpty ? movie : movie + langHint

        guard let token = await getSpotifyToken() else {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            NSWorkspace.shared.open(URL(string: "spotify:search:\(encoded)")!)
            return "Opened Spotify search for \(query)"
        }

        guard let trackURI = await searchSpotifyTrack(
            query:  query + langHint,
            token:  token,
            song:   songHinted,
            movie:  movieHinted,
            artist: artist
        ) else {
            // Final fallback — open search in Spotify app
            let encoded = (query + langHint).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            NSWorkspace.shared.open(URL(string: "spotify:search:\(encoded)")!)
            return "Opened Spotify search for \(query)"
        }

        NSWorkspace.shared.open(URL(string: trackURI)!)
        return "Playing \(song.isEmpty ? query : song) on Spotify"
    }

        // MARK: - Spotify Auth

    private let spotifyClientID     = Config.spotifyClientID
    private let spotifyClientSecret = Config.spotifySecret

        private func getSpotifyToken() async -> String? {
            let credentials = "\(spotifyClientID):\(spotifyClientSecret)"
            guard let data = credentials.data(using: .utf8) else { return nil }
            let base64 = data.base64EncodedString()

            var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
            req.httpMethod = "POST"
            req.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.httpBody = "grant_type=client_credentials".data(using: .utf8)

            guard let (data2, _) = try? await URLSession.shared.data(for: req),
                  let json = try? JSONSerialization.jsonObject(with: data2) as? [String: Any],
                  let token = json["access_token"] as? String else {
                print("❌ Spotify token failed")
                return nil
            }
            return token
        }

        // MARK: - Spotify Search

    private func searchSpotifyTrack(query: String, token: String, song: String = "", movie: String = "", artist: String = "") async -> String? {

        // Strategy 1: song name + movie name (most specific)
        if !song.isEmpty && !movie.isEmpty {
            let q = "\(song) \(movie)"
            print("🔍 Strategy 1: \(q)")
            if let uri = await spotifySearch(query: q, token: token) { return uri }
        }

        // Strategy 2: song name + artist
        if !song.isEmpty && !artist.isEmpty {
            let q = "\(song) \(artist)"
            print("🔍 Strategy 2: \(q)")
            if let uri = await spotifySearch(query: q, token: token) { return uri }
        }

        // Strategy 3: Spotify field filters — most accurate
        if !song.isEmpty && !movie.isEmpty {
            let q = "track:\(song) album:\(movie)"
            print("🔍 Strategy 3 (field filter): \(q)")
            if let uri = await spotifySearch(query: q, token: token) { return uri }
        }

        // Strategy 4: song name only
        if !song.isEmpty {
            print("🔍 Strategy 4 (song only): \(song)")
            if let uri = await spotifySearch(query: song, token: token) { return uri }
        }

        // Strategy 5: full original query as fallback
        print("🔍 Strategy 5 (full query): \(query)")
        return await spotifySearch(query: query, token: token)
    }

    private func spotifySearch(query: String, token: String) async -> String? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlStr  = "https://api.spotify.com/v1/search?q=\(encoded)&type=track&limit=1"

        var req = URLRequest(url: URL(string: urlStr)!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tracks = json["tracks"] as? [String: Any],
              let items  = tracks["items"] as? [[String: Any]],
              let first  = items.first,
              let uri    = first["uri"] as? String else { return nil }

        let name   = first["name"]    as? String ?? query
        let artist = (first["artists"] as? [[String: Any]])?.first?["name"] as? String ?? ""
        print("🎵 Found: \(name) by \(artist)")
        return uri
    }

    // Apple Music — AppleScript still works fine here
    private func playAppleMusic(query: String) async -> String {
        if !isAppRunning("Music") {
            NSWorkspace.shared.launchApplication("Music")
            await waitForApp("Music", timeout: 8)
        }

        let script = query.isEmpty ? """
            tell application "Music" to play
            """ : """
            tell application "Music"
                activate
                set results to search playlist "Library" for "\(query)"
                if results is not {} then
                    play first item of results
                else
                    play
                end if
            end tell
            """

        runAppleScript(script)
        return query.isEmpty ? "Resuming Apple Music" : "Playing \(query) in Music"
    }

    private func isAppRunning(_ appName: String) -> Bool {
        NSWorkspace.shared.runningApplications
            .contains { $0.localizedName == appName }
    }

    private func waitForApp(_ appName: String, timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isAppRunning(appName) {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                return
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
    
    @discardableResult
    private func runAppleScript(_ source: String) -> String {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { print("AppleScript error: \(error)") }
        return error == nil ? "OK" : "AppleScript failed"
    }

    // MARK: - TTS

    func speak(_ text: String) {
        speechRecognizer?.stopWakeWordDetectionPublic()
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate  = 0.52
        tts.speak(u)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            print("🔁 TTS done, resuming wake word detection...")
            self?.speechRecognizer?.startWakeWordDetection()
        }
    }
}
