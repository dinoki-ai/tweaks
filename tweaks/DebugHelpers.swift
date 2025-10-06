//
//  DebugHelpers.swift
//  tweaks
//
//  Debug utilities for managing accessibility permissions during development
//

import AppKit
import SwiftUI

struct DebugHelpers {
  static var isDebugBuild: Bool {
    #if DEBUG
      return true
    #else
      return false
    #endif
  }

  static var appPath: String {
    Bundle.main.bundlePath
  }

  static var appName: String {
    Bundle.main.bundleURL.lastPathComponent
  }

  static var buildIdentifier: String {
    // Create a unique identifier for this specific build
    let path = Bundle.main.bundlePath
    let modDate =
      try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
    let dateString = modDate?.timeIntervalSince1970.description ?? "unknown"
    return "\(appName) - \(dateString)"
  }

  static func copyDebugInstructions() {
    let instructions = """
      To enable accessibility for this debug build:

      1. Open System Settings > Privacy & Security > Accessibility
      2. Click the "+" button
      3. Navigate to: \(appPath)
      4. Select "\(appName)" and click "Open"
      5. Toggle the switch ON for the app

      Build ID: \(buildIdentifier)
      """

    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(instructions, forType: .string)
  }

  static func openAccessibilityPreferences() {
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    {
      NSWorkspace.shared.open(url)
    }
  }

  static func createDebugScript() {
    let script = """
      #!/bin/bash
      # Debug helper script for \(appName)
      # Generated on: \(Date().description)

      echo "🔧 Tweaks Debug Helper"
      echo "====================="
      echo ""
      echo "Current app path: \(appPath)"
      echo ""
      echo "To grant accessibility permissions:"
      echo "1. Open System Settings > Privacy & Security > Accessibility"
      echo "2. If an old version exists, remove it with the '-' button"
      echo "3. Click '+' and navigate to the path above"
      echo "4. Toggle the switch ON"
      echo ""
      echo "Opening accessibility settings..."
      open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
      echo ""
      echo "App path copied to clipboard!"
      echo "\(appPath)" | pbcopy
      """

    let scriptPath = NSTemporaryDirectory() + "tweaks_debug_helper.sh"
    try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)

    // Make it executable
    Process.launchedProcess(launchPath: "/bin/chmod", arguments: ["+x", scriptPath])

    // Copy path to clipboard
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(scriptPath, forType: .string)
  }
}

// Debug-only view component
struct DebugPermissionHelper: View {
  @State private var showingInstructions = false
  @State private var copiedPath = false
  @State private var scriptCreated = false

  var body: some View {
    #if DEBUG
      VStack(alignment: .leading, spacing: 12) {
        Label("Debug Mode", systemImage: "hammer.fill")
          .font(.headline)
          .foregroundColor(.orange)

        Text("App Path: \(DebugHelpers.appPath)")
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(2)
          .help(DebugHelpers.appPath)

        VStack(spacing: 8) {
          Button(action: {
            DebugHelpers.openAccessibilityPreferences()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(DebugHelpers.appPath, forType: .string)
            copiedPath = true

            // Reset after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
              copiedPath = false
            }
          }) {
            HStack {
              Image(systemName: copiedPath ? "checkmark.circle.fill" : "key.fill")
                .foregroundColor(copiedPath ? .green : nil)
              Text(copiedPath ? "Path Copied!" : "Setup Accessibility")
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)

          HStack(spacing: 8) {
            Button(action: {
              DebugHelpers.copyDebugInstructions()
              showingInstructions.toggle()
            }) {
              Image(systemName: "doc.on.doc")
              Text("Instructions")
            }
            .buttonStyle(.bordered)

            Button(action: {
              DebugHelpers.createDebugScript()
              scriptCreated = true

              // Open Terminal with the script using modern API
              if let scriptPath = NSPasteboard.general.string(forType: .string) {
                let fileURL = URL(fileURLWithPath: scriptPath)
                if let terminalURL = NSWorkspace.shared.urlForApplication(
                  withBundleIdentifier: "com.apple.Terminal")
                {
                  let config = NSWorkspace.OpenConfiguration()
                  NSWorkspace.shared.open(
                    [fileURL], withApplicationAt: terminalURL, configuration: config
                  ) { _, _ in }
                } else {
                  // Fallback if Terminal URL cannot be found
                  NSWorkspace.shared.open(fileURL)
                }
              }

              // Reset after 2 seconds
              DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                scriptCreated = false
              }
            }) {
              Image(systemName: scriptCreated ? "checkmark.circle.fill" : "terminal")
              Text(scriptCreated ? "Created!" : "Debug Script")
            }
            .buttonStyle(.bordered)
            .foregroundColor(scriptCreated ? .green : nil)
          }
        }

        if showingInstructions {
          Text("Instructions copied to clipboard!")
            .font(.caption)
            .foregroundColor(.green)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
      .padding()
      .background(Color.orange.opacity(0.1))
      .cornerRadius(8)
    #else
      EmptyView()
    #endif
  }
}
