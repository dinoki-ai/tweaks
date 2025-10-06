//
//  Osaurus.swift
//  tweaks
//
//  Minimal Osaurus SDK: discovery + chat completions
//

import Foundation

// MARK: - SDK Models

enum OsaurusError: Error {
  case discoveryFailed
  case invalidResponse
  case httpError(Int)
}

struct OsaurusChatMessage: Codable {
  let role: String  // "system" | "user" | "assistant"
  let content: String
}

struct OsaurusChatCompletionRequest: Codable {
  let model: String
  let messages: [OsaurusChatMessage]
  let temperature: Double?
}

struct OsaurusChatChoice: Codable {
  let index: Int?
  let message: OsaurusChatMessage
}

struct OsaurusChatCompletionResponse: Codable {
  let id: String?
  let object: String?
  let created: Int?
  let model: String?
  let choices: [OsaurusChatChoice]
}

// MARK: - Client

final class Osaurus {
  let baseURL: URL
  let session: URLSession
  lazy var chat: Chat = Chat(client: self)

  init(baseURL: URL? = nil, session: URLSession = .shared) throws {
    if let provided = baseURL {
      self.baseURL = provided
    } else if let override = ProcessInfo.processInfo.environment["OSAURUS_BASE_URL"],
      let url = URL(string: override)
    {
      self.baseURL = url
      #if DEBUG
        print("[Osaurus] Using base URL from environment: \(url)")
      #endif
    } else {
      self.baseURL = URL(string: "http://localhost:1337")!
      #if DEBUG
        print("[Osaurus] Using default base URL: \(self.baseURL)")
      #endif
    }
    self.session = session
  }

  final class Chat {
    let client: Osaurus
    let completions: Completions
    init(client: Osaurus) {
      self.client = client
      self.completions = Completions(client: client)
    }

    final class Completions {
      let client: Osaurus
      init(client: Osaurus) { self.client = client }

      func create(model: String, messages: [OsaurusChatMessage], temperature: Double? = nil)
        async throws -> OsaurusChatCompletionResponse
      {
        var request = URLRequest(url: client.baseURL.appendingPathComponent("/v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = ProcessInfo.processInfo.environment["OSAURUS_API_KEY"], !key.isEmpty {
          request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        let payload = OsaurusChatCompletionRequest(
          model: model, messages: messages, temperature: temperature)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, resp) = try await client.session.data(for: request)
        guard let http = resp as? HTTPURLResponse else { throw OsaurusError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
          throw OsaurusError.httpError(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(OsaurusChatCompletionResponse.self, from: data)
        return decoded
      }
    }
  }
}

// MARK: - Convenience Helpers
extension Osaurus {
  enum Defaults {
    static let model: String = "llama-3.2-3b-instruct-4bit"
    static let systemPrompt: String =
      "You are Osaurus Tweak. Improve the user's copied text for clarity and tone. Preserve meaning and formatting. Output only the revised text without any preface."
    static let temperature: Double = 0.3
  }

  func tweak(
    text: String,
    model: String = Defaults.model,
    systemPrompt: String = Defaults.systemPrompt,
    temperature: Double = Defaults.temperature
  ) async throws -> String {
    let messages = [
      OsaurusChatMessage(role: "system", content: systemPrompt),
      OsaurusChatMessage(role: "user", content: text),
    ]
    let response = try await chat.completions.create(
      model: model, messages: messages, temperature: temperature)
    let content = response.choices.first?.message.content.trimmingCharacters(
      in: .whitespacesAndNewlines)
    guard let tweaked = content, !tweaked.isEmpty else {
      throw OsaurusError.invalidResponse
    }
    return tweaked
  }
}
