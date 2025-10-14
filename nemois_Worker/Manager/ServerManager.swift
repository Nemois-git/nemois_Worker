
//
//  ServerManager.swift
//  nemois_Worker
//
//  Created by nemois on 10/14/25.
//

import Foundation
import Vapor
import Combine

/// Vapor 기반의 로컬 API 서버를 관리하는 핵심 클래스입니다.
final class ServerManager: ObservableObject {
    
    enum ServerState: Equatable {
        case stopped, starting, running, error(String)
    }
    
    @Published var serverState: ServerState = .stopped
    @Published var serverAddress: String = "Inactive"

    private var app: Application?
    private let modelManager: ModelManager
    private var serverTask: Task<Void, Never>?

    init(modelManager: ModelManager) {
        self.modelManager = modelManager
    }

    @MainActor
    func startServer() {
        guard !serverState.isStartingOrRunning else { return }

        LogStore.shared.add(log: "Server start sequence initiated.")
        self.serverState = .starting
        
        serverTask = Task.detached {
            do {
                var env = try Environment.detect()
                env.arguments = [CommandLine.arguments[0]]
                
                let app = try await Application.make(env)
                app.routes.defaultMaxBodySize = "500kb"
                
                defer { Task { try await app.asyncShutdown() } }

                try await self.configure(app: app)
                
                let ipAddress = self.getLocalIPAddress() ?? "localhost"
                let port = app.http.server.configuration.port
                let fullAddress = "http://\(ipAddress):\(port)"
                
                await MainActor.run {
                    self.app = app
                    self.serverAddress = fullAddress
                    self.serverState = .running
                    LogStore.shared.add(log: "Server is now running at \(fullAddress)")
                }
                
                // 서버를 프로그래밍 방식으로 시작하고, 종료될 때까지 현재 Task를 차단합니다.
                try await app.execute()
            } catch {
                let errorMessage = "Server start/run failed: \(error.localizedDescription)"
                await LogStore.shared.add(log: errorMessage)
                await MainActor.run {
                    self.serverState = .error(errorMessage)
                }
            }
            
            await MainActor.run {
                self.app = nil
                if self.serverState.isError == false {
                    self.serverState = .stopped
                    self.serverAddress = "Inactive"
                    LogStore.shared.add(log: "Server has stopped.")
                }
            }
        }
    }

    func stopServer() {
        guard let app = self.app, serverState.isStartingOrRunning else { return }
        LogStore.shared.add(log: "Server stop sequence initiated.")
        app.server.shutdown()
        if self.serverState.isError == false {
            self.serverState = .stopped
            self.serverAddress = "Inactive"
            LogStore.shared.add(log: "Server has stopped.")
        }
    }
    
