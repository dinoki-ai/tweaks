//
//  AppDelegate.swift
//  tweaks
//
//  Created by Terence on 10/5/25.
//

import AppKit
import Sparkle
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  static var shared: AppDelegate?
  var statusItem: NSStatusItem?
  var popover = NSPopover()

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Expose shared reference for convenient access from SwiftUI views
    AppDelegate.shared = self
    // Set activation policy to accessory (no dock icon)
    NSApp.setActivationPolicy(.accessory)

    // Initialize Sparkle for auto-updates
    _ = SparkleManager.shared

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

    // Install hotkey handler and register saved shortcut
    HotkeyManager.shared.installHandlerIfNeeded()
    HotkeyManager.shared.registerSavedShortcutOrDefault()
  }

  @objc func togglePopover() {
    guard let button = statusItem?.button else { return }

    if popover.isShown {
      popover.performClose(nil)
    } else {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
  }

  func pasteTweakedText() { TweakService.shared.pasteTweakedText() }

  private func postCmdV(tap: CGEventTapLocation, label: String) {}

  func applicationWillTerminate(_ notification: Notification) {
    // Unregister hotkey and remove handler on terminate
    HotkeyManager.shared.teardown()
  }

  // Temporarily unregister the current hotkey (used while recording a new shortcut)
  func suspendGlobalHotkey() { HotkeyManager.shared.suspendShortcut() }
}
