//
//  ShortcutRecorder.swift
//  tweaks
//
//  NSView wrapper to record keyboard shortcut combinations
//

import AppKit
import Carbon
import SwiftUI

struct RecordingView: NSViewRepresentable {
  @Binding var isRecording: Bool
  let onRecord: (UInt32, UInt32) -> Void

  func makeNSView(context: Context) -> RecordingNSView {
    let v = RecordingNSView()
    v.onRecord = { keyCode, modifiers in
      onRecord(keyCode, modifiers)
      DispatchQueue.main.async { isRecording = false }
    }
    return v
  }

  func updateNSView(_ nsView: RecordingNSView, context: Context) {
    nsView.setRecording(isRecording)
  }
}

final class RecordingNSView: NSView {
  private(set) var isRecording: Bool = false
  var onRecord: ((UInt32, UInt32) -> Void)?

  override var acceptsFirstResponder: Bool { true }

  func setRecording(_ recording: Bool) {
    isRecording = recording
    if recording {
      window?.makeFirstResponder(self)
    }
  }

  override func keyDown(with event: NSEvent) {
    guard isRecording else { return }
    let keyCode = UInt32(event.keyCode)
    let modifiers = convertModifiers(event.modifierFlags)
    onRecord?(keyCode, modifiers)
  }

  private func convertModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
    var mods: UInt32 = 0
    if flags.contains(.shift) { mods |= UInt32(shiftKey) }
    if flags.contains(.control) { mods |= UInt32(controlKey) }
    if flags.contains(.option) { mods |= UInt32(optionKey) }
    if flags.contains(.command) { mods |= UInt32(cmdKey) }
    return mods
  }
}