    private func configure(app: Application) throws {
        let port = UserDefaults.standard.integer(forKey: "serverPort")
        app.http.server.configuration.port = (port > 1024) ? port : 8080
        app.http.server.configuration.hostname = "0.0.0.0"

        app.get("health") { _ in "Server is running." }

        app.get("v1", "models") { [weak self] req async throws -> ModelListResponse in
            guard let self = self else { throw Abort(.internalServerError) }
            var models: [ModelObject] = []
            if let modelInfo = self.modelManager.currentModelInfo {
                models.append(modelInfo)
            }
            return ModelListResponse(data: models)
        }

        app.post("v1", "chat", "completions") { [weak self] req async throws -> Response in
            guard let self = self else { throw Abort(.internalServerError) }
            guard self.modelManager.isModelLoaded else { throw Abort(.serviceUnavailable, reason: "AI model is not loaded.") }
            let chatRequest = try req.content.decode(OpenAIChatRequest.self)

            if chatRequest.stream == true {
                let body = Response.Body(stream: { writer in
                    Task {
                        do {
                            let modelStream = await self.modelManager.generateResponse(for: chatRequest.messages)
                            let responseId = "chatcmpl-\(UUID().uuidString)"
                            let created = Int(Date().timeIntervalSince1970)

                            var isFirstChunk = true

                            for try await chunk in modelStream {
                                guard !chunk.isEmpty else { continue }
                                
                                let delta: ChatStreamDelta
                                if isFirstChunk {
                                    delta = ChatStreamDelta(role: .assistant, content: chunk)
                                    isFirstChunk = false
                                } else {
                                    delta = ChatStreamDelta(content: chunk)
                                }

                                let choice = ChatStreamChoice(index: 0, delta: delta, finishReason: nil)
                                let streamChunk = OpenAIChatStreamChunk(id: responseId, created: created, model: chatRequest.model, choices: [choice])

                                do {
                                    let jsonData = try JSONEncoder().encode(streamChunk)
                                    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                                        await LogStore.shared.add(log: "Streaming Error: Failed to convert JSON data to string.")
                                        continue
                                    }
                                    let eventString = "data: \(jsonString)\n\n"
                                    _ = writer.write(.buffer(ByteBuffer(string: eventString)))
                                } catch {
                                    await LogStore.shared.add(log: "Streaming Error: Failed to encode stream chunk - \(error.localizedDescription)")
                                }
                            }
                            let finalDelta = ChatStreamDelta(content: nil) // 내용은 비어있습니다.
                            let finalChoice = ChatStreamChoice(index: 0, delta: finalDelta, finishReason: "stop")
                            let finalStreamChunk = OpenAIChatStreamChunk(id: responseId, created: created, model: chatRequest.model, choices: [finalChoice])

                            do {
                                let jsonData = try JSONEncoder().encode(finalStreamChunk)
                                if let jsonString = String(data: jsonData, encoding: .utf8) {
                                    let eventString = "data: \(jsonString)\n\n"
                                    _ = writer.write(.buffer(ByteBuffer(string: eventString)))
                                }
                            } catch {
                                await LogStore.shared.add(log: "Streaming Error: Failed to encode final stream chunk.")
                            }
                            
                            let finalEventString = "data: [DONE]\n\n"
                            _ = writer.write(.buffer(ByteBuffer(string: finalEventString)))
                            
                        } catch {
                            await LogStore.shared.add(log: "Streaming response error: \(error.localizedDescription)")
                        }
                        _ = writer.write(.end)
                    }
                })
                return Response(status: .ok, headers: ["Content-Type": "text/event-stream"], body: body)
            } else {
                var responseText = ""
                for try await chunk in self.modelManager.generateResponse(for: chatRequest.messages) { responseText += chunk }
                let responseMessage = OpenAIChatMessage(role: .assistant, content: responseText)
                let choice = OpenAIChatChoice(index: 0, message: responseMessage, finishReason: "stop")
                let promptTokens = chatRequest.messages.map { $0.content }.joined().count
                let completionTokens = responseText.count
                let usage = OpenAIUsage(promptTokens: promptTokens, completionTokens: completionTokens, totalTokens: promptTokens + completionTokens)
                let response = OpenAIChatResponse(id: "chatcmpl-\(UUID().uuidString)", object: "chat.completion", created: Int(Date().timeIntervalSince1970), model: chatRequest.model, choices: [choice], usage: usage)
                return try await response.encodeResponse(for: req)
            }
        }
        
        app.post("v1", "completions") { [weak self] req async throws -> OpenAICompletionResponse in
            guard let self = self else { throw Abort(.internalServerError) }
            guard self.modelManager.isModelLoaded else { throw Abort(.serviceUnavailable, reason: "AI model is not loaded.") }
            let reqContent = try req.content.decode(OpenAICompletionRequest.self)
            let messages = [OpenAIChatMessage(role: .user, content: reqContent.prompt)]
            var responseText = ""
            for try await chunk in self.modelManager.generateResponse(for: messages) { responseText += chunk }
            let choice = OpenAICompletionChoice(text: responseText, index: 0, finishReason: "stop")
            let promptTokens = reqContent.prompt.count
            let completionTokens = responseText.count
            let usage = OpenAIUsage(promptTokens: promptTokens, completionTokens: completionTokens, totalTokens: promptTokens + completionTokens)
            return OpenAICompletionResponse(id: "cmpl-\(UUID().uuidString)", object: "text_completion", created: Int(Date().timeIntervalSince1970), model: reqContent.model, choices: [choice], usage: usage)
        }

        app.post("v1", "embeddings") { [weak self] req async throws -> OpenAIEmbeddingResponse in
            guard let self = self else { throw Abort(.internalServerError) }
            let reqContent = try req.content.decode(OpenAIEmbeddingRequest.self)
            let vector = try await self.modelManager.generateEmbedding(for: reqContent.input)
            let embeddingData = OpenAIEmbeddingData(embedding: vector, index: 0)
            let promptTokens = reqContent.input.count
            let usage = OpenAIUsage(promptTokens: promptTokens, completionTokens: 0, totalTokens: promptTokens)
            return OpenAIEmbeddingResponse(data: [embeddingData], model: reqContent.model, usage: usage)
        }
    }
    
    private nonisolated func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    if let name = interface.flatMap({ String(cString: $0.ifa_name) }), name == "en0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}


extension ServerManager.ServerState {
    var isStartingOrRunning: Bool { if case .starting = self { return true }; if case .running = self { return true }; return false }
    var isError: Bool { if case .error = self { return true }; return false }
}
