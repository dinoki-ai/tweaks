//
//  HotkeyManager.swift
//  tweaks
//
//  Centralizes global hotkey registration and handling
//

import AppKit
import Carbon
import Foundation

@MainActor
final class HotkeyManager {
  static let shared = HotkeyManager()

  private var hotKeyRef: EventHotKeyRef?
  private var hotKeyEventHandler: EventHandlerRef?

  private let hotkeyKeyCodeDefaultsKey = "HotkeyKeyCode"
  private let hotkeyModifiersDefaultsKey = "HotkeyModifiers"

  private init() {}

  func installHandlerIfNeeded() {
    guard hotKeyEventHandler == nil else { return }
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(
      GetApplicationEventTarget(),
      { (_, eventRef, _) -> OSStatus in
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
          DispatchQueue.main.async {
            HotkeyFeedbackManager.shared.hotkeyTriggered()
            QuickTweakMenuPresenter.shared.showCenteredHUD()
          }
        }
        return noErr
      }, 1, &eventType, nil, &hotKeyEventHandler)
  }

  @discardableResult
  func registerShortcut(keyCode: UInt32, modifiers: UInt32) -> Bool {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
    let signature: OSType = 0x5457_4B53  // 'TWKS'
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
  func updateShortcut(keyCode: UInt32, modifiers: UInt32) -> Bool {
    let defaults = UserDefaults.standard
    defaults.set(Int(keyCode), forKey: hotkeyKeyCodeDefaultsKey)
    defaults.set(Int(modifiers), forKey: hotkeyModifiersDefaultsKey)
    return registerShortcut(keyCode: keyCode, modifiers: modifiers)
  }

  func registerSavedShortcutOrDefault(
    defaultKeyCode: UInt32 = UInt32(kVK_ANSI_T), defaultModifiers: UInt32 = UInt32(controlKey)
  ) {
    let defaults = UserDefaults.standard
    let keyCode =
      defaults.object(forKey: hotkeyKeyCodeDefaultsKey) != nil
      ? UInt32(defaults.integer(forKey: hotkeyKeyCodeDefaultsKey)) : defaultKeyCode
    let modifiers =
      defaults.object(forKey: hotkeyModifiersDefaultsKey) != nil
      ? UInt32(defaults.integer(forKey: hotkeyModifiersDefaultsKey)) : defaultModifiers
    _ = registerShortcut(keyCode: keyCode, modifiers: modifiers)
  }

  func suspendShortcut() {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
  }

  func teardown() {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
    if let hotKeyEventHandler {
      RemoveEventHandler(hotKeyEventHandler)
      self.hotKeyEventHandler = nil
    }
  }
}
