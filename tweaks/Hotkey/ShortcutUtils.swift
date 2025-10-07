//
//  ShortcutUtils.swift
//  tweaks
//
//  Helpers to display and manage keyboard shortcuts
//

import Carbon
import Foundation

func shortcutDisplayString(keyCode: UInt32, modifiers: UInt32) -> String {
  var parts: [String] = []
  if (modifiers & UInt32(cmdKey)) != 0 { parts.append("⌘") }
  if (modifiers & UInt32(shiftKey)) != 0 { parts.append("⇧") }
  if (modifiers & UInt32(optionKey)) != 0 { parts.append("⌥") }
  if (modifiers & UInt32(controlKey)) != 0 { parts.append("⌃") }
  let key = keyCodeToString(keyCode)
  parts.append(key)
  return parts.joined()
}

func keyCodeToString(_ keyCode: UInt32) -> String {
  let letters: [UInt32: String] = [
    UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
    UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
    UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
    UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
    UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
    UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
    UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
    UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
    UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
  ]

  let digits: [UInt32: String] = [
    UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
    UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
    UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
    UInt32(kVK_ANSI_9): "9",
  ]

  if let letter = letters[keyCode] { return letter }
  if let digit = digits[keyCode] { return digit }

  switch keyCode {
  case UInt32(kVK_Space): return "Space"
  case UInt32(kVK_Return): return "Return"
  case UInt32(kVK_Escape): return "Esc"
  case UInt32(kVK_Tab): return "Tab"
  case UInt32(kVK_Delete): return "Delete"
  default:
    return "Key\(keyCode)"
  }
}
