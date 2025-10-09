//
//  TweakService.swift
//  tweaks
//
//  Encapsulates clipboard read, AI tweak, paste, and restore
//

import AppKit
import Carbon
import Foundation

@MainActor
final class TweakService {
  static let shared = TweakService()
  private init() {}

  func pasteTweakedText() {
    if DebugHelpers.isDebugBuild {
      let trusted = AXIsProcessTrusted()
      let secureInput = IsSecureEventInputEnabled()
      let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
      print(
        "[Tweaks] Enter pasteTweakedText trusted=\(trusted) secureInput=\(secureInput) app=\(activeApp)"
      )
    }

    guard AXIsProcessTrusted() else { return }
    guard Osaurus.isRunning() else { return }

    let pasteboard = NSPasteboard.general
    guard let originalContent = pasteboard.string(forType: .string) else { return }

    // Read settings on MainActor (this method is @MainActor)
    let settings = SettingsManager.shared
    let model = settings.selectedModelId
    let systemPrompt = settings.activePrompt?.content ?? Osaurus.Defaults.systemPrompt
    let temperature = settings.temperature

    Task {
      await self.performPasteFlow(
        originalContent: originalContent,
        model: model,
        systemPrompt: systemPrompt,
        temperature: temperature
      )
    }
  }

  /// Paste tweaked text using a specific system prompt (used by HUD quick slots 1-4)
  func pasteTweakedText(usingSystemPrompt systemPrompt: String) {
    if DebugHelpers.isDebugBuild {
      let trusted = AXIsProcessTrusted()
      let secureInput = IsSecureEventInputEnabled()
      let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
      print(
        "[Tweaks] Enter pasteTweakedText(tray) trusted=\(trusted) secureInput=\(secureInput) app=\(activeApp)"
      )
    }

    guard AXIsProcessTrusted() else { return }
    guard Osaurus.isRunning() else { return }

    let pasteboard = NSPasteboard.general
    let originalClipboard = pasteboard.string(forType: .string)

    // Attempt to copy current selection (Cmd+C), then read fresh clipboard
    Self.postCmdC(tap: .cgSessionEventTap)
    usleep(25_000)  // small delay to allow clipboard to update
    guard let originalContent = pasteboard.string(forType: .string), !originalContent.isEmpty else {
      // Fallback to previous clipboard content if selection copy failed
      guard let fallback = originalClipboard, !fallback.isEmpty else { return }
      Task {
        // Run flow against fallback content to still provide output
        let settings = SettingsManager.shared
        await self.performPasteFlow(
          originalContent: fallback,
          model: settings.selectedModelId,
          systemPrompt: systemPrompt,
          temperature: settings.temperature
        )
      }
      return
    }

    // Use selected model and temperature; override only the system prompt
    let settings = SettingsManager.shared
    let model = settings.selectedModelId
    let temperature = settings.temperature

    Task {
      await self.performPasteFlow(
        originalContent: originalContent,
        model: model,
        systemPrompt: systemPrompt,
        temperature: temperature
      )
    }
  }

  private func performPasteFlow(
    originalContent: String,
    model: String,
    systemPrompt: String,
    temperature: Double
  ) async {
    let pasteboard = NSPasteboard.general
    do {
      HotkeyFeedbackManager.shared.beginLoading()
      let client = try Osaurus.make()

      let stream = client.tweakStream(
        text: originalContent, model: model, systemPrompt: systemPrompt, temperature: temperature)

      var deltaBuffer = ""
      var receivedAny = false

      func pasteDelta(_ delta: String) {
        guard !delta.isEmpty else { return }
        DispatchQueue.main.async {
          pasteboard.clearContents()
          _ = pasteboard.setString(delta, forType: .string)
          let prePasteDelay: TimeInterval = 0.02
          DispatchQueue.main.asyncAfter(deadline: .now() + prePasteDelay) {
            Self.postCmdV(tap: .cgSessionEventTap, label: "session tap")
          }
        }
      }

      for try await chunk in stream {
        if chunk.isEmpty { continue }
        receivedAny = true
        deltaBuffer.append(chunk)
        if deltaBuffer.count >= 24 || deltaBuffer.contains("\n") {
          pasteDelta(deltaBuffer)
          deltaBuffer.removeAll(keepingCapacity: true)
        }
      }

      if !deltaBuffer.isEmpty {
        pasteDelta(deltaBuffer)
      }

      if !receivedAny {
        let tweakedText = try await client.tweak(
          text: originalContent, model: model, systemPrompt: systemPrompt, temperature: temperature)
        DispatchQueue.main.async {
          pasteboard.clearContents()
          _ = pasteboard.setString(tweakedText, forType: .string)
          let prePasteDelay: TimeInterval = 0.02
          DispatchQueue.main.asyncAfter(deadline: .now() + prePasteDelay) {
            Self.postCmdV(tap: .cgSessionEventTap, label: "session tap")
          }
        }
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) {
        pasteboard.clearContents()
        pasteboard.setString(originalContent, forType: .string)
      }
    } catch {
      DispatchQueue.main.async {
        pasteboard.clearContents()
        _ = pasteboard.setString(originalContent, forType: .string)
        let prePasteDelay: TimeInterval = 0.02
        DispatchQueue.main.asyncAfter(deadline: .now() + prePasteDelay) {
          Self.postCmdV(tap: .cgSessionEventTap, label: "session tap")
        }
      }
    }
    HotkeyFeedbackManager.shared.endLoading()
  }

  private static func postCmdV(tap: CGEventTapLocation, label: String) {
    let source = CGEventSource(stateID: .combinedSessionState)
    let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
    cmdDown?.flags = .maskCommand
    let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
    vDown?.flags = .maskCommand
    let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
    vUp?.flags = .maskCommand
    let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
    cmdUp?.flags = .maskCommand
    cmdDown?.post(tap: tap)
    usleep(1500)
    vDown?.post(tap: tap)
    usleep(1500)
    vUp?.post(tap: tap)
    usleep(1500)
    cmdUp?.post(tap: tap)
  }

  private static func postCmdC(tap: CGEventTapLocation) {
    let source = CGEventSource(stateID: .combinedSessionState)
    let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
    cmdDown?.flags = .maskCommand
    let cDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
    cDown?.flags = .maskCommand
    let cUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
    cUp?.flags = .maskCommand
    let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
    cmdUp?.flags = .maskCommand
    cmdDown?.post(tap: tap)
    usleep(1500)
    cDown?.post(tap: tap)
    usleep(1500)
    cUp?.post(tap: tap)
    usleep(1500)
    cmdUp?.post(tap: tap)
  }
}
