//
//  SystemSettingsView.swift
//  tweaks
//
//  Hotkey settings and app info
//

import Sparkle
import SwiftUI

// MARK: - System Settings View and subviews

struct SystemSettingsView: View {
  @Binding var recordingShortcut: Bool
  @Binding var recordedKeyCode: UInt32
  @Binding var recordedModifiers: UInt32
  @Binding var registrationResult: Bool?
  @StateObject private var sparkleManager = SparkleManager.shared
  private let actionControlWidth: CGFloat = 120

  var body: some View {
    VStack(spacing: 20) {
      // Hotkey Settings
      VStack(alignment: .leading, spacing: 12) {
        Label("Global Hotkey", systemImage: "keyboard")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(FuturisticTheme.text)

        HStack {
          Text("Current Shortcut")
            .font(.system(size: 12))
            .foregroundColor(FuturisticTheme.textSecondary)

          Spacer()

          Text(shortcutDisplayString(keyCode: recordedKeyCode, modifiers: recordedModifiers))
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundColor(FuturisticTheme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(FuturisticTheme.accent.opacity(0.1))
            .cornerRadius(FuturisticTheme.smallCornerRadius)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)

          if recordingShortcut {
            FuturisticButton(
              title: "Recording…",
              icon: "keyboard",
              action: {},
              style: .primary
            )
            .allowsHitTesting(false)
            .frame(width: actionControlWidth)
          } else {
            FuturisticButton(
              title: "Change",
              icon: "keyboard",
              action: {
                // Temporarily suspend current hotkey so it doesn't fire while capturing
                HotkeyManager.shared.suspendShortcut()
                recordingShortcut = true
              },
              style: .secondary
            )
            .frame(width: actionControlWidth)
          }
        }

        if recordingShortcut {
          HStack {
            Image(systemName: "keyboard.fill")
              .foregroundColor(FuturisticTheme.accent)
              .font(.system(size: 12))
            Text("Press your desired key combination...")
              .font(.system(size: 11))
              .foregroundColor(FuturisticTheme.accent)
          }
          .transition(.opacity.combined(with: .move(edge: .top)))
        } else if let result = registrationResult {
          HStack(spacing: 8) {
            Image(systemName: result ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
              .foregroundColor(result ? FuturisticTheme.success : FuturisticTheme.warning)
            Text(result ? "Hotkey updated" : "Failed to register hotkey")
              .font(.system(size: 11))
              .foregroundColor(FuturisticTheme.textSecondary)
          }
          .transition(.opacity)
        }
      }
      .padding()
      .glassEffect()

      // Updates Section
      VStack(alignment: .leading, spacing: 12) {
        Label("Updates", systemImage: "arrow.triangle.2.circlepath")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(FuturisticTheme.text)

        HStack {
          Text("Automatic Updates")
            .font(.system(size: 12))
            .foregroundColor(FuturisticTheme.textSecondary)

          Spacer()

          Toggle("", isOn: $sparkleManager.automaticUpdateChecks)
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .onChange(of: sparkleManager.automaticUpdateChecks) { _, newValue in
              sparkleManager.setAutomaticUpdateChecks(newValue)
            }
        }

        HStack {
          Text(sparkleManager.updateStatusString)
            .font(.system(size: 11))
            .foregroundColor(FuturisticTheme.textTertiary)

          Spacer()

          FuturisticButton(
            title: sparkleManager.isCheckingForUpdates ? "Checking..." : "Check Now",
            icon: "arrow.triangle.2.circlepath",
            action: {
              sparkleManager.checkForUpdates()
            },
            style: .secondary
          )
          .disabled(sparkleManager.isCheckingForUpdates || !sparkleManager.canCheckForUpdates)
        }
      }
      .padding()
      .glassEffect()

      // App Info
      VStack(alignment: .leading, spacing: 16) {
        Label("About Tweaks", systemImage: "info.circle")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(FuturisticTheme.text)

        VStack(spacing: 12) {
          InfoRow(icon: "menubar.rectangle", text: "Lives in your menu bar")
          InfoRow(icon: "keyboard.fill", text: "Global hotkey support")
          InfoRow(icon: "brain", text: "Powered by local AI (Osaurus)")
          InfoRow(icon: "lock.shield", text: "Privacy-focused, runs locally")
          InfoRow(icon: "arrow.triangle.2.circlepath", text: "Auto-update enabled")
        }
      }
      .padding()
      .glassEffect()

      // Quit Button
      FuturisticButton(
        title: "Quit Tweaks",
        icon: "power",
        action: { NSApp.terminate(nil) },
        style: .secondary
      )
      .foregroundColor(FuturisticTheme.error)
    }
  }
}

struct InfoRow: View {
  let icon: String
  let text: String

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 12))
        .foregroundColor(FuturisticTheme.accent)
        .frame(width: 20)

      Text(text)
        .font(.system(size: 12))
        .foregroundColor(FuturisticTheme.textSecondary)

      Spacer()
    }
  }
}
