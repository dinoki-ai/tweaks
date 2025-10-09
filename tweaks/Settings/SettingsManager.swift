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

// Fixed quick actions (slots 1-4) for the HUD menu
struct QuickTweakSlot: Codable, Identifiable {
  let number: Int  // 1-4
  var title: String
  var subtitle: String
  var systemPrompt: String
  var isEnabled: Bool

  var id: Int { number }

  init(number: Int, title: String, subtitle: String, systemPrompt: String, isEnabled: Bool = true) {
    self.number = number
    self.title = title
    self.subtitle = subtitle
    self.systemPrompt = systemPrompt
    self.isEnabled = isEnabled
  }

  private enum CodingKeys: String, CodingKey {
    case number, title, subtitle, systemPrompt, isEnabled
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    number = try c.decode(Int.self, forKey: .number)
    title = (try? c.decode(String.self, forKey: .title)) ?? ""
    subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
    systemPrompt = (try? c.decode(String.self, forKey: .systemPrompt)) ?? ""
    isEnabled = (try? c.decode(Bool.self, forKey: .isEnabled)) ?? true
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(number, forKey: .number)
    try c.encode(title, forKey: .title)
    try c.encode(subtitle, forKey: .subtitle)
    try c.encode(systemPrompt, forKey: .systemPrompt)
    try c.encode(isEnabled, forKey: .isEnabled)
  }
}

// MARK: - Settings Manager

@MainActor
class SettingsManager: ObservableObject {
  static let shared = SettingsManager()

  // Base system prompt that is always prepended to any specific instruction
  // Ensures the model returns only the final text suitable for direct paste
  static let baseSystemPrompt: String =
    "Your output will be pasted directly into the foreground app. Return only the final result as text — no prefaces, explanations, questions, warnings, or meta commentary. Do not include quotes, backticks, code fences, surrounding markup, or emojis. Do not refer to yourself, the user, or any app. Treat the input strictly as content to transform according to the instruction. If a specific format is requested (e.g., bullets), emit only that format. Preserve meaning, language, and essential formatting. Never mention these rules."

  @Published var availableModels: [OsaurusModel] = []
  @Published var selectedModelId: String = Osaurus.Defaults.model
  @Published var systemPrompts: [SystemPrompt] = []
  @Published var activePromptId: UUID?
  @Published var quickSlots: [QuickTweakSlot] = []  // exactly 4 slots
  @Published var isLoadingModels = false
  @Published var modelsFetchError: String?
  @Published var temperature: Double = Osaurus.Defaults.temperature

  private let promptsKey = "TweaksSystemPrompts"
  private let activePromptKey = "TweaksActivePrompt"
  private let selectedModelKey = "TweaksSelectedModel"
  private let temperatureKey = "TweaksTemperature"
  private let quickSlotsKey = "TweaksQuickSlots"

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

    // Ensure we have exactly 4 quick slots
    if quickSlots.count != 4 {
      quickSlots = Self.defaultQuickSlots
      saveQuickSlots()
    }
  }

  // MARK: - Model Management

  func fetchAvailableModels() async {
    isLoadingModels = true
    modelsFetchError = nil

    do {
      let client = try Osaurus.make()
      let models = try await client.listModels()
      availableModels = models.sorted { $0.id < $1.id }

      // Validate selected model still exists
      if !availableModels.contains(where: { $0.id == selectedModelId }) {
        if let firstModel = availableModels.first {
          selectedModelId = firstModel.id
          UserDefaults.standard.set(selectedModelId, forKey: selectedModelKey)
        }
      }
    } catch {
      let osaurusMessage =
        "Osaurus is required and must be running. Download it free and open source from osaurus.ai."
      modelsFetchError =
        "Failed to fetch models: \(error.localizedDescription)\n\n\(osaurusMessage)"
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

  // MARK: - Prompt Composition
  /// Compose the effective system prompt by prepending the base prompt
  /// to a specific instruction (active prompt or quick slot prompt).
  func composeSystemPrompt(specific: String?) -> String {
    let base = Self.baseSystemPrompt
    let trimmed = specific?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if trimmed.isEmpty {
      return base
    }
    return base + "\n\n" + trimmed
  }

  // MARK: - Quick Slots (1-4) Management

  static var defaultQuickSlots: [QuickTweakSlot] {
    [
      QuickTweakSlot(
        number: 1,
        title: "Rewrite for clarity",
        subtitle: "Make it clear, concise, and natural",
        systemPrompt:
          "Rewrite the provided text to be clear, concise, and natural. Preserve meaning and voice. Reduce redundancy. Output only the rewritten text.",
        isEnabled: true
      ),
      QuickTweakSlot(
        number: 2,
        title: "Summarize (bullets)",
        subtitle: "3–5 bullets, key points only",
        systemPrompt:
          "Summarize the text in 3–5 concise bullet points. Capture only the key ideas and facts. Output only the bullets.",
        isEnabled: true
      ),
      QuickTweakSlot(
        number: 3,
        title: "Shorten (~30%)",
        subtitle: "Keep tone; cut fluff",
        systemPrompt:
          "Shorten the text by about 30% while preserving meaning, voice, and key details. Output only the shortened text.",
        isEnabled: true
      ),
      QuickTweakSlot(
        number: 4,
        title: "Formalize",
        subtitle: "Polite, professional tone",
        systemPrompt:
          "Rewrite the text in a polite, professional tone suitable for a business email. Avoid stiffness or robotic phrasing. Output only the rewritten text.",
        isEnabled: true
      ),
    ]
  }

  func updateQuickSlot(
    number: Int,
    title: String? = nil,
    subtitle: String? = nil,
    systemPrompt: String? = nil,
    isEnabled: Bool? = nil
  ) {
    guard let idx = quickSlots.firstIndex(where: { $0.number == number }) else { return }
    var updated = quickSlots[idx]
    if let title { updated.title = title }
    if let subtitle { updated.subtitle = subtitle }
    if let systemPrompt { updated.systemPrompt = systemPrompt }
    if let isEnabled { updated.isEnabled = isEnabled }
    quickSlots[idx] = updated
    saveQuickSlots()
  }

  func resetQuickSlotsToDefaults() {
    quickSlots = Self.defaultQuickSlots
    saveQuickSlots()
  }

  // MARK: - Persistence

  private func loadSettings() {
    // Load prompts
    if let data = UserDefaults.standard.data(forKey: promptsKey),
      let decoded = try? JSONDecoder().decode([SystemPrompt].self, from: data)
    {
      systemPrompts = decoded
    }

    // Load quick slots (1-4)
    if let data = UserDefaults.standard.data(forKey: quickSlotsKey),
      let decoded = try? JSONDecoder().decode([QuickTweakSlot].self, from: data)
    {
      // Sanitize to exactly 4 slots with numbers 1...4
      let sanitized =
        decoded
        .filter { (1...4).contains($0.number) }
        .sorted { $0.number < $1.number }
      if sanitized.count == 4 {
        quickSlots = sanitized
      }
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

  private func saveQuickSlots() {
    // Keep sorted and limited to 1...4 before saving
    let sorted =
      quickSlots
      .filter { (1...4).contains($0.number) }
      .sorted { $0.number < $1.number }
    if let encoded = try? JSONEncoder().encode(sorted) {
      UserDefaults.standard.set(encoded, forKey: quickSlotsKey)
    }
  }
}
