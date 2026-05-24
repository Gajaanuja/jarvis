//
//  JarvisApp.swift
//  Jarvis
//

import SwiftUI
import AppKit

@main
struct JarvisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    let agent  = JarvisAgent()
    let speech = SpeechRecognizer()
    let hotkey = HotkeyManager()  // register() called automatically in its init

    func applicationDidFinishLaunching(_ notification: Notification) {
        agent.speechRecognizer = speech

        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "brain.head.profile",
                                   accessibilityDescription: "Jarvis")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environmentObject(agent)
                .environmentObject(speech)
        )

        // Wake word → open popover automatically
        speech.onWakeWord = { [weak self] in
            DispatchQueue.main.async { self?.showPopover() }
        }

        // CMD+SHIFT+J → toggle popover via NotificationCenter
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyPressed),
            name: .jarvisHotkey,
            object: nil
        )
    }

    @objc func hotkeyPressed() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
            speech.startListening()
        }
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
            speech.startListening()
        }
    }

    func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }
}
