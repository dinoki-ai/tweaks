//
//  MainView.swift
//  tweaks
//
//  Overview tab: hero, status, and test UI
//

import SwiftUI

// MARK: - Main View and subviews

struct MainView: View {
  @State var recordedKeyCode: UInt32
  @State var recordedModifiers: UInt32
  @State private var recordingShortcut: Bool = false
  @State private var hotkeyRegistrationStatus: Bool? = nil
  @ObservedObject private var permissionManager = PermissionManager.shared
  @ObservedObject private var settingsManager = SettingsManager.shared
  @ObservedObject private var feedbackManager = HotkeyFeedbackManager.shared

  var body: some View {
    VStack(spacing: 20) {
      // Hero Section
      VStack(spacing: 16) {
        // Hotkey Display
        VStack(spacing: 8) {
          Text("Press to Tweak")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(FuturisticTheme.textSecondary)

          Text(shortcutDisplayString(keyCode: recordedKeyCode, modifiers: recordedModifiers))
            .font(.system(size: 24, weight: .bold, design: .monospaced))
            .foregroundColor(FuturisticTheme.accent)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(FuturisticTheme.accent.opacity(0.1))
            .cornerRadius(FuturisticTheme.cornerRadius)
            .overlay(
              RoundedRectangle(cornerRadius: FuturisticTheme.cornerRadius)
                .stroke(FuturisticTheme.accent.opacity(0.3), lineWidth: 1)
            )
            .neonGlow(color: FuturisticTheme.accent, radius: 8)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }

        // Current Settings
        HStack(spacing: 16) {
          InfoPill(
            icon: "cpu",
            text: settingsManager.availableModels.first(where: {
              $0.id == settingsManager.selectedModelId
            })?.displayName ?? "Loading..."
          )

          InfoPill(
            icon: "text.bubble",
            text: settingsManager.activePrompt?.name ?? "Default"
          )
        }
      }
      .futuristicCard()

      // Hotkey Configuration
      HotkeyConfigurationCard(
        recordingShortcut: $recordingShortcut,
        recordedKeyCode: $recordedKeyCode,
        recordedModifiers: $recordedModifiers,
        registrationResult: $hotkeyRegistrationStatus
      )

      // Permission Status
      if permissionManager.accessibilityStatus != .granted {
        PermissionCard()
      }

      // Quick Test
      if permissionManager.accessibilityStatus == .granted {
        TestSection()
      }
    }
    .background(
      RecordingView(isRecording: $recordingShortcut) { keyCode, modifiers in
        recordedKeyCode = keyCode
        recordedModifiers = modifiers
        let success = HotkeyManager.shared.updateShortcut(
          keyCode: keyCode, modifiers: modifiers)
        hotkeyRegistrationStatus = success
        // Auto-clear the status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
          hotkeyRegistrationStatus = nil
        }
        feedbackManager.hotkeyTriggered()
      }
    )
    .onChange(of: recordingShortcut) { oldValue, isRecording in
      if isRecording {
        HotkeyManager.shared.suspendShortcut()
      } else {
        // Re-register current shortcut when recording stops (in case user cancelled)
        _ = HotkeyManager.shared.registerShortcut(
          keyCode: recordedKeyCode, modifiers: recordedModifiers)
      }
    }
  }
}

struct InfoPill: View {
  let icon: String
  let text: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 11))
      Text(text)
        .font(.system(size: 11, weight: .medium))
        .lineLimit(1)
    }
    .foregroundColor(FuturisticTheme.textSecondary)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(FuturisticTheme.surface)
    .cornerRadius(20)
  }
}

// MARK: - Permission Card

struct PermissionCard: View {
  @ObservedObject private var permissionManager = PermissionManager.shared

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: permissionManager.accessibilityStatus.icon)
        .font(.system(size: 32))
        .foregroundColor(permissionManager.accessibilityStatus.color)

      Text(permissionManager.accessibilityStatus.message)
        .font(.system(size: 12))
        .foregroundColor(FuturisticTheme.textSecondary)
        .multilineTextAlignment(.center)

      if permissionManager.accessibilityStatus == .notRequested
        || permissionManager.accessibilityStatus == .denied
      {
        FuturisticButton(
          title: "Grant Permission",
          icon: "lock.open",
          action: { permissionManager.requestPermission() },
          style: .primary
        )
      }
    }
    .frame(maxWidth: .infinity)
    .padding()
    .glassEffect()
  }
}

// MARK: - Test Section

struct TestSection: View {
  @ObservedObject private var feedbackManager = HotkeyFeedbackManager.shared

  var body: some View {
    VStack(spacing: 12) {
      Label("Test Your Hotkey", systemImage: "wand.and.stars")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(FuturisticTheme.text)

      Text("Copy some text and press your hotkey to see it transformed")
        .font(.system(size: 11))
        .foregroundColor(FuturisticTheme.textSecondary)
        .multilineTextAlignment(.center)

      // Visual feedback
      if feedbackManager.showingFeedback {
        HStack {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(FuturisticTheme.accent)
          Text("Hotkey triggered!")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(FuturisticTheme.accent)
        }
        .transition(.scale.combined(with: .opacity))
      }
    }
    .frame(maxWidth: .infinity)
    .padding()
    .glassEffect()
  }
}

// MARK: - Hotkey Configuration Card

struct HotkeyConfigurationCard: View {
  @Binding var recordingShortcut: Bool
  @Binding var recordedKeyCode: UInt32
  @Binding var recordedModifiers: UInt32
  @Binding var registrationResult: Bool?

  private let actionControlWidth: CGFloat = 100

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Hotkey Settings", systemImage: "keyboard")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(FuturisticTheme.text)

      HStack {
        Text("Global Shortcut")
          .font(.system(size: 12))
          .foregroundColor(FuturisticTheme.textSecondary)

        Spacer()

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
            .foregroundColor(
              result ? FuturisticTheme.accent : FuturisticTheme.accent.opacity(0.6))
          Text(result ? "Hotkey updated" : "Failed to register hotkey")
            .font(.system(size: 11))
            .foregroundColor(FuturisticTheme.textSecondary)
        }
        .transition(.opacity)
      }
    }
    .padding()
    .glassEffect()
  }
}
