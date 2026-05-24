//
//  ContentView.swift
//  Jarvis
//

//
//  ContentView.swift
//  Jarvis
//

import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var agent: JarvisAgent
    @EnvironmentObject var speech: SpeechRecognizer

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.05, blue: 0.08).ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                sphereView
                statusText
                waveformView
                chatView
                footerView
            }
        }
        .frame(width: 320, height: 520)
        .onAppear {
            speech.onResult = { text in
                let cleaned = text
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(
                        of: #"(?i)^jarvis[,.]?\s*"#,
                        with: "",
                        options: .regularExpression
                    )
                guard !cleaned.isEmpty else { return }
                Task { await agent.send(cleaned) }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("J.A.R.V.I.S")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Color(red: 0, green: 0.78, blue: 1))
                .tracking(3)

            Spacer()

            // Agent indicator
            HStack(spacing: 5) {
                Circle()
                    .fill(agentColor(agent.activeAgent))
                    .frame(width: 5, height: 5)
                Text(agent.activeAgent.rawValue.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(agentColor(agent.activeAgent).opacity(0.8))
                    .tracking(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(agentColor(agent.activeAgent).opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(agentColor(agent.activeAgent).opacity(0.2), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(red: 0, green: 0.7, blue: 1).opacity(0.12)),
            alignment: .bottom
        )
    }

    // MARK: - Particle Sphere

    private var sphereView: some View {
        ParticleSphereView(isListening: speech.isListening)
            .frame(width: 160, height: 160)
            .padding(.top, 8)
    }

    // MARK: - Status

    private var statusText: some View {
        Text(speech.isListening ? "LISTENING..." : agent.isThinking ? "PROCESSING..." : "READY")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(Color(red: 0, green: 0.78, blue: 1).opacity(0.5))
            .tracking(2)
            .padding(.vertical, 4)
    }

    // MARK: - Waveform

    private var waveformView: some View {
        WaveformView(isActive: speech.isListening)
            .frame(height: 36)
            .padding(.horizontal, 16)
    }

    // MARK: - Chat

    private var chatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if !agent.transcript.isEmpty {
                        chatBubble(text: agent.transcript, isUser: true)
                            .id("user")
                    }
                    if agent.isThinking {
                        thinkingBubble
                    } else if !agent.response.isEmpty {
                        chatBubble(text: agent.response, isUser: false)
                            .id("jarvis")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 100)
            .onChange(of: agent.response) { _ in
                withAnimation { proxy.scrollTo("jarvis") }
            }
        }
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(red: 0, green: 0.7, blue: 1).opacity(0.08)),
            alignment: .top
        )
    }

    private var thinkingBubble: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color(red: 0, green: 0.78, blue: 1).opacity(0.5))
                    .frame(width: 4, height: 4)
                    .scaleEffect(agent.isThinking ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15),
                        value: agent.isThinking
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func chatBubble(text: String, isUser: Bool) -> some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(
                    isUser
                    ? Color(red: 0.63, green: 0.91, blue: 1)
                    : Color.white.opacity(0.7)
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isUser
                    ? Color(red: 0, green: 0.7, blue: 1).opacity(0.15)
                    : Color.white.opacity(0.04)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isUser
                            ? Color(red: 0, green: 0.7, blue: 1).opacity(0.3)
                            : Color.white.opacity(0.08),
                            lineWidth: 0.5
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if !isUser { Spacer(minLength: 40) }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Text(speech.isListening ? "SPEAK NOW" : "CLICK OR ⌘⇧J")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(red: 0, green: 0.78, blue: 1).opacity(0.4))
                .tracking(1)

            Spacer()

            // Mic button
            Button {
                speech.isListening ? speech.stopListening() : speech.startListening()
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            speech.isListening
                            ? Color(red: 1, green: 0.27, blue: 0.4)
                            : Color(red: 0, green: 0.78, blue: 1).opacity(0.4),
                            lineWidth: 1.5
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .fill(
                                    speech.isListening
                                    ? Color(red: 1, green: 0.27, blue: 0.4).opacity(0.1)
                                    : Color(red: 0, green: 0.78, blue: 1).opacity(0.08)
                                )
                        )

                    Image(systemName: speech.isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 14))
                        .foregroundColor(
                            speech.isListening
                            ? Color(red: 1, green: 0.27, blue: 0.4)
                            : Color(red: 0, green: 0.78, blue: 1)
                        )
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button("QUIT") { NSApplication.shared.terminate(nil) }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.2))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(red: 0, green: 0.7, blue: 1).opacity(0.08)),
            alignment: .top
        )
    }

    // MARK: - Helpers

    private func agentColor(_ agent: AIAgent) -> Color {
        switch agent {
        case .gemini:  return Color(red: 0, green: 0.78, blue: 1)
//        case .claude:  return Color(red: 1, green: 0.62, blue: 0.25)
//        case .chatgpt: return Color(red: 0.06, green: 0.82, blue: 0.5)
        }
    }
}

