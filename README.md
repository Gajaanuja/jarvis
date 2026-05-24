# J.A.R.V.I.S
> Just A Rather Very Intelligent System — A Siri-like AI assistant for macOS

---

## Overview

Jarvis is a always-on macOS menu bar AI assistant inspired by Iron Man's J.A.R.V.I.S. It listens for a wake word, understands natural language commands, and routes them to the best AI model automatically.

![Jarvis Screenshot](Assets/Screenshot 2026-05-24 at 13.50.52.png)
![Jarvis Screenshot](Assets/Screenshot 2026-05-24 at 13.52.44.png)
![Jarvis Screenshot](Assets/Screenshot 2026-05-24 at 13.55.25.png)
---

## Features

### 🎙 Voice
- Always listening for **"Jarvis"** wake word
- **Gemini audio transcription** for accurate Tamil, Hindi, and English speech recognition
- **CMD+SHIFT+J** global hotkey to activate manually
- Auto-submits after 1.5s of silence

### 🤖 Multi-Agent AI
| Agent | Used For |
|-------|----------|
| **Gemini 2.5** (Pro / Flash / Flash-Lite) | Tools, weather, facts, quick commands |
| **Claude** | Code, debugging, analysis, reasoning |
| **ChatGPT** | Writing, creative tasks, brainstorming |

Automatically routes to the best model based on your query. Falls back gracefully if rate limits are hit.

### 🛠 Tools Jarvis Can Use
- 🌤 **Weather** — real-time weather for any city
- ⏰ **Reminders** — create reminders via EventKit
- 🖥 **Open Apps** — launch any macOS application
- 🎵 **Play Music** — Spotify and Apple Music with Tamil/Hindi song support
- 📄 **Write Documents** — create and open files in WPS Office
- 📧 **Send Email** — via Gmail API or Apple Mail

### 🧠 Memory & Learning
- Remembers your **name, preferences, and custom facts**
- Learns from **past conversations**
- Tracks your **daily routine** and suggests actions
- **Progressive topic teaching** — say "Jarvis, teach me quantum physics" for lesson-by-lesson learning
- Syncs memory across devices via **iCloud**

### 🎨 UI
- Iron Man HUD-inspired popup with **particle sphere animation**
- Waveform visualizer while listening
- Active AI agent indicator (Gemini / Claude / ChatGPT)
- Lives in the **menu bar** — no Dock icon

---

## Requirements

- macOS 12.0+
- Xcode 15+
- Active API keys (see setup below)

---

## Setup

### 1. Clone the repo
```bash
git clone https://github.com/Gajaanuja/jarvis.git
cd jarvis
```

### 2. Configure API keys
```bash
cp Jarvis/Config.example.swift Jarvis/Config.swift
```

Open `Jarvis/Config.swift` and fill in your keys:

```swift
enum Config {
    static let geminiAPIKey       = ""   // aistudio.google.com
    static let openAIKey          = ""   // platform.openai.com
    static let anthropicKey       = ""   // console.anthropic.com
    static let spotifyClientID    = ""   // developer.spotify.com
    static let spotifySecret      = ""
    static let googleClientID     = ""   // console.cloud.google.com
    static let googleClientSecret = ""
}
```

### 3. Info.plist permissions
Add these keys to your `Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Jarvis needs microphone access to listen for commands</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Jarvis needs speech recognition to detect the wake word</string>
<key>NSRemindersUsageDescription</key>
<string>Jarvis needs reminders access to create reminders for you</string>
```

### 4. Entitlements
Enable in Xcode → Signing & Capabilities:
- ✅ Audio Input
- ✅ Outgoing Connections (Client)
- ✅ Incoming Connections (Server)
- ✅ iCloud → Key-value storage
- ✅ Apple Events

### 5. Disable App Sandbox
Xcode → Signing & Capabilities → remove **App Sandbox** (required for file system access)

### 6. Build & Run
Open `Jarvis.xcodeproj` in Xcode and hit **CMD+R**

---

## Usage

| Action | How |
|--------|-----|
| Activate | Say **"Jarvis"** or press **CMD+SHIFT+J** |
| Ask anything | *"Jarvis, what's the weather in Jaffna"* |
| Play music | *"Jarvis, play Thangame from Naanum Rowdy Dhaan on Spotify"* |
| Set reminder | *"Jarvis, remind me to call John at 5pm"* |
| Open app | *"Jarvis, open Safari"* |
| Send email | *"Jarvis, send an email to john@gmail.com saying I'll be late"* |
| Write document | *"Jarvis, write a resignation letter and save it"* |
| Learn something | *"Jarvis, teach me quantum science"* |
| Remember a fact | *"Jarvis, my boss's name is Rajan"* |
| Recall a fact | *"Jarvis, what's my boss's name"* |

---

## Project Structure

```
Jarvis/
├── JarvisApp.swift          # App entry + MenuBarExtra + AppDelegate
├── ContentView.swift        # HUD UI with particle sphere
├── JarvisAgent.swift        # AI routing + tool execution + conversation
├── GeminiService.swift      # Gemini API with model rotation
├── OpenAIService.swift      # ChatGPT API
├── AnthropicService.swift   # Claude API
├── AIRouter.swift           # Routes queries to best AI agent
├── SpeechRecognizer.swift   # Wake word detection + command recording
├── WhisperService.swift     # Gemini audio transcription
├── HotkeyManager.swift      # CMD+SHIFT+J global hotkey
├── GmailService.swift       # Gmail OAuth + send
├── LocalAuthServer.swift    # Local OAuth callback server
├── MemoryManager.swift      # iCloud + local memory store
├── JarvisMemory.swift       # Memory data models
└── Config.swift             # API keys (gitignored — never commit)
    Config.example.swift     # Key template (safe to commit)
```

---

## API Keys Needed

| Service | Free Tier | Get Key |
|---------|-----------|---------|
| Gemini | ✅ Yes | [aistudio.google.com](https://aistudio.google.com) |
| OpenAI | ❌ Paid | [platform.openai.com](https://platform.openai.com) |
| Anthropic | ❌ Paid | [console.anthropic.com](https://console.anthropic.com) |
| Spotify | ✅ Yes | [developer.spotify.com](https://developer.spotify.com) |
| Gmail | ✅ Yes | [console.cloud.google.com](https://console.cloud.google.com) |

> Jarvis works with just the **Gemini key** — all other agents and tools are optional.

---

## Privacy

- All memory stored **locally** on your Mac and optionally synced via iCloud
- No data sent to any server except the AI APIs you configure
- API keys stored only in `Config.swift` which is gitignored
- Wake word detection runs fully **on-device** via Apple's SFSpeechRecognizer

---

## Built With

- [SwiftUI](https://developer.apple.com/xcode/swiftui/) — UI
- [SFSpeechRecognizer](https://developer.apple.com/documentation/speech) — Wake word detection
- [AVFoundation](https://developer.apple.com/av-foundation/) — Audio recording
- [Gemini API](https://aistudio.google.com) — AI + transcription
- [Spotify Web API](https://developer.spotify.com/documentation/web-api) — Music search
- [Gmail API](https://developers.google.com/gmail/api) — Email
- [EventKit](https://developer.apple.com/documentation/eventkit) — Reminders
- [NSUbiquitousKeyValueStore](https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestore) — iCloud sync

---

## License

MIT — feel free to use, modify, and distribute.

---

*Made with ❤️ by [Jaanu Megalathan](https://github.com/Gajaanuja)*
