//
//  Osaurus.swift
//  tweaks
//
//  Osaurus SDK
//

import Foundation

// MARK: - Discovery Types

struct OsaurusSharedConfiguration: Decodable {
  let instanceId: String
  let updatedAt: String
  let health: String
  let port: Int?
  let address: String?
  let url: String?
  let exposeToNetwork: Bool?
}

struct OsaurusInstance {
  let instanceId: String
  let updatedAt: Date
  let address: String
  let port: Int
  let url: URL
  let exposeToNetwork: Bool
}

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

// Streaming request explicitly sets stream=true to avoid encoding nulls for non-stream calls
struct OsaurusChatCompletionStreamRequest: Codable {
  let model: String
  let messages: [OsaurusChatMessage]
  let temperature: Double?
  let stream: Bool
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

// Streaming chunk model (OpenAI-compatible: choices[].delta.content)
struct OsaurusChatCompletionChunk: Codable {
  struct Choice: Codable {
    struct Delta: Codable {
      let role: String?
      let content: String?
    }
    let index: Int?
    let delta: Delta
    let finish_reason: String?
  }
  let id: String?
  let object: String?
  let created: Int?
  let model: String?
  let choices: [Choice]
}

// MARK: - Models API Types

struct OsaurusModel: Codable, Identifiable, Hashable {
  let id: String
  let object: String?
  let created: Int?
  let owned_by: String?

  var displayName: String {
    id.replacingOccurrences(of: "llama-", with: "Llama ")
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "instruct", with: "Instruct")
      .replacingOccurrences(of: "4bit", with: "(4-bit)")
      .replacingOccurrences(of: "8bit", with: "(8-bit)")
      .replacingOccurrences(of: "fp16", with: "(FP16)")
  }
}

struct OsaurusModelsResponse: Codable {
  let object: String?
  let data: [OsaurusModel]
}

// MARK: - Client

final class Osaurus {
  let baseURL: URL
  let session: URLSession
  lazy var chat: Chat = Chat(client: self)

  // Canonical base path used by Osaurus discovery
  private static let bundleIdentifier = "com.dinoki.osaurus"

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

  // Factory that prefers env override, then discovery. Throws when not found.
  static func make(session: URLSession = .shared) throws -> Osaurus {
    if let override = ProcessInfo.processInfo.environment["OSAURUS_BASE_URL"],
      let url = URL(string: override)
    {
      return try Osaurus(baseURL: url, session: session)
    }
    do {
      let instance = try discoverLatestRunningInstance()
      return try Osaurus(baseURL: instance.url, session: session)
    } catch {
      throw OsaurusError.discoveryFailed
    }
  }

  // MARK: - Discovery

  /// Discovers the latest running Osaurus instance by reading shared configuration files
  static func discoverLatestRunningInstance() throws -> OsaurusInstance {
    let fm = FileManager.default
    let supportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let base =
      supportDir
      .appendingPathComponent(bundleIdentifier, isDirectory: true)
      .appendingPathComponent("SharedConfiguration", isDirectory: true)

    guard
      let instanceDirs = try? fm.contentsOfDirectory(
        at: base, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
        options: [.skipsHiddenFiles]), !instanceDirs.isEmpty
    else {
      throw OsaurusError.discoveryFailed
    }

    var candidates: [OsaurusInstance] = []

    for dir in instanceDirs {
      var isDirectory: ObjCBool = false
      guard fm.fileExists(atPath: dir.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        continue
      }
      let fileURL = dir.appendingPathComponent("configuration.json")
      guard fm.fileExists(atPath: fileURL.path) else { continue }

      do {
        let data = try Data(contentsOf: fileURL)
        let cfg = try JSONDecoder().decode(OsaurusSharedConfiguration.self, from: data)
        guard cfg.health == "running", let address = cfg.address, let port = cfg.port else {
          continue
        }

        let updatedAt: Date =
          ISO8601DateFormatter().date(from: cfg.updatedAt)
          ?? (try? dir.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate) ?? Date.distantPast

        let url: URL
        if let cfgURL = cfg.url, let parsed = URL(string: cfgURL) {
          url = parsed
        } else {
          var comps = URLComponents()
          comps.scheme = "http"
          comps.host = address
          comps.port = port
          url = comps.url!
        }

        let expose = cfg.exposeToNetwork ?? false

        candidates.append(
          OsaurusInstance(
            instanceId: cfg.instanceId,
            updatedAt: updatedAt,
            address: address,
            port: port,
            url: url,
            exposeToNetwork: expose
          ))
      } catch {
        // Ignore malformed entries and continue
        continue
      }
    }

    guard let best = candidates.max(by: { $0.updatedAt < $1.updatedAt }) else {
      throw OsaurusError.discoveryFailed
    }
    return best
  }

  /// Quick check to see if any Osaurus instance is running
  static func isRunning() -> Bool {
    do {
      _ = try discoverLatestRunningInstance()
      return true
    } catch {
      return false
    }
  }