// MARK: - Particle Sphere (Metal-free, pure SwiftUI Canvas)

struct ParticleSphereView: View {
    var isListening: Bool
    @State private var t: Double = 0
    private let particles: [(theta: Double, phi: Double, speed: Double, offset: Double, size: Double)] = {
        (0..<180).map { _ in (
            theta: Double.random(in: 0...(.pi*2)),
            phi:   acos(Double.random(in: -1...1)),
            speed: Double.random(in: 0.003...0.009),
            offset: Double.random(in: 0...(.pi*2)),
            size:  Double.random(in: 0.8...2.2)
        )}
    }()

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let cx = size.width/2, cy = size.height/2
                let R  = size.width * 0.36
                let tt = tl.date.timeIntervalSinceReferenceDate

                // orbit rings
                for s in [0.4, 0.7, 1.0] {
                    var path = Path()
                    for i in 0...60 {
                        let a = Double(i)/60 * .pi * 2
                        let x = cx + R*s * cos(a + tt*0.3)
                        let y = cy + R*s*0.3 * sin(a + tt*0.3)
                        i == 0 ? path.move(to: CGPoint(x:x,y:y)) : path.addLine(to: CGPoint(x:x,y:y))
                    }
                    ctx.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
                }

                // particles sorted by z
                let pts = particles.map { p -> (x:Double,y:Double,z:Double,alpha:Double,size:Double) in
                    let theta = p.theta + tt * p.speed * 30
                    let phi   = p.phi + sin(tt * p.speed * 20 + p.offset) * 0.3
                    let wave  = isListening ? sin(tt * 8 + p.offset) * 0.12 : 0
                    let r     = R * (1 + wave)
                    let x = cx + r * sin(phi) * cos(theta)
                    let y = cy + r * sin(phi) * sin(theta) * 0.55
                    let z = cos(phi)
                    let alpha = isListening
                        ? 0.3 + 0.7*((z+1)/2) + sin(tt*6+p.offset)*0.3
                        : 0.15 + 0.6*((z+1)/2)
                    let sz = p.size * (0.5 + 0.5*((z+1)/2))
                    return (x,y,z,min(1,alpha),sz)
                }.sorted { $0.z < $1.z }

                for p in pts {
                    let rect = CGRect(x: p.x-p.size/2, y: p.y-p.size/2, width: p.size, height: p.size)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .color(Color(red:0, green: isListening ? 0.9 : 0.75, blue:1).opacity(p.alpha)))
                }

                // core glow
                let coreR = isListening ? R*0.14 : R*0.08
                let core  = Path(ellipseIn: CGRect(x:cx-coreR, y:cy-coreR, width:coreR*2, height:coreR*2))
                ctx.fill(core, with: .color(Color(red:0,green:0.85,blue:1).opacity(isListening ? 0.6 : 0.3)))
            }
        }
    }
}

// MARK: - Waveform

struct WaveformView: View {
    var isActive: Bool
    @State private var t: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: isActive ? 0.06 : 0.3)) { tl in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<40, id: \.self) { i in
                    let tt = tl.date.timeIntervalSinceReferenceDate
                    let h  = isActive
                        ? 6 + abs(sin(tt*4 + Double(i)*0.4)) * 24
                        : 3 + Double(i % 3) * 1.5
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red:0,green:0.78,blue:1).opacity(isActive ? 0.8 : 0.15))
                        .frame(width: 3, height: h)
                        .animation(.easeInOut(duration: 0.1), value: h)
                }
            }
        }
    }
}
