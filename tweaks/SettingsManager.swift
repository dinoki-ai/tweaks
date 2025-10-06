//
//  SettingsManager.swift
//  tweaks
//
//  Manages AI models and custom system prompts
//

import Combine
import Foundation
import SwiftUI

// MARK: - Data Models

struct OsaurusModel: Codable, Identifiable, Hashable {
  let id: String
  let object: String?
  let created: Int?
  let owned_by: String?

  var displayName: String {
    // Extract clean model name for display
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

struct SystemPrompt: Codable, Identifiable {
  let id: UUID
  var name: String
  var content: String
  var isDefault: Bool

  init(id: UUID = UUID(), name: String, content: String, isDefault: Bool = false) {
    self.id = id
    self.name = name
    self.content = content
    self.isDefault = isDefault
  }
}

// MARK: - Settings Manager

@MainActor
class SettingsManager: ObservableObject {
  static let shared = SettingsManager()

  @Published var availableModels: [OsaurusModel] = []
  @Published var selectedModelId: String = Osaurus.Defaults.model
  @Published var systemPrompts: [SystemPrompt] = []
  @Published var activePromptId: UUID?
  @Published var isLoadingModels = false
  @Published var modelsFetchError: String?
  @Published var temperature: Double = Osaurus.Defaults.temperature

  private let promptsKey = "TweaksSystemPrompts"
  private let activePromptKey = "TweaksActivePrompt"
  private let selectedModelKey = "TweaksSelectedModel"
  private let temperatureKey = "TweaksTemperature"

  private init() {
    loadSettings()

    // If no prompts exist, create the default one
    if systemPrompts.isEmpty {
      let defaultPrompt = SystemPrompt(
        name: "Default Tweaker",
        content: Osaurus.Defaults.systemPrompt,
        isDefault: true
      )
      systemPrompts = [defaultPrompt]
      activePromptId = defaultPrompt.id
      savePrompts()
    }
  }

  // MARK: - Model Management

  func fetchAvailableModels() async {
    isLoadingModels = true
    modelsFetchError = nil

    do {
      let client = try Osaurus()
      let url = client.baseURL.appendingPathComponent("/v1/models")

      var request = URLRequest(url: url)
      if let key = ProcessInfo.processInfo.environment["OSAURUS_API_KEY"], !key.isEmpty {
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
      }

      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse,
        (200...299).contains(httpResponse.statusCode)
      else {
        throw OsaurusError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
      }

      let modelsResponse = try JSONDecoder().decode(OsaurusModelsResponse.self, from: data)
      availableModels = modelsResponse.data.sorted { $0.id < $1.id }

      // Validate selected model still exists
      if !availableModels.contains(where: { $0.id == selectedModelId }) {
        if let firstModel = availableModels.first {
          selectedModelId = firstModel.id
          UserDefaults.standard.set(selectedModelId, forKey: selectedModelKey)
        }
      }
    } catch {
      modelsFetchError = "Failed to fetch models: \(error.localizedDescription)"
      print("[SettingsManager] Error fetching models: \(error)")
    }

    isLoadingModels = false
  }

  func selectModel(_ modelId: String) {
    selectedModelId = modelId
    UserDefaults.standard.set(modelId, forKey: selectedModelKey)
  }

  // MARK: - Prompt Management

  func addPrompt(name: String, content: String) {
    let newPrompt = SystemPrompt(name: name, content: content)
    systemPrompts.append(newPrompt)
    savePrompts()
  }

  func updatePrompt(_ promptId: UUID, name: String, content: String) {
    if let index = systemPrompts.firstIndex(where: { $0.id == promptId }) {
      systemPrompts[index].name = name
      systemPrompts[index].content = content
      savePrompts()
    }
  }

  func deletePrompt(_ promptId: UUID) {
    // Don't delete the default prompt
    guard let prompt = systemPrompts.first(where: { $0.id == promptId }),
      !prompt.isDefault
    else { return }

    systemPrompts.removeAll { $0.id == promptId }

    // If we deleted the active prompt, switch to default
    if activePromptId == promptId {
      if let defaultPrompt = systemPrompts.first(where: { $0.isDefault }) {
        activePromptId = defaultPrompt.id
      } else if let firstPrompt = systemPrompts.first {
        activePromptId = firstPrompt.id
      }
    }

    savePrompts()
  }

  func setActivePrompt(_ promptId: UUID) {
    activePromptId = promptId
    UserDefaults.standard.set(promptId.uuidString, forKey: activePromptKey)
  }

  var activePrompt: SystemPrompt? {
    systemPrompts.first { $0.id == activePromptId }
  }

  func updateTemperature(_ value: Double) {
    temperature = value
    UserDefaults.standard.set(temperature, forKey: temperatureKey)
  }

  // MARK: - Persistence

  private func loadSettings() {
    // Load prompts
    if let data = UserDefaults.standard.data(forKey: promptsKey),
      let decoded = try? JSONDecoder().decode([SystemPrompt].self, from: data)
    {
      systemPrompts = decoded
    }

    // Load active prompt
    if let activePromptString = UserDefaults.standard.string(forKey: activePromptKey),
      let uuid = UUID(uuidString: activePromptString)
    {
      activePromptId = uuid
    }

    // Load selected model
    if let model = UserDefaults.standard.string(forKey: selectedModelKey) {
      selectedModelId = model
    }

    // Load temperature
    if UserDefaults.standard.object(forKey: temperatureKey) != nil {
      temperature = UserDefaults.standard.double(forKey: temperatureKey)
    }
  }

  private func savePrompts() {
    if let encoded = try? JSONEncoder().encode(systemPrompts) {
      UserDefaults.standard.set(encoded, forKey: promptsKey)
    }

    if let activeId = activePromptId {
      UserDefaults.standard.set(activeId.uuidString, forKey: activePromptKey)
    }
  }
}