  /// Async health check that verifies connectivity to the discovered instance
  static func checkHealth() async -> Bool {
    do {
      let instance = try discoverLatestRunningInstance()
      let client = try Osaurus(baseURL: instance.url)

      // Try to list models as a lightweight health check
      let request = client.buildRequest(path: "v1/models")
      let (_, resp) = try await client.session.data(for: request)
      guard let http = resp as? HTTPURLResponse else { return false }
      return (200...299).contains(http.statusCode)
    } catch {
      return false
    }
  }

  // Build URL for API path like "v1/chat/completions"
  fileprivate func url(path: String) -> URL {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
    let normalized = path.hasPrefix("/") ? path : "/" + path
    components.path = (components.path.isEmpty ? "" : components.path) + normalized
    return components.url!
  }

  // Build a request with shared headers
  fileprivate func buildRequest(path: String, method: String = "GET", accept: String? = nil)
    -> URLRequest
  {
    var request = URLRequest(url: url(path: path))
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let accept { request.setValue(accept, forHTTPHeaderField: "Accept") }
    if let key = ProcessInfo.processInfo.environment["OSAURUS_API_KEY"], !key.isEmpty {
      request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    }
    return request
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

      func create(
        model: String,
        messages: [OsaurusChatMessage],
        temperature: Double? = nil
      ) async throws -> OsaurusChatCompletionResponse {
        var request = client.buildRequest(path: "v1/chat/completions", method: "POST")
        let payload = OsaurusChatCompletionRequest(
          model: model,
          messages: messages,
          temperature: temperature)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, resp) = try await client.session.data(for: request)
        guard let http = resp as? HTTPURLResponse else { throw OsaurusError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
          throw OsaurusError.httpError(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(OsaurusChatCompletionResponse.self, from: data)
        return decoded
      }

      // Streamed chat completion that yields content deltas as they arrive
      func createStream(
        model: String,
        messages: [OsaurusChatMessage],
        temperature: Double? = nil
      ) -> AsyncThrowingStream<String, Error> {
        var request = client.buildRequest(
          path: "v1/chat/completions", method: "POST", accept: "text/event-stream")

        // Encode with stream=true
        let payload = OsaurusChatCompletionStreamRequest(
          model: model,
          messages: messages,
          temperature: temperature,
          stream: true)
        request.httpBody = try? JSONEncoder().encode(payload)

        return AsyncThrowingStream { continuation in
          Task {
            do {
              let (bytes, resp) = try await client.session.bytes(for: request)
              guard let http = resp as? HTTPURLResponse else {
                throw OsaurusError.invalidResponse
              }
              guard (200...299).contains(http.statusCode) else {
                throw OsaurusError.httpError(http.statusCode)
              }

              for try await line in bytes.lines {
                // Expect lines like: "data: {json}" and blank line between events
                if line.hasPrefix("data:") {
                  let dataPart = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                  if dataPart == "[DONE]" {
                    break
                  }
                  if let jsonData = dataPart.data(using: .utf8) {
                    do {
                      let chunk = try JSONDecoder().decode(
                        OsaurusChatCompletionChunk.self, from: jsonData)
                      if let delta = chunk.choices.first?.delta.content, !delta.isEmpty {
                        continuation.yield(delta)
                      }
                    } catch {
                      // Ignore non-JSON keepalive chunks silently in release; log in debug
                      #if DEBUG
                        print("[Osaurus] Failed to decode stream chunk: \(error)")
                        if let str = String(data: jsonData, encoding: .utf8) {
                          print("[Osaurus] Chunk payload=\(str)")
                        }
                      #endif
                    }
                  }
                }
              }
              continuation.finish()
            } catch {
              continuation.finish(throwing: error)
            }
          }
        }
      }
    }
  }
}

// MARK: - Convenience Helpers
extension Osaurus {
  enum Defaults {
    static let model: String = "llama-3.2-3b-instruct-4bit"
    static let systemPrompt: String =
      "Improve the provided text for clarity and tone. Preserve meaning and formatting. Output only the revised text."
    static let temperature: Double = 0.3
  }

  func tweak(
    text: String,
    model: String,
    systemPrompt: String,
    temperature: Double
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

  // Streaming variant that yields only content deltas
  func tweakStream(
    text: String,
    model: String,
    systemPrompt: String,
    temperature: Double
  ) -> AsyncThrowingStream<String, Error> {
    let messages = [
      OsaurusChatMessage(role: "system", content: systemPrompt),
      OsaurusChatMessage(role: "user", content: text),
    ]
    return chat.completions.createStream(
      model: model, messages: messages, temperature: temperature)
  }

  // List available models from the server
  func listModels() async throws -> [OsaurusModel] {
    let request = buildRequest(path: "v1/models")
    let (data, resp) = try await session.data(for: request)
    guard let http = resp as? HTTPURLResponse else { throw OsaurusError.invalidResponse }
    guard (200...299).contains(http.statusCode) else {
      throw OsaurusError.httpError(http.statusCode)
    }
    let decoded = try JSONDecoder().decode(OsaurusModelsResponse.self, from: data)
    return decoded.data
  }
}
