//
//  SpeechRecognizer.swift
//  Jarvis
//

import Speech
import AVFoundation

class SpeechRecognizer: ObservableObject {
    @Published var isListening = false

    // Wake word still uses SFSpeechRecognizer (works fine for "Jarvis")
    private let recognizer  = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioEngine = AVAudioEngine()
    private var wakeRequest: SFSpeechAudioBufferRecognitionRequest?
    private var wakeTask:    SFSpeechRecognitionTask?
    private var isDetectingWakeWord = false

    // Command recording — AVAudioRecorder → Whisper
    private var audioRecorder:  AVAudioRecorder?
    private var recordingURL:   URL?
    private var silenceTimer:   Timer?
    private var lastAudioLevel: Float = -160
    private var silenceCount    = 0
    private var levelTimer:     Timer?

    private let whisper = WhisperService()

    var onResult:   ((String) -> Void)?
    var onWakeWord: (() -> Void)?

    init() { requestPermissions() }

    // MARK: - Permissions

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else { print("❌ Speech not authorized"); return }
            DispatchQueue.main.async { self?.startWakeWordDetection() }
        }
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            print(granted ? "🎙 Mic granted" : "❌ Mic denied")
        }
    }

    // MARK: - Wake Word (SFSpeechRecognizer is fine for English "Jarvis")

    func startWakeWordDetection() {
        guard !isListening, !isDetectingWakeWord else { return }
        guard recognizer?.isAvailable == true else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.startWakeWordDetection()
            }
            return
        }

        isDetectingWakeWord = true
        teardownAudio()

        wakeRequest = SFSpeechAudioBufferRecognitionRequest()
        wakeRequest?.shouldReportPartialResults = true

        let node   = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.wakeRequest?.append(buf)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("❌ Wake engine failed: \(error)")
            isDetectingWakeWord = false
            scheduleWakeWordRestart()
            return
        }

        print("👂 Waiting for 'Jarvis'...")

        wakeTask = recognizer?.recognitionTask(with: wakeRequest!) { [weak self] result, error in
            guard let self else { return }

            if let text = result?.bestTranscription.formattedString.lowercased(),
               text.contains("jarvis") {
                print("🟢 Wake word detected!")
                DispatchQueue.main.async {
                    self.isDetectingWakeWord = false
                    self.stopWakeWordDetection()
                    self.onWakeWord?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        self.startListening()
                    }
                }
                return
            }

            if result?.isFinal == true || error != nil {
                if let error { print("⚠️ Wake ended: \(error.localizedDescription)") }
                DispatchQueue.main.async {
                    self.isDetectingWakeWord = false
                    self.scheduleWakeWordRestart()
                }
            }
        }
    }

    private func scheduleWakeWordRestart() {
        guard !isListening else { return }
        print("🔄 Restarting wake word...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startWakeWordDetection()
        }
    }

    func stopWakeWordDetectionPublic() { stopWakeWordDetection() }

    private func stopWakeWordDetection() {
        wakeTask?.cancel()
        wakeTask = nil
        wakeRequest?.endAudio()
        wakeRequest = nil
        teardownAudio()
        isDetectingWakeWord = false
    }

    // MARK: - Command Recording → Whisper

    func startListening() {
        guard !isListening else { return }
        teardownAudio()

        // Save to temp file
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("jarvis_cmd_\(Date().timeIntervalSince1970).m4a")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey:         Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey:       16000,   // Whisper prefers 16kHz
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isListening = true
            print("🎙 Recording for Whisper...")
        } catch {
            print("❌ Recorder failed: \(error)")
            startWakeWordDetection()
            return
        }

        // Silence detection via audio levels
        silenceCount = 0
        startSilenceDetection()

        // Hard timeout — 10s max recording
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self, self.isListening else { return }
            print("⏱ Max recording time reached")
            self.stopListeningAndTranscribe()
        }
    }

    private var hasSpeechStarted = false  // ← add to class properties

    private func startSilenceDetection() {
        hasSpeechStarted = false
        silenceCount = 0

        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            let level = recorder.averagePower(forChannel: 0)

            if level > -35 {
                // Speech detected
                if !self.hasSpeechStarted {
                    print("🗣 Speech started (level: \(level) dB)")
                    self.hasSpeechStarted = true
                }
                self.silenceCount = 0
            } else if self.hasSpeechStarted {
                // Only count silence AFTER speech has started
                self.silenceCount += 1
                if self.silenceCount >= 15 {
                    print("⏱ Silence after speech, finalizing...")
                    DispatchQueue.main.async { self.stopListeningAndTranscribe() }
                }
            }
            // If hasSpeechStarted is false, ignore silence entirely
        }
    }

    private func stopListeningAndTranscribe() {
        guard isListening else { return }
        levelTimer?.invalidate()
        levelTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        isListening = false
        print("⏹ Stopped recording, sending to Whisper...")

        guard let url = recordingURL else { return }

        Task {
            if let text = await whisper.transcribe(audioURL: url) {
                print("✅ Whisper: \(text)")
                DispatchQueue.main.async { self.onResult?(text) }
            } else {
                print("❌ Whisper failed")
                DispatchQueue.main.async { self.startWakeWordDetection() }
            }
            // Clean up temp file
            try? FileManager.default.removeItem(at: url)
        }
    }

    func stopListening() {
        levelTimer?.invalidate()
        levelTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        isListening = false
        print("⏹ Stopped listening")
    }

    // MARK: - Teardown

    private func teardownAudio() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.reset()
    }
}
