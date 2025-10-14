
//
//  OpenAIModels.swift
//  nemois_Worker
//
//  Created by nemois on 10/14/25.
//

import Foundation
import Vapor

// 이 파일은 OpenAI API(v1)와 호환되는 데이터 모델을 정의합니다.

// MARK: - Chat Completions Structures

struct OpenAIChatRequest: Content {
    let model: String
    let messages: [OpenAIChatMessage]
    let stream: Bool? // 스트리밍 응답 요청 여부
}

struct OpenAIChatMessage: Content {
    let role: Role
    let content: String
    
    // 기본 멤버별 초기화 메소드를 다시 추가합니다.
    init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
    
    enum Role: String, Codable {
        case system
        case user
        case assistant
    }
    
    // content 필드가 String 또는 Array 형태 모두를 받을 수 있도록 커스텀 디코딩을 구현합니다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(Role.self, forKey: .role)
        
        // content를 먼저 String으로 디코딩 시도
        if let stringContent = try? container.decode(String.self, forKey: .content) {
            self.content = stringContent
        // 실패하면, 텍스트 파트를 담은 배열로 디코딩 시도
        } else if let contentParts = try? container.decode([ContentPart].self, forKey: .content) {
            // 배열에서 첫 번째 "text" 타입의 내용을 찾아 사용합니다.
            self.content = contentParts.first { $0.type == "text" }?.text ?? ""
        } else {
            throw DecodingError.dataCorruptedError(forKey: .content, in: container, debugDescription: "Content field is not a String or a valid array of content parts.")
        }
    }
    
    // 인코딩은 단순 String으로만 처리합니다.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
    }
    
    // 디코딩 시 사용할 키
    enum CodingKeys: String, CodingKey {
        case role, content
    }
    
    // content가 배열일 경우, 각 항목의 구조
    private struct ContentPart: Decodable {
        let type: String
        let text: String? // 이미지 등 다른 타입이 올 수 있으므로 옵셔널
    }
}

struct OpenAIChatResponse: Content {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIChatChoice]
    let usage: OpenAIUsage
}

struct OpenAIChatChoice: Content {
    let index: Int
    let message: OpenAIChatMessage
    let finishReason: String
    
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

// MARK: - Chat Completions Stream Structures

struct OpenAIChatStreamChunk: Content {
    let id: String
    var object: String = "chat.completion.chunk"
    let created: Int
    let model: String
    let choices: [ChatStreamChoice]
}

struct ChatStreamChoice: Content {
    let index: Int
    let delta: ChatStreamDelta
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, delta
        case finishReason = "finish_reason"
    }
}

struct ChatStreamDelta: Content {
    var role: OpenAIChatMessage.Role?
    let content: String?
}

// MARK: - Legacy Completions Structures

struct OpenAICompletionRequest: Content {
    let model: String
    let prompt: String
}

struct OpenAICompletionResponse: Content {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAICompletionChoice]
    let usage: OpenAIUsage
}

struct OpenAICompletionChoice: Content {
    let text: String
    let index: Int
    let finishReason: String

    enum CodingKeys: String, CodingKey {
        case text, index
        case finishReason = "finish_reason"
    }
}

// MARK: - Embeddings Structures

struct OpenAIEmbeddingRequest: Content {
    let model: String
    let input: String
}

struct OpenAIEmbeddingResponse: Content {
    var object: String = "list"
    let data: [OpenAIEmbeddingData]
    let model: String
    let usage: OpenAIUsage
}

struct OpenAIEmbeddingData: Content {
    var object: String = "embedding"
    let embedding: [Double]
    let index: Int
}

// MARK: - Shared Structures

struct OpenAIUsage: Content {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Model List Structures

struct ModelListResponse: Content {
    var object: String = "list"
    let data: [ModelObject]
}

struct ModelObject: Content {
    let id: String
    let object: String = "model"
    let created: Int
    let ownedBy: String
    
    enum CodingKeys: String, CodingKey {
        case id, object, created
        case ownedBy = "owned_by"
    }
}
