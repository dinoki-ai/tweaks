//
//  HeaderView.swift
//  tweaks
//
//  Header bar with status indicator and tabs
//

import SwiftUI

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
                colors: [FuturisticTheme.accent, FuturisticTheme.accent.opacity(0.6)],
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
        options: ["Overview", "Settings"]
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
