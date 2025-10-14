//
//  ModelManager.swift
//  nemois_Worker
//
//  Created by nemois on 10/14/25.
//

import Foundation
import CoreML
import FoundationModels
import Combine
import NaturalLanguage

/// 온디바이스 AI 모델의 로딩과 실행을 관리하는 `ObservableObject`입니다.
final class ModelManager: ObservableObject {
    enum ModelState: Equatable {
        case notLoaded
        case loading
        case loaded
        case error(String)
    }
    
    @Published var modelState: ModelState = .notLoaded
    @Published var memoryMode: Bool = false
    private var activeModel: LanguageModelSession?
    
    @MainActor
    func loadModel() {
        guard !isModelLoaded else {
            LogStore.shared.add(log: "Model is already loaded.")
            return
        }
        
        LogStore.shared.add(log: "Starting model load...")
        self.modelState = .loading
        
        Task.detached(priority: .userInitiated) {
            do {
                try await self.initializeModel()
                await MainActor.run {
                    self.modelState = .loaded
                    LogStore.shared.add(log: "Model loaded successfully.")
                }
            } catch {
                let errorMessage = "Model load failed: \(error.localizedDescription)"
                await MainActor.run {
                    LogStore.shared.add(log: errorMessage)
                    self.modelState = .error(errorMessage)
                }
            }
        }
    }
    
    @MainActor
    func unloadModel() {
        activeModel = nil
        modelState = .notLoaded
        LogStore.shared.add(log: "Model unloaded from memory.")
    }
    
    var isModelLoaded: Bool {
        if case .loaded = modelState { return true }
        return false
    }
    
    var currentModelInfo: ModelObject? {
        guard isModelLoaded else { return nil }
        let modelId: String
        modelId = "apple-foundation-model"
        return ModelObject(id: modelId, created: Int(Date().timeIntervalSince1970), ownedBy: "Apple")
    }
    
    func generateResponse(for messages: [OpenAIChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let activeModel = self.activeModel else {
                    continuation.finish(throwing: ModelError.modelNotLoaded)
                    return
                }
                do {
                    let session = activeModel
                    
                    // --- 1. 상수 정의 ---
                    let CONTEXT_LIMIT = 4096 // 모델의 전체 컨텍스트 창 크기
                    let RESPONSE_BUFFER = 1536 // 모델이 답변을 생성할 수 있도록 남겨둘 최소 토큰 공간
                    let PROMPT_TOKEN_LIMIT = CONTEXT_LIMIT - RESPONSE_BUFFER // 프롬프트가 차지할 수 있는 최대 토큰

                    // --- 2. 간단한 토큰 추정 함수 ---
                    func estimateTokens(for text: String) -> Int {
                        return Int(ceil(Double(text.count) / 1.0))
                    }

                    let stream: LanguageModelSession.ResponseStream<String>?
                    
                    var messagesForPrompt: [OpenAIChatMessage] = []
                    var currentTokens = 0
                    
                    // 가장 최신 메시지를 우선적으로 처리합니다. 이 메시지는 반드시 포함되어야 합니다.
                    guard let latestMessage = messages.last else {
                        // 메시지가 없는 경우, 빈 스트림을 시작하고 종료합니다.
                        // let stream = session.streamResponse(to: "")
                        continuation.finish()
                        // 실제로는 이 Task를 바로 return 해야 하지만, 현재 구조상 break 처럼 동작하게 둡니다.
                        // 이 부분은 함수의 전체 구조를 리팩토링할 때 개선될 수 있습니다.
                        return
                    }
                    
                    if memoryMode {
                        // 현재 요청(가장 최신 메시지)을 프롬프트에 먼저 추가합니다.
                        messagesForPrompt.append(latestMessage)
                        let latestMessageText = "\(latestMessage.role.rawValue): \(latestMessage.content)\n"
                        currentTokens += estimateTokens(for: latestMessageText)
                        
                        // 나머지 과거 대화 기록을 최신 순서(뒤에서부터)로 순회합니다.
                        let historicalMessages = messages.dropLast().reversed()
                        
                        for message in historicalMessages {
                            let messageText = "\(message.role.rawValue): \(message.content)\n"
                            let messageTokens = estimateTokens(for: messageText)
                            
                            // 이 메시지를 추가했을 때 토큰 제한을 넘지 않는 경우에만 포함시킵니다.
                            if currentTokens + messageTokens <= PROMPT_TOKEN_LIMIT {
                                currentTokens += messageTokens
                                // 배열의 맨 앞에 추가하여 원래의 시간 순서를 유지합니다.
                                messagesForPrompt.insert(message, at: 0)
                            } else {
                                // 토큰 제한을 초과하면 더 이상 과거 기록을 추가하지 않고 중단합니다.
                                break
                            }
                        }
                        // --- 4. 최종 프롬프트를 생성합니다. ---
                        let prompt = messagesForPrompt.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")
                        
                        LogStore.shared.add(log: "Prompt created with \(messagesForPrompt.count) messages, ensuring latest request. Estimated tokens: \(currentTokens).")
                        
                        stream = session.streamResponse(to: prompt)
                    } else {
                        messagesForPrompt.append(latestMessage)
                        let prompt = messagesForPrompt.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")
                        
                        stream = session.streamResponse(to: prompt)
                    }

                    guard let safe_stream = stream else {
                        continuation.finish(throwing: ModelError.outputProcessingError)
                        return
                    }
                    
                    // --- 5. 스트림 응답 처리 (델타 계산) ---
                    var lastResponse = ""
                    for try await partialResponse in safe_stream {
                        let fullResponse = partialResponse.content
                        let delta = fullResponse.dropFirst(lastResponse.count)
                        
                        if !delta.isEmpty {
                            continuation.yield(String(delta))
                            lastResponse = fullResponse
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func generateEmbedding(for input: String) async throws -> [Double] {
        guard let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english) else { throw ModelError.embeddingModelUnavailable }
        guard let vector = sentenceEmbedding.vector(for: input) else { throw ModelError.embeddingGenerationFailed }
        return vector
}
    
    private enum ModelType { case builtIn, custom(url: URL) }
    
    enum ModelError: Error, LocalizedError {
        case modelNotLoaded, featureProviderError, outputProcessingError, embeddingModelUnavailable, embeddingGenerationFailed, unsupportedForCustomModel
        case invalidURL(message: String)
        var errorDescription: String? {
            switch self {
            case .modelNotLoaded: "Model is not loaded."
            case .featureProviderError: "Failed to create model input features."
            case .outputProcessingError: "Failed to process model output."
            case .invalidURL(let message): message
            case .embeddingModelUnavailable: "The sentence embedding model is unavailable."
            case .embeddingGenerationFailed: "Failed to generate embedding for the input text."
            case .unsupportedForCustomModel: "This feature is not supported for custom models."
            }
        }
    }
    
    private func initializeModel() throws {
        activeModel = LanguageModelSession()
        LogStore.shared.add(log: "Built-in Foundation Model initialized.")
    }
}
