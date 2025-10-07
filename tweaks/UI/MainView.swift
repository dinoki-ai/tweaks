//
//  MainView.swift
//  tweaks
//
//  Overview tab: hero, status, and test UI
//

import SwiftUI

// MARK: - Main View and subviews

struct MainView: View {
  let recordedKeyCode: UInt32
  let recordedModifiers: UInt32
  @ObservedObject private var permissionManager = PermissionManager.shared
  @ObservedObject private var settingsManager = SettingsManager.shared

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

      // Permission Status
      if permissionManager.accessibilityStatus != .granted {
        PermissionCard()
      }

      // Quick Test
      if permissionManager.accessibilityStatus == .granted {
        TestSection()
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
            .foregroundColor(FuturisticTheme.success)
          Text("Hotkey triggered!")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(FuturisticTheme.success)
        }
        .transition(.scale.combined(with: .opacity))
      }
    }
    .frame(maxWidth: .infinity)
    .padding()
    .glassEffect()
  }
}
