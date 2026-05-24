//
//  GmailService.swift
//  Jarvis
//
//  Created by Jaanu Megalathan on 2026-05-23.
//


//
//  GmailService.swift
//  Jarvis
//

import Foundation
import AppKit

class GmailService {
    private let clientID     = Config.googleClientID
    private let clientSecret = Config.googleClientSecret
    private let redirectURI  = "http://localhost:8080"
    private let tokenKey     = "jarvis_gmail_token"

    // MARK: - Send

    func sendEmail(to: String, subject: String, body: String) async -> String {
        // Get or refresh token
        guard let token = await getValidToken() else {
            return await fallbackToMailto(to: to, subject: subject, body: body)
        }

        // Build RFC 2822 email
        let rawEmail = """
            To: \(to)\r
            Subject: \(subject)\r
            Content-Type: text/plain; charset=utf-8\r
            \r
            \(body)
            """

        guard let emailData = rawEmail.data(using: .utf8) else {
            return "Failed to encode email"
        }

        let base64Email = emailData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        var request = URLRequest(url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["raw": base64Email])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else {
            return "Network error sending email"
        }

        if http.statusCode == 200 {
            print("✅ Gmail sent to \(to)")
            return "Email sent to \(to) via Gmail"
        } else {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            print("❌ Gmail error: \(json ?? [:])")
            return await fallbackToMailto(to: to, subject: subject, body: body)
        }
    }

    // MARK: - OAuth Token

    private func getValidToken() async -> String? {
        // Check saved token
        if let saved = UserDefaults.standard.string(forKey: tokenKey) {
            let parts = saved.split(separator: "|")
            if parts.count == 3,
               let expiry = Double(parts[1]),
               Date().timeIntervalSince1970 < expiry {
                return String(parts[0])
            }
            // Expired — try refresh
            if parts.count == 3 {
                return await refreshToken(String(parts[2]))
            }
        }
        // No token — do full OAuth flow
        return await authorizeUser()
    }

    private func refreshToken(_ refreshToken: String) async -> String? {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(clientID)&client_secret=\(clientSecret)"
            .data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json     = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token    = json["access_token"] as? String,
              let expires  = json["expires_in"]   as? Double else {
            print("❌ Gmail refresh failed, re-authorizing...")
            return await authorizeUser()
        }

        let expiry = Date().timeIntervalSince1970 + expires - 60
        UserDefaults.standard.set("\(token)|\(expiry)|\(refreshToken)", forKey: tokenKey)
        print("✅ Gmail token refreshed")
        return token
    }

    private func authorizeUser() async -> String? {
        let scope = "https://www.googleapis.com/auth/gmail.send"
        let authURL = "https://accounts.google.com/o/oauth2/v2/auth"
            + "?client_id=\(clientID)"
            + "&redirect_uri=\(redirectURI)"
            + "&response_type=code"
            + "&scope=\(scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
            + "&access_type=offline"
            + "&prompt=consent"

        // Open browser for login
        NSWorkspace.shared.open(URL(string: authURL)!)
        print("🌐 Opened Gmail auth in browser")

        // Start local server to catch redirect
        guard let code = await waitForAuthCode() else {
            print("❌ No auth code received")
            return nil
        }

        return await exchangeCode(code)
    }

    private func exchangeCode(_ code: String) async -> String? {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "code=\(code)&client_id=\(clientID)&client_secret=\(clientSecret)&redirect_uri=\(redirectURI)&grant_type=authorization_code"
            .data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json         = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token        = json["access_token"]  as? String,
              let expires      = json["expires_in"]    as? Double,
              let refreshToken = json["refresh_token"] as? String else {
            print("❌ Token exchange failed")
            return nil
        }

        let expiry = Date().timeIntervalSince1970 + expires - 60
        UserDefaults.standard.set("\(token)|\(expiry)|\(refreshToken)", forKey: tokenKey)
        print("✅ Gmail authorized!")
        return token
    }

    // MARK: - Local Auth Server

    private func waitForAuthCode() async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let server = LocalAuthServer(port: 8080)
                let code = server.waitForCode(timeout: 120)
                continuation.resume(returning: code)
            }
        }
    }

    // MARK: - Fallback

    private func fallbackToMailto(to: String, subject: String, body: String) async -> String {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody    = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        let mailto = "mailto:\(to)?subject=\(encodedSubject)&body=\(encodedBody)"
        if let url = URL(string: mailto) {
            NSWorkspace.shared.open(url)
        }
        return "Opened email draft to \(to)"
    }
}
