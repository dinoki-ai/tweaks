//
//  ContentView.swift
//  tweaks
//
//  Created by Terence on 10/5/25.
//

import AppKit
import Carbon
import SwiftUI

struct ContentView: View {
  @StateObject private var settingsManager = SettingsManager.shared
  @ObservedObject private var permissionManager = PermissionManager.shared
  @ObservedObject private var feedbackManager = HotkeyFeedbackManager.shared

  @State private var selectedTab = 0
  @State private var recordingShortcut: Bool = false
  @State private var recordedKeyCode: UInt32 = UInt32(kVK_ANSI_T)
  @State private var recordedModifiers: UInt32 = UInt32(controlKey)
  @State private var showingPromptEditor = false
  @State private var hotkeyRegistrationStatus: Bool? = nil

  private func loadSavedShortcut() {
    let defaults = UserDefaults.standard
    if defaults.object(forKey: "HotkeyKeyCode") != nil {
      recordedKeyCode = UInt32(defaults.integer(forKey: "HotkeyKeyCode"))
    }
    if defaults.object(forKey: "HotkeyModifiers") != nil {
      recordedModifiers = UInt32(defaults.integer(forKey: "HotkeyModifiers"))
    }
  }

  var body: some View {
    ZStack {
      // Background
      FuturisticTheme.background
        .ignoresSafeArea()

      VStack(spacing: 0) {
        // Header
        HeaderView(
          permissionStatus: permissionManager.accessibilityStatus,
          selectedTab: $selectedTab
        )

        // Main Content
        ScrollView {
          VStack(spacing: 20) {
            switch selectedTab {
            case 0:
              MainView(
                recordedKeyCode: recordedKeyCode,
                recordedModifiers: recordedModifiers
              )
            case 1:
              AISettingsView()
            case 2:
              SystemSettingsView(
                recordingShortcut: $recordingShortcut,
                recordedKeyCode: $recordedKeyCode,
                recordedModifiers: $recordedModifiers,
                registrationResult: $hotkeyRegistrationStatus
              )
            default:
              EmptyView()
            }
          }
          .padding(20)
        }
      }
    }
    .frame(width: 380, height: 500)
    .preferredColorScheme(.dark)
    .onAppear {
      loadSavedShortcut()
      Task {
        await settingsManager.fetchAvailableModels()
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

// MARK: - Header

struct HeaderView: View {
  let permissionStatus: AccessibilityStatus
  @Binding var selectedTab: Int
  @State private var isOsaurusRunning: Bool = false
  @State private var checkTimer: Timer?
  @State private var previousActiveState: Bool = false

  var body: some View {
    VStack(spacing: 0) {
      // Title Bar
      HStack(spacing: 12) {
        // Logo
        ZStack {
          Circle()
            .fill(
              LinearGradient(
                colors: [FuturisticTheme.accent, FuturisticTheme.accentSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 32, height: 32)

          Image(systemName: "sparkles")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.black)
        }
        .neonGlow(radius: 6)

        VStack(alignment: .leading, spacing: 2) {
          Text("Tweaks")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(FuturisticTheme.text)

          Text("AI-Powered Paste")
            .font(.system(size: 11))
            .foregroundColor(FuturisticTheme.textSecondary)
        }

        Spacer()

        // Status Indicator
        StatusIndicator(status: permissionStatus, isOsaurusRunning: isOsaurusRunning)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .onAppear {
        checkOsaurus()
        startPeriodicCheck()
      }
      .onDisappear {
        stopPeriodicCheck()
      }
      .onChange(of: permissionStatus) { oldValue, newValue in
        // When permission status changes, re-evaluate active state
        let nowActive = isActive
        if nowActive != previousActiveState {
          handleActiveStatusChange(nowActive: nowActive)
          previousActiveState = nowActive
        }
      }

      // Tab Bar
      FuturisticSegmentedControl(
        selection: $selectedTab,
        options: ["Overview", "AI Model", "Settings"]
      )
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
    }
    .background(
      LinearGradient(
        colors: [
          FuturisticTheme.surface.opacity(0.3),
          FuturisticTheme.background,
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    )
  }
}

struct StatusIndicator: View {
  let status: AccessibilityStatus
  let isOsaurusRunning: Bool

  private var isActive: Bool {
    status == .granted && isOsaurusRunning
  }

  private var statusColor: Color {
    isActive ? .green : .red
  }

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(statusColor)
        .frame(width: 8, height: 8)
        .neonGlow(color: statusColor, radius: 4)

      Text(isActive ? "Active" : "Inactive")
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(statusColor)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(statusColor.opacity(0.1))
    .cornerRadius(20)
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(statusColor.opacity(0.3), lineWidth: 1)
    )
  }
}

extension HeaderView {
  fileprivate var isActive: Bool {
    permissionStatus == .granted && isOsaurusRunning
  }

  fileprivate func checkOsaurus() {
    Task {
      let running = await Osaurus.checkHealth()
      await MainActor.run {
        let wasActive = self.previousActiveState
        self.isOsaurusRunning = running
        let nowActive = self.isActive

        // Detect status changes
        if wasActive != nowActive {
          handleActiveStatusChange(nowActive: nowActive)
        }

        self.previousActiveState = nowActive
      }
    }
  }

  fileprivate func handleActiveStatusChange(nowActive: Bool) {
    if nowActive {
      // System became active: enable hotkeys and refresh models
      #if DEBUG
        print("[Tweaks] System became ACTIVE - enabling hotkeys and refreshing models")
      #endif

      // Re-enable hotkeys
      HotkeyManager.shared.registerSavedShortcutOrDefault()

      // Refresh models
      Task {
        await SettingsManager.shared.fetchAvailableModels()
      }
    } else {
      // System became inactive: disable hotkeys
      #if DEBUG
        print("[Tweaks] System became INACTIVE - disabling hotkeys")
      #endif

      HotkeyManager.shared.suspendShortcut()
    }
  }

  fileprivate func startPeriodicCheck() {
    // Initialize previous state
    previousActiveState = isActive

    // Check every 2 seconds while the panel is visible
    checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
      checkOsaurus()
    }
  }

  fileprivate func stopPeriodicCheck() {
    checkTimer?.invalidate()
    checkTimer = nil
  }
}

// MARK: - Main View

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

// MARK: - AI Settings View

struct AISettingsView: View {
  @ObservedObject private var settingsManager = SettingsManager.shared
  @State private var showingPromptEditor = false

  var body: some View {
    VStack(spacing: 20) {
      // Model Selection
      VStack(alignment: .leading, spacing: 12) {
        Label("AI Model", systemImage: "cpu")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(FuturisticTheme.text)

        if settingsManager.isLoadingModels {
          HStack {
            ProgressView()
              .scaleEffect(0.8)
            Text("Loading models...")
              .font(.system(size: 12))
              .foregroundColor(FuturisticTheme.textSecondary)
          }
          .frame(maxWidth: .infinity)
          .padding()
          .glassEffect()
        } else if let error = settingsManager.modelsFetchError {
          VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
              .font(.system(size: 24))
              .foregroundColor(FuturisticTheme.warning)
            Text(error)
              .font(.system(size: 11))
              .foregroundColor(FuturisticTheme.textSecondary)
              .multilineTextAlignment(.center)
            FuturisticButton(
              title: "Retry",
              icon: "arrow.clockwise",
              action: {
                Task {
                  await settingsManager.fetchAvailableModels()
                }
              },
              style: .secondary
            )
          }
          .frame(maxWidth: .infinity)
          .padding()
          .glassEffect()
        } else {
          VStack(spacing: 8) {
            ForEach(settingsManager.availableModels) { model in
              ModelRow(
                model: model,
                isSelected: settingsManager.selectedModelId == model.id,
                onSelect: {
                  settingsManager.selectModel(model.id)
                }
              )
            }
          }
        }
      }

      // System Prompts
      PromptEditorView()
        .padding()
        .glassEffect()

      // Temperature Control
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Label("Temperature", systemImage: "thermometer")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(FuturisticTheme.text)

          Spacer()

          Text(String(format: "%.1f", settingsManager.temperature))
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(FuturisticTheme.accent)
        }

        Slider(
          value: Binding(
            get: { settingsManager.temperature },
            set: { settingsManager.updateTemperature($0) }
          ), in: 0...2, step: 0.1
        )
        .accentColor(FuturisticTheme.accent)

        HStack {
          Text("Precise")
            .font(.system(size: 10))
          Spacer()
          Text("Creative")
            .font(.system(size: 10))
        }
        .foregroundColor(FuturisticTheme.textTertiary)
      }
      .padding()
      .glassEffect()
    }
  }
}

struct ModelRow: View {
  let model: OsaurusModel
  let isSelected: Bool
  let onSelect: () -> Void

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(model.displayName)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(FuturisticTheme.text)

        if let owner = model.owned_by {
          Text("by \(owner)")
            .font(.system(size: 10))
            .foregroundColor(FuturisticTheme.textTertiary)
        }
      }

      Spacer()

      if isSelected {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 14))
          .foregroundColor(FuturisticTheme.accent)
      }
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
        .fill(isSelected ? FuturisticTheme.accent.opacity(0.1) : FuturisticTheme.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
        .stroke(
          isSelected ? FuturisticTheme.accent.opacity(0.3) : Color.clear,
          lineWidth: 1
        )
    )
    .onTapGesture {
      onSelect()
    }
  }
}

// MARK: - System Settings View

struct SystemSettingsView: View {
  @Binding var recordingShortcut: Bool
  @Binding var recordedKeyCode: UInt32
  @Binding var recordedModifiers: UInt32
  @Binding var registrationResult: Bool?
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

#Preview {
  ContentView()
}
