//
//  AppDelegate.swift
//  tweaks
//
//  Created by Terence on 10/5/25.
//

import AppKit
import Carbon
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  static var shared: AppDelegate?
  var statusItem: NSStatusItem?
  var popover = NSPopover()
  var hotKeyRef: EventHotKeyRef?
  var hotKeyEventHandler: EventHandlerRef?
  let hotkeyKeyCodeDefaultsKey = "HotkeyKeyCode"
  let hotkeyModifiersDefaultsKey = "HotkeyModifiers"

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Expose shared reference for convenient access from SwiftUI views
    AppDelegate.shared = self
    // Set activation policy to accessory (no dock icon)
    NSApp.setActivationPolicy(.accessory)

    // Create the status bar item
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem?.button {
      button.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Tweaks")
      button.action = #selector(togglePopover)
    }

    // Configure the popover (match SwiftUI view frame to avoid layout loops)
    popover.contentSize = NSSize(width: 380, height: 500)
    popover.behavior = .transient
    popover.contentViewController = NSHostingController(rootView: ContentView())

    // Install hotkey handler once and register from saved settings
    installHotkeyHandlerIfNeeded()
    let defaults = UserDefaults.standard
    let defaultKeyCode = UInt32(kVK_ANSI_T)
    let defaultModifiers = UInt32(controlKey)
    let keyCode =
      defaults.object(forKey: hotkeyKeyCodeDefaultsKey) != nil
      ? UInt32(defaults.integer(forKey: hotkeyKeyCodeDefaultsKey)) : defaultKeyCode
    let modifiers =
      defaults.object(forKey: hotkeyModifiersDefaultsKey) != nil
      ? UInt32(defaults.integer(forKey: hotkeyModifiersDefaultsKey)) : defaultModifiers
    registerGlobalHotkey(keyCode: keyCode, modifiers: modifiers)
  }

  @objc func togglePopover() {
    guard let button = statusItem?.button else { return }

    if popover.isShown {
      popover.performClose(nil)
    } else {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
  }

  func installHotkeyHandlerIfNeeded() {
    guard hotKeyEventHandler == nil else { return }
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(
      GetApplicationEventTarget(),
      { (callRef, eventRef, userData) -> OSStatus in
        guard let eventRef = eventRef else { return noErr }
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
          eventRef,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &hotKeyID)
        if status == noErr && hotKeyID.id == 1 {
          // Debug: hotkey recognized
          if DebugHelpers.isDebugBuild {
            let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
            print("[Tweaks] Hotkey pressed. Frontmost app=\(activeApp)")
          }
          // Invoke tweak on main thread using shared delegate
          if let appDelegate = AppDelegate.shared {
            if DebugHelpers.isDebugBuild { print("[Tweaks] Queuing pasteTweakedText on main") }
            DispatchQueue.main.async {
              if DebugHelpers.isDebugBuild {
                print("[Tweaks] Dispatching pasteTweakedText on main thread")
              }
              appDelegate.pasteTweakedText()
            }
          } else {
            if DebugHelpers.isDebugBuild {
              print("[Tweaks] Could not resolve AppDelegate for tweak invocation")
            }
          }
          // Trigger feedback
          DispatchQueue.main.async {
            HotkeyFeedbackManager.shared.hotkeyTriggered()
          }
        }
        return noErr
      }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &hotKeyEventHandler)
  }

  @discardableResult
  func registerGlobalHotkey(keyCode: UInt32, modifiers: UInt32) -> Bool {
    // Unregister previous hotkey if any
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
    // Avoid deprecated UTGetOSTypeFromString; use literal four-char code for 'TWKS'
    let signature: OSType = 0x5457_4B53
    let hotKeyID = EventHotKeyID(signature: signature, id: 1)
    let status = RegisterEventHotKey(
      keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    if status != noErr {
      print("RegisterEventHotKey failed: \(status)")
      return false
    }
    return true
  }

  @discardableResult
  func updateGlobalHotkey(keyCode: UInt32, modifiers: UInt32) -> Bool {
    let defaults = UserDefaults.standard
    defaults.set(Int(keyCode), forKey: hotkeyKeyCodeDefaultsKey)
    defaults.set(Int(modifiers), forKey: hotkeyModifiersDefaultsKey)
    return registerGlobalHotkey(keyCode: keyCode, modifiers: modifiers)
  }

  func pasteTweakedText() {
    if DebugHelpers.isDebugBuild {
      let trusted = AXIsProcessTrusted()
      #if canImport(Carbon)
        let secureInput = IsSecureEventInputEnabled()
      #else
        let secureInput = false
      #endif
      let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
      print(
        "[Tweaks] Enter pasteTweakedText trusted=\(trusted) secureInput=\(secureInput) app=\(activeApp)"
      )
    }
    // Ensure we have accessibility permission before attempting to post events
    guard AXIsProcessTrusted() else {
      if DebugHelpers.isDebugBuild {
        print("[Tweaks] Accessibility not trusted. Aborting tweak.")
      }
      return
    }

    // Ensure Osaurus is running before attempting to process text
    guard Osaurus.isRunning() else {
      if DebugHelpers.isDebugBuild {
        print("[Tweaks] Osaurus not running. Aborting tweak.")
      }
      return
    }

    let pasteboard = NSPasteboard.general

    // Check if clipboard contains text
    if let text = pasteboard.string(forType: .string) {
      if DebugHelpers.isDebugBuild {
        print("[Tweaks] Clipboard detected. Length=\(text.count)")
      }
      // Save current clipboard content
      let originalContent = text

      // Create tweak using Osaurus on a background task (streaming)
      Task {
        do {
          let client = try Osaurus.make()
          let (model, systemPrompt, temperature): (String, String, Double) = await MainActor.run {
            let settings = SettingsManager.shared
            let model = settings.selectedModelId
            let systemPrompt = settings.activePrompt?.content ?? Osaurus.Defaults.systemPrompt
            let temperature = settings.temperature
            return (model, systemPrompt, temperature)
          }

          // Stream deltas and paste incrementally
          let stream = client.tweakStream(
            text: originalContent,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature
          )

          var deltaBuffer = ""
          var receivedAny = false

          func pasteDelta(_ delta: String) {
            guard !delta.isEmpty else { return }
            DispatchQueue.main.async {
              pasteboard.clearContents()
              let ok = pasteboard.setString(delta, forType: .string)
              if DebugHelpers.isDebugBuild {
                print("[Tweaks] Pasting delta chunk (len=\(delta.count)) ok=\(ok)")
              }
              let prePasteDelay: TimeInterval = 0.02
              DispatchQueue.main.asyncAfter(deadline: .now() + prePasteDelay) {
                self.postCmdV(tap: .cgSessionEventTap, label: "session tap")
              }
            }
          }

          for try await chunk in stream {
            if chunk.isEmpty { continue }
            receivedAny = true
            deltaBuffer.append(chunk)

            // Simple coalescing: paste when buffer is reasonably sized or contains newline
            if deltaBuffer.count >= 24 || deltaBuffer.contains("\n") {
              pasteDelta(deltaBuffer)
              deltaBuffer.removeAll(keepingCapacity: true)
            }
          }

          // Paste any remaining buffered text
          if !deltaBuffer.isEmpty {
            pasteDelta(deltaBuffer)
            deltaBuffer.removeAll()
          }

          // If nothing streamed (edge-case), fall back to one-shot call
          if !receivedAny {
            if DebugHelpers.isDebugBuild {
              print("[Tweaks] Stream yielded no chunks. Falling back to non-stream call.")
            }
            let tweakedText = try await client.tweak(
              text: originalContent,
              model: model,
              systemPrompt: systemPrompt,
              temperature: temperature
            )
            DispatchQueue.main.async {
              pasteboard.clearContents()
              let setOk = pasteboard.setString(tweakedText, forType: .string)
              if DebugHelpers.isDebugBuild {
                print("[Tweaks] Fallback set clipboard ok=\(setOk)")
              }
              let prePasteDelay: TimeInterval = 0.02
              DispatchQueue.main.asyncAfter(deadline: .now() + prePasteDelay) {
                self.postCmdV(tap: .cgSessionEventTap, label: "session tap")
              }
            }
          }

          // Restore original clipboard after a short delay from the last paste
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) {
            pasteboard.clearContents()
            pasteboard.setString(originalContent, forType: .string)
            if DebugHelpers.isDebugBuild {
              print("[Tweaks] Original clipboard restored. Length=\(originalContent.count)")
            }
          }
        } catch {
          if DebugHelpers.isDebugBuild {
            print("[Tweaks] Osaurus tweak (stream) failed: \(error)")
          }
          // Fallback: paste original clipboard content unchanged
          DispatchQueue.main.async {
            pasteboard.clearContents()
            _ = pasteboard.setString(originalContent, forType: .string)
            let prePasteDelay: TimeInterval = 0.02
            DispatchQueue.main.asyncAfter(deadline: .now() + prePasteDelay) {
              self.postCmdV(tap: .cgSessionEventTap, label: "session tap")
            }
          }
        }
      }
    } else {
      if DebugHelpers.isDebugBuild {
        print("[Tweaks] Clipboard empty or not string. No action.")
      }
    }
  }

  private func postCmdV(tap: CGEventTapLocation, label: String) {
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
    if DebugHelpers.isDebugBuild {
      let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
      print("[Tweaks] Posted Cmd+V sequence via \(label) for app=\(activeApp)")
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    // Unregister hotkey and remove handler on terminate
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
    }
    if let hotKeyEventHandler {
      RemoveEventHandler(hotKeyEventHandler)
    }
  }

  // Temporarily unregister the current hotkey (used while recording a new shortcut)
  func suspendGlobalHotkey() {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
  }
}
