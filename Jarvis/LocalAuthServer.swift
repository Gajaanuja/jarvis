//
//  LocalAuthServer.swift
//  Jarvis
//

import Foundation
import Network

class LocalAuthServer {
    private let port: UInt16
    private var listener: NWListener?

    init(port: UInt16) { self.port = port }

    func waitForCode(timeout: TimeInterval) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var authCode: String?

        let params = NWParameters.tcp
        listener = try? NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .global())
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                if let data = data,
                   let request = String(data: data, encoding: .utf8),
                   let range = request.range(of: "code=") {
                    let sub = String(request[range.upperBound...])
                    let code = sub.components(separatedBy: CharacterSet(charactersIn: "& ")).first ?? ""
                    if !code.isEmpty {
                        authCode = code

                        // Send success response to browser
                        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<html><body><h2>✅ Jarvis: Gmail authorized! You can close this tab.</h2></body></html>"
                        connection.send(content: response.data(using: .utf8),
                                        completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                        semaphore.signal()
                    }
                }
            }
        }

        listener?.start(queue: .global())
        print("🌐 Waiting for Gmail auth callback on port \(port)...")

        _ = semaphore.wait(timeout: .now() + timeout)
        listener?.cancel()
        listener = nil
        return authCode
    }
}
