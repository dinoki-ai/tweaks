//
//  ContentView.swift
//  tweaks
//
//  Root container view and tab routing
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

#Preview {
  ContentView()
}
