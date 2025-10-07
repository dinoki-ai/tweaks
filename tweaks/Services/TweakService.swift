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

    Task {
      do {
        let client = try Osaurus.make()
        let (model, systemPrompt, temperature): (String, String, Double) = await MainActor.run {
          let settings = SettingsManager.shared
          return (
            settings.selectedModelId,
            settings.activePrompt?.content ?? Osaurus.Defaults.systemPrompt,
            settings.temperature
          )
        }

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
          deltaBuffer.removeAll()
        }

        if !receivedAny {
          let tweakedText = try await client.tweak(
            text: originalContent, model: model, systemPrompt: systemPrompt,
            temperature: temperature)
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
    }
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
}
