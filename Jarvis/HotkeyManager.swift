//
//  HotkeyManager.swift
//  Jarvis
//
//  Created by Jaanu Megalathan on 2026-05-20.
//


import Carbon
import AppKit

class HotkeyManager: ObservableObject {
    init() { register() }

    private func register() {
        let id = EventHotKeyID(signature: 0x4A415256, id: 1) // "JARV"
        var ref: EventHotKeyRef?

        RegisterEventHotKey(
            UInt32(kVK_ANSI_J),
            UInt32(cmdKey | shiftKey),
            id,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        // Install handler
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            // Post notification — ContentView observes this
            NotificationCenter.default.post(name: .jarvisHotkey, object: nil)
            return noErr
        }, 1, &spec, nil, nil)
    }
}

extension Notification.Name {
    static let jarvisHotkey = Notification.Name("jarvisHotkey")
}